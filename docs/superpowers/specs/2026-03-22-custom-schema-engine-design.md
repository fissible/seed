# Custom Schema Engine — Design Spec

**Date:** 2026-03-22
**Scope:** `seed custom` generator with schema file support

---

## Goal

Add a `seed_custom` generator that reads a user-defined schema file and produces records matching any database table structure. Solves the core limitation of SQL output: hardcoded table names and field sets that don't match real application schemas.

## Architecture

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
- **No whitespace around pipes.** `firstname|VARCHAR(50)|first_name` is valid; `firstname | VARCHAR(50) | first_name` is not. Whitespace-only lines are treated as blank (skipped).
- SQL type is stored for readability and future `CREATE TABLE` generation; it does not affect value generation or quoting (quoting is determined by `_seed_is_numeric` on the generated value, same as all other generators)
- Per-field flags (`--min`, `--max`, `--from`, `--to`, `--words`, `--sentences`) are parsed from the generator spec portion of each field line

---

## CLI

```bash
# Auto-discover: looks for tests/fixtures/<name>.seed
seed.sh custom --schema user --count 50 --format sql

# Explicit path (any value containing / is treated as a file path, resolved relative to CWD)
seed.sh custom --schema tests/fixtures/users.seed --count 50 --format sql

# Override discovery directory via environment variable
SEED_FIXTURES_DIR=db/seeds seed.sh custom --schema user --count 50
```

**Schema resolution logic (in `seed_custom`):**
1. If `_SEED_FLAG_SCHEMA` is empty → `seed_custom: --schema is required` → exit 2
2. If `_SEED_FLAG_SCHEMA` contains `/` → treat as a file path directly (CWD-relative, not `SEED_HOME`-relative)
3. Otherwise → resolve to `${SEED_FIXTURES_DIR:-tests/fixtures}/${_SEED_FLAG_SCHEMA}.seed`

**Adding `--schema` to `seed.sh`:**

In `seed.sh`'s `_seed_parse_flags` function, add `_SEED_FLAG_SCHEMA=""` to the reset block (after `_SEED_FLAG_PREFIX=""`), and add a `--schema` arm after the `--prefix` arm (before `--seed`):

```bash
# In reset block (after _SEED_FLAG_PREFIX=""):
_SEED_FLAG_SCHEMA=""

# New arm (insert after --prefix, before --seed):
--schema)
    if [[ $# -lt 2 ]]; then
        printf 'Flag --schema requires a value\n' >&2
        return 2
    fi
    _SEED_FLAG_SCHEMA="$2"; shift 2 ;;
```

Also update the header comment in `_seed_parse_flags` to list `_SEED_FLAG_SCHEMA`.

**Note:** All generators will silently accept `--schema` and ignore it, consistent with how `--min`, `--from`, `--prefix` etc. are already accepted by generators that don't use them.

---

## `_seed_cfield_*` Functions

Each supported generator name maps to a function in `src/custom.sh` that writes to `_SEED_RESULT`. Functions receive only the arguments relevant to them (not a fixed positional signature), dispatched by a `case` in `seed_custom`'s field loop (see Dispatch section below).

**Note on `local` inside loops:** In bash, `local` is function-scoped regardless of loop depth — declaring `local x=value` inside a `while` loop is legal and does not allocate per-iteration. This codebase uses this pattern in `seed_custom`'s field loop for clarity.

