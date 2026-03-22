# RNG & Data Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix randomness correlation, add data-file caching, add `--seed` flag for reproducibility, fix `seed_date` day range, and expand data files — all with unit tests.

**Architecture:** Global LCG state (`_SEED_RNG_STATE`) replaces per-call awk seeding; data files are cached in numbered globals on first load; `--seed` is a new flag in `_seed_parse_flags` that sets the initial RNG state; `seed_date` derives max-day per month/year.

**Tech Stack:** bash 3.2+, awk (floats only), od (urandom seeding)

---

## File Map

| File | Action | What changes |
|---|---|---|
| `data/first_names.txt` | Modify | Add ~50 names (148 total) |
| `data/last_names.txt` | Modify | Add ~50 names (149 total) |
| `data/lorem.txt` | Modify | Add ~40 sentences (60 total) |
| `src/scalar.sh` | Modify | `_seed_rng_init`, `_seed_random_int`, `_seed_random_float`, `_seed_cache_data`, `_seed_random_line`, `seed_date` |
| `seed.sh` | Modify | `_seed_parse_flags`: add `--seed` flag |
| `tests/unit/test-scalar.sh` | Modify | Tests for RNG variety, caching, date range |
| `tests/unit/test-flags.sh` | Modify | Tests for `--seed` flag parsing and reproducibility |

---

## Task 1: Expand data files

**Files:**
- Modify: `data/first_names.txt`
- Modify: `data/last_names.txt`
- Modify: `data/lorem.txt`

No code changes. Verify with line count assertions at the end.

- [ ] **Step 1: Append to `data/first_names.txt`**

Add these 50 names (one per line, at the end of the file):

```
Sofia
Zoe
Mia
Luna
Nora
Hazel
Ellie
Violet
Aurora
Stella
Chloe
Penelope
Scarlett
Elena
Ivy
Ruby
Lydia
Naomi
Aria
Maya
Diana
Willow
Abigail
Eva
Leah
Liam
Noah
Mason
Lucas
Oliver
Aiden
Elijah
Logan
Owen
Carter
Hudson
Wyatt
Sebastian
Theo
Finn
Declan
Miles
Jasper
Ryder
Cole
Blake
Reid
Nolan
Silas
Axel
```

- [ ] **Step 2: Append to `data/last_names.txt`**

Add these 50 names:

```
Collins
Reed
Bell
Wright
Hughes
Stewart
Sanchez
Rogers
Perry
Powell
Sullivan
Murphy
Rivera
Cook
Morgan
Bailey
Cooper
Richardson
Cox
Howard
Ward
Torres
Gray
Ramirez
Watson
Brooks
Kelly
Sanders
Price
Bennett
Wood
Barnes
Ross
Henderson
Coleman
Jenkins
Patterson
Griffin
Diaz
Hayes
Myers
Long
Fisher
Stone
Andrews
Butler
Simmons
Foster
Flores
Nguyen
```

- [ ] **Step 3: Append to `data/lorem.txt`**

Add these 40 sentences:

