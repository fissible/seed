#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SEED_HOME/tests/vendor/ptyunit/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/seed.sh"

# --- _seed_cfield_* unit tests ---

ptyunit_test_begin "_seed_cfield_* unit"

_seed_cfield_first_name; assert_not_empty "$_SEED_RESULT" "_seed_cfield_first_name non-empty"
_seed_cfield_last_name;  assert_not_empty "$_SEED_RESULT" "_seed_cfield_last_name non-empty"
_seed_cfield_name;       assert_not_empty "$_SEED_RESULT" "_seed_cfield_name non-empty"
_seed_cfield_email;      assert_not_empty "$_SEED_RESULT" "_seed_cfield_email non-empty"
_seed_cfield_phone;      assert_not_empty "$_SEED_RESULT" "_seed_cfield_phone non-empty"
_seed_cfield_uuid;       assert_not_empty "$_SEED_RESULT" "_seed_cfield_uuid non-empty"
_seed_cfield_date;       assert_not_empty "$_SEED_RESULT" "_seed_cfield_date non-empty"
_seed_cfield_number;     assert_not_empty "$_SEED_RESULT" "_seed_cfield_number non-empty"
_seed_cfield_bool;       assert_not_empty "$_SEED_RESULT" "_seed_cfield_bool non-empty"
_seed_cfield_lorem;      assert_not_empty "$_SEED_RESULT" "_seed_cfield_lorem non-empty"
_seed_cfield_ip;         assert_not_empty "$_SEED_RESULT" "_seed_cfield_ip non-empty"
_seed_cfield_url;        assert_not_empty "$_SEED_RESULT" "_seed_cfield_url non-empty"

_seed_cfield_number "5" "5"
assert_eq "5" "$_SEED_RESULT" "_seed_cfield_number min=max=5 → 5"

_seed_cfield_date "2024-01-01" "2024-01-01"
assert_contains "$_SEED_RESULT" "2024-" "_seed_cfield_date single-year range starts with 2024-"

_seed_cfield_bool
[[ "$_SEED_RESULT" == "true" || "$_SEED_RESULT" == "false" ]]
assert_exit_code $? 0 "_seed_cfield_bool: true or false"

# --- seed_custom output format tests ---

ptyunit_test_begin "seed_custom output formats"

out=$(seed_custom --schema example 2>&1)
assert_contains "$out" '"firstname"'  "seed_custom json: firstname key"
assert_contains "$out" '"email"'      "seed_custom json: email key"
assert_contains "$out" '"age"'        "seed_custom json: age key"
assert_contains "$out" '"active"'     "seed_custom json: active key"
assert_contains "$out" '"created_at"' "seed_custom json: created_at key"

out=$(seed_custom --schema example --format sql)
assert_contains "$out" 'INSERT INTO example_records' "seed_custom sql: table name"

out=$(seed_custom --schema example --format kv)
assert_contains "$out" 'FIRSTNAME=' "seed_custom kv: FIRSTNAME key"

out=$(seed_custom --schema example --format csv)
assert_contains "$out" 'firstname' "seed_custom csv: firstname in header"
assert_contains "$out" 'email'     "seed_custom csv: email in header"

out=$(seed_custom --schema example --format sql --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "seed_custom --count 3: 3 sql rows"

# --- Reproducibility ---

ptyunit_test_begin "seed_custom reproducibility"

REPRO_SCHEMA="${TMPDIR:-/tmp}/repro_$$.seed"
printf 'table=repro_test\nfn|VARCHAR(100)|first_name\nage|INT|number --min 20 --max 40\nactive|BOOLEAN|bool\n' > "$REPRO_SCHEMA"
run1=$(seed_custom --schema "$REPRO_SCHEMA" --seed 42 --count 3)
run2=$(seed_custom --schema "$REPRO_SCHEMA" --seed 42 --count 3)
assert_eq "$run1" "$run2" "seed_custom --seed 42 reproducible (no-UUID schema)"
rm -f "$REPRO_SCHEMA"

out=$(seed_custom --schema example --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" "seed_custom --count 3 produces 3 distinct records"

# --- Error handling ---

ptyunit_test_begin "seed_custom error handling"

out=$(seed_custom 2>&1); ec=$?
assert_exit_code $ec 2 "seed_custom: no --schema exits 2"
assert_contains "$out" '--schema is required' "seed_custom: no --schema error message"

BAD_GEN="${TMPDIR:-/tmp}/badgen_$$.seed"
printf 'table=test\nfield|VARCHAR(50)|notarealgen\n' > "$BAD_GEN"
seed_custom --schema "$BAD_GEN" 2>/dev/null; ec=$?
assert_exit_code $ec 2 "seed_custom: unknown generator exits 2"
rm -f "$BAD_GEN"

out=$(seed_custom --schema notafile 2>&1); ec=$?
assert_exit_code $ec 2 "seed_custom: missing file exits 2"
assert_contains "$out" 'notafile.seed' "seed_custom: missing file: resolved path in message"

NO_TABLE="${TMPDIR:-/tmp}/notable_$$.seed"
printf 'id|VARCHAR(36)|uuid\n' > "$NO_TABLE"
seed_custom --schema "$NO_TABLE" 2>/dev/null; ec=$?
assert_exit_code $ec 2 "seed_custom: missing table= exits 2"
rm -f "$NO_TABLE"

# --- _seed_parse_flags --schema flag ---

ptyunit_test_begin "_seed_parse_flags --schema flag"

_seed_parse_flags --schema foo
assert_eq "foo" "$_SEED_FLAG_SCHEMA" "_seed_parse_flags: --schema sets _SEED_FLAG_SCHEMA"

_seed_parse_flags
assert_eq "" "$_SEED_FLAG_SCHEMA" "_seed_parse_flags: --schema resets to empty (no bleed)"

out=$(SEED_FIXTURES_DIR=/tmp seed_custom --schema example 2>&1); ec=$?
assert_exit_code $ec 2 "SEED_FIXTURES_DIR override: exits 2 when not found"
assert_contains "$out" '/tmp/example.seed' "SEED_FIXTURES_DIR override: resolved path in message"

ptyunit_test_summary
