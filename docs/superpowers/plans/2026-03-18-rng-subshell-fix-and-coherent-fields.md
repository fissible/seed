# RNG Subshell Fix and Coherent Fields — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix `--seed --count N` producing identical records, make `email`/`username` derive from the same first/last name as the `name` field, and add a `src/str.sh` string helper library.

**Architecture:** Add `_v` RNG primitives that write to `_SEED_RESULT` in the caller's process (no `$()` subshells, so `_SEED_RNG_STATE` advances in the parent), refactor all generator loop bodies to use `_v` calls, and derive `email`/`username` from shared `first_n`/`last_n` locals. `src/str.sh` provides `_seed_str_lower_v` and `_seed_str_slug_v` (bash 3.2 compatible, no dependencies).

**Tech Stack:** Bash 3.2+, POSIX `tr`, `awk`, `od`, `/dev/urandom`

---

## File Structure

**Create:**
- `src/str.sh` — `_seed_str_lower_v`, `_seed_str_slug_v`
- `tests/unit/test-str.sh` — unit tests for str.sh

**Modify:**
- `seed.sh:8` — add `source "$SEED_HOME/src/str.sh"` before all other sources
- `src/scalar.sh` — add `_v` primitives + `_v` helper variants; refactor all scalar generators
- `src/record.sh` — coherence refactor for `seed_user`; `_v` refactor for `seed_address`, `seed_company`
- `src/crm.sh` — coherence for `seed_contact`/`seed_lead`; `_v` for `seed_deal`, `seed_activity`, `seed_note`, `seed_tag`
- `src/ecommerce.sh` — `_v` refactor for all 6 generators
- `src/tui.sh` — `_v` refactor for `seed_filenames`, `seed_dirtree`, `seed_menu_items`
- `tests/unit/test-scalar.sh` — add distinctness tests
- `tests/unit/test-record.sh` — add coherence + distinctness tests
- `tests/unit/test-crm.sh` — add coherence + distinctness tests
- `tests/unit/test-ecommerce.sh` — add distinctness tests
- `tests/unit/test-tui.sh` — add distinctness tests
- `seed.sh` — add `--length` flag to `_seed_parse_flags` (Task 9)
- `src/scalar.sh` — add `seed_host`, `seed_port`, `seed_password`, `_SEED_DB_PORTS` (Task 9)
- `src/record.sh` — add `seed_db_credentials` (Task 9)

**Critical implementation rules (read before starting):**
- Never declare `local _SEED_RESULT` — it is an untyped global. Shadowing it breaks nested `_v` calls.
- Assign `_SEED_RESULT` to a named local immediately after each `_v` call; never read it after an intervening `_v` call.
- Record generator loop bodies must never call `seed_phone`, `seed_date`, `seed_name`, `seed_email` etc. — those call `_seed_parse_flags` which resets `_SEED_FLAG_*` globals. Inline all randomness using `_v` primitives directly.
- `_seed_uuid_gen` does not use LCG (reads `/dev/urandom`). Calling it via `$()` is safe — it won't affect `_SEED_RNG_STATE`.
- `_seed_today` and `_seed_date_subtract_years` use no LCG. Calling via `$()` is safe.
- `_seed_emit_record` uses no LCG. Calling via `$()` is safe.
- No `+=` on arrays (bash 3.2). Use `arr[${#arr[@]}]=value`.

---

### Task 1: src/str.sh string helper module

**Files:**
- Create: `src/str.sh`
- Create: `tests/unit/test-str.sh`
- Modify: `seed.sh` (add source line)

- [ ] **Step 1: Write the failing test**

```bash
# tests/unit/test-str.sh
#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/src/str.sh"

ptyunit_test_begin "str helpers"

_seed_str_lower_v "Mason Lambert"
assert_eq "mason lambert" "$_SEED_RESULT" "lower: mixed case"

_seed_str_lower_v "UPPER"
assert_eq "upper" "$_SEED_RESULT" "lower: all caps"

_seed_str_lower_v "already"
assert_eq "already" "$_SEED_RESULT" "lower: already lowercase"

_seed_str_slug_v "Mason Lambert"
assert_eq "mason.lambert" "$_SEED_RESULT" "slug: space to dot"

_seed_str_slug_v "Anne-Marie"
assert_eq "anne-marie" "$_SEED_RESULT" "slug: hyphen preserved"

_seed_str_slug_v "O'Brien"
assert_eq "obrien" "$_SEED_RESULT" "slug: apostrophe stripped"

ptyunit_test_summary
```

- [ ] **Step 2: Verify the test fails**

Run: `bash tests/unit/test-str.sh`
Expected: FAIL — `src/str.sh: No such file or directory`

- [ ] **Step 3: Create src/str.sh**

```bash
#!/usr/bin/env bash
# src/str.sh — string helpers for fissible/seed (bash 3.2 compatible)
# Convention: _v functions write to _SEED_RESULT global; no stdout.
# No dependencies on other seed modules — can be sourced in isolation.

# _seed_str_lower_v <str>
# Lowercase all ASCII uppercase letters. Writes to _SEED_RESULT.
_seed_str_lower_v() {
    _SEED_RESULT=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
}

# _seed_str_slug_v <str>
# Lowercase, replace spaces with '.', strip non-[a-z0-9.-]. Writes to _SEED_RESULT.
_seed_str_slug_v() {
    _SEED_RESULT=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '.' | tr -dc 'a-z0-9.-')
}
```

- [ ] **Step 4: Add source line to seed.sh**

In `seed.sh`, insert `source "$SEED_HOME/src/str.sh"` as the first source line (before `source "$SEED_HOME/src/scalar.sh"`):

```bash
source "$SEED_HOME/src/str.sh"
source "$SEED_HOME/src/scalar.sh"
source "$SEED_HOME/src/record.sh"
source "$SEED_HOME/src/ecommerce.sh"
source "$SEED_HOME/src/crm.sh"
source "$SEED_HOME/src/tui.sh"
```

- [ ] **Step 5: Verify tests pass**

Run: `bash tests/unit/test-str.sh`
Expected: all 6 assertions PASS

- [ ] **Step 6: Run full suite — must still be 163 passing**

Run (from repo root): `bash ../ptyunit/run.sh --unit`
Expected: 163 tests pass, 0 failures

- [ ] **Step 7: Commit**

```bash
git add src/str.sh tests/unit/test-str.sh seed.sh
git commit -m "feat: add src/str.sh string helper module (_seed_str_lower_v, _seed_str_slug_v)"
```

---

### Task 2: _v primitives and scalar generator refactor

**Files:**
- Modify: `src/scalar.sh`
- Modify: `tests/unit/test-scalar.sh`

- [ ] **Step 1: Add distinctness tests to test-scalar.sh**

Append a new test section before `ptyunit_test_summary`:

```bash
ptyunit_test_begin "seed --seed distinctness"

# Generators with LCG-only randomness: --seed 42 --count 3 must yield 3 distinct lines.
# These FAIL on current code (all 3 iterations get same starting state) and PASS after refactor.
for gen in name email phone date lorem ip url; do
    out=$(bash "$SEED_HOME/seed.sh" $gen --seed 42 --count 3)
    assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
        "$gen --seed 42 --count 3: 3 distinct"
done

# bool: only 2 possible values — 10 outputs must include both.
# Verify empirically after refactor: run `bash seed.sh bool --seed 42 --count 10` and confirm
# it produces both "true" and "false". If all 10 are the same value, change --seed to 99.
out=$(bash "$SEED_HOME/seed.sh" bool --seed 42 --count 10)
assert_eq "2" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "bool --seed 42 --count 10: both true and false"

# Regression: seed_name and seed_email still work as standalone generators
assert_not_empty "$(bash "$SEED_HOME/seed.sh" name)" "seed_name standalone post-refactor"
assert_not_empty "$(bash "$SEED_HOME/seed.sh" email)" "seed_email standalone post-refactor"
```

