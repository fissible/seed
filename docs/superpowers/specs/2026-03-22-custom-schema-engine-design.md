# Custom Schema Engine — Design Spec

**Date:** 2026-03-22
**Scope:** `seed custom` generator with schema file support

---

## Goal

Add a `seed_custom` generator that reads a user-defined schema file and produces records matching any database table structure. Solves the core limitation of SQL output: hardcoded table names and field sets that don't match real application schemas.

## Architecture

Three new source files follow the existing domain-grouping pattern:

```
src/
└── custom.sh       ← seed_custom + _seed_cfield_* helpers

tests/
├── unit/test-custom.sh
└── fixtures/example.seed   ← shipped example schema

seed.sh             ← add --schema to _seed_parse_flags; source custom.sh
mcp/server.py       ← add seed_custom tool
tests/integration/test-cli.sh    ← smoke assertion
tests/mcp/test_server.py         ← MCP registration + --schema passthrough
```

---

## Schema File Format

Line-based, pipe-delimited, parseable with bash parameter expansion and `while read`. No external tools required.

```bash
# tests/fixtures/users.seed
# Comment lines (# prefix) and blank lines are ignored.
table=app_users
id|VARCHAR(36)|uuid
firstname|VARCHAR(50)|first_name
email|VARCHAR(255)|email
age|INT|number --min 18 --max 80
created_at|TIMESTAMP|date --from 2020-01-01
active|BOOLEAN|bool
```

**Rules:**
- First non-comment, non-blank line must be `table=<name>`
- Field lines: `<column>|<sql_type>|<generator> [flags]`
- SQL type is stored for readability and future `CREATE TABLE` generation; it does not affect value generation or quoting (quoting is determined by `_seed_is_numeric` on the generated value, same as all other generators)
- Per-field flags (`--min`, `--max`, `--from`, `--to`, `--words`, `--sentences`) are parsed from the generator spec portion of each field line

---

## CLI

```bash
# Auto-discover: looks for tests/fixtures/<name>.seed
seed.sh custom --schema user --count 50 --format sql

# Explicit path (any path with / is treated as a path, not a name)
seed.sh custom --schema tests/fixtures/users.seed --count 50 --format sql

# Override discovery directory via environment variable
SEED_FIXTURES_DIR=db/seeds seed.sh custom --schema user --count 50
```

**Schema resolution logic:**
1. If `_SEED_FLAG_SCHEMA` contains `/` → treat as a file path
2. Otherwise → resolve to `${SEED_FIXTURES_DIR:-tests/fixtures}/${_SEED_FLAG_SCHEMA}.seed`

`--schema` is added to `_seed_parse_flags` alongside all other flags, with `_SEED_FLAG_SCHEMA=""` in the reset block.

---

## `_seed_cfield_*` Functions

Each supported generator name maps to a function in `src/custom.sh` that writes to `_SEED_RESULT`. Functions take parsed per-field flags as positional arguments to avoid touching the global `_SEED_FLAG_*` state set by `_seed_parse_flags`.

```bash
_seed_cfield_first_name()  { _seed_random_line_v first_names; }
_seed_cfield_last_name()   { _seed_random_line_v last_names; }
_seed_cfield_name()        { local fn ln
                             _seed_random_line_v first_names; fn="$_SEED_RESULT"
                             _seed_random_line_v last_names;  ln="$_SEED_RESULT"
                             _SEED_RESULT="$fn $ln"; }
_seed_cfield_email()       { # inline: slug(first).slug(last)@domain }
_seed_cfield_phone()       { # inline: same logic as seed_user's phone }
_seed_cfield_uuid()        { _SEED_RESULT=$(_seed_uuid_gen); }
_seed_cfield_date()        { # $1=from $2=to; inline date range logic }
_seed_cfield_number()      { _seed_random_int_v "${1:-1}" "${2:-100}"; }
_seed_cfield_bool()        { _seed_random_int_v 0 1
                             if [[ "$_SEED_RESULT" -eq 0 ]]; then _SEED_RESULT="false"
                             else _SEED_RESULT="true"; fi; }
_seed_cfield_lorem()       { _seed_random_line_v lorem; }
_seed_cfield_ip()          { # inline: same logic as seed_ip }
_seed_cfield_url()         { # inline: same logic as seed_url }
```

**Supported generator names for v1.1:**
`first_name` `last_name` `name` `email` `phone` `uuid` `date` `number` `bool` `lorem` `ip` `url`

---

## `seed_custom` Implementation

