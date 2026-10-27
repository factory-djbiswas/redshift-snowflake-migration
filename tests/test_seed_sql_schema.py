"""Cross-check the generated seed SQL against the source Postgres DDL.

``scripts/run_postgres.sh`` creates the schema from ``source_postgres/`` and then
loads ``scripts/seed_data.sql``. Nothing in the repository verified that the two
still agree, so a renamed column or a dropped table only surfaced when ``psql``
failed mid-demo. These tests parse both sides and assert:

* every INSERT targets a table defined in ``source_postgres/``,
* every inserted column exists on that table,
* each row supplies exactly one value per listed column,
* NOT NULL columns never receive a NULL,
* columns typed as a custom ``az_clinical`` enum only receive declared enum values,
* columns with an inline ``CHECK (col IN (...))`` list only receive listed values,
* foreign keys resolve to rows the seed file inserts, and
* PRIMARY KEY / UNIQUE constraints hold for the seeded rows.

The schema is read from exactly the files ``scripts/run_postgres.sh`` executes, so the
tests follow the demo instead of every ``.sql`` file in the tree (the repository also
carries stale duplicate table definitions the runner no longer loads).
"""

import re

import pytest

from sql_utils import (
    literal_to_python,
    parse_enum_column_references,
    parse_enums,
    parse_insert_statements,
    parse_table_columns,
    parse_unique_constraints,
)

# Inline CHECK constraints that the demo relies on but which are not modelled as
# custom enum types, keyed by (table, column) with the values from the DDL.
INLINE_CHECK_DOMAINS = {
    ("demographics", "sex"): {"M", "F", "U", "O"},
    ("validation_rules", "rule_type"): {"RANGE", "NOT_NULL", "UNIQUE", "FORMAT", "CUSTOM"},
    ("audit_trail", "operation"): {"INSERT", "UPDATE", "DELETE"},
}


@pytest.fixture(scope="module")
def schema(schema_sql_files):
    return parse_table_columns(schema_sql_files)


@pytest.fixture(scope="module")
def enums(types_sql_file):
    return parse_enums(types_sql_file)


@pytest.fixture(scope="module")
def statements(generated_seed_sql):
    return parse_insert_statements(generated_seed_sql)


def test_every_insert_targets_a_defined_table(statements, schema):
    unknown = sorted({s["table"] for s in statements} - set(schema))
    assert not unknown, f"seed data writes to undefined tables: {unknown}"


def test_every_inserted_column_exists_on_its_table(statements, schema):
    problems = []
    for statement in statements:
        known = schema.get(statement["table"], {})
        missing = [c for c in statement["columns"] if c.lower() not in known]
        if missing:
            problems.append((statement["table"], missing))
    assert not problems, f"seed data references unknown columns: {problems}"


def test_each_row_supplies_one_value_per_column(statements):
    mismatched = [
        (s["table"], len(s["columns"]), len(s["values"]))
        for s in statements
        if len(s["columns"]) != len(s["values"])
    ]
    assert not mismatched, f"column/value arity mismatch: {mismatched[:5]}"


def test_not_null_columns_never_receive_null(statements, schema):
    violations = []
    for statement in statements:
        known = schema[statement["table"]]
        for column, value in zip(statement["columns"], statement["values"]):
            meta = known.get(column.lower())
            if meta is None or not meta["not_null"]:
                continue
            if literal_to_python(value) is None:
                violations.append((statement["table"], column))
    assert not violations, f"NULL written to NOT NULL columns: {sorted(set(violations))}"


def test_enum_columns_only_receive_declared_values(statements, schema_sql_files, enums):
    references = parse_enum_column_references(schema_sql_files, enums)
    assert references, "expected the DDL to declare at least one az_clinical enum column"

    violations = []
    checked = 0
    for statement in statements:
        for column, value in zip(statement["columns"], statement["values"]):
            enum_name = references.get((statement["table"], column.lower()))
            if enum_name is None:
                continue
            checked += 1
            resolved = literal_to_python(value)
            if resolved not in enums[enum_name]:
                violations.append(
                    (statement["table"], column, resolved, enum_name)
                )
    assert checked > 0, "no seeded values were checked against an enum type"
    assert not violations, f"values outside the declared enum: {sorted(set(violations))[:5]}"


def test_inline_check_constraint_columns_only_receive_allowed_values(statements, schema):
    violations = []
    for statement in statements:
        for column, value in zip(statement["columns"], statement["values"]):
            allowed = INLINE_CHECK_DOMAINS.get((statement["table"], column.lower()))
            if allowed is None:
                continue
            if column.lower() not in schema[statement["table"]]:
                continue
            resolved = literal_to_python(value)
            if resolved not in allowed:
                violations.append((statement["table"], column, resolved))
    assert not violations, f"values outside an inline CHECK constraint: {sorted(set(violations))[:5]}"


