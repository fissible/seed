#!/usr/bin/env bash
# src/scalar.sh — shared helper functions for fissible/seed
# Bash 3.2 compatible: no mapfile/readarray, no +=, no declare -A

# ---------------------------------------------------------------------------
# _seed_cache_data <name>
# Load $SEED_HOME/data/<name>.txt into globals on first call; no-op after that.
# Globals: _SEED_DATA_<UPPER_NAME>_N  (count)
#          _SEED_DATA_<UPPER_NAME>_<i> (line at index i)
# ---------------------------------------------------------------------------
_seed_cache_data() {
    local name="$1"
    local uname
    uname=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    local count_var="_SEED_DATA_${uname}_N"
    [[ -n "${!count_var}" ]] && return 0   # already cached

    local file="$SEED_HOME/data/${name}.txt"
    if [[ ! -f "$file" ]]; then
        printf 'Data file not found: %s\n' "$file" >&2
        return 1
    fi

    local count=0
    while IFS= read -r line; do
        printf -v "_SEED_DATA_${uname}_${count}" '%s' "$line"
        count=$((count + 1))
    done < "$file"
    printf -v "$count_var" '%d' "$count"
}

# ---------------------------------------------------------------------------
# _seed_random_line <name>
# Return a single random line from $SEED_HOME/data/<name>.txt.
# File is loaded into globals on first call; subsequent calls use the cache.
# ---------------------------------------------------------------------------
_seed_random_line() {
    local name="$1"
    _seed_cache_data "$name" || return 1

    local uname
    uname=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    local count_var="_SEED_DATA_${uname}_N"
    local count="${!count_var}"
    [[ $count -eq 0 ]] && return 1

    local idx
    idx=$(_seed_random_int 0 $((count - 1)))
    local line_var="_SEED_DATA_${uname}_${idx}"
    printf '%s\n' "${!line_var}"
}

# ---------------------------------------------------------------------------
# Global LCG RNG state. Seeded lazily on first use, or explicitly via --seed.
# ---------------------------------------------------------------------------
_SEED_RNG_STATE=""

# _seed_rng_init
# Idempotent. Seeds _SEED_RNG_STATE from /dev/urandom (or PID+RANDOM fallback).
# Does nothing if state is already set.
_seed_rng_init() {
    [[ -n "$_SEED_RNG_STATE" ]] && return
    if [[ -r /dev/urandom ]]; then
        _SEED_RNG_STATE=$(od -An -N4 -tu4 /dev/urandom | tr -d ' \n')
    else
        _SEED_RNG_STATE=$(awk -v p="$$" -v r1="$RANDOM" -v r2="$RANDOM" \
            'BEGIN { printf "%d", (p * 1000003 + r1 * 65537 + r2) % 4294967296 }')
    fi
}

# ---------------------------------------------------------------------------
# _seed_random_int <min> <max>
# Print a random integer in [min, max] inclusive.
# Advances global LCG state; no per-call seeding.
# ---------------------------------------------------------------------------
_seed_random_int() {
    local min="${1:-1}" max="${2:-100}"
    _seed_rng_init
    _SEED_RNG_STATE=$(( (1664525 * _SEED_RNG_STATE + 1013904223) % 4294967296 ))
    printf '%d\n' $(( _SEED_RNG_STATE % (max - min + 1) + min ))
}

# ---------------------------------------------------------------------------
# _seed_random_float <min> <max>
# Print a random float with 2 decimal places in [min, max].
# ---------------------------------------------------------------------------
_seed_random_float() {
    local min="${1:-1.00}" max="${2:-999.99}"
    _seed_rng_init
    _SEED_RNG_STATE=$(( (1664525 * _SEED_RNG_STATE + 1013904223) % 4294967296 ))
    awk -v s="$_SEED_RNG_STATE" -v lo="$min" -v hi="$max" \
        'BEGIN { printf "%.2f", (s / 4294967296.0) * (hi - lo) + lo }'
}

# ---------------------------------------------------------------------------
# _seed_today
# Print today's date as YYYY-MM-DD (BSD and GNU date compatible).
# ---------------------------------------------------------------------------
_seed_today() {
    date +%Y-%m-%d
}

# ---------------------------------------------------------------------------
# _seed_date_subtract_years <YYYY-MM-DD> <years>
# Subtract N years from a date using bash arithmetic only (no date -d).
# ---------------------------------------------------------------------------
_seed_date_subtract_years() {
    local d="$1" years="$2"
    local year="${d:0:4}" rest="${d:4}"
    year=$((year - years))
    printf '%04d%s\n' "$year" "$rest"
}

# ---------------------------------------------------------------------------
# _seed_json_escape <string>
# Escape backslashes and double-quotes for embedding in JSON strings.
# ---------------------------------------------------------------------------
_seed_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

# ---------------------------------------------------------------------------
# _seed_uuid_gen
# Generate a UUID v4.
# Primary: /dev/urandom via od; Fallback: uuidgen; otherwise exit 1.
# ---------------------------------------------------------------------------
_seed_uuid_gen() {
    if [[ -r /dev/urandom ]]; then
        local hex
        hex=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
        local p1="${hex:0:8}"
        local p2="${hex:8:4}"
        local p3="4${hex:13:3}"
        local variant
        variant=$(printf '%x' $(( (0x${hex:16:2} & 0x3f) | 0x80 )))
        local p4="${variant}${hex:18:2}"
        local p5="${hex:20:12}"
        printf '%s-%s-%s-%s-%s\n' "$p1" "$p2" "$p3" "$p4" "$p5"
    elif command -v uuidgen > /dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        printf 'ERROR: cannot generate UUID\n' >&2
        return 1
    fi
}

