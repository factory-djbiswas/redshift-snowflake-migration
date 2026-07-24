-- Trigger function: writes GxP audit trail and versioned history for critical tables.
-- Pass the primary-key column name as the first trigger argument (TG_ARGV[0]).
-- This is a deliberate SnowConvert pain point: procedural logic with dynamic SQL and exception handling.
CREATE OR REPLACE FUNCTION az_clinical.audit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    old_json JSONB;
    new_json JSONB;
    next_version INTEGER;
    pk_col TEXT := TG_ARGV[0];
    old_pk INTEGER;
    new_pk INTEGER;
BEGIN
    IF TG_OP = 'INSERT' THEN
        new_json := to_jsonb(NEW);
        EXECUTE format('SELECT ($1->>%L)::INTEGER', pk_col) INTO new_pk USING new_json;
        INSERT INTO az_clinical.audit_trail (table_name, operation, record_id, new_values, changed_by, changed_at)
        VALUES (TG_TABLE_NAME, 'INSERT', new_pk, new_json, COALESCE(new_json->>'updated_by', 'system'), CURRENT_TIMESTAMP);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        old_json := to_jsonb(OLD);
        new_json := to_jsonb(NEW);
        EXECUTE format('SELECT ($1->>%L)::INTEGER', pk_col) INTO old_pk USING old_json;
        SELECT COALESCE(MAX(version), 0) + 1 INTO next_version
        FROM az_clinical.data_change_history
        WHERE table_name = TG_TABLE_NAME AND record_id = old_pk;
        INSERT INTO az_clinical.audit_trail (table_name, operation, record_id, old_values, new_values, changed_by, changed_at)
        VALUES (TG_TABLE_NAME, 'UPDATE', old_pk, old_json, new_json, COALESCE(new_json->>'updated_by', 'system'), CURRENT_TIMESTAMP);
        INSERT INTO az_clinical.data_change_history (table_name, record_id, version, row_data, changed_by, changed_at)
        VALUES (TG_TABLE_NAME, old_pk, next_version, old_json, COALESCE(new_json->>'updated_by', 'system'), CURRENT_TIMESTAMP);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        old_json := to_jsonb(OLD);
        EXECUTE format('SELECT ($1->>%L)::INTEGER', pk_col) INTO old_pk USING old_json;
        INSERT INTO az_clinical.audit_trail (table_name, operation, record_id, old_values, changed_by, changed_at)
        VALUES (TG_TABLE_NAME, 'DELETE', old_pk, old_json, COALESCE(old_json->>'updated_by', 'system'), CURRENT_TIMESTAMP);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

-- JSONB scalar UDF: Redshift equivalent would use SUPER/json_extract_path_text;
-- SnowConvert may generate broken VARIANT access.
CREATE OR REPLACE FUNCTION az_clinical.parse_patient_json(payload JSONB, key TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN payload->>key;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$;

-- BMI calculation UDF.
CREATE OR REPLACE FUNCTION az_clinical.calculate_bmi(weight_kg NUMERIC, height_cm NUMERIC)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF height_cm IS NULL OR height_cm = 0 OR weight_kg IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN ROUND(weight_kg / ((height_cm / 100.0) ^ 2), 2);
END;
$$;
