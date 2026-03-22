# New Generator Domains Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 6 generators (seed_coordinates, seed_country, seed_credit_card, seed_log_entry, seed_error_log, seed_api_key) across 3 new domain files with full format support.

**Architecture:** Three new source files (geo.sh, finance.sh, devops.sh) follow the existing domain-grouping pattern. Two new data files (countries.txt, error_messages.txt). `_seed_random_datetime_v` helper added to scalar.sh. `--prefix` flag added to seed.sh's `_seed_parse_flags`. Each new source file is added to the `source` list in seed.sh alongside its creation.

**Tech Stack:** Bash 3.2+, awk (%.4f float formatting and Luhn check digit), existing `_seed_emit_record` / `_seed_fmt_*` infrastructure, ptyunit test framework.

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `data/countries.txt` | Create | ~60 pipe-delimited `code\|name\|region` entries |
| `data/error_messages.txt` | Create | ~25 realistic error strings, one per line |
| `src/scalar.sh` | Modify | Add `_seed_random_datetime_v` helper |
| `seed.sh` | Modify | Add `--prefix` flag; source geo/finance/devops |
| `src/geo.sh` | Create | `seed_coordinates`, `seed_country` |
| `src/finance.sh` | Create | `seed_credit_card` |
| `src/devops.sh` | Create | `seed_log_entry`, `seed_error_log`, `seed_api_key` |
| `tests/unit/test-scalar.sh` | Modify | Add `_seed_random_datetime_v` and `--prefix` tests |
| `tests/unit/test-geo.sh` | Create | Tests for geo generators |
| `tests/unit/test-finance.sh` | Create | Tests for finance generators |
| `tests/unit/test-devops.sh` | Create | Tests for devops generators |

---

## Key Conventions (read before touching any file)

**`_v` primitives:** `_seed_random_int_v`, `_seed_random_float_v`, `_seed_random_line_v` write to `_SEED_RESULT` global — no stdout, NEVER `local _SEED_RESULT`. Save to a named local immediately after each `_v` call before calling another `_v`.

**No inlining scalar generators:** Record generators CANNOT call `seed_phone`, `seed_date`, etc. — those call `_seed_parse_flags` which resets all flag globals. Inline the logic instead.

**Bash 3.2 compat:** No `declare -A`, no `${var,,}`, no `mapfile`, no `+=` on arrays or strings. Use `var="${var}suffix"` for string concat. Use `arr[${#arr[@]}]=val` for array append.

**CSV multi-count dedup pattern** (copy from existing generators):
```bash
if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
    if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
    else printf '%s\n' "$rec" | tail -n 1; fi
elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
    [[ $first -eq 0 ]] && printf '\n'
    printf '%s\n' "$rec"; first=0
else
    printf '%s\n' "$rec"
fi
```

**`_seed_json_escape` behavior:** Escapes `\` → `\\` and `"` → `\"`. Does NOT convert real newlines to `\n`. The `_seed_fmt_json` function calls it unconditionally on every field value. Stack trace frames joined with literal `\n` (backslash+n in bash string) will emerge from `_seed_fmt_json` as `\\n` — this is correct and expected.

---

## Task 1: Data files

**Files:**
- Create: `data/countries.txt`
- Create: `data/error_messages.txt`

- [ ] **Step 1: Create `data/countries.txt`**

Pipe-delimited, no leading/trailing whitespace, ≥60 entries:

```
US|United States|Americas
DE|Germany|Europe
JP|Japan|Asia
BR|Brazil|Americas
NG|Nigeria|Africa
AU|Australia|Oceania
ZA|South Africa|Africa
IN|India|Asia
CN|China|Asia
FR|France|Europe
GB|United Kingdom|Europe
MX|Mexico|Americas
IT|Italy|Europe
ES|Spain|Europe
KR|South Korea|Asia
CA|Canada|Americas
AR|Argentina|Americas
EG|Egypt|Africa
SA|Saudi Arabia|Middle East
TR|Turkey|Middle East
PL|Poland|Europe
NL|Netherlands|Europe
SE|Sweden|Europe
NO|Norway|Europe
DK|Denmark|Europe
FI|Finland|Europe
CH|Switzerland|Europe
BE|Belgium|Europe
AT|Austria|Europe
PT|Portugal|Europe
GR|Greece|Europe
CZ|Czech Republic|Europe
HU|Hungary|Europe
RO|Romania|Europe
PH|Philippines|Asia
TH|Thailand|Asia
VN|Vietnam|Asia
MY|Malaysia|Asia
ID|Indonesia|Asia
PK|Pakistan|Asia
BD|Bangladesh|Asia
LK|Sri Lanka|Asia
NZ|New Zealand|Oceania
PG|Papua New Guinea|Oceania
CO|Colombia|Americas
VE|Venezuela|Americas
PE|Peru|Americas
CL|Chile|Americas
EC|Ecuador|Americas
BO|Bolivia|Americas
PY|Paraguay|Americas
GH|Ghana|Africa
KE|Kenya|Africa
TZ|Tanzania|Africa
ET|Ethiopia|Africa
CI|Ivory Coast|Africa
CM|Cameroon|Africa
MA|Morocco|Africa
TN|Tunisia|Africa
DZ|Algeria|Africa
IL|Israel|Middle East
AE|UAE|Middle East
IQ|Iraq|Middle East
IR|Iran|Middle East
```

