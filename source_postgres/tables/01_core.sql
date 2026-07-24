-- Core tables with no inbound foreign keys.
-- Redshift equivalents would include DISTSTYLE/DISTKEY/SORTKEY/ENCODE/IDENTITY clauses.
-- In this Postgres stand-in those are noted in table comments.

CREATE TABLE az_clinical.studies (
    study_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    study_code VARCHAR(20) NOT NULL UNIQUE,
    study_name VARCHAR(200) NOT NULL,
    protocol_number VARCHAR(50) NOT NULL UNIQUE,
    protocol_version VARCHAR(20) NOT NULL,
    phase VARCHAR(20) NOT NULL CHECK (phase IN ('Phase I', 'Phase II', 'Phase III', 'Phase IV')),
    indication VARCHAR(100) NOT NULL,
    sponsor VARCHAR(100) NOT NULL,
    planned_sites INTEGER NOT NULL CHECK (planned_sites > 0),
    planned_subjects INTEGER NOT NULL CHECK (planned_subjects > 0),
    start_date DATE,
    end_date DATE,
    status az_clinical.study_status NOT NULL DEFAULT 'Planning',
    -- JSONB metadata is a deliberate SnowConvert pain point (SUPER/VARIANT + dot notation).
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(50) NOT NULL DEFAULT 'system',
    updated_by VARCHAR(50) NOT NULL DEFAULT 'system'
);
COMMENT ON TABLE az_clinical.studies IS 'Redshift stand-in: DISTSTYLE ALL, SORTKEY(study_id), ENCODE AUTO, IDENTITY(study_id).';

CREATE TABLE az_clinical.investigators (
    investigator_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    credentials VARCHAR(50),
    email VARCHAR(100) NOT NULL,
    phone VARCHAR(30),
    institution VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE az_clinical.investigators IS 'Redshift stand-in: DISTSTYLE ALL, SORTKEY(investigator_id).';
