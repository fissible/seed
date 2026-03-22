# Schema Wizard — Design Spec

**Date:** 2026-03-22
**Scope:** `seed.sh new custom-schema` — interactive wizard to generate `.seed` files

---

## Goal

Add `bash seed.sh new custom-schema` — an interactive terminal wizard that guides the user through defining a database table schema and writes the result as a `.seed` file consumable by `seed_custom`.

**Prerequisite:** `seed_custom` (`src/custom.sh`) must exist before the wizard's output can be used. The wizard produces valid `.seed` files regardless, and the usage comment it embeds is aspirational. The wizard can be implemented and tested independently of `seed_custom`.

---

## Architecture

```
src/new.sh          ← seed_new dispatcher + _seed_new_custom_schema wizard
                      + _seed_new_build_schema pure builder function

seed.sh             ← add: source "$SEED_HOME/src/new.sh"

tests/unit/test-new.sh   ← unit tests for seed_new and _seed_new_build_schema
```

`seed_new` follows the same pattern as all other generator families: `_seed_cli` calls `seed_${gen}`, so `bash seed.sh new custom-schema` calls `seed_new custom-schema` with zero changes to `_seed_cli` or `seed.sh` beyond adding the source line.

---

## CLI Routing

```bash
seed_new() {
    local sub="${1:-}"; shift || true
    case "$sub" in
        custom-schema) _seed_new_custom_schema "$@" ;;
        *) printf 'Usage: seed.sh new <subcommand>\n' >&2
           printf 'Available: custom-schema\n' >&2
           return 1 ;;
    esac
}
```

`seed_new` with no args or an unknown subcommand exits 1 with usage. No changes to `_seed_cli`.

---

## Wizard Flow

`_seed_new_custom_schema` is the interactive wrapper. It:
1. Guards for TTY: `[[ ! -t 0 ]]` → exit 1 with `seed new: requires an interactive terminal`
2. Collects input via bash `read` (no external tools)
3. Calls `_seed_new_build_schema` to produce the file content
4. Resolves the output path and writes the file

### Session example

```
$ bash seed.sh new custom-schema

Table name: app_users

Generators:
  1) first_name    2) last_name     3) name
  4) email         5) phone         6) uuid
  7) date          8) number        9) bool
 10) lorem        11) ip           12) url

Column name: id
Select generator [1-12, Enter to finish]: 6

Column name: email
Select generator [1-12, Enter to finish]: 4

Column name: age
Select generator [1-12, Enter to finish]: 8
  Min value [1]: 18
  Max value [100]: 80

Column name: created_at
Select generator [1-12, Enter to finish]: 7
  From date [2000-01-01]: 2020-01-01
  To date [today]:

Column name: bio
Select generator [1-12, Enter to finish]: 10
  Words [none]:
  Sentences [none]: 2

Fields so far:
  id           uuid
  email        email
  age          number --min 18 --max 80
  created_at   date --from 2020-01-01
  bio          lorem --sentences 2

Add another field? [Y/n]: n

Save to: tests/fixtures/app_users.seed
Written.
```

### Input rules

- **Table name**: required; empty input re-prompts until non-empty
- **Generator list** (canonical ordered array, indices 1–12):
  ```
  1=first_name  2=last_name  3=name   4=email   5=phone  6=uuid
  7=date        8=number     9=bool  10=lorem   11=ip    12=url
  ```
  Printed once at start, not repeated after each field (the "Fields so far" summary takes that role).
