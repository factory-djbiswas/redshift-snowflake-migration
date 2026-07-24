# Vallon x AstraZeneca Redshift→Snowflake Migration Demo Spec

**Goal:** Stand up a hands-on demo/POC in this repo that proves Factory's core differentiator for the AstraZeneca migration: **"did it actually run correctly in Snowflake"** (not just "did it convert"). Lead with the two sharpest wedges - the **SnowConvert run-fix-rerun automation (Phase 2 Missions)** and the **GxP/UAT evidence capture (Phase 3 Droid Control)**.

**Source material:** `vallon_az_migration_notes.md` (copied into this repo root).

---

## 1. Deliverables

| # | Deliverable | Location | Priority |
|---|-------------|----------|----------|
| 1 | Copied notes file | `vallon_az_migration_notes.md` | Done |
| 2 | This spec | `vallon_az_migration_spec.md` | In progress |
| 3 | Sample Redshift source objects | `source_redshift/` | Must have |
| 4 | Simulated SnowConvert output | `snowconvert_output/` | Must have |
| 5 | Reusable failure-pattern rule set | `missions/phase2_snowconvert_fixloop/rules/failure_patterns.md` | Must have |
| 6 | Phase 2 Mission runbook | `missions/phase2_snowconvert_fixloop/run_fix_rerun.md` | Must have |
| 7 | Null/space normalization validation spec | `validation/metadata_match.md` | Must have |
| 8 | Audit logging format | `logs/` | Must have |
| 9 | Phase 1 readiness spec | `missions/phase1_readiness/readiness_spec.md` | Expanded |
| 10 | Phase 3 GxP/UAT spec | `missions/phase3_gxp_uat/gxp_uat_spec.md` | Expanded |
| 11 | README with demo narrative | `README.md` | Must have |

---

## 2. Narrative and positioning

### 2.1 The migration as it runs today

A live, schema-by-schema Redshift to Snowflake migration, run as parallel mini-processes so business units migrate and test independently (BU-A tests while BU-B moves). Two workstreams run in parallel:

1. **Data migration** - export to Parquet, ingest into Snowflake.
2. **Code conversion** - SnowConvert (~70-80% automated; remainder manual).

Every unit of work flows through the same seven-stage pipeline:

1. SnowConvert DDL/DML conversion
2. Unit testing
3. System integration testing (SIT)
4. Functional testing
5. Historical data backfill and validation
6. GxP validation (150+ tests)
7. UAT (screenshots per test case, pass/fail tracker)

Upstream / downstream: ETL/ELT jobs, Domino Data Labs, Jupyter, dashboards, pharma apps, and ad hoc analytics.

### 2.2 Solved vs. opportunity

**What the Vallon/AZ team already owns (do not sell into these):**

- Data completeness validation - Snowflake metadata script outputs a spreadsheet with row counts and column alignment, reaching 100% match.
- File handling - Parquet chosen to avoid newline/pipe issues and messy Redshift defaults.
- Business logic - defined by users; raw provider data ingested as-is.
- Replatforming - dashboards, notebooks, and apps owned by the AstraZeneca customer.

