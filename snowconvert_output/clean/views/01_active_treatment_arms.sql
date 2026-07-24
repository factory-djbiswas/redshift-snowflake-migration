-- SnowConvert output (SIMULATED) - CLEAN, runs in Snowflake without modification.
-- Aggregate view over converted clean tables; no Redshift-specific constructs.
CREATE OR REPLACE VIEW AZ_CLINICAL.ACTIVE_TREATMENT_ARMS AS
SELECT
    STUDY_ID,
    COUNT(*)                                        AS ARM_COUNT,
    SUM(CASE WHEN PLACEBO_FLAG THEN 1 ELSE 0 END)   AS PLACEBO_ARMS,
    SUM(CASE WHEN ACTIVE_FLAG THEN 1 ELSE 0 END)    AS ACTIVE_ARMS
FROM AZ_CLINICAL.TREATMENT_ARMS
GROUP BY STUDY_ID;
