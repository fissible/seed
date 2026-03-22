#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"
source "$SEED_HOME/tests/assert-ext.sh"
source "$SEED_HOME/seed.sh"

ptyunit_test_begin "seed_log_entry"

out=$(seed_log_entry)
# Timestamp format
[[ "$out" =~ \"timestamp\":\"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\" ]]
assert_exit_code $? 0 "seed_log_entry timestamp format"

# Level in {DEBUG, INFO, WARN, ERROR}
[[ "$out" =~ \"level\":\"(DEBUG|INFO|WARN|ERROR)\" ]]
assert_exit_code $? 0 "seed_log_entry level is valid"

assert_contains "$out" '"service"' "seed_log_entry has service"
assert_contains "$out" '"message"' "seed_log_entry has message"
assert_contains "$out" '"request_id"' "seed_log_entry has request_id"

# --seed 42 --count 3: 3 distinct records
out=$(bash "$SEED_HOME/seed.sh" log_entry --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_log_entry --seed 42 --count 3: 3 distinct"

ptyunit_test_begin "seed_error_log"

out=$(seed_error_log)
# Level in {ERROR, FATAL}
[[ "$out" =~ \"level\":\"(ERROR|FATAL)\" ]]
assert_exit_code $? 0 "seed_error_log level is ERROR or FATAL"

# error_code matches ^E[0-9]{4}$
[[ "$out" =~ \"error_code\":\"E[0-9][0-9][0-9][0-9]\" ]]
assert_exit_code $? 0 "seed_error_log error_code format"

# JSON output contains stack_trace key
assert_contains "$out" '"stack_trace"' "seed_error_log JSON has stack_trace"
# JSON stack_trace value uses \\n (JSON-escaped backslash-n) as frame separator
[[ "$out" == *'\\n'* ]]
assert_exit_code $? 0 "seed_error_log JSON stack_trace uses JSON-escaped \\\\n separator"

# CSV output does NOT contain stack_trace
out_csv=$(seed_error_log --format csv)
[[ "$out_csv" != *"stack_trace"* ]]
assert_exit_code $? 0 "seed_error_log --format csv omits stack_trace"

# SQL output does NOT contain stack_trace
out_sql=$(seed_error_log --format sql)
[[ "$out_sql" != *"stack_trace"* ]]
assert_exit_code $? 0 "seed_error_log --format sql omits stack_trace"

# KV output CONTAINS STACK_TRACE
out_kv=$(seed_error_log --format kv)
assert_contains "$out_kv" 'STACK_TRACE=' "seed_error_log --format kv has STACK_TRACE"
# KV stack_trace value uses literal \n (backslash-n) as frame separator
[[ "$out_kv" == *'\n'* ]]
assert_exit_code $? 0 "seed_error_log KV stack_trace uses literal backslash-n separator"

# --seed 42 --count 3: 3 distinct records
out=$(bash "$SEED_HOME/seed.sh" error_log --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_error_log --seed 42 --count 3: 3 distinct"

ptyunit_test_begin "seed_api_key"

# Default prefix sk_, 32 hex chars
key=$(seed_api_key)
[[ "$key" =~ ^sk_[0-9a-f]{32}$ ]]
assert_exit_code $? 0 "seed_api_key default format ^sk_[0-9a-f]{32}$"

# --prefix override
key=$(seed_api_key --prefix pk_)
[[ "$key" =~ ^pk_ ]]
assert_exit_code $? 0 "seed_api_key --prefix pk_ starts with pk_"

# Flag reset: after --prefix call, next call must use default sk_
seed_api_key --prefix custom_ > /dev/null
key2=$(seed_api_key)
[[ "$key2" =~ ^sk_ ]]
assert_exit_code $? 0 "seed_api_key prefix does not bleed across calls"

# --format rejected
seed_api_key --format json 2>/dev/null
assert_exit_code $? 2 "seed_api_key --format exits 2"

# --seed 42 --count 3: 3 distinct keys
out=$(bash "$SEED_HOME/seed.sh" api_key --seed 42 --count 3)
assert_eq "3" "$(printf '%s\n' "$out" | sort -u | wc -l | tr -d ' ')" \
    "seed_api_key --seed 42 --count 3: 3 distinct"

ptyunit_test_begin "data file: error_messages.txt"

count=$(wc -l < "$SEED_HOME/data/error_messages.txt" | tr -d ' ')
[[ "$count" -ge 20 ]]
assert_exit_code $? 0 "error_messages.txt has >= 20 entries"

ptyunit_test_summary
