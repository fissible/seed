#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PTYUNIT_HOME/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/seed.sh"

ptyunit_test_begin "seed_credit_card"

# Basic fields present
out=$(seed_credit_card)
assert_contains "$out" '"type"' "seed_credit_card has type"
assert_contains "$out" '"number"' "seed_credit_card has number"
assert_contains "$out" '"expiry"' "seed_credit_card has expiry"
assert_contains "$out" '"cvv"' "seed_credit_card has cvv"

# number and cvv are numeric (unquoted in JSON)
[[ "$out" =~ \"number\":[0-9] ]]
assert_exit_code $? 0 "seed_credit_card number is unquoted numeric"
[[ "$out" =~ \"cvv\":[0-9] ]]
assert_exit_code $? 0 "seed_credit_card cvv is unquoted numeric"

# Luhn validity — extract raw number value and verify sum % 10 == 0
raw_num=$(printf '%s\n' "$out" | grep -o '"number":[0-9]*' | cut -d: -f2)
luhn_ok=$(printf '%s\n' "$raw_num" | awk '{
    n = length($0); sum = 0
    for (i = n; i >= 1; i--) {
        d = substr($0, i, 1) + 0
        if ((n - i + 1) % 2 == 0) { d = d * 2; if (d > 9) d -= 9 }
        sum += d
    }
    print (sum % 10 == 0) ? "valid" : "invalid"
}')
assert_eq "valid" "$luhn_ok" "credit card number passes Luhn check"

# Expiry format MM/YY
raw_exp=$(printf '%s\n' "$out" | grep -o '"expiry":"[^"]*"' | cut -d'"' -f4)
[[ "$raw_exp" =~ ^[0-9]{2}/[0-9]{2}$ ]]
assert_exit_code $? 0 "expiry matches MM/YY format"

# Type-specific prefix checks — generate 100 cards, verify prefixes
cards=$(bash "$SEED_HOME/seed.sh" credit_card --seed 42 --count 100)
# Assert all four types appear in 100 cards so conditional checks below cannot silently skip
[[ $(printf '%s\n' "$cards" | grep -c '"type":"Visa"') -gt 0 ]]
assert_exit_code $? 0 "100 cards include at least one Visa"
[[ $(printf '%s\n' "$cards" | grep -c '"type":"Mastercard"') -gt 0 ]]
assert_exit_code $? 0 "100 cards include at least one Mastercard"
[[ $(printf '%s\n' "$cards" | grep -c '"type":"Amex"') -gt 0 ]]
assert_exit_code $? 0 "100 cards include at least one Amex"
[[ $(printf '%s\n' "$cards" | grep -c '"type":"Discover"') -gt 0 ]]
assert_exit_code $? 0 "100 cards include at least one Discover"
visa=$(printf '%s\n' "$cards" | grep '"type":"Visa"' | head -1)
if [[ -n "$visa" ]]; then
    [[ "$visa" =~ \"number\":4 ]]
    assert_exit_code $? 0 "Visa number starts with 4"
fi
mc=$(printf '%s\n' "$cards" | grep '"type":"Mastercard"' | head -1)
if [[ -n "$mc" ]]; then
    [[ "$mc" =~ \"number\":5 ]]
    assert_exit_code $? 0 "Mastercard number starts with 5"
fi
amex=$(printf '%s\n' "$cards" | grep '"type":"Amex"' | head -1)
if [[ -n "$amex" ]]; then
    [[ "$amex" =~ \"number\":3 ]]
    assert_exit_code $? 0 "Amex number starts with 3"
    # Amex CVV is 4 digits (range 1000-9999, always no leading zero)
    amex_cvv=$(printf '%s\n' "$amex" | grep -o '"cvv":[0-9]*' | cut -d: -f2)
    [[ ${#amex_cvv} -eq 4 ]]
    assert_exit_code $? 0 "Amex CVV is 4 digits"
fi
discover=$(printf '%s\n' "$cards" | grep '"type":"Discover"' | head -1)
if [[ -n "$discover" ]]; then
    [[ "$discover" =~ \"number\":6 ]]
    assert_exit_code $? 0 "Discover number starts with 6"
fi

# --seed 42 --count 3: 3 distinct records
out=$(bash "$SEED_HOME/seed.sh" credit_card --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_credit_card --seed 42 --count 3: 3 distinct"

# --format sql: number is unquoted (numeric)
out_sql=$(seed_credit_card --format sql)
# number appears without surrounding quotes in SQL VALUES
[[ "$out_sql" =~ [[:space:]][0-9]{15,16}[,\)] ]]
assert_exit_code $? 0 "seed_credit_card --format sql: number unquoted"

# --format csv: number field is present (always quoted in CSV)
out_csv=$(seed_credit_card --format csv)
assert_contains "$out_csv" 'number' "seed_credit_card --format csv: number column present"

ptyunit_test_summary
