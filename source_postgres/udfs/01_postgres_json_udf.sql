-- Scalar UDF: safely extract a string value from a JSON payload.
-- Redshift equivalent would use SUPER or json_extract_path_text; SnowConvert may produce broken VARIANT access.
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
