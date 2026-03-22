# Schema Wizard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `bash seed.sh new custom-schema` — an interactive terminal wizard that collects a table name and fields from the user and writes a `.seed` file consumable by `seed_custom`.

**Architecture:** A new `src/new.sh` module contains three functions: `_seed_new_infer_sql_type` (pure, no deps), `_seed_new_build_schema` (pure builder, depends on infer), and `seed_new` (dispatcher) + `_seed_new_custom_schema` (interactive wrapper). `seed.sh` gains one `source` line. Tests cover the two pure functions and the dispatcher; the interactive wrapper is not unit-tested.

**Tech Stack:** Bash 3.2+, ptyunit test framework (same as all other tests in this repo), no external tools beyond POSIX `mkdir`.

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `src/new.sh` | **Create** | All four functions: `_seed_new_infer_sql_type`, `_seed_new_build_schema`, `seed_new`, `_seed_new_custom_schema` |
| `seed.sh` | **Modify** (line 17) | Add `source "$SEED_HOME/src/new.sh"` after existing source lines |
| `tests/unit/test-new.sh` | **Create** | All unit tests for `_seed_new_infer_sql_type`, `_seed_new_build_schema`, `seed_new` routing |

**Existing files to understand before starting:**
- `seed.sh:135-153` — `_seed_cli` dispatcher and source-time guard; understand how `seed_${gen}` dispatch works
- `src/scalar.sh:97-100` — example `_v` function pattern; read to understand coding conventions
- `tests/unit/test-geo.sh` — example test file; copy its header pattern exactly
- `tests/assert-ext.sh` — provides `assert_exit_code`, `assert_contains`, `assert_not_empty`
- `docs/superpowers/specs/2026-03-22-schema-wizard-design.md` — the spec; re-read before implementing the wizard

**How to run tests:**
```bash
# Single suite (use during development):
bash tests/unit/test-new.sh

# Full suite (run before committing):
bash run.sh
```

---

## Task 1: Scaffold `src/new.sh` and wire into `seed.sh`

**Files:**
- Create: `src/new.sh`
- Modify: `seed.sh:16` (after `source "$SEED_HOME/src/devops.sh"`)

- [ ] **Step 1: Create `src/new.sh` with a stub**

```bash
#!/usr/bin/env bash
# src/new.sh — schema wizard and new-resource generators
# Bash 3.2 compatible: no declare -A, no +=, no mapfile
```

- [ ] **Step 2: Add the source line to `seed.sh`**

After line 16 (`source "$SEED_HOME/src/devops.sh"`), add:
```bash
source "$SEED_HOME/src/new.sh"
```

- [ ] **Step 3: Verify `seed.sh` still sources cleanly**

```bash
bash -c 'source seed.sh && echo OK'
```
Expected: `OK` (no errors).

- [ ] **Step 4: Commit**

```bash
git add src/new.sh seed.sh
git commit -m "feat: scaffold src/new.sh and source in seed.sh"
```

---

## Task 2: `_seed_new_infer_sql_type` with tests

**Files:**
- Modify: `src/new.sh`
- Create: `tests/unit/test-new.sh`

This is a pure function with no dependencies — implement it first so `_seed_new_build_schema` can use it.

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test-new.sh`:

```bash
#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/seed.sh"

ptyunit_test_begin "_seed_new_infer_sql_type"

assert_eq "VARCHAR(36)"  "$(_seed_new_infer_sql_type uuid)"        "uuid → VARCHAR(36)"
assert_eq "INT"          "$(_seed_new_infer_sql_type number)"      "number → INT"
assert_eq "TIMESTAMP"    "$(_seed_new_infer_sql_type date)"        "date → TIMESTAMP"
assert_eq "BOOLEAN"      "$(_seed_new_infer_sql_type bool)"        "bool → BOOLEAN"
assert_eq "VARCHAR(15)"  "$(_seed_new_infer_sql_type ip)"          "ip → VARCHAR(15)"
assert_eq "VARCHAR(255)" "$(_seed_new_infer_sql_type url)"         "url → VARCHAR(255)"
assert_eq "VARCHAR(255)" "$(_seed_new_infer_sql_type email)"       "email → VARCHAR(255)"
assert_eq "VARCHAR(100)" "$(_seed_new_infer_sql_type first_name)"  "first_name → VARCHAR(100)"
assert_eq "VARCHAR(100)" "$(_seed_new_infer_sql_type last_name)"   "last_name → VARCHAR(100)"
assert_eq "VARCHAR(100)" "$(_seed_new_infer_sql_type name)"        "name → VARCHAR(100)"
assert_eq "VARCHAR(100)" "$(_seed_new_infer_sql_type phone)"       "phone → VARCHAR(100)"
assert_eq "TEXT"         "$(_seed_new_infer_sql_type lorem)"       "lorem → TEXT"

