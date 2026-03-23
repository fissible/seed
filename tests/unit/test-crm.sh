#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PTYUNIT_HOME/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/seed.sh"

# seed_contact
out=$(seed_contact)
assert_contains "$out" '"name"' "seed_contact has name"
assert_contains "$out" '"email"' "seed_contact has email"
assert_contains "$out" '"title"' "seed_contact has title"
assert_contains "$out" '"phone"' "seed_contact has phone"
assert_contains "$out" '"company"' "seed_contact has company"

# seed_lead — flat, has all contact + CRM fields
out=$(seed_lead)
assert_contains "$out" '"source"' "seed_lead has source"
assert_contains "$out" '"score"' "seed_lead has score"
assert_contains "$out" '"name"' "seed_lead has name (flat)"

# seed_deal
out=$(seed_deal)
assert_contains "$out" '"stage"' "seed_deal has stage"
assert_contains "$out" '"value"' "seed_deal has value"

# seed_activity — type is one of call/email/meeting
[[ "$(seed_activity)" =~ \"type\":\"(call|email|meeting)\" ]]
assert_exit_code $? 0 "activity type valid"

# seed_note — linked_type is contact or deal
[[ "$(seed_note)" =~ \"linked_type\":\"(contact|deal)\" ]]
assert_exit_code $? 0 "note linked_type valid"

# seed_tag — color is hex
[[ "$(seed_tag)" =~ \"color\":\"#[0-9a-f]{6}\" ]]
assert_exit_code $? 0 "tag color hex format"

# --count 3
assert_eq "3" "$(seed_contact --count 3 --format sql | wc -l | tr -d ' ')" "contact count sql"

ptyunit_test_begin "crm coherence and distinctness"

# seed_contact coherence
out=$(bash "$SEED_HOME/seed.sh" contact --seed 42)
name_val=$(printf '%s' "$out" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
email_val=$(printf '%s' "$out" | grep -o '"email":"[^"]*"' | cut -d'"' -f4)
email_prefix="${email_val%@*}"
first=$(printf '%s' "$name_val" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
last=$(printf '%s' "$name_val" | cut -d' ' -f2 | tr '[:upper:]' '[:lower:]')
assert_eq "${first}.${last}" "$email_prefix" "seed_contact email coherent with name"

out=$(bash "$SEED_HOME/seed.sh" contact --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_contact --seed 42 --count 3: 3 distinct"

# seed_lead coherence
out=$(bash "$SEED_HOME/seed.sh" lead --seed 42)
name_val=$(printf '%s' "$out" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
email_val=$(printf '%s' "$out" | grep -o '"email":"[^"]*"' | cut -d'"' -f4)
email_prefix="${email_val%@*}"
first=$(printf '%s' "$name_val" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
last=$(printf '%s' "$name_val" | cut -d' ' -f2 | tr '[:upper:]' '[:lower:]')
assert_eq "${first}.${last}" "$email_prefix" "seed_lead email coherent with name"

out=$(bash "$SEED_HOME/seed.sh" lead --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_lead --seed 42 --count 3: 3 distinct"

ptyunit_test_summary