```
Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.
Quisque commodo velit vitae augue fermentum ac dapibus augue lobortis.
Suspendisse potenti sed feugiat nibh blandit pellentesque laoreet.
Fusce euismod magna non purus tincidunt vel condimentum augue volutpat.
Nulla facilisi cras porta eros a nunc pharetra eu finibus diam lacinia.
Phasellus tristique orci a commodo euismod lorem libero feugiat augue.
Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae.
Donec tincidunt erat a magna vehicula at fermentum odio condimentum.
Aenean bibendum velit id libero tincidunt at bibendum enim dignissim.
Integer faucibus eros at quam vehicula sed efficitur justo accumsan.
Morbi volutpat enim sit amet nibh scelerisque at ornare ligula porta.
Proin aliquam purus vel ante finibus at convallis enim dictum.
Curabitur sodales nulla ut sapien facilisis vel commodo sem gravida.
Nam porta dui sit amet quam iaculis et fringilla dolor aliquam.
Etiam vulputate lorem a velit aliquet vel feugiat dolor ornare.
Sed gravida est quis justo tincidunt vel porta metus rutrum.
Aliquam erat volutpat maecenas fringilla orci a rhoncus lobortis faucibus.
Mauris posuere lectus in tortor varius vel interdum ipsum porttitor.
Nullam egestas metus at nunc pretium id aliquet ipsum maximus.
Vivamus ornare turpis vel augue tincidunt at facilisis libero posuere.
Praesent laoreet erat vel justo dignissim at tincidunt nulla condimentum.
Interdum et malesuada fames ac ante ipsum primis in faucibus orci.
Duis vulputate nisi in lorem commodo vel efficitur libero facilisis.
Pellentesque faucibus risus vel tortor porta id tincidunt nulla maximus.
Cras elementum diam at nibh aliquet vel accumsan lorem lobortis.
Fusce ornare mi vel orci condimentum at pharetra velit faucibus.
Maecenas porta enim sit amet nunc gravida at fermentum diam posuere.
Nunc posuere sapien vel augue bibendum id ornare lorem tincidunt.
Aenean dignissim quam a tortor lobortis vel efficitur libero faucibus.
Vestibulum tincidunt erat vel nulla aliquet at porta lorem gravida.
Sed bibendum justo vel augue aliquet at fringilla nibh condimentum.
Proin efficitur lorem vel nibh commodo id tincidunt enim dignissim.
Integer aliquet risus a justo maximus vel ornare lorem posuere.
Morbi tincidunt erat vel sapien faucibus id bibendum nulla lobortis.
Etiam fringilla libero vel tortor condimentum at fermentum lorem aliquet.
Curabitur accumsan enim vel augue dignissim at lobortis libero maximus.
Aliquam lobortis nisi vel quam tincidunt id ornare erat faucibus.
Praesent bibendum justo a lorem condimentum vel aliquet nibh posuere.
Vivamus efficitur metus vel sapien lobortis at fringilla erat tincidunt.
Nam tincidunt nulla a lorem dignissim vel bibendum augue faucibus.
```

- [ ] **Step 4: Write failing tests for data file sizes**

Add to `tests/unit/test-scalar.sh` (before `ptyunit_test_summary`):

```bash
ptyunit_test_begin "data file sizes"
first_count=$(wc -l < "$SEED_HOME/data/first_names.txt" | tr -d ' ')
last_count=$(wc -l  < "$SEED_HOME/data/last_names.txt"  | tr -d ' ')
lorem_count=$(wc -l < "$SEED_HOME/data/lorem.txt"       | tr -d ' ')
[[ "$first_count" -ge 140 ]]
assert_exit_code $? 0 "first_names has >= 140 entries"
[[ "$last_count"  -ge 140 ]]
assert_exit_code $? 0 "last_names has >= 140 entries"
[[ "$lorem_count" -ge 55 ]]
assert_exit_code $? 0 "lorem has >= 55 entries"
```

- [ ] **Step 5: Run tests to verify they fail**

```bash
bash tests/unit/test-scalar.sh 2>&1 | tail -5
```
Expected: FAIL on the new size assertions (file not yet edited).

- [ ] **Step 6: Run tests to verify they pass after edits**

```bash
bash tests/unit/test-scalar.sh 2>&1 | tail -5
```
Expected: all size assertions PASS.

- [ ] **Step 7: Commit**

```bash
git add data/first_names.txt data/last_names.txt data/lorem.txt tests/unit/test-scalar.sh
git commit -m "data: expand first_names, last_names, lorem data files"
```

---

## Task 2: Fix RNG — replace per-call seeding with global LCG state

**Files:**
- Modify: `src/scalar.sh` — `_seed_rng_init`, `_seed_random_int`, `_seed_random_float`

**Background:** The current `_seed_random_int` re-seeds awk with `"${$}${RANDOM}"` on each call. Within one process the PID never changes, so adjacent calls share a correlated seed. Replace with a global LCG (linear congruential generator) whose state persists across calls. LCG params (Knuth/NR): `a=1664525, c=1013904223, m=2^32`. State is advanced in bash arithmetic (no overflow risk: 1664525 × 4294967295 < 2^63). Floats still need awk; ints do not.

