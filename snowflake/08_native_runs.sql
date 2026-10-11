-- ============================================================================
-- 08_native_runs.sql - Snowflake-only build: live run feed without AWS.
-- Creates RAW.LIVE_RUNS (same columns as the Snowpipe target created by
-- aws/setup_aws.py) and APP.SIMULATE_RUNS(N), which inserts synthetic
-- run-completion summaries (instrument, data output, phasing) with the same value
-- ranges and ~10% QC_FLAG rate as aws/publish_runs.py. Rows are inserted directly; this
-- simulates a sequencer run-summary feed and is not Snowpipe Streaming.
-- Run before 06_intelligence.sql (the alert reads RAW.LIVE_RUNS).
-- Idempotent: safe to run in the AWS build too.
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS APP;

CREATE TABLE IF NOT EXISTS RAW.LIVE_RUNS (
  SEQUENCER_ID VARCHAR, EVENT_TS TIMESTAMP_NTZ, GB_OUTPUT FLOAT, PHASING_PCT FLOAT,
  STATUS VARCHAR, SENT_TS TIMESTAMP_NTZ, SOURCE_FILE VARCHAR,
  LOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());

CREATE OR REPLACE PROCEDURE APP.SIMULATE_RUNS(N NUMBER)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  IF (N < 1 OR N > 1000) THEN
    RETURN 0;
  END IF;
  INSERT INTO RAW.LIVE_RUNS (SEQUENCER_ID, EVENT_TS, GB_OUTPUT, PHASING_PCT, STATUS, SENT_TS, SOURCE_FILE)
    WITH g AS (
      SELECT 'SQ-' || LPAD(UNIFORM(0, 39, RANDOM())::VARCHAR, 4, '0') AS SEQUENCER_ID,
             UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.1 AS IS_FLAG,
             SYSDATE() AS TS, SEQ4() AS I
      FROM TABLE(GENERATOR(ROWCOUNT => 1000))
    )
    -- NORMAL() needs a constant mean, so the QC-flag offset is added outside it.
    SELECT SEQUENCER_ID, TS,
           ROUND(IFF(IS_FLAG, 40, 120) * EXP(NORMAL(0, 0.3, RANDOM())), 1),
           ROUND(GREATEST(0, IFF(IS_FLAG, 7.5, 1.2) + NORMAL(0, 0.8, RANDOM())), 2),
           IFF(IS_FLAG, 'QC_FLAG', 'PASS'), TS, 'APP.SIMULATE_RUNS'
    FROM g
    WHERE I < :N;
  RETURN SQLROWCOUNT;
END;
$$;

-- Optional continuous feed for longer demos (suspended; RESUME to start, SUSPEND after).
CREATE OR REPLACE TASK APP.TASK_SIMULATE_RUNS
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '1 MINUTE'
AS
  CALL APP.SIMULATE_RUNS(5);
