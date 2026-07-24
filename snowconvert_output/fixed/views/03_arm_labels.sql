-- FIXED (RS001) - Redshift 3-arg NVL -> COALESCE (Snowflake NVL takes exactly 2 args).
-- Captured error: too many arguments for function [NVL(...)] expected 2, got 3.
CREATE OR REPLACE VIEW AZ_CLINICAL.ARM_LABELS AS
SELECT
    ARM_ID,
    STUDY_ID,
    COALESCE(ARM_NAME, DOSAGE, 'UNSPECIFIED') AS ARM_LABEL
FROM AZ_CLINICAL.TREATMENT_ARMS;