- [ ] **Step 2: Verify tests fail**

Run: `bash tests/unit/test-scalar.sh`
Expected: the `name`/`email`/`phone`/`date`/`lorem`/`ip`/`url` distinctness assertions FAIL (assert "3" but get "1"); `bool` and regression guards may pass.

- [ ] **Step 3: Add _v primitives to src/scalar.sh**

Insert the following block after `_seed_random_float` (after line 93, before `_seed_today`):

```bash
# ---------------------------------------------------------------------------
# _seed_random_int_v <min> <max>
# Like _seed_random_int but writes to _SEED_RESULT; no stdout.
# Advances _SEED_RNG_STATE in the caller's process.
# ---------------------------------------------------------------------------
_seed_random_int_v() {
    local min="${1:-1}" max="${2:-100}"
    _seed_rng_init
    _SEED_RNG_STATE=$(( (1664525 * _SEED_RNG_STATE + 1013904223) % 4294967296 ))
    _SEED_RESULT=$(( _SEED_RNG_STATE % (max - min + 1) + min ))
}

# ---------------------------------------------------------------------------
# _seed_random_float_v <min> <max>
# Like _seed_random_float but writes to _SEED_RESULT; no stdout.
# ---------------------------------------------------------------------------
_seed_random_float_v() {
    local min="${1:-1.00}" max="${2:-999.99}"
    _seed_rng_init
    _SEED_RNG_STATE=$(( (1664525 * _SEED_RNG_STATE + 1013904223) % 4294967296 ))
    _SEED_RESULT=$(awk -v s="$_SEED_RNG_STATE" -v lo="$min" -v hi="$max" \
        'BEGIN { printf "%.2f", (s / 4294967296.0) * (hi - lo) + lo }')
}

# ---------------------------------------------------------------------------
# _seed_random_line_v <name>
# Like _seed_random_line but writes to _SEED_RESULT; no stdout.
# ---------------------------------------------------------------------------
_seed_random_line_v() {
    local name="$1"
    _seed_cache_data "$name" || { _SEED_RESULT=""; return 1; }
    local uname
    uname=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    local count_var="_SEED_DATA_${uname}_N"
    local count="${!count_var}"
    if [[ $count -eq 0 ]]; then _SEED_RESULT=""; return 1; fi
    _seed_random_int_v 0 $((count - 1))
    local idx="$_SEED_RESULT"
    local line_var="_SEED_DATA_${uname}_${idx}"
    _SEED_RESULT="${!line_var}"
}

# ---------------------------------------------------------------------------
# _seed_random_state_v  (implementation detail — not in spec's primitive list,
#   but required to avoid calling _seed_random_state via $() in record generators)
# Writes a random 2-letter US state abbreviation to _SEED_RESULT; no stdout.
# ---------------------------------------------------------------------------
_seed_random_state_v() {
    local -a states=()
    local s
    for s in $_SEED_US_STATES; do
        states[${#states[@]}]="$s"
    done
    _seed_random_int_v 0 $(( ${#states[@]} - 1 ))
    _SEED_RESULT="${states[$_SEED_RESULT]}"
}

# ---------------------------------------------------------------------------
# _seed_random_zip_v  (implementation detail — same rationale as _seed_random_state_v)
# Writes a random 5-digit zip code to _SEED_RESULT; no stdout.
# ---------------------------------------------------------------------------
_seed_random_zip_v() {
    _seed_random_int_v 10000 99999
    _SEED_RESULT=$(printf '%05d' "$_SEED_RESULT")
}
```

- [ ] **Step 4: Refactor existing helpers to use _v internally**

Replace `_seed_random_line` (currently uses `idx=$(_seed_random_int ...)`):

```bash
_seed_random_line() {
    local name="$1"
    _seed_cache_data "$name" || return 1
    local uname
    uname=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    local count_var="_SEED_DATA_${uname}_N"
    local count="${!count_var}"
    [[ $count -eq 0 ]] && return 1
    _seed_random_int_v 0 $((count - 1))
    local line_var="_SEED_DATA_${uname}_${_SEED_RESULT}"
    printf '%s\n' "${!line_var}"
}
```

Replace `_seed_random_elem` (currently uses `$(_seed_random_int ...)`):

```bash
_seed_random_elem() {
    local -a arr=("$@")
    _seed_random_int_v 0 $(( ${#arr[@]} - 1 ))
    printf '%s\n' "${arr[$_SEED_RESULT]}"
}
```

Replace `_seed_random_state` (currently uses `$(_seed_random_int ...)`):

```bash
_seed_random_state() {
    _seed_random_state_v
    printf '%s\n' "$_SEED_RESULT"
}
```

Replace `_seed_random_zip` (currently uses `$(_seed_random_int ...)`):

```bash
_seed_random_zip() {
    _seed_random_zip_v
    printf '%s\n' "$_SEED_RESULT"
}
```

- [ ] **Step 5: Refactor scalar generators**

Replace each generator's loop body. Complete replacements (keep the `_seed_has_format_flag` guard and `_seed_parse_flags` call unchanged):

**seed_name:**
```bash
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local fn ln
        _seed_random_line_v first_names; fn="$_SEED_RESULT"
        _seed_random_line_v last_names;  ln="$_SEED_RESULT"
        printf '%s %s\n' "$fn" "$ln"
        i=$((i+1))
    done
```

**seed_first_name:**
```bash
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_line_v first_names
        printf '%s\n' "$_SEED_RESULT"
        i=$((i+1))
    done
```

**seed_last_name:**
```bash
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_line_v last_names
        printf '%s\n' "$_SEED_RESULT"
        i=$((i+1))
    done
```

**seed_email** (inline names rather than calling seed_first_name/seed_last_name):
```bash
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local fn ln fl ll domain
        _seed_random_line_v first_names; fn="$_SEED_RESULT"
        _seed_random_line_v last_names;  ln="$_SEED_RESULT"
        _seed_random_line_v domains;     domain="$_SEED_RESULT"
        _seed_str_lower_v "$fn"; fl="$_SEED_RESULT"
        _seed_str_lower_v "$ln"; ll="$_SEED_RESULT"
        printf '%s.%s@%s\n' "$fl" "$ll" "$domain"
        i=$((i+1))
    done
```

**seed_phone:**
```bash
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local a b c d
        _seed_random_int_v 2 9;       a="$_SEED_RESULT"
        _seed_random_int_v 10 99;     b="$_SEED_RESULT"
        _seed_random_int_v 100 999;   c="$_SEED_RESULT"
        _seed_random_int_v 1000 9999; d="$_SEED_RESULT"
        printf '%d%02d-%03d-%04d\n' "$a" "$b" "$c" "$d"
        i=$((i+1))
    done
```

**seed_date** (replace `year=$(_seed_random_int ...)`, `month=$(_seed_random_int ...)`, `day=$(_seed_random_int ...)`):
```bash
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
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
        printf '%04d-%02d-%02d\n' "$year" "$month" "$day"
        i=$((i+1))
    done
```

