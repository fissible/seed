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

ptyunit_test_begin "scalar generators"

# seed_name
assert_not_empty "$(seed_name)" "seed_name not empty"
[[ "$(seed_name)" =~ ^[A-Z][a-z]+\ [A-Z][a-z]+$ ]]
assert_exit_code $? 0 "seed_name format"

# seed_email
assert_not_empty "$(seed_email)" "seed_email not empty"
[[ "$(seed_email)" =~ ^[a-z]+\.[a-z]+@ ]]
assert_exit_code $? 0 "seed_email format"

# seed_phone
[[ "$(seed_phone)" =~ ^[2-9][0-9]{2}-[0-9]{3}-[0-9]{4}$ ]]
assert_exit_code $? 0 "seed_phone format"

# seed_uuid
[[ "$(seed_uuid)" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]]
assert_exit_code $? 0 "seed_uuid format"

# seed_date
[[ "$(seed_date)" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
assert_exit_code $? 0 "seed_date format"

# seed_number default range
n=$(seed_number)
[[ "$n" -ge 1 && "$n" -le 100 ]]
assert_exit_code $? 0 "seed_number default range"

n=$(seed_number --min 42 --max 42)
assert_eq "42" "$n" "seed_number exact"

# seed_lorem
assert_not_empty "$(seed_lorem)" "seed_lorem not empty"

# seed_lorem mutual exclusion
seed_lorem --words 3 --sentences 2 2>/dev/null
assert_exit_code $? 2 "seed_lorem --words + --sentences exits 2"

# seed_ip
[[ "$(seed_ip)" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
assert_exit_code $? 0 "seed_ip format"

# seed_url
[[ "$(seed_url)" =~ ^https:// ]]
assert_exit_code $? 0 "seed_url https"

# seed_bool
val=$(seed_bool)
[[ "$val" == "true" || "$val" == "false" ]]
assert_exit_code $? 0 "seed_bool value"

# --count N produces N lines
assert_eq "5" "$(seed_name --count 5 | wc -l | tr -d ' \t')" "seed_name --count 5"
assert_eq "3" "$(seed_uuid --count 3 | wc -l | tr -d ' \t')" "seed_uuid --count 3"

# --format on scalar → exit 2
seed_name --format json 2>/dev/null
assert_exit_code $? 2 "seed_name --format exits 2"

ptyunit_test_begin "data file sizes"
first_count=$(wc -l < "$SEED_HOME/data/first_names.txt" | tr -d ' ')
last_count=$(wc -l  < "$SEED_HOME/data/last_names.txt"  | tr -d ' ')
lorem_count=$(wc -l < "$SEED_HOME/data/lorem.txt"       | tr -d ' ')
[[ "$first_count" -ge 140 ]]
assert_exit_code $? 0 "first_names has >= 140 entries"
[[ "$last_count"  -ge 140 ]]
assert_exit_code $? 0 "last_names has >= 140 entries"
[[ "$lorem_count" -ge 55 ]]
assert_exit_code $? 0 "lorem has >= 55 entries"

ptyunit_test_begin "rng variety"
# 10 numbers in [1,1000] must have at least 6 unique values
uniq_count=$(seed_number --count 10 --max 1000 | sort -u | wc -l | tr -d ' ')
[[ "$uniq_count" -ge 6 ]]
assert_exit_code $? 0 "_seed_random_int produces varied output"

# _seed_random_float variety: 5 prices must not all be the same
prices=$(seed_number --count 5 --max 999)
first_price=$(printf '%s\n' "$prices" | head -1)
different=$(printf '%s\n' "$prices" | grep -vc "^${first_price}$" || true)
[[ "$different" -gt 0 ]]
assert_exit_code $? 0 "_seed_random_int values are not all identical"

ptyunit_test_begin "data file caching"

# After sourcing seed.sh, cache globals should not exist yet
[[ -z "$_SEED_DATA_FIRST_NAMES_N" ]]
assert_exit_code $? 0 "cache empty before first call"

# After _seed_random_line, cache should be populated
_seed_random_line first_names > /dev/null
[[ -n "$_SEED_DATA_FIRST_NAMES_N" ]]
assert_exit_code $? 0 "cache populated after first call"

# A second call should produce a non-empty result (uses cache, not file)
v2=$(_seed_random_line first_names)
assert_not_empty "$v2" "second call from cache returns value"

# Cache count should match actual file line count
file_count=$(wc -l < "$SEED_HOME/data/first_names.txt" | tr -d ' ')
assert_eq "$file_count" "$_SEED_DATA_FIRST_NAMES_N" "cache count matches file"

ptyunit_test_begin "seed_date day range"

# Generate 500 dates — statistically certain to include days 29-31
high_days=$(seed_date --count 500 | awk -F'-' '$3+0 > 28' | wc -l | tr -d ' ')
[[ "$high_days" -gt 0 ]]
assert_exit_code $? 0 "seed_date generates days 29-31"

# Leap year: 2000 was a leap year; Feb should allow day 29.
# --from/--to only constrain the year, so dates across all of 2000
# are generated. Among them, some February dates should reach day 29.
# Use 2000 dates: P(at least one Feb 29) > 99.99% with correct leap logic.
feb29=$(seed_date --count 2000 --from 2000-01-01 --to 2000-12-31 \
    | awk -F'-' '$2=="02" && $3=="29"' | wc -l | tr -d ' ')
[[ "$feb29" -gt 0 ]]
assert_exit_code $? 0 "seed_date generates Feb 29 in leap year (2000)"

# Non-leap year: 1900 was NOT a leap year (divisible by 100 but not 400).
# --from/--to only constrain the year range, not the month or day.
# With --from 1900-... --to 1900-..., year is fixed to 1900 and month/day
# are picked randomly across all of 1900. The leap-year check for year=1900
# should set max_day=28 for February, so no Feb 29 should ever appear.
bad=$(seed_date --count 200 --from 1900-01-01 --to 1900-12-31 \
    | awk -F'-' '$2=="02" && $3=="29"')
assert_eq "" "$bad" "no Feb 29 in non-leap year (1900)"

ptyunit_test_begin "seed --seed distinctness"

# Generators with LCG-only randomness: --seed 42 --count 3 must yield 3 distinct lines.
# These FAIL on current code (all 3 iterations get same starting state) and PASS after refactor.
for gen in name email phone date lorem ip url; do
    out=$(bash "$SEED_HOME/seed.sh" $gen --seed 42 --count 3)
    assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
        "$gen --seed 42 --count 3: 3 distinct"
done

# bool: only 2 possible values — 10 outputs must include both.
out=$(bash "$SEED_HOME/seed.sh" bool --seed 42 --count 10)
assert_eq "2" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "bool --seed 42 --count 10: both true and false"

# Regression: seed_name and seed_email still work as standalone generators
assert_not_empty "$(bash "$SEED_HOME/seed.sh" name)" "seed_name standalone post-refactor"
assert_not_empty "$(bash "$SEED_HOME/seed.sh" email)" "seed_email standalone post-refactor"

ptyunit_test_begin "network scalar generators"

# seed_host: bare hostname, no scheme or path
assert_not_empty "$(seed_host)" "seed_host not empty"
[[ "$(seed_host)" =~ ^[a-z0-9.-]+\.[a-z]{2,}$ ]]
assert_exit_code $? 0 "seed_host format (no scheme, no path)"

# seed_port: must be one of the well-known port values
port=$(seed_port)
assert_not_empty "$port" "seed_port not empty"
[[ "$port" =~ ^[0-9]+$ ]]
assert_exit_code $? 0 "seed_port is numeric"
# verify it's in the known list
echo "5432 3306 6379 27017 8080 8000 3000 9200 5672 9042 1433 1521 26257 8086 11211" | grep -wq "$port"
assert_exit_code $? 0 "seed_port is a known port"

# seed_password: alphanumeric, default length 10
pwd=$(seed_password)
assert_not_empty "$pwd" "seed_password not empty"
assert_eq "10" "${#pwd}" "seed_password default length 10"
[[ "$pwd" =~ ^[A-Za-z0-9]+$ ]]
assert_exit_code $? 0 "seed_password alphanumeric only"

# seed_password --length 20
pwd=$(seed_password --length 20)
assert_eq "20" "${#pwd}" "seed_password --length 20"

# seed_password --seed 42 --count 3: 3 distinct passwords
out=$(bash "$SEED_HOME/seed.sh" password --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_password --seed 42 --count 3: 3 distinct"

ptyunit_test_begin "_seed_random_datetime_v"

# Format check: must be YYYY-MM-DDThh:mm:ssZ
_seed_rng_init
_seed_random_datetime_v 2025
[[ "$_SEED_RESULT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
assert_exit_code $? 0 "_seed_random_datetime_v format"

# Year is in range [2000, to_year]
_seed_random_datetime_v 2025
year="${_SEED_RESULT:0:4}"
[[ "$year" -ge 2000 && "$year" -le 2025 ]]
assert_exit_code $? 0 "_seed_random_datetime_v year in range"

# Variety: 3 calls must not all return identical results
dt1=""; dt2=""; dt3=""
_seed_random_datetime_v 2025; dt1="$_SEED_RESULT"
_seed_random_datetime_v 2025; dt2="$_SEED_RESULT"
_seed_random_datetime_v 2025; dt3="$_SEED_RESULT"
[[ "$dt1" != "$dt2" || "$dt2" != "$dt3" ]]
assert_exit_code $? 0 "_seed_random_datetime_v produces varied output"

ptyunit_test_summary
