#!/usr/bin/env bash
# tests/unit/test-flags.sh — unit tests for _seed_parse_flags
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/seed.sh"

# --count 5 → _SEED_FLAG_COUNT == "5", exit 0
ptyunit_test_begin "--count sets value"
_seed_parse_flags --count 5
assert_exit_code "$?" "0" "--count exits 0"
assert_eq "5" "$_SEED_FLAG_COUNT" "--count value stored"

# --format kv → _SEED_FLAG_FORMAT == "kv", exit 0
ptyunit_test_begin "--format sets value"
_seed_parse_flags --format kv
assert_exit_code "$?" "0" "--format exits 0"
assert_eq "kv" "$_SEED_FLAG_FORMAT" "--format value stored"

# --unknown-flag → exit 2
ptyunit_test_begin "unknown flag exits 2"
_seed_parse_flags --unknown-flag 2>/dev/null
assert_exit_code "$?" "2" "unknown flag exits 2"

# --count (no value) → exit 2
ptyunit_test_begin "--count with no value exits 2"
_seed_parse_flags --count 2>/dev/null
assert_exit_code "$?" "2" "--count missing value exits 2"

# no args → globals reset to defaults, exit 0
ptyunit_test_begin "no args resets defaults and exits 0"
# First put something non-default in the globals
_SEED_FLAG_COUNT=99
_SEED_FLAG_FORMAT="csv"
_seed_parse_flags
assert_exit_code "$?" "0" "no-arg call exits 0"
assert_eq "1"    "$_SEED_FLAG_COUNT"  "COUNT reset to default 1"
assert_eq "json" "$_SEED_FLAG_FORMAT" "FORMAT reset to default json"

ptyunit_test_summary