**seed_number:**
```bash
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_int_v "$min" "$max"
        printf '%s\n' "$_SEED_RESULT"
        i=$((i+1))
    done
```

**seed_lorem** (replace all `$(_seed_random_line lorem)` occurrences in the loop):
```bash
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        if [[ -n "$_SEED_FLAG_WORDS" ]]; then
            local sentence
            _seed_random_line_v lorem; sentence="$_SEED_RESULT"
            printf '%s\n' "$sentence" | tr ' ' '\n' | head -n "$_SEED_FLAG_WORDS" | tr '\n' ' ' | sed 's/ $//'
            printf '\n'
        elif [[ -n "$_SEED_FLAG_SENTENCES" ]]; then
            local s=0
            while [[ $s -lt $_SEED_FLAG_SENTENCES ]]; do
                _seed_random_line_v lorem
                printf '%s\n' "$_SEED_RESULT"
                s=$((s+1))
            done
        else
            _seed_random_line_v lorem
            printf '%s\n' "$_SEED_RESULT"
        fi
        i=$((i+1))
    done
```

**seed_ip:**
```bash
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local o1 o2 o3 o4
        _seed_random_int_v 1 254; o1="$_SEED_RESULT"
        _seed_random_int_v 1 254; o2="$_SEED_RESULT"
        _seed_random_int_v 1 254; o3="$_SEED_RESULT"
        _seed_random_int_v 1 254; o4="$_SEED_RESULT"
        printf '%d.%d.%d.%d\n' "$o1" "$o2" "$o3" "$o4"
        i=$((i+1))
    done
```

**seed_url:**
```bash
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local dom noun
        _seed_random_line_v domains; dom="$_SEED_RESULT"
        _seed_random_line_v nouns;   noun="$_SEED_RESULT"
        printf 'https://%s/%s\n' "$dom" "$noun"
        i=$((i+1))
    done
```

**seed_bool** (replace `$(( RANDOM % 2 ))` with `_seed_random_int_v 0 1`):
```bash
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_int_v 0 1
        if [[ "$_SEED_RESULT" -eq 0 ]]; then printf 'true\n'; else printf 'false\n'; fi
        i=$((i+1))
    done
```

- [ ] **Step 6: Verify tests pass**

Run: `bash tests/unit/test-scalar.sh`
Expected: all assertions PASS including the new distinctness tests.

If any distinctness test fails (e.g., `--seed 42` happens to produce duplicate values for a specific generator), change the seed to `99` for that generator and update the test accordingly.

- [ ] **Step 7: Run full suite**

Run: `bash ../ptyunit/run.sh --unit`
Expected: ≥163 tests pass, 0 failures

- [ ] **Step 8: Commit**

```bash
git add src/scalar.sh tests/unit/test-scalar.sh
git commit -m "feat: add _v RNG primitives and refactor scalar generators to fix --seed --count N"
```

---

### Task 3: seed_user coherence refactor

**Files:**
- Modify: `src/record.sh`
- Modify: `tests/unit/test-record.sh`

- [ ] **Step 1: Add coherence and distinctness tests to test-record.sh**

Append before `ptyunit_test_summary`:

```bash
ptyunit_test_begin "seed_user coherence and distinctness"

# Coherence: email prefix must match name's first.last (regression guard)
out=$(bash "$SEED_HOME/seed.sh" user --seed 42)
name_val=$(printf '%s' "$out" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
email_val=$(printf '%s' "$out" | grep -o '"email":"[^"]*"' | cut -d'"' -f4)
email_prefix="${email_val%@*}"
first=$(printf '%s' "$name_val" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
last=$(printf '%s' "$name_val" | cut -d' ' -f2 | tr '[:upper:]' '[:lower:]')
assert_eq "${first}.${last}" "$email_prefix" "seed_user email coherent with name"

# Distinctness: --seed 42 --count 3 must produce 3 distinct records (FAILS before fix)
out=$(bash "$SEED_HOME/seed.sh" user --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_user --seed 42 --count 3: 3 distinct records"
```

- [ ] **Step 2: Verify distinctness test fails**

Run: `bash tests/unit/test-record.sh`
Expected: distinctness assertion FAILS (gets "1" not "3"); coherence assertion may pass or fail.

- [ ] **Step 3: Replace seed_user in src/record.sh**

Replace the entire `seed_user` function body with:

```bash
seed_user() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        # Coherent name + email + username from same first/last names
        local first_n last_n name fl ll domain email username
        _seed_random_line_v first_names; first_n="$_SEED_RESULT"
        _seed_random_line_v last_names;  last_n="$_SEED_RESULT"
        name="$first_n $last_n"
        _seed_str_slug_v "$first_n"; fl="$_SEED_RESULT"
        _seed_str_slug_v "$last_n";  ll="$_SEED_RESULT"
        _seed_random_line_v domains; domain="$_SEED_RESULT"
        email="${fl}.${ll}@${domain}"
        username="${fl}.${ll}"
        # Inline phone (cannot call seed_phone — _seed_parse_flags would reset flags)
        local a b c d phone
        _seed_random_int_v 2 9;       a="$_SEED_RESULT"
        _seed_random_int_v 10 99;     b="$_SEED_RESULT"
        _seed_random_int_v 100 999;   c="$_SEED_RESULT"
        _seed_random_int_v 1000 9999; d="$_SEED_RESULT"
        phone=$(printf '%d%02d-%03d-%04d' "$a" "$b" "$c" "$d")
        # Inline DOB date (18–80 years ago)
        local today_val from_dob to_dob
        today_val=$(_seed_today)
        from_dob=$(_seed_date_subtract_years "$today_val" 80)
        to_dob=$(_seed_date_subtract_years "$today_val" 18)
        local dy dm dd dmax dob
        _seed_random_int_v "${from_dob:0:4}" "${to_dob:0:4}"; dy="$_SEED_RESULT"
        _seed_random_int_v 1 12; dm="$_SEED_RESULT"
        case "$dm" in
            1|3|5|7|8|10|12) dmax=31 ;;
            4|6|9|11)         dmax=30 ;;
            2)
                if (( dy % 400 == 0 || (dy % 4 == 0 && dy % 100 != 0) )); then
                    dmax=29
                else
                    dmax=28
                fi
                ;;
        esac
        _seed_random_int_v 1 "$dmax"; dd="$_SEED_RESULT"
        dob=$(printf '%04d-%02d-%02d' "$dy" "$dm" "$dd")
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" users \
            name "$name" email "$email" phone "$phone" dob "$dob" username "$username")
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

- [ ] **Step 4: Verify tests pass**

Run: `bash tests/unit/test-record.sh`
Expected: all assertions PASS

- [ ] **Step 5: Run full suite**

Run: `bash ../ptyunit/run.sh --unit`
Expected: ≥163 tests pass, 0 failures

- [ ] **Step 6: Commit**

```bash
git add src/record.sh tests/unit/test-record.sh
git commit -m "feat: seed_user coherence — email/username derived from same name fields"
```

---

### Task 4: seed_address and seed_company _v refactor

**Files:**
- Modify: `src/record.sh`
- Modify: `tests/unit/test-record.sh`

- [ ] **Step 1: Add distinctness tests to test-record.sh**

Append before `ptyunit_test_summary`:

```bash
ptyunit_test_begin "address and company distinctness"

