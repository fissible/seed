#!/usr/bin/env bash
# fissible/seed — bash fake data generator
# Usage (CLI):   bash seed.sh <generator> [flags]
# Usage (lib):   source seed.sh; seed_name

SEED_HOME="${SEED_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

source "$SEED_HOME/src/scalar.sh"
source "$SEED_HOME/src/record.sh"
source "$SEED_HOME/src/ecommerce.sh"
source "$SEED_HOME/src/crm.sh"
source "$SEED_HOME/src/tui.sh"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _seed_cli "$@"
fi
