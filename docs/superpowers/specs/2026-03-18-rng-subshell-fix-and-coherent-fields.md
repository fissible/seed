# RNG Subshell Fix and Coherent Fields — Design Spec

## Problem Statement

Two related bugs in the current implementation:

1. **`--seed --count N` produces identical records.** The global LCG RNG state (`_SEED_RNG_STATE`) is advanced by calling `_seed_random_int`, `_seed_random_float`, or `_seed_random_line`. These functions are currently called inside `$(...)` subshells. A subshell inherits `_SEED_RNG_STATE` from the parent but cannot write back to it — mutations in the subshell are discarded when the subshell exits. Every iteration of a `--count N` loop therefore starts from the same `_SEED_RNG_STATE` value → identical output.

2. **Incoherent multi-field records.** `seed_user`, `seed_contact`, and `seed_lead` call `seed_name` and `seed_email` as independent black boxes. Each draws its own random first and last name, so `{"name":"Mason Lambert","email":"ryder.henderson@domain"}` is possible — the email prefix belongs to a different person than the name field.

### RNG State Background

`_SEED_RNG_STATE` is a single integer holding the LCG state. It is initialized lazily on first use (from `/dev/urandom` or a PID+`$RANDOM` fallback), or explicitly via `--seed N`. Each call to a random primitive computes:

```
state = (1664525 × state + 1013904223) mod 2^32
```

then maps `state` to the requested range. Because the state is a plain bash variable in the parent process's environment, any `$(...)` subshell that calls a random primitive gets its own copy of the state at fork time — the parent's copy never changes. This is the root cause of both bugs.

## Goals

- Fix `--seed --count N` for ALL generators (scalar and record).
- Make `email` and `username` fields in `seed_user`, `seed_contact`, `seed_lead` derive from the same first/last name chosen for the `name` field.
- Add a small `src/str.sh` string helper library (bash 3.2 compatible).
- Preserve full CLI compatibility and all 163 existing tests.

## Architecture

Three interlocking pieces:

### 1. `_v` RNG primitives (src/scalar.sh)

Add three variants that write to `_SEED_RESULT` and run in the caller's process — no `$()` wrapping, so `_SEED_RNG_STATE` advances in the parent between calls:

```bash
_seed_random_int_v   [min] [max]   # integer in [min, max]
_seed_random_float_v [min] [max]   # float with 2 decimal places
_seed_random_line_v  <name>        # random line from data/<name>.txt
```

**Contract:**
- On success: `_SEED_RESULT` is set to the generated value; function returns 0.
- On failure (e.g., missing data file): `_SEED_RESULT` is set to the empty string; function returns non-zero. Note: the return code is visible on the `_v` call line itself. Generators do not use `set -e`; callers check return codes explicitly if needed. This spec does not add new error handling — empty-field behavior on missing data files is unchanged from today.
- `_SEED_RESULT` is an ordinary untyped bash global — it is not declared or initialized anywhere; it simply holds whatever the last `_v` call wrote.
- **Critical:** callers must never declare a `local` variable named `_SEED_RESULT` — doing so would shadow the global and break the pattern for any nested `_v` call.
- Callers must assign `_SEED_RESULT` to a named local immediately after each `_v` call. Never read `_SEED_RESULT` after an intervening `_v` call:

```bash
# correct
_seed_random_int_v 1 100; local score="$_SEED_RESULT"
_seed_random_line_v domains; local domain="$_SEED_RESULT"

# wrong — second call overwrites _SEED_RESULT before first is saved
_seed_random_int_v 1 100
_seed_random_line_v domains
local score="$_SEED_RESULT"   # this is the domain, not the score
```

### 2. Generator refactor (all src/*.sh except str.sh)

Every generator loop body is rewritten to use `_v` calls. Before:

```bash
local val
val=$(_seed_random_int 1 100)
```

After:

```bash
_seed_random_int_v 1 100; local val="$_SEED_RESULT"
```

Same pattern for `_seed_random_float_v` and `_seed_random_line_v`. Array-indexed picks become:

```bash
_seed_random_int_v 0 $((${#arr[@]} - 1)); local item="${arr[$_SEED_RESULT]}"
```

Note: arrays are always initialized with positional assignment (`arr=("a" "b" "c")` or `arr[N]=value`) — never `+=`, which is not bash 3.2 compatible. This is already the pattern in the codebase; the refactor does not introduce it.

