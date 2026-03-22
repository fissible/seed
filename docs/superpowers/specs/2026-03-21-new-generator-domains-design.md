# New Generator Domains — Design Spec

**Date:** 2026-03-21
**Scope:** geo, finance, devops domain generators

---

## Goal

Add 6 new generators across 3 new domain files, filling the most practically useful gaps in fissible/seed's coverage: geographic coordinates, country records, payment cards, structured log entries, error logs with stack traces, and API keys.

## Architecture

Three new source files follow the existing domain-grouping pattern (`ecommerce.sh`, `crm.sh`):

```
src/
├── geo.sh        ← seed_coordinates, seed_country
├── finance.sh    ← seed_credit_card
└── devops.sh     ← seed_log_entry, seed_error_log, seed_api_key
```

Two new data files:

```
data/
├── countries.txt       ← pipe-delimited: "DE|Germany|Europe"
└── error_messages.txt  ← one realistic error string per line
```

All three new source files sourced in `seed.sh` after `tui.sh`. `--prefix` flag added to `_seed_parse_flags` in `seed.sh`. `_seed_random_datetime_v` helper added to `src/scalar.sh`.

---

## Generators

### `seed_coordinates` — `src/geo.sh`

Record generator. No flags beyond `--count`/`--format`.

**Output (JSON default):**
```json
{"lat": 37.7749, "lng": -122.4194}
```

- `lat`: float in [-90, 90], 4 decimal places.
- `lng`: float in [-180, 180], 4 decimal places.
- Worldwide range.
- **Important:** `_seed_random_float_v` is hardcoded to 2 decimal places. `seed_coordinates` must use inline `awk` with `"%.4f"` directly, advancing `_SEED_RNG_STATE` first then invoking awk in a subshell (same pattern as `_seed_random_float_v` itself):

```bash
_seed_random_int_v "$((from * 10000))" "$((to * 10000))"
# or: advance state, then awk with %.4f
_seed_rng_init
_SEED_RNG_STATE=$(( (1664525 * _SEED_RNG_STATE + 1013904223) % 4294967296 ))
lat=$(awk -v s="$_SEED_RNG_STATE" 'BEGIN { printf "%.4f", (s / 4294967296.0) * 180.0 - 90.0 }')
_SEED_RNG_STATE=$(( (1664525 * _SEED_RNG_STATE + 1013904223) % 4294967296 ))
lng=$(awk -v s="$_SEED_RNG_STATE" 'BEGIN { printf "%.4f", (s / 4294967296.0) * 360.0 - 180.0 }')
```

The `_SEED_RNG_STATE` advance happens in the parent process; only the `printf` runs in awk. `--seed` reproducibility is preserved.

---

### `seed_country` — `src/geo.sh`

Record generator. Backed by `data/countries.txt` (pipe-delimited: `code|name|region`).

**Output (JSON default):**
```json
{"code": "DE", "name": "Germany", "region": "Europe"}
```

- ~60 well-known countries. Regions: Europe, Asia, Americas, Africa, Oceania, Middle East.
- `_seed_random_line_v countries` returns the full line. Three-field extraction via bash parameter expansion only (bash 3.2 compatible, no external tools):

```bash
_seed_random_line_v countries; local line="$_SEED_RESULT"
local code="${line%%|*}"            # everything before first |
local rest="${line#*|}"             # everything after first |
local name="${rest%%|*}"            # everything before second | (in rest)
local region="${rest#*|}"           # everything after second | (in rest) = region
```

---

### `seed_credit_card` — `src/finance.sh`

Record generator. Card number is Luhn-valid, generated algorithmically — no data file.

**Output (JSON default):**
```json
{"type": "Visa", "number": "4532015112830366", "expiry": "09/28", "cvv": "472"}
```

**Types, prefixes, and lengths:**
| Type | Prefix | Total digits | CVV digits |
|---|---|---|---|
| Visa | `4` | 16 | 3 |
| Mastercard | `51`–`55` (random via `_seed_random_int_v 51 55`) | 16 | 3 |
| Amex | `34` or `37` | 15 | 4 |
| Discover | `6011` | 16 | 3 |

**Luhn check digit algorithm (awk):**
Given `N-1` partial digits as a string, compute the final check digit:
1. From rightmost digit of partial, double every second position (1st, 3rd, … from right)
2. If doubled value > 9, subtract 9
3. Sum all digits (original + doubled)
4. Check digit = `(10 - (sum % 10)) % 10`

Implemented as a single `awk` invocation passed the partial number string. The awk subshell does not touch `_SEED_RNG_STATE` — reproducibility is preserved.

