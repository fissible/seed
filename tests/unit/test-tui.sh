#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/seed.sh"

# seed_filenames default count = 10 lines
assert_eq "10" "$(seed_filenames | wc -l | tr -d ' ')" "seed_filenames default 10"

# seed_filenames --count 5
assert_eq "5" "$(seed_filenames --count 5 | wc -l | tr -d ' ')" "seed_filenames count 5"

# seed_filenames output: contains a dash
assert_contains "$(seed_filenames --count 1)" "-" "filename contains dash"

# seed_dirtree — paths have at least one slash
out=$(seed_dirtree --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "dirtree count 3"
assert_contains "$out" "/" "dirtree has slash"

# seed_menu_items
out=$(seed_menu_items --count 5)
assert_eq "5" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "menu_items count 5"

# --format rejected
seed_filenames --format json 2>/dev/null
assert_exit_code $? 2 "seed_filenames --format exits 2"

seed_dirtree --format json 2>/dev/null
assert_exit_code $? 2 "seed_dirtree --format exits 2"

seed_menu_items --format json 2>/dev/null
assert_exit_code $? 2 "seed_menu_items --format exits 2"

ptyunit_test_summary
