#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/seed.sh"

ptyunit_test_begin "helpers"

# _seed_random_int
val=$(_seed_random_int 5 5)
assert_eq "5" "$val" "_seed_random_int exact value"

val=$(_seed_random_int 1 100)
[[ "$val" -ge 1 && "$val" -le 100 ]]
assert_exit_code $? 0 "_seed_random_int in range"

# _seed_random_float
val=$(_seed_random_float 1.00 1.00)
assert_eq "1.00" "$val" "_seed_random_float exact"

# _seed_today — format check
today=$(_seed_today)
[[ "$today" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
assert_exit_code $? 0 "_seed_today format"

# _seed_random_line
line=$(_seed_random_line first_names)
assert_not_empty "$line" "_seed_random_line returns value"

# _seed_json_escape
escaped=$(_seed_json_escape 'say "hello"')
assert_eq 'say \"hello\"' "$escaped" "_seed_json_escape quotes"

# _seed_date_subtract_years
result=$(_seed_date_subtract_years "2024-07-15" 10)
assert_eq "2014-07-15" "$result" "_seed_date_subtract_years"

# _seed_uuid_gen — format check
uuid=$(_seed_uuid_gen)
[[ "$uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]]
assert_exit_code $? 0 "_seed_uuid_gen format"

# _seed_random_elem
elem=$(_seed_random_elem a b c)
[[ "$elem" == "a" || "$elem" == "b" || "$elem" == "c" ]]
assert_exit_code $? 0 "_seed_random_elem returns one of the elements"

# _seed_random_state — 2 uppercase letters
state=$(_seed_random_state)
[[ "$state" =~ ^[A-Z]{2}$ ]]
assert_exit_code $? 0 "_seed_random_state format"

# _seed_random_zip — 5 digits
zip=$(_seed_random_zip)
[[ "$zip" =~ ^[0-9]{5}$ ]]
assert_exit_code $? 0 "_seed_random_zip format"

# _seed_is_numeric
_seed_is_numeric "42"
assert_exit_code $? 0 "_seed_is_numeric integer"
_seed_is_numeric "3.14"
assert_exit_code $? 0 "_seed_is_numeric float"
_seed_is_numeric "hello"
assert_exit_code $? 1 "_seed_is_numeric string"

ptyunit_test_summary
