#!/usr/bin/env bash
# src/record.sh — format helpers and core record generators

# ---------------------------------------------------------------------------
# _seed_emit_record <format> <table> <field1> <val1> [<field2> <val2> ...]
#
# Emits a single record in the requested format.
# Uses globals _SEED_REC_FIELDS, _SEED_REC_VALS, _SEED_REC_TABLE (set internally).
# ---------------------------------------------------------------------------
_seed_emit_record() {
    local fmt="$1" table="$2"; shift 2
    _SEED_REC_FIELDS=()
    _SEED_REC_VALS=()
    while [[ $# -ge 2 ]]; do
        _SEED_REC_FIELDS[${#_SEED_REC_FIELDS[@]}]="$1"
        _SEED_REC_VALS[${#_SEED_REC_VALS[@]}]="$2"
        shift 2
    done
    _SEED_REC_TABLE="$table"
    case "$fmt" in
        json) _seed_fmt_json ;;
        kv)   _seed_fmt_kv ;;
        csv)  _seed_fmt_csv ;;
        sql)  _seed_fmt_sql ;;
        *) printf 'Unknown format: %s\n' "$fmt" >&2; return 2 ;;
    esac
}

_seed_fmt_json() {
    local out="{" i=0
    while [[ $i -lt ${#_SEED_REC_FIELDS[@]} ]]; do
        [[ $i -gt 0 ]] && out="${out},"
        local key="${_SEED_REC_FIELDS[$i]}"
        local val="${_SEED_REC_VALS[$i]}"
        local escaped
        escaped=$(_seed_json_escape "$val")
        if _seed_is_numeric "$val"; then
            out="${out}\"${key}\":${val}"
        else
            out="${out}\"${key}\":\"${escaped}\""
        fi
        i=$((i+1))
    done
    out="${out}}"
    printf '%s\n' "$out"
}

_seed_fmt_kv() {
    local i=0
    while [[ $i -lt ${#_SEED_REC_FIELDS[@]} ]]; do
        local key
        key=$(printf '%s' "${_SEED_REC_FIELDS[$i]}" | tr '[:lower:]' '[:upper:]')
        printf '%s="%s"\n' "$key" "${_SEED_REC_VALS[$i]}"
        i=$((i+1))
    done
}

_seed_fmt_csv() {
    # Emits: header row THEN data row (always, even for --count 1)
    local header="" data="" i=0
    while [[ $i -lt ${#_SEED_REC_FIELDS[@]} ]]; do
        [[ $i -gt 0 ]] && header="${header}," && data="${data},"
        header="${header}${_SEED_REC_FIELDS[$i]}"
        data="${data}\"${_SEED_REC_VALS[$i]}\""
        i=$((i+1))
    done
    printf '%s\n%s\n' "$header" "$data"
}

_seed_fmt_sql() {
    local cols="" vals="" i=0
    while [[ $i -lt ${#_SEED_REC_FIELDS[@]} ]]; do
        [[ $i -gt 0 ]] && cols="${cols}, " && vals="${vals}, "
        cols="${cols}${_SEED_REC_FIELDS[$i]}"
        if _seed_is_numeric "${_SEED_REC_VALS[$i]}"; then
            vals="${vals}${_SEED_REC_VALS[$i]}"
        else
            local escaped="${_SEED_REC_VALS[$i]//\'/\'\'}"
            vals="${vals}'${escaped}'"
        fi
        i=$((i+1))
    done
    printf 'INSERT INTO %s (%s) VALUES (%s);\n' "$_SEED_REC_TABLE" "$cols" "$vals"
}

# ---------------------------------------------------------------------------
# _seed_emit_multi <format> <first_ref> <rec>
# Print a record within a multi-record loop, handling CSV header dedup and
# KV blank-line separator.  Callers pass the name of the "first" variable as
# a nameref-style workaround (we use an indirect global instead for bash 3.2).
# Internal helper; not part of the public API.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# seed_user [--count N] [--format json|kv|csv|sql]
# ---------------------------------------------------------------------------
seed_user() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        # Coherent name + email + username from same first/last names
        local first_n last_n name fl ll domain email username
        _seed_random_line_v first_names; first_n="$_SEED_RESULT"
        _seed_random_line_v last_names;  last_n="$_SEED_RESULT"
        name="$first_n $last_n"
        _seed_str_slug_v "$first_n"; fl="$_SEED_RESULT"
        _seed_str_slug_v "$last_n";  ll="$_SEED_RESULT"
        _seed_random_line_v domains; domain="$_SEED_RESULT"
        email="${fl}.${ll}@${domain}"
        username="${fl}.${ll}"
        # Inline phone (cannot call seed_phone — _seed_parse_flags would reset flags)
        local a b c d phone
        _seed_random_int_v 2 9;       a="$_SEED_RESULT"
        _seed_random_int_v 10 99;     b="$_SEED_RESULT"
        _seed_random_int_v 100 999;   c="$_SEED_RESULT"
        _seed_random_int_v 1000 9999; d="$_SEED_RESULT"
        phone=$(printf '%d%02d-%03d-%04d' "$a" "$b" "$c" "$d")
        # Inline DOB date (18–80 years ago)
        local today_val from_dob to_dob
        today_val=$(_seed_today)
        from_dob=$(_seed_date_subtract_years "$today_val" 80)
        to_dob=$(_seed_date_subtract_years "$today_val" 18)
        local dy dm dd dmax dob
        _seed_random_int_v "${from_dob:0:4}" "${to_dob:0:4}"; dy="$_SEED_RESULT"
        _seed_random_int_v 1 12; dm="$_SEED_RESULT"
        case "$dm" in
            1|3|5|7|8|10|12) dmax=31 ;;
            4|6|9|11)         dmax=30 ;;
            2)
                if (( dy % 400 == 0 || (dy % 4 == 0 && dy % 100 != 0) )); then
                    dmax=29
                else
                    dmax=28
                fi
                ;;
        esac
        _seed_random_int_v 1 "$dmax"; dd="$_SEED_RESULT"
        dob=$(printf '%04d-%02d-%02d' "$dy" "$dm" "$dd")
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" users \
            name "$name" email "$email" phone "$phone" dob "$dob" username "$username")
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
# seed_address [--count N] [--format json|kv|csv|sql]
# ---------------------------------------------------------------------------
seed_address() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local street city state zip country
        street="$(_seed_random_int 1 9999) $(_seed_random_line streets)"
        city=$(_seed_random_line cities)
        state=$(_seed_random_state)
        zip=$(_seed_random_zip)
        country="US"
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" addresses \
            street "$street" city "$city" state "$state" zip "$zip" country "$country")
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
# seed_company [--count N] [--format json|kv|csv|sql]
# Flat record — no nested address object.
# ---------------------------------------------------------------------------
seed_company() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local name domain phone street city state zip country
        name=$(_seed_random_line companies)
        domain=$(_seed_random_line domains)
        phone=$(seed_phone)
        street="$(_seed_random_int 1 9999) $(_seed_random_line streets)"
        city=$(_seed_random_line cities)
        state=$(_seed_random_state)
        zip=$(_seed_random_zip)
        country="US"
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" companies \
            name "$name" domain "$domain" phone "$phone" \
            street "$street" city "$city" state "$state" zip "$zip" country "$country")
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