- [ ] **Step 2: Create `data/error_messages.txt`**

One realistic error string per line, ≥25 entries:

```
connection timeout after 30000ms
null pointer dereference in request handler
permission denied: insufficient privileges
disk quota exceeded
failed to acquire lock after 10 retries
index out of bounds: array length 5, index 7
unexpected end of input while parsing JSON
database connection refused on port 5432
memory allocation failed: out of heap space
authentication token expired
invalid checksum: expected 0xdeadbeef, got 0xbeefdead
maximum retry limit reached
socket closed unexpectedly by remote host
schema validation failed: missing required field
deadlock detected, transaction rolled back
rate limit exceeded: 429 too many requests
service unavailable: upstream dependency not responding
certificate verification failed
invalid UTF-8 sequence at byte offset 42
stack overflow in recursive function call
transaction aborted due to serialization failure
file not found: /var/data/config.json
network unreachable: no route to host
operation timed out after 5000ms
invalid argument: expected positive integer, got -1
```

- [ ] **Step 3: Verify line counts**

```bash
wc -l data/countries.txt data/error_messages.txt
```

Expected: countries ≥ 60 lines, error_messages ≥ 25 lines.

- [ ] **Step 4: Commit**

```bash
git add data/countries.txt data/error_messages.txt
git commit -m "feat: add countries and error_messages data files"
```

---

## Task 2: `_seed_random_datetime_v` helper in scalar.sh

**Files:**
- Modify: `src/scalar.sh` (add after `_seed_is_numeric`)
- Modify: `tests/unit/test-scalar.sh` (add section before `ptyunit_test_summary`)

- [ ] **Step 1: Write failing test — add to end of `tests/unit/test-scalar.sh` before `ptyunit_test_summary`**

```bash
ptyunit_test_begin "_seed_random_datetime_v"

# Format check: must be YYYY-MM-DDThh:mm:ssZ
_seed_rng_init
_seed_random_datetime_v 2025
[[ "$_SEED_RESULT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
assert_exit_code $? 0 "_seed_random_datetime_v format"

# Year is in range [2000, to_year]
_seed_random_datetime_v 2025
year="${_SEED_RESULT:0:4}"
[[ "$year" -ge 2000 && "$year" -le 2025 ]]
assert_exit_code $? 0 "_seed_random_datetime_v year in range"

# Variety: 5 calls must not all return identical results
dt1=""; dt2=""; dt3=""
_seed_random_datetime_v 2025; dt1="$_SEED_RESULT"
_seed_random_datetime_v 2025; dt2="$_SEED_RESULT"
_seed_random_datetime_v 2025; dt3="$_SEED_RESULT"
[[ "$dt1" != "$dt2" || "$dt2" != "$dt3" ]]
assert_exit_code $? 0 "_seed_random_datetime_v produces varied output"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/unit/test-scalar.sh 2>&1 | tail -20
```

Expected: failure on `_seed_random_datetime_v format` (function not found).

- [ ] **Step 3: Add `_seed_random_datetime_v` to `src/scalar.sh`**

Add after the `_seed_is_numeric` function (around line 248):

