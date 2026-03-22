#!/usr/bin/env bash
# src/new.sh — schema wizard and new-resource generators
# Bash 3.2 compatible: no declare -A, no +=, no mapfile

# ---------------------------------------------------------------------------
# _seed_new_infer_sql_type <gen_name>
# Returns the SQL column type for a given generator name on stdout.
# ---------------------------------------------------------------------------
_seed_new_infer_sql_type() {
    local gen="$1"
    case "$gen" in
        uuid)                              printf 'VARCHAR(36)\n'  ;;
        number)                            printf 'INT\n'          ;;
        date)                              printf 'TIMESTAMP\n'    ;;
        bool)                              printf 'BOOLEAN\n'      ;;
        ip)                                printf 'VARCHAR(15)\n'  ;;
        url|email)                         printf 'VARCHAR(255)\n' ;;
        first_name|last_name|name|phone)   printf 'VARCHAR(100)\n' ;;
        lorem)                             printf 'TEXT\n'         ;;
        *)                                 printf 'VARCHAR(255)\n' ;;
    esac
}