**Where the time still goes (Factory's opportunity):**

- SnowConvert remediation - the #1 time sink: run converted scripts, catch errors, fix, rerun.
- Manual orchestration - running code conversion and executing scripts in Snowflake is still manual.
- Redshift null/space defaulting - breaks the 100% table match check.
- GxP + UAT evidence - 150+ regulated tests plus per-test-case screenshots and a pass/fail tracker across every user scenario.

### 2.3 Parallel per-BU migration model

The migration is run as parallel mini-processes across business units. Factory mirrors this by running parallel Missions per schema/BU, each with its own status and logs, so BU-A tests while BU-B moves.

---

## 3. Capability mapping

| Your step (in your words) | Signal | Droid capability |
|---|---|---|
| SnowConvert: run scripts, catch errors, fix, rerun | #1 time sink | Missions run the execute-validate-fix loop in Snowflake with full logs |
| Running conversion and executing scripts in Snowflake | Manual | Missions + Droid Control orchestrate the pipeline |
| Redshift null/space defaulting breaks 100% match | Edge case | Missions detect and patch load scripts for the defaulting rule |
| Reverse-engineer Redshift objects and connections | Setup | Agent Readiness maps objects, dependencies, and IT assets |
| Parallel per-schema migration (BU-A while BU-B tests) | Velocity | Parallel Missions per schema, each with status and logs |
| Unit, SIT, and functional testing | Repetitive | Missions generate and execute tests against expected outputs |
| GxP validation (150+ tests) | Regulated | Droid Control for repeatable, auditable, logged execution |
| UAT: screenshots per case, pass/fail tracker | Highly manual | Droid Control drives Domino, Jupyter, dashboards; auto-captures screenshots and updates the tracker |

---

## 4. Engagement phases

Factory joins the AstraZeneca room at the right moment, not prematurely. Three phases, aligned to how Vallon already frames the work.

### 4.1 Phase 1 - Migration Readiness (Agent Readiness)

- **Entry:** Target schema selected; Redshift access available.
- **Exit:** Approved readiness report with per-schema success criteria.
- **Owner:** Factory + Vallon.
- **What it does:** Reverse-engineer all Redshift objects, dependencies, and connections per schema. Produce human-reviewed validation and success criteria before any move.

### 4.2 Phase 2 - Migration Mission (Factory Missions)

- **Entry:** Readiness signed off; before/after state defined.
- **Exit:** Converted objects live and validated in Snowflake.
- **Owner:** Factory Missions.
- **What it does:** Run the SnowConvert execute-validate-fix loop and data movement per schema, in parallel, with logs. Patch null/space defaulting so tables reach 100% match.

### 4.3 Phase 3 - Acceptance (Droid Control)

- **Entry:** Migration validated; UAT scenarios listed.
- **Exit:** GxP + UAT evidence complete; sign-off.
- **Owner:** Factory + business stakeholders.
- **What it does:** Automate terminals, browsers, and desktop apps (Domino, Jupyter, dashboards) for GxP and UAT. Auto-capture screenshots per test case and update the pass/fail tracker.

### 4.4 The sharpest wedge to demo first

Data validation is already solved, so we lead with the two areas that are still manual and painful:

1. **SnowConvert run-fix-rerun loop** (Missions).
2. **UAT/GxP evidence capture** (Droid Control - screenshots and trackers across every user scenario).

This is the demo to build together for the AstraZeneca meeting.

---

## 5. Proposed repo layout

```
redshift-snowflake-migration/
  vallon_az_migration_notes.md            # source notes (copied)
  vallon_az_migration_spec.md             # this spec
  README.md                               # demo narrative + how to run
  source_redshift/                        # sample Redshift DDL/DML objects
    schemas/01_az_clinical.sql
    tables/01_patient_demographics.sql
    tables/02_trial_sites.sql
    tables/03_lab_results.sql
    views/01_active_enrollment.sql
    procedures/01_monthly_rollup.sql
    udfs/01_redshift_json_udf.sql
  snowconvert_output/                     # "converted" scripts
    clean/                                # 70-80% that pass
    broken/                               # 20-30% that fail on execution
      tables/01_patient_demographics.sql
      views/01_active_enrollment.sql
      procedures/01_monthly_rollup.sql
      udfs/01_redshift_json_udf.sql
  missions/
    phase2_snowconvert_fixloop/           # THE WEDGE
      rules/failure_patterns.md
      run_fix_rerun.md
    phase1_readiness/                     # Phase 1 spec
      readiness_spec.md
    phase3_gxp_uat/                       # Phase 3 spec
      gxp_uat_spec.md
  validation/
    metadata_match.md                     # row/col match + null/space normalization
  logs/                                   # per-object error/fix/rerun audit trail
    .gitkeep
```

---

## 6. Phase 2 - SnowConvert run-fix-rerun (the wedge)

SnowConvert converts ~70-80% automatically; the remaining 20-30% must be run, error-checked, fixed, and re-run by hand - the team's #1 time sink. A Factory Mission turns that manual run-fix-rerun loop into an automated, logged, and parallel process, and it also automates the auto-converted majority that is still executed by hand today.

### 6.1 The auto-converted 70-80%: orchestrate and execute

SnowConvert converts this cleanly, but "converting the code" and "executing the scripts in Snowflake" are still manual. Factory automates the whole pipeline:

- **Run SnowConvert at scale** - orchestrate the conversion across many objects and schemas, not object by object.
- **Bulk-execute in Snowflake** - create the converted DDL/DML objects automatically.
- **Sequence dependencies** - create objects in order (tables before views and procedures) so bulk runs don't fail on ordering.
- **Confirm clean runs** - verify each object executes without error.
- **Validate and log** - feed each object into the existing metadata match check; full audit trail for GxP.
- **Route failures onward** - anything that errors on execution drops into the remediation loop below.
- **Parallelize across BUs** - run the happy path for multiple schemas/business units concurrently.

### 6.2 What SnowConvert leaves behind (the manual 20-30%)

- **Unsupported functions** - Redshift functions with no direct Snowflake equivalent, rewritten by hand.
- **Stored procedures and procedural logic** - loops, cursors, exception handling map imperfectly to Snowflake Scripting.
- **Data type mismatches** - precision, VARCHAR sizing, timestamp/timezone, numeric scale.
- **Redshift-specific constructs** - DISTKEY/SORTKEY, ENCODE, identity columns, COPY/UNLOAD patterns.
- **Semi-structured / JSON** - SUPER/JSON vs Snowflake VARIANT and dot-notation.
- **Dynamic SQL** - runtime-generated queries a static converter can't safely rewrite.
- **Vendor / external extensions** - UDFs, Lambda UDFs, external tables / Spectrum, custom functions.
- **Performance-tuning artifacts** - Redshift optimizations that need re-architecting for Snowflake.
- **Execution-only errors** - code that "converts" but fails only when actually run in Snowflake.
- **Non-deterministic edge cases** - each object can fail for a different reason, so it does not batch cleanly.

### 6.3 How a Mission works through the remainder

1. **Ingest** - read `source_redshift/` and `snowconvert_output/`.
2. **Execute in Snowflake** - run each converted DDL/DML object in a sandboxed Snowflake session.
3. **Capture the exact error** - parse Snowflake errors with object name and line/position.
4. **Diagnose against rule set** - match errors to recurring SnowConvert failure patterns.
5. **Patch the script** - apply the fix (rewrite function, cast type, adjust syntax).
6. **Re-run until clean** - repeat execute-fix automatically until the object runs without error.
7. **Validate output** - confirm the object returns expected results, feeding the existing metadata match check.
8. **Log every step for GxP** - every error, fix, and re-run is recorded for auditability.
9. **Parallelize across schemas** - run the loop concurrently per object and business unit (BU-A while BU-B).
10. **Escalate true edge cases only** - route genuine exceptions to a human with full context attached.

### 6.4 Sample Redshift source objects

Create a small, pharma-flavored schema that mirrors the real categories of failure:

- **Tables** with Redshift-specific artifacts: `DISTKEY`, `SORTKEY`, `ENCODE`, `IDENTITY`, and a nullable `VARCHAR` that suffers from the space/null defaulting issue.
- **View** using a Redshift function or syntax that has no direct Snowflake equivalent.
- **Stored procedure** with a cursor, loop, and exception handling (procedural logic).
- **Scalar UDF** that manipulates a JSON/SUPER-style payload.

Intentional realism: the schema should look like something a clinical-trial data team would build, not a toy retail example.

### 6.5 Simulated SnowConvert output

Produce two buckets:

1. **`snowconvert_output/clean/`** - scripts that run in Snowflake without modification (the 70-80%).
2. **`snowconvert_output/broken/`** - scripts that "converted" but fail on execution (the 20-30%). The broken bucket should cover the recurring failure patterns from the notes:
   - Unsupported / non-equivalent functions.
   - Procedural logic (cursor, loop, exception handling).
   - Data type mismatches (VARCHAR sizing, timestamp/timezone, numeric scale).
   - Redshift-specific constructs (DISTKEY, SORTKEY, ENCODE, COPY/UNLOAD, identity columns).
   - Semi-structured / JSON (SUPER vs VARIANT + dot-notation).
   - Execution-only errors (valid-looking SQL that fails in Snowflake).

Each broken script should be paired with an expected error and the rule that fixes it.

### 6.6 Reusable failure-pattern rule set

`missions/phase2_snowconvert_fixloop/rules/failure_patterns.md`:

- A catalog of recurring Redshift→Snowflake execution failures.
- Each entry: symptom (exact error or pattern), root cause, patch template, and one or more example object IDs.
- Rules are ordered by frequency; the Mission tries the highest-confidence rules first.

Examples to include:

- `RS001`: Redshift `NVL` / `ISNULL` differences → Snowflake `NVL`/`IFNULL`.
- `RS002`: `DISTKEY`/`SORTKEY`/`ENCODE` clauses left in DDL → strip them.
- `RS003`: `SUPER`/`JSON` column access via dot notation → wrap in `TRY_PARSE_JSON` / `VARIANT` dot notation.
- `RS004`: `GETDATE()` / `SYSDATE` timestamp semantics → use `CURRENT_TIMESTAMP` with explicit timezone.
- `RS005`: `varchar` without length → `VARCHAR(16777216)` or explicit size.
- `RS006`: `IDENTITY` columns → `AUTOINCREMENT` / `IDENTITY` with Snowflake syntax.
- `RS007`: Stored-procedure cursor loops → rewrite to Snowflake JavaScript/Scala procedure or SQLScript.
- `RS008`: Empty Redshift field defaulting to space/null → apply normalization in load script.
- `RS009`: Execution-only error from missing object dependency → reorder via dependency graph.

### 6.7 Phase 2 Mission runbook

`missions/phase2_snowconvert_fixloop/run_fix_rerun.md`:

A concrete Mission specification that performs:

1. **Ingest** - read `source_redshift/` and `snowconvert_output/`.
2. **Build dependency graph** - tables first, then views, then procedures/UDFs.
3. **Bulk execute** - run each converted object in the dedicated Snowflake demo database (see Section 10), capturing any execution errors.
4. **Capture exact error** - object name, line/position, SQL error code, message.
5. **Diagnose** - match the error against `failure_patterns.md` rules.
6. **Patch** - apply the rule's rewrite template; escalate to human if no rule matches.
7. **Re-run** - execute the patched script.
8. **Validate** - confirm the object runs cleanly and can be checked against the metadata-match rules.
9. **Log** - write a structured record to `logs/` for every execution, error, patch, and rerun.
10. **Parallelize** - across objects and across simulated BUs.

Acceptance criteria for Phase 2 demo:
- All `clean/` scripts execute successfully on the first pass.
- All `broken/` scripts are patched and re-run until they succeed.
- Every object has an entry in `logs/` with a final `status: success`.
- The null/space normalization rule is demonstrated on at least one table.

---

## 7. Validation - null/space normalization

`validation/metadata_match.md`:

- Document the existing metadata-match approach (row counts, column alignment) and note that it is already solved by Vallon/AZ.
- Add the **null/space normalization rule** that is not yet solved:
  - Treat a Redshift empty/space value as equivalent to Snowflake `NULL` or `''` when the source column has no semantic distinction.
  - Patch the load script to apply a consistent normalization (e.g., `NULLIF(TRIM(col), '')` or `IFF(col IS NULL, ' ', col)` depending on the agreed source-of-truth).
  - Re-run the comparison to show true 100% match.
- Define the comparison logic and output format (pass/fail + mismatch count).

---

## 8. GxP audit logging

`logs/`:

Every execution attempt produces a JSON line with:

```json
{
  "timestamp": "2026-07-23T12:34:56Z",
  "schema": "clinical",
  "object": "patient_demographics",
  "object_type": "table",
  "phase": "phase2",
  "attempt": 1,
  "status": "failed",
  "error": {
    "code": "SQL compilation error",
    "message": "DISTKEY is not a valid option",
    "line": 7
  },
  "rule_applied": "RS002",
  "patch_summary": "Removed DISTKEY and SORTKEY clauses",
  "patched_sql_sha": "a1b2c3...",
  "next_attempt": 2
}
```

Final success entries are used for GxP evidence and the Phase 3 tracker.

---

## 9. Snowflake connection

### 9.1 Connection decisions (confirmed)

| Decision | Choice |
|---|---|
| Account | Existing Snowflake account |
| Authentication | Username + password |
| Credential storage | Environment variables only (no hardcoded secrets in repo) |
| Provisioning | DJ will create the demo user, role, warehouse, database, and schema |
| Target scope | Dedicated demo database/schema that can be safely dropped and recreated |

### 9.2 Snowflake objects to provision

Create a dedicated, demo-only set of objects (prefix `MIGRATION_DEMO_` or similar):

- **Role:** `MIGRATION_DEMO_ROLE`
- **Warehouse:** `MIGRATION_DEMO_WH` (auto-suspend enabled; size XS or S)
- **Database:** `MIGRATION_DEMO`
- **Schema:** `AZ_CLINICAL`
- **User:** `MIGRATION_DEMO_USER` with password stored separately and assigned to the role

Permissions:
- Role owns or has full DDL/DML rights on `MIGRATION_DEMO.AZ_CLINICAL`.
- Role can use `MIGRATION_DEMO_WH`.
- Role should not have account-level admin privileges.

### 9.3 Connection method

Use the official Snowflake Python connector (`snowflake-connector-python`) with environment variables. A connection helper will read from a `.env` file that is **gitignored**:

```python
# missions/phase2_snowconvert_fixloop/snowflake_connection.py (planned)
import os
import snowflake.connector
from dotenv import load_dotenv

load_dotenv()

conn = snowflake.connector.connect(
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD"),
    role=os.getenv("SNOWFLAKE_ROLE"),
    warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
    database=os.getenv("SNOWFLAKE_DATABASE"),
    schema=os.getenv("SNOWFLAKE_SCHEMA"),
)
```

Required environment variables (template only, no values):

```bash
# .env.example (safe to commit)
SNOWFLAKE_ACCOUNT=your_account_here
SNOWFLAKE_USER=MIGRATION_DEMO_USER
SNOWFLAKE_PASSWORD=your_password_here
SNOWFLAKE_ROLE=MIGRATION_DEMO_ROLE
SNOWFLAKE_WAREHOUSE=MIGRATION_DEMO_WH
SNOWFLAKE_DATABASE=MIGRATION_DEMO
SNOWFLAKE_SCHEMA=AZ_CLINICAL
```

### 9.4 Security rules

- `.env` is never committed.
- Real credentials are shared via 1Password / Factory secrets manager, not pasted into the repo or chat.
- The demo user is scoped to the demo database only.
- All SQL execution is logged to `logs/` for auditability.

### 9.5 Connection validation step

Before Phase 2 runs, a one-time validation script will:

1. Connect to Snowflake using the env vars.
2. Run `SELECT CURRENT_VERSION(), CURRENT_ROLE(), CURRENT_WAREHOUSE();`
3. Create the target schema if it does not exist.
4. Verify the user can create and drop a test table.
5. Write the connection test result to `logs/`.

---

## 10. Phase 1 - Migration Readiness

Before touching a schema, Factory reverse-engineers everything that exists in Redshift and everything that connects to it, then produces a human-reviewed readiness report with per-schema success criteria. This is the "before" state the migration is validated against.

### 10.1 What we map

**Objects (IT assets in Redshift):**

- Schemas, tables, views, and materialized views.
- Stored procedures, functions, UDFs (including Lambda UDFs).
- Sequences, constraints, grants, roles, and permissions.
- Per-object metadata - DDL, data types, row counts, sizes.
- Redshift-specific attributes - DISTKEY, SORTKEY, ENCODE, identity columns.
- Dependency graph - view/proc-to-table lineage and cross-schema references.

**Connections (what plugs into Redshift):**

- Upstream - ETL/ELT jobs and providers feeding raw data in.
- Downstream - Domino Data Labs, Jupyter, dashboards, pharma apps, ad hoc analytics.
- Access - users, service accounts, roles, JDBC/ODBC endpoints.
- Usage - which objects are actually queried, how often, by whom.
- Custom code - Python packages and scripts bound to the old schema.

### 10.2 Why it matters

- **Know the blast radius** - data is live and moved schema by schema; you can't safely move what isn't mapped.
- **Protect downstream** - every dependent dashboard, notebook, and app must be known before cutover.
- **Establish the "before"** - the before/after definition the migration is validated against.
- **Surface hidden connections** - undocumented links that would break at cutover.
- **Flag blockers early** - DISTKEY/SORTKEY/ENCODE and other constructs that won't translate.
- **Scope, sequence, and prove** - drive effort estimates, parallel BU ordering, and GxP evidence.

### 10.3 How a Mission does it

1. **Connect to Redshift** - query system catalogs: `information_schema`, `pg_catalog`, `pg_table_def`, `pg_views`, `pg_proc`, `svv_*`, `stl_*`, `svl_*`.
2. **Extract DDL for every object** - pull the full definition of each table, view, procedure, and function automatically.
3. **Build the dependency graph** - resolve lineage from catalog references and by parsing view and procedure definitions.
4. **Mine query history** - use `stl_query` and `svl_*` logs to find real usage and which clients and accounts connect.
5. **Enumerate connections** - inspect connection logs, ETL configs, and downstream tool configs (Domino, Jupyter, BI).
6. **Flag non-translatable constructs** - mark DISTKEY, SORTKEY, ENCODE, and identity columns as attention or blocker items.
7. **Generate the readiness report** - inventory + dependency map + connection map + risks + per-schema success criteria.
8. **Route to human review** - team validates the report; approved criteria feed Phase 2.

### 10.4 GxP note

Readiness is not validation itself (validation proves before = after, after the move). But it makes validation trustworthy, complete, and audit-defensible. Acceptance criteria must be defined before execution (21 CFR Part 11, EU Annex 11, GAMP 5). Defining pass/fail after seeing results is a data-integrity red flag. Readiness produces pre-approved, human-reviewed criteria upfront, so validation is compliant by design.

---

## 11. Phase 3 - GxP/UAT acceptance

Phase 3 is the second sharpest demo wedge. Factory uses Droid Control to automate the terminal, browser, and desktop-app interactions that currently make GxP and UAT heavy and manual.

### 11.1 What Droid Control does

- Execute test cases by driving terminals, browsers, and desktop apps (Domino, Jupyter, dashboards, pharma apps).
- Auto-capture a screenshot per test case as regulatory evidence.
- Populate the pass/fail tracker automatically across every scenario.
- Run repeatably and consistently (what regulators want).
- Enable cheap regression: rerun the whole growing suite each time a schema moves.
- Produce full audit trails/logs for Part 11 / Annex 11.
- Humans review reports only.

### 11.2 Deliverable

`missions/phase3_gxp_uat/gxp_uat_spec.md` - a spec for the Droid Control automation that covers the 150+ GxP tests and the UAT scenarios, with screenshot evidence and tracker updates.

---

## 12. Out of scope (per the notes)

- Data completeness validation tooling (already solved by their team).
- Parquet file-handling implementation details.
- Replatforming of dashboards, notebooks, or apps (owned by AZ).
- Hardcoded credentials in the repo (all Snowflake credentials are loaded from environment variables).
- Redshift-to-Snowflake data movement tooling (this demo focuses on code conversion and validation; data movement is handled separately by the existing AZ/Vallon pipeline).

---

## 13. Open questions before implementation

1. What is the Snowflake account identifier and region? (Needed for `SNOWFLAKE_ACCOUNT`.)
2. How many rows of sample data should be included to make the null/space normalization tangible?
3. Should the demo include a simple notebook/dashboard smoke test to hint at Phase 3, or stay focused on Phase 2?

---

## 14. Next steps (owner-specific)

| Owner | Action |
|---|---|
| DJ (Factory) | Provision the POC/demo account for Vallon Systems (unblocks Sumeet; billing/API-key flow changed). |
| DJ + Sumeet + Dmytro | Scope the demo - focus on UAT automation and notebook migration showcase. |
| DJ + Dmytro | Align positioning before Sumeet meets the AstraZeneca team: simplify migration readiness, execution, and UAT. |
| Sumeet (Vallon) | Q&A answers already shared; feed into demo scope. |
| Factory team | Once this spec is approved, create the directory structure and the Phase 2 assets first, then add the README and the Phase 1/3 specs. |
