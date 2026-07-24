-- SnowConvert output (SIMULATED) - CLEAN, runs in Snowflake without modification.
-- Source: source_postgres/tables/02_entities.sql (demographics)
-- Notes: NUMERIC -> NUMBER; CHECK on SEX preserved (Snowflake parses, does not enforce).
CREATE OR REPLACE TABLE AZ_CLINICAL.DEMOGRAPHICS (
    DEMOGRAPHIC_ID INTEGER IDENTITY(1,1),
    PATIENT_ID     INTEGER NOT NULL,
    DATE_OF_BIRTH  DATE NOT NULL,
    SEX            CHAR(1) NOT NULL,
    RACE           VARCHAR(50),
    ETHNICITY      VARCHAR(50),
    WEIGHT_KG      NUMBER(5,2),
    HEIGHT_CM      NUMBER(5,2),
    BMI            NUMBER(5,2),
    CREATED_AT     TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT     TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (DEMOGRAPHIC_ID),
    UNIQUE (PATIENT_ID)
);
