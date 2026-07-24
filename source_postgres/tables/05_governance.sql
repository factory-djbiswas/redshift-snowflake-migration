-- GxP / audit governance tables.

CREATE TABLE az_clinical.audit_trail (
    audit_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation VARCHAR(10) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    record_id INTEGER NOT NULL,
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(50) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    change_reason VARCHAR(255)
);
COMMENT ON TABLE az_clinical.audit_trail IS 'GxP audit trail: logs every change on critical tables.';

CREATE TABLE az_clinical.data_change_history (
    history_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id INTEGER NOT NULL,
    version INTEGER NOT NULL,
    row_data JSONB NOT NULL,
    changed_by VARCHAR(50) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE az_clinical.data_change_history IS 'GxP versioned history: keeps prior snapshots of critical rows.';

CREATE TABLE az_clinical.protocol_versions (
    protocol_version_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    study_id INTEGER NOT NULL REFERENCES az_clinical.studies(study_id),
    version VARCHAR(20) NOT NULL,
    effective_date DATE NOT NULL,
    document_url VARCHAR(255),
    amendment_summary TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(study_id, version)
);
COMMENT ON TABLE az_clinical.protocol_versions IS 'GxP protocol version history.';

CREATE TABLE az_clinical.validation_rules (
    rule_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    study_id INTEGER NOT NULL REFERENCES az_clinical.studies(study_id),
    table_name VARCHAR(50) NOT NULL,
    column_name VARCHAR(50),
    rule_type VARCHAR(50) NOT NULL CHECK (rule_type IN ('RANGE', 'NOT_NULL', 'UNIQUE', 'FORMAT', 'CUSTOM')),
    rule_expression TEXT NOT NULL,
    error_message VARCHAR(255) NOT NULL,
    active_flag BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE az_clinical.validation_rules IS 'GxP validation rules applied to migrated data.';

CREATE TABLE az_clinical.validation_results (
    validation_result_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rule_id INTEGER NOT NULL REFERENCES az_clinical.validation_rules(rule_id),
    record_id INTEGER NOT NULL,
    passed BOOLEAN NOT NULL,
    validation_message VARCHAR(255),
    validated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE az_clinical.validation_results IS 'GxP validation execution results per rule per record.';
