-- Patient demographics table.
-- Redshift equivalent would include: DISTKEY(site_id), SORTKEY(enrollment_date), ENCODE LZO for names.
-- The nullable VARCHAR 'notes' column is intentionally used to demonstrate the null/space defaulting issue.
CREATE TABLE IF NOT EXISTS az_clinical.patient_demographics (
    patient_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    date_of_birth DATE NOT NULL,
    sex CHAR(1) NOT NULL CHECK (sex IN ('M', 'F', 'U')),
    race VARCHAR(50),
    ethnicity VARCHAR(50),
    site_id INTEGER NOT NULL,
    enrollment_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('Active', 'Completed', 'Screen Failed', 'Withdrawn')),
    notes VARCHAR(255),  -- intentional null/space issue
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE az_clinical.patient_demographics IS 'Redshift stand-in: DISTKEY(site_id), SORTKEY(enrollment_date), ENCODE LZO for name columns.';
