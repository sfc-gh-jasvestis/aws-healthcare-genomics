-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-run alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes validated __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_RUNS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic run-QC troubleshooting knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.QC_SOP_DOCS AS
WITH modes AS (
  SELECT DISTINCT r.FAILURE_MODE, s.CATEGORY
  FROM RAW.SEQUENCER_DAILY r JOIN RAW.SEQUENCERS s ON s.ID = r.ENTITY_ID
  WHERE r.QC_FAIL_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, FAILURE_MODE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  FAILURE_MODE,
  CATEGORY || ' - ' || FAILURE_MODE || ' run QC troubleshooting' AS TITLE,
  'Synthetic demo SOP for research sequencing operations. Assay: ' || CATEGORY || '. Failure mode: ' || FAILURE_MODE || '. '
  || 'Step 1: hold the run data from release, mark the run as QC failed in the LIMS and notify the lab supervisor within 4 working hours. '
  || 'Step 2: ' || CASE
       WHEN FAILURE_MODE = 'Low cluster density' THEN 'check library quantification and the loading concentration against the flow cell specification, then re-quantify the pool before reloading.'
       WHEN FAILURE_MODE = 'Phasing drift' THEN 'review phasing and prephasing trends over recent runs, inspect fluidics for bubbles or leaks, and book a preventive maintenance visit if drift persists.'
       WHEN FAILURE_MODE = 'Flow cell defect' THEN 'image the flow cell surface, record the lot number, quarantine remaining flow cells from the same lot and raise a supplier complaint.'
       WHEN FAILURE_MODE = 'Low on-target rate' THEN 'check hybridisation temperature and time, bait lot and post-capture yield, and compare with the last passing exome batch.'
       WHEN FAILURE_MODE = 'Library under-loading' THEN 'repeat fragment-size and concentration checks on the pooled library and recalculate the molarity used for loading.'
       WHEN FAILURE_MODE = 'Index hopping' THEN 'confirm unique dual indexes were used, check free adapter carry-over and review the demultiplexing report for unexpected index pairs.'
       WHEN FAILURE_MODE = 'Low coverage uniformity' THEN 'review amplicon coverage by region, check PCR cycle number and input amount, and rebalance the primer pool if the same regions drop out.'
       WHEN FAILURE_MODE = 'Primer dimers' THEN 'inspect the fragment profile for a dimer peak, repeat bead clean-up at the specified ratio and check primer storage.'
       WHEN FAILURE_MODE = 'rRNA carry-over' THEN 'check the ribosomal depletion step and reagent lot, and compare the rRNA read fraction with the last passing batch.'
       WHEN FAILURE_MODE = 'Low input quality' THEN 'review input RNA integrity and quantity records for the batch and repeat library preparation from fresh material where available.'
       WHEN FAILURE_MODE = 'Low read depth' THEN 'compare reads per sample with the target, check pooling balance and library concentration, and top up the run if the instrument allows.'
       ELSE 'review the run metrics against the assay acceptance criteria and escalate if unexplained.'
     END
  || ' Step 3: if phasing exceeds 5% or more than 10% of tiles fall below Q30, keep the run on hold and repeat the instrument performance check before the next run. '
  || 'Step 4: record the outcome and corrective action; if the failure is confirmed, re-queue the affected libraries, with sign-off from the lab supervisor.' AS CONTENT
FROM modes;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.QC_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, FAILURE_MODE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, FAILURE_MODE, CONTENT FROM SEARCH.QC_SOP_DOCS);

