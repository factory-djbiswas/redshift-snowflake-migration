-- =====================================================================
-- SnowConvert output (SIMULATED) - FAILS ON EXECUTION IN SNOWFLAKE
-- Object:         AZ_CLINICAL enum types
-- Source:         source_postgres/types/01_enums.sql
-- Failure class:  Unsupported DDL feature (ENUM types)
-- Expected error: SQL compilation error: Unsupported feature 'CREATE TYPE ... AS ENUM'
-- Fix rule:       RS010 (rewrite enums as VARCHAR + CHECK, or lookup tables)
-- =====================================================================
CREATE TYPE AZ_CLINICAL.STUDY_STATUS   AS ENUM ('Planning', 'Active', 'Completed', 'Suspended', 'Terminated');
CREATE TYPE AZ_CLINICAL.PATIENT_STATUS AS ENUM ('Screening', 'Active', 'Completed', 'Screen Failed', 'Withdrawn', 'Lost to Follow-up');
CREATE TYPE AZ_CLINICAL.VISIT_STATUS   AS ENUM ('Scheduled', 'Completed', 'Missed', 'Early Termination', 'Rescheduled');
CREATE TYPE AZ_CLINICAL.SITE_STATUS    AS ENUM ('Initiating', 'Active', 'Inactive', 'Closed');
CREATE TYPE AZ_CLINICAL.RESULT_STATUS  AS ENUM ('Final', 'Preliminary', 'Cancelled', 'Corrected', 'Amended');
