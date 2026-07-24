# Validation - Metadata Match & Null/Space Normalization

This validation confirms that migrated objects in Snowflake match the source, row for row and
column for column. It is the check that turns "the object runs" into "the object runs
**correctly**."

## What is already solved (do not sell into this)

AZ/Vallon already own the core completeness check: a Snowflake metadata script produces a
spreadsheet of **row counts and column alignment**, reaching 100% match with very little manual
work. Parquet was chosen for data movement to avoid newline/pipe/format issues. This spec
documents that baseline and layers on the one gap that is **not** yet solved.

### Baseline comparison (existing)

For each migrated table:

- **Row count parity:** `COUNT(*)` in source == `COUNT(*)` in Snowflake.
- **Column alignment:** column names, order, and mapped data types match the agreed mapping
  (e.g. `NUMERIC`->`NUMBER`, `JSONB`->`VARIANT`, `TIMESTAMP`->`TIMESTAMP_NTZ`).
- **Output:** pass/fail per table plus a mismatch count.

---

## The unsolved gap - Redshift null/space defaulting (RS008)

### Problem

Redshift defaults empty fields to a **space (`' '`)** or **null**, depending on the column and
export path. Snowflake load scripts don't account for that defaulting, so a value that is
semantically "empty" lands inconsistently:

```
Redshift " "  ->  Snowflake NULL  or  ""     ->   comparison  " " != NULL   FAILS
```

Parquet dodges format issues but **not** this one, because it is about the *semantics of
emptiness*, not the file format. The result: the comparison script flags a mismatch even though
the data is effectively identical. This is the edge case that breaks the otherwise-100% match.

### Demonstration column

`snowconvert_output/broken/tables/02_patient_demographics.sql` -> `NOTES VARCHAR` (and the
`NOTES` columns on `TRIAL_SITES` / `LAB_RESULTS` in source). These nullable free-text columns
are where the space/null defaulting surfaces.

### Fix - consistent normalization on load

Agree a single source of truth for "empty," then normalize both sides before comparing. Two
canonical options:

- **Empty == NULL (recommended default):**
  ```sql
  NULLIF(TRIM(col), '')   -- ' ' and '' both become NULL
  ```
- **Space is canonical (only if the business requires a literal space):**
  ```sql
  IFF(col IS NULL OR TRIM(col) = '', ' ', col)
  ```

Apply the chosen rule in the **load script** for the affected columns, reload, and re-run the
comparison. The Mission (Phase 2) detects these systematic discrepancies and patches the load
script automatically rather than hand-fixing per column.

### Comparison logic

Normalize both source and target with the same rule, then compare:

```sql
-- Per-column mismatch count after normalization
SELECT COUNT(*) AS mismatch_count
FROM source_tbl s
FULL OUTER JOIN target_tbl t
  ON s.patient_id = t.patient_id
WHERE NULLIF(TRIM(s.notes), '') IS DISTINCT FROM NULLIF(TRIM(t.notes), '');
```

- `mismatch_count = 0` -> column passes.
- `mismatch_count > 0` -> fail; emit the offending keys for review.

### Output format

| table | column | rows_source | rows_target | mismatches_before | rule | mismatches_after | status |
|-------|--------|-------------|-------------|-------------------|------|------------------|--------|
| patient_demographics | notes | 5000 | 5000 | 143 | RS008 (`NULLIF(TRIM(col),'')`) | 0 | pass |

The `before -> after` columns make the fix auditable: they show the mismatch existed, which rule
resolved it, and that the table reached true 100% match. Every run is logged to `logs/` for GxP
evidence and feeds the Phase 3 tracker.

## Relationship to Phase 2

Metadata match is step 8 of the Phase 2 Mission (`run_fix_rerun.md`). An object is not "done"
when it merely executes - it is done when it executes **and** matches the source under the
agreed normalization rules.
