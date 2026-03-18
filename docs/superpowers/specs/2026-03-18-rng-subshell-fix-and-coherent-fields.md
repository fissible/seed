# RNG Subshell Fix and Coherent Fields — Design Spec

## Problem Statement

Two related bugs in the current implementation:

1. **`--seed --count N` produces identical records.** All generators use `$(...)` subshells to capture sub-generator output. Subshells inherit `_SEED_RNG_STATE` but mutations don't propagate back to the parent. Every loop iteration starts from the same RNG state → identical output.

2. **Incoherent multi-field records.** `seed_user`, `seed_contact`, and `seed_lead` call `seed_name` and `seed_email` as independent black boxes. The email's name prefix is drawn from a separate random name pick, so `{"name":"Mason Lambert","email":"ryder.henderson@domain"}` is possible.

## Goals

- Fix `--seed --count N` for ALL generators (scalar and record).
- Make `email` and `username` fields in `seed_user`, `seed_contact`, `seed_lead` derive from the same first/last name already chosen for the `name` field.
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

All three follow the same convention: set `_SEED_RESULT`, return 0 on success.

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

Array-indexed picks become:

```bash
_seed_random_int_v 0 $((${#arr[@]} - 1)); local item="${arr[$_SEED_RESULT]}"
```

Generators that currently call other generators via `$()` (e.g., `seed_contact` calling `seed_name`) are refactored to bypass those calls entirely and use `_v` primitives directly at record scope (see Coherent Fields below).

Scalar generators continue to `printf` to stdout for CLI compatibility. They also set `_SEED_RESULT` as a side effect so they remain callable without `$()` where convenient.

### 3. `src/str.sh` — string helper module

A small, standalone string library. Bash 3.2 compatible (no `${var,,}` or `${var^^}`). All helpers use the `_v` convention: write to `_SEED_RESULT`, no stdout.

```bash
_seed_str_lower_v <str>   # "Mason Lambert" → _SEED_RESULT="mason lambert"
_seed_str_slug_v  <str>   # "Mason Lambert" → _SEED_RESULT="mason.lambert"
```

Internally both use `printf '%s' "$1" | tr` subshells. This is fine — string transforms don't advance `_SEED_RNG_STATE`.

Sourced from `seed.sh` alongside the other modules.

## Coherent Field Derivation

In `seed_user`, `seed_contact`, `seed_lead`, replace independent `seed_name` / `seed_email` calls with direct `_v` primitive calls at record scope:

```bash
_seed_random_line_v first_names; local first_n="$_SEED_RESULT"
_seed_random_line_v last_names;  local last_n="$_SEED_RESULT"
local name="$first_n $last_n"

_seed_str_lower_v "$first_n"; local fl="$_SEED_RESULT"
_seed_str_lower_v "$last_n";  local ll="$_SEED_RESULT"
_seed_random_line_v domains;  local domain="$_SEED_RESULT"

local email="${fl}.${ll}@${domain}"
local username="${fl}.${ll}"
```

`seed_name` and `seed_email` remain valid standalone CLI generators — they're just not called internally by record generators anymore.

Generators with a `name` field but no `email` field (e.g., `seed_deal` `owner`) get the `_v` refactor for loop correctness but no coherence changes.

## Files Touched

| File | Change |
|---|---|
| `src/str.sh` | **Create** — `_seed_str_lower_v`, `_seed_str_slug_v` |
| `seed.sh` | Add `source "$SEED_HOME/src/str.sh"` |
| `src/scalar.sh` | Add `_v` primitives; refactor all scalar generator loop bodies |
| `src/record.sh` | Refactor `seed_user`; other generators get `_v` loop refactor |
| `src/crm.sh` | Refactor `seed_contact`, `seed_lead` for coherence; `_v` refactor all |
| `src/ecommerce.sh` | `_v` refactor all generator loop bodies |
| `src/tui.sh` | `_v` refactor all generator loop bodies |
| `tests/unit/test-str.sh` | **Create** — unit tests for `_seed_str_lower_v`, `_seed_str_slug_v` |
| `tests/unit/test-scalar.sh` | Add `--seed --count N` distinctness tests for scalar generators |
| `tests/unit/test-record.sh` | Add coherence + distinctness tests for `seed_user` |
| `tests/unit/test-crm.sh` | Add coherence + distinctness tests for `seed_contact`, `seed_lead` |
| `tests/unit/test-flags.sh` | Verify existing `--seed` tests still pass (no new tests needed) |

## Testing

### New: `tests/unit/test-str.sh`
- `_seed_str_lower_v` with uppercase, mixed, already-lowercase, multi-word input
- `_seed_str_slug_v` with space → dot, uppercase → lowercase, multi-word input

### `tests/unit/test-scalar.sh` additions
- `--seed N --count 3` produces 3 **distinct** lines for `name`, `email`, `phone`, `date`, `number`, `lorem`, `ip`, `url`, `bool`

### `tests/unit/test-record.sh` additions
- `seed_user` email prefix matches name: extract first.last from email, compare to lowercased name fields
- `seed_user --seed N --count 3` produces 3 distinct records (different names)

### `tests/unit/test-crm.sh` additions
- Same coherence and distinctness checks for `seed_contact` and `seed_lead`

### Regression
- All 163 existing tests must continue to pass.
- CLI output format unchanged for all generators.

## Constraints

- Bash 3.2+ compatible throughout (no `mapfile`, no `declare -A`, no `${var,,}`, no `${var^^}`, no `+=` on arrays).
- No new external dependencies.
- `_SEED_RESULT` is a single shared global — callers must consume it immediately after each `_v` call (no deferred reads).