```bash
_seed_cfield_first_name()  { _seed_random_line_v first_names; }
_seed_cfield_last_name()   { _seed_random_line_v last_names; }
_seed_cfield_name()        {
    local fn ln
    _seed_random_line_v first_names; fn="$_SEED_RESULT"
    _seed_random_line_v last_names;  ln="$_SEED_RESULT"
    _SEED_RESULT="$fn $ln"
}
_seed_cfield_email()       {
    # Matches seed_email in scalar.sh: uses _seed_str_lower_v (not slug)
    local fn ln d fl ll
    _seed_random_line_v first_names; fn="$_SEED_RESULT"
    _seed_random_line_v last_names;  ln="$_SEED_RESULT"
    _seed_random_line_v domains;     d="$_SEED_RESULT"
    _seed_str_lower_v "$fn"; fl="$_SEED_RESULT"
    _seed_str_lower_v "$ln"; ll="$_SEED_RESULT"
    _SEED_RESULT="${fl}.${ll}@${d}"
}
_seed_cfield_phone()       {
    local a b c d
    _seed_random_int_v 2 9;       a="$_SEED_RESULT"
    _seed_random_int_v 10 99;     b="$_SEED_RESULT"
    _seed_random_int_v 100 999;   c="$_SEED_RESULT"
    _seed_random_int_v 1000 9999; d="$_SEED_RESULT"
    _SEED_RESULT=$(printf '%d%02d-%03d-%04d' "$a" "$b" "$c" "$d")
}
_seed_cfield_uuid()        {
    # Deliberate exception: _seed_uuid_gen reads /dev/urandom, not the LCG.
    # The subshell does not advance _SEED_RNG_STATE, which is correct because
    # no LCG state is used inside _seed_uuid_gen.
    _SEED_RESULT=$(_seed_uuid_gen)
}
_seed_cfield_date()        {
    # $1=from (YYYY-MM-DD, default 2000-01-01)  $2=to (YYYY-MM-DD, default today)
    # Adapted from seed_date in scalar.sh.
    local from="${1:-2000-01-01}" to="${2:-$(_seed_today)}"
    local from_year="${from:0:4}" to_year="${to:0:4}"
    local year month day max_day
    _seed_random_int_v "$from_year" "$to_year"; year="$_SEED_RESULT"
    _seed_random_int_v 1 12; month="$_SEED_RESULT"
    case "$month" in
        1|3|5|7|8|10|12) max_day=31 ;;
        4|6|9|11)         max_day=30 ;;
        2)
            if (( year % 400 == 0 || (year % 4 == 0 && year % 100 != 0) )); then
                max_day=29
            else
                max_day=28
            fi
            ;;
    esac
    _seed_random_int_v 1 "$max_day"; day="$_SEED_RESULT"
    _SEED_RESULT=$(printf '%04d-%02d-%02d' "$year" "$month" "$day")
}
_seed_cfield_number()      {
    # $1=min  $2=max
    _seed_random_int_v "${1:-1}" "${2:-100}"
}
_seed_cfield_bool()        {
    # Matches seed_bool convention: 0 → true, 1 → false
    _seed_random_int_v 0 1
    if [[ "$_SEED_RESULT" -eq 0 ]]; then _SEED_RESULT="true"
    else _SEED_RESULT="false"; fi
}
_seed_cfield_lorem()       {
    # $1=words $2=sentences (both optional; default: one line from lorem.txt)
    _seed_random_line_v lorem
}
_seed_cfield_ip()          {
    # Matches seed_ip in scalar.sh
    local o1 o2 o3 o4
    _seed_random_int_v 1 254; o1="$_SEED_RESULT"
    _seed_random_int_v 1 254; o2="$_SEED_RESULT"
    _seed_random_int_v 1 254; o3="$_SEED_RESULT"
    _seed_random_int_v 1 254; o4="$_SEED_RESULT"
    _SEED_RESULT=$(printf '%d.%d.%d.%d' "$o1" "$o2" "$o3" "$o4")
}
_seed_cfield_url()         {
    # Matches seed_url in scalar.sh
    local dom noun
    _seed_random_line_v domains; dom="$_SEED_RESULT"
    _seed_random_line_v nouns;   noun="$_SEED_RESULT"
    _SEED_RESULT="https://${dom}/${noun}"
}
```

**Supported generator names for v1.1:**
`first_name` `last_name` `name` `email` `phone` `uuid` `date` `number` `bool` `lorem` `ip` `url`

---

## Per-Field Flag Parser

The generator spec portion of a field line (e.g., `number --min 18 --max 80`) may contain flags. `seed_custom` parses them with a bash parameter-expansion loop before calling the `_seed_cfield_*` function. No `eval`, no external tools, bash 3.2 compatible.

