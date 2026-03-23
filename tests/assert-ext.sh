#!/usr/bin/env bash
# tests/assert-ext.sh — extra assert helpers for seed tests
# Source AFTER ptyunit/assert.sh:
#   source "$SEED_HOME/tests/vendor/ptyunit/assert.sh"
#   source "$SEED_HOME/tests/assert-ext.sh"

# Assert an exit code equals expected.
# Usage: assert_exit_code <actual> <expected> [message]
assert_exit_code() {
    local actual="$1" expected="$2" msg="${3:-exit code}"
    assert_eq "$expected" "$actual" "$msg"
}

# Assert a string is non-empty.
# Usage: assert_not_empty <value> [message]
assert_not_empty() {
    local value="$1" msg="${2:-value}"
    if [[ -n "$value" ]]; then
        (( _PTYUNIT_TEST_PASS++ )) || true
    else
        (( _PTYUNIT_TEST_FAIL++ )) || true
        printf 'FAIL — %s: expected non-empty string\n' "$msg"
    fi
}
