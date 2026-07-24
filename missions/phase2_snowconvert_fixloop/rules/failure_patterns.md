# SnowConvert Execution Failure Patterns (Reusable Rule Set)

The Phase 2 Mission uses this catalog to diagnose and patch converted objects that
"compiled" out of SnowConvert but fail when actually executed in Snowflake. Rules are
ordered by frequency; the Mission tries the highest-confidence rule for a given error
signature first. Each rule carries a symptom, root cause, patch template, and the example
object(s) in `snowconvert_output/broken/` that it fixes.

> Success metric: **"did it actually run correctly in Snowflake"**, not "did it convert".

| Rule | Failure class | Blocking? | Example object(s) |
|------|---------------|-----------|-------------------|
| RS001 | Multi-arg `NVL` | Yes | `views/03_arm_labels.sql` |
| RS002 | Redshift storage clauses (`DISTSTYLE`/`DISTKEY`/`SORTKEY`/`ENCODE`) | Yes | `tables/01_studies.sql`, `tables/02_patient_demographics.sql` |
| RS003 | JSON/SUPER `->>` dot-notation | Yes | `views/01_active_enrollment.sql`, `views/02_lab_results_with_metadata.sql`, `udfs/01_parse_patient_json.sql` |
| RS004 | `SYSDATE` / `GETDATE()` timestamp semantics | Yes | `tables/02_patient_demographics.sql` |
| RS005 | `VARCHAR(MAX)` / unbounded VARCHAR | Yes | `tables/02_patient_demographics.sql` |
| RS006 | Identity column standardization | No (standardize) | `tables/*` |
| RS007 | Procedural logic (cursor / loop / exception) | Yes | `procedures/01_monthly_rollup.sql`, `procedures/02_screening_enrollment_report.sql`, `udfs/01_parse_patient_json.sql` |
| RS008 | Empty field space/null defaulting | Yes (validation) | `tables/02_patient_demographics.sql` (`NOTES`) |
| RS009 | Missing object dependency at execution | Yes | `views/01_active_enrollment.sql`, `views/02_lab_results_with_metadata.sql` |
| RS010 | `CREATE TYPE ... AS ENUM` unsupported | Yes | `types/01_enums.sql`, `tables/03_trial_sites.sql` |
| RS011 | Array/composite column types (`TEXT[]`) | Yes | `tables/03_trial_sites.sql` |
| RS012 | `COUNT(*) FILTER (WHERE ...)` clause | Yes | `procedures/02_screening_enrollment_report.sql` |

---

## RS001 - Multi-argument NVL

- **Symptom:** `too many arguments for function 'NVL'`.
- **Root cause:** Redshift `NVL` accepts 3+ arguments (alias for `COALESCE`); Snowflake `NVL` takes exactly 2.
- **Patch template:** Rewrite `NVL(a, b, c, ...)` -> `COALESCE(a, b, c, ...)`.
- **Example:** `NVL(ARM_NAME, DOSAGE, 'UNSPECIFIED')` -> `COALESCE(ARM_NAME, DOSAGE, 'UNSPECIFIED')`.

## RS002 - Redshift storage clauses left in DDL

- **Symptom:** `syntax error line N at 'DISTSTYLE' | 'DISTKEY' | 'SORTKEY' | 'ENCODE'`.
- **Root cause:** Redshift physical-storage directives have no Snowflake equivalent (Snowflake manages micro-partitions automatically).
- **Patch template:**
  - Strip trailing `DISTSTYLE {ALL|EVEN|KEY}`, `DISTKEY (col)`, `SORTKEY (cols)`.
  - Strip inline column `ENCODE <codec>`.
  - Preserve column definitions, PK/UNIQUE, and defaults.
- **Example:** remove `DISTSTYLE ALL / SORTKEY (STUDY_ID)` from `STUDIES`; remove `ENCODE LZO` from `PATIENT_DEMOGRAPHICS` name columns.

## RS003 - JSON/SUPER dot-notation

- **Symptom:** `syntax error ... at '->>'` (or wrong result type on `->`).
- **Root cause:** Postgres/Redshift `->>` (text) and `->` (json) operators do not exist in Snowflake; Snowflake uses `VARIANT` path access.
- **Patch template:**
  - `col->>'key'` -> `col:key::string`  (or `GET_PATH(col, 'key')::string`).
  - `col->'key'`  -> `col:key`.
  - Ensure the column is typed `VARIANT`; wrap raw strings with `TRY_PARSE_JSON(col)` if needed.
- **Example:** `STRATIFICATION->>'region'` -> `STRATIFICATION:region::string`.

## RS004 - SYSDATE / GETDATE timestamp semantics

- **Symptom:** `invalid identifier 'SYSDATE'` when used without parentheses as a default.
- **Root cause:** Redshift `SYSDATE` is a bare keyword; Snowflake requires a function call.
- **Patch template:** `DEFAULT SYSDATE` -> `DEFAULT CURRENT_TIMESTAMP()`; `GETDATE()` -> `CURRENT_TIMESTAMP()`; add explicit timezone (`TIMESTAMP_TZ`) only where the source is timezone-aware.
- **Example:** `CREATED_AT ... DEFAULT SYSDATE` -> `CREATED_AT ... DEFAULT CURRENT_TIMESTAMP()`.

## RS005 - VARCHAR(MAX) / unbounded VARCHAR

- **Symptom:** `syntax error ... at 'MAX'` for `VARCHAR(MAX)`.
- **Root cause:** Redshift supports `VARCHAR(MAX)`; Snowflake does not.
- **Patch template:** `VARCHAR(MAX)` -> `VARCHAR(16777216)` (Snowflake max) or an explicit business-appropriate size. A bare `VARCHAR` is valid in Snowflake (defaults to max) but should be normalized to an explicit size for parity checks.
- **Example:** `NOTES VARCHAR(MAX)` -> `NOTES VARCHAR(16777216)`.

