"""Unit tests for ``scripts/generate_seed_data.py``.

The generator is the only executable code in the repository, and the SQL it emits is
loaded into Postgres by ``scripts/run_postgres.sh`` for every migration demo run. A
broken literal (an unescaped quote, a mis-encoded array or JSON payload) fails at
``psql`` time, so the escaping helpers and the generated file are covered here.

The generator seeds ``random`` with a fixed value, so the emitted SQL is fully
reproducible. The tests below rely on that: ``generated_seed_sql`` re-seeds before
each generation (see ``conftest.py``), and the golden test pins the committed
``scripts/seed_data.sql`` against a fresh run.
"""

import json
import random
from datetime import date, datetime, timedelta

import pytest

from generate_seed_data import (
    ARMS,
    CRF_PAGES,
    INVESTIGATORS,
    LAB_TESTS,
    NOTE_VARIANTS,
    SITES,
    STUDY,
    VISIT_WINDOWS,
    generate_date,
    generate_seed_data,
    generate_ts,
    sql_array,
    sql_jsonb,
    sql_quote,
)

from sql_utils import literal_to_python, parse_insert_statements

SEED = 42

# Tables whose row count is fixed by a module-level constant or a literal in the
# generator (as opposed to the randomized clinical data).
FIXED_ROW_COUNTS = {
    "studies": 1,
    "treatment_arms": len(ARMS),
    "investigators": len(INVESTIGATORS),
    "trial_sites": len(SITES),
    "patients": 50,  # num_patients in generate_seed_data()
    "demographics": 50,
    "visit_windows": len(VISIT_WINDOWS),
    "crf_pages": len(CRF_PAGES),
    "protocol_versions": 3,
    "validation_rules": 10,
    "validation_results": 30,
}

VARIABLE_ROW_COUNT_TABLES = [
    "visits",
    "vital_signs",
    "lab_results",
    "adverse_events",
    "concomitant_medications",
    "randomization",
    "crf_data",
]

NOTE_COLUMNS = {
    "trial_sites": "notes",
    "vital_signs": "notes",
    "lab_results": "notes",
    "concomitant_medications": "notes",
}


# ---------------------------------------------------------------------------
# sql_quote
# ---------------------------------------------------------------------------


def test_sql_quote_renders_null_keyword():
    assert sql_quote(None) == "NULL"


def test_sql_quote_wraps_plain_text():
    assert sql_quote("AstraZeneca") == "'AstraZeneca'"


def test_sql_quote_doubles_embedded_single_quotes():
    assert sql_quote("O'Brien") == "'O''Brien'"
    assert sql_quote("'quoted'") == "'''quoted'''"


def test_sql_quote_stringifies_non_text_values():
    assert sql_quote(42) == "'42'"
    assert sql_quote(date(2026, 7, 23)) == "'2026-07-23'"
    assert sql_quote(True) == "'True'"


def test_sql_quote_preserves_unicode_text():
    assert sql_quote("Charite Universitatsmedizin") == "'Charite Universitatsmedizin'"


# ---------------------------------------------------------------------------
# sql_array
# ---------------------------------------------------------------------------


def test_sql_array_renders_null_keyword():
    assert sql_array(None) == "NULL"


def test_sql_array_renders_empty_array_literal():
    assert sql_array([]) == "'{}'::text[]"


def test_sql_array_renders_postgres_array_literal():
    assert sql_array(["a@example.com", "b@example.com"]) == (
        '\'{"a@example.com","b@example.com"}\'::text[]'
    )


def test_sql_array_escapes_quotes_and_backslashes():
    rendered = sql_array(['say "hi"', "back\\slash"])
    assert rendered == '\'{"say \\"hi\\"","back\\\\slash"}\'::text[]'


def test_sql_array_output_is_parseable_after_stripping_cast():
    rendered = sql_array(["a", 'b"c', "d\\e"])
    payload = rendered[: -len("::text[]")]
    assert payload.startswith("'{") and payload.endswith("}'")
    inner = payload[2:-2]
    values = [part[1:-1] for part in inner.split('","')]
    assert len(values) == 3