```bash
# Given: flags="--min 18 --max 80"
local fmin="" fmax="" ffrom="" fto="" fwords="" fsentences=""
local _f="$flags"
while [[ -n "$_f" ]]; do
    local _tok="${_f%% *}"
    [[ "$_tok" == "$_f" ]] && _f="" || _f="${_f#* }"
    case "$_tok" in
        --min)       fmin="${_f%% *}";       [[ "$fmin"       == "$_f" ]] && _f="" || _f="${_f#* }" ;;
        --max)       fmax="${_f%% *}";       [[ "$fmax"       == "$_f" ]] && _f="" || _f="${_f#* }" ;;
        --from)      ffrom="${_f%% *}";      [[ "$ffrom"      == "$_f" ]] && _f="" || _f="${_f#* }" ;;
        --to)        fto="${_f%% *}";        [[ "$fto"        == "$_f" ]] && _f="" || _f="${_f#* }" ;;
        --words)     fwords="${_f%% *}";     [[ "$fwords"     == "$_f" ]] && _f="" || _f="${_f#* }" ;;
        --sentences) fsentences="${_f%% *}"; [[ "$fsentences" == "$_f" ]] && _f="" || _f="${_f#* }" ;;
    esac
done
```

---

## Field Dispatch

After parsing per-field flags, `seed_custom` dispatches to `_seed_cfield_*` passing only the arguments each function needs:

```bash
case "$gen" in
    number) _seed_cfield_number "$fmin" "$fmax" ;;
    date)   _seed_cfield_date   "$ffrom" "$fto" ;;
    lorem)  _seed_cfield_lorem  "$fwords" "$fsentences" ;;
    *)      _seed_cfield_${gen} ;;   # all others take no args
esac
```

---

## `seed_custom` Implementation

