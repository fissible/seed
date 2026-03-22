#!/usr/bin/env bash
# src/devops.sh — DevOps/infrastructure generators

# ---------------------------------------------------------------------------
# seed_log_entry [--count N] [--format json|kv|csv|sql]
# Fields: timestamp, level, service, message, request_id
# ---------------------------------------------------------------------------
seed_log_entry() {
    _seed_parse_flags "$@" || return $?
    local levels
    levels=("DEBUG" "INFO" "WARN" "ERROR")
    local suffixes
    suffixes=("api" "service" "worker")
    local to_year
    to_year=$(_seed_today | cut -c1-4)
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local ts level adj noun suffix service message request_id
        _seed_random_datetime_v "$to_year"; ts="$_SEED_RESULT"
        _seed_random_int_v 0 3; level="${levels[$_SEED_RESULT]}"
        _seed_random_line_v adjectives; adj="$_SEED_RESULT"
        _seed_random_line_v nouns;      noun="$_SEED_RESULT"
        _seed_random_int_v 0 2;         suffix="${suffixes[$_SEED_RESULT]}"
        service="${adj}-${noun}-${suffix}"
        _seed_random_line_v lorem; message="$_SEED_RESULT"
        request_id=$(_seed_uuid_gen)
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" log_entries \
            timestamp "$ts" level "$level" service "$service" \
            message "$message" request_id "$request_id")
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
# seed_error_log [--count N] [--format json|kv|csv|sql]
# Fields: timestamp, level, service, error_code, message, request_id,
#         stack_trace (omitted in csv and sql formats)
#
# Stack trace: frames joined with literal \n (backslash+n). _seed_fmt_json
# will double the backslash to \\n in JSON output — this is correct behavior.
# ---------------------------------------------------------------------------
seed_error_log() {
    _seed_parse_flags "$@" || return $?
    local levels
    levels=("ERROR" "FATAL")
    local methods
    methods=("handle" "process" "execute" "validate" "parse" "dispatch" "run" "fetch" "connect")
    local suffixes
    suffixes=("api" "service" "worker")
    local to_year
    to_year=$(_seed_today | cut -c1-4)
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local ts level adj noun suffix service error_code message request_id
        _seed_random_datetime_v "$to_year"; ts="$_SEED_RESULT"
        _seed_random_int_v 0 1; level="${levels[$_SEED_RESULT]}"
        _seed_random_line_v adjectives; adj="$_SEED_RESULT"
        _seed_random_line_v nouns;      noun="$_SEED_RESULT"
        _seed_random_int_v 0 2;         suffix="${suffixes[$_SEED_RESULT]}"
        service="${adj}-${noun}-${suffix}"
        _seed_random_int_v 1000 9999; error_code="E${_SEED_RESULT}"
        _seed_random_line_v error_messages; message="$_SEED_RESULT"
        request_id=$(_seed_uuid_gen)

        # Build stack trace: 2-4 frames joined with literal \n (backslash+n)
        local num_frames stack_trace=""
        _seed_random_int_v 2 4; num_frames="$_SEED_RESULT"
        local f=0
        while [[ $f -lt $num_frames ]]; do
            local frame_noun frame_line frame_method frame
            _seed_random_line_v nouns;              frame_noun="$_SEED_RESULT"
            _seed_random_int_v 1 200;               frame_line="$_SEED_RESULT"
            _seed_random_int_v 0 $(( ${#methods[@]} - 1 )); frame_method="${methods[$_SEED_RESULT]}"
            frame="File ${frame_noun}.py, line ${frame_line}, in ${frame_method}"
            if [[ -n "$stack_trace" ]]; then
                stack_trace="${stack_trace}\n${frame}"
            else
                stack_trace="$frame"
            fi
            f=$((f+1))
        done

        # Conditionally include stack_trace (omit in csv and sql)
        # Use array to avoid word-splitting on spaces in the trace value
        local st_args
        st_args=()
        if [[ "$_SEED_FLAG_FORMAT" != "csv" && "$_SEED_FLAG_FORMAT" != "sql" ]]; then
            # stack_trace value contains spaces — array prevents word-splitting
            # \n separators will be doubled by _seed_fmt_json — do not pre-escape
            st_args[0]="stack_trace"
            st_args[1]="$stack_trace"
        fi

        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" error_logs \
            timestamp "$ts" level "$level" service "$service" \
            error_code "$error_code" message "$message" \
            request_id "$request_id" "${st_args[@]}")
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
# seed_api_key [--count N] [--prefix <str>] (rejects --format)
# Generates a prefixed 32-char lowercase hex key.
# Default prefix: sk_. Override: --prefix pk_live_
# Fully LCG-based — reproducible with --seed.
# ---------------------------------------------------------------------------
seed_api_key() {
    _seed_has_format_flag "$@" && { printf 'seed_api_key: --format not valid for scalar generators\n' >&2; return 2; }
    _seed_parse_flags "$@" || return $?
    local prefix="${_SEED_FLAG_PREFIX:-sk_}"
    local i=0
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local body="" k=0
        while [[ $k -lt 16 ]]; do
            _seed_random_int_v 0 255
            body="${body}$(printf '%02x' "$_SEED_RESULT")"
            k=$((k+1))
        done
        printf '%s%s\n' "$prefix" "$body"
        i=$((i+1))
    done
}