# ---------------------------------------------------------------------------
# sql_jsonb
# ---------------------------------------------------------------------------


def test_sql_jsonb_renders_null_keyword():
    assert sql_jsonb(None) == "NULL"


def test_sql_jsonb_emits_valid_json_with_cast():
    literal = sql_jsonb({"region": "Europe", "blinded": True})
    assert literal.endswith("::jsonb")
    payload = literal[: -len("::jsonb")]
    assert payload.startswith("'") and payload.endswith("'")
    assert json.loads(payload[1:-1].replace("''", "'")) == {
        "region": "Europe",
        "blinded": True,
    }


def test_sql_jsonb_escapes_embedded_quotes_for_sql():
    literal = sql_jsonb({"note": "site's comment"})
    payload = literal[: -len("::jsonb")]
    # A SQL string literal must double every apostrophe it contains.
    assert "''" in payload
    assert json.loads(payload[1:-1].replace("''", "'")) == {"note": "site's comment"}


def test_sql_jsonb_handles_nested_structures():
    value = {"conditions": ["Asthma", "None"], "nested": {"depth": 2}}
    literal = sql_jsonb(value)
    payload = literal[: -len("::jsonb")]
    assert json.loads(payload[1:-1].replace("''", "'")) == value


# ---------------------------------------------------------------------------
# generate_date / generate_ts
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "start,end",
    [
        (date(2025, 1, 1), date(2026, 1, 1)),
        (date(2026, 7, 1), date(2026, 7, 1)),
        (date(2024, 2, 28), date(2024, 3, 1)),
    ],
)
def test_generate_date_stays_within_bounds(start, end):
    for _ in range(200):
        value = generate_date(start, end)
        assert isinstance(value, date)
        assert start <= value <= end


def test_generate_ts_stays_within_bounds():
    start = datetime(2026, 7, 1, 8, 0, 0)
    end = datetime(2026, 7, 2, 8, 0, 0)
    for _ in range(200):
        value = generate_ts(start, end)
        assert isinstance(value, datetime)
        assert start <= value <= end


def test_generate_ts_covers_full_second_range():
    start = datetime(2026, 7, 1, 0, 0, 0)
    end = start + timedelta(seconds=60)
    values = {generate_ts(start, end) for _ in range(500)}
    assert min(values) >= start
    assert max(values) > start + timedelta(seconds=30)


# ---------------------------------------------------------------------------
# generated SQL file
# ---------------------------------------------------------------------------


def test_generated_file_is_a_single_transaction(generated_seed_sql):
    statements = [
        line.strip()
        for line in generated_seed_sql.splitlines()
        if line.strip() and not line.strip().startswith("--")
    ]
    assert statements[0] == "BEGIN;"
    assert statements[-1] == "COMMIT;"


def test_generated_file_ends_every_statement_with_a_semicolon(generated_seed_sql):
    for line in generated_seed_sql.splitlines():
        stripped = line.strip()
        if stripped.startswith(("INSERT", "BEGIN", "COMMIT")):
            assert stripped.endswith(";"), f"statement is not terminated: {stripped[:80]}"


def test_generated_row_counts_match_the_documented_demo_dataset(generated_seed_sql):
    counts = {}
    for statement in parse_insert_statements(generated_seed_sql):
        counts[statement["table"]] = counts.get(statement["table"], 0) + 1

    for table, expected in FIXED_ROW_COUNTS.items():
        assert counts.get(table) == expected, f"{table} row count drifted"

    for table in VARIABLE_ROW_COUNT_TABLES:
        assert counts.get(table, 0) > 0, f"{table} was never populated"


def test_study_row_matches_the_module_constants(generated_seed_sql):
    studies = [
        statement
        for statement in parse_insert_statements(generated_seed_sql)
        if statement["table"] == "studies"
    ]
    assert len(studies) == 1
    row = {
        column: literal_to_python(value)
        for column, value in zip(studies[0]["columns"], studies[0]["values"])
    }
    assert row["study_code"] == STUDY["study_code"]
    assert row["study_name"] == STUDY["study_name"]
    assert row["phase"] == STUDY["phase"]
    assert row["planned_sites"] == STUDY["planned_sites"]
    assert json.loads(row["metadata"]) == STUDY["metadata"]


