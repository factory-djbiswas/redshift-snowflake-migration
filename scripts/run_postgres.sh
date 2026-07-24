#!/usr/bin/env bash
set -euo pipefail

# Run the enhanced local Postgres demo setup against the existing Docker container.
# Credentials are pulled from the running container at runtime; nothing is hardcoded.

export PGHOST=localhost
export PGPORT=55432
export PGUSER=migration_user
export PGDATABASE=migration_demo
export PGPASSWORD=$(docker exec data-migration-demo-postgres-1 printenv POSTGRES_PASSWORD)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SP="$ROOT_DIR/source_postgres"

echo "Dropping and recreating schema..."
psql -f "$SP/schemas/01_az_clinical.sql"

echo "Creating custom types..."
psql -f "$SP/types/01_enums.sql"

echo "Creating tables..."
psql -f "$SP/tables/01_core.sql"
psql -f "$SP/tables/02_entities.sql"
psql -f "$SP/tables/03_visits_and_results.sql"
psql -f "$SP/tables/04_trial_ops.sql"
psql -f "$SP/tables/05_governance.sql"

echo "Creating functions..."
psql -f "$SP/functions/01_audit_and_utility.sql"

echo "Creating audit triggers..."
psql -f "$SP/triggers/01_audit_triggers.sql"

echo "Creating views..."
psql -f "$SP/views/01_active_enrollment.sql"
psql -f "$SP/views/02_lab_results_with_metadata.sql"

echo "Creating procedures..."
psql -f "$SP/procedures/01_monthly_rollup.sql"
psql -f "$SP/procedures/02_screening_enrollment_report.sql"

echo "Generating seed data..."
python3 "$ROOT_DIR/scripts/generate_seed_data.py"

echo "Inserting seed data..."
psql -f "$ROOT_DIR/scripts/seed_data.sql"

echo "Running post-load procedures..."
psql -c "CALL az_clinical.monthly_rollup();"
psql -c "CALL az_clinical.screening_enrollment_report();"

echo "Done. Summary:"
psql -c "
SELECT 'studies' AS object, COUNT(*) AS rows FROM az_clinical.studies UNION ALL
SELECT 'treatment_arms', COUNT(*) FROM az_clinical.treatment_arms UNION ALL
SELECT 'investigators', COUNT(*) FROM az_clinical.investigators UNION ALL
SELECT 'trial_sites', COUNT(*) FROM az_clinical.trial_sites UNION ALL
SELECT 'patients', COUNT(*) FROM az_clinical.patients UNION ALL
SELECT 'demographics', COUNT(*) FROM az_clinical.demographics UNION ALL
SELECT 'visit_windows', COUNT(*) FROM az_clinical.visit_windows UNION ALL
SELECT 'visits', COUNT(*) FROM az_clinical.visits UNION ALL
SELECT 'vital_signs', COUNT(*) FROM az_clinical.vital_signs UNION ALL
SELECT 'lab_results', COUNT(*) FROM az_clinical.lab_results UNION ALL
SELECT 'adverse_events', COUNT(*) FROM az_clinical.adverse_events UNION ALL
SELECT 'concomitant_medications', COUNT(*) FROM az_clinical.concomitant_medications UNION ALL
SELECT 'randomization', COUNT(*) FROM az_clinical.randomization UNION ALL
SELECT 'crf_pages', COUNT(*) FROM az_clinical.crf_pages UNION ALL
SELECT 'crf_data', COUNT(*) FROM az_clinical.crf_data UNION ALL
SELECT 'audit_trail', COUNT(*) FROM az_clinical.audit_trail UNION ALL
SELECT 'data_change_history', COUNT(*) FROM az_clinical.data_change_history UNION ALL
SELECT 'protocol_versions', COUNT(*) FROM az_clinical.protocol_versions UNION ALL
SELECT 'validation_rules', COUNT(*) FROM az_clinical.validation_rules UNION ALL
SELECT 'validation_results', COUNT(*) FROM az_clinical.validation_results UNION ALL
SELECT 'monthly_lab_rollup', COUNT(*) FROM az_clinical.monthly_lab_rollup UNION ALL
SELECT 'screening_enrollment_summary', COUNT(*) FROM az_clinical.screening_enrollment_summary
ORDER BY object;
"
