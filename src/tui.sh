#!/usr/bin/env bash
# src/tui.sh — TUI helper generators

_seed_title_case() {
    local word="$1"
    printf '%s%s' "$(printf '%s' "${word:0:1}" | tr '[:lower:]' '[:upper:]')" "${word:1}"
}

seed_filenames() {
    _seed_has_format_flag "$@" && { printf 'seed_filenames: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    # Default count is 10 for TUI generators (not 1)
    # Detect whether --count was explicitly passed
    local count=10
    local a
    for a in "$@"; do
        if [[ "$a" == "--count" ]]; then
            count="$_SEED_FLAG_COUNT"
            break
        fi
    done
    local extensions
    extensions=("txt" "csv" "pdf" "log" "json" "sh")
    local i=0
    while [[ $i -lt $count ]]; do
        local adj noun year ext name
        _seed_random_line_v adjectives; adj="$_SEED_RESULT"
        _seed_random_line_v nouns;      noun="$_SEED_RESULT"
        _seed_random_int_v 2019 2025;   year="$_SEED_RESULT"
        _seed_random_int_v 0 $(( ${#extensions[@]} - 1 ))
        ext="${extensions[$_SEED_RESULT]}"
        name="${adj}-${noun}-${year}.${ext}"
        if [[ ${#name} -gt 40 ]]; then
            name="${adj:0:8}-${noun:0:8}-${year}.${ext}"
        fi
        printf '%s\n' "$name"
        i=$((i+1))
    done
}

seed_dirtree() {
    _seed_has_format_flag "$@" && { printf 'seed_dirtree: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    # Default count is 10 for TUI generators
    local count=10
    local a
    for a in "$@"; do
        if [[ "$a" == "--count" ]]; then
            count="$_SEED_FLAG_COUNT"
            break
        fi
    done
    local i=0
    while [[ $i -lt $count ]]; do
        local depth path d
        _seed_random_int_v 2 4; depth="$_SEED_RESULT"
        path=""
        d=0
        while [[ $d -lt $depth ]]; do
            [[ $d -gt 0 ]] && path="${path}/"
            _seed_random_line_v nouns
            path="${path}$_SEED_RESULT"
            d=$((d+1))
        done
        if [[ ${#path} -gt 60 ]]; then
            path="${path:0:60}"
        fi
        printf '%s\n' "$path"
        i=$((i+1))
    done
}

seed_menu_items() {
    _seed_has_format_flag "$@" && { printf 'seed_menu_items: --format not valid\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    # Default count is 10 for TUI generators
    local count=10
    local a
    for a in "$@"; do
        if [[ "$a" == "--count" ]]; then
            count="$_SEED_FLAG_COUNT"
            break
        fi
    done
    local i=0
    while [[ $i -lt $count ]]; do
        local adj noun label
        _seed_random_line_v adjectives; adj="$_SEED_RESULT"
        _seed_random_line_v nouns;      noun="$_SEED_RESULT"
        label="$(_seed_title_case "$adj") $(_seed_title_case "$noun")"
        if [[ ${#label} -gt 30 ]]; then
            label="${label:0:30}"
        fi
        printf '%s\n' "$label"
        i=$((i+1))
    done
}
