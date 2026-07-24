-- FIXED (RS003 + RS009) - JSON ->> dot-notation -> Snowflake VARIANT path col:key::string.
-- Captured error: syntax error at ''instrument_id'' / ''batch_number'' / ''lab_location''.
-- Dependency order (RS009): LAB_RESULTS, PATIENTS, VISITS must exist first.
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
    lr.RAW_RESULT:instrument_id::string AS INSTRUMENT_ID,
    lr.RAW_RESULT:batch_number::string  AS BATCH_NUMBER,
    lr.RAW_RESULT:lab_location::string  AS LAB_LOCATION,
    lr.NOTES
FROM AZ_CLINICAL.LAB_RESULTS lr
JOIN AZ_CLINICAL.PATIENTS p ON lr.PATIENT_ID = p.PATIENT_ID
JOIN AZ_CLINICAL.VISITS v   ON lr.VISIT_ID = v.VISIT_ID;