```bash
# ---------------------------------------------------------------------------
# _seed_random_datetime_v <to_year>
# Takes to_year as $1. Caller must compute to_year=$(_seed_today | cut -c1-4)
# once before the loop. Writes "YYYY-MM-DDThh:mm:ssZ" to _SEED_RESULT.
# All LCG advances in the caller's process — no subshells.
# ---------------------------------------------------------------------------
_seed_random_datetime_v() {
    local dy dm dd dmax dh dmin ds
    _seed_random_int_v 2000 "$1"; dy="$_SEED_RESULT"   # $1 = to_year
    _seed_random_int_v 1 12;      dm="$_SEED_RESULT"
    case "$dm" in
        1|3|5|7|8|10|12) dmax=31 ;;
        4|6|9|11)         dmax=30 ;;
        2) if (( dy % 400 == 0 || (dy % 4 == 0 && dy % 100 != 0) )); then dmax=29; else dmax=28; fi ;;
    esac
    _seed_random_int_v 1 "$dmax"; dd="$_SEED_RESULT"
    _seed_random_int_v 0 23;      dh="$_SEED_RESULT"
    _seed_random_int_v 0 59;      dmin="$_SEED_RESULT"
    _seed_random_int_v 0 59;      ds="$_SEED_RESULT"
    _SEED_RESULT=$(printf '%04d-%02d-%02dT%02d:%02d:%02dZ' "$dy" "$dm" "$dd" "$dh" "$dmin" "$ds")
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/unit/test-scalar.sh 2>&1 | tail -20
```

Expected: all `_seed_random_datetime_v` assertions PASS.

- [ ] **Step 5: Commit**

```bash
git add src/scalar.sh tests/unit/test-scalar.sh
git commit -m "feat: add _seed_random_datetime_v helper to scalar.sh"
```

---

## Task 3: `--prefix` flag in `seed.sh`

**Files:**
- Modify: `seed.sh` (`_seed_parse_flags`)
- Modify: `tests/unit/test-scalar.sh` (add flag parsing test)

- [ ] **Step 1: Write failing test — add to `tests/unit/test-scalar.sh` in the `helpers` section**

Add after the existing `_seed_is_numeric` tests (around line 64):

```bash
ptyunit_test_begin "flag parsing: --prefix"

# --prefix sets _SEED_FLAG_PREFIX
_seed_parse_flags --prefix pk_live_
assert_eq "pk_live_" "$_SEED_FLAG_PREFIX" "--prefix sets _SEED_FLAG_PREFIX"

# --prefix is reset on next call (no bleed)
_seed_parse_flags
assert_eq "" "$_SEED_FLAG_PREFIX" "--prefix reset on next _seed_parse_flags call"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/unit/test-scalar.sh 2>&1 | grep -A2 "prefix"
```

Expected: failure — `Unknown flag: --prefix` or `_SEED_FLAG_PREFIX` is empty after setting.

- [ ] **Step 3: Update `seed.sh` — add `_SEED_FLAG_PREFIX` to reset block and add parsing branch**

In `_seed_parse_flags`, add to the initialization block (after `_SEED_FLAG_LENGTH=""`):

```bash
    _SEED_FLAG_PREFIX=""
```

Update the comment on line 19 to include `_SEED_FLAG_PREFIX`:
```bash
#   _SEED_FLAG_SENTENCES _SEED_FLAG_ITEMS _SEED_FLAG_LENGTH _SEED_FLAG_PREFIX;
```

Add the parsing branch before the `--*)` catch-all:

```bash
            --prefix)
                if [[ $# -lt 2 ]]; then
                    printf 'Flag --prefix requires a value\n' >&2
                    return 2
                fi
                _SEED_FLAG_PREFIX="$2"; shift 2 ;;
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/unit/test-scalar.sh 2>&1 | grep -A2 "prefix"
```

Expected: both `--prefix` assertions PASS.

- [ ] **Step 5: Commit**

```bash
git add seed.sh tests/unit/test-scalar.sh
git commit -m "feat: add --prefix flag to _seed_parse_flags"
```

---

## Task 4: `src/geo.sh` — `seed_coordinates` and `seed_country`

**Files:**
- Create: `src/geo.sh`
- Create: `tests/unit/test-geo.sh`
- Modify: `seed.sh` (add `source "$SEED_HOME/src/geo.sh"`)

- [ ] **Step 1: Write failing test — create `tests/unit/test-geo.sh`**

