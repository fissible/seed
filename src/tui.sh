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
        adj=$(_seed_random_line adjectives)
        noun=$(_seed_random_line nouns)
        year=$(_seed_random_int 2019 2025)
        ext="${extensions[$(_seed_random_int 0 $((${#extensions[@]} - 1)))]}"
        name="${adj}-${noun}-${year}.${ext}"
        # Enforce max 40 chars
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
        depth=$(_seed_random_int 2 4)
        path=""
        d=0
        while [[ $d -lt $depth ]]; do
            [[ $d -gt 0 ]] && path="${path}/"
            path="${path}$(_seed_random_line nouns)"
            d=$((d+1))
        done
        # Enforce max 60 chars
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
        adj=$(_seed_random_line adjectives)
        noun=$(_seed_random_line nouns)
        # Title case both words
        label="$(_seed_title_case "$adj") $(_seed_title_case "$noun")"
        # Enforce max 30 chars
        if [[ ${#label} -gt 30 ]]; then
            label="${label:0:30}"
        fi
        printf '%s\n' "$label"
        i=$((i+1))
    done
}
