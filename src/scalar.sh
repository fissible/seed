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
    _seed_random_int_v 0 $((count - 1))
    local line_var="_SEED_DATA_${uname}_${_SEED_RESULT}"
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
# _seed_random_int_v <min> <max>
# Like _seed_random_int but writes to _SEED_RESULT; no stdout.
# Advances _SEED_RNG_STATE in the caller's process.
# ---------------------------------------------------------------------------
_seed_random_int_v() {
    local min="${1:-1}" max="${2:-100}"
    _seed_rng_init
    _SEED_RNG_STATE=$(( (1664525 * _SEED_RNG_STATE + 1013904223) % 4294967296 ))
    _SEED_RESULT=$(( _SEED_RNG_STATE % (max - min + 1) + min ))
}

# ---------------------------------------------------------------------------
# _seed_random_float_v <min> <max>
# Like _seed_random_float but writes to _SEED_RESULT; no stdout.
# ---------------------------------------------------------------------------
_seed_random_float_v() {
    local min="${1:-1.00}" max="${2:-999.99}"
    _seed_rng_init
    _SEED_RNG_STATE=$(( (1664525 * _SEED_RNG_STATE + 1013904223) % 4294967296 ))
    _SEED_RESULT=$(awk -v s="$_SEED_RNG_STATE" -v lo="$min" -v hi="$max" \
        'BEGIN { printf "%.2f", (s / 4294967296.0) * (hi - lo) + lo }')
}

# ---------------------------------------------------------------------------
# _seed_random_line_v <name>
# Like _seed_random_line but writes to _SEED_RESULT; no stdout.
# ---------------------------------------------------------------------------
_seed_random_line_v() {
    local name="$1"
    _seed_cache_data "$name" || { _SEED_RESULT=""; return 1; }
    local uname
    uname=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    local count_var="_SEED_DATA_${uname}_N"
    local count="${!count_var}"
    if [[ $count -eq 0 ]]; then _SEED_RESULT=""; return 1; fi
    _seed_random_int_v 0 $((count - 1))
    local idx="$_SEED_RESULT"
    local line_var="_SEED_DATA_${uname}_${idx}"
    _SEED_RESULT="${!line_var}"
}