```bash
seed_custom() {
    _seed_parse_flags "$@" || return $?

    # Resolve schema path
    local schema_path
    if [[ "$_SEED_FLAG_SCHEMA" == */* ]]; then
        schema_path="$_SEED_FLAG_SCHEMA"
    else
        schema_path="${SEED_FIXTURES_DIR:-tests/fixtures}/${_SEED_FLAG_SCHEMA}.seed"
    fi
    if [[ ! -f "$schema_path" ]]; then
        printf 'seed_custom: schema file not found: %s\n' "$schema_path" >&2
        return 2
    fi

    # Parse schema: extract table name and field specs
    local table=""
    local field_names=() field_generators=() field_flags=()
    while IFS= read -r line; do
        # Strip comments and blank lines
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        if [[ "$line" =~ ^table= ]]; then
            table="${line#table=}"
        else
            local col sql_type gen_spec
            col="${line%%|*}"; local rest="${line#*|}"
            sql_type="${rest%%|*}"; gen_spec="${rest#*|}"
            local gen_name gen_args
            gen_name="${gen_spec%% *}"
            gen_args="${gen_spec#* }"; [[ "$gen_args" == "$gen_name" ]] && gen_args=""
            # Validate generator name
            if ! declare -f "_seed_cfield_${gen_name}" > /dev/null 2>&1; then
                printf 'seed_custom: unknown generator "%s" in %s\n' "$gen_name" "$schema_path" >&2
                return 2
            fi
            field_names[${#field_names[@]}]="$col"
            field_generators[${#field_generators[@]}]="$gen_name"
            field_flags[${#field_flags[@]}]="$gen_args"
        fi
    done < "$schema_path"

    if [[ -z "$table" ]]; then
        printf 'seed_custom: missing table= line in %s\n' "$schema_path" >&2
        return 2
    fi

    # Generate records
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        # Build field/value argument list for _seed_emit_record
        local rec_args=()
        local f=0
        while [[ $f -lt ${#field_names[@]} ]]; do
            local gen="${field_generators[$f]}"
            local flags="${field_flags[$f]}"
            # Parse per-field --min/--max/--from/--to from flags string
            local fmin="" fmax="" ffrom="" fto="" fwords="" fsentences=""
            # (mini flag parser: extract --min N --max N --from D --to D etc.)
            _seed_cfield_${gen} "$fmin" "$fmax" "$ffrom" "$fto" "$fwords" "$fsentences"
            rec_args[${#rec_args[@]}]="${field_names[$f]}"
            rec_args[${#rec_args[@]}]="$_SEED_RESULT"
            f=$((f+1))
        done
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" "$table" "${rec_args[@]}")
        # CSV/kv/else dedup pattern (same as all record generators)
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else
            printf '%s\n' "$rec"
        fi
        i=$((i+1))
    done
}
```

---

## Per-Field Flag Parsing

The generator spec portion of a field line (e.g., `number --min 18 --max 80`) may contain flags. These are parsed in `seed_custom`'s field loop using a mini parser — a `while` loop over space-split tokens, extracting `--min`, `--max`, `--from`, `--to`, `--words`, `--sentences`. Parsed values are passed as positional arguments to `_seed_cfield_*` functions. No `eval`, no `_seed_parse_flags` — bash 3.2 compatible.

The `_seed_cfield_*` signature is:
```bash
_seed_cfield_number()  { local min="${1:-1}" max="${2:-100}"; _seed_random_int_v "$min" "$max"; }
_seed_cfield_date()    { # $1=from $2=to; defaults: 2000-01-01 / today }
_seed_cfield_lorem()   { # $1=words $2=sentences }
# Others ignore positional args they don't need
```

---

## Error Handling

| Condition | Behavior |
|---|---|
| Schema file not found | `seed_custom: schema file not found: <path>` → exit 2 |
| Missing `table=` line | `seed_custom: missing table= line in <path>` → exit 2 |
| Unknown generator name | `seed_custom: unknown generator "<name>" in <path>` → exit 2 |
| `--schema` flag missing value | existing `_seed_parse_flags` guard → exit 2 |

---

## MCP Tool

```python
@mcp.tool()
def seed_custom(schema: str, count: int = 1, format: str = "json") -> str:
    """Generate records from a .seed schema file. schema = name (auto-discovers tests/fixtures/<name>.seed) or file path."""
    return _run("custom", schema=schema, count=count, format=format)
```

---

## Example Schema (shipped with repo)

`tests/fixtures/example.seed`:

```bash
# Example custom schema — copy and adapt for your project
# Usage: seed.sh custom --schema example --count 10 --format sql
table=example_records
id|VARCHAR(36)|uuid
firstname|VARCHAR(50)|first_name
email|VARCHAR(255)|email
age|INT|number --min 18 --max 80
created_at|TIMESTAMP|date --from 2020-01-01
active|BOOLEAN|bool
```

---

## Testing

### `tests/unit/test-custom.sh`

- Schema parsed correctly: table name and field names extracted
- Each `_seed_cfield_*` function produces non-empty `_SEED_RESULT`
- `number --min 5 --max 5` always produces `5` (flag respected)
- `date --from 2024-01-01 --to 2024-01-01` always produces `2024-01-01`
- All 4 output formats produce correct output (`json`, `kv`, `csv`, `sql`)
- `--format sql` uses schema table name: `INSERT INTO example_records`
- `--count 3` produces 3 records
- `--seed 42 --count 3` produces 3 distinct records
- Unknown generator → exits 2
- Missing schema file → exits 2
- Missing `table=` line → exits 2
- `--schema` flag resets across `_seed_parse_flags` calls (no bleed)

### `tests/integration/test-cli.sh`

```bash
assert_contains "$(seed.sh custom --schema tests/fixtures/example.seed)" '"firstname"' "CLI custom json"
```

### `tests/mcp/test_server.py`

- `seed_custom` is registered and callable
- `seed_custom(schema="example")` passes `--schema` and `example` to `_run`

---

## Compatibility

- Bash 3.2+: `while IFS= read -r line`, `${var%%|*}`, `${var#*|}`, `arr[${#arr[@]}]=val` — no `declare -A`, no `+=`, no `mapfile`
- Per-field mini flag parser uses only `case`/`shift`-style token iteration over space-split generator spec
- No `eval`
