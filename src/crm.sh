#!/usr/bin/env bash
# src/crm.sh — CRM generators

seed_contact() {
    _seed_parse_flags "$@" || return $?
    local titles
    titles=("Engineer" "Manager" "Director" "VP" "President" "Analyst" "Developer" "Designer" "Consultant")
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local name email phone company title
        name=$(seed_name)
        email=$(seed_email)
        phone=$(seed_phone)
        company=$(_seed_random_line companies)
        title="${titles[$(_seed_random_int 0 $((${#titles[@]} - 1)))]}"
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
        local name email phone company title source status score
        name=$(seed_name)
        email=$(seed_email)
        phone=$(seed_phone)
        company=$(_seed_random_line companies)
        title="${titles[$(_seed_random_int 0 $((${#titles[@]} - 1)))]}"
        source="${sources[$(_seed_random_int 0 $((${#sources[@]} - 1)))]}"
        status="${statuses[$(_seed_random_int 0 $((${#statuses[@]} - 1)))]}"
        score=$(_seed_random_int 1 100)
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
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local title value stage close_date owner
        title="$(_seed_random_line adjectives) $(_seed_random_line nouns) Deal"
        value=$(_seed_random_float 1.00 999.99)
        stage="${stages[$(_seed_random_int 0 $((${#stages[@]} - 1)))]}"
        close_date=$(seed_date)
        owner=$(seed_name)
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
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local type contact_email date notes
        type="${types[$(_seed_random_int 0 $((${#types[@]} - 1)))]}"
        contact_email=$(seed_email)
        date=$(seed_date)
        notes=$(seed_lorem)
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" activities \
            type "$type" contact_email "$contact_email" date "$date" notes "$notes")
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
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local body author created linked_type linked_id
        body=$(seed_lorem)
        author=$(seed_name)
        created=$(seed_date)
        linked_type="${linked_types[$(_seed_random_int 0 $((${#linked_types[@]} - 1)))]}"
        linked_id=$(seed_uuid)
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
        name=$(_seed_random_line adjectives)
        color=$(printf '#%06x\n' "$(_seed_random_int 0 16777214)")
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
