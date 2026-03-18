#!/usr/bin/env bash
# Run test suite against multiple bash versions via Docker
SEED_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PTYUNIT_HOME="${PTYUNIT_HOME:-$SEED_HOME/../ptyunit}"

pass=0 fail=0

run_image() {
    local tag="$1" dockerfile="$2"
    echo "=== Building $tag ==="
    docker build -f "$SEED_HOME/docker/$dockerfile" \
        -t "fissible-seed-$tag" "$SEED_HOME" \
        --build-arg PTYUNIT_SRC="$PTYUNIT_HOME" 2>&1 | tail -5

    echo "=== Running $tag ==="
    if docker run --rm \
        -v "$PTYUNIT_HOME:/ptyunit:ro" \
        "fissible-seed-$tag" \
        bash /seed/run.sh; then
        echo "PASS: $tag"
        pass=$((pass+1))
    else
        echo "FAIL: $tag"
        fail=$((fail+1))
    fi
}

run_image "bash44" "Dockerfile.bash44"
run_image "bash5"  "Dockerfile.bash5"

echo ""
echo "Matrix: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
