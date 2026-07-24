-- Active enrollment view: patients enrolled in the last 6 months who are still active.
-- Uses JSONB access syntax (stratification->>'region') that mirrors Redshift SUPER dot-notation failures.
CREATE OR REPLACE VIEW az_clinical.active_enrollment AS
SELECT
    p.patient_id,
    p.subject_number,
    p.initials,
    d.date_of_birth,
    d.sex,
    d.race,
    d.ethnicity,
    p.enrollment_date,
    p.randomization_date,
    p.stratification->>'region' AS stratification_region,
    p.stratification->>'site_size' AS stratification_site_size,
    s.site_code,
    s.site_name,
    s.country,
    st.study_code,
    st.study_name
FROM az_clinical.patients p
JOIN az_clinical.demographics d ON p.patient_id = d.patient_id
JOIN az_clinical.trial_sites s ON p.site_id = s.site_id
JOIN az_clinical.studies st ON p.study_id = st.study_id
WHERE p.status = 'Active'
  AND p.enrollment_date >= CURRENT_DATE - INTERVAL '6 months';
