#!/usr/bin/env bash
# src/ecommerce.sh — ecommerce generators

seed_product() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local noun adj sku price category desc stock
        noun=$(_seed_random_line nouns)
        adj=$(_seed_random_line adjectives)
        # SKU: 3 uppercase letters + hyphen + 5 digits
        sku=$(printf '%s-%05d' \
            "$(printf '%s' "$adj$noun" | tr '[:lower:]' '[:upper:]' | tr -dc 'A-Z' | head -c 3)" \
            "$(_seed_random_int 10000 99999)")
        price=$(_seed_random_float 1.00 999.99)
        category=$(_seed_random_line nouns)
        desc=$(seed_lorem)
        stock=$(_seed_random_int 0 500)
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" products \
            name "${adj} ${noun}" sku "$sku" price "$price" \
            category "$category" description "$desc" stock_qty "$stock")
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

seed_category() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local name slug parent
        name=$(_seed_random_line nouns)
        slug=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        parent=""
        [[ $(( RANDOM % 2 )) -eq 0 ]] && parent=$(_seed_random_line nouns)
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" categories \
            name "$name" slug "$slug" parent_category "$parent")
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

seed_order() {
    _seed_parse_flags "$@" || return $?
    local statuses="pending processing shipped delivered cancelled"
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local oid email status total created
        oid=$(seed_uuid)
        email=$(seed_email)
        status=$(_seed_random_elem $statuses)
        total=$(_seed_random_float 5.00 9999.99)
        created=$(seed_date)
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" orders \
            order_id "$oid" customer_email "$email" status "$status" \
            total "$total" created_at "$created")
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

seed_order_item() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local oid adj noun sku qty unit_price line_total
        oid=$(seed_uuid)
        adj=$(_seed_random_line adjectives)
        noun=$(_seed_random_line nouns)
        sku=$(printf '%s-%05d' \
            "$(printf '%s' "$adj$noun" | tr '[:lower:]' '[:upper:]' | tr -dc 'A-Z' | head -c 3)" \
            "$(_seed_random_int 10000 99999)")
        qty=$(_seed_random_int 1 10)
        unit_price=$(_seed_random_float 1.00 999.99)
        line_total=$(awk "BEGIN { printf \"%.2f\", $qty * $unit_price }")
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" order_items \
            order_id "$oid" product_sku "$sku" name "${adj} ${noun}" \
            qty "$qty" unit_price "$unit_price" line_total "$line_total")
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

seed_coupon() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local code dtype value expires
        code=$(od -An -N6 -tx1 /dev/urandom | tr -dc 'A-Z0-9' | head -c 8)
        if [[ $(( RANDOM % 2 )) -eq 0 ]]; then dtype="pct"; else dtype="fixed"; fi
        value=$(_seed_random_float 1.00 99.99)
        expires=$(seed_date --from "$(_seed_today)" --to "2028-12-31")
        local rec
        rec=$(_seed_emit_record "$_SEED_FLAG_FORMAT" coupons \
            code "$code" discount_type "$dtype" value "$value" expires_at "$expires")
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

seed_cart() {
    # --format sql not supported — check before parsing flags
    local arg
    for arg in "$@"; do
        if [[ "$arg" == "sql" ]]; then
            printf 'seed_cart: --format sql is not supported\n' >&2
            return 2
        fi
    done
    _seed_parse_flags "$@" || return $?
    if [[ "$_SEED_FLAG_FORMAT" == "sql" ]]; then
        printf 'seed_cart: --format sql is not supported\n' >&2
        return 2
    fi
    local item_count="${_SEED_FLAG_ITEMS:-3}"
    [[ $item_count -lt 1 ]] && item_count=1
    [[ $item_count -gt 10 ]] && item_count=10

    local ci=0 first=1
    while [[ $ci -lt $_SEED_FLAG_COUNT ]]; do
        local cart_id customer_email subtotal
        cart_id=$(seed_uuid)
        customer_email=$(seed_email)

        # Generate N items — use indexed arrays (bash 3.2 safe)
        local item_skus item_qtys item_prices item_totals
        item_skus=(); item_qtys=(); item_prices=(); item_totals=()
        subtotal="0"
        local ii=0
        while [[ $ii -lt $item_count ]]; do
            local adj noun sku qty up lt
            adj=$(_seed_random_line adjectives)
            noun=$(_seed_random_line nouns)
            sku=$(printf '%s-%05d' \
                "$(printf '%s' "$adj$noun" | tr '[:lower:]' '[:upper:]' | tr -dc 'A-Z' | head -c 3)" \
                "$(_seed_random_int 10000 99999)")
            qty=$(_seed_random_int 1 10)
            up=$(_seed_random_float 1.00 999.99)
            lt=$(awk "BEGIN { printf \"%.2f\", $qty * $up }")
            item_skus[${#item_skus[@]}]="$sku"
            item_qtys[${#item_qtys[@]}]="$qty"
            item_prices[${#item_prices[@]}]="$up"
            item_totals[${#item_totals[@]}]="$lt"
            subtotal=$(awk "BEGIN { printf \"%.2f\", $subtotal + $lt }")
            ii=$((ii+1))
        done

        case "$_SEED_FLAG_FORMAT" in
            json)
                local items_json="["
                ii=0
                while [[ $ii -lt $item_count ]]; do
                    [[ $ii -gt 0 ]] && items_json="${items_json},"
                    items_json="${items_json}{\"order_id\":\"${cart_id}\",\"product_sku\":\"${item_skus[$ii]}\",\"qty\":${item_qtys[$ii]},\"unit_price\":${item_prices[$ii]},\"line_total\":${item_totals[$ii]}}"
                    ii=$((ii+1))
                done
                items_json="${items_json}]"
                printf '{"cart_id":"%s","customer_email":"%s","subtotal":%s,"items":%s}\n' \
                    "$cart_id" "$customer_email" "$subtotal" "$items_json"
                ;;
            kv|csv)
                # Flatten items as item_N_* fields
                local flat_fields flat_vals
                flat_fields=(); flat_vals=()
                flat_fields[${#flat_fields[@]}]="cart_id"
                flat_vals[${#flat_vals[@]}]="$cart_id"
                flat_fields[${#flat_fields[@]}]="customer_email"
                flat_vals[${#flat_vals[@]}]="$customer_email"
                flat_fields[${#flat_fields[@]}]="subtotal"
                flat_vals[${#flat_vals[@]}]="$subtotal"
                ii=0
                while [[ $ii -lt $item_count ]]; do
                    local n=$((ii+1))
                    flat_fields[${#flat_fields[@]}]="item_${n}_product_sku"
                    flat_vals[${#flat_vals[@]}]="${item_skus[$ii]}"
                    flat_fields[${#flat_fields[@]}]="item_${n}_qty"
                    flat_vals[${#flat_vals[@]}]="${item_qtys[$ii]}"
                    flat_fields[${#flat_fields[@]}]="item_${n}_unit_price"
                    flat_vals[${#flat_vals[@]}]="${item_prices[$ii]}"
                    flat_fields[${#flat_fields[@]}]="item_${n}_line_total"
                    flat_vals[${#flat_vals[@]}]="${item_totals[$ii]}"
                    ii=$((ii+1))
                done
                # Build positional args array for _seed_emit_record
                local pargs
                pargs=("$_SEED_FLAG_FORMAT" "carts")
                ii=0
                while [[ $ii -lt ${#flat_fields[@]} ]]; do
                    pargs[${#pargs[@]}]="${flat_fields[$ii]}"
                    pargs[${#pargs[@]}]="${flat_vals[$ii]}"
                    ii=$((ii+1))
                done
                local rec
                rec=$(_seed_emit_record "${pargs[@]}")
                if [[ "$_SEED_FLAG_FORMAT" == "csv" ]]; then
                    if [[ $first -eq 1 ]]; then printf '%s\n' "$rec"; first=0
                    else printf '%s\n' "$rec" | tail -n 1; fi
                else
                    [[ $first -eq 0 ]] && printf '\n'
                    printf '%s\n' "$rec"; first=0
                fi
                ;;
        esac
        ci=$((ci+1))
    done
}