def test_patient_subject_numbers_are_unique(generated_seed_sql):
    patients = [
        statement
        for statement in parse_insert_statements(generated_seed_sql)
        if statement["table"] == "patients"
    ]
    subject_numbers = [
        literal_to_python(statement["values"][statement["columns"].index("subject_number")])
        for statement in patients
    ]
    assert len(subject_numbers) == len(set(subject_numbers))


def test_randomization_only_covers_enrolled_patients(generated_seed_sql):
    """``randomization`` has a FK to ``patients``, so every randomized subject must be enrolled.

    ``patients.patient_id`` is an IDENTITY column and is not part of the INSERT, so the
    seeded identifier is the insertion order (the identity sequence starts at 1).
    """
    statements = parse_insert_statements(generated_seed_sql)

    enrolled = set()
    for index, statement in enumerate(
        (s for s in statements if s["table"] == "patients"), start=1
    ):
        enrollment_date = literal_to_python(
            statement["values"][statement["columns"].index("enrollment_date")]
        )
        if enrollment_date is not None:
            enrolled.add(index)

    randomized = {
        literal_to_python(s["values"][s["columns"].index("patient_id")])
        for s in statements
        if s["table"] == "randomization"
    }
    assert randomized, "expected at least one randomized patient"
    assert randomized <= enrolled


def test_lab_results_reference_known_tests_and_units(generated_seed_sql):
    known_tests = {code: unit for code, _name, unit, _range in LAB_TESTS}
    lab_results = [
        statement
        for statement in parse_insert_statements(generated_seed_sql)
        if statement["table"] == "lab_results"
    ]
    assert lab_results
    for statement in lab_results:
        row = {
            column: literal_to_python(value)
            for column, value in zip(statement["columns"], statement["values"])
        }
        assert row["test_code"] in known_tests
        assert row["unit"] == known_tests[row["test_code"]]
        assert row["result_value"] is not None


def test_notes_columns_exercise_the_redshift_empty_value_variants(generated_seed_sql):
    """RS008 regression: the demo must keep mixing NULL, '', and whitespace notes.

    The migration spec (``validation/metadata_match.md``) exists because Redshift
    lands empty text as NULL or a space depending on the export path. If the seed
    data stopped producing those variants, the demo would silently stop exercising
    the normalization rule it is meant to demonstrate.
    """
    observed = set()
    for statement in parse_insert_statements(generated_seed_sql):
        column = NOTE_COLUMNS.get(statement["table"])
        if column is None:
            continue
        observed.add(literal_to_python(statement["values"][statement["columns"].index(column)]))

    empties = {value for value in observed if value is None or not value.strip()}
    assert None in empties or "" in empties
    assert any(value is not None and value.strip() for value in observed)
    assert len(empties) >= 2, "expected more than one representation of an empty note"

    expected_variants = {
        None if value is None else value for value in NOTE_VARIANTS if value is None or not value.strip()
    }
    assert empties <= expected_variants


def test_generator_is_deterministic(tmp_path):
    first = tmp_path / "first.sql"
    second = tmp_path / "second.sql"

    random.seed(SEED)
    generate_seed_data(str(first))
    random.seed(SEED)
    generate_seed_data(str(second))

    assert first.read_bytes() == second.read_bytes()


def test_committed_seed_data_is_in_sync_with_the_generator(tmp_path, repo_root):
    """The checked-in seed file must match what the generator produces today."""
    output_path = tmp_path / "seed_data.sql"
    random.seed(SEED)
    generate_seed_data(str(output_path))

    committed = (repo_root / "scripts" / "seed_data.sql").read_text()
    regenerated = output_path.read_text()
    if committed != regenerated:
        pytest.fail(
            "scripts/seed_data.sql is stale; re-run "
            "'python3 scripts/generate_seed_data.py' and commit the result."
        )
