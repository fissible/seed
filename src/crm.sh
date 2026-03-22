#!/usr/bin/env bash
# src/crm.sh — CRM generators

seed_contact() {
    _seed_parse_flags "$@" || return $?
    local titles
    titles=("Engineer" "Manager" "Director" "VP" "President" "Analyst" "Developer" "Designer" "Consultant")
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        # Coherent name + email
        local first_n last_n name fl ll domain email
        _seed_random_line_v first_names; first_n="$_SEED_RESULT"
        _seed_random_line_v last_names;  last_n="$_SEED_RESULT"
        name="$first_n $last_n"
        _seed_str_slug_v "$first_n"; fl="$_SEED_RESULT"
        _seed_str_slug_v "$last_n";  ll="$_SEED_RESULT"
        _seed_random_line_v domains; domain="$_SEED_RESULT"
        email="${fl}.${ll}@${domain}"
        # Inline phone
        local a b c d phone
        _seed_random_int_v 2 9;       a="$_SEED_RESULT"
        _seed_random_int_v 10 99;     b="$_SEED_RESULT"
        _seed_random_int_v 100 999;   c="$_SEED_RESULT"
        _seed_random_int_v 1000 9999; d="$_SEED_RESULT"
        phone=$(printf '%d%02d-%03d-%04d' "$a" "$b" "$c" "$d")
        local company
        _seed_random_line_v companies; company="$_SEED_RESULT"
        _seed_random_int_v 0 $(( ${#titles[@]} - 1 ))
        local title="${titles[$_SEED_RESULT]}"
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" contacts \
            name "$name" email "$email" phone "$phone" company "$company" title "$title")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}

seed_lead() {
    _seed_parse_flags "$@" || return $?
    local titles sources statuses
    titles=("Engineer" "Manager" "Director" "VP" "President" "Analyst" "Developer" "Designer" "Consultant")
    sources=("web" "referral" "email" "phone" "event")
    statuses=("new" "contacted" "qualified" "unqualified")
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        # Coherent name + email
        local first_n last_n name fl ll domain email
        _seed_random_line_v first_names; first_n="$_SEED_RESULT"
        _seed_random_line_v last_names;  last_n="$_SEED_RESULT"
        name="$first_n $last_n"
        _seed_str_slug_v "$first_n"; fl="$_SEED_RESULT"
        _seed_str_slug_v "$last_n";  ll="$_SEED_RESULT"
        _seed_random_line_v domains; domain="$_SEED_RESULT"
        email="${fl}.${ll}@${domain}"
        # Inline phone
        local a b c d phone
        _seed_random_int_v 2 9;       a="$_SEED_RESULT"
        _seed_random_int_v 10 99;     b="$_SEED_RESULT"
        _seed_random_int_v 100 999;   c="$_SEED_RESULT"
        _seed_random_int_v 1000 9999; d="$_SEED_RESULT"
        phone=$(printf '%d%02d-%03d-%04d' "$a" "$b" "$c" "$d")
        local company
        _seed_random_line_v companies; company="$_SEED_RESULT"
        _seed_random_int_v 0 $(( ${#titles[@]} - 1 ))
        local title="${titles[$_SEED_RESULT]}"
        _seed_random_int_v 0 $(( ${#sources[@]} - 1 ))
        local source="${sources[$_SEED_RESULT]}"
        _seed_random_int_v 0 $(( ${#statuses[@]} - 1 ))
        local status="${statuses[$_SEED_RESULT]}"
        _seed_random_int_v 1 100
        local score="$_SEED_RESULT"
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" leads \
            name "$name" email "$email" phone "$phone" company "$company" title "$title" \
            source "$source" status "$status" score "$score")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}

seed_deal() {
    _seed_parse_flags "$@" || return $?
    local stages
    stages=("prospecting" "qualified" "proposal" "negotiation" "closed_won" "closed_lost")
    local i=0 first=1
    local today_val to_year
    today_val=$(_seed_today)
    to_year="${today_val:0:4}"
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local adj noun title value stage close_date owner
        _seed_random_line_v adjectives; adj="$_SEED_RESULT"
        _seed_random_line_v nouns;      noun="$_SEED_RESULT"
        title="$adj $noun Deal"
        _seed_random_float_v 1.00 999.99; value="$_SEED_RESULT"
        _seed_random_int_v 0 $(( ${#stages[@]} - 1 ))
        stage="${stages[$_SEED_RESULT]}"
        # Inline close_date (default seed_date range: 2000–today)
        local dy dm dd dmax
        _seed_random_int_v 2000 "$to_year"; dy="$_SEED_RESULT"
        _seed_random_int_v 1 12; dm="$_SEED_RESULT"
        case "$dm" in
            1|3|5|7|8|10|12) dmax=31 ;;
            4|6|9|11)         dmax=30 ;;
            2) if (( dy % 400 == 0 || (dy % 4 == 0 && dy % 100 != 0) )); then dmax=29; else dmax=28; fi ;;
        esac
        _seed_random_int_v 1 "$dmax"; dd="$_SEED_RESULT"
        close_date=$(printf '%04d-%02d-%02d' "$dy" "$dm" "$dd")
        # Inline owner name
        local fn ln
        _seed_random_line_v first_names; fn="$_SEED_RESULT"
        _seed_random_line_v last_names;  ln="$_SEED_RESULT"
        owner="$fn $ln"
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" deals \
            title "$title" value "$value" stage "$stage" close_date "$close_date" owner "$owner")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}

seed_activity() {
    _seed_parse_flags "$@" || return $?
    local types
    types=("call" "email" "meeting")
    local i=0 first=1
    local today_val to_year
    today_val=$(_seed_today)
    to_year="${today_val:0:4}"
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        _seed_random_int_v 0 $(( ${#types[@]} - 1 ))
        local type="${types[$_SEED_RESULT]}"
        # Inline email
        local fn ln fl ll domain contact_email
        _seed_random_line_v first_names; fn="$_SEED_RESULT"
        _seed_random_line_v last_names;  ln="$_SEED_RESULT"
        _seed_random_line_v domains;     domain="$_SEED_RESULT"
        _seed_str_lower_v "$fn"; fl="$_SEED_RESULT"
        _seed_str_lower_v "$ln"; ll="$_SEED_RESULT"
        contact_email="${fl}.${ll}@${domain}"
        # Inline activity_date
        local dy dm dd dmax activity_date
        _seed_random_int_v 2000 "$to_year"; dy="$_SEED_RESULT"
        _seed_random_int_v 1 12; dm="$_SEED_RESULT"
        case "$dm" in
            1|3|5|7|8|10|12) dmax=31 ;;
            4|6|9|11)         dmax=30 ;;
            2) if (( dy % 400 == 0 || (dy % 4 == 0 && dy % 100 != 0) )); then dmax=29; else dmax=28; fi ;;
        esac
        _seed_random_int_v 1 "$dmax"; dd="$_SEED_RESULT"
        activity_date=$(printf '%04d-%02d-%02d' "$dy" "$dm" "$dd")
        # Inline lorem (notes)
        local notes
        _seed_random_line_v lorem; notes="$_SEED_RESULT"
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" activities \
            type "$type" contact_email "$contact_email" activity_date "$activity_date" notes "$notes")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}

seed_note() {
    _seed_parse_flags "$@" || return $?
    local linked_types
    linked_types=("contact" "deal")
    local i=0 first=1
    local today_val to_year
    today_val=$(_seed_today)
    to_year="${today_val:0:4}"
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        # Inline body (lorem)
        local body
        _seed_random_line_v lorem; body="$_SEED_RESULT"
        # Inline author name
        local fn ln author
        _seed_random_line_v first_names; fn="$_SEED_RESULT"
        _seed_random_line_v last_names;  ln="$_SEED_RESULT"
        author="$fn $ln"
        # Inline created date
        local dy dm dd dmax created
        _seed_random_int_v 2000 "$to_year"; dy="$_SEED_RESULT"
        _seed_random_int_v 1 12; dm="$_SEED_RESULT"
        case "$dm" in
            1|3|5|7|8|10|12) dmax=31 ;;
            4|6|9|11)         dmax=30 ;;
            2) if (( dy % 400 == 0 || (dy % 4 == 0 && dy % 100 != 0) )); then dmax=29; else dmax=28; fi ;;
        esac
        _seed_random_int_v 1 "$dmax"; dd="$_SEED_RESULT"
        created=$(printf '%04d-%02d-%02d' "$dy" "$dm" "$dd")
        _seed_random_int_v 0 $(( ${#linked_types[@]} - 1 ))
        local linked_type="${linked_types[$_SEED_RESULT]}"
        # UUID for linked_id — /dev/urandom, not LCG; subshell is safe
        local linked_id
        linked_id=$(_seed_uuid_gen)
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" notes \
            body "$body" author "$author" created_at "$created" \
            linked_type "$linked_type" linked_id "$linked_id")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}

seed_tag() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local name color
        _seed_random_line_v adjectives; name="$_SEED_RESULT"
        _seed_random_int_v 0 16777214
        color=$(printf '#%06x' "$_SEED_RESULT")
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" tags name "$name" color "$color")
        if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
            if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
            else printf '%s\n' "$rec" | tail -n 1; fi
        elif [[ "$_SEED_FLAG_FORMAT" == "kv" ]]; then
            [[ $first -eq 0 ]] && printf '\n'
            printf '%s\n' "$rec"; first=0
        else printf '%s\n' "$rec"; fi
        i=$((i+1))
    done
}
