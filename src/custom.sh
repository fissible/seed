#!/usr/bin/env bash
# src/custom.sh — seed_custom generator + _seed_cfield_* helpers

_seed_cfield_first_name()  { _seed_random_line_v first_names; }
_seed_cfield_last_name()   { _seed_random_line_v last_names; }
_seed_cfield_name()        {
    local fn ln
    _seed_random_line_v first_names; fn="$_SEED_RESULT"
    _seed_random_line_v last_names;  ln="$_SEED_RESULT"
    _SEED_RESULT="$fn $ln"
}
_seed_cfield_email()       {
    local fn ln d fl ll
    _seed_random_line_v first_names; fn="$_SEED_RESULT"
    _seed_random_line_v last_names;  ln="$_SEED_RESULT"
    _seed_random_line_v domains;     d="$_SEED_RESULT"
    _seed_str_lower_v "$fn"; fl="$_SEED_RESULT"
    _seed_str_lower_v "$ln"; ll="$_SEED_RESULT"
    _SEED_RESULT="${fl}.${ll}@${d}"
}
_seed_cfield_phone()       {
    local a b c d
    _seed_random_int_v 2 9;       a="$_SEED_RESULT"
    _seed_random_int_v 10 99;     b="$_SEED_RESULT"
    _seed_random_int_v 100 999;   c="$_SEED_RESULT"
    _seed_random_int_v 1000 9999; d="$_SEED_RESULT"
    _SEED_RESULT=$(printf '%d%02d-%03d-%04d' "$a" "$b" "$c" "$d")
}
_seed_cfield_uuid()        {
    _SEED_RESULT=$(_seed_uuid_gen)
}
_seed_cfield_date()        {
    # $1=from (YYYY-MM-DD, default 2000-01-01)  $2=to (YYYY-MM-DD, default today)
    local from="${1:-2000-01-01}" to="${2:-$(_seed_today)}"
    local from_year="${from:0:4}" to_year="${to:0:4}"
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
    _SEED_RESULT=$(printf '%04d-%02d-%02d' "$year" "$month" "$day")
}
_seed_cfield_number()      {
    # $1=min  $2=max
    _seed_random_int_v "${1:-1}" "${2:-100}"
}
_seed_cfield_bool()        {
    _seed_random_int_v 0 1
    if [[ "$_SEED_RESULT" -eq 0 ]]; then _SEED_RESULT="true"
    else _SEED_RESULT="false"; fi
}
_seed_cfield_lorem()       {
    _seed_random_line_v lorem
}
_seed_cfield_ip()          {
    local o1 o2 o3 o4
    _seed_random_int_v 1 254; o1="$_SEED_RESULT"
    _seed_random_int_v 1 254; o2="$_SEED_RESULT"
    _seed_random_int_v 1 254; o3="$_SEED_RESULT"
    _seed_random_int_v 1 254; o4="$_SEED_RESULT"
    _SEED_RESULT=$(printf '%d.%d.%d.%d' "$o1" "$o2" "$o3" "$o4")
}
_seed_cfield_url()         {
    local dom noun
    _seed_random_line_v domains; dom="$_SEED_RESULT"
    _seed_random_line_v nouns;   noun="$_SEED_RESULT"
    _SEED_RESULT="https://${dom}/${noun}"
}

seed_custom() {
    _seed_parse_flags "$@" || return $?

    if [[ -z "$_SEED_FLAG_SCHEMA" ]]; then
        printf 'seed_custom: --schema is required\n' >&2
        return 2
    fi

    local schema_path
    if [[ "$_SEED_FLAG_SCHEMA" == */* ]]; then
        schema_path="$_SEED_FLAG_SCHEMA"
    else
        schema_path="${SEED_FIXTURES_DIR:-tests/fixtures}/${_SEED_FLAG_SCHEMA}.seed"
    fi
    if [[ ! -f "$schema_path" ]]; then
        printf 'seed_custom: schema file not found: %s\n' "$schema_path" >&2
        return 2
    fi

    local table=""
    local field_names=() field_generators=() field_flags=()
    while IFS= read -r line; do
        case "$line" in '#'*) continue ;; esac
        [[ -z "${line//[[:space:]]/}" ]] && continue
        if [[ "$line" == table=* ]]; then
            table="${line#table=}"
        else
            local col rest sql_type gen_spec gen_name gen_args
            col="${line%%|*}"; rest="${line#*|}"
            sql_type="${rest%%|*}"; gen_spec="${rest#*|}"
            gen_name="${gen_spec%% *}"
            gen_args="${gen_spec#* }"; [[ "$gen_args" == "$gen_name" ]] && gen_args=""
            if ! declare -f "_seed_cfield_${gen_name}" > /dev/null 2>&1; then
                printf 'seed_custom: unknown generator "%s" in %s\n' "$gen_name" "$schema_path" >&2
                return 2
            fi
            field_names[${#field_names[@]}]="$col"
            field_generators[${#field_generators[@]}]="$gen_name"
            field_flags[${#field_flags[@]}]="$gen_args"
        fi
    done < "$schema_path"

    if [[ -z "$table" ]]; then
        printf 'seed_custom: missing table= line in %s\n' "$schema_path" >&2
        return 2
    fi

    local rec_args=()
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        rec_args=()
        local f=0
        while [[ $f -lt ${#field_names[@]} ]]; do
            local gen="${field_generators[$f]}"
            local flags="${field_flags[$f]}"
            local fmin="" fmax="" ffrom="" fto="" fwords="" fsentences=""
            local _f="$flags"
            while [[ -n "$_f" ]]; do
                local _tok="${_f%% *}"
                [[ "$_tok" == "$_f" ]] && _f="" || _f="${_f#* }"
                case "$_tok" in
                    --min)       fmin="${_f%% *}";       [[ "$fmin"       == "$_f" ]] && _f="" || _f="${_f#* }" ;;
                    --max)       fmax="${_f%% *}";       [[ "$fmax"       == "$_f" ]] && _f="" || _f="${_f#* }" ;;
                    --from)      ffrom="${_f%% *}";      [[ "$ffrom"      == "$_f" ]] && _f="" || _f="${_f#* }" ;;
                    --to)        fto="${_f%% *}";        [[ "$fto"        == "$_f" ]] && _f="" || _f="${_f#* }" ;;
                    --words)     fwords="${_f%% *}";     [[ "$fwords"     == "$_f" ]] && _f="" || _f="${_f#* }" ;;
                    --sentences) fsentences="${_f%% *}"; [[ "$fsentences" == "$_f" ]] && _f="" || _f="${_f#* }" ;;
                esac
            done
            case "$gen" in
                number) _seed_cfield_number "$fmin" "$fmax" ;;
                date)   _seed_cfield_date   "$ffrom" "$fto" ;;
                lorem)  _seed_cfield_lorem  "$fwords" "$fsentences" ;;
                *)      _seed_cfield_${gen} ;;
            esac
            rec_args[${#rec_args[@]}]="${field_names[$f]}"
            rec_args[${#rec_args[@]}]="$_SEED_RESULT"
            f=$((f+1))
        done
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" "$table" "${rec_args[@]}")
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
