#!/usr/bin/env python3
"""Generate realistic clinical-trial seed data for the enhanced local Postgres demo.

This script writes a SQL file (scripts/seed_data.sql) that can be executed with psql.
No Postgres driver is required; the script only generates INSERT statements.
"""

import random
import os
import json
from datetime import datetime, timedelta

random.seed(42)

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

def sql_quote(value):
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def sql_array(value):
    if value is None:
        return "NULL"
    if not value:
        return "'{}'::text[]"
    escaped = [str(v).replace("\\", "\\\\").replace('"', '\\"') for v in value]
    return "'{" + ','.join(f'"{v}"' for v in escaped) + "}'::text[]"


def sql_jsonb(value):
    if value is None:
        return "NULL"
    return sql_quote(json.dumps(value)) + "::jsonb"


def generate_date(start, end):
    delta = end - start
    return start + timedelta(days=random.randint(0, delta.days))


def generate_ts(start, end):
    delta = end - start
    return start + timedelta(seconds=random.randint(0, int(delta.total_seconds())))


# -----------------------------------------------------------------------------
# Realistic sample data
# -----------------------------------------------------------------------------

STUDY = {
    "study_code": "AZ-CLIN-2026",
    "study_name": "AstraZeneca Respiratory Phase III Trial Demo",
    "protocol_number": "PROT-2026-001",
    "protocol_version": "3.0",
    "phase": "Phase III",
    "indication": "Chronic Respiratory Disease",
    "sponsor": "AstraZeneca",
    "planned_sites": 5,
    "planned_subjects": 100,
    "status": "Active",
    "metadata": {"therapeutic_area": "Respiratory", "compound": "AZD1234", "blinded": True},
}

ARMS = [
    {"arm_code": "PBO", "arm_name": "Placebo", "dosage": "0 mg", "frequency": "Once daily", "route": "Oral", "placebo_flag": True},
    {"arm_code": "LOW", "arm_name": "Active Low Dose", "dosage": "50 mg", "frequency": "Once daily", "route": "Oral", "placebo_flag": False},
    {"arm_code": "HIGH", "arm_name": "Active High Dose", "dosage": "100 mg", "frequency": "Once daily", "route": "Oral", "placebo_flag": False},
]

INVESTIGATORS = [
    ("Sarah", "Chen", "MD, PhD", "s.chen@azdemo-site001.com", "+1-555-0101", "AstraZeneca Clinical Research Center"),
    ("James", "Wilson", "MD", "j.wilson@azdemo-site002.com", "+44-20-5555-0102", "Cambridge University Hospital"),
    ("Klaus", "Mueller", "MD", "k.mueller@azdemo-site003.com", "+49-30-5555-0103", "Charite Universitatsmedizin Berlin"),
    ("Marie", "Dubois", "MD", "m.dubois@azdemo-site004.com", "+33-1-5555-0104", "Centre Hospitalier Universitaire"),
    ("Yuki", "Tanaka", "MD, PhD", "y.tanaka@azdemo-site005.com", "+81-3-5555-0105", "Tokyo Medical Center"),
]

SITES = [
    ("AZ-001", "AstraZeneca Clinical Research Center", "United States", "North America", "2023-01-15"),
    ("AZ-002", "Cambridge University Hospital", "United Kingdom", "Europe", "2023-02-01"),
    ("AZ-003", "Charite Universitatsmedizin Berlin", "Germany", "Europe", "2023-02-10"),
    ("AZ-004", "Centre Hospitalier Universitaire", "France", "Europe", "2023-02-20"),
    ("AZ-005", "Tokyo Medical Center", "Japan", "Asia Pacific", "2023-03-01"),
]