ptyunit_test_summary
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/unit/test-new.sh
```
Expected: FAIL — `_seed_new_infer_sql_type: command not found` (or similar).

- [ ] **Step 3: Implement `_seed_new_infer_sql_type` in `src/new.sh`**

```bash
# ---------------------------------------------------------------------------
# _seed_new_infer_sql_type <gen_name>
# Returns the SQL column type for a given generator name on stdout.
# ---------------------------------------------------------------------------
_seed_new_infer_sql_type() {
    local gen="$1"
    case "$gen" in
        uuid)                              printf 'VARCHAR(36)\n'  ;;
        number)                            printf 'INT\n'          ;;
        date)                              printf 'TIMESTAMP\n'    ;;
        bool)                              printf 'BOOLEAN\n'      ;;
        ip)                                printf 'VARCHAR(15)\n'  ;;
        url|email)                         printf 'VARCHAR(255)\n' ;;
        first_name|last_name|name|phone)   printf 'VARCHAR(100)\n' ;;
        lorem)                             printf 'TEXT\n'         ;;
        *)                                 printf 'VARCHAR(255)\n' ;;
    esac
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/unit/test-new.sh
```
Expected: 12 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add src/new.sh tests/unit/test-new.sh
git commit -m "feat: add _seed_new_infer_sql_type with 12 SQL type mappings"
```

---

## Task 3: `_seed_new_build_schema` with tests

**Files:**
- Modify: `src/new.sh`
- Modify: `tests/unit/test-new.sh`

Pure builder: takes `<table> <col1> <gen_spec1> [<col2> <gen_spec2> ...]` and prints `.seed` content to stdout. `gen_spec` values that contain spaces (e.g., `"number --min 18 --max 80"`) must be passed as single quoted arguments at the call site.

- [ ] **Step 1: Add failing tests to `tests/unit/test-new.sh`**

Append before `ptyunit_test_summary`:

```bash
ptyunit_test_begin "_seed_new_build_schema"

# Basic two-field output
out=$(_seed_new_build_schema users id uuid email email)
assert_contains "$out" 'table=users'              "_seed_new_build_schema: table= line"
assert_contains "$out" 'id|VARCHAR(36)|uuid'      "_seed_new_build_schema: uuid field line"
assert_contains "$out" 'email|VARCHAR(255)|email' "_seed_new_build_schema: email field line"

# Header and usage comments use actual table name
assert_contains "$out" '# Generated by seed.sh new custom-schema' \
    "_seed_new_build_schema: header comment"
assert_contains "$out" '# Usage: seed.sh custom --schema users' \
    "_seed_new_build_schema: usage comment with table name"

# gen_spec with flags passed as single quoted arg
out=$(_seed_new_build_schema orders qty "number --min 1 --max 99")
assert_contains "$out" 'qty|INT|number --min 1 --max 99' \
    "_seed_new_build_schema: flagged gen_spec preserved"

# date with --from only; --to absent when not passed
out=$(_seed_new_build_schema events ts "date --from 2020-01-01")
assert_contains "$out" 'ts|TIMESTAMP|date --from 2020-01-01' \
    "_seed_new_build_schema: date --from present"
[[ "$out" != *"--to"* ]]
assert_exit_code $? 0 "_seed_new_build_schema: --to absent when not in gen_spec"

# lorem with --sentences
out=$(_seed_new_build_schema posts body "lorem --sentences 2")
assert_contains "$out" 'body|TEXT|lorem --sentences 2' \
    "_seed_new_build_schema: lorem --sentences"
```

- [ ] **Step 2: Run tests to verify new assertions fail**

```bash
bash tests/unit/test-new.sh
```
Expected: 12 passed (from Task 2), several FAIL for `_seed_new_build_schema`.

- [ ] **Step 3: Implement `_seed_new_build_schema` in `src/new.sh`**