- `expiry`: `MM/YY` format — random month (`_seed_random_int_v 1 12`), random year in [`current_year + 1`, `current_year + 5`]. Current year extracted from `$(_seed_today)` before the loop.
- All `_v` primitives for digit generation — `--seed` reproducible.

---

### `seed_log_entry` — `src/devops.sh`

Record generator. No domain-specific flags beyond `--count`/`--format`.

**Output (JSON default):**
```json
{"timestamp": "2024-03-15T14:23:45Z", "level": "INFO", "service": "dynamic-widget-api", "message": "Lorem ipsum dolor sit amet.", "request_id": "4f9a1c2e-8b3d-47f0-a561-dc9e2b8f1034"}
```

- `timestamp`: `YYYY-MM-DDThh:mm:ssZ` via `_seed_random_datetime_v` helper (see below).
- `level`: DEBUG | INFO | WARN | ERROR — uniform random via `_seed_random_int_v 0 3` + inline array.
- `service`: `{adjective}-{noun}-{suffix}` where suffix ∈ inline array `(api service worker)`.
- `message`: random line from `data/lorem.txt` via `_seed_random_line_v lorem`.
- `request_id`: `_seed_uuid_gen` (safe subshell — uses `/dev/urandom`, does not advance LCG).
- All field randomness via `_v` primitives.

---

### `seed_error_log` — `src/devops.sh`

Record generator. Separate schema from `seed_log_entry`.

**Output (JSON default):**
```json
{"timestamp": "2024-03-15T14:23:45Z", "level": "ERROR", "service": "quick-block-api", "error_code": "E4029", "message": "connection timeout after 30000ms", "stack_trace": "Traceback (most recent call last):\n  File \"handler.py\", line 42, in handle\n  File \"router.py\", line 18, in process", "request_id": "uuid"}
```

- `level`: ERROR or FATAL — `_seed_random_int_v 0 1` + inline array.
- `error_code`: `E{4 random digits}` via `_seed_random_int_v 1000 9999`.
- `message`: random line from `data/error_messages.txt`.
- `request_id`: `_seed_uuid_gen`.

**Stack trace construction:**
- 2–4 frames (`_seed_random_int_v 2 4`), Python-style.
- Each frame: `File "{noun}.py", line {N}, in {method}` where noun from `data/nouns.txt`, line number from `_seed_random_int_v 1 200`, method from inline array `(handle process execute validate parse dispatch run fetch connect)`.
- Frames are joined with **literal two-character `\n` escape sequences** (not real newlines), so the full stack trace string never contains a real newline. The trace is already valid JSON-escaped: backslash-n is the correct JSON encoding of a newline character, and no `"` characters appear in frame strings. **Do NOT pass the trace through `_seed_json_escape`** — that would double-escape the backslashes to `\\n`, producing invalid JSON.
- Assembly: build trace by concatenating `frame1\\nframe2\\n...` using bash string concatenation. Never embed real newlines.

**Format-conditional `stack_trace` field:**
`stack_trace` is **omitted in CSV and SQL formats** (too unwieldy for tabular output). Included in JSON and KV. Since `_seed_emit_record` takes a flat argument list with no per-format field filtering, the implementation must conditionally build the argument list:

```bash
local st_args
if [[ "$_SEED_FLAG_FORMAT" != "csv" && "$_SEED_FLAG_FORMAT" != "sql" ]]; then
    # stack_trace is pre-built with literal \n sequences — already JSON-safe, do NOT call _seed_json_escape
    st_args="stack_trace $stack_trace"
fi
# $st_args deliberately unquoted for word-splitting into positional args:
# shellcheck disable=SC2086
rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" error_logs \
    timestamp "$ts" level "$level" ... $st_args)
```

The unquoted `$st_args` expansion is intentional word-splitting — same pattern used in `seed_cart`. Document with a comment.

---

### `seed_api_key` — `src/devops.sh`

Scalar generator. Supports `--prefix` flag.

**Output:**
```
sk_a3f8c2d1e4b9c2d1e4b9c2d1e4b9c2d1
```

- Default prefix: `sk_`. Override: `--prefix pk_live_`.
- Body: 32 lowercase hex chars — 16 × `_seed_random_int_v 0 255` → `printf '%02x'`.
- LCG-based — fully reproducible with `--seed`.
- Rejects `--format` (scalar generator).

---

## Shared primitive: `_seed_random_datetime_v`

Added to `src/scalar.sh`. Writes an ISO 8601 datetime string to `_SEED_RESULT`. No LCG subshells — all `_SEED_RNG_STATE` advances happen in the parent process.

