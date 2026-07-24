# Phase 2 Mission - SnowConvert Run-Fix-Rerun

**The wedge.** SnowConvert auto-converts ~70-80% of objects; the remaining 20-30% "convert"
but fail when executed in Snowflake. Today AZ/Vallon runs that gap by hand - execute, read the
error, patch, re-run - object by object, schema by schema. This Mission turns that manual loop
into an automated, logged, parallel process, and also bulk-executes the auto-converted majority
that is still run by hand.

> SnowConvert's success metric is "did it convert." This Mission's is **"did it actually run
> correctly in Snowflake."**

## Inputs

- `source_postgres/` - the original source objects (the Redshift stand-in).
- `snowconvert_output/clean/` - converted objects expected to run as-is (~70-80%).
- `snowconvert_output/broken/` - converted objects that fail on execution (~20-30%).
- `missions/phase2_snowconvert_fixloop/rules/failure_patterns.md` - the reusable rule set.
- Snowflake connection via environment variables (see spec Section 9; `.env` is gitignored).

## Outputs

- All objects created and validated in the `MIGRATION_DEMO.AZ_CLINICAL` demo schema.
- A structured JSON audit record in `logs/` for every execution, error, patch, and rerun.
- An updated `failure_patterns.md` if any new pattern was escalated and resolved.

---

## Procedure

### 1. Ingest
Read `source_postgres/`, `snowconvert_output/clean/`, and `snowconvert_output/broken/`.
Build the working set of objects with type (schema, type, table, view, procedure, udf) and
source path.

### 2. Build the dependency graph
Resolve create-order from catalog references and by parsing view/procedure bodies:
**types/tables -> views -> procedures/UDFs.** This pre-empts RS009 (missing-dependency
execution errors) on bulk runs and defines parallelizable, independent branches.

### 3. Bulk execute (happy path first)
Execute every `clean/` object in dependency order in the demo schema. Confirm each returns no
error. This is the 70-80% that is correct but still run by hand today - here it is orchestrated
and executed automatically. Anything that unexpectedly errors drops into the loop below.

### 4. Capture the exact error
For each failing object record: object name, object type, line/position, SQL error code, and
the full message. Write a `status: failed` entry to `logs/`.

### 5. Diagnose against the rule set
Match the error signature to `failure_patterns.md`. Select the highest-confidence rule
(`RS001`..`RS012`). If no rule matches, **escalate to a human** with full context and pause
that object only (siblings keep moving).

### 6. Patch
Apply the rule's patch template to produce a corrected script. Record `rule_applied`,
`patch_summary`, and the SHA of the patched SQL. A single object may need several rules in
sequence (e.g. `PATIENT_DEMOGRAPHICS` needs RS002 + RS005 + RS004).

### 7. Re-run until clean
Execute the patched script. If it fails on a *different* signature, return to step 4 (new
attempt, incremented `attempt`). Repeat until the object executes without error or the retry
ceiling is hit and it escalates.

### 8. Validate output
Confirm the object exists and behaves: DDL objects resolve; views select; procedures/UDFs
execute against seed data. Feed row/column results into the metadata-match check
(`validation/metadata_match.md`), including the RS008 null/space normalization.

### 9. Log every step for GxP
Every attempt (clean pass, failure, patch, rerun, final success) emits one JSON line to
`logs/`. The final `status: success` records are the evidence trail Phase 3 consumes.

### 10. Parallelize across schemas / BUs
Run independent dependency branches and independent schemas/business units concurrently
(BU-A while BU-B), each with its own status and logs. This mirrors the parallel per-BU
migration model.

---

## Worked examples (from `snowconvert_output/broken/`)

