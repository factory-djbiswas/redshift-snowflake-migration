-- =====================================================================
-- SnowConvert output (SIMULATED) - FAILS ON EXECUTION IN SNOWFLAKE
-- Object:         AZ_CLINICAL.TRIAL_SITES
-- Source:         source_postgres/tables/02_entities.sql (trial_sites)
-- Failure class:  Unsupported ENUM type reference + array column type
-- Expected error: SQL compilation error: invalid type 'AZ_CLINICAL.SITE_STATUS'
--                 (subsequent run) syntax error at '[' for CONTACT_EMAILS
-- Fix rules:      RS010 (ENUM type -> VARCHAR + CHECK), RS011 (TEXT[] -> ARRAY)
-- =====================================================================
CREATE OR REPLACE TABLE AZ_CLINICAL.TRIAL_SITES (
    SITE_ID         INTEGER IDENTITY(1,1),
    STUDY_ID        INTEGER NOT NULL,
    INVESTIGATOR_ID INTEGER,
    SITE_CODE       VARCHAR(20) NOT NULL,
    SITE_NAME       VARCHAR(200) NOT NULL,
    COUNTRY         VARCHAR(50) NOT NULL,
    REGION          VARCHAR(50) NOT NULL,
    ADDRESS         VARCHAR(16777216),
    ACTIVATION_DATE DATE,
    STATUS          AZ_CLINICAL.SITE_STATUS NOT NULL DEFAULT 'Initiating',
    CONTACT_EMAILS  VARCHAR(16777216)[],
    NOTES           VARCHAR(255),
    CREATED_AT      TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT      TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CREATED_BY      VARCHAR(50) NOT NULL DEFAULT 'system',
    UPDATED_BY      VARCHAR(50) NOT NULL DEFAULT 'system',
    PRIMARY KEY (SITE_ID),
    UNIQUE (SITE_CODE)
);