FIRST_NAMES = [
    "Emma", "Liam", "Olivia", "Noah", "Ava", "Ethan", "Sophia", "Mason", "Isabella", "William",
    "Mia", "James", "Charlotte", "Benjamin", "Amelia", "Lucas", "Harper", "Henry", "Evelyn", "Alexander",
    "Abigail", "Michael", "Emily", "Daniel", "Elizabeth", "Jackson", "Sofia", "Sebastian", "Avery", "David",
    "Grace", "Joseph", "Chloe", "Samuel", "Ella", "Matthew", "Victoria", "Wyatt", "Riley", "Carter"
]

LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez",
    "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
    "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson",
    "Walker", "Young", "Allen", "King", "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores"
]

RACES = ["Asian", "Black or African American", "White", "Native Hawaiian or Other Pacific Islander", "Other", "Unknown"]
ETHNICITIES = ["Hispanic or Latino", "Not Hispanic or Latino", "Unknown"]

LAB_TESTS = [
    ("HEMOGLOBIN", "Hemoglobin", "g/dL", "12.0-15.5"),
    ("GLUCOSE", "Glucose", "mg/dL", "70-100"),
    ("CREATININE", "Creatinine", "mg/dL", "0.6-1.2"),
    ("ALT", "Alanine Aminotransferase", "U/L", "7-56"),
    ("AST", "Aspartate Aminotransferase", "U/L", "10-40"),
    ("WBC", "White Blood Cell Count", "10^9/L", "4.0-11.0"),
    ("PLATELET", "Platelet Count", "10^9/L", "150-450"),
    ("CHOLESTEROL", "Total Cholesterol", "mg/dL", "125-200"),
    ("LDL", "LDL Cholesterol", "mg/dL", "<100"),
    ("HDL", "HDL Cholesterol", "mg/dL", ">40"),
]

AE_TERMS = [
    "Headache", "Nausea", "Fatigue", "Dizziness", "Cough", "Upper respiratory infection",
    "Back pain", "Diarrhea", "Hypertension", "Insomnia", "Rash", "Vomiting"
]

MEDICATIONS = [
    ("Paracetamol", "Acetaminophen", "Pain relief", "N02BE01"),
    ("Ibuprofen", "Ibuprofen", "Inflammation", "M01AE01"),
    ("Salbutamol", "Albuterol", "Asthma", "R03AC02"),
    ("Omeprazole", "Omeprazole", "GERD", "A02BC01"),
    ("Loratadine", "Loratadine", "Allergy", "R06AX13"),
    ("Metformin", "Metformin", "Diabetes", "A10BA02"),
]

CRF_PAGES = [
    ("DEMO", "Demographics", "1.0"),
    ("MH", "Medical History", "1.0"),
    ("VS", "Vital Signs", "1.0"),
    ("LB", "Laboratory Results", "1.0"),
    ("AE", "Adverse Events", "1.0"),
]

VISIT_WINDOWS = [
    ("SCR", "Screening", -28, -1, -14, 1),
    ("D1", "Day 1", 0, 0, 0, 2),
    ("W2", "Week 2", 12, 16, 14, 3),
    ("W4", "Week 4", 26, 30, 28, 4),
    ("W8", "Week 8", 54, 58, 56, 5),
    ("W12", "Week 12", 82, 86, 84, 6),
]

# Null/space patterns for demonstrating the migration normalization issue
NOTE_VARIANTS = [
    None, "", " ", "  ",
    "No clinically significant findings",
    "Patient reported mild fatigue",
    "Repeat sample requested",
    "Value confirmed by repeat testing",
    "Pending local lab verification",
]


# -----------------------------------------------------------------------------
# Generators
# -----------------------------------------------------------------------------