| Object | Attempt 1 error | Rule(s) | Patch | Result |
|--------|-----------------|---------|-------|--------|
| `types/01_enums.sql` | Unsupported `CREATE TYPE ... AS ENUM` | RS010 | Drop types; move to VARCHAR+CHECK on columns | success |
| `tables/01_studies.sql` | syntax error at `DISTSTYLE` | RS002 | Strip DISTSTYLE/SORTKEY | success |
| `tables/02_patient_demographics.sql` | syntax error at `ENCODE` | RS002, RS005, RS004 | Strip ENCODE/DISTKEY/SORTKEY; `VARCHAR(MAX)`->`VARCHAR(16777216)`; `SYSDATE`->`CURRENT_TIMESTAMP()` | success |
| `tables/03_trial_sites.sql` | invalid type `SITE_STATUS` | RS010, RS011 | Enum->VARCHAR+CHECK; `VARCHAR[]`->`ARRAY` | success |
| `views/01_active_enrollment.sql` | syntax error at `->>` | RS003 (RS009 order) | `col->>'k'`->`col:k::string`; run after base tables | success |
| `views/02_lab_results_with_metadata.sql` | syntax error at `->>` | RS003 | VARIANT path rewrite | success |
| `views/03_arm_labels.sql` | too many arguments for `NVL` | RS001 | `NVL(3-arg)`->`COALESCE` | success |
| `procedures/01_monthly_rollup.sql` | syntax error at `RECORD`/`::` | RS007 | Cursor loop -> set-based `INSERT ... SELECT` | success |
| `procedures/02_screening_enrollment_report.sql` | syntax error at `FILTER` | RS007, RS012 | `COUNT(*) FILTER`->`COUNT_IF`; rewrite cursor/exception | success |
| `udfs/01_parse_patient_json.sql` | syntax error at `BEGIN`/`->>` | RS007, RS003 | Collapse to single expression `PAYLOAD:KEY::string` | success |

## Acceptance criteria (Phase 2 demo)

- [x] All `clean/` scripts execute successfully on the first pass. (Milestone 1: 6 clean objects + 3 base tables live in `MIGRATION_DEMO.AZ_CLINICAL`.)
- [x] All `broken/` scripts are patched and re-run until they succeed. (Milestone 2: 10 objects captured real errors, patched per RS rules, reran green; fixed SQL in `snowconvert_output/fixed/`.)
- [x] Every object has a `logs/` entry with a final `status: success`. (See `logs/phase2_run.jsonl`; capture rows carry `status: error`, patch/rerun rows `status: success`.)
- [x] The null/space normalization rule (RS008) is demonstrated on at least one table. (`PATIENT_DEMOGRAPHICS.NOTES`: 2 of 5 space/empty values normalized to NULL via `NULLIF(TRIM(col),'')`.)
- [x] Any escalated pattern that gets resolved is written back into `failure_patterns.md`. (No new escalations; all 10 failures matched existing rules RS001-RS012.)

### Run result (executed live)

- Validation Gate 1 (clean 70% + base): PASS - INVESTIGATORS=5, TREATMENT_ARMS=5, VISIT_WINDOWS=4, DEMOGRAPHICS=10, PATIENTS=10, VISITS=10, LAB_RESULTS=10; view ACTIVE_TREATMENT_ARMS returns 2 rows.
- Validation Gate 2 (broken 30% fix-loop): PASS - views ARM_LABELS=5 / ACTIVE_ENROLLMENT=2 / LAB_RESULTS_WITH_METADATA=10; procs populated MONTHLY_LAB_ROLLUP=5 / SCREENING_ENROLLMENT_SUMMARY=3; UDF PARSE_PATIENT_JSON returns VARIANT path values; final inventory 12 tables / 4 views / 2 procedures / 1 function.
- Rules exercised: RS001 (NVL), RS002 (DISTSTYLE/ENCODE/SORTKEY/DISTKEY), RS003 (`->>`), RS004 (SYSDATE), RS005 (VARCHAR(MAX)), RS007 (cursor/RECORD/scalar-UDF body), RS009 (dependency order), RS010 (ENUM), RS011 (TEXT[]), RS012 (FILTER).

## Notes on the demo ratio

The `broken/` bucket here is intentionally dense so every recurring failure class is visible in
one runnable demo. In a live schema the ratio tracks the real ~70-80% clean / ~20-30% broken
split; the same loop and rule set apply unchanged.
