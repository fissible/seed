#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SEED_HOME/tests/vendor/ptyunit/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/seed.sh"

ptyunit_test_begin "format helpers"

# JSON format
out=$(_seed_emit_record json users name "Jane Doe" email "jane@test.com")
assert_contains "$out" '"name":"Jane Doe"' "json field name"
assert_contains "$out" '"email":"jane@test.com"' "json field email"

# JSON: wrap in object braces
[[ "$out" == "{"* ]] && [[ "$out" == *"}" ]]
assert_exit_code $? 0 "json is object"

# JSON: numeric value not quoted
out=$(_seed_emit_record json users score "42")
assert_contains "$out" '"score":42' "json numeric not quoted"

# JSON: float not quoted
out=$(_seed_emit_record json users price "9.99")
assert_contains "$out" '"price":9.99' "json float not quoted"

# KV format
out=$(_seed_emit_record kv users name "Jane Doe" email "jane@test.com")
assert_contains "$out" 'NAME="Jane Doe"' "kv NAME key"
assert_contains "$out" 'EMAIL="jane@test.com"' "kv EMAIL key"

# KV: underscore field → uppercase
out=$(_seed_emit_record kv users order_id "abc-123")
assert_contains "$out" 'ORDER_ID="abc-123"' "kv ORDER_ID key"

# CSV format: always has header
out=$(_seed_emit_record csv users name "Jane Doe" email "jane@test.com")
assert_contains "$out" 'name,email' "csv header present"
assert_contains "$out" '"Jane Doe","jane@test.com"' "csv values quoted"

# SQL format
out=$(_seed_emit_record sql users name "Jane Doe" email "jane@test.com")
assert_contains "$out" "INSERT INTO users" "sql table name"
assert_contains "$out" "name, email" "sql columns"
assert_contains "$out" "'Jane Doe'" "sql single-quoted value"

# SQL: numeric not quoted
out=$(_seed_emit_record sql products price "9.99" stock_qty "5")
assert_contains "$out" "9.99" "sql numeric not quoted"
assert_contains "$out" "5" "sql integer not quoted"

# Unknown format → exit 2
_seed_emit_record tsv users name "Jane" 2>/dev/null
assert_exit_code $? 2 "unknown format exits 2"

ptyunit_test_begin "core record generators"

# seed_user
out=$(seed_user)
assert_contains "$out" '"name"' "seed_user has name"
assert_contains "$out" '"email"' "seed_user has email"
assert_contains "$out" '"phone"' "seed_user has phone"
assert_contains "$out" '"dob"' "seed_user has dob"
assert_contains "$out" '"username"' "seed_user has username"

# seed_user --format kv
out=$(seed_user --format kv)
assert_contains "$out" 'NAME=' "seed_user kv NAME"
assert_contains "$out" 'USERNAME=' "seed_user kv USERNAME"

# seed_user --count 3 --format csv: header + 3 data rows = 4 lines
assert_eq "4" "$(seed_user --count 3 --format csv | wc -l | tr -d ' \t')" "seed_user csv count 3"

# seed_user --count 3 --format sql: 3 INSERT statements
assert_eq "3" "$(seed_user --count 3 --format sql | wc -l | tr -d ' \t')" "seed_user sql count 3"

# seed_address
out=$(seed_address)
assert_contains "$out" '"street"' "seed_address has street"
assert_contains "$out" '"city"' "seed_address has city"
assert_contains "$out" '"state"' "seed_address has state"
assert_contains "$out" '"zip"' "seed_address has zip"
assert_contains "$out" '"country":"US"' "seed_address country is US"

# seed_company
out=$(seed_company)
assert_contains "$out" '"name"' "seed_company has name"
assert_contains "$out" '"domain"' "seed_company has domain"
assert_contains "$out" '"street"' "seed_company has street (flat)"
assert_contains "$out" '"country":"US"' "seed_company country is US"

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

ptyunit_test_begin "address and company distinctness"

out=$(bash "$SEED_HOME/seed.sh" address --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_address --seed 42 --count 3: 3 distinct"

out=$(bash "$SEED_HOME/seed.sh" company --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_company --seed 42 --count 3: 3 distinct"

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

ptyunit_test_summary
