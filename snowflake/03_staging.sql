-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.SEQUENCER_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.SEQUENCER_DAILY observation
    LEFT JOIN RAW.SEQUENCERS seq ON seq.ID = observation.ENTITY_ID
    WHERE seq.ID IS NULL OR observation.SAMPLE_COUNT < 0
       OR observation.GB_OUTPUT < 0 OR observation.GB_TARGET <= 0
       OR observation.QC_FAIL_COUNT < 0 OR observation.QC_FAIL_COUNT > observation.QC_FLAG_COUNT
       OR observation.RERUN_COUNT > observation.QC_FAIL_COUNT
       OR observation.PM_COMPLETED > observation.PM_DUE
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
