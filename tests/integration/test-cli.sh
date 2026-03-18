#!/usr/bin/env bash
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}/assert.sh"

# Unknown generator → exit 1
bash "$SEED_HOME/seed.sh" notarealgen 2>/dev/null
assert_eq "1" "$?" "unknown generator exits 1"

# No args → exit 1
bash "$SEED_HOME/seed.sh" 2>/dev/null
assert_eq "1" "$?" "no args exits 1"

ptyunit_test_summary
