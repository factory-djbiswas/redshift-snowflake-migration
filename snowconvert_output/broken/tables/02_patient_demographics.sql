-- =====================================================================
-- SnowConvert output (SIMULATED) - FAILS ON EXECUTION IN SNOWFLAKE
-- Object:         AZ_CLINICAL.PATIENT_DEMOGRAPHICS
-- Source:         source_postgres/tables/01_patient_demographics.sql
-- Failure class:  Multiple - inline ENCODE, DISTKEY/SORTKEY, VARCHAR(MAX), SYSDATE
-- Expected error: SQL compilation error: syntax error line ... at 'ENCODE'
--                 (subsequent runs surface VARCHAR(MAX) and SYSDATE errors)
-- Fix rules:      RS002 (ENCODE / DISTKEY / SORTKEY), RS005 (VARCHAR(MAX)), RS004 (SYSDATE)
-- =====================================================================
CREATE OR REPLACE TABLE AZ_CLINICAL.PATIENT_DEMOGRAPHICS (
    PATIENT_ID      INTEGER IDENTITY(1,1),
    FIRST_NAME      VARCHAR(50) NOT NULL ENCODE LZO,
    LAST_NAME       VARCHAR(50) NOT NULL ENCODE LZO,
    DATE_OF_BIRTH   DATE NOT NULL,
    SEX             CHAR(1) NOT NULL,
    RACE            VARCHAR(50),
    ETHNICITY       VARCHAR(50),
    SITE_ID         INTEGER NOT NULL,
    ENROLLMENT_DATE DATE NOT NULL,
    STATUS          VARCHAR(20) NOT NULL,
    NOTES           VARCHAR(MAX),
    CREATED_AT      TIMESTAMP_NTZ NOT NULL DEFAULT SYSDATE,
    UPDATED_AT      TIMESTAMP_NTZ NOT NULL DEFAULT SYSDATE,
    PRIMARY KEY (PATIENT_ID)
)
DISTKEY (SITE_ID)
SORTKEY (ENROLLMENT_DATE);
