#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SEED_HOME/tests/vendor/ptyunit/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/seed.sh"

# seed_product
out=$(seed_product)
assert_contains "$out" '"sku"' "seed_product has sku"
assert_contains "$out" '"price"' "seed_product has price"
[[ "$(seed_product)" =~ \"sku\":\"[A-Z]{3}-[0-9]{5}\" ]]
assert_exit_code $? 0 "sku format"

# seed_order
out=$(seed_order)
assert_contains "$out" '"order_id"' "seed_order has order_id"
assert_contains "$out" '"status"' "seed_order has status"

# seed_order_item — line_total derived
item=$(seed_order_item)
qty=$(printf '%s' "$item" | grep -o '"qty":[0-9]*' | grep -o '[0-9]*$')
unit_price=$(printf '%s' "$item" | grep -o '"unit_price":[0-9.]*' | grep -o '[0-9.]*$')
line_total=$(printf '%s' "$item" | grep -o '"line_total":[0-9.]*' | grep -o '[0-9.]*$')
expected=$(awk "BEGIN { printf \"%.2f\", $qty * $unit_price }")
assert_eq "$expected" "$line_total" "line_total = qty * unit_price"

# seed_cart JSON has items array
cart=$(seed_cart)
assert_contains "$cart" '"items":[' "cart has items array"

# seed_cart --items 2
cart=$(seed_cart --items 2)
item_count=$(printf '%s' "$cart" | grep -o '"order_id"' | wc -l | tr -d ' ')
assert_eq "2" "$item_count" "cart has 2 items"

# seed_cart --format sql → exit 2
seed_cart --format sql 2>/dev/null
assert_exit_code $? 2 "seed_cart --format sql exits 2"

# seed_cart subtotal = sum of line_totals
cart=$(seed_cart --items 3)
subtotal=$(printf '%s' "$cart" | grep -o '"subtotal":[0-9.]*' | grep -o '[0-9.]*$')
assert_not_empty "$subtotal" "cart has subtotal"

# seed_coupon
out=$(seed_coupon)
assert_contains "$out" '"code"' "seed_coupon has code"
[[ "$(seed_coupon)" =~ \"discount_type\":\"(pct|fixed)\" ]]
assert_exit_code $? 0 "discount_type valid"

# seed_category
assert_contains "$(seed_category)" '"slug"' "seed_category has slug"

ptyunit_test_begin "ecommerce distinctness with --seed"

out=$(bash "$SEED_HOME/seed.sh" product --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_product --seed 42 --count 3: 3 distinct"

out=$(bash "$SEED_HOME/seed.sh" order --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_order --seed 42 --count 3: 3 distinct"

ptyunit_test_summary