def generate_seed_data():
    output_path = os.path.join(os.path.dirname(__file__), "seed_data.sql")
    with open(output_path, "w") as f:
        f.write("-- Auto-generated clinical-trial seed data for enhanced local Postgres demo.\n")
        f.write("-- Includes intentional null/space/empty-string variations and SnowConvert pain points.\n\n")
        f.write("BEGIN;\n\n")

        today = datetime(2026, 7, 23).date()
        study_start = today - timedelta(days=365)

        # Studies
        f.write("-- Studies\n")
        f.write(
            f"INSERT INTO az_clinical.studies (study_code, study_name, protocol_number, protocol_version, phase, indication, sponsor, planned_sites, planned_subjects, start_date, end_date, status, metadata) VALUES "
            f"({sql_quote(STUDY['study_code'])}, {sql_quote(STUDY['study_name'])}, {sql_quote(STUDY['protocol_number'])}, {sql_quote(STUDY['protocol_version'])}, "
            f"{sql_quote(STUDY['phase'])}, {sql_quote(STUDY['indication'])}, {sql_quote(STUDY['sponsor'])}, {STUDY['planned_sites']}, {STUDY['planned_subjects']}, "
            f"{sql_quote(study_start)}, {sql_quote(today + timedelta(days=180))}, {sql_quote(STUDY['status'])}, {sql_jsonb(STUDY['metadata'])});\n"
        )
        study_id = 1
        f.write("\n")

        # Treatment arms
        f.write("-- Treatment arms\n")
        for i, arm in enumerate(ARMS, start=1):
            f.write(
                f"INSERT INTO az_clinical.treatment_arms (study_id, arm_code, arm_name, dosage, frequency, route, placebo_flag) VALUES "
                f"({study_id}, {sql_quote(arm['arm_code'])}, {sql_quote(arm['arm_name'])}, {sql_quote(arm['dosage'])}, {sql_quote(arm['frequency'])}, "
                f"{sql_quote(arm['route'])}, {str(arm['placebo_flag']).upper()});\n"
            )
        f.write("\n")
        arm_ids = list(range(1, len(ARMS) + 1))

        # Investigators
        f.write("-- Investigators\n")
        for i, inv in enumerate(INVESTIGATORS, start=1):
            f.write(
                f"INSERT INTO az_clinical.investigators (first_name, last_name, credentials, email, phone, institution) VALUES "
                f"({sql_quote(inv[0])}, {sql_quote(inv[1])}, {sql_quote(inv[2])}, {sql_quote(inv[3])}, {sql_quote(inv[4])}, {sql_quote(inv[5])});\n"
            )
        f.write("\n")
        investigator_ids = list(range(1, len(INVESTIGATORS) + 1))

        # Trial sites
        f.write("-- Trial sites\n")
        site_ids = []
        for i, site in enumerate(SITES, start=1):
            notes = random.choice(NOTE_VARIANTS)
            contact_emails = [f"site{i:03d}@azdemo.com", f"crc{i:03d}@azdemo.com"]
            f.write(
                f"INSERT INTO az_clinical.trial_sites (study_id, investigator_id, site_code, site_name, country, region, address, activation_date, status, contact_emails, notes) VALUES "
                f"({study_id}, {investigator_ids[i-1]}, {sql_quote(site[0])}, {sql_quote(site[1])}, {sql_quote(site[2])}, {sql_quote(site[3])}, "
                f"{sql_quote(f'{site[1]}, {site[2]}')}, {sql_quote(site[4])}, {sql_quote('Active')}, {sql_array(contact_emails)}, {sql_quote(notes)});\n"
            )
            site_ids.append(i)
        f.write("\n")

        # Patients
        f.write("-- Patients\n")
        patient_records = []
        num_patients = 50
        statuses = ["Screening", "Active", "Completed", "Screen Failed", "Withdrawn", "Lost to Follow-up"]
        status_weights = [10, 30, 15, 5, 8, 2]
        for i in range(1, num_patients + 1):
            site_id = random.choice(site_ids)
            subject_number = f"{site_id:03d}-{i:03d}"
            initials = f"{random.choice(FIRST_NAMES)[0]}{random.choice(LAST_NAMES)[0]}"
            screening_date = generate_date(study_start, today - timedelta(days=30))
            enrollment_date = screening_date + timedelta(days=random.randint(1, 14)) if random.random() > 0.15 else None
            status = random.choices(statuses, weights=status_weights)[0]
            if status in ["Active", "Completed", "Withdrawn"] and enrollment_date is None:
                enrollment_date = screening_date + timedelta(days=random.randint(1, 14))
            randomization_date = enrollment_date + timedelta(days=random.randint(0, 3)) if status in ["Active", "Completed"] and random.random() > 0.2 else None
            completion_date = enrollment_date + timedelta(days=84) if status == "Completed" else None
            stratification = {
                "region": random.choice(["North America", "Europe", "Asia Pacific"]),
                "site_size": random.choice(["Small", "Medium", "Large"]),
            }
            patient_records.append({
                "patient_id": i,
                "site_id": site_id,
                "subject_number": subject_number,
                "initials": initials,
                "screening_date": screening_date,
                "enrollment_date": enrollment_date,
                "randomization_date": randomization_date,
                "completion_date": completion_date,
                "status": status,
                "stratification": stratification,
            })
            f.write(
                f"INSERT INTO az_clinical.patients (study_id, site_id, subject_number, initials, screening_date, enrollment_date, randomization_date, completion_date, status, stratification) VALUES "
                f"({study_id}, {site_id}, {sql_quote(subject_number)}, {sql_quote(initials)}, {sql_quote(screening_date)}, {sql_quote(enrollment_date)}, "
                f"{sql_quote(randomization_date)}, {sql_quote(completion_date)}, {sql_quote(status)}, {sql_jsonb(stratification)});\n"
            )
        f.write("\n")

        # Demographics
        f.write("-- Demographics\n")
        for p in patient_records:
            dob = generate_date(today - timedelta(days=80 * 365), today - timedelta(days=18 * 365))
            sex = random.choice(["M", "F", "U", "O"])
            weight = round(random.uniform(55.0, 95.0), 2)
            height = round(random.uniform(150.0, 185.0), 2)
            bmi = round(weight / ((height / 100.0) ** 2), 2) if height > 0 else None
            f.write(
                f"INSERT INTO az_clinical.demographics (patient_id, date_of_birth, sex, race, ethnicity, weight_kg, height_cm, bmi) VALUES "
                f"({p['patient_id']}, {sql_quote(dob)}, {sql_quote(sex)}, {sql_quote(random.choice(RACES))}, {sql_quote(random.choice(ETHNICITIES))}, "
                f"{weight}, {height}, {bmi});\n"
            )
        f.write("\n")

        # Visit windows
        f.write("-- Visit windows\n")
        window_ids = {}
        for i, vw in enumerate(VISIT_WINDOWS, start=1):
            window_ids[vw[0]] = i
            f.write(
                f"INSERT INTO az_clinical.visit_windows (study_id, visit_code, visit_name, day_min, day_max, day_target, visit_order) VALUES "
                f"({study_id}, {sql_quote(vw[0])}, {sql_quote(vw[1])}, {vw[2]}, {vw[3]}, {vw[4]}, {vw[5]});\n"
            )
        f.write("\n")

        # Visits
        f.write("-- Visits\n")
        visits = []
        visit_id = 1
        for p in patient_records:
            if p["status"] == "Screen Failed":
                window_codes = ["SCR"]
            elif p["status"] == "Withdrawn" or p["status"] == "Lost to Follow-up":
                window_codes = ["SCR", "D1", "W2", "W4"]
            elif p["status"] == "Completed":
                window_codes = ["SCR", "D1", "W2", "W4", "W8", "W12"]
            else:  # Active / Screening
                window_codes = ["SCR", "D1", "W2", "W4", "W8"]

            for vc in window_codes:
                vw = next(w for w in VISIT_WINDOWS if w[0] == vc)
                base = p["screening_date"] if vc == "SCR" else p["enrollment_date"] or p["screening_date"]
                actual = base + timedelta(days=vw[4] + random.randint(-2, 2)) if vc != "SCR" else base
                if vc == "SCR":
                    actual = p["screening_date"]
                status = "Completed" if random.random() > 0.05 else random.choice(["Missed", "Rescheduled"])
                visit_start = datetime.combine(actual, datetime.min.time()) + timedelta(hours=random.randint(8, 16))
                f.write(
                    f"INSERT INTO az_clinical.visits (patient_id, window_id, visit_code, visit_name, scheduled_date, actual_date, status, visit_start_at, visit_end_at) VALUES "
                    f"({p['patient_id']}, {window_ids[vc]}, {sql_quote(vc)}, {sql_quote(vw[1])}, {sql_quote(actual)}, {sql_quote(actual)}, "
                    f"{sql_quote(status)}, {sql_quote(visit_start.isoformat() + '+00')}, {sql_quote((visit_start + timedelta(minutes=45)).isoformat() + '+00')});\n"
                )
                visits.append({"visit_id": visit_id, "patient_id": p["patient_id"], "visit_code": vc, "actual_date": actual})
                visit_id += 1
        f.write("\n")

        # Vital signs
        f.write("-- Vital signs\n")
        for v in visits:
            if v["visit_code"] == "SCR":
                continue
            abnormal = []
            if random.random() < 0.1:
                abnormal.append("Tachycardia")
            if random.random() < 0.05:
                abnormal.append("Hypertension")
            notes = random.choice(NOTE_VARIANTS)
            f.write(
                f"INSERT INTO az_clinical.vital_signs (visit_id, patient_id, systolic_bp, diastolic_bp, heart_rate, respiratory_rate, temperature_celsius, weight_kg, abnormal_flags, notes) VALUES "
                f"({v['visit_id']}, {v['patient_id']}, {random.randint(100, 140)}, {random.randint(60, 90)}, {random.randint(60, 100)}, "
                f"{random.randint(12, 20)}, {round(random.uniform(36.0, 37.5), 1)}, {round(random.uniform(55.0, 95.0), 2)}, "
                f"{sql_array(abnormal if abnormal else None)}, {sql_quote(notes)});\n"
            )
        f.write("\n")

        # Lab results
        f.write("-- Lab results\n")
        for v in visits:
            num_tests = random.randint(2, 5)
            for _ in range(num_tests):
                test = random.choice(LAB_TESTS)
                base_value = random.uniform(50, 300)
                result_value = f"{base_value:.2f}"
                collected = datetime.combine(v["actual_date"], datetime.min.time()) + timedelta(hours=random.randint(7, 12))
                received = collected + timedelta(hours=random.randint(2, 48))
                status = random.choice(["Final", "Final", "Final", "Preliminary", "Corrected", "Amended"])
                raw = {
                    "instrument_id": f"INST-{random.randint(100, 999)}",
                    "batch_number": f"BATCH-{random.randint(1000, 9999)}",
                    "lab_location": random.choice(["Central Lab", "Local Lab"]),
                }
                notes = random.choice(NOTE_VARIANTS)
                f.write(
                    f"INSERT INTO az_clinical.lab_results (visit_id, patient_id, test_code, test_name, result_value, unit, reference_range, collected_at, received_at, result_status, raw_result, notes) VALUES "
                    f"({v['visit_id']}, {v['patient_id']}, {sql_quote(test[0])}, {sql_quote(test[1])}, {sql_quote(result_value)}, {sql_quote(test[2])}, "
                    f"{sql_quote(test[3])}, {sql_quote(collected.strftime('%Y-%m-%d %H:%M:%S'))}, {sql_quote(received.strftime('%Y-%m-%d %H:%M:%S'))}, "
                    f"{sql_quote(status)}, {sql_jsonb(raw)}, {sql_quote(notes)});\n"
                )
        f.write("\n")

        # Adverse events
        f.write("-- Adverse events\n")
        for p in patient_records:
            if p["status"] in ["Screening", "Screen Failed"]:
                continue
            num_aes = random.randint(0, 3)
            for _ in range(num_aes):
                onset = p["enrollment_date"] + timedelta(days=random.randint(1, 120)) if p["enrollment_date"] else p["screening_date"]
                resolved = onset + timedelta(days=random.randint(1, 30)) if random.random() > 0.3 else None
                f.write(
                    f"INSERT INTO az_clinical.adverse_events (patient_id, ae_term, ae_description, onset_date, resolution_date, severity, seriousness, causality, outcome, action_taken) VALUES "
                    f"({p['patient_id']}, {sql_quote(random.choice(AE_TERMS))}, {sql_quote('Mild event reported by subject')}, {sql_quote(onset)}, {sql_quote(resolved)}, "
                    f"{sql_quote(random.choice(['Mild', 'Moderate', 'Severe']))}, {sql_quote(random.choice(['Not Serious', 'Serious']))}, "
                    f"{sql_quote(random.choice(['Unrelated', 'Unlikely', 'Possible', 'Probable']))}, {sql_quote(random.choice(['Resolved', 'Recovering', 'Ongoing']))}, "
                    f"{sql_quote(random.choice(['None', 'Dose reduced', 'Medication given']))});\n"
                )
        f.write("\n")

        # Concomitant medications
        f.write("-- Concomitant medications\n")
        for p in patient_records:
            num_meds = random.randint(0, 2)
            for _ in range(num_meds):
                med = random.choice(MEDICATIONS)
                start = p["screening_date"] - timedelta(days=random.randint(1, 90))
                end = start + timedelta(days=random.randint(7, 180)) if random.random() > 0.5 else None
                ongoing = end is None
                notes = random.choice(NOTE_VARIANTS)
                f.write(
                    f"INSERT INTO az_clinical.concomitant_medications (patient_id, medication_name, generic_name, indication, start_date, end_date, ongoing_flag, atc_codes, notes) VALUES "
                    f"({p['patient_id']}, {sql_quote(med[0])}, {sql_quote(med[1])}, {sql_quote(med[2])}, {sql_quote(start)}, {sql_quote(end)}, "
                    f"{str(ongoing).upper()}, {sql_array([med[3]])}, {sql_quote(notes)});\n"
                )
        f.write("\n")

        # Randomization
        f.write("-- Randomization\n")
        randomized_count = 0
        for p in patient_records:
            if p["randomization_date"] is None:
                continue
            randomized_count += 1
            arm_id = random.choice(arm_ids)
            f.write(
                f"INSERT INTO az_clinical.randomization (patient_id, arm_id, randomization_date, randomization_number, stratification_factors) VALUES "
                f"({p['patient_id']}, {arm_id}, {sql_quote(p['randomization_date'])}, {sql_quote(f'R{randomized_count:04d}')}, {sql_jsonb(p['stratification'])});\n"
            )
        f.write("\n")

        # CRF pages
        f.write("-- CRF pages\n")
        page_ids = {}
        for i, page in enumerate(CRF_PAGES, start=1):
            page_ids[page[0]] = i
            f.write(
                f"INSERT INTO az_clinical.crf_pages (study_id, page_code, page_name, version, status) VALUES "
                f"({study_id}, {sql_quote(page[0])}, {sql_quote(page[1])}, {sql_quote(page[2])}, {sql_quote('Approved')});\n"
            )
        f.write("\n")

        # CRF data
        f.write("-- CRF data\n")
        for v in visits:
            pages_for_visit = ["DEMO"] if v["visit_code"] == "SCR" else ["VS", "LB"]
            if v["visit_code"] in ["D1", "W2", "W4"]:
                pages_for_visit.append("MH")
            if random.random() < 0.3:
                pages_for_visit.append("AE")
            for pc in pages_for_visit:
                if pc == "DEMO":
                    data = {"age_at_consent": random.randint(25, 70), "consent_date": v["actual_date"].isoformat()}
                elif pc == "MH":
                    data = {"conditions": [random.choice(["Asthma", "Hypertension", "Diabetes"]), "None"]}
                elif pc == "VS":
                    data = {"measured_by": random.choice(["Investigator", "Study Nurse"]), "device_id": f"DEV-{random.randint(100, 999)}"}
                elif pc == "LB":
                    data = {"fasting": random.choice([True, False]), "sample_id": f"S-{random.randint(1000, 9999)}"}
                elif pc == "AE":
                    data = {"reviewed_by": "Dr. Safety", "review_date": v["actual_date"].isoformat()}
                else:
                    data = {}
                f.write(
                    f"INSERT INTO az_clinical.crf_data (page_id, visit_id, patient_id, data, status) VALUES "
                    f"({page_ids[pc]}, {v['visit_id']}, {v['patient_id']}, {sql_jsonb(data)}, {sql_quote('Approved')});\n"
                )
        f.write("\n")

        # Protocol versions
        f.write("-- Protocol versions\n")
        for i, (version, effective_date, summary) in enumerate([
            ("1.0", study_start - timedelta(days=90), "Initial protocol"),
            ("2.0", study_start - timedelta(days=30), "Added inclusion criteria"),
            ("3.0", study_start, "Final protocol version"),
        ], start=1):
            f.write(
                f"INSERT INTO az_clinical.protocol_versions (study_id, version, effective_date, document_url, amendment_summary) VALUES "
                f"({study_id}, {sql_quote(version)}, {sql_quote(effective_date)}, {sql_quote(f'https://azdemo.com/protocols/{version}')}, {sql_quote(summary)});\n"
            )
        f.write("\n")

        # Validation rules
        f.write("-- Validation rules\n")
        rules = [
            ("patients", "subject_number", "NOT_NULL", "subject_number IS NOT NULL", "Subject number must not be null"),
            ("patients", "enrollment_date", "NOT_NULL", "enrollment_date IS NOT NULL", "Enrollment date must not be null for active subjects"),
            ("demographics", "sex", "NOT_NULL", "sex IS NOT NULL", "Sex must not be null"),
            ("lab_results", "result_value", "NOT_NULL", "result_value IS NOT NULL", "Result value must not be null"),
            ("visits", "actual_date", "NOT_NULL", "actual_date IS NOT NULL", "Visit actual date must not be null"),
            ("lab_results", "result_value", "FORMAT", "result_value ~ '^[0-9]+\\.?[0-9]*$'", "Result value must be numeric"),
            ("vital_signs", "systolic_bp", "RANGE", "systolic_bp BETWEEN 50 AND 300", "Systolic BP out of range"),
            ("adverse_events", "onset_date", "NOT_NULL", "onset_date IS NOT NULL", "AE onset date must not be null"),
            ("randomization", "arm_id", "NOT_NULL", "arm_id IS NOT NULL", "Randomization must have an arm"),
            ("crf_data", "data", "NOT_NULL", "data IS NOT NULL", "CRF data must not be null"),
        ]
        rule_ids = {}
        for i, rule in enumerate(rules, start=1):
            rule_ids[i] = i
            f.write(
                f"INSERT INTO az_clinical.validation_rules (study_id, table_name, column_name, rule_type, rule_expression, error_message) VALUES "
                f"({study_id}, {sql_quote(rule[0])}, {sql_quote(rule[1])}, {sql_quote(rule[2])}, {sql_quote(rule[3])}, {sql_quote(rule[4])});\n"
            )
        f.write("\n")

        # Validation results (simple pass/fail based on the rule)
        f.write("-- Validation results\n")
        for rid, rule in enumerate(rules, start=1):
            # Just create a few representative results per rule; exact evaluation would need dynamic SQL.
            for _ in range(3):
                passed = random.random() > 0.1
                f.write(
                    f"INSERT INTO az_clinical.validation_results (rule_id, record_id, passed, validation_message) VALUES "
                    f"({rid}, {random.randint(1, num_patients)}, {str(passed).upper()}, {sql_quote('Pass' if passed else rule[4])});\n"
                )
        f.write("\n")

        f.write("COMMIT;\n")
    print(f"Generated {output_path}")


if __name__ == "__main__":
    generate_seed_data()
