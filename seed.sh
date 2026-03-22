#!/usr/bin/env bash
# fissible/seed — bash fake data generator
# Usage (CLI):   bash seed.sh <generator> [flags]
# Usage (lib):   source seed.sh; seed_name

SEED_HOME="${SEED_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

source "$SEED_HOME/src/str.sh"
source "$SEED_HOME/src/scalar.sh"
source "$SEED_HOME/src/record.sh"
source "$SEED_HOME/src/ecommerce.sh"
source "$SEED_HOME/src/crm.sh"
source "$SEED_HOME/src/tui.sh"

# ---------------------------------------------------------------------------
# Internal: flag parser
# Populates globals: _SEED_FLAG_COUNT _SEED_FLAG_FORMAT _SEED_FLAG_MIN
#   _SEED_FLAG_MAX _SEED_FLAG_FROM _SEED_FLAG_TO _SEED_FLAG_WORDS
#   _SEED_FLAG_SENTENCES _SEED_FLAG_ITEMS; conditionally sets _SEED_RNG_STATE
# Returns exit code 2 on unknown/malformed flags.
# ---------------------------------------------------------------------------
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
            --count)
                if [[ $# -lt 2 ]]; then
                    printf 'Flag --count requires a value\n' >&2
                    return 2
                fi
                _SEED_FLAG_COUNT="$2"; shift 2 ;;
            --format)
                if [[ $# -lt 2 ]]; then
                    printf 'Flag --format requires a value\n' >&2
                    return 2
                fi
                _SEED_FLAG_FORMAT="$2"; shift 2 ;;
            --min)
                if [[ $# -lt 2 ]]; then
                    printf 'Flag --min requires a value\n' >&2
                    return 2
                fi
                _SEED_FLAG_MIN="$2"; shift 2 ;;
            --max)
                if [[ $# -lt 2 ]]; then
                    printf 'Flag --max requires a value\n' >&2
                    return 2
                fi
                _SEED_FLAG_MAX="$2"; shift 2 ;;
            --from)
                if [[ $# -lt 2 ]]; then
                    printf 'Flag --from requires a value\n' >&2
                    return 2
                fi
                _SEED_FLAG_FROM="$2"; shift 2 ;;
            --to)
                if [[ $# -lt 2 ]]; then
                    printf 'Flag --to requires a value\n' >&2
                    return 2
                fi
                _SEED_FLAG_TO="$2"; shift 2 ;;
            --words)
                if [[ $# -lt 2 ]]; then
                    printf 'Flag --words requires a value\n' >&2
                    return 2
                fi
                _SEED_FLAG_WORDS="$2"; shift 2 ;;
            --sentences)
                if [[ $# -lt 2 ]]; then
                    printf 'Flag --sentences requires a value\n' >&2
                    return 2
                fi
                _SEED_FLAG_SENTENCES="$2"; shift 2 ;;
            --items)
                if [[ $# -lt 2 ]]; then
                    printf 'Flag --items requires a value\n' >&2
                    return 2
                fi
                _SEED_FLAG_ITEMS="$2"; shift 2 ;;
            --seed)
                if [[ $# -lt 2 ]]; then
                    printf 'Flag --seed requires a value\n' >&2
                    return 2
                fi
                _SEED_RNG_STATE="$2"; shift 2 ;;
            --*) printf 'Unknown flag: %s\n' "$1" >&2; return 2 ;;
            *)   printf 'Unexpected argument: %s\n' "$1" >&2; return 2 ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Internal: check if --format was explicitly passed in raw args
# Used by scalar generators to reject the flag before calling _seed_parse_flags.
# ---------------------------------------------------------------------------
_seed_has_format_flag() {
    local arg
    for arg in "$@"; do
        [[ "$arg" == "--format" ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# CLI entrypoint: called when seed.sh is executed directly.
# Generators are responsible for calling _seed_parse_flags on their own args.
# ---------------------------------------------------------------------------
_seed_cli() {
    if [[ $# -eq 0 ]]; then
        printf 'Usage: seed.sh <generator> [flags]\n' >&2
        return 1
    fi

    local gen="$1"; shift

    if declare -f "seed_${gen}" > /dev/null 2>&1; then
        "seed_${gen}" "$@"
    else
        printf 'Unknown generator: %s\n' "$gen" >&2
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _seed_cli "$@"
fi
