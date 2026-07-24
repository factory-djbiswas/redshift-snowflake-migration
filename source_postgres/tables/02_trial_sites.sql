-- Trial sites table.
-- Redshift equivalent would include: DISTSTYLE ALL, SORTKEY(site_id), ENCODE AUTO.
CREATE TABLE IF NOT EXISTS az_clinical.trial_sites (
    site_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    site_code VARCHAR(10) NOT NULL UNIQUE,
    site_name VARCHAR(100) NOT NULL,
    country VARCHAR(50) NOT NULL,
    region VARCHAR(50) NOT NULL,
    principal_investigator VARCHAR(100) NOT NULL,
    activation_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('Active', 'Inactive', 'Initiating')),
    notes VARCHAR(255),  -- intentional null/space issue
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE az_clinical.trial_sites IS 'Redshift stand-in: DISTSTYLE ALL, SORTKEY(site_id).';