- [ ] **Step 1: Write failing test for RNG variety**

Add to `tests/unit/test-scalar.sh` (before `ptyunit_test_summary`):

```bash
ptyunit_test_begin "rng variety"
# 10 numbers in [1,1000] must have at least 6 unique values
uniq_count=$(seed_number --count 10 --max 1000 | sort -u | wc -l | tr -d ' ')
[[ "$uniq_count" -ge 6 ]]
assert_exit_code $? 0 "_seed_random_int produces varied output"

# _seed_random_float variety: 5 prices must not all be the same
prices=$(seed_number --count 5 --max 999)
first_price=$(printf '%s\n' "$prices" | head -1)
different=$(printf '%s\n' "$prices" | grep -vc "^${first_price}$" || true)
[[ "$different" -gt 0 ]]
assert_exit_code $? 0 "_seed_random_int values are not all identical"
```

- [ ] **Step 2: Run to confirm current behavior can fail (may pass by luck — that's OK)**

```bash
bash tests/unit/test-scalar.sh 2>&1 | grep -E "rng variety|FAIL"
```

- [ ] **Step 3: Add `_seed_rng_init` and rewrite `_seed_random_int` / `_seed_random_float` in `src/scalar.sh`**

Replace the existing `_seed_random_int` and `_seed_random_float` blocks with:

```bash
# ---------------------------------------------------------------------------
# Global LCG RNG state. Seeded lazily on first use, or explicitly via --seed.
# ---------------------------------------------------------------------------
_SEED_RNG_STATE=""

# _seed_rng_init
# Idempotent. Seeds _SEED_RNG_STATE from /dev/urandom (or PID+RANDOM fallback).
# Does nothing if state is already set.
_seed_rng_init() {
    [[ -n "$_SEED_RNG_STATE" ]] && return
    if [[ -r /dev/urandom ]]; then
        _SEED_RNG_STATE=$(od -An -N4 -tu4 /dev/urandom | tr -d ' \n')
    else
        _SEED_RNG_STATE=$(awk -v p="$$" -v r1="$RANDOM" -v r2="$RANDOM" \
            'BEGIN { printf "%d", (p * 1000003 + r1 * 65537 + r2) % 4294967296 }')
    fi
}

# ---------------------------------------------------------------------------
# _seed_random_int <min> <max>
# Print a random integer in [min, max] inclusive.
# Advances global LCG state; no per-call seeding.
# ---------------------------------------------------------------------------
_seed_random_int() {
    local min="${1:-1}" max="${2:-100}"
    _seed_rng_init
    _SEED_RNG_STATE=$(( (1664525 * _SEED_RNG_STATE + 1013904223) % 4294967296 ))
    printf '%d\n' $(( _SEED_RNG_STATE % (max - min + 1) + min ))
}

# ---------------------------------------------------------------------------
# _seed_random_float <min> <max>
# Print a random float with 2 decimal places in [min, max].
# ---------------------------------------------------------------------------
_seed_random_float() {
    local min="${1:-1.00}" max="${2:-999.99}"
    _seed_rng_init
    _SEED_RNG_STATE=$(( (1664525 * _SEED_RNG_STATE + 1013904223) % 4294967296 ))
    awk -v s="$_SEED_RNG_STATE" -v lo="$min" -v hi="$max" \
        'BEGIN { printf "%.2f", (s / 4294967296.0) * (hi - lo) + lo }'
}
```

> **Note on modulo bias:** `_SEED_RNG_STATE % range` has slight bias when `range` doesn't divide 2^32. For fake-data generation this is inconsequential.

- [ ] **Step 4: Run tests**

```bash
bash tests/unit/test-scalar.sh 2>&1 | tail -10
```
Expected: all tests PASS including new rng variety tests.

Also run the full suite to verify no regressions:
```bash
bash tests/unit/test-record.sh 2>&1 | tail -5
bash tests/unit/test-crm.sh 2>&1 | tail -5
bash tests/unit/test-ecommerce.sh 2>&1 | tail -5
```

- [ ] **Step 5: Commit**

```bash
git add src/scalar.sh tests/unit/test-scalar.sh
git commit -m "fix: replace per-call awk seeding with global LCG RNG state"
```

---

## Task 3: Add `--seed` flag for reproducibility

**Files:**
- Modify: `seed.sh` — `_seed_parse_flags`
- Modify: `tests/unit/test-flags.sh`

**How it works:** `--seed N` sets `_SEED_RNG_STATE=N` inside `_seed_parse_flags`. Because `_seed_rng_init` is idempotent (does nothing if state already set), subsequent `_seed_random_int` calls advance from that seed. Two calls with the same `--seed` produce identical output.

**Important — LCG state persistence:** `_seed_parse_flags` does NOT reset `_SEED_RNG_STATE` in its default-reset block. This is intentional: the LCG state carries over between generators in the same process (library use), and `--seed` is the only thing that resets it. Each generator invocation from the CLI runs in its own subshell, so state never leaks between separate `bash seed.sh ...` invocations. For reproducibility, the caller must pass `--seed` on every invocation they want to reproduce.

- [ ] **Step 1: Write failing reproducibility test**

Add to `tests/unit/test-flags.sh` (before `ptyunit_test_summary`):

```bash
ptyunit_test_begin "--seed flag"

# --seed sets _SEED_RNG_STATE
_seed_parse_flags --seed 42
assert_exit_code "$?" "0" "--seed exits 0"
assert_eq "42" "$_SEED_RNG_STATE" "--seed sets RNG state"

# --seed without value → exit 2
_seed_parse_flags --seed 2>/dev/null
assert_exit_code "$?" "2" "--seed missing value exits 2"

# Reproducibility: same seed → same output.
# Each $(…) runs seed_user in a subshell; _SEED_RNG_STATE changes inside the
# subshell never propagate back to the parent, so no reset is needed between calls.
out1=$(seed_user --seed 99999)
out2=$(seed_user --seed 99999)
assert_eq "$out1" "$out2" "--seed produces reproducible output"

# Different seeds → different output (probabilistically certain)
out_a=$(seed_user --seed 1)
out_b=$(seed_user --seed 2)
[[ "$out_a" != "$out_b" ]]
assert_exit_code $? 0 "different seeds produce different output"
```

- [ ] **Step 2: Run to confirm failure**

```bash
bash tests/unit/test-flags.sh 2>&1 | grep -E "seed|FAIL"
```
Expected: FAIL on `--seed sets RNG state` (flag not yet recognized).

- [ ] **Step 3: Add `--seed` to `_seed_parse_flags` in `seed.sh`**

In the `while` loop of `_seed_parse_flags`, add after the `--items` block and before `--*)`:

```bash
            --seed)
                if [[ $# -lt 2 ]]; then
                    printf 'Flag --seed requires a value\n' >&2
                    return 2
                fi
                _SEED_RNG_STATE="$2"; shift 2 ;;
```

- [ ] **Step 4: Run tests**

```bash
bash tests/unit/test-flags.sh 2>&1 | tail -10
```
Expected: all tests PASS including the new `--seed` tests.

```bash
bash tests/integration/test-cli.sh 2>&1 | tail -5
```
Expected: all existing CLI tests PASS.

- [ ] **Step 5: Commit**

```bash
git add seed.sh tests/unit/test-flags.sh
git commit -m "feat: add --seed flag for reproducible output"
```

---

## Task 4: Cache data files in `_seed_random_line`

**Files:**
- Modify: `src/scalar.sh` — add `_seed_cache_data`, rewrite `_seed_random_line`

**How it works:** On first call for a given file name, `_seed_cache_data` reads the file and stores each line in a global variable `_SEED_DATA_<UPPER_NAME>_<i>` and stores the total count in `_SEED_DATA_<UPPER_NAME>_N`. Subsequent calls skip the file read entirely. Uses `printf -v` (bash 3.1+) to assign dynamic variable names, and `${!var}` indirect expansion to retrieve them.

- [ ] **Step 1: Write failing test for caching**

Add to `tests/unit/test-scalar.sh`:

```bash
ptyunit_test_begin "data file caching"

# After sourcing seed.sh, cache globals should not exist yet
[[ -z "$_SEED_DATA_FIRST_NAMES_N" ]]
assert_exit_code $? 0 "cache empty before first call"

# After _seed_random_line, cache should be populated
_seed_random_line first_names > /dev/null
[[ -n "$_SEED_DATA_FIRST_NAMES_N" ]]
assert_exit_code $? 0 "cache populated after first call"

# A second call should produce a non-empty result (uses cache, not file)
v2=$(_seed_random_line first_names)
assert_not_empty "$v2" "second call from cache returns value"

# Cache count should match actual file line count
file_count=$(wc -l < "$SEED_HOME/data/first_names.txt" | tr -d ' ')
assert_eq "$file_count" "$_SEED_DATA_FIRST_NAMES_N" "cache count matches file"
```

- [ ] **Step 2: Run to confirm failure**

```bash
bash tests/unit/test-scalar.sh 2>&1 | grep -E "caching|FAIL"
```
Expected: FAIL on `cache populated after first call` (no caching yet).

- [ ] **Step 3: Add `_seed_cache_data` and rewrite `_seed_random_line` in `src/scalar.sh`**

Replace the existing `_seed_load_data` and `_seed_random_line` blocks with:

```bash
# ---------------------------------------------------------------------------
# _seed_cache_data <name>
# Load $SEED_HOME/data/<name>.txt into globals on first call; no-op after that.
# Globals: _SEED_DATA_<UPPER_NAME>_N  (count)
#          _SEED_DATA_<UPPER_NAME>_<i> (line at index i)
# ---------------------------------------------------------------------------
_seed_cache_data() {
    local name="$1"
    local uname
    uname=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    local count_var="_SEED_DATA_${uname}_N"
    [[ -n "${!count_var}" ]] && return 0   # already cached

    local file="$SEED_HOME/data/${name}.txt"
    if [[ ! -f "$file" ]]; then
        printf 'Data file not found: %s\n' "$file" >&2
        return 1
    fi

    local count=0
    while IFS= read -r line; do
        printf -v "_SEED_DATA_${uname}_${count}" '%s' "$line"
        count=$((count + 1))
    done < "$file"
    printf -v "$count_var" '%d' "$count"
}

# ---------------------------------------------------------------------------
# _seed_random_line <name>
# Return a single random line from $SEED_HOME/data/<name>.txt.
# File is loaded into globals on first call; subsequent calls use the cache.
# ---------------------------------------------------------------------------
_seed_random_line() {
    local name="$1"
    _seed_cache_data "$name" || return 1

    local uname
    uname=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    local count_var="_SEED_DATA_${uname}_N"
    local count="${!count_var}"
    [[ $count -eq 0 ]] && return 1

    local idx
    idx=$(_seed_random_int 0 $((count - 1)))
    local line_var="_SEED_DATA_${uname}_${idx}"
    printf '%s\n' "${!line_var}"
}
```

> **Note:** `_seed_load_data` is removed. It was only used internally by the old `_seed_random_line`.  Check no other code references it before deleting.

- [ ] **Step 4: Verify no remaining references to `_seed_load_data`**

```bash
grep -r '_seed_load_data' /Users/allenmccabe/lib/fissible/seed/
```
Expected: no output (only the definition, which is being replaced).

- [ ] **Step 5: Run full test suite**

```bash
bash tests/unit/test-scalar.sh 2>&1 | tail -10
bash tests/unit/test-record.sh 2>&1 | tail -5
bash tests/unit/test-crm.sh 2>&1 | tail -5
bash tests/unit/test-ecommerce.sh 2>&1 | tail -5
bash tests/integration/test-cli.sh 2>&1 | tail -5
```
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add src/scalar.sh tests/unit/test-scalar.sh
git commit -m "perf: cache data files in _seed_random_line to avoid repeated file reads"
```

---

## Task 5: Fix `seed_date` day range (29–31)

**Files:**
- Modify: `src/scalar.sh` — `seed_date`
- Modify: `tests/unit/test-scalar.sh`

**Current bug:** Day is always `_seed_random_int 1 28`, so the 29th–31st can never appear (~10% of dates are impossible). Fix: derive `max_day` per month, with correct leap-year logic for February.

- [ ] **Step 1: Write failing test**

Add to `tests/unit/test-scalar.sh`:

```bash
ptyunit_test_begin "seed_date day range"

# Generate 500 dates — statistically certain to include days 29-31
high_days=$(seed_date --count 500 | awk -F'-' '$3+0 > 28' | wc -l | tr -d ' ')
[[ "$high_days" -gt 0 ]]
assert_exit_code $? 0 "seed_date generates days 29-31"

# Leap year: 2000 was a leap year; Feb should allow day 29.
# --from/--to only constrain the year, so 200 dates across all of 2000
# are generated. Among them, some February dates should reach day 29.
feb29=$(seed_date --count 200 --from 2000-01-01 --to 2000-12-31 \
    | awk -F'-' '$2=="02" && $3=="29"' | wc -l | tr -d ' ')
[[ "$feb29" -gt 0 ]]
assert_exit_code $? 0 "seed_date generates Feb 29 in leap year (2000)"

# Non-leap year: 1900 was NOT a leap year (divisible by 100 but not 400).
# --from/--to only constrain the year range, not the month or day.
# With --from 1900-... --to 1900-..., year is fixed to 1900 and month/day
# are picked randomly across all of 1900. The leap-year check for year=1900
# should set max_day=28 for February, so no Feb 29 should ever appear.
bad=$(seed_date --count 200 --from 1900-01-01 --to 1900-12-31 \
    | awk -F'-' '$2=="02" && $3=="29"')
assert_eq "" "$bad" "no Feb 29 in non-leap year (1900)"
```

- [ ] **Step 2: Run to confirm failure**

```bash
bash tests/unit/test-scalar.sh 2>&1 | grep -E "day range|FAIL"
```
Expected: FAIL on `seed_date generates days 29-31`.

- [ ] **Step 3: Rewrite the inner loop of `seed_date` in `src/scalar.sh`**

Replace the existing loop body inside `seed_date`:

```bash
seed_date() {
    _seed_has_format_flag "$@" && { printf 'seed_date: --format not valid for scalar generators\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local from="${_SEED_FLAG_FROM:-2000-01-01}"
    local to="${_SEED_FLAG_TO:-$(_seed_today)}"
    local from_year="${from:0:4}" to_year="${to:0:4}"
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local year month day max_day
        year=$(_seed_random_int "$from_year" "$to_year")
        month=$(_seed_random_int 1 12)
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
        day=$(_seed_random_int 1 "$max_day")
        printf '%04d-%02d-%02d\n' "$year" "$month" "$day"
        i=$((i+1))
    done
}
```

- [ ] **Step 4: Run tests**

```bash
bash tests/unit/test-scalar.sh 2>&1 | tail -10
```
Expected: all tests PASS including new day-range tests.

- [ ] **Step 5: Commit**

```bash
git add src/scalar.sh tests/unit/test-scalar.sh
git commit -m "fix: seed_date now generates days 29-31 with correct leap-year logic"
```

---

## Final verification

After all tasks, run the complete test suite:

```bash
bash tests/unit/test-flags.sh
bash tests/unit/test-scalar.sh
bash tests/unit/test-record.sh
bash tests/unit/test-crm.sh
bash tests/unit/test-ecommerce.sh
bash tests/unit/test-tui.sh
bash tests/integration/test-cli.sh
```

All should pass. Then do a sanity check on the original command:

```bash
bash seed.sh user --count 3 --format json
bash seed.sh user --seed 42 --count 3 --format json   # run twice — output must match
```
