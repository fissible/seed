#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/src/str.sh"

ptyunit_test_begin "str helpers"

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
