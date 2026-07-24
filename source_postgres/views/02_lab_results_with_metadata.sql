-- Lab results enriched with raw JSON metadata.
-- Uses JSONB dot-notation (raw_result->>'instrument_id', raw_result->>'batch_number')
-- which is a classic Redshift SUPER -> Snowflake VARIANT conversion failure pattern.
CREATE OR REPLACE VIEW az_clinical.lab_results_with_metadata AS
SELECT
    lr.result_id,
    lr.patient_id,
    p.subject_number,
    v.visit_code,
    lr.test_code,
    lr.test_name,
    lr.result_value,
    lr.unit,
    lr.reference_range,
    lr.result_status,
    lr.collected_at,
    lr.raw_result->>'instrument_id' AS instrument_id,
    lr.raw_result->>'batch_number' AS batch_number,
    lr.raw_result->>'lab_location' AS lab_location,
    lr.notes
FROM az_clinical.lab_results lr
JOIN az_clinical.patients p ON lr.patient_id = p.patient_id
JOIN az_clinical.visits v ON lr.visit_id = v.visit_id;
