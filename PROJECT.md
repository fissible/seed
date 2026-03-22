# seed — Project Tracker

## Status

| Issue | Title | Effort | Status |
|---|---|---|---|
| — | scalar generators (name, email, phone, uuid, date, number, lorem, ip, url, bool) | L | closed |
| — | shared helpers (seed.sh, _seed_parse_flags, assert-ext.sh) | M | closed |
| — | record generators (user, address, company, db_credentials) | L | closed |
| — | ecommerce generators (product, category, order, order_item, coupon, cart) | L | closed |
| — | CRM generators (contact, lead, deal, activity, note, tag) | L | closed |
| — | geo generators (coordinates, country) | S | closed |
| — | finance generators (credit_card) | M | closed |
| — | devops generators (log_entry, error_log, api_key) | M | closed |
| — | TUI generators (filenames, dirtree, menu_items) | M | closed |
| — | MCP server adapter (FastMCP, one tool per generator) | M | closed |
| — | `seed new custom-schema` interactive wizard | M | closed |
| — | `seed_custom` — custom schema engine (reads .seed files) | L | open |
| — | `--help` flag | S | open |

**Effort key:** XS (<1h), S (1–2h), M (~half day), L (~1 day), XL (2–3 days)

---

## Session handoff notes

**Last updated:** 2026-03-22

### Completed this session

- **Schema wizard** (`bash seed.sh new custom-schema`): interactive terminal wizard that collects a table name and fields (with generator selection and per-field flag prompts) and writes a `.seed` file to `tests/fixtures/`.
  - `src/new.sh` — 4 functions: `_seed_new_infer_sql_type`, `_seed_new_build_schema`, `seed_new` dispatcher, `_seed_new_custom_schema`
  - `tests/unit/test-new.sh` — 25 assertions (13 SQL type mappings, 9 builder assertions, 3 dispatcher routing)
  - `tests/fixtures/.gitkeep` — ensures directory is tracked
  - Full test suite: 300/300 passing (12 suites)
- Design docs committed: `docs/superpowers/specs/2026-03-22-schema-wizard-design.md`, `docs/superpowers/plans/2026-03-22-schema-wizard.md`
- `.gitignore` created (`.worktrees/`, `.claude/`, `__pycache__/`)

### Next task

**`seed_custom`** — custom schema engine that reads `.seed` files and produces JSON/KV/CSV/SQL output. Spec location: `docs/superpowers/specs/2026-03-22-custom-schema-engine-design.md`. The wizard already writes the correct `.seed` format; `seed_custom` is the consumer.

**Prerequisite:** `--schema` flag must be added to `_seed_parse_flags` in `seed.sh` before `seed_custom` can be wired into the CLI (unknown flags → exit 2).

### Decisions made

- `seed new custom-schema` routes via `seed_new` dispatcher (same pattern as all other generators — no changes to `_seed_cli`)
- `lorem` mutual exclusion handled at wizard level (only prompt for Sentences when Words is blank)
- Per-field flags: omit flag when value equals the generator default (not just when blank)
- `trap ... exit 1` (not `return 1`) for bash 3.2 compatibility in interactive wizard
- `tests/fixtures/` created now (wizard needs it for branch-1 auto-write)

### Blockers

None.
