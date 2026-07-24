-- =====================================================================
-- SnowConvert output (SIMULATED) - FAILS ON EXECUTION IN SNOWFLAKE
-- Object:         AZ_CLINICAL.LAB_RESULTS_WITH_METADATA
-- Source:         source_postgres/views/02_lab_results_with_metadata.sql
-- Failure class:  JSON/SUPER dot-notation carried over from Postgres/Redshift
-- Expected error: SQL compilation error: syntax error line ... at '->>'
-- Fix rule:       RS003 (rewrite ->> access to Snowflake VARIANT path col:key::string)
-- Depends on:     LAB_RESULTS, PATIENTS, VISITS created first (RS009)
-- =====================================================================
CREATE OR REPLACE VIEW AZ_CLINICAL.LAB_RESULTS_WITH_METADATA AS
SELECT
    lr.RESULT_ID,
    lr.PATIENT_ID,
    p.SUBJECT_NUMBER,
    v.VISIT_CODE,
    lr.TEST_CODE,
    lr.TEST_NAME,
    lr.RESULT_VALUE,
    lr.UNIT,
    lr.REFERENCE_RANGE,
    lr.RESULT_STATUS,
    lr.COLLECTED_AT,
    lr.RAW_RESULT->>'instrument_id' AS INSTRUMENT_ID,
    lr.RAW_RESULT->>'batch_number'  AS BATCH_NUMBER,
    lr.RAW_RESULT->>'lab_location'  AS LAB_LOCATION,
    lr.NOTES
FROM AZ_CLINICAL.LAB_RESULTS lr
JOIN AZ_CLINICAL.PATIENTS p ON lr.PATIENT_ID = p.PATIENT_ID
JOIN AZ_CLINICAL.VISITS v   ON lr.VISIT_ID = v.VISIT_ID;
