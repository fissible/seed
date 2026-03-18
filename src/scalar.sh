#!/usr/bin/env bash
# src/scalar.sh — shared helper functions for fissible/seed
# Bash 3.2 compatible: no mapfile/readarray, no +=, no declare -A

# ---------------------------------------------------------------------------
# _seed_load_data <name>
# Print every line from $SEED_HOME/data/<name>.txt, one line per output line.
# ---------------------------------------------------------------------------
_seed_load_data() {
    local file="$SEED_HOME/data/$1.txt"
    if [[ ! -f "$file" ]]; then
        printf 'Data file not found: %s\n' "$file" >&2
        return 1
    fi
    while IFS= read -r line; do
        printf '%s\n' "$line"
    done < "$file"
}

# ---------------------------------------------------------------------------
# _seed_random_line <name>
# Return a single random line from $SEED_HOME/data/<name>.txt.
# ---------------------------------------------------------------------------
_seed_random_line() {
    local -a arr=()
    while IFS= read -r line; do
        arr[${#arr[@]}]="$line"
    done < <(_seed_load_data "$1")
    local count=${#arr[@]}
    [[ $count -eq 0 ]] && return 1
    local idx
    idx=$(_seed_random_int 0 $((count - 1)))
    printf '%s\n' "${arr[$idx]}"
}

# ---------------------------------------------------------------------------
# _seed_random_int <min> <max>
# Print a random integer in [min, max] inclusive.
# Uses awk for portability across bash versions.
# ---------------------------------------------------------------------------
_seed_random_int() {
    local min="${1:-1}" max="${2:-100}"
    awk "BEGIN { srand(); printf \"%d\", int(rand() * ($max - $min + 1)) + $min }"
}

# ---------------------------------------------------------------------------
# _seed_random_float <min> <max>
# Print a random float with 2 decimal places in [min, max].
# ---------------------------------------------------------------------------
_seed_random_float() {
    local min="${1:-1.00}" max="${2:-999.99}"
    awk "BEGIN { srand(); printf \"%.2f\", rand() * ($max - $min) + $min }"
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