**Scalar generator `_SEED_RESULT` side effect:** after refactoring, scalar generators call `_v` primitives internally. The last `_v` call in the loop body will have left `_SEED_RESULT` set to the last generated value when `--count 1` is used. Callers in library mode may optionally read `_SEED_RESULT` instead of using `$()`. The CLI output path (via `printf`) is unchanged.

### 3. `src/str.sh` — string helper module

A small, standalone string library. Bash 3.2 compatible (no `${var,,}` or `${var^^}`). All helpers use the `_v` convention: write to `_SEED_RESULT`, no stdout.

**`src/str.sh` has no dependencies** — it can be sourced alone without `scalar.sh`. `_SEED_RESULT` is just a global variable the helpers write to; no prior declaration is needed.

```bash
_seed_str_lower_v <str>   # lowercase only — "Mason Lambert" → "mason lambert"
_seed_str_slug_v  <str>   # lowercase + sanitize → "Mason Lambert" → "mason.lambert"
```

**`_seed_str_lower_v` rules:** convert all ASCII uppercase to lowercase via `tr '[:upper:]' '[:lower:]'`. All other characters pass through unchanged.

**`_seed_str_slug_v` rules:** three steps applied in order:
1. Lowercase via `tr '[:upper:]' '[:lower:]'`
2. Replace spaces with `.` via `tr ' ' '.'`
3. Strip any character not in `[a-z0-9.-]` via `tr -dc 'a-z0-9.-'`

The `-` at the end of the `tr -dc` set is a literal hyphen (not a range). `tr -dc` is POSIX-compliant and works on both macOS `tr` and GNU `tr`. Output character set is strictly `[a-z0-9.-]`. Examples:
- `"Mason Lambert"` → `"mason.lambert"`
- `"Anne-Marie"` → `"anne-marie"` (hyphen preserved)
- `"O'Brien"` → `"obrien"` (apostrophe stripped)

`_seed_str_slug_v` is used in the coherent field derivation pattern. `_seed_str_lower_v` is available for cases where full slug sanitization isn't needed.

Internally both use `printf '%s' "$1" | tr` subshells — fine since string transforms don't advance `_SEED_RNG_STATE`.

### Source order in `seed.sh`

The current `seed.sh` source block looks like:

```bash
source "$SEED_HOME/src/scalar.sh"
source "$SEED_HOME/src/record.sh"
source "$SEED_HOME/src/ecommerce.sh"
source "$SEED_HOME/src/crm.sh"
source "$SEED_HOME/src/tui.sh"
```

Add `str.sh` as the first source line, before all others:

```bash
source "$SEED_HOME/src/str.sh"       # ← add this first
source "$SEED_HOME/src/scalar.sh"
source "$SEED_HOME/src/record.sh"
source "$SEED_HOME/src/ecommerce.sh"
source "$SEED_HOME/src/crm.sh"
source "$SEED_HOME/src/tui.sh"
```

Although bash resolves function definitions at call time (not source time), sourcing `str.sh` first makes the dependency order explicit.

## Coherent Field Derivation

### Which generators receive coherence treatment

| Generator | Has name+email? | Action |
|---|---|---|
| `seed_user` | yes — `name`, `email`, `username` | coherence + `_v` refactor |
| `seed_contact` | yes — `name`, `email` | coherence + `_v` refactor |
| `seed_lead` | yes — `name`, `email` | coherence + `_v` refactor |
| `seed_address` | no | `_v` refactor only |
| `seed_company` | no | `_v` refactor only |
| `seed_product` | no | `_v` refactor only |
| `seed_category` | no | `_v` refactor only |
| `seed_order` | `customer_email` only — no customer name field | `_v` refactor only |
| `seed_order_item` | no | `_v` refactor only |
| `seed_coupon` | no | `_v` refactor only |
| `seed_cart` | `customer_email` only — no customer name field | `_v` refactor only |
| `seed_deal` | `owner` (a person name) but no email | `_v` refactor only |
| `seed_activity` | no | `_v` refactor only |
| `seed_note` | no | `_v` refactor only |
| `seed_tag` | no | `_v` refactor only |
| `seed_filenames` | no — generates filename strings from adjective/noun data | `_v` refactor only |
| `seed_dirtree` | no — generates directory path strings | `_v` refactor only |
| `seed_menu_items` | no — generates menu label strings | `_v` refactor only |