```bash
#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/seed.sh"

ptyunit_test_begin "seed_coordinates"

out=$(seed_coordinates)
assert_contains "$out" '"lat"' "seed_coordinates has lat key"
assert_contains "$out" '"lng"' "seed_coordinates has lng key"

# lat and lng are numeric — no quotes in JSON
[[ "$out" =~ \"lat\":[0-9\-] ]]
assert_exit_code $? 0 "seed_coordinates lat is unquoted numeric"

# Worldwide range: 50 samples must include at least one negative lat
neg=$(seed_coordinates --count 50 | grep -c '"lat":-' || true)
[[ "$neg" -gt 0 ]]
assert_exit_code $? 0 "seed_coordinates includes negative lats (worldwide range)"

# seed_coordinates --seed 42 --count 3: 3 distinct records
out=$(bash "$SEED_HOME/seed.sh" coordinates --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_coordinates --seed 42 --count 3: 3 distinct"

ptyunit_test_begin "seed_country"

out=$(seed_country)
assert_contains "$out" '"code"' "seed_country has code"
assert_contains "$out" '"name"' "seed_country has name"
assert_contains "$out" '"region"' "seed_country has region"

# code matches ^[A-Z]{2}$
[[ "$out" =~ \"code\":\"[A-Z][A-Z]\" ]]
assert_exit_code $? 0 "seed_country code is 2-letter uppercase"

# seed_country --seed 42 --count 3: 3 distinct records
out=$(bash "$SEED_HOME/seed.sh" country --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_country --seed 42 --count 3: 3 distinct"

ptyunit_test_begin "data file: countries.txt"

count=$(wc -l < "$SEED_HOME/data/countries.txt" | tr -d ' ')
[[ "$count" -ge 60 ]]
assert_exit_code $? 0 "countries.txt has >= 60 entries"

ptyunit_test_summary
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/unit/test-geo.sh 2>&1 | head -20
```

Expected: failure — `seed_coordinates: command not found` or similar.

- [ ] **Step 3: Add source line to `seed.sh`**

After `source "$SEED_HOME/src/tui.sh"`, add:

```bash
source "$SEED_HOME/src/geo.sh"
```

- [ ] **Step 4: Create `src/geo.sh`**

```bash
#!/usr/bin/env bash
# src/geo.sh — geographic generators

# ---------------------------------------------------------------------------
# seed_coordinates [--count N] [--format json|kv|csv|sql]
# Generates worldwide latitude/longitude pairs. lat/lng have 4 decimal places.
# Uses inline awk with %.4f (not _seed_random_float_v which is 2 decimal places).
# _SEED_RNG_STATE is advanced in the parent process; awk only formats.
# ---------------------------------------------------------------------------
seed_coordinates() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local lat lng
        _seed_rng_init
        _SEED_RNG_STATE=$(( (1664525 * _SEED_RNG_STATE + 1013904223) % 4294967296 ))
        lat=$(awk -v s="$_SEED_RNG_STATE" 'BEGIN { printf "%.4f", (s / 4294967296.0) * 180.0 - 90.0 }')
        _SEED_RNG_STATE=$(( (1664525 * _SEED_RNG_STATE + 1013904223) % 4294967296 ))
        lng=$(awk -v s="$_SEED_RNG_STATE" 'BEGIN { printf "%.4f", (s / 4294967296.0) * 360.0 - 180.0 }')
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" coordinates lat "$lat" lng "$lng")
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

# ---------------------------------------------------------------------------
# seed_country [--count N] [--format json|kv|csv|sql]
# Backed by data/countries.txt — pipe-delimited: code|name|region
# ---------------------------------------------------------------------------
seed_country() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local line code rest name region
        _seed_random_line_v countries; line="$_SEED_RESULT"
        code="${line%%|*}"            # everything before first |
        rest="${line#*|}"             # everything after first |
        name="${rest%%|*}"            # everything before second | (in rest)
        region="${rest#*|}"           # everything after second | (in rest)
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" countries \
            code "$code" name "$name" region "$region")
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

- [ ] **Step 5: Run test to verify it passes**

```bash
bash tests/unit/test-geo.sh 2>&1
```

Expected: all assertions PASS.

- [ ] **Step 6: Commit**

```bash
git add src/geo.sh tests/unit/test-geo.sh seed.sh
git commit -m "feat: add seed_coordinates and seed_country generators (geo.sh)"
```

---

## Task 5: `src/finance.sh` — `seed_credit_card`

**Files:**
- Create: `src/finance.sh`
- Create: `tests/unit/test-finance.sh`
- Modify: `seed.sh` (add source)

- [ ] **Step 1: Write failing test — create `tests/unit/test-finance.sh`**

```bash
#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/seed.sh"

ptyunit_test_begin "seed_credit_card"

# Basic fields present
out=$(seed_credit_card)
assert_contains "$out" '"type"' "seed_credit_card has type"
assert_contains "$out" '"number"' "seed_credit_card has number"
assert_contains "$out" '"expiry"' "seed_credit_card has expiry"
assert_contains "$out" '"cvv"' "seed_credit_card has cvv"

