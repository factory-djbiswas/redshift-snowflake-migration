"""Small SQL parsing helpers used by the test suite.

The repository ships the demo as plain SQL scripts rather than through a database
driver, so the tests parse the scripts directly. Nothing here needs a running
Postgres instance, which keeps the suite runnable in CI.

Only the subset of SQL the project actually uses is supported: ``CREATE TABLE``
column lists, ``CREATE TYPE ... AS ENUM`` and ``INSERT INTO ... VALUES`` tuples
with single-quoted strings, ``'{}'::text[]`` array literals and ``'...'::jsonb``
literals.
"""

import re
from pathlib import Path

CREATE_TABLE_RE = re.compile(
    r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?az_clinical\.(\w+)\s*\(",
    re.IGNORECASE,
)

CREATE_ENUM_RE = re.compile(
    r"CREATE\s+TYPE\s+az_clinical\.(\w+)\s+AS\s+ENUM\s*\(",
    re.IGNORECASE,
)

INSERT_RE = re.compile(r"INSERT\s+INTO\s+az_clinical\.(\w+)\s*\(", re.IGNORECASE)

CAST_SUFFIX_RE = re.compile(r"::\s*[A-Za-z_][\w\s\[\]\(\),]*$")

TABLE_CONSTRAINT_KEYWORDS = {
    "CONSTRAINT",
    "PRIMARY",
    "FOREIGN",
    "UNIQUE",
    "CHECK",
    "EXCLUDE",
    "LIKE",
}


def strip_sql_comments(sql_text):
    """Remove ``--`` line comments so they cannot be mistaken for SQL tokens."""
    return "\n".join(line.split("--", 1)[0] for line in sql_text.splitlines())


PSQL_FILE_RE = re.compile(r'psql\s+-f\s+"\$SP/([^"]+)"')


def parse_loaded_sql_files(runner_script, source_sql_dir):
    """Return the ``source_postgres`` files ``run_postgres.sh`` actually loads.

    The repository carries a few stale, duplicate table definitions that the demo
    runner does not load, so the tests validate against exactly the files the demo
    executes rather than every ``.sql`` file on disk.
    """
    text = Path(runner_script).read_text()
    names = PSQL_FILE_RE.findall(text)
    if not names:
        raise ValueError(f"no psql -f \"$SP/...\" invocations found in {runner_script}")
    return [Path(source_sql_dir) / name for name in names]


def _iter_sql_files(target):
    """Accept a directory or an explicit list of SQL files."""
    if isinstance(target, (str, Path)):
        return sorted(Path(target).glob("**/*.sql"))
    return [Path(path) for path in target]


def _read_paren_group(text, open_index):
    """Return ``(inner_text, index_after_closing_paren)`` for the group at ``open_index``.

    Handles nesting and skips over single-quoted strings, double-quoted identifiers
    and bracket/brace groups such as ``'{"a","b"}'::text[]``.
    """
    if text[open_index] != "(":
        raise ValueError(f"expected '(' at index {open_index}")
    depth = 0
    in_single = False
    in_double = False
    i = open_index
    while i < len(text):
        char = text[i]
        if in_single:
            if char == "'":
                if text[i + 1 : i + 2] == "'":
                    i += 2
                    continue
                in_single = False
        elif in_double:
            if char == '"':
                if text[i + 1 : i + 2] == '"':
                    i += 2
                    continue
                in_double = False
        elif char == "'":
            in_single = True
        elif char == '"':
            in_double = True
        elif char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
            if depth == 0:
                return text[open_index + 1 : i], i + 1
        i += 1
    raise ValueError("unbalanced parentheses in SQL text")


def split_top_level(text):
    """Split on commas that are not nested in parens/brackets/braces or quotes."""
    parts = []
    buffer = []
    depth = 0
    in_single = False
    in_double = False
    i = 0
    while i < len(text):
        char = text[i]
        if in_single:
            buffer.append(char)
            if char == "'":
                if text[i + 1 : i + 2] == "'":
                    buffer.append("'")
                    i += 2
                    continue
                in_single = False
        elif in_double:
            buffer.append(char)
            if char == '"':
                if text[i + 1 : i + 2] == '"':
                    buffer.append('"')
                    i += 2
                    continue
                in_double = False
        elif char == "'":
            in_single = True
            buffer.append(char)
        elif char == '"':
            in_double = True
            buffer.append(char)
        elif char in "([{":
            depth += 1
            buffer.append(char)
        elif char in ")]}":
            depth -= 1
            buffer.append(char)
        elif char == "," and depth == 0:
            parts.append("".join(buffer).strip())
            buffer = []
        else:
            buffer.append(char)
        i += 1
    if buffer or parts:
        parts.append("".join(buffer).strip())
    return parts


def parse_insert_statements(sql_text):
    """Parse every ``INSERT INTO az_clinical.<table> (<cols>) VALUES (...)`` statement.

    Returns a list of dicts with ``table``, ``columns`` and ``values`` (both lists of
    raw SQL text, already split on top-level commas).
    """
    sql_text = strip_sql_comments(sql_text)
    statements = []
    position = 0
    while True:
        match = INSERT_RE.search(sql_text, position)
        if match is None:
            return statements
        table = match.group(1)
        columns_text, cursor = _read_paren_group(sql_text, match.end() - 1)
        values_match = re.compile(r"\s*VALUES\s*\(", re.IGNORECASE).match(sql_text, cursor)
        if values_match is None:
            raise ValueError(f"INSERT into {table} is not followed by VALUES (...)")
        values_text, cursor = _read_paren_group(sql_text, values_match.end() - 1)
        statements.append(
            {
                "table": table,
                "columns": split_top_level(columns_text),
                "values": split_top_level(values_text),
            }
        )
        position = cursor


def parse_enums(types_file):
    """Parse ``CREATE TYPE az_clinical.<name> AS ENUM (...)`` into ``{name: {values}}``."""
    sql_text = strip_sql_comments(Path(types_file).read_text())
    enums = {}
    position = 0
    while True:
        match = CREATE_ENUM_RE.search(sql_text, position)
        if match is None:
            return enums
        values_text, position = _read_paren_group(sql_text, match.end() - 1)
        values = {
            literal_to_python(value)
            for value in split_top_level(values_text)
        }
        enums[match.group(1).lower()] = values


def parse_table_columns(sql_dir):
    """Parse table definitions into ``{table: {column: {"type", "not_null"}}}``.

    ``sql_dir`` may be a directory or an explicit list of SQL files. Definitions are
    merged, so a column is considered NOT NULL when any definition says so; this keeps
    the helper usable against the whole ``source_postgres`` tree as well as against the
    exact files the demo runner loads.
    """
    tables = {}
    for sql_file in _iter_sql_files(sql_dir):
        sql_text = strip_sql_comments(sql_file.read_text())
        position = 0
        while True:
            match = CREATE_TABLE_RE.search(sql_text, position)
            if match is None:
                break
            table = match.group(1).lower()
            body, position = _read_paren_group(sql_text, match.end() - 1)
            columns = tables.setdefault(table, {})
            for definition in split_top_level(body):
                if not definition:
                    continue
                tokens = definition.split()
                if not tokens:
                    continue
                name = tokens[0].strip('"')
                if name.upper() in TABLE_CONSTRAINT_KEYWORDS:
                    continue
                upper = definition.upper()
                not_null = bool(re.search(r"\bNOT\s+NULL\b", upper)) or bool(
                    re.search(r"\bPRIMARY\s+KEY\b", upper)
                )
                column = columns.setdefault(name.lower(), {"type": None, "not_null": False})
                column["not_null"] = column["not_null"] or not_null
                if len(tokens) > 1:
                    declared = tokens[1]
                    # Prefer a custom enum type over the plain VARCHAR an older
                    # duplicate definition of the same table may declare.
                    if column["type"] is None or (
                        declared.lower().startswith("az_clinical.")
                        and not (column["type"] or "").lower().startswith("az_clinical.")
                    ):
                        column["type"] = declared
    return tables


def parse_unique_constraints(sql_dir):
    """Parse PRIMARY KEY / UNIQUE constraints into ``{table: [columns, ...]}``."""
    constraints = {}
    for sql_file in _iter_sql_files(sql_dir):
        sql_text = strip_sql_comments(sql_file.read_text())
        position = 0
        while True:
            match = CREATE_TABLE_RE.search(sql_text, position)
            if match is None:
                break
            table = match.group(1).lower()
            body, position = _read_paren_group(sql_text, match.end() - 1)
            entries = constraints.setdefault(table, set())
            for definition in split_top_level(body):
                if not definition:
                    continue
                upper = definition.upper()
                if upper.startswith("UNIQUE") or upper.startswith("PRIMARY KEY"):
                    columns_match = re.search(r"\(([^)]*)\)", definition)
                    if columns_match:
                        columns = tuple(
                            column.strip().lower()
                            for column in columns_match.group(1).split(",")
                        )
                    else:
                        columns = (definition.split()[0].strip('"').lower(),)
                elif re.search(r"\bUNIQUE\b", definition.split("(", 1)[0].upper()):
                    # Column-level UNIQUE. Only the part before the type's own
                    # parentheses counts, so the UNIQUE keyword inside a CHECK list
                    # such as CHECK (rule_type IN ('...','UNIQUE',...)) is ignored.
                    columns = (definition.split()[0].strip('"').lower(),)
                else:
                    continue
                if columns:
                    entries.add(columns)
    return {table: sorted(columns) for table, columns in constraints.items()}


def parse_enum_column_references(sql_dir, enum_names):
    """Map ``(table, column)`` to the ``az_clinical`` enum type the column declares."""
    references = {}
    for table, columns in parse_table_columns(sql_dir).items():
        for column, meta in columns.items():
            declared_type = (meta["type"] or "").lower()
            if declared_type.startswith("az_clinical."):
                enum_name = declared_type.split(".", 1)[1]
                if enum_name in enum_names:
                    references[(table, column)] = enum_name
    return references


def literal_to_python(raw):
    """Convert a SQL literal from the seed file into a Python value.

    Handles ``NULL``/``TRUE``/``FALSE``, single-quoted strings (with ``''`` escapes)
    and numeric literals, ignoring trailing casts such as ``::jsonb`` or ``::text[]``.
    """
    text = raw.strip()
    cast = CAST_SUFFIX_RE.search(text)
    if cast:
        text = text[: cast.start()].strip()
    if text.upper() == "NULL":
        return None
    if text.upper() == "TRUE":
        return True
    if text.upper() == "FALSE":
        return False
    if text.startswith("'") and text.endswith("'"):
        return text[1:-1].replace("''", "'")
    try:
        return int(text)
    except ValueError:
        pass
    try:
        return float(text)
    except ValueError:
        return text
