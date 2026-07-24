-- =====================================================================
-- SnowConvert output (SIMULATED) - FAILS ON EXECUTION IN SNOWFLAKE
-- Object:         AZ_CLINICAL.MONTHLY_ROLLUP
-- Source:         source_postgres/procedures/01_monthly_rollup.sql
-- Failure class:  Procedural logic (cursor FOR..LOOP, RECORD, ::cast) not valid Snowflake Scripting
-- Expected error: SQL compilation error: syntax error at 'RECORD' / '::' / FOR..IN..LOOP body
-- Fix rule:       RS007 (rewrite plpgsql cursor loop to Snowflake Scripting or set-based INSERT)
-- =====================================================================
CREATE OR REPLACE PROCEDURE AZ_CLINICAL.MONTHLY_ROLLUP()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    rec RECORD;
BEGIN
    CREATE TABLE IF NOT EXISTS AZ_CLINICAL.MONTHLY_LAB_ROLLUP (
        SITE_ID INTEGER,
        SITE_CODE VARCHAR(20),
        MONTH DATE,
        TEST_CODE VARCHAR(20),
        RESULT_COUNT INTEGER,
        MIN_VALUE NUMBER,
        MAX_VALUE NUMBER,
        AVG_VALUE NUMBER,
        ROLLED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );

    TRUNCATE TABLE AZ_CLINICAL.MONTHLY_LAB_ROLLUP;

    FOR rec IN
        SELECT
            s.SITE_ID,
            s.SITE_CODE,
            date_trunc('month', lr.COLLECTED_AT)::date AS MONTH,
            lr.TEST_CODE,
            COUNT(*) AS RESULT_COUNT,
            MIN(lr.RESULT_VALUE::numeric) AS MIN_VALUE,
            MAX(lr.RESULT_VALUE::numeric) AS MAX_VALUE,
            AVG(lr.RESULT_VALUE::numeric) AS AVG_VALUE
        FROM AZ_CLINICAL.LAB_RESULTS lr
        JOIN AZ_CLINICAL.PATIENTS p ON lr.PATIENT_ID = p.PATIENT_ID
        JOIN AZ_CLINICAL.TRIAL_SITES s ON p.SITE_ID = s.SITE_ID
        WHERE lr.RESULT_STATUS = 'Final'
        GROUP BY s.SITE_ID, s.SITE_CODE, date_trunc('month', lr.COLLECTED_AT)::date, lr.TEST_CODE
    LOOP
        INSERT INTO AZ_CLINICAL.MONTHLY_LAB_ROLLUP
        VALUES (rec.SITE_ID, rec.SITE_CODE, rec.MONTH, rec.TEST_CODE, rec.RESULT_COUNT, rec.MIN_VALUE, rec.MAX_VALUE, rec.AVG_VALUE, CURRENT_TIMESTAMP());
    END LOOP;

    RETURN 'OK';
END;
$$;
