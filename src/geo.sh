#!/usr/bin/env bash
# src/geo.sh — geographic generators

# ---------------------------------------------------------------------------
# seed_coordinates [--count N] [--format json|kv|csv|sql]
# Generates worldwide latitude/longitude pairs. lat/lng have 4 decimal places.
# Uses inline awk with %.4f (not _seed_random_float_v which is 2 decimal places).
# _SEED_RNG_STATE is advanced in the parent process; awk only formats.
# ---------------------------------------------------------------------------
seed_coordinates() {
    _seed_parse_flags "$@" || return $?
    _seed_rng_init
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local lat lng
        _SEED_RNG_STATE=$(( (1664525 * _SEED_RNG_STATE + 1013904223) % 4294967296 ))
        lat=$(awk -v s="$_SEED_RNG_STATE" 'BEGIN { printf "%.4f", (s / 4294967296.0) * 180.0 - 90.0 }')
        _SEED_RNG_STATE=$(( (1664525 * _SEED_RNG_STATE + 1013904223) % 4294967296 ))
        lng=$(awk -v s="$_SEED_RNG_STATE" 'BEGIN { printf "%.4f", (s / 4294967296.0) * 360.0 - 180.0 }')
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" coordinates lat "$lat" lng "$lng")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else
            printf '%s\n' "$rec"
        fi
        i=$((i+1))
    done
}

# ---------------------------------------------------------------------------
# seed_country [--count N] [--format json|kv|csv|sql]
# Backed by data/countries.txt — pipe-delimited: code|name|region
# ---------------------------------------------------------------------------
seed_country() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local line code rest name region
        _seed_random_line_v countries; line="$_SEED_RESULT"
        code="${line%%|*}"            # everything before first |
        rest="${line#*|}"             # everything after first |
        name="${rest%%|*}"            # everything before second | (in rest)
        region="${rest#*|}"           # everything after second | (in rest)
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" countries \
            code "$code" name "$name" region "$region")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else
            printf '%s\n' "$rec"
        fi
        i=$((i+1))
    done
}