```bash
# ---------------------------------------------------------------------------
# _seed_new_build_schema <table> <col1> <gen_spec1> [<col2> <gen_spec2> ...]
# Prints .seed file content to stdout. No I/O, no file writing.
# gen_spec may contain spaces (e.g. "number --min 1 --max 99") — pass each
# as a single quoted argument; the caller must pre-assemble each gen_spec.
# ---------------------------------------------------------------------------
_seed_new_build_schema() {
    local table="$1"; shift
    printf '# Generated by seed.sh new custom-schema\n'
    printf '# Usage: seed.sh custom --schema %s --count 10 --format sql\n' "$table"
    printf 'table=%s\n' "$table"
    while [[ $# -ge 2 ]]; do
        local col="$1" gen_spec="$2"; shift 2
        local gen_name="${gen_spec%% *}"
        local sql_type
        sql_type=$(_seed_new_infer_sql_type "$gen_name")
        printf '%s|%s|%s\n' "$col" "$sql_type" "$gen_spec"
    done
}
```

- [ ] **Step 4: Run tests to verify all pass**

```bash
bash tests/unit/test-new.sh
```
Expected: all assertions pass, 0 failed.

- [ ] **Step 5: Run full suite to check for regressions**

```bash
bash run.sh
```
Expected: 0 suites failed.

- [ ] **Step 6: Commit**

```bash
git add src/new.sh tests/unit/test-new.sh
git commit -m "feat: add _seed_new_build_schema pure schema content builder"
```

---

## Task 4: `seed_new` dispatcher with tests

**Files:**
- Modify: `src/new.sh`
- Modify: `tests/unit/test-new.sh`

`seed_new` dispatches subcommands. `custom-schema` → `_seed_new_custom_schema`. Unknown or missing → exits 1 with usage.

Note: `_seed_new_custom_schema` does not exist yet. The `custom-schema` branch will be tested manually in Task 5 — here we only test the error paths.

- [ ] **Step 1: Add failing tests to `tests/unit/test-new.sh`**

Append before `ptyunit_test_summary`:

```bash
ptyunit_test_begin "seed_new dispatcher"

# No args → exits 1, stderr contains "Usage"
# Capture exit code BEFORE $? is clobbered by the next statement
out=$(seed_new 2>&1); ec=$?
assert_exit_code $ec 1 "seed_new: no args exits 1"
assert_contains "$out" 'Usage' "seed_new: no args prints Usage"

# Unknown subcommand → exits 1 (direct call: $? is reliable)
seed_new totally-unknown 2>/dev/null
assert_exit_code $? 1 "seed_new: unknown subcommand exits 1"
```

- [ ] **Step 2: Run tests to verify new assertions fail**

```bash
bash tests/unit/test-new.sh
```
Expected: prior assertions pass, new `seed_new` assertions FAIL (`seed_new: command not found`).

- [ ] **Step 3: Implement `seed_new` in `src/new.sh`**

```bash
# ---------------------------------------------------------------------------
# seed_new <subcommand> [args...]
# Dispatcher for new-resource generators.
# ---------------------------------------------------------------------------
seed_new() {
    local sub="${1:-}"; shift || true
    case "$sub" in
        custom-schema) _seed_new_custom_schema "$@" ;;
        *)  printf 'Usage: seed.sh new <subcommand>\n' >&2
            printf 'Available: custom-schema\n' >&2
            return 1 ;;
    esac
}
```

- [ ] **Step 4: Run tests to verify all pass**

```bash
bash tests/unit/test-new.sh
```
Expected: all assertions pass, 0 failed.

- [ ] **Step 5: Run full suite**

```bash
bash run.sh
```
Expected: 0 suites failed.

- [ ] **Step 6: Commit**

```bash
git add src/new.sh tests/unit/test-new.sh
git commit -m "feat: add seed_new dispatcher with usage error handling"
```

---

## Task 5: `_seed_new_custom_schema` interactive wizard

**Files:**
- Modify: `src/new.sh`

This is the interactive wrapper. No unit tests — it depends on stdin being a TTY. Verify with a manual smoke test after implementation.

**Read the spec before implementing:** `docs/superpowers/specs/2026-03-22-schema-wizard-design.md` — the wizard flow, input rules, output path resolution, and error handling table are all there.

**Key implementation notes:**
- Generator list ordered array (1-indexed; index 0 is unused placeholder): `('' first_name last_name name email phone uuid date number bool lorem ip url)`
- Per-field flags: empty input means "use generator's default" — omit the flag from the gen_spec entirely. Do not compare against a default string value.
- `lorem`: only prompt for Sentences if Words was left blank (prevents both flags being set simultaneously)
- Output path: check `tests/fixtures/` first, then `tests/`, then prompt with no default
- Dynamic arg list for `_seed_new_build_schema`: build a `args` array from parallel `cols`/`gen_specs` arrays, then call `_seed_new_build_schema "$table" "${args[@]}"`

