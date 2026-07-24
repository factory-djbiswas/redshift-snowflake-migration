-- Trial operations tables: randomization and CRFs.

CREATE TABLE az_clinical.randomization (
    randomization_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id INTEGER NOT NULL UNIQUE REFERENCES az_clinical.patients(patient_id),
    arm_id INTEGER NOT NULL REFERENCES az_clinical.treatment_arms(arm_id),
    randomization_date DATE NOT NULL,
    randomization_number VARCHAR(20) NOT NULL UNIQUE,
    -- JSONB stratification factors used for IRT/IWRS integration; SnowConvert pain point.
    stratification_factors JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE az_clinical.randomization IS 'Redshift stand-in: DISTKEY(patient_id), SORTKEY(randomization_id).';

CREATE TABLE az_clinical.crf_pages (
    page_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    study_id INTEGER NOT NULL REFERENCES az_clinical.studies(study_id),
    page_code VARCHAR(20) NOT NULL,
    page_name VARCHAR(100) NOT NULL,
    version VARCHAR(20) NOT NULL,
    status az_clinical.crf_status NOT NULL DEFAULT 'Draft',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(study_id, page_code, version)
);
COMMENT ON TABLE az_clinical.crf_pages IS 'Redshift stand-in: DISTSTYLE ALL, SORTKEY(page_id).';

CREATE TABLE az_clinical.crf_data (
    crf_data_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    page_id INTEGER NOT NULL REFERENCES az_clinical.crf_pages(page_id),
    visit_id INTEGER NOT NULL REFERENCES az_clinical.visits(visit_id),
    patient_id INTEGER NOT NULL REFERENCES az_clinical.patients(patient_id),
    -- Free-form JSONB CRF data is a major SnowConvert pain point (SUPER/VARIANT).
    data JSONB NOT NULL,
    status az_clinical.crf_status NOT NULL DEFAULT 'Draft',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(page_id, visit_id)
);
COMMENT ON TABLE az_clinical.crf_data IS 'Redshift stand-in: DISTKEY(patient_id), SORTKEY(crf_data_id).';
