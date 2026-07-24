-- FIXED (RS007 + RS003) - a scalar SQL UDF cannot contain a BEGIN/EXCEPTION procedural body;
--   collapsed to a single expression. JSON ->> access -> Snowflake VARIANT path via GET(...)::string.
-- Captured error: SQL UDF compilation error: syntax error at 'RETURN' (procedural body in scalar UDF).
CREATE OR REPLACE FUNCTION AZ_CLINICAL.PARSE_PATIENT_JSON(PAYLOAD VARIANT, KEY TEXT)
RETURNS TEXT
LANGUAGE SQL
IMMUTABLE
AS
$$
GET(PAYLOAD, KEY)::string
$$;
