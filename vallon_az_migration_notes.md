# Vallon Systems x Factory - AstraZeneca Migration Notes

Working notes from the discussion. Source: "Quick Connect on AZ Data Migration Usecase" call (10 Jul 2026, DJ + Dmytro + Sumeet) and Sumeet's follow-up Q&A email.

Companion one-pager: `vallon_az_migration_onepager.html`

---

## 1. Current state (how AZ/Vallon runs the migration today)

- Live Redshift -> Snowflake migration, done schema by schema.
- Run as parallel mini-processes (BU-A tests while BU-B moves) to maximize velocity.
- Two workstreams:
  - Data migration: export to Parquet, ingest into Snowflake.
  - Code conversion: SnowConvert (~70-80% automated, remainder manual).
- Seven-stage pipeline per unit of work:
  1. SnowConvert DDL/DML conversion
  2. Unit testing
  3. System integration testing (SIT)
  4. Functional testing
  5. Historical data backfill and validation
  6. GxP validation (150+ tests)
  7. UAT (screenshots per test case, pass/fail tracker)
- Upstream/downstream: Domino Data Labs, Jupyter, dashboards, pharma apps, ad hoc analytics.

## 2. Already solved by their team (do NOT sell into these)

- Data completeness validation - Snowflake metadata script outputs a spreadsheet (row counts, column alignment), reaching 100% match. Very little manual checking.
- File handling - Parquet chosen to avoid newline/pipe issues and messy Redshift defaults.
- Business logic - defined by users; raw provider data ingested as-is.
- Replatforming (dashboards, notebooks, apps) - owned by the AstraZeneca customer, not Vallon.

## 3. Where the pain still is

