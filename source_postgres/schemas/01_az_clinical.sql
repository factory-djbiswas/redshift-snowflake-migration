-- Drop and recreate the demo schema so the rebuild is clean.
-- All prior objects (tables, views, functions, triggers, types) are removed.
DROP SCHEMA IF EXISTS az_clinical CASCADE;
CREATE SCHEMA az_clinical;
