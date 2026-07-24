-- Custom PostgreSQL enums.
-- These are a deliberate Snowflake migration pain point: Snowflake does not support
-- CREATE TYPE ... AS ENUM, so the SnowConvert output must rewrite them as VARCHAR
-- with CHECK constraints or lookup tables.
CREATE TYPE az_clinical.study_status AS ENUM ('Planning', 'Active', 'Completed', 'Suspended', 'Terminated');
CREATE TYPE az_clinical.patient_status AS ENUM ('Screening', 'Active', 'Completed', 'Screen Failed', 'Withdrawn', 'Lost to Follow-up');
CREATE TYPE az_clinical.visit_status AS ENUM ('Scheduled', 'Completed', 'Missed', 'Early Termination', 'Rescheduled');
CREATE TYPE az_clinical.ae_severity AS ENUM ('Mild', 'Moderate', 'Severe', 'Life-threatening');
CREATE TYPE az_clinical.ae_seriousness AS ENUM ('Not Serious', 'Serious', 'Fatal');
CREATE TYPE az_clinical.ae_causality AS ENUM ('Unrelated', 'Unlikely', 'Possible', 'Probable', 'Definite');
CREATE TYPE az_clinical.result_status AS ENUM ('Final', 'Preliminary', 'Cancelled', 'Corrected', 'Amended');
CREATE TYPE az_clinical.site_status AS ENUM ('Initiating', 'Active', 'Inactive', 'Closed');
CREATE TYPE az_clinical.crf_status AS ENUM ('Draft', 'In Review', 'Approved', 'Locked');