# ---------------------------------------------------------------------------
# _seed_random_state_v
# Writes a random 2-letter US state abbreviation to _SEED_RESULT; no stdout.
# ---------------------------------------------------------------------------
_seed_random_state_v() {
    local -a states=()
    local s
    for s in $_SEED_US_STATES; do
        states[${#states[@]}]="$s"
    done
    _seed_random_int_v 0 $(( ${#states[@]} - 1 ))
    _SEED_RESULT="${states[$_SEED_RESULT]}"
}

# ---------------------------------------------------------------------------
# _seed_random_zip_v
# Writes a random 5-digit zip code to _SEED_RESULT; no stdout.
# ---------------------------------------------------------------------------
_seed_random_zip_v() {
    _seed_random_int_v 10000 99999
    _SEED_RESULT=$(printf '%05d' "$_SEED_RESULT")
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
    _seed_random_int_v 0 $(( ${#arr[@]} - 1 ))
    printf '%s\n' "${arr[$_SEED_RESULT]}"
}

# ---------------------------------------------------------------------------
# _seed_random_state
# Return a random 2-letter uppercase US state abbreviation.
# ---------------------------------------------------------------------------
_SEED_US_STATES="AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY"

_seed_random_state() {
    _seed_random_state_v
    printf '%s\n' "$_SEED_RESULT"
}

# ---------------------------------------------------------------------------
# _seed_random_zip
# Return a random 5-digit US zip code, zero-padded.
# ---------------------------------------------------------------------------
_seed_random_zip() {
    _seed_random_zip_v
    printf '%s\n' "$_SEED_RESULT"
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
        local fn ln
        _seed_random_line_v first_names; fn="$_SEED_RESULT"
        _seed_random_line_v last_names;  ln="$_SEED_RESULT"
        printf '%s %s\n' "$fn" "$ln"
        i=$((i+1))
    done
}

seed_first_name() {
    _seed_has_format_flag "$@" && { printf 'seed_first_name: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_line_v first_names
        printf '%s\n' "$_SEED_RESULT"
        i=$((i+1))
    done
}

seed_last_name() {
    _seed_has_format_flag "$@" && { printf 'seed_last_name: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_line_v last_names
        printf '%s\n' "$_SEED_RESULT"
        i=$((i+1))
    done
}

seed_email() {
    _seed_has_format_flag "$@" && { printf 'seed_email: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local fn ln fl ll domain
        _seed_random_line_v first_names; fn="$_SEED_RESULT"
        _seed_random_line_v last_names;  ln="$_SEED_RESULT"
        _seed_random_line_v domains;     domain="$_SEED_RESULT"
        _seed_str_lower_v "$fn"; fl="$_SEED_RESULT"
        _seed_str_lower_v "$ln"; ll="$_SEED_RESULT"
        printf '%s.%s@%s\n' "$fl" "$ll" "$domain"
        i=$((i+1))
    done
}

seed_phone() {
    _seed_has_format_flag "$@" && { printf 'seed_phone: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local a b c d
        _seed_random_int_v 2 9;       a="$_SEED_RESULT"
        _seed_random_int_v 10 99;     b="$_SEED_RESULT"
        _seed_random_int_v 100 999;   c="$_SEED_RESULT"
        _seed_random_int_v 1000 9999; d="$_SEED_RESULT"
        printf '%d%02d-%03d-%04d\n' "$a" "$b" "$c" "$d"
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
    _seed_has_format_flag "$@" && { printf 'seed_date: --format not valid for scalar generators\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local from="${_SEED_FLAG_FROM:-2000-01-01}"
    local to="${_SEED_FLAG_TO:-$(_seed_today)}"
    local from_year="${from:0:4}" to_year="${to:0:4}"
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local year month day max_day
        _seed_random_int_v "$from_year" "$to_year"; year="$_SEED_RESULT"
        _seed_random_int_v 1 12; month="$_SEED_RESULT"
        case "$month" in
            1|3|5|7|8|10|12) max_day=31 ;;
            4|6|9|11)         max_day=30 ;;
            2)
                if (( year % 400 == 0 || (year % 4 == 0 && year % 100 != 0) )); then
                    max_day=29
                else
                    max_day=28
                fi
                ;;
        esac
        _seed_random_int_v 1 "$max_day"; day="$_SEED_RESULT"
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
        _seed_random_int_v "$min" "$max"
        printf '%s\n' "$_SEED_RESULT"
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
            _seed_random_line_v lorem; sentence="$_SEED_RESULT"
            printf '%s\n' "$sentence" | tr ' ' '\n' | head -n "$_SEED_FLAG_WORDS" | tr '\n' ' ' | sed 's/ $//'
            printf '\n'
        elif [[ -n "$_SEED_FLAG_SENTENCES" ]]; then
            local s=0
            while [[ $s -lt $_SEED_FLAG_SENTENCES ]]; do
                _seed_random_line_v lorem
                printf '%s\n' "$_SEED_RESULT"
                s=$((s+1))
            done
        else
            _seed_random_line_v lorem
            printf '%s\n' "$_SEED_RESULT"
        fi
        i=$((i+1))
    done
}

seed_ip() {
    _seed_has_format_flag "$@" && { printf 'seed_ip: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local o1 o2 o3 o4
        _seed_random_int_v 1 254; o1="$_SEED_RESULT"
        _seed_random_int_v 1 254; o2="$_SEED_RESULT"
        _seed_random_int_v 1 254; o3="$_SEED_RESULT"
        _seed_random_int_v 1 254; o4="$_SEED_RESULT"
        printf '%d.%d.%d.%d\n' "$o1" "$o2" "$o3" "$o4"
        i=$((i+1))
    done
}

seed_url() {
    _seed_has_format_flag "$@" && { printf 'seed_url: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local dom noun
        _seed_random_line_v domains; dom="$_SEED_RESULT"
        _seed_random_line_v nouns;   noun="$_SEED_RESULT"
        printf 'https://%s/%s\n' "$dom" "$noun"
        i=$((i+1))
    done
}

seed_bool() {
    _seed_has_format_flag "$@" && { printf 'seed_bool: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_int_v 0 1
        if [[ "$_SEED_RESULT" -eq 0 ]]; then printf 'true\n'; else printf 'false\n'; fi
        i=$((i+1))
    done
}

# ---------------------------------------------------------------------------
# Shared port list for seed_port and seed_db_credentials.
# Space-separated string — build array with loop (bash 3.2 compatible).
# ---------------------------------------------------------------------------
_SEED_DB_PORTS="5432 3306 6379 27017 8080 8000 3000 9200 5672 9042 1433 1521 26257 8086 11211"

seed_host() {
    _seed_has_format_flag "$@" && { printf 'seed_host: --format not valid for scalar generators\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_line_v domains
        printf '%s\n' "$_SEED_RESULT"
        i=$((i+1))
    done
}

seed_port() {
    _seed_has_format_flag "$@" && { printf 'seed_port: --format not valid for scalar generators\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local -a ports=()
    local p
    for p in $_SEED_DB_PORTS; do ports[${#ports[@]}]="$p"; done
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_int_v 0 $(( ${#ports[@]} - 1 ))
        printf '%s\n' "${ports[$_SEED_RESULT]}"
        i=$((i+1))
    done
}

seed_password() {
    _seed_has_format_flag "$@" && { printf 'seed_password: --format not valid for scalar generators\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local length="${_SEED_FLAG_LENGTH:-10}"
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local pwd="" j=0
        while [[ $j -lt $length ]]; do
            _seed_random_int_v 0 61
            pwd="${pwd}${chars:$_SEED_RESULT:1}"
            j=$((j+1))
        done
        printf '%s\n' "$pwd"
        i=$((i+1))
    done
}
