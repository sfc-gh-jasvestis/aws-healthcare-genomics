-- Synthetic instrument-day observations for a fictional Singapore research sequencing
-- lab network. 40 sequencers = 8 lab sites x 5 assay lines. Data is aggregate
-- per instrument and day: there are no patient, sample-level or variant records.
-- Nothing is seeded as a prediction. Randomness is HASH-seeded, so every rebuild
-- is reproducible: per-instrument QC failure propensity, drift between periodic
-- preventive maintenance (PM) visits, missed PM visits, assay-weighted failure
-- modes, QC flags that pass on review, and two site-wide reagent lot holds.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.SEQUENCERS AS
WITH instruments AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS SEQ_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT SEQ_INDEX,
         MOD(ABS(HASH(SEQ_INDEX, 'sg-age')), 1000000) / 1e6 AS U_AGE,
         MOD(ABS(HASH(SEQ_INDEX, 'sg-rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(SEQ_INDEX, 'sg-pm')), 1000000) / 1e6 AS U_PM,
         MOD(ABS(HASH(SEQ_INDEX, 'sg-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(SEQ_INDEX, 'sg-tier')), 1000000) / 1e6 AS U_TIER,
         MOD(ABS(HASH(SEQ_INDEX, 'sg-size')), 1000000) / 1e6 AS U_SIZE
  FROM instruments
), named AS (
  SELECT *,
         -- Every lab site x assay combination appears exactly once.
         CASE MOD(SEQ_INDEX, 8) WHEN 0 THEN 'Queenstown' WHEN 1 THEN 'Novena'
              WHEN 2 THEN 'Outram' WHEN 3 THEN 'Jurong East' WHEN 4 THEN 'Tampines'
              WHEN 5 THEN 'Woodlands' WHEN 6 THEN 'Seletar' ELSE 'Changi' END AS REGION,
         CASE FLOOR(SEQ_INDEX / 8) WHEN 0 THEN 'Whole Genome' WHEN 1 THEN 'Whole Exome'
              WHEN 2 THEN 'Targeted Panel' WHEN 3 THEN 'RNA-Seq'
              ELSE 'Pathogen Surveillance' END AS CATEGORY
  FROM draws
)
SELECT 'SQ-' || LPAD(SEQ_INDEX::VARCHAR, 4, '0') AS ID,
       REGION || ' ' || CATEGORY AS NAME,
       REGION, CATEGORY, SEQ_INDEX,
       1 + FLOOR(U_TIER * 3) AS UTILISATION_TIER,
       ROUND(0.3 + U_AGE * 5.7, 1) AS INSTRUMENT_AGE_YEARS,
       ROUND(0.6 + U_SIZE * 0.8, 3) AS SIZE_FACTOR,
       -- Base daily probability of a failed run 0.4%-3%; ~15% of instruments
       -- have a recurring hardware issue (x3).
       (0.004 + U_RATE * 0.026) * IFF(U_RATE > 0.85, 3, 1) AS BASE_FAIL_RATE,
       7 * (1 + FLOOR(U_PM * 3)) AS PM_INTERVAL_DAYS,
       0.55 + U_DISCIPLINE * 0.45 AS PM_COMPLETION_PROB,
       ROUND(CASE CATEGORY WHEN 'Whole Genome' THEN 24 * 100 WHEN 'Whole Exome' THEN 48 * 8
                           WHEN 'Targeted Panel' THEN 96 * 1 WHEN 'RNA-Seq' THEN 36 * 6
                           ELSE 64 * 2 END * (0.6 + U_SIZE * 0.8), 1) AS DAILY_TARGET_GB,
       'Active' AS STATUS
FROM named;


CREATE TABLE RAW.SEQUENCER_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), lot_holds AS (
  -- Two site-wide reagent lot holds; every instrument at the site gets a QC flag.
  SELECT * FROM VALUES (31, 'Novena'), (58, 'Seletar') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT s.ID AS ENTITY_ID, s.SEQ_INDEX, s.CATEGORY, s.REGION, s.INSTRUMENT_AGE_YEARS,
         s.SIZE_FACTOR, s.DAILY_TARGET_GB,
         s.BASE_FAIL_RATE, s.PM_INTERVAL_DAYS, s.PM_COMPLETION_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + s.SEQ_INDEX * 5, s.PM_INTERVAL_DAYS) AS DAYS_SINCE_PM,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-fail')), 1000000) / 1e6 AS U_FAIL,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-fp')), 1000000) / 1e6 AS U_FP,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-mode')), 1000000) / 1e6 AS U_MODE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-done')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-samples')), 1000000) / 1e6 AS U_SAMPLES,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-rerun')), 1000000) / 1e6 AS U_RERUN,
         h.REGION IS NOT NULL AS LOT_HOLD
  FROM RAW.SEQUENCERS s CROSS JOIN days d
  LEFT JOIN lot_holds h ON h.DAY_INDEX = d.DAY_INDEX AND h.REGION = s.REGION
), pm AS (
  SELECT *,
         IFF(DAYS_SINCE_PM = 0, 1, 0) AS PM_DUE,
         IFF(DAYS_SINCE_PM = 0 AND U_DONE < PM_COMPLETION_PROB, 1, 0) AS PM_COMPLETED,
         -- Optics and fluidics drift between PM visits; weak PM discipline carries it over.
         DAYS_SINCE_PM / PM_INTERVAL_DAYS + (1 - PM_COMPLETION_PROB) AS DRIFT
  FROM base
), activity AS (
  SELECT *,
         CASE WHEN U_FAIL < LEAST(0.5, BASE_FAIL_RATE * (0.4 + 1.6 * DRIFT) * (1 + INSTRUMENT_AGE_YEARS / 6)) / 4 THEN 2
              WHEN U_FAIL < LEAST(0.5, BASE_FAIL_RATE * (0.4 + 1.6 * DRIFT) * (1 + INSTRUMENT_AGE_YEARS / 6)) THEN 1
              ELSE 0 END AS FAIL_COUNT
  FROM pm
), flags AS (
  SELECT *,
         -- Run QC catches about 85% of failed runs; the rest is found downstream.
         IFF(LOT_HOLD, 0, IFF(U_DETECT < 0.85, FAIL_COUNT, 0)) AS QC_FAIL_COUNT,
         -- QC flags that pass on review: higher for high-multiplex assays.
         IFF(LOT_HOLD, 1, IFF(U_FP < CASE CATEGORY WHEN 'Targeted Panel' THEN 0.18
                                                   WHEN 'Pathogen Surveillance' THEN 0.14
                                                   WHEN 'RNA-Seq' THEN 0.12
                                                   WHEN 'Whole Exome' THEN 0.10 ELSE 0.08 END, 1, 0)) AS PASSED_REVIEW_COUNT
  FROM activity
), measured AS (
  SELECT *,
         QC_FAIL_COUNT + PASSED_REVIEW_COUNT AS QC_FLAG_COUNT,
         ROUND(CASE CATEGORY WHEN 'Whole Genome' THEN 24 WHEN 'Whole Exome' THEN 48
                             WHEN 'Targeted Panel' THEN 96 WHEN 'RNA-Seq' THEN 36 ELSE 64 END
               * SIZE_FACTOR * (0.7 + 0.6 * U_SAMPLES) * IFF(LOT_HOLD, 0.3, 1)) AS SAMPLE_COUNT,
         ROUND(DAILY_TARGET_GB * (0.82 + 0.3 * U_NOISE) * (1 - 0.25 * FAIL_COUNT) * IFF(LOT_HOLD, 0.3, 1), 1) AS GB_OUTPUT
  FROM flags
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       SAMPLE_COUNT,
       GB_OUTPUT,
       DAILY_TARGET_GB AS GB_TARGET,
       QC_FLAG_COUNT, QC_FAIL_COUNT,
       IFF(QC_FAIL_COUNT > 0 AND U_RERUN < 0.6, 1, 0) AS RERUN_COUNT,
       CASE WHEN QC_FLAG_COUNT = 0 THEN 'None'
            WHEN LOT_HOLD THEN 'Reagent lot hold'
            WHEN CATEGORY = 'Whole Genome' THEN IFF(U_MODE < 0.5, 'Low cluster density', IFF(U_MODE < 0.8, 'Phasing drift', 'Flow cell defect'))
            WHEN CATEGORY = 'Whole Exome' THEN IFF(U_MODE < 0.55, 'Low on-target rate', 'Library under-loading')
            WHEN CATEGORY = 'Targeted Panel' THEN IFF(U_MODE < 0.45, 'Index hopping', IFF(U_MODE < 0.8, 'Low coverage uniformity', 'Primer dimers'))
            WHEN CATEGORY = 'RNA-Seq' THEN IFF(U_MODE < 0.5, 'rRNA carry-over', 'Low input quality')
            ELSE IFF(U_MODE < 0.4, 'Low read depth', IFF(U_MODE < 0.75, 'Phasing drift', 'Flow cell defect')) END AS FAILURE_MODE,
       PM_DUE, PM_COMPLETED,
       ROUND(0.5 + 2.0 * DRIFT + 3.0 * FAIL_COUNT + U_NOISE * 0.8, 2) AS PHASING_PCT,
       ROUND(4 + 3 * DRIFT + 6 * FAIL_COUNT + U_NOISE * 2, 1) AS LOW_Q30_TILE_PCT,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM measured;

-- Reagent kit coverage per instrument (snapshot).
CREATE TABLE RAW.REAGENT_KITS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Whole Genome' THEN 'WGS library prep kit' WHEN 'Whole Exome' THEN 'Exome capture kit'
                     WHEN 'Targeted Panel' THEN 'Panel amplicon kit' WHEN 'RNA-Seq' THEN 'RNA library prep kit'
                     ELSE 'Pathogen enrichment kit' END AS KIT_TYPE,
       1 + MOD(ABS(HASH(ID, 'sg-req')), 4) AS REQUIRED_QTY,
       MOD(ABS(HASH(ID, 'sg-hand')), 5) AS ON_HAND_QTY,
       IFF(MOD(ABS(HASH(ID, 'sg-hand')), 5) < 1 + MOD(ABS(HASH(ID, 'sg-req')), 4),
           MOD(ABS(HASH(ID, 'sg-order')), 3), 0) AS ON_ORDER_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.SEQUENCERS;
