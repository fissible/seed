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

- `lat`: float in [-90, 90], 4 decimal places, via `_seed_random_float_v`
- `lng`: float in [-180, 180], 4 decimal places, via `_seed_random_float_v`
- Worldwide range. All `_v` primitives — `--seed` reproducible.

---

### `seed_country` — `src/geo.sh`

Record generator. Backed by `data/countries.txt` (pipe-delimited: `code|name|region`).

**Output (JSON default):**
```json
{"code": "DE", "name": "Germany", "region": "Europe"}
```

- ~60 well-known countries. Regions: Europe, Asia, Americas, Africa, Oceania, Middle East.
- `_seed_random_line_v countries` returns full line; bash `${line%%|*}` / `${line#*|}` splits fields without external tools (bash 3.2 compatible).

---

### `seed_credit_card` — `src/finance.sh`

Record generator. Card number is Luhn-valid, generated algorithmically — no data file.

**Output (JSON default):**
```json
{"type": "Visa", "number": "4532015112830366", "expiry": "09/28", "cvv": "472"}
```

- **Types and prefixes:**
  - Visa: starts with `4`, 16 digits, 3-digit CVV
  - Mastercard: starts with `51`–`55`, 16 digits, 3-digit CVV
  - Amex: starts with `34` or `37`, 15 digits, 4-digit CVV
  - Discover: starts with `6011`, 16 digits, 3-digit CVV
- Type selected randomly via `_seed_random_int_v`.
- Prefix digits fixed per type; remaining digits filled with `_seed_random_int_v 0 9`; final check digit computed via Luhn algorithm in `awk`.
- `expiry`: `MM/YY` — random month (01–12), year in [current_year+1, current_year+5].
- All `_v` primitives — `--seed` reproducible.

---

### `seed_log_entry` — `src/devops.sh`

Record generator. No domain-specific flags beyond `--count`/`--format`.

**Output (JSON default):**
```json
{"timestamp": "2024-03-15T14:23:45Z", "level": "INFO", "service": "dynamic-widget-api", "message": "Lorem ipsum dolor sit amet.", "request_id": "4f9a1c2e-8b3d-47f0-a561-dc9e2b8f1034"}
```

- `timestamp`: `YYYY-MM-DDThh:mm:ssZ` via `_seed_random_datetime_v` helper (see below).
- `level`: DEBUG | INFO | WARN | ERROR — uniform random.
- `service`: `{adjective}-{noun}-{suffix}` where suffix ∈ `(api service worker)` inline array.
- `message`: random line from `data/lorem.txt`.
- `request_id`: `_seed_uuid_gen` (safe subshell — uses `/dev/urandom`).
- All field randomness via `_v` primitives.

---

### `seed_error_log` — `src/devops.sh`

Record generator. Separate schema from `seed_log_entry`.

**Output (JSON default):**
```json
{
  "timestamp": "2024-03-15T14:23:45Z",
  "level": "ERROR",
  "service": "quick-block-api",
  "error_code": "E4029",
  "message": "connection timeout after 30000ms",
  "stack_trace": "Traceback (most recent call last):\n  File \"handler.py\", line 42, in handle\n  File \"router.py\", line 18, in process",
  "request_id": "uuid"
}
```

- `level`: ERROR or FATAL — random.
- `error_code`: `E{4 random digits}` via `_seed_random_int_v 1000 9999`.
- `message`: random line from `data/error_messages.txt`.
- `stack_trace`: 2–4 frames, Python-style. Each frame: `File "{noun}.py", line {N}, in {method}` where noun from `data/nouns.txt`, line number from `_seed_random_int_v 1 200`, method from inline array `(handle process execute validate parse dispatch run fetch connect)`.
- Stack trace stored as JSON-escaped string (via `_seed_json_escape`). **Omitted in CSV and SQL formats** (too unwieldy for tabular output). Included in KV as raw multi-line value.
- `request_id`: `_seed_uuid_gen`.

---

### `seed_api_key` — `src/devops.sh`

Scalar generator. Supports `--prefix` flag (new flag added to `_seed_parse_flags`).

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

Added to `src/scalar.sh`. Writes an ISO 8601 datetime string to `_SEED_RESULT`.

```bash
_seed_random_datetime_v() {
    # date part: year 2000–today, random month, random day with leap logic
    # time part: random HH (0–23), MM (0–59), SS (0–59)
    # output: "YYYY-MM-DDThh:mm:ssZ"
}
```

Uses existing date-range logic from `seed_date` plus 3 additional `_seed_random_int_v` calls for HH/MM/SS. No subshell — advances `_SEED_RNG_STATE` in place.

---

## New flag: `--prefix`

Added to `_seed_parse_flags` in `seed.sh`, alongside other flags. Initializes `_SEED_FLAG_PREFIX=""`. Used only by `seed_api_key`.

```bash
--prefix)
    _SEED_FLAG_PREFIX="$2"; shift 2 ;;
```

---

## Data files

### `data/countries.txt`

Pipe-delimited, ~60 entries:

```
US|United States|Americas
DE|Germany|Europe
JP|Japan|Asia
BR|Brazil|Americas
NG|Nigeria|Africa
AU|Australia|Oceania
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
...
```

---

## Testing

Three new test files:

### `tests/unit/test-geo.sh`

- `seed_coordinates`: lat in [-90,90], lng in [-180,180], format check
- `seed_country`: has `code`/`name`/`region` fields, code is 2 uppercase letters
- `seed_country --seed 42 --count 3`: 3 distinct records
- `seed_coordinates --seed 42 --count 3`: 3 distinct records
- `countries.txt >= 60 entries`

### `tests/unit/test-finance.sh`

- `seed_credit_card`: number passes Luhn check (awk one-liner)
- Type-specific prefix check (Visa starts with 4, Mastercard 51–55, etc.)
- Expiry matches `^[0-9]{2}/[0-9]{2}$`
- CVV: 3 digits for Visa/MC/Discover, 4 for Amex
- `seed_credit_card --seed 42 --count 3`: 3 distinct records

### `tests/unit/test-devops.sh`

- `seed_log_entry`: timestamp matches ISO 8601, level in {DEBUG,INFO,WARN,ERROR}
- `seed_error_log`: level in {ERROR,FATAL}, error_code matches `^E[0-9]{4}$`, has `stack_trace`
- `seed_api_key`: starts with `sk_`, length correct, hex body
- `seed_api_key --prefix pk_`: starts with `pk_`
- `--seed 42 --count 3` distinctness for all 5 generators
- `error_messages.txt >= 20 entries`

---

## Compatibility

- Bash 3.2+ throughout: no `declare -A`, no `+=`, no `${var,,}` — all array ops use `arr[${#arr[@]}]=val`
- `_seed_random_datetime_v` uses only `_seed_random_int_v` and `printf` — no external date command
- Country line parsing uses bash parameter expansion only (`${line%%|*}`, `${line#*|}`, `${line##*|}`)