def test_required_columns_are_marked_not_null_in_the_ddl(schema):
    """Guard against the DDL changing under the seeded demo dataset."""
    assert schema["demographics"]["sex"]["not_null"]
    assert schema["studies"]["phase"]["not_null"]
    assert schema["studies"]["study_code"]["not_null"]
    assert schema["trial_sites"]["status"]["not_null"]
    assert schema["lab_results"]["result_value"]["not_null"]
    assert "notes" in schema["trial_sites"]
    assert not schema["trial_sites"]["notes"]["not_null"]


def test_ddl_declares_the_tables_the_demo_reports_on(statements, schema):
    expected = {
        "studies",
        "treatment_arms",
        "investigators",
        "trial_sites",
        "patients",
        "demographics",
        "visit_windows",
        "visits",
        "vital_signs",
        "lab_results",
        "adverse_events",
        "concomitant_medications",
        "randomization",
        "crf_pages",
        "crf_data",
        "protocol_versions",
        "validation_rules",
        "validation_results",
    }
    assert expected <= set(schema)
    assert expected == {s["table"] for s in statements}


def test_seeded_timestamp_columns_use_sql_parseable_literals(statements, schema):
    timestamp_columns = {
        "visits": ["visit_start_at", "visit_end_at"],
        "lab_results": ["collected_at", "received_at"],
    }
    pattern = re.compile(r"^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(\.\d+)?([+-]\d{2}(:\d{2})?)?$")
    for statement in statements:
        columns = timestamp_columns.get(statement["table"])
        if columns is None:
            continue
        row = dict(zip(statement["columns"], statement["values"]))
        for column in columns:
            if column not in row:
                continue
            resolved = literal_to_python(row[column])
            if resolved is None:
                continue
            assert pattern.match(str(resolved)), f"{statement['table']}.{column}={resolved!r}"


# Columns that carry a foreign key, mapped to the table they point at. ``None`` in the
# target column position means the referenced table's IDENTITY primary key, which the
# generator emits in insertion order starting at 1.
FOREIGN_KEYS = {
    "treatment_arms": {"study_id": "studies"},
    "trial_sites": {"study_id": "studies", "investigator_id": "investigators"},
    "patients": {"study_id": "studies", "site_id": "trial_sites"},
    "demographics": {"patient_id": "patients"},
    "visit_windows": {"study_id": "studies"},
    "visits": {"patient_id": "patients", "window_id": "visit_windows"},
    "vital_signs": {"visit_id": "visits", "patient_id": "patients"},
    "lab_results": {"visit_id": "visits", "patient_id": "patients"},
    "adverse_events": {"patient_id": "patients"},
    "concomitant_medications": {"patient_id": "patients"},
    "randomization": {"patient_id": "patients", "arm_id": "treatment_arms"},
    "crf_pages": {"study_id": "studies"},
    "crf_data": {"page_id": "crf_pages", "visit_id": "visits", "patient_id": "patients"},
    "protocol_versions": {"study_id": "studies"},
    "validation_rules": {"study_id": "studies"},
    "validation_results": {"rule_id": "validation_rules"},
}


def test_foreign_keys_point_at_seeded_rows(statements):
    """Every FK value must resolve to a row the seed file actually inserts."""
    seeded_ids = {
        table: set(range(1, count + 1))
        for table, count in _row_counts(statements).items()
    }

    violations = []
    for statement in statements:
        references = FOREIGN_KEYS.get(statement["table"])
        if not references:
            continue
        row = dict(zip(statement["columns"], statement["values"]))
        for column, target in references.items():
            if column not in row:
                continue
            value = literal_to_python(row[column])
            if value is None:
                continue
            if value not in seeded_ids.get(target, set()):
                violations.append((statement["table"], column, value, target))
    assert not violations, f"dangling foreign keys: {sorted(set(violations))[:5]}"


def test_seeded_rows_satisfy_the_unique_constraints_in_the_ddl(statements, schema_sql_files):
    constraints = parse_unique_constraints(schema_sql_files)
    assert constraints, "expected the DDL to declare primary keys / unique constraints"

    by_table = {}
    for statement in statements:
        by_table.setdefault(statement["table"], []).append(
            dict(zip(statement["columns"], statement["values"]))
        )

    checked = 0
    for table, rows in by_table.items():
        for columns in constraints.get(table, []):
            if not rows or not all(column in rows[0] for column in columns):
                continue  # identity / generated columns are not part of the INSERT
            checked += 1
            seen = set()
            for row in rows:
                key = tuple(row[column] for column in columns)
                assert key not in seen, f"{table} violates UNIQUE{columns}: {key}"
                seen.add(key)
    assert checked > 0, "no seeded table was checked against a unique constraint"


def _row_counts(statements):
    counts = {}
    for statement in statements:
        counts[statement["table"]] = counts.get(statement["table"], 0) + 1
    return counts