# number and cvv are numeric (unquoted in JSON)
[[ "$out" =~ \"number\":[0-9] ]]
assert_exit_code $? 0 "seed_credit_card number is unquoted numeric"

# Luhn validity — extract raw number value and verify sum % 10 == 0
raw_num=$(printf '%s\n' "$out" | grep -o '"number":[0-9]*' | cut -d: -f2)
luhn_ok=$(printf '%s\n' "$raw_num" | awk '{
    n = length($0); sum = 0
    for (i = n; i >= 1; i--) {
        d = substr($0, i, 1) + 0
        if ((n - i + 1) % 2 == 0) { d = d * 2; if (d > 9) d -= 9 }
        sum += d
    }
    print (sum % 10 == 0) ? "valid" : "invalid"
}')
assert_eq "valid" "$luhn_ok" "credit card number passes Luhn check"

# Expiry format MM/YY
raw_exp=$(printf '%s\n' "$out" | grep -o '"expiry":"[^"]*"' | cut -d'"' -f4)
[[ "$raw_exp" =~ ^[0-9]{2}/[0-9]{2}$ ]]
assert_exit_code $? 0 "expiry matches MM/YY format"

# Type-specific prefix checks — generate 100 cards, verify prefixes
cards=$(bash "$SEED_HOME/seed.sh" credit_card --seed 42 --count 100)
visa=$(printf '%s\n' "$cards" | grep '"type":"Visa"' | head -1)
if [[ -n "$visa" ]]; then
    [[ "$visa" =~ \"number\":4 ]]
    assert_exit_code $? 0 "Visa number starts with 4"
fi
mc=$(printf '%s\n' "$cards" | grep '"type":"Mastercard"' | head -1)
if [[ -n "$mc" ]]; then
    [[ "$mc" =~ \"number\":5 ]]
    assert_exit_code $? 0 "Mastercard number starts with 5"
fi
amex=$(printf '%s\n' "$cards" | grep '"type":"Amex"' | head -1)
if [[ -n "$amex" ]]; then
    [[ "$amex" =~ \"number\":3 ]]
    assert_exit_code $? 0 "Amex number starts with 3"
    # Amex CVV is 4 digits (range 1000-9999, always no leading zero)
    amex_cvv=$(printf '%s\n' "$amex" | grep -o '"cvv":[0-9]*' | cut -d: -f2)
    [[ ${#amex_cvv} -eq 4 ]]
    assert_exit_code $? 0 "Amex CVV is 4 digits"
fi
discover=$(printf '%s\n' "$cards" | grep '"type":"Discover"' | head -1)
if [[ -n "$discover" ]]; then
    [[ "$discover" =~ \"number\":6 ]]
    assert_exit_code $? 0 "Discover number starts with 6"
fi

# --seed 42 --count 3: 3 distinct records
out=$(bash "$SEED_HOME/seed.sh" credit_card --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_credit_card --seed 42 --count 3: 3 distinct"

# --format sql: number is unquoted (numeric)
out_sql=$(seed_credit_card --format sql)
# number appears without surrounding quotes in SQL VALUES
[[ "$out_sql" =~ [[:space:]][0-9]{13,16}[,\)] ]]
assert_exit_code $? 0 "seed_credit_card --format sql: number unquoted"

# --format csv: number field is present (always quoted in CSV)
out_csv=$(seed_credit_card --format csv)
assert_contains "$out_csv" 'number' "seed_credit_card --format csv: number column present"

ptyunit_test_summary
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/unit/test-finance.sh 2>&1 | head -10
```

Expected: failure — `seed_credit_card: command not found`.

- [ ] **Step 3: Add source line to `seed.sh`**

After `source "$SEED_HOME/src/geo.sh"`, add:

```bash
source "$SEED_HOME/src/finance.sh"
```

- [ ] **Step 4: Create `src/finance.sh`**

```bash
#!/usr/bin/env bash
# src/finance.sh — financial generators

# ---------------------------------------------------------------------------
# seed_credit_card [--count N] [--format json|kv|csv|sql]
# Generates Luhn-valid card numbers for Visa, Mastercard, Amex, Discover.
# number and cvv are pure digits — emitted unquoted in JSON/SQL.
# ---------------------------------------------------------------------------
seed_credit_card() {
    _seed_parse_flags "$@" || return $?
    local to_year
    to_year=$(_seed_today | cut -c1-4)
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local type prefix cvv_len total_len
        _seed_random_int_v 0 3
        case "$_SEED_RESULT" in
            0) type="Visa";       prefix="4";    cvv_len=3; total_len=16 ;;
            1) _seed_random_int_v 51 55; prefix="$_SEED_RESULT"
               type="Mastercard"; cvv_len=3; total_len=16 ;;
            2) _seed_random_int_v 0 1
               if [[ "$_SEED_RESULT" -eq 0 ]]; then prefix="34"; else prefix="37"; fi
               type="Amex";       cvv_len=4; total_len=15 ;;
            3) type="Discover";   prefix="6011"; cvv_len=3; total_len=16 ;;
        esac

        # Build partial: prefix + random digits to fill (total_len - 1) positions
        local partial="$prefix"
        local needed=$(( total_len - 1 - ${#prefix} ))
        local k=0
        while [[ $k -lt $needed ]]; do
            _seed_random_int_v 0 9
            partial="${partial}${_SEED_RESULT}"
            k=$((k+1))
        done

        # Compute Luhn check digit via awk subshell (does not touch _SEED_RNG_STATE)
        local check_digit
        check_digit=$(awk -v partial="$partial" 'BEGIN {
            n = length(partial); sum = 0
            for (i = n; i >= 1; i--) {
                d = substr(partial, i, 1) + 0
                if ((n - i + 1) % 2 == 1) { d = d * 2; if (d > 9) d -= 9 }
                sum += d
            }
            printf "%d", (10 - (sum % 10)) % 10
        }')
        local number="${partial}${check_digit}"

        # Expiry: MM/YY — random month, year in [current+1, current+5]
        local exp_month exp_year expiry
        _seed_random_int_v 1 12;                          exp_month="$_SEED_RESULT"
        _seed_random_int_v $(( to_year + 1 )) $(( to_year + 5 )); exp_year="$_SEED_RESULT"
        expiry=$(printf '%02d/%02d' "$exp_month" "$(( exp_year % 100 ))")

        # CVV: generate as a single random integer in a no-leading-zero range.
        # Range [100,999] for 3-digit CVV; [1000,9999] for 4-digit Amex CVV.
        # This ensures _seed_fmt_json emits a valid JSON number (no leading zero).
        local cvv cvv_min cvv_max
        if [[ $cvv_len -eq 4 ]]; then cvv_min=1000; cvv_max=9999
        else                          cvv_min=100;  cvv_max=999; fi
        _seed_random_int_v "$cvv_min" "$cvv_max"; cvv="$_SEED_RESULT"

        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" credit_cards \
            type "$type" number "$number" expiry "$expiry" cvv "$cvv")
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

- [ ] **Step 5: Run test to verify it passes**

```bash
bash tests/unit/test-finance.sh 2>&1
```

Expected: all assertions PASS.

- [ ] **Step 6: Commit**

```bash
git add src/finance.sh tests/unit/test-finance.sh seed.sh
git commit -m "feat: add seed_credit_card generator with Luhn-valid numbers (finance.sh)"
```

---

## Task 6: `src/devops.sh` — `seed_log_entry`, `seed_error_log`, `seed_api_key`

**Files:**
- Create: `src/devops.sh`
- Create: `tests/unit/test-devops.sh`
- Modify: `seed.sh` (add source)

- [ ] **Step 1: Write failing test — create `tests/unit/test-devops.sh`**

```bash
#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/seed.sh"

ptyunit_test_begin "seed_log_entry"

out=$(seed_log_entry)
# Timestamp format
[[ "$out" =~ \"timestamp\":\"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\" ]]
assert_exit_code $? 0 "seed_log_entry timestamp format"

# Level in {DEBUG, INFO, WARN, ERROR}
[[ "$out" =~ \"level\":\"(DEBUG|INFO|WARN|ERROR)\" ]]
assert_exit_code $? 0 "seed_log_entry level is valid"

assert_contains "$out" '"service"' "seed_log_entry has service"
assert_contains "$out" '"message"' "seed_log_entry has message"
assert_contains "$out" '"request_id"' "seed_log_entry has request_id"

# --seed 42 --count 3: 3 distinct records
out=$(bash "$SEED_HOME/seed.sh" log_entry --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_log_entry --seed 42 --count 3: 3 distinct"

ptyunit_test_begin "seed_error_log"

out=$(seed_error_log)
# Level in {ERROR, FATAL}
[[ "$out" =~ \"level\":\"(ERROR|FATAL)\" ]]
assert_exit_code $? 0 "seed_error_log level is ERROR or FATAL"

# error_code matches ^E[0-9]{4}$
[[ "$out" =~ \"error_code\":\"E[0-9][0-9][0-9][0-9]\" ]]
assert_exit_code $? 0 "seed_error_log error_code format"

# JSON output contains stack_trace key
assert_contains "$out" '"stack_trace"' "seed_error_log JSON has stack_trace"

# CSV output does NOT contain stack_trace
out_csv=$(seed_error_log --format csv)
[[ "$out_csv" != *"stack_trace"* ]]
assert_exit_code $? 0 "seed_error_log --format csv omits stack_trace"

# SQL output does NOT contain stack_trace
out_sql=$(seed_error_log --format sql)
[[ "$out_sql" != *"stack_trace"* ]]
assert_exit_code $? 0 "seed_error_log --format sql omits stack_trace"

# KV output CONTAINS STACK_TRACE
out_kv=$(seed_error_log --format kv)
assert_contains "$out_kv" 'STACK_TRACE=' "seed_error_log --format kv has STACK_TRACE"

# --seed 42 --count 3: 3 distinct records
out=$(bash "$SEED_HOME/seed.sh" error_log --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_error_log --seed 42 --count 3: 3 distinct"

ptyunit_test_begin "seed_api_key"

# Default prefix sk_, 32 hex chars
key=$(seed_api_key)
[[ "$key" =~ ^sk_[0-9a-f]{32}$ ]]
assert_exit_code $? 0 "seed_api_key default format ^sk_[0-9a-f]{32}$"

# --prefix override
key=$(seed_api_key --prefix pk_)
[[ "$key" =~ ^pk_ ]]
assert_exit_code $? 0 "seed_api_key --prefix pk_ starts with pk_"

# Flag reset: after --prefix call, next call must use default sk_
seed_api_key --prefix custom_ > /dev/null
key2=$(seed_api_key)
[[ "$key2" =~ ^sk_ ]]
assert_exit_code $? 0 "seed_api_key prefix does not bleed across calls"

# --format rejected
seed_api_key --format json 2>/dev/null
assert_exit_code $? 2 "seed_api_key --format exits 2"

# --seed 42 --count 3: 3 distinct keys
out=$(bash "$SEED_HOME/seed.sh" api_key --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_api_key --seed 42 --count 3: 3 distinct"

ptyunit_test_begin "data file: error_messages.txt"

count=$(wc -l < "$SEED_HOME/data/error_messages.txt" | tr -d ' ')
[[ "$count" -ge 20 ]]
assert_exit_code $? 0 "error_messages.txt has >= 20 entries"

ptyunit_test_summary
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/unit/test-devops.sh 2>&1 | head -10
```

Expected: failure — `seed_log_entry: command not found`.

- [ ] **Step 3: Add source line to `seed.sh`**

After `source "$SEED_HOME/src/finance.sh"`, add:

```bash
source "$SEED_HOME/src/devops.sh"
```

- [ ] **Step 4: Create `src/devops.sh`**

```bash
#!/usr/bin/env bash
# src/devops.sh — DevOps/infrastructure generators

# ---------------------------------------------------------------------------
# seed_log_entry [--count N] [--format json|kv|csv|sql]
# Fields: timestamp, level, service, message, request_id
# ---------------------------------------------------------------------------
seed_log_entry() {
    _seed_parse_flags "$@" || return $?
    local levels
    levels=("DEBUG" "INFO" "WARN" "ERROR")
    local suffixes
    suffixes=("api" "service" "worker")
    local to_year
    to_year=$(_seed_today | cut -c1-4)
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local ts level adj noun suffix service message request_id
        _seed_random_datetime_v "$to_year"; ts="$_SEED_RESULT"
        _seed_random_int_v 0 3; level="${levels[$_SEED_RESULT]}"
        _seed_random_line_v adjectives; adj="$_SEED_RESULT"
        _seed_random_line_v nouns;      noun="$_SEED_RESULT"
        _seed_random_int_v 0 2;         suffix="${suffixes[$_SEED_RESULT]}"
        service="${adj}-${noun}-${suffix}"
        _seed_random_line_v lorem; message="$_SEED_RESULT"
        request_id=$(_seed_uuid_gen)
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" log_entries \
            timestamp "$ts" level "$level" service "$service" \
            message "$message" request_id "$request_id")
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

# ---------------------------------------------------------------------------
# seed_error_log [--count N] [--format json|kv|csv|sql]
# Fields: timestamp, level, service, error_code, message, request_id,
#         stack_trace (omitted in csv and sql formats)
#
# Stack trace: frames joined with literal \n (backslash+n). _seed_fmt_json
# will double the backslash to \\n in JSON output — this is correct behavior.
# ---------------------------------------------------------------------------
seed_error_log() {
    _seed_parse_flags "$@" || return $?
    local levels
    levels=("ERROR" "FATAL")
    local methods
    methods=("handle" "process" "execute" "validate" "parse" "dispatch" "run" "fetch" "connect")
    local suffixes
    suffixes=("api" "service" "worker")
    local to_year
    to_year=$(_seed_today | cut -c1-4)
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local ts level adj noun suffix service error_code message request_id
        _seed_random_datetime_v "$to_year"; ts="$_SEED_RESULT"
        _seed_random_int_v 0 1; level="${levels[$_SEED_RESULT]}"
        _seed_random_line_v adjectives; adj="$_SEED_RESULT"
        _seed_random_line_v nouns;      noun="$_SEED_RESULT"
        _seed_random_int_v 0 2;         suffix="${suffixes[$_SEED_RESULT]}"
        service="${adj}-${noun}-${suffix}"
        _seed_random_int_v 1000 9999; error_code="E${_SEED_RESULT}"
        _seed_random_line_v error_messages; message="$_SEED_RESULT"
        request_id=$(_seed_uuid_gen)

        # Build stack trace: 2-4 frames joined with literal \n (backslash+n)
        local num_frames stack_trace=""
        _seed_random_int_v 2 4; num_frames="$_SEED_RESULT"
        local f=0
        while [[ $f -lt $num_frames ]]; do
            local frame_noun frame_line frame_method frame
            _seed_random_line_v nouns;              frame_noun="$_SEED_RESULT"
            _seed_random_int_v 1 200;               frame_line="$_SEED_RESULT"
            _seed_random_int_v 0 $(( ${#methods[@]} - 1 )); frame_method="${methods[$_SEED_RESULT]}"
            frame="File ${frame_noun}.py, line ${frame_line}, in ${frame_method}"
            if [[ -n "$stack_trace" ]]; then
                stack_trace="${stack_trace}\n${frame}"
            else
                stack_trace="$frame"
            fi
            f=$((f+1))
        done

        # Conditionally include stack_trace (omit in csv and sql)
        # Use array to avoid word-splitting on spaces in the trace value
        local st_args
        st_args=()
        if [[ "$_SEED_FLAG_FORMAT" != "csv" && "$_SEED_FLAG_FORMAT" != "sql" ]]; then
            # stack_trace value contains spaces — array prevents word-splitting
            # \n separators will be doubled by _seed_fmt_json — do not pre-escape
            st_args[0]="stack_trace"
            st_args[1]="$stack_trace"
        fi

        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" error_logs \
            timestamp "$ts" level "$level" service "$service" \
            error_code "$error_code" message "$message" \
            request_id "$request_id" "${st_args[@]}")
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

# ---------------------------------------------------------------------------
# seed_api_key [--count N] [--prefix <str>] (rejects --format)
# Generates a prefixed 32-char lowercase hex key.
# Default prefix: sk_. Override: --prefix pk_live_
# Fully LCG-based — reproducible with --seed.
# ---------------------------------------------------------------------------
seed_api_key() {
    _seed_has_format_flag "$@" && { printf 'seed_api_key: --format not valid for scalar generators\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local prefix="${_SEED_FLAG_PREFIX:-sk_}"
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local body="" k=0
        while [[ $k -lt 16 ]]; do
            _seed_random_int_v 0 255
            body="${body}$(printf '%02x' "$_SEED_RESULT")"
            k=$((k+1))
        done
        printf '%s%s\n' "$prefix" "$body"
        i=$((i+1))
    done
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
bash tests/unit/test-devops.sh 2>&1
```

Expected: all assertions PASS.

- [ ] **Step 6: Run all existing tests to verify nothing regressed**

```bash
bash tests/unit/test-scalar.sh 2>&1 | tail -5
bash tests/unit/test-record.sh 2>&1 | tail -5
bash tests/unit/test-geo.sh 2>&1 | tail -5
bash tests/unit/test-finance.sh 2>&1 | tail -5
```

Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add src/devops.sh tests/unit/test-devops.sh seed.sh
git commit -m "feat: add seed_log_entry, seed_error_log, seed_api_key generators (devops.sh)"
```

---

## Final verification

- [ ] Run all test suites:

```bash
for f in tests/unit/test-*.sh; do
    echo "=== $f ===" && bash "$f" 2>&1 | tail -3
done
```

Expected: all suites report all tests passing, exit 0.

- [ ] Verify new generators are accessible via CLI:

```bash
bash seed.sh coordinates
bash seed.sh country
bash seed.sh credit_card
bash seed.sh log_entry
bash seed.sh error_log
bash seed.sh api_key
bash seed.sh api_key --prefix pk_live_
```

Expected: each produces well-formed output, no errors.
