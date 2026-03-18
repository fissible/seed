#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"
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

ptyunit_test_summary
