# fissible/seed

A complete bash fake-data generator with an MCP server for Claude Code. Generate realistic test data in JSON, KV, CSV, or SQL formats—or use TUI helpers for filenames and directory structures.

## Quick Start

### As a Bash Library

Source the library and call generators directly:

```bash
source ~/lib/fissible/seed/seed.sh

# Single scalar value
seed_name
seed_email
seed_phone

# Generate 5 users in JSON
seed_user --count 5 --format json
```

### As a CLI

Run generators directly via bash:

```bash
bash ~/lib/fissible/seed/seed.sh user --format json --count 3
bash ~/lib/fissible/seed/seed.sh product --count 10 --format csv
bash ~/lib/fissible/seed/seed.sh lead --format json --count 1
```

## Generators

### Scalar (single values, no --format support)

- `seed_name` – Full name (first + last)
- `seed_first_name` – First name only
- `seed_last_name` – Last name only
- `seed_email` – Email address
- `seed_phone` – Phone number (US format)
- `seed_uuid` – UUID v4
- `seed_date` – ISO 8601 date (today ±30 days)
- `seed_number` – Random integer
- `seed_lorem` – Lorem ipsum paragraph
- `seed_ip` – IPv4 address
- `seed_url` – HTTP URL
- `seed_bool` – true or false

### Record (structured data)

- `seed_user` – User with name, email, phone
- `seed_address` – Postal address
- `seed_company` – Company with name, industry, size

### Ecommerce

- `seed_product` – Product with SKU, price, category, description, stock
- `seed_category` – Product category with slug
- `seed_order` – Order with customer, total, status
- `seed_order_item` – Line item with product, quantity, price
- `seed_coupon` – Discount code with percentage/amount
- `seed_cart` – Shopping cart with items

### CRM

- `seed_contact` – Contact with name, email, phone, company, title
- `seed_lead` – Lead with score, source, status
- `seed_deal` – Deal with amount, stage, owner
- `seed_activity` – Activity (call/email/meeting) with date, outcome
- `seed_note` – Internal note with text
- `seed_tag` – Tag for categorization

### TUI (terminal UI helpers, no --format support)

- `seed_filenames` – Realistic filenames (default: 10)
- `seed_dirtree` – Hierarchical directory structure (default: 10)
- `seed_menu_items` – Menu items for selection lists (default: 10)

## Formats

Formats apply to record and ecommerce/CRM generators. Scalar and TUI generators ignore `--format`.

- `--format json` – JSON object per line (default)
- `--format kv` – Key=value pairs, blank-line delimited
- `--format csv` – CSV with headers (record + ecommerce + CRM only)
- `--format sql` – SQL INSERT statements

## Flags

All generators support:

- `--count <int>` – Number of records (default: 1; TUI default: 10)

Additional flags for specific generators:

- `--min <int>`, `--max <int>` – For `seed_number` and numeric generators
- `--from <date>`, `--to <date>` – For `seed_date` (ISO 8601 format)
- `--words <int>` – For `seed_lorem` (default: ~50)
- `--sentences <int>` – For `seed_lorem` (default: varies)
- `--items <int>` – For `seed_cart` (default: 3)

## MCP Setup for Claude Code

1. Copy `.mcp.json` to your project root:
   ```bash
   cp ~/lib/fissible/seed/.mcp.json /path/to/your/project/
   ```

   Or manually add to your project's `.mcp.json`:
   ```json
   {
     "mcpServers": {
       "seed": {
         "command": "python3",
         "args": ["/Users/allenmccabe/lib/fissible/seed/mcp/server.py"]
       }
     }
   }
   ```

2. Restart Claude Code or reload the MCP server configuration.

3. You can now use tools like `seed_name`, `seed_email`, `seed_product`, etc. directly in Claude Code to generate test data on demand.

## Bash Compatibility

Requires bash 3.2 or later (including macOS native bash, Docker, WSL). No external dependencies beyond core utilities (awk, tr, head).

## Environment

- `SEED_HOME` – Home directory of the seed repo (auto-detected from script location)
- `SEED_DATA` – Data file directory (auto-detected, defaults to `$SEED_HOME/data`)

## Examples

```bash
# Generate 5 JSON users
bash seed.sh user --count 5 --format json

# Generate 3 CSV products
bash seed.sh product --count 3 --format csv

# Generate a single CRM contact (JSON default)
bash seed.sh contact

# Generate 20 filenames for your test file list
bash seed.sh filenames --count 20

# Generate SQL insert statements for orders
bash seed.sh order --count 5 --format sql

# Use in a pipeline
bash seed.sh email --count 100 | sort | uniq

# Source as a library in your script
source seed.sh
for i in {1..5}; do seed_name; done
```

## Files

```
fissible/seed/
├── seed.sh              # Main CLI dispatcher and library entrypoint
├── mcp/
│   └── server.py        # Python MCP server (for Claude Code)
├── src/
│   ├── scalar.sh        # Atomic value generators (name, email, uuid, etc.)
│   ├── record.sh        # Structured record generators (user, address, company)
│   ├── ecommerce.sh     # E-commerce generators (product, order, coupon, etc.)
│   ├── crm.sh           # CRM generators (contact, lead, deal, activity, etc.)
│   └── tui.sh           # TUI helpers (filenames, dirtree, menu_items)
├── data/                # Data files (names, emails, nouns, adjectives, etc.)
├── tests/               # Integration tests (ptyunit)
└── docker/              # Docker matrix for CI/CD
```

## License

MIT
