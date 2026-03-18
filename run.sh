#!/usr/bin/env bash
# run.sh — test runner for fissible/seed
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PTYUNIT_HOME="${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}"

if [[ ! -f "$PTYUNIT_HOME/assert.sh" ]]; then
    echo "ERROR: ptyunit not found at $PTYUNIT_HOME" >&2
    echo "Set PTYUNIT_HOME or ensure ptyunit is at ~/lib/fissible/ptyunit" >&2
    exit 1
fi

pass=0 fail=0

run_suite() {
    local file="$1"
    echo "--- $file"
    if bash "$file"; then
        pass=$((pass+1))
    else
        fail=$((fail+1))
    fi
}

for f in "$SEED_HOME/tests/unit"/test-*.sh; do
    [[ -f "$f" ]] && run_suite "$f"
done

for f in "$SEED_HOME/tests/integration"/test-*.sh; do
    [[ -f "$f" ]] && run_suite "$f"
done

echo ""
echo "Suites passed: $pass  failed: $fail"
[[ $fail -eq 0 ]]
