#!/usr/bin/env bash
# src/finance.sh — financial generators

# ---------------------------------------------------------------------------
# seed_credit_card [--count N] [--format json|kv|csv|sql]
# Generates Luhn-valid card numbers for Visa, Mastercard, Amex, Discover.
# number and cvv are pure digits — emitted unquoted in JSON/SQL.
# ---------------------------------------------------------------------------
seed_credit_card() {
    _seed_parse_flags "$@" || return $?
    local to_year
    to_year=$(_seed_today | cut -c1-4)
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local type prefix cvv_len total_len
        _seed_random_int_v 0 3
        case "$_SEED_RESULT" in
            0) type="Visa";       prefix="4";    cvv_len=3; total_len=16 ;;
            1) _seed_random_int_v 51 55; prefix="$_SEED_RESULT"
               type="Mastercard"; cvv_len=3; total_len=16 ;;
            2) _seed_random_int_v 0 1
               if [[ "$_SEED_RESULT" -eq 0 ]]; then prefix="34"; else prefix="37"; fi
               type="Amex";       cvv_len=4; total_len=15 ;;
            3) type="Discover";   prefix="6011"; cvv_len=3; total_len=16 ;;
        esac

        # Build partial: prefix + random digits to fill (total_len - 1) positions
        local partial="$prefix"
        local needed=$(( total_len - 1 - ${#prefix} ))
        local k=0
        while [[ $k -lt $needed ]]; do
            _seed_random_int_v 0 9
            partial="${partial}${_SEED_RESULT}"
            k=$((k+1))
        done

        # Compute Luhn check digit via awk subshell (does not touch _SEED_RNG_STATE)
        local check_digit
        check_digit=$(awk -v partial="$partial" 'BEGIN {
            n = length(partial); sum = 0
            for (i = n; i >= 1; i--) {
                d = substr(partial, i, 1) + 0
                if ((n - i + 1) % 2 == 1) { d = d * 2; if (d > 9) d -= 9 }
                sum += d
            }
            printf "%d", (10 - (sum % 10)) % 10
        }')
        local number="${partial}${check_digit}"

        # Expiry: MM/YY — random month, year in [current+1, current+5]
        local exp_month exp_year expiry
        _seed_random_int_v 1 12;                                          exp_month="$_SEED_RESULT"
        _seed_random_int_v $(( to_year + 1 )) $(( to_year + 5 )); exp_year="$_SEED_RESULT"
        expiry=$(printf '%02d/%02d' "$exp_month" "$(( exp_year % 100 ))")

        # CVV: generate as a single random integer in a no-leading-zero range.
        # Range [100,999] for 3-digit CVV; [1000,9999] for 4-digit Amex CVV.
        # This ensures _seed_fmt_json emits a valid JSON number (no leading zero).
        local cvv cvv_min cvv_max
        if [[ $cvv_len -eq 4 ]]; then cvv_min=1000; cvv_max=9999
        else                          cvv_min=100;  cvv_max=999; fi
        _seed_random_int_v "$cvv_min" "$cvv_max"; cvv="$_SEED_RESULT"

        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" credit_cards \
            type "$type" number "$number" expiry "$expiry" cvv "$cvv")
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