- SnowConvert remediation: run scripts, catch errors, fix, rerun (the #1 time sink).
- Manual orchestration: running conversion and executing scripts in Snowflake is manual ("but we can automate them").
- Redshift null/space defaulting breaking 100% table match.
- GxP (150+ tests) + UAT (screenshots, tracker across every scenario) - heavy, regulated, manual.

---

## 4. The null/space error

- Redshift defaults empty fields to a space (" ") or null, depending on column/export path.
- Snowflake load scripts don't account for that defaulting, so a space can land as null or empty string (and vice versa).
- Result: source vs target don't match 100%; the validation script flags a mismatch even though the data is effectively the same.
- Example: Redshift `" "` -> Snowflake `NULL` or `""` -> comparison `" " != NULL` fails.
- Parquet dodges format issues (newlines, pipes) but not this, because it's about the semantics of emptiness.
- Factory fix: a Mission detects these systematic discrepancies and patches the load scripts with a consistent normalization rule so tables reach true 100% match.

---

## 5. SnowConvert remediation - why it's the #1 issue

- SnowConvert auto-converts ~70-80%; the remaining 20-30% must be run, error-checked, fixed, re-run by hand.
- "Convert" is not "runs correctly" - converted scripts still error when actually executed in Snowflake.
- It's a manual run-fix-rerun loop, per object, repeated until it passes.
- The slow part is validating that scripts run correctly in Snowflake, not the conversion itself.
- Scale multiplies it: schema-by-schema across many BUs = hundreds of objects, each potentially needing the loop.
- It's a serial bottleneck gating how fast a schema moves through the pipeline.

### What SnowConvert leaves behind (the manual 20-30%)

- Unsupported / non-equivalent functions (no direct Snowflake equivalent).
- Stored procedures & procedural logic (loops, cursors, exception handling).
- Data type mismatches (precision, VARCHAR sizing, timestamp/timezone, numeric scale).
- Redshift-specific constructs (DISTKEY, SORTKEY, ENCODE/compression, identity columns, COPY/UNLOAD).
- Semi-structured / JSON (Redshift SUPER/JSON vs Snowflake VARIANT + dot-notation).
- Dynamic SQL / runtime-generated queries.
- Vendor / external extensions (UDFs, Lambda UDFs, external tables / Spectrum).
- Performance-tuning artifacts (need re-architecting for Snowflake's model).
- Execution-only errors ("converts" but fails only when actually run).
- Non-deterministic edge cases (each object can fail for a different reason; doesn't batch cleanly).

## 6. How Factory specifically solves SnowConvert - the WHOLE pipeline

### The auto-converted 70-80% (orchestrate + execute; still manual today)

- Run SnowConvert at scale (orchestrate across many objects/schemas, not object by object).
- Bulk-execute converted DDL/DML objects in Snowflake automatically.
- Sequence dependencies (tables before views/procedures) so bulk runs don't fail on ordering.
- Confirm clean runs - verify each object executes without error.
- Validate output against the existing metadata match check; log everything for GxP.
- Route any execution failures into the remediation loop below.
- Parallelize across business units (BU-A while BU-B).

### The manual 20-30% (diagnose-patch-rerun loop)

1. Ingest conversion output (SnowConvert scripts + source Redshift objects).
2. Execute each converted object in a sandboxed Snowflake session.
3. Capture the exact Snowflake error (object + line).
4. Diagnose against a reusable rule set of recurring failure patterns.
5. Patch the script (rewrite function, cast type, fix syntax).
6. Re-run until it executes cleanly.
7. Validate output, feeding the existing metadata match check.
8. Log every error/fix/re-run for GxP auditability.
9. Parallelize across objects and business units.
10. Escalate only true edge cases to a human, with full context.

Net: Factory automates the entire conversion pipeline end to end, not just the hard 20-30%.

Key differentiator: SnowConvert's success metric is "did it convert." Factory's is "did it actually run correctly in Snowflake." That gap is exactly Sumeet's pain.

---

## 7. Migration Readiness - reverse-engineer Redshift objects and connections (Phase 1)

### What we map

Objects (IT assets in Redshift):
- Schemas, tables, views, materialized views.
- Stored procedures, functions, UDFs (incl. Lambda UDFs).
- Sequences, constraints, grants/roles/permissions.
- Per-object metadata: DDL, data types, row counts, sizes.
- Redshift-specific attributes: DISTKEY, SORTKEY, ENCODE, identity columns.
- Dependency graph: view/proc-to-table lineage, cross-schema references.

Connections (what plugs into Redshift):
- Upstream: ETL/ELT jobs and providers feeding raw data in.
- Downstream: Domino Data Labs, Jupyter, dashboards, pharma apps, ad hoc analytics.
- Access: users, service accounts, roles, JDBC/ODBC endpoints, connection strings.
- Usage: which objects are actually queried, how often, by whom.
- Custom code: Python packages/scripts bound to the old schema.

### Why we do it

- Know the blast radius (live data, moved schema by schema).
- Protect downstream (every dependent dashboard/notebook/app must be known before cutover).
- Establish the "before" state for before/after validation.
- Define per-schema success criteria (the explicit output of Mission 1).
- Surface hidden/undocumented connections that would break at cutover.
- Flag non-translatable constructs early (DISTKEY/SORTKEY/ENCODE).
- Scope and sequence the work; produce GxP evidence.

### How a Mission does it

1. Connect to Redshift; query system catalogs (information_schema, pg_catalog, pg_table_def, pg_views, pg_proc, svv_/stl_/svl_).
2. Extract DDL for every object.
3. Build the dependency graph (catalog references + parsing view/proc definitions).
4. Mine query history (stl_query, svl_) for real usage and connecting clients.
5. Enumerate connections (connection logs, ETL configs, downstream tool configs).
6. Flag non-translatable constructs as attention/blocker items.
7. Generate the readiness report (inventory + dependency map + connection map + risks + criteria).
8. Route to human review; approved criteria feed Phase 2.

### Does readiness-first make it "more validated"?

- Readiness is not validation itself (validation proves before = after, after the move).
- But it makes validation trustworthy, complete, and audit-defensible:
  - Defines the baseline and the completeness bar you validate against.
  - Surfaces hidden dependencies and blockers early (fewer late failures).
- GxP nuance (the real point): acceptance criteria must be defined BEFORE execution (21 CFR Part 11, EU Annex 11, GAMP 5). Defining pass/fail after seeing results is a data-integrity red flag. Readiness produces those pre-approved, human-reviewed criteria upfront, so validation is compliant by design.
- Gives the traceability chain auditors want: documented "before" -> defined criteria -> executed tests -> evidence.

---

## 8. GxP validation (150+ tests)

### What it is

- GxP = "Good x Practice" (GMP, GLP, GCP, GDP) - FDA/EMA-regulated quality standards for pharma.
- For a migration: proving the migrated system is validated (data/outputs correct, complete, traceable, reproducible).
- Governed by 21 CFR Part 11, EU Annex 11, GAMP 5 (computer system validation).
- Anchored on data integrity / ALCOA+ principles.

### What the 150+ tests are

- Documented test cases, each with expected result, actual result, pass/fail, and screenshot evidence.
- Typically validate: data completeness/accuracy, business/functional correctness, access controls/security, audit trails, reproducibility.
- Output: a tracker doc with per-test pass/fail plus screenshots for every user scenario.

### Will it grow? Yes

- More scope = more tests (each schema, BU, and downstream app adds cases).
- Regression pressure: the suite re-runs on every change/release, so execution volume compounds.
- 150+ is a baseline, not a ceiling.

### How Factory uses it (Phase 3 - Droid Control)

- Executes test cases by driving terminals, browsers, desktop apps (Domino, Jupyter, dashboards, pharma apps).
- Auto-captures a screenshot per test case as regulatory evidence.
- Populates the pass/fail tracker automatically across every scenario.
- Runs repeatably and consistently (what regulators want).
- Cheap regression: rerun the whole growing suite each time a schema moves.
- Full audit trail/logs for Part 11 / Annex 11.
- Humans review reports only (Dmytro's "near-full automation" case).

---

## 9. The engagement plan (3 phases)

- Phase 1 - Migration Readiness (Agent Readiness): reverse-engineer Redshift objects/connections/assets -> human-reviewed success criteria.
- Phase 2 - Migration Mission (Factory Missions): SnowConvert execute-validate-fix loop + data movement per schema, in parallel, with logs; patch null/space defaulting.
- Phase 3 - Acceptance (Droid Control): automate terminals/browsers/desktop apps for GxP + UAT; auto-capture screenshots and update the tracker.

Factory joins the AstraZeneca room at the right moment, not prematurely.

### The sharpest wedge to demo first

- SnowConvert run-fix-rerun automation (Missions).
- UAT/GxP evidence capture (Droid Control - screenshots + trackers).
- Data validation is off the table (already solved).

## 10. Next steps (owners)

- DJ (Factory): provision the POC/demo account for Vallon Systems (unblocks Sumeet - billing/API-key flow changed).
- DJ + Sumeet + Dmytro: scope the demo (UAT automation + notebook migration showcase).
- DJ + Dmytro: align positioning before Sumeet meets the AstraZeneca team.
- Sumeet (Vallon): Q&A answers shared (done) -> feed into demo scope.
