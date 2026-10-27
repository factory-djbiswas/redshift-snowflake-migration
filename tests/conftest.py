"""Shared pytest fixtures for the redshift-snowflake-migration test suite.

The seed-data generator lives in ``scripts/`` and is not an installed package, so
the directory is added to ``sys.path`` here. Keeping this in ``conftest.py`` means
the tests can be run from the repository root (``pytest``) or from anywhere else
(``pytest tests/``) without any packaging setup.
"""

import random
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
TESTS_DIR = REPO_ROOT / "tests"
SCRIPTS_DIR = REPO_ROOT / "scripts"
SOURCE_SQL_DIR = REPO_ROOT / "source_postgres"
RUNNER_SCRIPT = SCRIPTS_DIR / "run_postgres.sh"

for directory in (SCRIPTS_DIR, TESTS_DIR):
    if str(directory) not in sys.path:
        sys.path.insert(0, str(directory))

import generate_seed_data  # noqa: E402  (path setup must run first)
import sql_utils  # noqa: E402  (path setup must run first)

# ``generate_seed_data`` seeds ``random`` at import time, so a single generation per
# process is reproducible. Any test that generates more than once must re-seed first.
SEED = 42


@pytest.fixture(scope="session")
def repo_root():
    return REPO_ROOT


@pytest.fixture(scope="session")
def source_sql_dir():
    return SOURCE_SQL_DIR


@pytest.fixture(scope="session")
def generated_seed_sql(tmp_path_factory):
    """Generate the seed SQL into a temp file and return its text."""
    output_path = tmp_path_factory.mktemp("seed") / "seed_data.sql"
    random.seed(SEED)
    generate_seed_data.generate_seed_data(str(output_path))
    return output_path.read_text()


@pytest.fixture(scope="session")
def loaded_sql_files():
    """The ``source_postgres`` files ``scripts/run_postgres.sh`` loads, in order."""
    return sql_utils.parse_loaded_sql_files(RUNNER_SCRIPT, SOURCE_SQL_DIR)


@pytest.fixture(scope="session")
def schema_sql_files(loaded_sql_files):
    """Just the table DDL files the demo runner loads."""
    return [path for path in loaded_sql_files if path.parent.name == "tables"]


@pytest.fixture(scope="session")
def types_sql_file(loaded_sql_files):
    """The custom-type DDL file the demo runner loads."""
    types_files = [path for path in loaded_sql_files if path.parent.name == "types"]
    assert len(types_files) == 1, f"expected one types file, got {types_files}"
    return types_files[0]
