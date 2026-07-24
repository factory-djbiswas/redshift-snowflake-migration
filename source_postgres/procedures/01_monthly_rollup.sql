-- Stored procedure: monthly lab result rollup by site using a cursor.
-- Redshift equivalent would use a cursor/loop; SnowConvert often fails to rewrite procedural logic cleanly.
CREATE OR REPLACE PROCEDURE az_clinical.monthly_rollup()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
BEGIN
    -- Truncate and load the result into a permanent rollup table
    CREATE TABLE IF NOT EXISTS az_clinical.monthly_lab_rollup (
        site_id INTEGER,
        site_code VARCHAR(20),
        month DATE,
        test_code VARCHAR(20),
        result_count INTEGER,
        min_value NUMERIC,
        max_value NUMERIC,
        avg_value NUMERIC,
        rolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    TRUNCATE TABLE az_clinical.monthly_lab_rollup;

    -- Cursor over aggregated lab results
    FOR rec IN
        SELECT
            s.site_id,
            s.site_code,
            date_trunc('month', lr.collected_at)::date AS month,
            lr.test_code,
            COUNT(*) AS result_count,
            MIN(lr.result_value::numeric) AS min_value,
            MAX(lr.result_value::numeric) AS max_value,
            AVG(lr.result_value::numeric) AS avg_value
        FROM az_clinical.lab_results lr
        JOIN az_clinical.patients p ON lr.patient_id = p.patient_id
        JOIN az_clinical.trial_sites s ON p.site_id = s.site_id
        WHERE lr.result_status = 'Final'
        GROUP BY s.site_id, s.site_code, date_trunc('month', lr.collected_at)::date, lr.test_code
    LOOP
        INSERT INTO az_clinical.monthly_lab_rollup
        VALUES (rec.site_id, rec.site_code, rec.month, rec.test_code, rec.result_count, rec.min_value, rec.max_value, rec.avg_value, CURRENT_TIMESTAMP);
    END LOOP;
END;
$$;
