-- Re-randomize VARIANTS clinical significance with realistic per-gene skew.
-- BRCA1, BRCA2, TP53 are well-known cancer drivers with high pathogenic rates.
-- Other genes follow a tiered distribution from 5% to ~25% pathogenic.
-- Hash-based deterministic randomness so reruns are stable.

USE SCHEMA HEALTHCARE_GENOMICS.RAW;

CREATE OR REPLACE TABLE VARIANTS AS
WITH g AS (SELECT *, ABS(HASH(VARIANT_ID, 'sig')) % 1000 AS r FROM VARIANTS)
SELECT
  VARIANT_ID, PATIENT_ID, GENE, CHROMOSOME, POSITION, REF_ALLELE, ALT_ALLELE, VARIANT_TYPE, CONSEQUENCE, ALLELE_FREQUENCY,
  CASE
    WHEN GENE = 'BRCA1' THEN
      CASE WHEN r < 320 THEN 'Pathogenic' WHEN r < 420 THEN 'Likely Pathogenic'
           WHEN r < 580 THEN 'VUS'        WHEN r < 800 THEN 'Likely Benign' ELSE 'Benign' END
    WHEN GENE IN ('TP53','BRCA2') THEN
      CASE WHEN r < 250 THEN 'Pathogenic' WHEN r < 360 THEN 'Likely Pathogenic'
           WHEN r < 540 THEN 'VUS'        WHEN r < 770 THEN 'Likely Benign' ELSE 'Benign' END
    WHEN GENE IN ('APC','PIK3CA','EGFR','KRAS') THEN
      CASE WHEN r < 180 THEN 'Pathogenic' WHEN r < 280 THEN 'Likely Pathogenic'
           WHEN r < 500 THEN 'VUS'        WHEN r < 750 THEN 'Likely Benign' ELSE 'Benign' END
    WHEN GENE IN ('MLH1','MSH2','VHL','HER2','BRAF','MET') THEN
      CASE WHEN r < 130 THEN 'Pathogenic' WHEN r < 220 THEN 'Likely Pathogenic'
           WHEN r < 460 THEN 'VUS'        WHEN r < 730 THEN 'Likely Benign' ELSE 'Benign' END
    WHEN GENE IN ('FLT3','ROS1','CDH1','PTEN','NTRK1') THEN
      CASE WHEN r < 90  THEN 'Pathogenic' WHEN r < 170 THEN 'Likely Pathogenic'
           WHEN r < 420 THEN 'VUS'        WHEN r < 700 THEN 'Likely Benign' ELSE 'Benign' END
    ELSE
      CASE WHEN r < 50  THEN 'Pathogenic' WHEN r < 120 THEN 'Likely Pathogenic'
           WHEN r < 380 THEN 'VUS'        WHEN r < 670 THEN 'Likely Benign' ELSE 'Benign' END
  END AS CLINICAL_SIGNIFICANCE,
  ZYGOSITY, DEPTH
FROM g;

-- Recreate downstream dynamic table to pick up new RAW data (CREATE OR REPLACE breaks change tracking)
USE SCHEMA HEALTHCARE_GENOMICS.CURATED;
ALTER DYNAMIC TABLE VARIANT_SUMMARY REFRESH;
