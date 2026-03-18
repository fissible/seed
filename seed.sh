#!/usr/bin/env bash
# fissible/seed — bash fake data generator
# Usage (CLI):   bash seed.sh <generator> [flags]
# Usage (lib):   source seed.sh; seed_name

SEED_HOME="${SEED_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

source "$SEED_HOME/src/scalar.sh"
source "$SEED_HOME/src/record.sh"
source "$SEED_HOME/src/ecommerce.sh"
source "$SEED_HOME/src/crm.sh"
source "$SEED_HOME/src/tui.sh"

_seed_parse_flags() {
    _SEED_FLAG_COUNT=1
    _SEED_FLAG_FORMAT="json"
    _SEED_FLAG_MIN=""
    _SEED_FLAG_MAX=""
    _SEED_FLAG_FROM=""
    _SEED_FLAG_TO=""
    _SEED_FLAG_WORDS=""
    _SEED_FLAG_SENTENCES=""
    _SEED_FLAG_ITEMS=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --count)     _SEED_FLAG_COUNT="$2";     shift 2 ;;
            --format)    _SEED_FLAG_FORMAT="$2";    shift 2 ;;
            --min)       _SEED_FLAG_MIN="$2";       shift 2 ;;
            --max)       _SEED_FLAG_MAX="$2";       shift 2 ;;
            --from)      _SEED_FLAG_FROM="$2";      shift 2 ;;
            --to)        _SEED_FLAG_TO="$2";        shift 2 ;;
            --words)     _SEED_FLAG_WORDS="$2";     shift 2 ;;
            --sentences) _SEED_FLAG_SENTENCES="$2"; shift 2 ;;
            --items)     _SEED_FLAG_ITEMS="$2";     shift 2 ;;
            --*) printf 'Unknown flag: %s\n' "$1" >&2; return 2 ;;
            *)   printf 'Unexpected argument: %s\n' "$1" >&2; return 2 ;;
        esac
    done
}

_seed_has_format_flag() {
    local arg
    for arg in "$@"; do
        [[ "$arg" == "--format" ]] && return 0
    done
    return 1
}

_seed_cli() {
    if [[ $# -eq 0 ]]; then
        printf 'Usage: seed.sh <generator> [flags]\n' >&2
        return 1
    fi

    local gen="$1"; shift

    if declare -f "seed_${gen}" > /dev/null 2>&1; then
        "seed_${gen}" "$@"
        return $?
    else
        printf 'Unknown generator: %s\n' "$gen" >&2
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _seed_cli "$@"
fi