- **Column name**: prompted at the start of each iteration; empty input → loop ends (done)
- **Generator selection**: number 1–12 → select; Enter (empty) → loop ends (done); invalid input re-prompts
- **Per-field flags** (`number`, `date`, `lorem` only — all other generators are prompted with no flag questions):
  - `number`: `Min value [1]:` then `Max value [100]:` — Enter keeps default; default values are omitted from the output line (flag written only when value differs from default)
  - `date`: `From date [2000-01-01]:` then `To date [today]:` — same omit-if-default rule
  - `lorem`: `Words [none]:` then `Sentences [none]:` — both default to blank/empty; if both are provided, `--words` takes priority and `--sentences` is silently ignored (mirrors `seed_lorem`'s mutual-exclusion at runtime but resolves it at the wizard level); blank → flag omitted
- **SQL type**: inferred from generator name (not prompted — see inference table)
- **Generator name format**: names in the menu (e.g., `first_name`) are written verbatim into the `.seed` file; `seed_custom` maps them to `_seed_cfield_${name}` directly, so the underscore form is the canonical contract between wizard output and `seed_custom` dispatch
- **Primary loop exit**: after each field is added, show "Fields so far" summary then prompt `Add another field? [Y/n]:` — `Y`/`y`/Enter continues; `N`/`n` ends
- **Shortcut exits**: empty column name or empty generator selection also end the loop immediately (skips the "Add another field?" prompt)

---

## `_seed_new_build_schema` — Pure Builder

Accepts table name and col/gen_spec pairs as positional arguments; returns `.seed` file content on stdout. No I/O, no file writing — fully testable without stdin mocking.

**Signature:**
```bash
_seed_new_build_schema <table> <col1> <gen_spec1> [<col2> <gen_spec2> ...]
```

Arguments are consumed in pairs starting at `$2`. Each `gen_spec` is the generator name plus any assembled flags (e.g., `"number --min 18 --max 80"`) passed as a **single pre-quoted argument** by the caller. The builder iterates with `shift 2`:

```bash
_seed_new_build_schema() {
    local table="$1"; shift
    # emit header and table= line ...
    while [[ $# -ge 2 ]]; do
        local col="$1" gen_spec="$2"; shift 2
        local gen_name="${gen_spec%% *}"
        local sql_type
        sql_type=$(_seed_new_infer_sql_type "$gen_name")
        printf '%s|%s|%s\n' "$col" "$sql_type" "$gen_spec"
    done
}
```

The wizard builds the call using parallel indexed arrays (bash 3.2 safe):
```bash
# wizard accumulates:
cols[${#cols[@]}]="$col"
gen_specs[${#gen_specs[@]}]="$assembled_gen_spec"

# call:
_seed_new_build_schema "$table" "${cols[0]}" "${gen_specs[0]}" \
                                "${cols[1]}" "${gen_specs[1]}" ...
```

Because bash expands `"${array[i]}"` as a single word, gen_specs with spaces (e.g., `number --min 18 --max 80`) are safely passed as single arguments.

**Dynamic expansion:** The number of fields is not known until runtime, so the wizard must build the argument list in a loop rather than hardcoding indices. Example pattern:

```bash
local args=()
local j=0
while [[ $j -lt ${#cols[@]} ]]; do
    args[${#args[@]}]="${cols[$j]}"
    args[${#args[@]}]="${gen_specs[$j]}"
    j=$((j+1))
done
_seed_new_build_schema "$table" "${args[@]}"
```

**Output format:**
```
# Generated by seed.sh new custom-schema
# Usage: seed.sh custom --schema app_users --count 10 --format sql
table=app_users
id|VARCHAR(36)|uuid
email|VARCHAR(255)|email
age|INT|number --min 18 --max 80
created_at|TIMESTAMP|date --from 2020-01-01
bio|TEXT|lorem --sentences 2
```

The `# Usage:` comment substitutes the actual table name (not the placeholder `<table>`). Tests that check for this comment should match the substituted name.

---

## SQL Type Inference

`_seed_new_infer_sql_type <gen_name>` — pure function, returns SQL type string on stdout.

| Generator | SQL type |
|---|---|
| `uuid` | `VARCHAR(36)` |
| `number` | `INT` |
| `date` | `TIMESTAMP` |
| `bool` | `BOOLEAN` |
| `ip` | `VARCHAR(15)` |
| `url`, `email` | `VARCHAR(255)` |
| `first_name`, `last_name`, `name`, `phone` | `VARCHAR(100)` |
| `lorem` | `TEXT` |

---

## Output Path Resolution

Resolved by `_seed_new_custom_schema` after the wizard completes:

1. If `tests/fixtures/` exists relative to CWD → auto-write to `tests/fixtures/<table>.seed` (no prompt)
2. If `tests/` exists but `tests/fixtures/` does not → prompt `Save to [tests/fixtures/<table>.seed]:` (default shown)
3. If neither exists → prompt `Save to:` with no default (user must supply a path; re-prompts if blank)

If the resolved directory does not exist, create it with `mkdir -p` before writing.

**If the target file already exists:**
```
tests/fixtures/app_users.seed already exists. Overwrite? [y/N]:
```
Default is No. If declined, re-prompt with `Save to [<same path>]:` — user may enter a different path or press Enter to retry the overwrite prompt for the same path. Ctrl-C aborts at any point.

---

## Error Handling

| Condition | Behaviour |
|---|---|
| Not a TTY (`[[ ! -t 0 ]]`) | Exit 1: `seed new: requires an interactive terminal` |
| Empty table name | Re-prompt `Table name:` until non-empty |
| No fields added before "done" | Re-prompt: `No fields defined. Add at least one field.` |
| Invalid generator number | Re-prompt `Select generator [1-12, Enter to finish]:` |
| File already exists, overwrite declined | Re-prompt `Save to [<path>]:` |
| Save path blank (case 3 above) | Re-prompt until non-empty path supplied |
| Target directory does not exist | `mkdir -p <dir>` before writing |
| User interrupts with Ctrl-C | `trap` on `INT`; print newline + `Aborted.`; exit 1 |
| Unknown subcommand to `seed_new` | Exit 1 with usage |

---

## Testing (`tests/unit/test-new.sh`)

Tests exercise `seed_new` routing and `_seed_new_build_schema` / `_seed_new_infer_sql_type` directly. `_seed_new_custom_schema` is not directly tested (thin I/O wrapper).

- `seed_new` with no args → exits 1, output contains `Usage`
- `seed_new unknown` → exits 1
- `_seed_new_build_schema users id uuid email email` → output contains `table=users`, `id|VARCHAR(36)|uuid`, `email|VARCHAR(255)|email`
- `_seed_new_build_schema orders qty "number --min 1 --max 99"` → output contains `qty|INT|number --min 1 --max 99`
- `_seed_new_build_schema events ts "date --from 2020-01-01"` → output contains `ts|TIMESTAMP|date --from 2020-01-01`; `--to` is absent (empty default omitted)
- `_seed_new_build_schema posts body "lorem --sentences 2"` → output contains `body|TEXT|lorem --sentences 2`
- Output contains `# Generated by seed.sh new custom-schema` header comment
- Output contains `# Usage: seed.sh custom --schema users` (actual table name substituted)
- SQL type inference: `_seed_new_infer_sql_type` tested for each generator type (12 assertions)
- `lorem --words` priority: if wizard assembles `lorem --words 5` (when user entered both words and sentences), `--sentences` is absent from gen_spec

---

## Compatibility

- Bash 3.2+: uses `read`, `case`, `[[ ]]`, parameter expansion, indexed arrays (`arr[${#arr[@]}]=val`) — no `declare -A`, no `+=`, no `mapfile`
- `[[ ! -t 0 ]]` for TTY check (double-bracket, consistent with codebase style)
- No external tools in the wizard loop (no `tput`, no `awk`, no `sed`)
- `mkdir -p` is POSIX, accepted dependency (same as other file-writing utilities in the project)
