# 🌱 seed

**Fake data for the rest of us.**

A bash-first fake data generator — source it as a library, call it from the CLI, or wire it up as an MCP server so Claude can generate test data without spending tokens.

```bash
$ bash seed.sh user --count 3 --format json
{"name":"Amy Peterson","email":"amy.peterson@generated.io","phone":"941-212-9025","dob":"1992-12-22","username":"amy.peterson"}
{"name":"Joshua Campbell","email":"j.campbell@testmail.net","phone":"765-893-8309","dob":"1947-10-02","username":"joshua.campbell"}
{"name":"Angela Bell","email":"angela.bell@trial.co","phone":"752-176-9946","dob":"1952-05-14","username":"angela.bell"}
```

No runtime. No package manager. No dependencies beyond bash and awk.

---

## What's in the box

**31 generators** across 5 categories, 4 output formats, and an MCP server that turns Claude into a data factory.

| Category | Generators |
|---|---|
| Scalar | `name` `email` `phone` `uuid` `date` `number` `lorem` `ip` `url` `bool` `first_name` `last_name` |
| Record | `user` `address` `company` |
| Ecommerce | `product` `category` `order` `order_item` `coupon` `cart` |
| CRM | `contact` `lead` `deal` `activity` `note` `tag` |
| TUI | `filenames` `dirtree` `menu_items` |

---

## Install

```bash
git clone https://github.com/fissible/seed ~/lib/fissible/seed
```

That's it. No build step.

---

## Usage

### Library

Source `seed.sh` and call any `seed_*` function:

```bash
source ~/lib/fissible/seed/seed.sh

seed_name          # Patricia Torres
seed_email         # patricia.torres@fakecorp.dev
seed_uuid          # 4f9a1c2e-8b3d-47f0-a561-dc9e2b8f1034
seed_bool          # true
```

### CLI

```bash
bash seed.sh <generator> [flags]

bash seed.sh name --count 5
bash seed.sh user --format json
bash seed.sh product --count 10 --format csv
bash seed.sh order --format sql --count 3
bash seed.sh filenames --count 20
```

---

## Output formats

All record generators support `--format json|kv|csv|sql`. Default is JSON.

### JSON (default)
```bash
$ bash seed.sh order
{"order_id":"27ba8115-eb1c-44a0-bbb9-a9681275bfba","customer_email":"andrew.henderson@samplelink.net","status":"cancelled","total":1951.20,"created_at":"2020-07-27"}
```

### CSV
```bash
$ bash seed.sh user --count 3 --format csv
name,email,phone,dob,username
"Joshua Campbell","jeffrey.torres@testmail.net","765-893-8309","1947-10-02","joshua.campbell"
"Angela Bell","michael.jackson@trial.co","752-176-9946","1952-05-14","angela.bell"
"Patrick Martinez","mark.white@fakecorp.dev","796-750-6687","1977-04-20","patrick.martinez"
```

### SQL
```bash
$ bash seed.sh order --format sql
INSERT INTO orders (order_id, customer_email, status, total, created_at) VALUES ('407c15a9-d62c-434f-90fb-5575d901de46', 'stephanie.russell@fakemailbox.net', 'shipped', 8154.95, '2009-02-15');
```

### KV
```bash
$ bash seed.sh user --format kv
NAME="Amy Peterson"
EMAIL="amy.peterson@generated.io"
PHONE="941-212-9025"
DOB="1992-12-22"
USERNAME="amy.peterson"
```

---

## Structured generators

### `seed_cart` — nested JSON

```bash
$ bash seed.sh cart --items 2
{
  "cart_id": "a0abf54b-b3d5-46b8-a8c5-f8bd67ced3a1",
  "customer_email": "michelle.alexander@trial.co",
  "subtotal": 2626.93,
  "items": [
    {"order_id": "a0abf54b...", "product_sku": "WEE-20993", "qty": 9, "unit_price": 155.33, "line_total": 1397.97},
    {"order_id": "a0abf54b...", "product_sku": "QUI-21548", "qty": 4, "unit_price": 307.24, "line_total": 1228.96}
  ]
}
```

`line_total` is always `qty × unit_price`. `subtotal` is always the sum of `line_total`s. Math is real.

### TUI helpers — plain text, one per line

```bash
$ bash seed.sh filenames --count 5
draft-widget-2019.csv
latest-dataset-2025.json
optimized-queue-2025.json
quick-block-2024.txt
old-detail-2020.txt

$ bash seed.sh dirtree --count 3
network/asset/log
client/dataset/node
quick/block/archive

$ bash seed.sh menu_items --count 4
Dynamic Widget
Latest Dataset
Optimized Queue
Quick Block
```

TUI generators don't support `--format` — they output plain lines, ready for your TUI list.

---

## Flags

| Flag | Default | Applies to |
|---|---|---|
| `--count <n>` | 1 (TUI: 10) | all generators |
| `--format json\|kv\|csv\|sql` | json | record generators |
| `--min <n>` / `--max <n>` | 1 / 100 | `seed_number` |
| `--from <date>` / `--to <date>` | 2000-01-01 / today | `seed_date` |
| `--words <n>` | — | `seed_lorem` |
| `--sentences <n>` | — | `seed_lorem` |
| `--items <n>` | 3 (max 10) | `seed_cart` |

---

## MCP server — for Claude Code

Wire seed up as an MCP tool so Claude can generate fake data on demand, without spending tokens inventing it.

### Setup

**1. Clone the repo** (if you haven't):

```bash
git clone https://github.com/fissible/seed ~/lib/fissible/seed
pip3 install mcp
```

**2. Add to your project's `.mcp.json`:**

```json
{
  "mcpServers": {
    "seed": {
      "command": "python3",
      "args": ["/path/to/fissible/seed/mcp/server.py"]
    }
  }
}
```

Replace `/path/to/fissible/seed` with your actual clone path (e.g. `~/lib/fissible/seed`).

**3. Restart Claude Code.**

Claude will now have `seed_name`, `seed_user`, `seed_product`, and all other generators available as tools. When you ask for fake data, it calls the tools instead of hallucinating records — saving tokens and giving you consistent, realistic output.

---

## Compatibility

- **Bash 3.2+** — works on macOS (native bash), Linux, Docker, WSL
- **No external deps** — just `bash`, `awk`, `od`, and standard coreutils
- **MCP server** — requires Python 3.x and `pip3 install mcp`

---

## File map

```
seed/
├── seed.sh              ← entrypoint (library + CLI)
├── src/
│   ├── scalar.sh        ← name, email, uuid, date, number, lorem, ip, url, bool
│   ├── record.sh        ← user, address, company + format helpers
│   ├── ecommerce.sh     ← product, category, order, order_item, coupon, cart
│   ├── crm.sh           ← contact, lead, deal, activity, note, tag
│   └── tui.sh           ← filenames, dirtree, menu_items
├── data/                ← names, domains, cities, nouns, adjectives, lorem…
├── mcp/
│   ├── server.py        ← FastMCP adapter (one tool per generator)
│   └── requirements.txt
└── tests/
    ├── unit/            ← per-module bash tests (146 assertions)
    ├── integration/     ← end-to-end CLI tests
    └── mcp/             ← Python unit tests for the MCP adapter
```

---

## License

MIT — use it, fork it, embed it.
