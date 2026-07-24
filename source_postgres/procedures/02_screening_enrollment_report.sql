-- Stored procedure: screening and enrollment report by site and month.
-- Uses a cursor, exception handling, and a temp table - all common SnowConvert failure patterns.
CREATE OR REPLACE PROCEDURE az_clinical.screening_enrollment_report()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
    v_total_screened INTEGER;
    v_total_enrolled INTEGER;
BEGIN
    CREATE TEMP TABLE IF NOT EXISTS tmp_screening_enrollment AS
    SELECT
        s.site_id,
        s.site_code,
        s.site_name,
        date_trunc('month', p.screening_date)::date AS month,
        COUNT(*) FILTER (WHERE p.status IN ('Screening', 'Screen Failed')) AS screened_count,
        COUNT(*) FILTER (WHERE p.status IN ('Active', 'Completed', 'Withdrawn')) AS enrolled_count
    FROM az_clinical.patients p
    JOIN az_clinical.trial_sites s ON p.site_id = s.site_id
    WHERE p.screening_date IS NOT NULL
    GROUP BY s.site_id, s.site_code, s.site_name, date_trunc('month', p.screening_date)::date;

    CREATE TABLE IF NOT EXISTS az_clinical.screening_enrollment_summary (
        site_id INTEGER,
        site_code VARCHAR(20),
        site_name VARCHAR(200),
        month DATE,
        screened_count INTEGER,
        enrolled_count INTEGER,
        conversion_rate NUMERIC(5,2),
        generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    TRUNCATE TABLE az_clinical.screening_enrollment_summary;

    SELECT COUNT(*) INTO v_total_screened FROM az_clinical.patients WHERE screening_date IS NOT NULL;
    SELECT COUNT(*) INTO v_total_enrolled FROM az_clinical.patients WHERE status IN ('Active', 'Completed');

    IF v_total_screened = 0 THEN
        RAISE EXCEPTION 'No screened patients found; cannot generate report.';
    END IF;

    FOR rec IN SELECT * FROM tmp_screening_enrollment LOOP
        BEGIN
            INSERT INTO az_clinical.screening_enrollment_summary
                (site_id, site_code, site_name, month, screened_count, enrolled_count, conversion_rate, generated_at)
            VALUES (
                rec.site_id,
                rec.site_code,
                rec.site_name,
                rec.month,
                rec.screened_count,
                rec.enrolled_count,
                CASE
                    WHEN rec.screened_count = 0 THEN 0
                    ELSE ROUND((rec.enrolled_count::numeric / rec.screened_count) * 100, 2)
                END,
                CURRENT_TIMESTAMP
            );
        EXCEPTION
            WHEN OTHERS THEN
                -- Log the error and continue; SnowConvert rarely preserves this pattern correctly.
                RAISE NOTICE 'Error processing site %: %', rec.site_code, SQLERRM;
        END;
    END LOOP;

    DROP TABLE IF EXISTS tmp_screening_enrollment;
END;
$$;
