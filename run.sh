#!/usr/bin/env bash
# run.sh — test runner for fissible/seed
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
