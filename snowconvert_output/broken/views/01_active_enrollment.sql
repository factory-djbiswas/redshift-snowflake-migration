-- =====================================================================
-- SnowConvert output (SIMULATED) - FAILS ON EXECUTION IN SNOWFLAKE
-- Object:         AZ_CLINICAL.ACTIVE_ENROLLMENT
-- Source:         source_postgres/views/01_active_enrollment.sql
-- Failure class:  JSON/SUPER dot-notation carried over from Postgres/Redshift
-- Expected error: SQL compilation error: syntax error line ... at '->>'
-- Fix rule:       RS003 (rewrite ->> access to Snowflake VARIANT path col:key::string)
-- Depends on:     STUDIES, PATIENTS, DEMOGRAPHICS, TRIAL_SITES created first (RS009)
-- =====================================================================
CREATE OR REPLACE VIEW AZ_CLINICAL.ACTIVE_ENROLLMENT AS
SELECT
    p.PATIENT_ID,
    p.SUBJECT_NUMBER,
    p.INITIALS,
    d.DATE_OF_BIRTH,
    d.SEX,
    d.RACE,
    d.ETHNICITY,
    p.ENROLLMENT_DATE,
    p.RANDOMIZATION_DATE,
    p.STRATIFICATION->>'region'    AS STRATIFICATION_REGION,
    p.STRATIFICATION->>'site_size' AS STRATIFICATION_SITE_SIZE,
    s.SITE_CODE,
    s.SITE_NAME,
    s.COUNTRY,
    st.STUDY_CODE,
    st.STUDY_NAME
FROM AZ_CLINICAL.PATIENTS p
JOIN AZ_CLINICAL.DEMOGRAPHICS d ON p.PATIENT_ID = d.PATIENT_ID
JOIN AZ_CLINICAL.TRIAL_SITES s  ON p.SITE_ID = s.SITE_ID
JOIN AZ_CLINICAL.STUDIES st     ON p.STUDY_ID = st.STUDY_ID
WHERE p.STATUS = 'Active'
  AND p.ENROLLMENT_DATE >= DATEADD('month', -6, CURRENT_DATE());
