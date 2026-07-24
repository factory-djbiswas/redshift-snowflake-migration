-- =====================================================================
-- SnowConvert output (SIMULATED) - FAILS ON EXECUTION IN SNOWFLAKE
-- Object:         AZ_CLINICAL.SCREENING_ENROLLMENT_REPORT
-- Source:         source_postgres/procedures/02_screening_enrollment_report.sql
-- Failure class:  Procedural logic + aggregate FILTER clause + RAISE/EXCEPTION handling
-- Expected error: SQL compilation error: syntax error at 'FILTER' (also RECORD / RAISE NOTICE)
-- Fix rules:      RS007 (cursor/exception rewrite), RS012 (COUNT(*) FILTER (WHERE ..) -> COUNT_IF / CASE)
-- =====================================================================
CREATE OR REPLACE PROCEDURE AZ_CLINICAL.SCREENING_ENROLLMENT_REPORT()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    rec RECORD;
    v_total_screened INTEGER;
    v_total_enrolled INTEGER;
BEGIN
    CREATE TEMP TABLE IF NOT EXISTS tmp_screening_enrollment AS
    SELECT
        s.SITE_ID,
        s.SITE_CODE,
        s.SITE_NAME,
        date_trunc('month', p.SCREENING_DATE)::date AS MONTH,
        COUNT(*) FILTER (WHERE p.STATUS IN ('Screening', 'Screen Failed')) AS SCREENED_COUNT,
        COUNT(*) FILTER (WHERE p.STATUS IN ('Active', 'Completed', 'Withdrawn')) AS ENROLLED_COUNT
    FROM AZ_CLINICAL.PATIENTS p
    JOIN AZ_CLINICAL.TRIAL_SITES s ON p.SITE_ID = s.SITE_ID
    WHERE p.SCREENING_DATE IS NOT NULL
    GROUP BY s.SITE_ID, s.SITE_CODE, s.SITE_NAME, date_trunc('month', p.SCREENING_DATE)::date;

    CREATE TABLE IF NOT EXISTS AZ_CLINICAL.SCREENING_ENROLLMENT_SUMMARY (
        SITE_ID INTEGER,
        SITE_CODE VARCHAR(20),
        SITE_NAME VARCHAR(200),
        MONTH DATE,
        SCREENED_COUNT INTEGER,
        ENROLLED_COUNT INTEGER,
        CONVERSION_RATE NUMBER(5,2),
        GENERATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );

    TRUNCATE TABLE AZ_CLINICAL.SCREENING_ENROLLMENT_SUMMARY;

    SELECT COUNT(*) INTO v_total_screened FROM AZ_CLINICAL.PATIENTS WHERE SCREENING_DATE IS NOT NULL;
    SELECT COUNT(*) INTO v_total_enrolled FROM AZ_CLINICAL.PATIENTS WHERE STATUS IN ('Active', 'Completed');

    IF v_total_screened = 0 THEN
        RAISE EXCEPTION 'No screened patients found; cannot generate report.';
    END IF;

    FOR rec IN SELECT * FROM tmp_screening_enrollment LOOP
        BEGIN
            INSERT INTO AZ_CLINICAL.SCREENING_ENROLLMENT_SUMMARY
                (SITE_ID, SITE_CODE, SITE_NAME, MONTH, SCREENED_COUNT, ENROLLED_COUNT, CONVERSION_RATE, GENERATED_AT)
            VALUES (
                rec.SITE_ID,
                rec.SITE_CODE,
                rec.SITE_NAME,
                rec.MONTH,
                rec.SCREENED_COUNT,
                rec.ENROLLED_COUNT,
                CASE
                    WHEN rec.SCREENED_COUNT = 0 THEN 0
                    ELSE ROUND((rec.ENROLLED_COUNT::numeric / rec.SCREENED_COUNT) * 100, 2)
                END,
                CURRENT_TIMESTAMP()
            );
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Error processing site %: %', rec.SITE_CODE, SQLERRM;
        END;
    END LOOP;

    DROP TABLE IF EXISTS tmp_screening_enrollment;
    RETURN 'OK';
END;
$$;
