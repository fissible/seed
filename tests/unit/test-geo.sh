#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SEED_HOME/tests/vendor/ptyunit/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/seed.sh"

ptyunit_test_begin "seed_coordinates"

out=$(seed_coordinates)
assert_contains "$out" '"lat"' "seed_coordinates has lat key"
assert_contains "$out" '"lng"' "seed_coordinates has lng key"

# lat and lng are numeric — no quotes in JSON
[[ "$out" =~ \"lat\":[0-9\-] ]]
assert_exit_code $? 0 "seed_coordinates lat is unquoted numeric"

# Worldwide range: 50 samples must include at least one negative lat
neg=$(seed_coordinates --count 50 | grep -c '"lat":-' || true)
[[ "$neg" -gt 0 ]]
assert_exit_code $? 0 "seed_coordinates includes negative lats (worldwide range)"

# seed_coordinates --seed 42 --count 3: 3 distinct records
out=$(bash "$SEED_HOME/seed.sh" coordinates --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_coordinates --seed 42 --count 3: 3 distinct"

ptyunit_test_begin "seed_country"

out=$(seed_country)
assert_contains "$out" '"code"' "seed_country has code"
assert_contains "$out" '"name"' "seed_country has name"
assert_contains "$out" '"region"' "seed_country has region"

# code matches ^[A-Z]{2}$
[[ "$out" =~ \"code\":\"[A-Z][A-Z]\" ]]
assert_exit_code $? 0 "seed_country code is 2-letter uppercase"

# seed_country --seed 42 --count 3: 3 distinct records
out=$(bash "$SEED_HOME/seed.sh" country --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_country --seed 42 --count 3: 3 distinct"

ptyunit_test_begin "data file: countries.txt"

count=$(wc -l < "$SEED_HOME/data/countries.txt" | tr -d ' ')
[[ "$count" -ge 60 ]]
assert_exit_code $? 0 "countries.txt has >= 60 entries"

ptyunit_test_summary
