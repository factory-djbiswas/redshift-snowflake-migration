-- Entity tables with simple foreign keys.

CREATE TABLE az_clinical.treatment_arms (
    arm_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    study_id INTEGER NOT NULL REFERENCES az_clinical.studies(study_id),
    arm_code VARCHAR(20) NOT NULL,
    arm_name VARCHAR(100) NOT NULL,
    dosage VARCHAR(50),
    frequency VARCHAR(50),
    route VARCHAR(50),
    placebo_flag BOOLEAN NOT NULL DEFAULT FALSE,
    active_flag BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(study_id, arm_code)
);
COMMENT ON TABLE az_clinical.treatment_arms IS 'Redshift stand-in: DISTKEY(study_id), SORTKEY(arm_id).';

CREATE TABLE az_clinical.trial_sites (
    site_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    study_id INTEGER NOT NULL REFERENCES az_clinical.studies(study_id),
    investigator_id INTEGER REFERENCES az_clinical.investigators(investigator_id),
    site_code VARCHAR(20) NOT NULL UNIQUE,
    site_name VARCHAR(200) NOT NULL,
    country VARCHAR(50) NOT NULL,
    region VARCHAR(50) NOT NULL,
    address TEXT,
    activation_date DATE,
    status az_clinical.site_status NOT NULL DEFAULT 'Initiating',
    -- PostgreSQL array of contact emails; Snowflake has no native array support in SQL DDL.
    contact_emails TEXT[],
    notes VARCHAR(255),  -- intentional null/space issue
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50) NOT NULL DEFAULT 'system',
    updated_by VARCHAR(50) NOT NULL DEFAULT 'system'
);
COMMENT ON TABLE az_clinical.trial_sites IS 'Redshift stand-in: DISTSTYLE ALL, SORTKEY(site_id), ENCODE LZO for name columns.';

CREATE TABLE az_clinical.patients (
    patient_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    study_id INTEGER NOT NULL REFERENCES az_clinical.studies(study_id),
    site_id INTEGER NOT NULL REFERENCES az_clinical.trial_sites(site_id),
    subject_number VARCHAR(20) NOT NULL UNIQUE,
    initials VARCHAR(10) NOT NULL,
    enrollment_date DATE,
    screening_date DATE,
    randomization_date DATE,
    completion_date DATE,
    status az_clinical.patient_status NOT NULL DEFAULT 'Screening',
    -- JSONB for stratification; another SnowConvert pain point.
    stratification JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50) NOT NULL DEFAULT 'system',
    updated_by VARCHAR(50) NOT NULL DEFAULT 'system'
);
COMMENT ON TABLE az_clinical.patients IS 'Redshift stand-in: DISTKEY(site_id), SORTKEY(enrollment_date), ENCODE LZO for subject_number.';

CREATE TABLE az_clinical.demographics (
    demographic_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id INTEGER NOT NULL UNIQUE REFERENCES az_clinical.patients(patient_id),
    date_of_birth DATE NOT NULL,
    sex CHAR(1) NOT NULL CHECK (sex IN ('M', 'F', 'U', 'O')),
    race VARCHAR(50),
    ethnicity VARCHAR(50),
    weight_kg NUMERIC(5,2),
    height_cm NUMERIC(5,2),
    bmi NUMERIC(5,2),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE az_clinical.demographics IS 'Redshift stand-in: DISTKEY(patient_id), SORTKEY(demographic_id).';

CREATE TABLE az_clinical.visit_windows (
    window_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    study_id INTEGER NOT NULL REFERENCES az_clinical.studies(study_id),
    visit_code VARCHAR(20) NOT NULL,
    visit_name VARCHAR(100) NOT NULL,
    day_min INTEGER NOT NULL,
    day_max INTEGER NOT NULL,
    day_target INTEGER NOT NULL,
    visit_order INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(study_id, visit_code)
);
COMMENT ON TABLE az_clinical.visit_windows IS 'Redshift stand-in: DISTSTYLE ALL, SORTKEY(window_id).';
