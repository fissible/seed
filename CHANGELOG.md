# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).
## [1.1.0] - 2026-03-22

### Added
- Scaffold src/new.sh and source in seed.sh
- Add _seed_new_infer_sql_type with 12 SQL type mappings
- Add _seed_new_build_schema pure schema content builder
- Add seed_new dispatcher with usage error handling
- Add _seed_new_custom_schema interactive schema wizard
- Add seed_custom engine with .seed schema file support
- Add --help / -h flag listing all generators and flags

### Changed
- Hoist locals, split array declarations, clarify break comments in wizard

### Fixed
- Correct MCP server path from placeholder to absolute path
## [1.0.0] - 2026-03-22

### Added
- Seed.sh CLI dispatcher and flag parser
- Scalar.sh shared helpers
- Scalar generators (name, email, phone, uuid, date, number, lorem, ip, url, bool)
- Record.sh format helpers (json, kv, csv, sql)
- Core record generators (user, address, company)
- Ecommerce generators (product, category, order, order_item, coupon, cart)
- CRM generators (contact, lead, deal, activity, note, tag)
- TUI helpers (filenames, dirtree, menu_items)
- MCP server with all seed_* tools
- Expand first_names, last_names, lorem data files
- Add --seed flag for reproducible output
- Add src/str.sh string helper module (_seed_str_lower_v, _seed_str_slug_v)
- Add _v RNG primitives and refactor scalar generators to fix --seed --count N
- Seed_user coherence — email/username derived from same name fields
- Seed_address and seed_company _v refactor — fix --seed distinctness
- Seed_contact/seed_lead coherence — email derived from same name fields
- Seed_deal/activity/note/tag _v refactor — fix --seed distinctness
- Ecommerce generators _v refactor — fix --seed distinctness, use LCG for dtype
- Tui generators _v refactor — fix --seed distinctness
- Add seed_host, seed_port, seed_password, seed_db_credentials generators
- Add countries and error_messages data files
- Add _seed_random_datetime_v helper to scalar.sh
- Add --prefix flag to _seed_parse_flags
- Add seed_coordinates and seed_country generators (geo.sh)
- Add seed_credit_card generator with Luhn-valid numbers (finance.sh)
- Add seed_log_entry, seed_error_log, seed_api_key generators (devops.sh)
- Add geo, finance, devops, and db_credentials tools to MCP server

### Changed
- Cache data files in _seed_random_line to avoid repeated file reads

### Fixed
- Add missing-value guards and tests to _seed_parse_flags
- Use PID+RANDOM as awk srand seed to avoid repeated values
- Ecommerce.sh word-split bug in seed_order, remove redundant cart sql guard
- Crm.sh rename activity date field, add contact test coverage
- Replace duplicate last names with 50 genuinely new entries
- Replace per-call awk seeding with global LCG RNG state
- Seed_date now generates days 29-31 with correct leap-year logic
- Resolve stack_trace json-escape contradiction and datetime comment
- Remove frame double-quotes and use array for st_args
- Clarify stack_trace json escaping and remove stale st_args bullet
- Credit card JSON example and CSV/SQL test assertions
- Correct Vatican City ISO code (VA) and UAE full name
- Document datetime_v lower bound and correct variety test comment
- Move _seed_rng_init before loop in seed_coordinates

