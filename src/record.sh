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
