-- =====================================================================
-- SnowConvert output (SIMULATED) - FAILS ON EXECUTION IN SNOWFLAKE
-- Object:         AZ_CLINICAL.ARM_LABELS
-- Failure class:  Redshift NVL with 3+ arguments (Snowflake NVL takes exactly 2)
-- Expected error: SQL compilation error: error line ... too many arguments for function 'NVL'
-- Fix rule:       RS001 (multi-arg NVL -> COALESCE)
-- Depends on:     TREATMENT_ARMS (clean)
-- =====================================================================
CREATE OR REPLACE VIEW AZ_CLINICAL.ARM_LABELS AS
SELECT
    ARM_ID,
    STUDY_ID,
    NVL(ARM_NAME, DOSAGE, 'UNSPECIFIED') AS ARM_LABEL
FROM AZ_CLINICAL.TREATMENT_ARMS;
