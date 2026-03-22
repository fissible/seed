# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).
Version bumps are derived from commit types since the previous release tag:
- `feat:` → minor bump
- `fix:` → patch bump
- `feat!:` / `BREAKING CHANGE:` → major bump

---

## [1.1.0] - 2026-03-22

### Added
- `seed new custom-schema` — interactive terminal wizard for creating `.seed` schema files
- `seed custom` — custom schema engine: reads `.seed` files, generates records in all 4 output formats
- `--schema` flag added to `_seed_parse_flags` (required by `seed custom`)
- `tests/fixtures/example.seed` — reference schema shipped with the repo
- `seed_custom` MCP tool
- `--help` / `-h` flag: lists all 42 generators grouped by category and all flags

### Fixed
- MCP server path in `.mcp.json` corrected from placeholder to absolute path

---

## [1.0.0] - 2026-03-22

### Added
- 37 generators across 8 categories: scalar (name, email, phone, uuid, date, number, lorem, ip, url, bool, host, port, password), record (user, address, company, db_credentials), ecommerce (product, category, order, order_item, coupon, cart), CRM (contact, lead, deal, activity, note, tag), geo (coordinates, country), finance (credit_card), devops (log_entry, error_log, api_key), TUI (filenames, dirtree, menu_items)
- 4 output formats: `json`, `kv`, `csv`, `sql`
- MCP server adapter via FastMCP — one tool per generator
- LCG-based reproducible RNG with `--seed` flag
- Bash 3.2+ compatible throughout (no `declare -A`, no `+=`, no `mapfile`)
- Full test suite: unit, integration, and MCP tests via ptyunit
