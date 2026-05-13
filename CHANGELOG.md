# Changelog

All notable changes to ZICN are documented here. Format roughly follows [Keep a Changelog](https://keepachangelog.com/), versioning is [SemVer](https://semver.org/).

Each entry corresponds to a GitHub Release tag and a SAP Transport Request (TR) bundled here.

---

## [0.21.0] — 2026-05-13 (TR `Q01K905330`)

### Added
- **Cockpit web UI** at `/sap/bc/icf/iconela/v1/cockpit/ui` — single-page dashboard for basis admins with tabs:
  - **Dashboard**: version, build, SID/client, host, calls today, list of registered domains with smoke status
  - **Logs**: live tail of `ZICN_T_LOG` with filters (user, domain, limit)
  - **Updates**: dynamic update discovery via this repo's manifest (introduced same release)
  - **Tools**: ad-hoc endpoint tester + health report bundle for support tickets
- **Cockpit domain** with 3 JSON actions (`info`, `smoke`, `logs`) + 1 HTML action (`ui`)
- **V2 authorization mode** via new class `ZICN_CL_AUTH_NULL` — defers entirely to SAP native auth (SICF user + standard `S_DEVELOP` / `S_TABU_DIS` / object-level checks). Eliminates the dependency on `ZICN_T_ACL` admin table for clients that don't want a parallel ACL layer.
- Pre-flight SYNTAX-CHECK in `upsert_source` — blocks `INSERT REPORT` if source has syntax errors. Returns structured `SYNTAX_ERROR` envelope with line/word/message.

### Fixed
- **CRITICAL**: ZICN was activating ABAP code with syntax errors. Root cause: `RS_WORKING_OBJECTS_ACTIVATE` returns `sy-subrc=0` even when the object stays inactive with errors. Pre-flight syntax check now blocks the bad write before it reaches activation. Customer impact: clients running ZICN ≤ 0.20 should upgrade ASAP — affects any AI agent that calls source writers.
- Pre-flight SYNTAX-CHECK was over-eager and rejected valid INCLUDE writes ("REPORT/PROGRAM statement is missing"). Now wrapped in IF guard to skip for subc `I` (include), `F` (FG include), `K` (class include), `J` (interface include), `T` (type pool) — none of these have a standalone REPORT statement.
- Cockpit JS: `const API = "../v1"` resolved to `/sap/bc/icf/iconela/v1/v1/cockpit/info` (double `v1`) → "Domain not implemented". Replaced with `location.pathname.replace(/\/cockpit\/ui\/?$/, "")` for robust dynamic resolution regardless of mount path.
- `cockpit/info` `callsToday` rendered with locale thousands separator (`4.516` instead of `4516`). Switched to NUMC trick (`shift left deleting leading 0`) to emit clean integer.

### Notes
- Requires ABAP Platform ≥ 7.40 (uses string templates, inline declarations, `cl_http_utility=>decode_x_base64`)
- Cockpit HTML SPA has zero CDN dependencies (vanilla JS, inline CSS) — works on air-gapped systems for the Dashboard/Logs/Tools tabs; only Updates tab requires browser internet access to fetch this manifest

---

## [0.20.x and earlier]

Not distributed via this repo. Historical changelog lives in the private `iconela/zicn` repo. Contact `support@iconela.ai` for sprint-by-sprint changelog if needed.

Key milestones:
- **0.20.x** (May 2026): Adobe Forms domain (`adobe/check_ads`, `adobe/preview`, `adobe/upload`), SPRO IMG full-tree dump with cross-tree orphan resolution (`STREE_HIERARCHY_READ_ALL_SUBS`).
- **0.19.x** (May 2026): Forms/Styles parity (preview, upload, lifecycle).
- **0.18.x**: Tier 1 quick wins — 4 endpoints (CDS, package, transport variants).
- **0.17.x and below**: Sprint 4 N+3 — DDIC (TABL, TTYP, SHLP, ENQU), function-group creation, class shell + method add.

[0.21.0]: https://github.com/Iconela/zicn-releases/releases/tag/v0.21.0