-- ---------- Phasing anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.PHASING_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, PHASING_PCT::FLOAT AS PHASING
FROM RAW.SEQUENCER_DAILY;
CREATE OR REPLACE VIEW ML.PHASING_TRAIN AS
SELECT * FROM ML.PHASING_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.PHASING_SERIES);
CREATE OR REPLACE VIEW ML.PHASING_DETECT AS
SELECT * FROM ML.PHASING_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.PHASING_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.PHASING_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.PHASING_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'PHASING',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.PHASING_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS PHASING, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.PHASING_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.PHASING_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'PHASING'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.SEQUENCING_ANALYTICS
  TABLES (
    instruments AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      COMMENT = 'One row per sequencer (lab site x assay), 90-day totals',
    risk AS ML.QC_FAIL_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day failed-run probability per sequencer',
    modes AS CURATED.FAILURE_MODE_SUMMARY PRIMARY KEY (FAILURE_MODE)
      COMMENT = 'QC flags, confirmed failed runs and re-queued runs by failure mode, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Network-wide totals per day'
  )
  RELATIONSHIPS (risk_instrument AS risk (ENTITY_ID) REFERENCES instruments)
  FACTS (
    instruments.samples_f AS SAMPLE_COUNT,
    instruments.gb_out_f AS GB_OUTPUT,
    instruments.gb_target_f AS GB_TARGET,
    instruments.flags_f AS QC_FLAG_COUNT,
    instruments.fails_f AS QC_FAIL_COUNT,
    instruments.reruns_f AS RERUN_COUNT,
    instruments.pm_due_f AS PM_DUE,
    instruments.pm_done_f AS PM_COMPLETED,
    risk.fail_prob_f AS FAIL_PROB_7D,
    modes.mode_flags_f AS QC_FLAG_COUNT,
    modes.mode_fails_f AS QC_FAIL_COUNT,
    modes.mode_reruns_f AS RERUN_COUNT,
    daily.day_samples_f AS SAMPLE_COUNT,
    daily.day_gb_out_f AS GB_OUTPUT,
    daily.day_gb_target_f AS GB_TARGET,
    daily.day_flags_f AS QC_FLAG_COUNT
  )
  DIMENSIONS (
    instruments.sequencer_id AS ENTITY_ID WITH SYNONYMS = ('sequencer', 'instrument', 'entity', 'entities'),
    instruments.sequencer_name AS ENTITY_NAME,
    instruments.lab_site AS REGION WITH SYNONYMS = ('site', 'planning area', 'region', 'lab') COMMENT = 'Singapore lab site (planning area) where the sequencer runs',
    instruments.assay AS CATEGORY WITH SYNONYMS = ('assay', 'assay line', 'application'),
    instruments.utilisation_tier AS UTILISATION_TIER COMMENT = 'Utilisation tier 1 (low) to 3 (high)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    modes.failure_mode AS FAILURE_MODE WITH SYNONYMS = ('failure type', 'QC issue', 'root cause'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    instruments.sequencer_count AS COUNT(instruments.sequencer_id) WITH SYNONYMS = ('number of sequencers', 'number of entities', 'instrument count'),
    instruments.net_yield_attainment_pct AS 100 * SUM(instruments.gb_out_f) / NULLIF(SUM(instruments.gb_target_f), 0)
      COMMENT = 'Data output (GB) / target output (GB)',
    instruments.samples_sequenced AS SUM(instruments.samples_f) WITH SYNONYMS = ('samples', 'sample volume'),
    instruments.total_gb_output AS SUM(instruments.gb_out_f) WITH SYNONYMS = ('data output', 'gigabases'),
    instruments.total_gb_target AS SUM(instruments.gb_target_f) WITH SYNONYMS = ('target output'),
    instruments.qc_flags AS SUM(instruments.flags_f) WITH SYNONYMS = ('flagged runs', 'QC alerts'),
    instruments.confirmed_failed_runs AS SUM(instruments.fails_f) WITH SYNONYMS = ('failed runs', 'QC failures'),
    instruments.runs_requeued AS SUM(instruments.reruns_f) WITH SYNONYMS = ('reruns', 're-queued runs'),
    instruments.net_flag_precision_pct AS 100 * SUM(instruments.fails_f) / NULLIF(SUM(instruments.flags_f), 0)
      COMMENT = 'Confirmed failed runs / QC flags',
    instruments.net_pm_compliance_pct AS 100 * SUM(instruments.pm_done_f) / NULLIF(SUM(instruments.pm_due_f), 0)
      COMMENT = 'Preventive maintenance visits completed / visits due',
    risk.avg_fail_prob AS AVG(risk.fail_prob_f),
    modes.mode_flags AS SUM(modes.mode_flags_f),
    modes.mode_failed_runs AS SUM(modes.mode_fails_f),
    modes.mode_requeued AS SUM(modes.mode_reruns_f),
    modes.mode_precision_pct AS 100 * SUM(modes.mode_fails_f) / NULLIF(SUM(modes.mode_flags_f), 0),
    daily.daily_samples AS SUM(daily.day_samples_f),
    daily.daily_gb_output AS SUM(daily.day_gb_out_f),
    daily.daily_yield_pct AS 100 * SUM(daily.day_gb_out_f) / NULLIF(SUM(daily.day_gb_target_f), 0),
    daily.daily_flags AS SUM(daily.day_flags_f)
  )
  COMMENT = 'Synthetic Singapore research sequencing lab operations analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.SEQUENCING_AGENT
  COMMENT = 'Sequencing operations assistant over a synthetic Singapore research lab network'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give sequencer IDs and numbers with units. Do not give clinical or diagnostic advice."
  orchestration: "Use sequencing_analyst for sequencer counts, samples sequenced, data output, yield attainment, QC flags, confirmed failed runs, re-queued runs, preventive maintenance, lab sites, assays, failure modes and failed-run risk. Use sop_search for run QC troubleshooting procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: sequencing_analyst
      description: "Sequencer count, samples sequenced, data output (GB), yield attainment, QC flags, confirmed failed runs, re-queued runs, flag precision, PM compliance, failure modes and failed-run risk scores by sequencer"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic run QC troubleshooting SOPs by assay and failure mode"
