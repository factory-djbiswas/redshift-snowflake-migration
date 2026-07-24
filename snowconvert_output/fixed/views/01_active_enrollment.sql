-- FIXED (RS003 + RS009) - JSON ->> dot-notation -> Snowflake VARIANT path col:key::string.
-- Captured error: syntax error at ''region'' / ''site_size'' (the ->> operator does not exist in Snowflake).
-- Dependency order (RS009): PATIENTS, DEMOGRAPHICS, TRIAL_SITES, STUDIES must exist first.
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
    p.STRATIFICATION:region::string    AS STRATIFICATION_REGION,
    p.STRATIFICATION:site_size::string AS STRATIFICATION_SITE_SIZE,
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