- [ ] **Step 1: Implement `_seed_new_custom_schema` in `src/new.sh`**

```bash
# ---------------------------------------------------------------------------
# _seed_new_custom_schema
# Interactive wizard: collects table name + fields, writes a .seed file.
# Requires an interactive terminal (exits 1 if stdin is not a TTY).
# ---------------------------------------------------------------------------
_seed_new_custom_schema() {
    if [[ ! -t 0 ]]; then
        printf 'seed new: requires an interactive terminal\n' >&2
        return 1
    fi

    # bash 3.2: `return` inside a trap does NOT return from the enclosing function —
    # it only returns from the trap handler and the function continues. Use `exit 1`
    # instead. This is safe because seed.sh is always invoked as a subprocess
    # (`bash seed.sh new custom-schema`), never sourced by the user's interactive shell.
    trap 'printf "\nAborted.\n" >&2; exit 1' INT

    # Generator list — 1-indexed; element 0 is unused
    local _GENS=('' first_name last_name name email phone uuid date number bool lorem ip url)

    # ── Collect table name ───────────────────────────────────────────────────
    local table=""
    while [[ -z "$table" ]]; do
        printf 'Table name: '
        read -r table
    done

    # ── Print generator menu ─────────────────────────────────────────────────
    printf '\nGenerators:\n'
    printf '  1) first_name    2) last_name     3) name\n'
    printf '  4) email         5) phone         6) uuid\n'
    printf '  7) date          8) number        9) bool\n'
    printf ' 10) lorem        11) ip           12) url\n'
    printf '\n'

    # ── Collect fields ────────────────────────────────────────────────────────
    local cols=()
    local gen_specs=()
    local done_adding=0

    while [[ $done_adding -eq 0 ]]; do
        # Inner field-collection loop
        while true; do
            printf 'Column name: '
            local col=""
            read -r col
            [[ -z "$col" ]] && break        # shortcut exit: empty col name

            # Generator selection
            local gen_num="" gen_name=""
            while true; do
                printf 'Select generator [1-12, Enter to finish]: '
                read -r gen_num
                if [[ -z "$gen_num" ]]; then
                    col=""                  # signal shortcut exit
                    break
                fi
                if [[ "$gen_num" =~ ^([1-9]|1[0-2])$ ]]; then
                    gen_name="${_GENS[$gen_num]}"
                    break
                fi
                printf 'Invalid selection. Enter a number 1-12 or press Enter to finish.\n' >&2
            done
            [[ -z "$col" ]] && break        # shortcut exit from empty gen selection

            # Per-field flags
            local gen_spec="$gen_name"
            case "$gen_name" in
                number)
                    local fmin="" fmax=""
                    printf '  Min value [1]: ';     read -r fmin
                    printf '  Max value [100]: ';   read -r fmax
                    [[ -n "$fmin" ]]  && gen_spec="${gen_spec} --min ${fmin}"
                    [[ -n "$fmax" ]]  && gen_spec="${gen_spec} --max ${fmax}"
                    ;;
                date)
                    local ffrom="" fto=""
                    printf '  From date [2000-01-01]: '; read -r ffrom
                    printf '  To date [today]: ';        read -r fto
                    [[ -n "$ffrom" ]] && gen_spec="${gen_spec} --from ${ffrom}"
                    [[ -n "$fto" ]]   && gen_spec="${gen_spec} --to ${fto}"
                    ;;
                lorem)
                    local fwords="" fsentences=""
                    printf '  Words [none]: '; read -r fwords
                    if [[ -z "$fwords" ]]; then
                        printf '  Sentences [none]: '; read -r fsentences
                    fi
                    [[ -n "$fwords" ]]     && gen_spec="${gen_spec} --words ${fwords}"
                    [[ -n "$fsentences" ]] && gen_spec="${gen_spec} --sentences ${fsentences}"
                    ;;
            esac

            cols[${#cols[@]}]="$col"
            gen_specs[${#gen_specs[@]}]="$gen_spec"

            # Show running summary
            printf '\nFields so far:\n'
            local k=0
            while [[ $k -lt ${#cols[@]} ]]; do
                printf '  %-14s %s\n' "${cols[$k]}" "${gen_specs[$k]}"
                k=$((k+1))
            done
            printf '\n'

            # Continue prompt
            printf 'Add another field? [Y/n]: '
            local again=""
            read -r again
            case "$again" in
                [Nn]) break ;;
            esac
        done

        # Guard: at least one field required
        if [[ ${#cols[@]} -eq 0 ]]; then
            printf 'No fields defined. Add at least one field.\n' >&2
        else
            done_adding=1
        fi
    done

    # ── Build schema content ──────────────────────────────────────────────────
    local args=()
    local j=0
    while [[ $j -lt ${#cols[@]} ]]; do
        args[${#args[@]}]="${cols[$j]}"
        args[${#args[@]}]="${gen_specs[$j]}"
        j=$((j+1))
    done
    local content
    content=$(_seed_new_build_schema "$table" "${args[@]}")

    # ── Resolve output path ───────────────────────────────────────────────────
    local outpath=""
    if [[ -d "tests/fixtures" ]]; then
        # Branch 1: auto-write, no prompt
        outpath="tests/fixtures/${table}.seed"
    elif [[ -d "tests" ]]; then
        # Branch 2: tests/ exists, fixtures/ does not — prompt with default.
        # Re-prompt if user enters blank (even though a default is shown, the
        # user may have accidentally pressed Enter; loop until non-empty path).
        local _default_path="tests/fixtures/${table}.seed"
        while [[ -z "$outpath" ]]; do
            printf 'Save to [%s]: ' "$_default_path"
            local ans=""
            read -r ans
            outpath="${ans:-$_default_path}"
        done
    else
        # Branch 3: no tests/ at all — prompt with no default, re-prompt if blank
        while [[ -z "$outpath" ]]; do
            printf 'Save to: '
            read -r outpath
        done
    fi

    # ── Handle existing file ──────────────────────────────────────────────────
    while [[ -f "$outpath" ]]; do
        printf '%s already exists. Overwrite? [y/N]: ' "$outpath"
        local overwrite=""
        read -r overwrite
        case "$overwrite" in
            [Yy]) break ;;
            *)
                printf 'Save to [%s]: ' "$outpath"
                local newpath=""
                read -r newpath
                outpath="${newpath:-$outpath}"
                ;;
        esac
    done

    # ── Write file ────────────────────────────────────────────────────────────
    mkdir -p "$(dirname "$outpath")"
    printf '%s\n' "$content" > "$outpath"
    printf 'Save to: %s\n' "$outpath"
    printf 'Written.\n'

    trap - INT
}
```

