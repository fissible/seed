#!/usr/bin/env bash
# src/str.sh — string helpers for fissible/seed (bash 3.2 compatible)
# Convention: _v functions write to _SEED_RESULT global; no stdout.
# No dependencies on other seed modules — can be sourced in isolation.

# _seed_str_lower_v <str>
# Lowercase all ASCII uppercase letters. Writes to _SEED_RESULT.
_seed_str_lower_v() {
    _SEED_RESULT=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
}

# _seed_str_slug_v <str>
# Lowercase, replace spaces with '.', strip non-[a-z0-9.-]. Writes to _SEED_RESULT.
_seed_str_slug_v() {
    _SEED_RESULT=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '.' | tr -dc 'a-z0-9.-')
}