```bash
seed_custom() {
    _seed_parse_flags "$@" || return $?

    # Guard: --schema is required
    if [[ -z "$_SEED_FLAG_SCHEMA" ]]; then
        printf 'seed_custom: --schema is required\n' >&2
        return 2
    fi

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
        # Skip comments, blank lines, and whitespace-only lines
        case "$line" in '#'*) continue ;; esac
        [[ -z "${line// /}" ]] && continue
        if [[ "$line" == table=* ]]; then
            table="${line#table=}"
        else
            local col rest sql_type gen_spec gen_name gen_args
            col="${line%%|*}"; rest="${line#*|}"
            sql_type="${rest%%|*}"; gen_spec="${rest#*|}"
            gen_name="${gen_spec%% *}"
            gen_args="${gen_spec#* }"; [[ "$gen_args" == "$gen_name" ]] && gen_args=""
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
    # rec_args is declared before the outer loop; reset to () on each iteration.
    local rec_args=()
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        rec_args=()
        local f=0
        while [[ $f -lt ${#field_names[@]} ]]; do
            local gen="${field_generators[$f]}"
            local flags="${field_flags[$f]}"
            local fmin="" fmax="" ffrom="" fto="" fwords="" fsentences=""
            # Mini flag parser
            local _f="$flags"
            while [[ -n "$_f" ]]; do
                local _tok="${_f%% *}"
                [[ "$_tok" == "$_f" ]] && _f="" || _f="${_f#* }"
                case "$_tok" in
                    --min)       fmin="${_f%% *}";       [[ "$fmin"       == "$_f" ]] && _f="" || _f="${_f#* }" ;;
                    --max)       fmax="${_f%% *}";       [[ "$fmax"       == "$_f" ]] && _f="" || _f="${_f#* }" ;;
                    --from)      ffrom="${_f%% *}";      [[ "$ffrom"      == "$_f" ]] && _f="" || _f="${_f#* }" ;;
                    --to)        fto="${_f%% *}";        [[ "$fto"        == "$_f" ]] && _f="" || _f="${_f#* }" ;;
                    --words)     fwords="${_f%% *}";     [[ "$fwords"     == "$_f" ]] && _f="" || _f="${_f#* }" ;;
                    --sentences) fsentences="${_f%% *}"; [[ "$fsentences" == "$_f" ]] && _f="" || _f="${_f#* }" ;;
                esac
            done
            # Dispatch with only the args each function needs
            case "$gen" in
                number) _seed_cfield_number "$fmin" "$fmax" ;;
                date)   _seed_cfield_date   "$ffrom" "$fto" ;;
                lorem)  _seed_cfield_lorem  "$fwords" "$fsentences" ;;
                *)      _seed_cfield_${gen} ;;
            esac
            rec_args[${#rec_args[@]}]="${field_names[$f]}"
            rec_args[${#rec_args[@]}]="$_SEED_RESULT"
            f=$((f+1))
        done
        local rec
        # _seed_emit_record and tail are POSIX dependencies, consistent with all other generators
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" "$table" "${rec_args[@]}")
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

## Error Handling

| Condition | Behavior |
|---|---|
| `--schema` not provided | `seed_custom: --schema is required` → exit 2 |
| `--schema` flag missing value | `_seed_parse_flags` guard → exit 2 |
| Schema file not found | `seed_custom: schema file not found: <resolved-path>` → exit 2 |
| Missing `table=` line | `seed_custom: missing table= line in <path>` → exit 2 |
| Unknown generator name | `seed_custom: unknown generator "<name>" in <path>` → exit 2 |

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

- Schema parsed correctly: table name and all field names extracted from `example.seed`
- Each supported `_seed_cfield_*` function produces non-empty `_SEED_RESULT`
- `_seed_cfield_number "5" "5"` always produces `5` (min/max args respected)
- `_seed_cfield_date "2024-01-01" "2024-01-01"` always produces `2024-01-01`
- `_seed_cfield_bool` output is `true` or `false` (matches `seed_bool` convention: 0 → true)
- All 4 output formats produce correct output (`json`, `kv`, `csv`, `sql`)
- `--format sql` uses schema's table name: `INSERT INTO example_records`
- `--count 3` produces 3 newline-separated records
- `--seed 42 --count 3` with `example.seed` (6 fields) produces 3 fully distinct records (full-record `sort -u | wc -l` = 3; this tests the multi-field record, not individual field values)
- `--schema` omitted → exits 2 with message containing `--schema is required`
- Unknown generator in schema → exits 2
- Missing schema file → exits 2 with resolved path in message
- Missing `table=` line → exits 2
- `--schema` flag resets to `""` across `_seed_parse_flags` calls (no bleed)
- `SEED_FIXTURES_DIR` override: `SEED_FIXTURES_DIR=/tmp seed.sh custom --schema example` fails with "schema file not found: /tmp/example.seed" (confirms env var is used in path construction)

### `tests/integration/test-cli.sh`

```bash
assert_contains "$(bash seed.sh custom --schema tests/fixtures/example.seed)" '"firstname"' "CLI custom json"
assert_contains "$(bash seed.sh custom --schema tests/fixtures/example.seed --format sql)" 'INSERT INTO example_records' "CLI custom sql table name"
bash seed.sh custom 2>/dev/null
assert_exit_code $? 2 "CLI custom --schema required"
```

### `tests/mcp/test_server.py`

- `seed_custom` is registered and callable
- Calling `seed_custom(schema="example")` passes `--schema` and `"example"` to `_run`

---

## Compatibility

- Bash 3.2+: `while IFS= read -r line`, `${var%%|*}`, `${var#*|}`, `arr[${#arr[@]}]=val` — no `declare -A`, no `+=`, no `mapfile`
- `local` inside loops: valid in bash 3.2 (function-scoped, not loop-scoped); used intentionally for clarity
- Per-field flag parser uses only parameter expansion (`${var%% *}`, `${var#* }`) and a `case` statement — no `eval`, no subshells
- `declare -f` (for generator name validation) is bash 3.2 compatible
- `tail -n 1`: POSIX utility, accepted dependency (same pattern used by `seed_country`, `seed_coordinates`, etc.)
- `_seed_cfield_bool`: 0 → `true`, 1 → `false` — matches existing `seed_bool` convention
- `_seed_cfield_uuid`: uses `_seed_uuid_gen` (reads `/dev/urandom`); deliberate exception to LCG-only pattern since no RNG state is involved
