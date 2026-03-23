# seed — Project Tracker

## Current version

`v1.1.0` (pending merge + tag) — see `VERSION` and `CHANGELOG.md`

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
| — | `seed new custom-schema` interactive schema wizard | M | closed |
| — | `seed_custom` — custom schema engine (reads .seed files) | L | closed |
| — | `--help` flag | S | closed |

**Effort key:** XS (<1h), S (1–2h), M (~half day), L (~1 day), XL (2–3 days)

---

## Release process

This project uses [Semantic Versioning](https://semver.org) and [Conventional Commits](https://www.conventionalcommits.org).

### Version bump rules (from commits since last tag)

| Commit type | Bump |
|---|---|
| `fix:` | patch (`1.0.0 → 1.0.1`) |
| `feat:` | minor (`1.0.0 → 1.1.0`) |
| `feat!:` or `BREAKING CHANGE:` in footer | major (`1.0.0 → 2.0.0`) |

### Steps to cut a release

1. Determine bump type from `git log <last-tag>..HEAD --oneline`
2. Update `VERSION` to the new version
3. Add a new section to `CHANGELOG.md` with the date and grouped changes
4. Update "Current version" line in this file
5. Commit: `git commit -m "chore: release vX.Y.Z"`
6. Tag: `git tag -a vX.Y.Z -m "vX.Y.Z"`
7. Push: `git push && git push --tags`

### What goes in CHANGELOG.md

Group entries under: **Added**, **Changed**, **Fixed**, **Removed**.
Source from `feat:`, `fix:`, and breaking-change commits only — skip `docs:`, `chore:`, `refactor:`, `test:`.

---

## Session handoff notes

**Last updated:** 2026-03-23

### Completed this session

- **Vendor ptyunit**: copied `assert.sh` + `mock.sh` into `tests/vendor/ptyunit/`
  - All 13 test files updated to source from `$SEED_HOME/tests/vendor/ptyunit/assert.sh`
  - `run.sh` simplified — removed `PTYUNIT_HOME` env var and external dependency check
  - `assert-ext.sh` — removed `assert_contains` (now provided by vendored ptyunit); kept `assert_exit_code` and `assert_not_empty`
  - 347/347 tests pass; suite is now fully self-contained

### Next task

All planned tasks are closed. Next work is likely:
- New generator domains (if needed)
- Improvements driven by real usage of `seed_custom`

### Decisions made

- `seed new custom-schema` routes via `seed_new` dispatcher
- `lorem` mutual exclusion handled at wizard level
- Per-field flags: omit flag when value equals the generator default
- `trap ... exit 1` (not `return 1`) for bash 3.2 compatibility in interactive wizard
- `_seed_cfield_date` uses year-only range (known limitation, consistent with `seed_date`)
- Version strategy: semver + conventional commits + `VERSION` file + annotated git tags
- ptyunit vendored (not submoduled) — test suite self-contained, no sibling-dir dependency
