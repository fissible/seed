#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"

SH="bash $SEED_HOME/seed.sh"

# Unknown generator → exit 1
$SH notarealgen 2>/dev/null
assert_exit_code $? 1 "unknown generator exits 1"

# No args → exit 1
$SH 2>/dev/null
assert_exit_code $? 1 "no args exits 1"

# Scalar generators via CLI
assert_not_empty "$($SH name)" "CLI name"
assert_not_empty "$($SH email)" "CLI email"
assert_not_empty "$($SH uuid)" "CLI uuid"
assert_not_empty "$($SH date)" "CLI date"
assert_not_empty "$($SH number)" "CLI number"
assert_not_empty "$($SH lorem)" "CLI lorem"
assert_not_empty "$($SH ip)" "CLI ip"
assert_not_empty "$($SH url)" "CLI url"
assert_not_empty "$($SH bool)" "CLI bool"

# Record generators — default JSON
assert_contains "$($SH user)" '"email"' "CLI user json"
assert_contains "$($SH address)" '"city"' "CLI address json"
assert_contains "$($SH company)" '"domain"' "CLI company json"
assert_contains "$($SH product)" '"sku"' "CLI product json"
assert_contains "$($SH order)" '"order_id"' "CLI order json"
assert_contains "$($SH contact)" '"title"' "CLI contact json"
assert_contains "$($SH lead)" '"score"' "CLI lead json"
assert_contains "$($SH deal)" '"stage"' "CLI deal json"
assert_contains "$($SH activity)" '"type"' "CLI activity json"
assert_contains "$($SH note)" '"linked_type"' "CLI note json"
assert_contains "$($SH tag)" '"color"' "CLI tag json"
assert_contains "$($SH db_credentials)" '"host"' "CLI db_credentials json"
assert_contains "$($SH coordinates)" '"lat"' "CLI coordinates json"
assert_contains "$($SH country)" '"code"' "CLI country json"
assert_contains "$($SH credit_card)" '"number"' "CLI credit_card json"
assert_contains "$($SH log_entry)" '"timestamp"' "CLI log_entry json"
assert_contains "$($SH error_log)" '"stack_trace"' "CLI error_log json"
assert_not_empty "$($SH api_key)" "CLI api_key"

# --format sql
out=$($SH user --format sql)
assert_contains "$out" "INSERT INTO users" "user sql"

out=$($SH order --format sql --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "order sql count 3"

# --format csv: header + N rows
out=$($SH user --format csv --count 3)
assert_eq "4" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "user csv 3+header"

# --format kv
assert_contains "$($SH user --format kv)" 'NAME=' "user kv NAME key"
assert_contains "$($SH order_item --format kv)" 'ORDER_ID=' "order_item kv ORDER_ID"

# seed_cart special cases
assert_contains "$($SH cart)" '"items":[' "cart json items"
assert_eq "2" "$($SH cart --items 2 | grep -o '"order_id"' | wc -l | tr -d ' ')" "cart 2 items"
$SH cart --format sql 2>/dev/null
assert_exit_code $? 2 "cart sql exits 2"

# seed_cart --format csv flattens items
out=$($SH cart --items 2 --format csv)
assert_contains "$out" "item_1_product_sku" "cart csv item_1_product_sku"
assert_contains "$out" "item_2_product_sku" "cart csv item_2_product_sku"

# TUI helpers
assert_eq "5" "$($SH filenames --count 5 | wc -l | tr -d ' ')" "CLI filenames 5"
assert_eq "3" "$($SH dirtree --count 3 | wc -l | tr -d ' ')" "CLI dirtree 3"
assert_eq "7" "$($SH menu_items --count 7 | wc -l | tr -d ' ')" "CLI menu_items 7"

# --format on scalar → exit 2
$SH name --format json 2>/dev/null
assert_exit_code $? 2 "CLI name --format exits 2"

$SH api_key --format json 2>/dev/null
assert_exit_code $? 2 "CLI api_key --format exits 2"

# --help / -h
out=$($SH --help); ec=$?
assert_exit_code $ec 0 "--help exits 0"
assert_contains "$out" 'Usage' "--help output: Usage"
assert_contains "$out" 'email' "--help output: email generator listed"
assert_contains "$out" 'custom' "--help output: custom generator listed"
assert_contains "$out" '--count' "--help output: --count flag listed"
assert_contains "$out" '--schema' "--help output: --schema flag listed"

out=$($SH -h)
assert_contains "$out" 'Usage' "-h output: Usage"

# seed_custom via CLI
assert_contains "$(bash seed.sh custom --schema tests/fixtures/example.seed)" '"firstname"' "CLI custom json"
assert_contains "$(bash seed.sh custom --schema tests/fixtures/example.seed --format sql)" 'INSERT INTO example_records' "CLI custom sql table name"
bash seed.sh custom 2>/dev/null
assert_exit_code $? 2 "CLI custom --schema required"

ptyunit_test_summary
