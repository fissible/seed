#!/usr/bin/env bash
# src/ecommerce.sh — ecommerce generators

seed_product() {
    _seed_parse_flags "$@" || return $?
    local i=0 first=1
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local adj noun sku_num sku_prefix sku price category desc stock
        _seed_random_line_v adjectives;  adj="$_SEED_RESULT"
        _seed_random_line_v nouns;       noun="$_SEED_RESULT"
        _seed_random_int_v 10000 99999;  sku_num="$_SEED_RESULT"
        sku_prefix=$(printf '%s' "$adj$noun" | tr '[:lower:]' '[:upper:]' | tr -dc 'A-Z' | head -c 3)
        sku="${sku_prefix}-$(printf '%05d' "$sku_num")"
        _seed_random_float_v 1.00 999.99; price="$_SEED_RESULT"
        _seed_random_line_v nouns;        category="$_SEED_RESULT"
        _seed_random_line_v lorem;        desc="$_SEED_RESULT"
        _seed_random_int_v 0 500;         stock="$_SEED_RESULT"
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
        _seed_random_line_v nouns; name="$_SEED_RESULT"
        slug=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        parent=""
        _seed_random_int_v 0 1
        if [[ "$_SEED_RESULT" -eq 0 ]]; then
            _seed_random_line_v nouns; parent="$_SEED_RESULT"
        fi
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
    local i=0 first=1
    local statuses
    statuses=("pending" "processing" "shipped" "delivered" "cancelled")
    local today_val to_year
    today_val=$(_seed_today)
    to_year="${today_val:0:4}"
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local oid fn ln fl ll domain email status total
        # UUID from /dev/urandom — subshell safe (no LCG)
        oid=$(_seed_uuid_gen)
        # Inline customer_email
        _seed_random_line_v first_names; fn="$_SEED_RESULT"
        _seed_random_line_v last_names;  ln="$_SEED_RESULT"
        _seed_random_line_v domains;     domain="$_SEED_RESULT"
        _seed_str_lower_v "$fn"; fl="$_SEED_RESULT"
        _seed_str_lower_v "$ln"; ll="$_SEED_RESULT"
        email="${fl}.${ll}@${domain}"
        _seed_random_int_v 0 $(( ${#statuses[@]} - 1 ))
        status="${statuses[$_SEED_RESULT]}"
        _seed_random_float_v 5.00 9999.99; total="$_SEED_RESULT"
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
        local oid adj noun sku_num sku_prefix sku qty unit_price line_total
        oid=$(_seed_uuid_gen)
        _seed_random_line_v adjectives; adj="$_SEED_RESULT"
        _seed_random_line_v nouns;      noun="$_SEED_RESULT"
        _seed_random_int_v 10000 99999; sku_num="$_SEED_RESULT"
        sku_prefix=$(printf '%s' "$adj$noun" | tr '[:lower:]' '[:upper:]' | tr -dc 'A-Z' | head -c 3)
        sku="${sku_prefix}-$(printf '%05d' "$sku_num")"
        _seed_random_int_v 1 10;          qty="$_SEED_RESULT"
        _seed_random_float_v 1.00 999.99; unit_price="$_SEED_RESULT"
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
    local today_val from_year
    today_val=$(_seed_today)
    from_year="${today_val:0:4}"
    while [[ $i -lt $_SEED_FLAG_COUNT ]]; do
        local code dtype value
        # coupon code: /dev/urandom — subshell safe (no LCG)
        code=$(od -An -N6 -tx1 /dev/urandom | tr -dc 'A-Z0-9' | head -c 8)
        _seed_random_int_v 0 1
        if [[ "$_SEED_RESULT" -eq 0 ]]; then dtype="pct"; else dtype="fixed"; fi
        _seed_random_float_v 1.00 99.99; value="$_SEED_RESULT"
        # Inline date (from today to 2028-12-31)
        local dy dm dd dmax expires
        _seed_random_int_v "$from_year" 2028; dy="$_SEED_RESULT"
        _seed_random_int_v 1 12; dm="$_SEED_RESULT"
        case "$dm" in
            1|3|5|7|8|10|12) dmax=31 ;;
            4|6|9|11)         dmax=30 ;;
            2) if (( dy % 400 == 0 || (dy % 4 == 0 && dy % 100 != 0) )); then dmax=29; else dmax=28; fi ;;
        esac
        _seed_random_int_v 1 "$dmax"; dd="$_SEED_RESULT"
        expires=$(printf '%04d-%02d-%02d' "$dy" "$dm" "$dd")
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
        local cart_id fn ln fl ll domain customer_email subtotal
        cart_id=$(_seed_uuid_gen)
        # Inline customer_email
        _seed_random_line_v first_names; fn="$_SEED_RESULT"
        _seed_random_line_v last_names;  ln="$_SEED_RESULT"
        _seed_random_line_v domains;     domain="$_SEED_RESULT"
        _seed_str_lower_v "$fn"; fl="$_SEED_RESULT"
        _seed_str_lower_v "$ln"; ll="$_SEED_RESULT"
        customer_email="${fl}.${ll}@${domain}"

        local item_skus item_qtys item_prices item_totals
        item_skus=(); item_qtys=(); item_prices=(); item_totals=()
        subtotal="0"
        local ii=0
        while [[ $ii -lt $item_count ]]; do
            local adj noun sku_num sku_prefix sku qty up lt
            _seed_random_line_v adjectives; adj="$_SEED_RESULT"
            _seed_random_line_v nouns;      noun="$_SEED_RESULT"
            _seed_random_int_v 10000 99999; sku_num="$_SEED_RESULT"
            sku_prefix=$(printf '%s' "$adj$noun" | tr '[:lower:]' '[:upper:]' | tr -dc 'A-Z' | head -c 3)
            sku="${sku_prefix}-$(printf '%05d' "$sku_num")"
            _seed_random_int_v 1 10;          qty="$_SEED_RESULT"
            _seed_random_float_v 1.00 999.99; up="$_SEED_RESULT"
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
