-- Visit-level and clinical-result tables.

CREATE TABLE az_clinical.visits (
    visit_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES az_clinical.patients(patient_id),
    window_id INTEGER REFERENCES az_clinical.visit_windows(window_id),
    visit_code VARCHAR(20) NOT NULL,
    visit_name VARCHAR(100) NOT NULL,
    scheduled_date DATE NOT NULL,
    actual_date DATE,
    status az_clinical.visit_status NOT NULL DEFAULT 'Scheduled',
    -- Timezone-aware timestamp is a deliberate SnowConvert pain point (TIMESTAMP vs TIMESTAMP_TZ).
    visit_start_at TIMESTAMP WITH TIME ZONE,
    visit_end_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(patient_id, visit_code)
);
COMMENT ON TABLE az_clinical.visits IS 'Redshift stand-in: DISTKEY(patient_id), SORTKEY(actual_date), ENCODE LZO for visit_code.';

CREATE TABLE az_clinical.vital_signs (
    vital_sign_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    visit_id INTEGER NOT NULL REFERENCES az_clinical.visits(visit_id),
    patient_id INTEGER NOT NULL REFERENCES az_clinical.patients(patient_id),
    systolic_bp INTEGER CHECK (systolic_bp BETWEEN 50 AND 300),
    diastolic_bp INTEGER CHECK (diastolic_bp BETWEEN 30 AND 200),
    heart_rate INTEGER CHECK (heart_rate BETWEEN 30 AND 220),
    respiratory_rate INTEGER CHECK (respiratory_rate BETWEEN 5 AND 60),
    temperature_celsius NUMERIC(4,1),
    weight_kg NUMERIC(5,2),
    -- Array of abnormal flag strings; another SnowConvert pain point.
    abnormal_flags TEXT[],
    notes VARCHAR(255),  -- intentional null/space issue
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE az_clinical.vital_signs IS 'Redshift stand-in: DISTKEY(patient_id), SORTKEY(vital_sign_id).';

CREATE TABLE az_clinical.lab_results (
    result_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    visit_id INTEGER NOT NULL REFERENCES az_clinical.visits(visit_id),
    patient_id INTEGER NOT NULL REFERENCES az_clinical.patients(patient_id),
    test_code VARCHAR(20) NOT NULL,
    test_name VARCHAR(100) NOT NULL,
    result_value VARCHAR(50) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    reference_range VARCHAR(50),
    collected_at TIMESTAMP NOT NULL,
    received_at TIMESTAMP,
    result_status az_clinical.result_status NOT NULL DEFAULT 'Final',
    -- JSONB raw result is a deliberate SnowConvert pain point (SUPER/VARIANT).
    raw_result JSONB,
    notes VARCHAR(255),  -- intentional null/space issue
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE az_clinical.lab_results IS 'Redshift stand-in: DISTKEY(patient_id), SORTKEY(collected_at), ENCODE LZO for varchar columns.';

CREATE TABLE az_clinical.adverse_events (
    ae_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES az_clinical.patients(patient_id),
    ae_term VARCHAR(100) NOT NULL,
    ae_description TEXT,
    onset_date DATE NOT NULL,
    resolution_date DATE,
    severity az_clinical.ae_severity NOT NULL,
    seriousness az_clinical.ae_seriousness NOT NULL DEFAULT 'Not Serious',
    causality az_clinical.ae_causality NOT NULL DEFAULT 'Possible',
    outcome VARCHAR(50),
    action_taken VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE az_clinical.adverse_events IS 'Redshift stand-in: DISTKEY(patient_id), SORTKEY(onset_date).';

CREATE TABLE az_clinical.concomitant_medications (
    cm_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES az_clinical.patients(patient_id),
    medication_name VARCHAR(100) NOT NULL,
    generic_name VARCHAR(100),
    indication VARCHAR(100),
    start_date DATE NOT NULL,
    end_date DATE,
    ongoing_flag BOOLEAN NOT NULL DEFAULT TRUE,
    -- PostgreSQL array; SnowConvert pain point.
    atc_codes TEXT[],
    notes VARCHAR(255),  -- intentional null/space issue
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE az_clinical.concomitant_medications IS 'Redshift stand-in: DISTKEY(patient_id), SORTKEY(start_date).';