- [ ] **Step 2: Run the full test suite to ensure nothing regressed**

```bash
bash run.sh
```
Expected: 0 suites failed.

- [ ] **Step 3: Create `tests/fixtures/` so the wizard takes branch 1 (auto-write)**

The wizard checks for `tests/fixtures/` at runtime. If it doesn't exist, branch 2 triggers an interactive prompt, breaking the smoke test flow. Create it now:

```bash
mkdir -p tests/fixtures
```

- [ ] **Step 4: Smoke test the wizard manually**

```bash
bash seed.sh new custom-schema
```

Enter: table name `smoke_test`, add one field (`id` → `6` for uuid), answer `n` to add another. The wizard should auto-write (branch 1 — no save-path prompt). Verify the file:

```bash
cat tests/fixtures/smoke_test.seed
```
Expected output:
```
# Generated by seed.sh new custom-schema
# Usage: seed.sh custom --schema smoke_test --count 10 --format sql
table=smoke_test
id|VARCHAR(36)|uuid
```

- [ ] **Step 5: Clean up smoke test file**

```bash
rm tests/fixtures/smoke_test.seed
```

- [ ] **Step 6: Test TTY guard**

```bash
echo "" | bash seed.sh new custom-schema
echo "Exit code: $?"
```
Expected: prints `seed new: requires an interactive terminal`, exit code 1.

- [ ] **Step 7: Commit**

```bash
git add src/new.sh tests/fixtures/.gitkeep
git commit -m "feat: add _seed_new_custom_schema interactive schema wizard"
```

> Note: if `tests/fixtures/` was newly created in Step 3, commit a `.gitkeep` to track the directory. If other fixtures already live there, omit `.gitkeep` and just add `src/new.sh`.

---

## Done

After all tasks are complete:

- `bash seed.sh new custom-schema` launches the interactive wizard
- `bash seed.sh new` or `bash seed.sh new unknown` exits 1 with usage
- `bash run.sh` passes all suites

The generated `.seed` files are ready for use with `seed_custom` once `src/custom.sh` is implemented (tracked in the custom schema engine spec).
