#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/seed.sh"

ptyunit_test_begin "_seed_new_infer_sql_type"

assert_eq "VARCHAR(36)"  "$(_seed_new_infer_sql_type uuid)"        "uuid → VARCHAR(36)"
assert_eq "INT"          "$(_seed_new_infer_sql_type number)"      "number → INT"
assert_eq "TIMESTAMP"    "$(_seed_new_infer_sql_type date)"        "date → TIMESTAMP"
assert_eq "BOOLEAN"      "$(_seed_new_infer_sql_type bool)"        "bool → BOOLEAN"
assert_eq "VARCHAR(15)"  "$(_seed_new_infer_sql_type ip)"          "ip → VARCHAR(15)"
assert_eq "VARCHAR(255)" "$(_seed_new_infer_sql_type url)"         "url → VARCHAR(255)"
assert_eq "VARCHAR(255)" "$(_seed_new_infer_sql_type email)"       "email → VARCHAR(255)"
assert_eq "VARCHAR(100)" "$(_seed_new_infer_sql_type first_name)"  "first_name → VARCHAR(100)"
assert_eq "VARCHAR(100)" "$(_seed_new_infer_sql_type last_name)"   "last_name → VARCHAR(100)"
assert_eq "VARCHAR(100)" "$(_seed_new_infer_sql_type name)"        "name → VARCHAR(100)"
assert_eq "VARCHAR(100)" "$(_seed_new_infer_sql_type phone)"       "phone → VARCHAR(100)"
assert_eq "TEXT"         "$(_seed_new_infer_sql_type lorem)"       "lorem → TEXT"
assert_eq "VARCHAR(255)" "$(_seed_new_infer_sql_type unknown_gen)" "unknown → VARCHAR(255) fallback"

ptyunit_test_summary