## RS006 - Identity column standardization (non-blocking)

- **Symptom:** none at execution; `IDENTITY(seed, step)` runs in Snowflake.
- **Root cause:** SnowConvert may emit varying identity syntaxes; teams standardize for readability and parity.
- **Patch template:** normalize to `INTEGER IDENTITY(1,1)` (or `AUTOINCREMENT START 1 INCREMENT 1`) consistently across tables.
- **Note:** Flagged for consistency; does not block execution.

## RS007 - Procedural logic (cursor / loop / exception)

- **Symptom:** `syntax error at 'RECORD' | 'FOR' | 'LOOP' | 'RAISE' | 'EXCEPTION'`, or `unsupported language`.
- **Root cause:** plpgsql cursor loops, `RECORD` variables, `::` casts, `RAISE NOTICE`, and per-row `EXCEPTION` blocks are not valid Snowflake Scripting; scalar UDFs cannot contain a procedural body at all.
- **Patch template:**
  - Prefer **set-based rewrite**: replace the cursor `FOR..LOOP` + row `INSERT` with a single `INSERT ... SELECT`.
  - Where control flow is required, rewrite to Snowflake Scripting: `DECLARE c CURSOR FOR ...; FOR r IN c DO ... END FOR;` with `:r.col` bind syntax and `LET` variables.
  - Replace `::type` casts with `CAST(expr AS type)`.
  - Replace `RAISE NOTICE` with a logging `INSERT` to `logs`; keep `RAISE EXCEPTION` as Snowflake `RAISE`.
  - For scalar UDFs, collapse `BEGIN ... EXCEPTION ... END` to a single expression (see RS003).
- **Example:** `MONTHLY_ROLLUP` cursor loop -> `INSERT INTO MONTHLY_LAB_ROLLUP SELECT ... GROUP BY ...`.

## RS008 - Empty field space/null defaulting

- **Symptom:** metadata match reports a mismatch on a nullable text column even though data is "the same".
- **Root cause:** Redshift defaults empty fields to a space `' '` or null depending on export path; Snowflake load lands it as `NULL`/`''`, so `' ' != NULL` fails the 100% comparison.
- **Patch template (load script):** apply a consistent normalization to the agreed source of truth, e.g. `NULLIF(TRIM(col), '')` on load, or `IFF(col IS NULL, ' ', col)` if space is canonical. Re-run the comparison to confirm true 100% match.
- **Example:** `PATIENT_DEMOGRAPHICS.NOTES`. See `validation/metadata_match.md`.

## RS009 - Missing object dependency at execution

- **Symptom:** `Object 'AZ_CLINICAL.PATIENTS' does not exist or not authorized` when creating a view/proc.
- **Root cause:** bulk execution ran objects out of dependency order (view before its base tables).
- **Patch template:** build a dependency graph and execute in order: types/tables -> views -> procedures/UDFs. Re-queue the failed object after its dependencies succeed.
- **Example:** `ACTIVE_ENROLLMENT` and `LAB_RESULTS_WITH_METADATA` must run after their base tables.

## RS010 - CREATE TYPE ... AS ENUM unsupported

- **Symptom:** `Unsupported feature 'CREATE TYPE'`; or `invalid type 'AZ_CLINICAL.SITE_STATUS'` when a column references the enum.
- **Root cause:** Snowflake has no ENUM type.
- **Patch template:**
  - Drop the `CREATE TYPE ... AS ENUM` statements.
  - Replace column type `AZ_CLINICAL.<enum>` with `VARCHAR(n)` plus a `CHECK (col IN (...))` constraint (or a reference lookup table).
- **Example:** `STATUS AZ_CLINICAL.SITE_STATUS` -> `STATUS VARCHAR(20) NOT NULL DEFAULT 'Initiating' CHECK (STATUS IN ('Initiating','Active','Inactive','Closed'))`.

## RS011 - Array / composite column types

- **Symptom:** `syntax error ... at '['` for `VARCHAR(...)[]` / `TEXT[]`.
- **Root cause:** Postgres/Redshift array column syntax is not valid Snowflake DDL.
- **Patch template:** `<type>[]` -> `ARRAY` (store as VARIANT array); adjust load to `ARRAY_CONSTRUCT(...)` / `SPLIT(...)`.
- **Example:** `CONTACT_EMAILS VARCHAR(16777216)[]` -> `CONTACT_EMAILS ARRAY`.

## RS012 - Aggregate FILTER clause

- **Symptom:** `syntax error ... at 'FILTER'`.
- **Root cause:** Snowflake does not support the SQL-standard `agg(...) FILTER (WHERE cond)` clause.
- **Patch template:**
  - `COUNT(*) FILTER (WHERE cond)` -> `COUNT_IF(cond)`.
  - `SUM(x) FILTER (WHERE cond)` -> `SUM(CASE WHEN cond THEN x END)`.
- **Example:** `COUNT(*) FILTER (WHERE p.STATUS IN ('Screening','Screen Failed'))` -> `COUNT_IF(p.STATUS IN ('Screening','Screen Failed'))`.

---

## Adding a new rule

When the Mission hits an error signature no rule matches, it escalates to a human with full
context (object, line, SQL error code, message). The resolved fix is then captured here as a
new `RSNNN` entry - symptom, root cause, patch template, example - so the next occurrence is
auto-diagnosed. The rule set is the compounding asset of the engagement.