# ---------------------------------------------------------------------------
# _seed_random_elem <elem1> [elem2 ...]
# Return one random element from the positional arguments.
# ---------------------------------------------------------------------------
_seed_random_elem() {
    local -a arr=("$@")
    local idx
    idx=$(_seed_random_int 0 $(( ${#arr[@]} - 1 )))
    printf '%s\n' "${arr[$idx]}"
}

# ---------------------------------------------------------------------------
# _seed_random_state
# Return a random 2-letter uppercase US state abbreviation.
# ---------------------------------------------------------------------------
_SEED_US_STATES="AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY"

_seed_random_state() {
    local -a states=()
    local s
    for s in $_SEED_US_STATES; do
        states[${#states[@]}]="$s"
    done
    local idx
    idx=$(_seed_random_int 0 $(( ${#states[@]} - 1 )))
    printf '%s\n' "${states[$idx]}"
}

# ---------------------------------------------------------------------------
# _seed_random_zip
# Return a random 5-digit US zip code, zero-padded.
# ---------------------------------------------------------------------------
_seed_random_zip() {
    printf '%05d\n' "$(_seed_random_int 10000 99999)"
}

# ---------------------------------------------------------------------------
# _seed_is_numeric <value>
# Returns 0 if value is a valid integer or float, 1 otherwise.
# ---------------------------------------------------------------------------
_seed_is_numeric() {
    [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]
}

# ---------------------------------------------------------------------------
# Scalar generators
# Each accepts --count N (default 1) and rejects --format.
# ---------------------------------------------------------------------------

seed_name() {
    _seed_has_format_flag "$@" && { printf 'seed_name: --format not valid for scalar generators\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        printf '%s %s\n' "$(_seed_random_line first_names)" "$(_seed_random_line last_names)"
        i=$((i+1))
    done
}

seed_first_name() {
    _seed_has_format_flag "$@" && { printf 'seed_first_name: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_line first_names
        i=$((i+1))
    done
}

seed_last_name() {
    _seed_has_format_flag "$@" && { printf 'seed_last_name: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_line last_names
        i=$((i+1))
    done
}

seed_email() {
    _seed_has_format_flag "$@" && { printf 'seed_email: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local first last domain
        first=$(seed_first_name | tr '[:upper:]' '[:lower:]')
        last=$(seed_last_name | tr '[:upper:]' '[:lower:]')
        domain=$(_seed_random_line domains)
        printf '%s.%s@%s\n' "$first" "$last" "$domain"
        i=$((i+1))
    done
}

seed_phone() {
    _seed_has_format_flag "$@" && { printf 'seed_phone: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        printf '%d%02d-%03d-%04d\n' \
            "$(_seed_random_int 2 9)" \
            "$(_seed_random_int 10 99)" \
            "$(_seed_random_int 100 999)" \
            "$(_seed_random_int 1000 9999)"
        i=$((i+1))
    done
}

seed_uuid() {
    _seed_has_format_flag "$@" && { printf 'seed_uuid: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_uuid_gen || return $?
        i=$((i+1))
    done
}

seed_date() {
    _seed_has_format_flag "$@" && { printf 'seed_date: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local from="${_SEED_FLAG_FROM:-2000-01-01}"
    local to="${_SEED_FLAG_TO:-$(_seed_today)}"
    local from_year="${from:0:4}" to_year="${to:0:4}"
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local year month day
        year=$(_seed_random_int "$from_year" "$to_year")
        month=$(_seed_random_int 1 12)
        day=$(_seed_random_int 1 28)
        printf '%04d-%02d-%02d\n' "$year" "$month" "$day"
        i=$((i+1))
    done
}

seed_number() {
    _seed_has_format_flag "$@" && { printf 'seed_number: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local min="${_SEED_FLAG_MIN:-1}" max="${_SEED_FLAG_MAX:-100}"
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_int "$min" "$max"
        i=$((i+1))
    done
}

seed_lorem() {
    _seed_has_format_flag "$@" && { printf 'seed_lorem: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    # --words and --sentences are mutually exclusive
    if [[ -n "$_SEED_FLAG_WORDS" && -n "$_SEED_FLAG_SENTENCES" ]]; then
        printf 'seed_lorem: --words and --sentences are mutually exclusive\n' >&2
        return 2
    fi
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        if [[ -n "$_SEED_FLAG_WORDS" ]]; then
            local sentence
            sentence=$(_seed_random_line lorem)
            printf '%s\n' "$sentence" | tr ' ' '\n' | head -n "$_SEED_FLAG_WORDS" | tr '\n' ' ' | sed 's/ $//'
            printf '\n'
        elif [[ -n "$_SEED_FLAG_SENTENCES" ]]; then
            local s=0
            while [[ $s -lt $_SEED_FLAG_SENTENCES ]]; do
                _seed_random_line lorem
                s=$((s+1))
            done
        else
            _seed_random_line lorem
        fi
        i=$((i+1))
    done
}

seed_ip() {
    _seed_has_format_flag "$@" && { printf 'seed_ip: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        printf '%d.%d.%d.%d\n' \
            "$(_seed_random_int 1 254)" "$(_seed_random_int 1 254)" \
            "$(_seed_random_int 1 254)" "$(_seed_random_int 1 254)"
        i=$((i+1))
    done
}

seed_url() {
    _seed_has_format_flag "$@" && { printf 'seed_url: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        printf 'https://%s/%s\n' "$(_seed_random_line domains)" "$(_seed_random_line nouns)"
        i=$((i+1))
    done
}

seed_bool() {
    _seed_has_format_flag "$@" && { printf 'seed_bool: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        if [[ $(( RANDOM % 2 )) -eq 0 ]]; then printf 'true\n'; else printf 'false\n'; fi
        i=$((i+1))
    done
}