Note: one non-LCG subshell is required (`$(_seed_today)`) to get the current year as upper bound, called once before the loop. This is safe — `_seed_today` runs `date +%Y-%m-%d` and does not touch `_SEED_RNG_STATE`. `--seed` reproducibility is fully preserved.

```bash
_seed_random_datetime_v() {
    # Takes to_year as $1. Caller must compute to_year=$(_seed_today | cut -c1-4) once before the loop.
    # Uses _seed_random_int_v for: year(2000–today), month, day (with leap logic), HH, MM, SS
    # Writes "YYYY-MM-DDThh:mm:ssZ" to _SEED_RESULT
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

Callers compute `to_year` once before the loop via `_seed_today`.

---

## New flags in `seed.sh`

### `--prefix` (for `seed_api_key`)

In `_seed_parse_flags`, add `_SEED_FLAG_PREFIX=""` to the **initialization/reset block** (alongside all other `_SEED_FLAG_*=""` resets) so stale values never bleed across calls. Then add the parsing branch:

```bash
--prefix)
    if [[ $# -lt 2 ]]; then
        printf 'Flag --prefix requires a value\n' >&2
        return 2
    fi
    _SEED_FLAG_PREFIX="$2"; shift 2 ;;
```

Update the comment block above `_seed_parse_flags` to list `_SEED_FLAG_PREFIX`.

---

## Data files

### `data/countries.txt`

Pipe-delimited, ~60 entries, no leading/trailing whitespace:

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
...
```

### `data/error_messages.txt`

One realistic error string per line, ~25 entries:

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
```

---

## Testing

Three new test files:

### `tests/unit/test-geo.sh`

- `seed_coordinates`: lat and lng are numeric, full record output contains `"lat"` and `"lng"` keys
- Lat range: run 50 samples, verify at least one is negative (confirms worldwide range, not just positive)
- `seed_country`: record contains `"code"`, `"name"`, `"region"` fields; code matches `^[A-Z]{2}$`
- `seed_country --seed 42 --count 3`: 3 distinct records
- `seed_coordinates --seed 42 --count 3`: 3 distinct records
- `countries.txt >= 60 entries`

### `tests/unit/test-finance.sh`

- `seed_credit_card`: record contains `"type"`, `"number"`, `"expiry"`, `"cvv"` fields
- Number passes Luhn check (awk one-liner verifying `sum % 10 == 0`)
- Type-specific prefix: Visa starts with `4`, Mastercard with `5`, Amex with `3`, Discover with `6`
- Expiry matches `^[0-9]{2}/[0-9]{2}$`
- CVV: 3 digits for Visa/MC/Discover; Amex CVV is 4 digits (generate Amex-only records with `--seed` values known to produce Amex, or generate 20 cards and find an Amex)
- `seed_credit_card --seed 42 --count 3`: 3 distinct records
- `seed_credit_card --format csv` and `--format sql`: verify number field is unquoted (numeric)

### `tests/unit/test-devops.sh`

- `seed_log_entry`: timestamp matches `^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$`
- Level in {DEBUG, INFO, WARN, ERROR}
- `seed_error_log`: level in {ERROR, FATAL}, error_code matches `^E[0-9]{4}$`
- `seed_error_log` JSON output contains `"stack_trace"` key
- `seed_error_log --format csv` output does **not** contain `stack_trace` (negative test)
- `seed_error_log --format sql` output does **not** contain `stack_trace` (negative test)
- `seed_error_log --format kv` output contains `STACK_TRACE=` line (positive test)
- `seed_api_key`: output matches `^sk_[0-9a-f]{32}$` (default prefix, 32 hex chars)
- `seed_api_key --prefix pk_`: output starts with `pk_`
- Call `seed_api_key --prefix custom_` then `seed_api_key` (no flag): second call must start with `sk_` (flag reset test)
- `--seed 42 --count 3` distinctness for all 5 generators
- `error_messages.txt >= 20 entries`

---

## Compatibility

- Bash 3.2+ throughout: no `declare -A`, no `+=`, no `${var,,}` — all array ops use `arr[${#arr[@]}]=val`
- Country line parsing uses only bash parameter expansion (`${line%%|*}`, `${line#*|}`, `${rest%%|*}`, `${rest#*|}`)
- `_seed_random_datetime_v` uses only `_seed_random_int_v` and `printf` for all LCG-driven fields; one non-LCG `$(_seed_today)` subshell called before the generator loop
- Stack trace uses literal `\n` escape sequences (not real newlines) — compatible with `_seed_json_escape` as-is
- `$st_args` word-splitting in `seed_error_log` is intentional (documented with comment)