tool_resources:
  sequencing_analyst:
    semantic_view: __DEMO_DB__.APP.SEQUENCING_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.QC_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-run alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), SEQUENCER_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, GB_OUTPUT FLOAT, PHASING_PCT FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION SG_HEALTHCARE_GENOMICS_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_FLAGS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (SEQUENCER_ID, EVENT_TS, GB_OUTPUT, PHASING_PCT, SOP_HINT)
    SELECT c.SEQUENCER_ID, c.EVENT_TS, c.GB_OUTPUT, c.PHASING_PCT,
           'Check ' || b.CATEGORY || ' run QC troubleshooting SOPs; current risk band ' || COALESCE(r.RISK_BAND, 'n/a')
    FROM RAW.LIVE_RUNS c
    JOIN RAW.SEQUENCERS b ON b.ID = c.SEQUENCER_ID
    LEFT JOIN ML.QC_FAIL_SCORES r ON r.ENTITY_ID = c.SEQUENCER_ID
    WHERE c.STATUS = 'QC_FLAG'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.SEQUENCER_ID = c.SEQUENCER_ID AND l.EVENT_TS = c.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('SG_HEALTHCARE_GENOMICS_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Sequencer run QC flag alert',
      'New live run QC flags logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_RUN_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_RUNS c
    WHERE c.STATUS = 'QC_FLAG'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.SEQUENCER_ID = c.SEQUENCER_ID AND l.EVENT_TS = c.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_FLAGS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.FAILURE_MODE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.QC_FAIL_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.QC_FAIL_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.QC_FAIL_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'UTILISATION_TIER', UTILISATION_TIER, 'INSTRUMENT_AGE_YEARS', INSTRUMENT_AGE_YEARS,
             'PHASING_PCT', PHASING_PCT, 'LOW_Q30_TILE_PCT', LOW_Q30_TILE_PCT,
             'PHASING_7D', PHASING_7D, 'FAILS_30D', FAILS_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:FAIL::FLOAT, 4) AS FAIL_PROB_7D,
         CASE WHEN PRED:probability:FAIL::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:FAIL::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