### Derivation pattern for coherent generators

Replace independent `seed_name` / `seed_email` calls with direct `_v` primitive calls at record scope. Use `_seed_str_slug_v` for the email/username parts to ensure sanitized identifier output:

```bash
_seed_random_line_v first_names; local first_n="$_SEED_RESULT"
_seed_random_line_v last_names;  local last_n="$_SEED_RESULT"
local name="$first_n $last_n"

_seed_str_slug_v "$first_n"; local fl="$_SEED_RESULT"
_seed_str_slug_v "$last_n";  local ll="$_SEED_RESULT"
_seed_random_line_v domains;  local domain="$_SEED_RESULT"

local email="${fl}.${ll}@${domain}"
local username="${fl}.${ll}"   # seed_user only; seed_contact and seed_lead have no username field
```

`seed_name` and `seed_email` remain valid standalone CLI generators — they are not removed and their CLI output format is unchanged.

## Files Touched

| File | Change |
|---|---|
| `src/str.sh` | **Create** — `_seed_str_lower_v`, `_seed_str_slug_v` |
| `seed.sh` | Add `source "$SEED_HOME/src/str.sh"` as first source line |
| `src/scalar.sh` | Add `_v` primitives; refactor all scalar generator loop bodies |
| `src/record.sh` | Coherence refactor for `seed_user`; `_v` loop refactor for `seed_address`, `seed_company` |
| `src/crm.sh` | Coherence refactor for `seed_contact`, `seed_lead`; `_v` loop refactor for `seed_deal`, `seed_activity`, `seed_note`, `seed_tag` |
| `src/ecommerce.sh` | `_v` loop refactor for `seed_product`, `seed_category`, `seed_order`, `seed_order_item`, `seed_coupon`, `seed_cart` |
| `src/tui.sh` | `_v` loop refactor for `seed_filenames`, `seed_dirtree`, `seed_menu_items` |
| `tests/unit/test-str.sh` | **Create** — unit tests for `_seed_str_lower_v`, `_seed_str_slug_v` |
| `tests/unit/test-scalar.sh` | Add `--seed --count N` distinctness tests; `seed_name`/`seed_email` standalone regression |
| `tests/unit/test-record.sh` | Add coherence + distinctness tests for `seed_user` |
| `tests/unit/test-crm.sh` | Add coherence + distinctness tests for `seed_contact`, `seed_lead` |
| `tests/unit/test-ecommerce.sh` | Add distinctness tests for `seed_order`, `seed_product` |
| `tests/unit/test-tui.sh` | Add distinctness tests for tui generators (create file if not exists) |
| `tests/unit/test-flags.sh` | Verify existing `--seed` tests still pass (no new tests needed) |

## Testing

All record generators output one compact JSON object per line (no pretty-printing). Distinctness tests use `sort -u | wc -l` on the line-per-record output — this is valid because each record is a single line.

The test fixture seed value `42` is used as a fixed reference. Before finalizing tests, verify empirically that `--seed 42 --count 3` produces 3 distinct values for each generator. If seed 42 happens to collide for any generator (e.g., a generator with few possible values), use a higher `--count` or a different seed. Record generators produce many-field JSON objects where seed-42 collisions are practically impossible.

### New: `tests/unit/test-str.sh`

`str.sh` has no dependencies — source only `str.sh`:

```bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/src/str.sh"

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

### `tests/unit/test-scalar.sh` additions

**`--seed --count 3` distinctness** for generators with large output spaces — `name`, `email`, `phone`, `date`, `number`, `lorem`, `ip`, `url`, `uuid`:

```bash
out=$(bash seed.sh name --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "name --seed 42 --count 3 produces 3 distinct values"
# repeat for email, phone, date, number, lorem, ip, url, uuid
```

**`bool` uses a 2-value check** (only 2 possible outputs):

```bash
out=$(bash seed.sh bool --seed 42 --count 10)
assert_eq "2" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "bool --seed 42 --count 10 produces both true and false"
```

**`seed_name` / `seed_email` standalone regression:**

```bash
assert_not_empty "$(bash seed.sh name)" "seed_name still works post-refactor"
assert_not_empty "$(bash seed.sh email)" "seed_email still works post-refactor"
out=$(bash seed.sh name --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_name --seed 42 --count 3 distinct post-refactor"
```

### `tests/unit/test-record.sh` additions

All names in `first_names.txt` and `last_names.txt` are plain ASCII with no apostrophes or hyphens, so `_seed_str_slug_v` and plain lowercase produce identical output for any name drawn from the data files. The test reconstructs the expected email prefix using lowercase-only transform:

```bash
out=$(bash seed.sh user --seed 42)
name_val=$(printf '%s' "$out" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
email_val=$(printf '%s' "$out" | grep -o '"email":"[^"]*"' | cut -d'"' -f4)
email_prefix="${email_val%@*}"
first=$(printf '%s' "$name_val" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
last=$(printf '%s' "$name_val" | cut -d' ' -f2 | tr '[:upper:]' '[:lower:]')
assert_eq "${first}.${last}" "$email_prefix" "seed_user email coherent with name"

out=$(bash seed.sh user --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_user --seed 42 --count 3 produces 3 distinct records"
```

### `tests/unit/test-crm.sh` additions

`seed_contact` JSON fields: `name`, `email`, `phone`, `company`, `title`.
`seed_lead` JSON fields: `name`, `email`, `phone`, `company`, `title`, `source`, `status`, `score`.

**`seed_contact` coherence and distinctness:**

```bash
out=$(bash seed.sh contact --seed 42)
name_val=$(printf '%s' "$out" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
email_val=$(printf '%s' "$out" | grep -o '"email":"[^"]*"' | cut -d'"' -f4)
email_prefix="${email_val%@*}"
first=$(printf '%s' "$name_val" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
last=$(printf '%s' "$name_val" | cut -d' ' -f2 | tr '[:upper:]' '[:lower:]')
assert_eq "${first}.${last}" "$email_prefix" "seed_contact email coherent with name"

out=$(bash seed.sh contact --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_contact --seed 42 --count 3 produces 3 distinct records"
```

**`seed_lead` coherence and distinctness (same pattern):**

```bash
out=$(bash seed.sh lead --seed 42)
name_val=$(printf '%s' "$out" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
email_val=$(printf '%s' "$out" | grep -o '"email":"[^"]*"' | cut -d'"' -f4)
email_prefix="${email_val%@*}"
first=$(printf '%s' "$name_val" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
last=$(printf '%s' "$name_val" | cut -d' ' -f2 | tr '[:upper:]' '[:lower:]')
assert_eq "${first}.${last}" "$email_prefix" "seed_lead email coherent with name"

out=$(bash seed.sh lead --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_lead --seed 42 --count 3 produces 3 distinct records"
```

### `tests/unit/test-ecommerce.sh` additions

```bash
out=$(bash seed.sh order --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_order --seed 42 --count 3 produces 3 distinct records"

out=$(bash seed.sh product --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_product --seed 42 --count 3 produces 3 distinct records"
```

### `tests/unit/test-tui.sh` (create if not exists)

```bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
SH="bash $SEED_HOME/seed.sh"

out=$($SH filenames --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_filenames --seed 42 --count 3 produces 3 distinct values"

out=$($SH dirtree --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_dirtree --seed 42 --count 3 produces 3 distinct values"

out=$($SH menu_items --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_menu_items --seed 42 --count 3 produces 3 distinct values"

ptyunit_test_summary
```

### Regression

- All 163 existing tests must continue to pass.
- CLI output format unchanged for all generators.

## Constraints

- Bash 3.2+ compatible throughout: no `mapfile`, no `declare -A`, no `${var,,}`, no `${var^^}`, no `+=` on arrays.
- No new external dependencies. `tr -dc` is POSIX and works on both macOS and GNU `tr`.
- `_SEED_RESULT` is a single shared global. Callers must assign it to a named local immediately after each `_v` call. Never read `_SEED_RESULT` after any intervening `_v` call. Never declare a `local` variable named `_SEED_RESULT`.
- `_seed_str_slug_v` output character set: `[a-z0-9.-]` only. All other characters are stripped.
- `str.sh` has no dependencies on other seed modules and can be sourced in isolation.
- Generators do not use `set -e`. Return code checking is explicit where needed.