out=$(bash "$SEED_HOME/seed.sh" address --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_address --seed 42 --count 3: 3 distinct"

out=$(bash "$SEED_HOME/seed.sh" company --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_company --seed 42 --count 3: 3 distinct"
```

- [ ] **Step 2: Verify tests fail**

Run: `bash tests/unit/test-record.sh`
Expected: both new distinctness assertions FAIL.

- [ ] **Step 3: Replace seed_address**

```bash
seed_address() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local num strname street city state zip
        _seed_random_int_v 1 9999;   num="$_SEED_RESULT"
        _seed_random_line_v streets; strname="$_SEED_RESULT"
        street="$num $strname"
        _seed_random_line_v cities;  city="$_SEED_RESULT"
        _seed_random_state_v;        state="$_SEED_RESULT"
        _seed_random_zip_v;          zip="$_SEED_RESULT"
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" addresses \
            street "$street" city "$city" state "$state" zip "$zip" country "US")
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

- [ ] **Step 4: Replace seed_company**

```bash
seed_company() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local name domain a b c d phone num strname street city state zip
        _seed_random_line_v companies; name="$_SEED_RESULT"
        _seed_random_line_v domains;   domain="$_SEED_RESULT"
        # Inline phone
        _seed_random_int_v 2 9;       a="$_SEED_RESULT"
        _seed_random_int_v 10 99;     b="$_SEED_RESULT"
        _seed_random_int_v 100 999;   c="$_SEED_RESULT"
        _seed_random_int_v 1000 9999; d="$_SEED_RESULT"
        phone=$(printf '%d%02d-%03d-%04d' "$a" "$b" "$c" "$d")
        _seed_random_int_v 1 9999;    num="$_SEED_RESULT"
        _seed_random_line_v streets;  strname="$_SEED_RESULT"
        street="$num $strname"
        _seed_random_line_v cities;   city="$_SEED_RESULT"
        _seed_random_state_v;         state="$_SEED_RESULT"
        _seed_random_zip_v;           zip="$_SEED_RESULT"
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" companies \
            name "$name" domain "$domain" phone "$phone" \
            street "$street" city "$city" state "$state" zip "$zip" country "US")
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

- [ ] **Step 5: Verify tests pass**

Run: `bash tests/unit/test-record.sh`
Expected: all assertions PASS

- [ ] **Step 6: Run full suite**

Run: `bash ../ptyunit/run.sh --unit`
Expected: ≥163 tests pass, 0 failures

- [ ] **Step 7: Commit**

```bash
git add src/record.sh tests/unit/test-record.sh
git commit -m "feat: seed_address and seed_company _v refactor — fix --seed distinctness"
```

---

### Task 5: seed_contact and seed_lead coherence refactor

**Files:**
- Modify: `src/crm.sh`
- Modify: `tests/unit/test-crm.sh`

- [ ] **Step 1: Add coherence and distinctness tests to test-crm.sh**

Append before `ptyunit_test_summary`:

```bash
ptyunit_test_begin "crm coherence and distinctness"

# seed_contact coherence
out=$(bash "$SEED_HOME/seed.sh" contact --seed 42)
name_val=$(printf '%s' "$out" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
email_val=$(printf '%s' "$out" | grep -o '"email":"[^"]*"' | cut -d'"' -f4)
email_prefix="${email_val%@*}"
first=$(printf '%s' "$name_val" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
last=$(printf '%s' "$name_val" | cut -d' ' -f2 | tr '[:upper:]' '[:lower:]')
assert_eq "${first}.${last}" "$email_prefix" "seed_contact email coherent with name"

out=$(bash "$SEED_HOME/seed.sh" contact --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_contact --seed 42 --count 3: 3 distinct"

# seed_lead coherence
out=$(bash "$SEED_HOME/seed.sh" lead --seed 42)
name_val=$(printf '%s' "$out" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
email_val=$(printf '%s' "$out" | grep -o '"email":"[^"]*"' | cut -d'"' -f4)
email_prefix="${email_val%@*}"
first=$(printf '%s' "$name_val" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
last=$(printf '%s' "$name_val" | cut -d' ' -f2 | tr '[:upper:]' '[:lower:]')
assert_eq "${first}.${last}" "$email_prefix" "seed_lead email coherent with name"

out=$(bash "$SEED_HOME/seed.sh" lead --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_lead --seed 42 --count 3: 3 distinct"
```

- [ ] **Step 2: Verify distinctness tests fail**

Run: `bash tests/unit/test-crm.sh`
Expected: both distinctness assertions FAIL; coherence assertions may vary.

- [ ] **Step 3: Replace seed_contact**

```bash
seed_contact() {
    _seed_parse_flags "$@" || return $?
    local titles
    titles=("Engineer" "Manager" "Director" "VP" "President" "Analyst" "Developer" "Designer" "Consultant")
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        # Coherent name + email
        local first_n last_n name fl ll domain email
        _seed_random_line_v first_names; first_n="$_SEED_RESULT"
        _seed_random_line_v last_names;  last_n="$_SEED_RESULT"
        name="$first_n $last_n"
        _seed_str_slug_v "$first_n"; fl="$_SEED_RESULT"
        _seed_str_slug_v "$last_n";  ll="$_SEED_RESULT"
        _seed_random_line_v domains; domain="$_SEED_RESULT"
        email="${fl}.${ll}@${domain}"
        # Inline phone
        local a b c d phone
        _seed_random_int_v 2 9;       a="$_SEED_RESULT"
        _seed_random_int_v 10 99;     b="$_SEED_RESULT"
        _seed_random_int_v 100 999;   c="$_SEED_RESULT"
        _seed_random_int_v 1000 9999; d="$_SEED_RESULT"
        phone=$(printf '%d%02d-%03d-%04d' "$a" "$b" "$c" "$d")
        local company
        _seed_random_line_v companies; company="$_SEED_RESULT"
        _seed_random_int_v 0 $(( ${#titles[@]} - 1 ))
        local title="${titles[$_SEED_RESULT]}"
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" contacts \
            name "$name" email "$email" phone "$phone" company "$company" title "$title")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}
```

- [ ] **Step 4: Replace seed_lead**

```bash
seed_lead() {
    _seed_parse_flags "$@" || return $?
    local titles sources statuses
    titles=("Engineer" "Manager" "Director" "VP" "President" "Analyst" "Developer" "Designer" "Consultant")
    sources=("web" "referral" "email" "phone" "event")
    statuses=("new" "contacted" "qualified" "unqualified")
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        # Coherent name + email
        local first_n last_n name fl ll domain email
        _seed_random_line_v first_names; first_n="$_SEED_RESULT"
        _seed_random_line_v last_names;  last_n="$_SEED_RESULT"
        name="$first_n $last_n"
        _seed_str_slug_v "$first_n"; fl="$_SEED_RESULT"
        _seed_str_slug_v "$last_n";  ll="$_SEED_RESULT"
        _seed_random_line_v domains; domain="$_SEED_RESULT"
        email="${fl}.${ll}@${domain}"
        # Inline phone
        local a b c d phone
        _seed_random_int_v 2 9;       a="$_SEED_RESULT"
        _seed_random_int_v 10 99;     b="$_SEED_RESULT"
        _seed_random_int_v 100 999;   c="$_SEED_RESULT"
        _seed_random_int_v 1000 9999; d="$_SEED_RESULT"
        phone=$(printf '%d%02d-%03d-%04d' "$a" "$b" "$c" "$d")
        local company
        _seed_random_line_v companies; company="$_SEED_RESULT"
        _seed_random_int_v 0 $(( ${#titles[@]} - 1 ))
        local title="${titles[$_SEED_RESULT]}"
        _seed_random_int_v 0 $(( ${#sources[@]} - 1 ))
        local source="${sources[$_SEED_RESULT]}"
        _seed_random_int_v 0 $(( ${#statuses[@]} - 1 ))
        local status="${statuses[$_SEED_RESULT]}"
        _seed_random_int_v 1 100
        local score="$_SEED_RESULT"
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" leads \
            name "$name" email "$email" phone "$phone" company "$company" title "$title" \
            source "$source" status "$status" score "$score")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}
```

- [ ] **Step 5: Verify tests pass**

Run: `bash tests/unit/test-crm.sh`
Expected: all assertions PASS

- [ ] **Step 6: Run full suite**

Run: `bash ../ptyunit/run.sh --unit`
Expected: ≥163 tests pass, 0 failures

- [ ] **Step 7: Commit**

```bash
git add src/crm.sh tests/unit/test-crm.sh
git commit -m "feat: seed_contact/seed_lead coherence — email derived from same name fields"
```

---

### Task 6: Remaining CRM generators _v refactor

**Files:**
- Modify: `src/crm.sh`

No new tests required by spec; existing tests cover format/field correctness.

- [ ] **Step 1: Replace seed_deal**

Date inline pattern (used throughout): pick year in `[2000, current_year]`, then month, then day with leap-year logic. Call `_seed_today` once before the loop if possible; in the loop body, extract year from `today_val:0:4`.

```bash
seed_deal() {
    _seed_parse_flags "$@" || return $?
    local stages
    stages=("prospecting" "qualified" "proposal" "negotiation" "closed_won" "closed_lost")
    local i=0 first=1
    local today_val to_year
    today_val=$(_seed_today)
    to_year="${today_val:0:4}"
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local adj noun title value stage
        _seed_random_line_v adjectives; adj="$_SEED_RESULT"
        _seed_random_line_v nouns;      noun="$_SEED_RESULT"
        title="$adj $noun Deal"
        _seed_random_float_v 1.00 999.99; value="$_SEED_RESULT"
        _seed_random_int_v 0 $(( ${#stages[@]} - 1 ))
        stage="${stages[$_SEED_RESULT]}"
        # Inline close_date (default seed_date range: 2000–today)
        local dy dm dd dmax close_date
        _seed_random_int_v 2000 "$to_year"; dy="$_SEED_RESULT"
        _seed_random_int_v 1 12; dm="$_SEED_RESULT"
        case "$dm" in
            1|3|5|7|8|10|12) dmax=31 ;;
            4|6|9|11)         dmax=30 ;;
            2) if (( dy % 400 == 0 || (dy % 4 == 0 && dy % 100 != 0) )); then dmax=29; else dmax=28; fi ;;
        esac
        _seed_random_int_v 1 "$dmax"; dd="$_SEED_RESULT"
        close_date=$(printf '%04d-%02d-%02d' "$dy" "$dm" "$dd")
        # Inline owner name
        local fn ln owner
        _seed_random_line_v first_names; fn="$_SEED_RESULT"
        _seed_random_line_v last_names;  ln="$_SEED_RESULT"
        owner="$fn $ln"
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" deals \
            title "$title" value "$value" stage "$stage" close_date "$close_date" owner "$owner")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}
```

- [ ] **Step 2: Replace seed_activity**

```bash
seed_activity() {
    _seed_parse_flags "$@" || return $?
    local types
    types=("call" "email" "meeting")
    local i=0 first=1
    local today_val to_year
    today_val=$(_seed_today)
    to_year="${today_val:0:4}"
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_int_v 0 $(( ${#types[@]} - 1 ))
        local type="${types[$_SEED_RESULT]}"
        # Inline email
        local fn ln fl ll domain contact_email
        _seed_random_line_v first_names; fn="$_SEED_RESULT"
        _seed_random_line_v last_names;  ln="$_SEED_RESULT"
        _seed_random_line_v domains;     domain="$_SEED_RESULT"
        _seed_str_lower_v "$fn"; fl="$_SEED_RESULT"
        _seed_str_lower_v "$ln"; ll="$_SEED_RESULT"
        contact_email="${fl}.${ll}@${domain}"
        # Inline activity_date
        local dy dm dd dmax activity_date
        _seed_random_int_v 2000 "$to_year"; dy="$_SEED_RESULT"
        _seed_random_int_v 1 12; dm="$_SEED_RESULT"
        case "$dm" in
            1|3|5|7|8|10|12) dmax=31 ;;
            4|6|9|11)         dmax=30 ;;
            2) if (( dy % 400 == 0 || (dy % 4 == 0 && dy % 100 != 0) )); then dmax=29; else dmax=28; fi ;;
        esac
        _seed_random_int_v 1 "$dmax"; dd="$_SEED_RESULT"
        activity_date=$(printf '%04d-%02d-%02d' "$dy" "$dm" "$dd")
        # Inline lorem (notes)
        local notes
        _seed_random_line_v lorem; notes="$_SEED_RESULT"
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" activities \
            type "$type" contact_email "$contact_email" activity_date "$activity_date" notes "$notes")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}
```

- [ ] **Step 3: Replace seed_note**

```bash
seed_note() {
    _seed_parse_flags "$@" || return $?
    local linked_types
    linked_types=("contact" "deal")
    local i=0 first=1
    local today_val to_year
    today_val=$(_seed_today)
    to_year="${today_val:0:4}"
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        # Inline body (lorem)
        local body
        _seed_random_line_v lorem; body="$_SEED_RESULT"
        # Inline author name
        local fn ln author
        _seed_random_line_v first_names; fn="$_SEED_RESULT"
        _seed_random_line_v last_names;  ln="$_SEED_RESULT"
        author="$fn $ln"
        # Inline created date
        local dy dm dd dmax created
        _seed_random_int_v 2000 "$to_year"; dy="$_SEED_RESULT"
        _seed_random_int_v 1 12; dm="$_SEED_RESULT"
        case "$dm" in
            1|3|5|7|8|10|12) dmax=31 ;;
            4|6|9|11)         dmax=30 ;;
            2) if (( dy % 400 == 0 || (dy % 4 == 0 && dy % 100 != 0) )); then dmax=29; else dmax=28; fi ;;
        esac
        _seed_random_int_v 1 "$dmax"; dd="$_SEED_RESULT"
        created=$(printf '%04d-%02d-%02d' "$dy" "$dm" "$dd")
        _seed_random_int_v 0 $(( ${#linked_types[@]} - 1 ))
        local linked_type="${linked_types[$_SEED_RESULT]}"
        # UUID for linked_id — /dev/urandom, not LCG; subshell is safe
        local linked_id
        linked_id=$(_seed_uuid_gen)
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" notes \
            body "$body" author "$author" created_at "$created" \
            linked_type "$linked_type" linked_id "$linked_id")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}
```

- [ ] **Step 4: Replace seed_tag**

```bash
seed_tag() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local name color
        _seed_random_line_v adjectives; name="$_SEED_RESULT"
        _seed_random_int_v 0 16777214
        color=$(printf '#%06x' "$_SEED_RESULT")
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" tags name "$name" color "$color")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}
```

- [ ] **Step 5: Run tests**

Run: `bash tests/unit/test-crm.sh`
Expected: all assertions PASS

- [ ] **Step 6: Run full suite**

Run: `bash ../ptyunit/run.sh --unit`
Expected: ≥163 tests pass, 0 failures

- [ ] **Step 7: Commit**

```bash
git add src/crm.sh
git commit -m "feat: seed_deal/activity/note/tag _v refactor — fix --seed distinctness"
```

---

### Task 7: ecommerce generators _v refactor

**Files:**
- Modify: `src/ecommerce.sh`
- Modify: `tests/unit/test-ecommerce.sh`

- [ ] **Step 1: Add distinctness tests to test-ecommerce.sh**

Append before `ptyunit_test_summary`:

```bash
ptyunit_test_begin "ecommerce distinctness with --seed"

out=$(bash "$SEED_HOME/seed.sh" product --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_product --seed 42 --count 3: 3 distinct"

out=$(bash "$SEED_HOME/seed.sh" order --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_order --seed 42 --count 3: 3 distinct"
```

- [ ] **Step 2: Verify tests fail**

Run: `bash tests/unit/test-ecommerce.sh`
Expected: product distinctness FAILS; order may pass (UUID field makes records distinct).

- [ ] **Step 3: Replace seed_product**

```bash
seed_product() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local adj noun sku_num sku_prefix sku price category desc stock
        _seed_random_line_v adjectives;  adj="$_SEED_RESULT"
        _seed_random_line_v nouns;       noun="$_SEED_RESULT"
        _seed_random_int_v 10000 99999;  sku_num="$_SEED_RESULT"
        sku_prefix=$(printf '%s' "$adj$noun" | tr '[:lower:]' '[:upper:]' | tr -dc 'A-Z' | head -c 3)
        sku="${sku_prefix}-$(printf '%05d' "$sku_num")"
        _seed_random_float_v 1.00 999.99; price="$_SEED_RESULT"
        _seed_random_line_v nouns;        category="$_SEED_RESULT"
        _seed_random_line_v lorem;        desc="$_SEED_RESULT"
        _seed_random_int_v 0 500;         stock="$_SEED_RESULT"
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" products \
            name "${adj} ${noun}" sku "$sku" price "$price" \
            category "$category" description "$desc" stock_qty "$stock")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}
```

- [ ] **Step 4: Replace seed_category**

Replace `$(( RANDOM % 2 ))` with `_seed_random_int_v 0 1`:

```bash
seed_category() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local name slug parent
        _seed_random_line_v nouns; name="$_SEED_RESULT"
        slug=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        parent=""
        _seed_random_int_v 0 1
        if [[ "$_SEED_RESULT" -eq 0 ]]; then
            _seed_random_line_v nouns; parent="$_SEED_RESULT"
        fi
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" categories \
            name "$name" slug "$slug" parent_category "$parent")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}
```

- [ ] **Step 5: Replace seed_order**

```bash
seed_order() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    local statuses
    statuses=("pending" "processing" "shipped" "delivered" "cancelled")
    local today_val to_year
    today_val=$(_seed_today)
    to_year="${today_val:0:4}"
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local oid fn ln fl ll domain email status total
        # UUID from /dev/urandom — subshell safe (no LCG)
        oid=$(_seed_uuid_gen)
        # Inline customer_email
        _seed_random_line_v first_names; fn="$_SEED_RESULT"
        _seed_random_line_v last_names;  ln="$_SEED_RESULT"
        _seed_random_line_v domains;     domain="$_SEED_RESULT"
        _seed_str_lower_v "$fn"; fl="$_SEED_RESULT"
        _seed_str_lower_v "$ln"; ll="$_SEED_RESULT"
        email="${fl}.${ll}@${domain}"
        _seed_random_int_v 0 $(( ${#statuses[@]} - 1 ))
        status="${statuses[$_SEED_RESULT]}"
        _seed_random_float_v 5.00 9999.99; total="$_SEED_RESULT"
        # Inline created date
        local dy dm dd dmax created
        _seed_random_int_v 2000 "$to_year"; dy="$_SEED_RESULT"
        _seed_random_int_v 1 12; dm="$_SEED_RESULT"
        case "$dm" in
            1|3|5|7|8|10|12) dmax=31 ;;
            4|6|9|11)         dmax=30 ;;
            2) if (( dy % 400 == 0 || (dy % 4 == 0 && dy % 100 != 0) )); then dmax=29; else dmax=28; fi ;;
        esac
        _seed_random_int_v 1 "$dmax"; dd="$_SEED_RESULT"
        created=$(printf '%04d-%02d-%02d' "$dy" "$dm" "$dd")
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" orders \
            order_id "$oid" customer_email "$email" status "$status" \
            total "$total" created_at "$created")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}
```

- [ ] **Step 6: Replace seed_order_item**

```bash
seed_order_item() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local oid adj noun sku_num sku_prefix sku qty unit_price line_total
        oid=$(_seed_uuid_gen)
        _seed_random_line_v adjectives; adj="$_SEED_RESULT"
        _seed_random_line_v nouns;      noun="$_SEED_RESULT"
        _seed_random_int_v 10000 99999; sku_num="$_SEED_RESULT"
        sku_prefix=$(printf '%s' "$adj$noun" | tr '[:lower:]' '[:upper:]' | tr -dc 'A-Z' | head -c 3)
        sku="${sku_prefix}-$(printf '%05d' "$sku_num")"
        _seed_random_int_v 1 10;          qty="$_SEED_RESULT"
        _seed_random_float_v 1.00 999.99; unit_price="$_SEED_RESULT"
        line_total=$(awk "BEGIN { printf \"%.2f\", $qty * $unit_price }")
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" order_items \
            order_id "$oid" product_sku "$sku" name "${adj} ${noun}" \
            qty "$qty" unit_price "$unit_price" line_total "$line_total")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}
```

- [ ] **Step 7: Replace seed_coupon**

Replace `$(( RANDOM % 2 ))` with `_seed_random_int_v 0 1`; inline date range `today–2028-12-31`:

```bash
seed_coupon() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    local today_val from_year
    today_val=$(_seed_today)
    from_year="${today_val:0:4}"
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local code dtype value
        # coupon code: /dev/urandom — subshell safe (no LCG)
        code=$(od -An -N6 -tx1 /dev/urandom | tr -dc 'A-Z0-9' | head -c 8)
        _seed_random_int_v 0 1
        if [[ "$_SEED_RESULT" -eq 0 ]]; then dtype="pct"; else dtype="fixed"; fi
        _seed_random_float_v 1.00 99.99; value="$_SEED_RESULT"
        # Inline date (from today to 2028-12-31)
        local dy dm dd dmax expires
        _seed_random_int_v "$from_year" 2028; dy="$_SEED_RESULT"
        _seed_random_int_v 1 12; dm="$_SEED_RESULT"
        case "$dm" in
            1|3|5|7|8|10|12) dmax=31 ;;
            4|6|9|11)         dmax=30 ;;
            2) if (( dy % 400 == 0 || (dy % 4 == 0 && dy % 100 != 0) )); then dmax=29; else dmax=28; fi ;;
        esac
        _seed_random_int_v 1 "$dmax"; dd="$_SEED_RESULT"
        expires=$(printf '%04d-%02d-%02d' "$dy" "$dm" "$dd")
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" coupons \
            code "$code" discount_type "$dtype" value "$value" expires_at "$expires")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}
```

- [ ] **Step 8: Replace seed_cart inner loop**

In `seed_cart`, replace:
- `cart_id=$(seed_uuid)` → `cart_id=$(_seed_uuid_gen)`
- `customer_email=$(seed_email)` → inline email using `_v` calls
- `adj=$(_seed_random_line adjectives)` → `_seed_random_line_v adjectives; adj="$_SEED_RESULT"`
- `noun=$(_seed_random_line nouns)` → `_seed_random_line_v nouns; noun="$_SEED_RESULT"`
- `"$(_seed_random_int 10000 99999)"` in SKU → `_seed_random_int_v 10000 99999; sku_num="$_SEED_RESULT"`, then `sku="${sku_prefix}-$(printf '%05d' "$sku_num")"`
- `qty=$(_seed_random_int 1 10)` → `_seed_random_int_v 1 10; qty="$_SEED_RESULT"`
- `up=$(_seed_random_float 1.00 999.99)` → `_seed_random_float_v 1.00 999.99; up="$_SEED_RESULT"`

The outer structure (json/kv/csv output sections) is unchanged. Only the data-generation block at the top of the outer while loop changes:

```bash
    while [[ $ci -lt $_SEED_FLAG_COUNT ]]; do
        local cart_id fn ln fl ll domain customer_email subtotal
        cart_id=$(_seed_uuid_gen)
        # Inline customer_email
        _seed_random_line_v first_names; fn="$_SEED_RESULT"
        _seed_random_line_v last_names;  ln="$_SEED_RESULT"
        _seed_random_line_v domains;     domain="$_SEED_RESULT"
        _seed_str_lower_v "$fn"; fl="$_SEED_RESULT"
        _seed_str_lower_v "$ln"; ll="$_SEED_RESULT"
        customer_email="${fl}.${ll}@${domain}"

        local item_skus item_qtys item_prices item_totals
        item_skus=(); item_qtys=(); item_prices=(); item_totals=()
        subtotal="0"
        local ii=0
        while [[ $ii -lt $item_count ]]; do
            local adj noun sku_num sku_prefix sku qty up lt
            _seed_random_line_v adjectives; adj="$_SEED_RESULT"
            _seed_random_line_v nouns;      noun="$_SEED_RESULT"
            _seed_random_int_v 10000 99999; sku_num="$_SEED_RESULT"
            sku_prefix=$(printf '%s' "$adj$noun" | tr '[:lower:]' '[:upper:]' | tr -dc 'A-Z' | head -c 3)
            sku="${sku_prefix}-$(printf '%05d' "$sku_num")"
            _seed_random_int_v 1 10;          qty="$_SEED_RESULT"
            _seed_random_float_v 1.00 999.99; up="$_SEED_RESULT"
            lt=$(awk "BEGIN { printf \"%.2f\", $qty * $up }")
            item_skus[${#item_skus[@]}]="$sku"
            item_qtys[${#item_qtys[@]}]="$qty"
            item_prices[${#item_prices[@]}]="$up"
            item_totals[${#item_totals[@]}]="$lt"
            subtotal=$(awk "BEGIN { printf \"%.2f\", $subtotal + $lt }")
            ii=$((ii+1))
        done
        # (json/kv/csv output sections unchanged)
```

- [ ] **Step 9: Verify tests pass**

Run: `bash tests/unit/test-ecommerce.sh`
Expected: all assertions PASS

- [ ] **Step 10: Run full suite**

Run: `bash ../ptyunit/run.sh --unit`
Expected: ≥163 tests pass, 0 failures

- [ ] **Step 11: Commit**

```bash
git add src/ecommerce.sh tests/unit/test-ecommerce.sh
git commit -m "feat: ecommerce generators _v refactor — fix --seed distinctness, use LCG for dtype"
```

---

### Task 8: tui generators _v refactor

**Files:**
- Modify: `src/tui.sh`
- Modify: `tests/unit/test-tui.sh`

- [ ] **Step 1: Add distinctness tests to test-tui.sh**

Append before `ptyunit_test_summary`:

```bash
ptyunit_test_begin "tui distinctness with --seed"

out=$(bash "$SEED_HOME/seed.sh" filenames --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_filenames --seed 42 --count 3: 3 distinct"

out=$(bash "$SEED_HOME/seed.sh" dirtree --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_dirtree --seed 42 --count 3: 3 distinct"

out=$(bash "$SEED_HOME/seed.sh" menu_items --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_menu_items --seed 42 --count 3: 3 distinct"
```

- [ ] **Step 2: Verify tests fail**

Run: `bash tests/unit/test-tui.sh`
Expected: all three distinctness assertions FAIL.

- [ ] **Step 3: Replace seed_filenames loop body**

The `--count` detection preamble is unchanged. Replace only the inner while loop body:

```bash
    while [[ $i -lt $count ]]; do
        local adj noun year ext name
        _seed_random_line_v adjectives; adj="$_SEED_RESULT"
        _seed_random_line_v nouns;      noun="$_SEED_RESULT"
        _seed_random_int_v 2019 2025;   year="$_SEED_RESULT"
        _seed_random_int_v 0 $(( ${#extensions[@]} - 1 ))
        ext="${extensions[$_SEED_RESULT]}"
        name="${adj}-${noun}-${year}.${ext}"
        if [[ ${#name} -gt 40 ]]; then
            name="${adj:0:8}-${noun:0:8}-${year}.${ext}"
        fi
        printf '%s\n' "$name"
        i=$((i+1))
    done
```

- [ ] **Step 4: Replace seed_dirtree loop body**

```bash
    while [[ $i -lt $count ]]; do
        local depth path d
        _seed_random_int_v 2 4; depth="$_SEED_RESULT"
        path=""
        d=0
        while [[ $d -lt $depth ]]; do
            [[ $d -gt 0 ]] && path="${path}/"
            _seed_random_line_v nouns
            path="${path}$_SEED_RESULT"
            d=$((d+1))
        done
        if [[ ${#path} -gt 60 ]]; then
            path="${path:0:60}"
        fi
        printf '%s\n' "$path"
        i=$((i+1))
    done
```

- [ ] **Step 5: Replace seed_menu_items loop body**

`_seed_title_case` uses `$()` for pure string transform — no LCG, so the subshell is fine:

```bash
    while [[ $i -lt $count ]]; do
        local adj noun label
        _seed_random_line_v adjectives; adj="$_SEED_RESULT"
        _seed_random_line_v nouns;      noun="$_SEED_RESULT"
        label="$(_seed_title_case "$adj") $(_seed_title_case "$noun")"
        if [[ ${#label} -gt 30 ]]; then
            label="${label:0:30}"
        fi
        printf '%s\n' "$label"
        i=$((i+1))
    done
```

- [ ] **Step 6: Verify tests pass**

Run: `bash tests/unit/test-tui.sh`
Expected: all assertions PASS

If any distinctness test fails (unlikely but possible with seed 42), change `--seed 42` to `--seed 99` in that specific test only.

- [ ] **Step 7: Run full suite**

Run: `bash ../ptyunit/run.sh --unit`
Expected: ≥163 tests pass (likely more due to new tests), 0 failures

- [ ] **Step 8: Commit**

```bash
git add src/tui.sh tests/unit/test-tui.sh
git commit -m "feat: tui generators _v refactor — fix --seed distinctness"
```

---

### Task 9: seed_host, seed_port, seed_password, seed_db_credentials

**Files:**
- Modify: `seed.sh` — add `--length` flag + `_SEED_FLAG_LENGTH` global to `_seed_parse_flags`
- Modify: `src/scalar.sh` — add `_SEED_DB_PORTS`, `seed_host`, `seed_port`, `seed_password`
- Modify: `src/record.sh` — add `seed_db_credentials`
- Modify: `tests/unit/test-scalar.sh` — tests for `seed_host`, `seed_port`, `seed_password`
- Modify: `tests/unit/test-record.sh` — tests for `seed_db_credentials`

**Note:** This task requires Task 2 (`_v` primitives) and Task 1 (`str.sh`) to be complete first.

`seed_host` is intentionally an alias for the domain part of `seed_url` — same data file, different name. This makes intent explicit in db/network contexts.

- [ ] **Step 1: Write failing tests**

Append to `tests/unit/test-scalar.sh` before `ptyunit_test_summary`:

```bash
ptyunit_test_begin "network scalar generators"

# seed_host: bare hostname, no scheme or path
assert_not_empty "$(seed_host)" "seed_host not empty"
[[ "$(seed_host)" =~ ^[a-z0-9.-]+\.[a-z]{2,}$ ]]
assert_exit_code $? 0 "seed_host format (no scheme, no path)"

# seed_port: must be one of the well-known port values
port=$(seed_port)
assert_not_empty "$port" "seed_port not empty"
[[ "$port" =~ ^[0-9]+$ ]]
assert_exit_code $? 0 "seed_port is numeric"
# verify it's in the known list
echo "5432 3306 6379 27017 8080 8000 3000 9200 5672 9042 1433 1521 26257 8086 11211" | grep -wq "$port"
assert_exit_code $? 0 "seed_port is a known port"

# seed_password: alphanumeric, default length 10
pwd=$(seed_password)
assert_not_empty "$pwd" "seed_password not empty"
assert_eq "10" "${#pwd}" "seed_password default length 10"
[[ "$pwd" =~ ^[A-Za-z0-9]+$ ]]
assert_exit_code $? 0 "seed_password alphanumeric only"

# seed_password --length 20
pwd=$(seed_password --length 20)
assert_eq "20" "${#pwd}" "seed_password --length 20"

# seed_password --seed 42 --count 3: 3 distinct passwords
out=$(bash "$SEED_HOME/seed.sh" password --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_password --seed 42 --count 3: 3 distinct"
```

Append to `tests/unit/test-record.sh` before `ptyunit_test_summary`:

```bash
ptyunit_test_begin "seed_db_credentials"

out=$(seed_db_credentials)
assert_contains "$out" '"host"'     "db_credentials has host"
assert_contains "$out" '"port"'     "db_credentials has port"
assert_contains "$out" '"database"' "db_credentials has database"
assert_contains "$out" '"username"' "db_credentials has username"
assert_contains "$out" '"password"' "db_credentials has password"

# username matches db_user_<N>
[[ "$(seed_db_credentials)" =~ \"username\":\"db_user_[0-9]+\" ]]
assert_exit_code $? 0 "db_credentials username format"

# password is 10 chars
pwd_val=$(printf '%s' "$(seed_db_credentials)" | grep -o '"password":"[^"]*"' | cut -d'"' -f4)
assert_eq "10" "${#pwd_val}" "db_credentials password length 10"

# distinctness
out=$(bash "$SEED_HOME/seed.sh" db_credentials --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_db_credentials --seed 42 --count 3: 3 distinct"
```

- [ ] **Step 2: Verify tests fail**

Run: `bash tests/unit/test-scalar.sh && bash tests/unit/test-record.sh`
Expected: all new assertions FAIL — generators not defined yet.

- [ ] **Step 3: Add --length flag to seed.sh**

In `_seed_parse_flags`, add `_SEED_FLAG_LENGTH=""` to the initialization block (with the other flag resets), then add the case:

```bash
            --length)
                if [[ $# -lt 2 ]]; then
                    printf 'Flag --length requires a value\n' >&2
                    return 2
                fi
                _SEED_FLAG_LENGTH="$2"; shift 2 ;;
```

Also update the comment block above `_seed_parse_flags` to include `_SEED_FLAG_LENGTH` in the globals list.

- [ ] **Step 4: Add generators to src/scalar.sh**

Append to the end of `src/scalar.sh`:

```bash
# ---------------------------------------------------------------------------
# Shared port list for seed_port and seed_db_credentials.
# Space-separated string — build array with loop (bash 3.2 compatible).
# ---------------------------------------------------------------------------
_SEED_DB_PORTS="5432 3306 6379 27017 8080 8000 3000 9200 5672 9042 1433 1521 26257 8086 11211"

seed_host() {
    _seed_has_format_flag "$@" && { printf 'seed_host: --format not valid for scalar generators\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_line_v domains
        printf '%s\n' "$_SEED_RESULT"
        i=$((i+1))
    done
}

seed_port() {
    _seed_has_format_flag "$@" && { printf 'seed_port: --format not valid for scalar generators\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local -a ports=()
    local p
    for p in $_SEED_DB_PORTS; do ports[${#ports[@]}]="$p"; done
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_int_v 0 $(( ${#ports[@]} - 1 ))
        printf '%s\n' "${ports[$_SEED_RESULT]}"
        i=$((i+1))
    done
}

seed_password() {
    _seed_has_format_flag "$@" && { printf 'seed_password: --format not valid for scalar generators\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local length="${_SEED_FLAG_LENGTH:-10}"
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local pwd="" j=0
        while [[ $j -lt $length ]]; do
            _seed_random_int_v 0 61
            pwd="${pwd}${chars:$_SEED_RESULT:1}"
            j=$((j+1))
        done
        printf '%s\n' "$pwd"
        i=$((i+1))
    done
}
```

- [ ] **Step 5: Add seed_db_credentials to src/record.sh**

Append to the end of `src/record.sh`:

```bash
# ---------------------------------------------------------------------------
# seed_db_credentials [--count N] [--format json|kv|csv|sql]
# Fields: host, port (numeric), database, username (db_user_N), password (10 chars)
# ---------------------------------------------------------------------------
seed_db_credentials() {
    _seed_parse_flags "$@" || return $?
    local -a ports=()
    local p
    for p in $_SEED_DB_PORTS; do ports[${#ports[@]}]="$p"; done
    local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local host port database username password
        _seed_random_line_v domains; host="$_SEED_RESULT"
        _seed_random_int_v 0 $(( ${#ports[@]} - 1 ))
        port="${ports[$_SEED_RESULT]}"
        _seed_random_line_v nouns; database="$_SEED_RESULT"
        _seed_random_int_v 1 999; username="db_user_$_SEED_RESULT"
        local pwd="" j=0
        while [[ $j -lt 10 ]]; do
            _seed_random_int_v 0 61
            pwd="${pwd}${chars:$_SEED_RESULT:1}"
            j=$((j+1))
        done
        password="$pwd"
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" db_credentials \
            host "$host" port "$port" database "$database" \
            username "$username" password "$password")
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

- [ ] **Step 6: Verify tests pass**

Run: `bash tests/unit/test-scalar.sh && bash tests/unit/test-record.sh`
Expected: all assertions PASS.

If `seed_password --seed 42 --count 3` distinctness fails (very unlikely with 62-char alphabet × 10 positions), change to `--seed 99`.

- [ ] **Step 7: Run full suite**

Run: `bash ../ptyunit/run.sh --unit`
Expected: all prior tests pass + new assertions pass, 0 failures.

- [ ] **Step 8: Commit**

```bash
git add seed.sh src/scalar.sh src/record.sh tests/unit/test-scalar.sh tests/unit/test-record.sh
git commit -m "feat: add seed_host, seed_port, seed_password, seed_db_credentials generators"
```
