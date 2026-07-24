-- =====================================================================
-- SnowConvert output (SIMULATED) - FAILS ON EXECUTION IN SNOWFLAKE
-- Object:         AZ_CLINICAL.PARSE_PATIENT_JSON
-- Source:         source_postgres/udfs/01_postgres_json_udf.sql
-- Failure class:  plpgsql procedural body in a scalar UDF + JSON dot-notation
-- Expected error: SQL compilation error: syntax error at 'BEGIN' / 'EXCEPTION' / '->>'
-- Fix rules:      RS007 (scalar UDF cannot hold BEGIN/EXCEPTION - use single expression),
--                 RS003 (JSON ->> access -> VARIANT path GET(payload, key)::string)
-- =====================================================================
CREATE OR REPLACE FUNCTION AZ_CLINICAL.PARSE_PATIENT_JSON(PAYLOAD VARIANT, KEY TEXT)
RETURNS TEXT
LANGUAGE SQL
IMMUTABLE
AS
$$
BEGIN
    RETURN PAYLOAD->>KEY;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$;
