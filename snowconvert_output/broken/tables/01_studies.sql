-- =====================================================================
-- SnowConvert output (SIMULATED) - FAILS ON EXECUTION IN SNOWFLAKE
-- Object:         AZ_CLINICAL.STUDIES
-- Source:         source_postgres/tables/01_core.sql (studies)
-- Failure class:  Redshift-specific storage clauses left in DDL
-- Expected error: SQL compilation error: syntax error line ... at 'DISTSTYLE'
-- Fix rule:       RS002 (strip DISTSTYLE / DISTKEY / SORTKEY / ENCODE)
-- =====================================================================
CREATE OR REPLACE TABLE AZ_CLINICAL.STUDIES (
    STUDY_ID         INTEGER IDENTITY(1,1),
    STUDY_CODE       VARCHAR(20) NOT NULL,
    STUDY_NAME       VARCHAR(200) NOT NULL,
    PROTOCOL_NUMBER  VARCHAR(50) NOT NULL,
    PROTOCOL_VERSION VARCHAR(20) NOT NULL,
    PHASE            VARCHAR(20) NOT NULL,
    INDICATION       VARCHAR(100) NOT NULL,
    SPONSOR          VARCHAR(100) NOT NULL,
    PLANNED_SITES    INTEGER NOT NULL,
    PLANNED_SUBJECTS INTEGER NOT NULL,
    START_DATE       DATE,
    END_DATE         DATE,
    STATUS           VARCHAR(20) NOT NULL DEFAULT 'Planning',
    METADATA         VARIANT,
    CREATED_AT       TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT       TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CREATED_BY       VARCHAR(50) NOT NULL DEFAULT 'system',
    UPDATED_BY       VARCHAR(50) NOT NULL DEFAULT 'system',
    PRIMARY KEY (STUDY_ID),
    UNIQUE (STUDY_CODE),
    UNIQUE (PROTOCOL_NUMBER)
)
DISTSTYLE ALL
SORTKEY (STUDY_ID);
