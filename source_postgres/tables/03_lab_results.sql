-- Lab results table.
-- Redshift equivalent would include: DISTKEY(patient_id), SORTKEY(collected_at), ENCODE LZO for varchar columns.
CREATE TABLE IF NOT EXISTS az_clinical.lab_results (
    result_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id INTEGER NOT NULL,
    visit_id VARCHAR(20) NOT NULL,
    test_code VARCHAR(20) NOT NULL,
    test_name VARCHAR(50) NOT NULL,
    result_value VARCHAR(50) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    reference_range VARCHAR(50),
    collected_at TIMESTAMP NOT NULL,
    received_at TIMESTAMP,
    result_status VARCHAR(20) NOT NULL CHECK (result_status IN ('Final', 'Preliminary', 'Cancelled', 'Corrected')),
    notes VARCHAR(255),  -- intentional null/space issue
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE az_clinical.lab_results IS 'Redshift stand-in: DISTKEY(patient_id), SORTKEY(collected_at), ENCODE LZO for varchar columns.';
