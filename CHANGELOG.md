# Changelog

All notable changes to ZICN are documented here. Format roughly follows [Keep a Changelog](https://keepachangelog.com/), versioning is [SemVer](https://semver.org/).

Each entry corresponds to a GitHub Release tag and a SAP Transport Request (TR) bundled here.

---

## [Unreleased — v0.21.0] — pending TR `Q01K905330`

Tracked in this repo's manifest as `channel: rc` until released.

### Will add
- **Cockpit web UI** at `/sap/bc/icf/iconela/v1/cockpit/ui` — single-page dashboard for basis admins (Dashboard / Logs / Updates / Tools)
- **Cockpit domain** with 3 JSON actions (`info`, `smoke`, `logs`) + 1 HTML action (`ui`)
- **V2 authorization mode** via new class `ZICN_CL_AUTH_NULL` — defers entirely to SAP native auth (SICF user + `S_DEVELOP` / `S_TABU_DIS` / object-level checks). Removes the dependency on `ZICN_T_ACL` admin table for clients that don't want a parallel ACL layer.
- Pre-flight SYNTAX-CHECK in `upsert_source` — blocks `INSERT REPORT` if source has syntax errors. Returns structured `SYNTAX_ERROR` envelope with line/word/message.

### Will fix
- **CRITICAL**: ZICN was activating ABAP code with syntax errors. Root cause: `RS_WORKING_OBJECTS_ACTIVATE` returns `sy-subrc=0` even when the object stays inactive with errors. Pre-flight syntax check now blocks the bad write before it reaches activation.
- Pre-flight SYNTAX-CHECK was over-eager and rejected valid INCLUDE writes ("REPORT/PROGRAM statement is missing"). Now wrapped in IF guard to skip for subc `I` (include), `F` (FG include), `K` (class include), `J` (interface include), `T` (type pool).
- Cockpit JS: `const API = "../v1"` resolved to `/sap/bc/icf/iconela/v1/v1/cockpit/info` (double `v1`) → "Domain not implemented". Replaced with `location.pathname.replace(/\/cockpit\/ui\/?$/, "")` for robust dynamic resolution.
- `cockpit/info` `callsToday` rendered with locale thousands separator. Switched to NUMC trick to emit clean integer.

---

## [0.20.0] — 2026-05-12 (TR `Q01K905147`)

First release distributed via this repo. Baseline of the ZICN service as deployed to Sumol DEC.

### Included
- 33 production ZICN objects: HTTP handler (`ZICN_CL_HTTP_HANDLER`), service interface (`ZICN_IF_SERVICE`), domain implementations for **system, search, program, source, class, syntax, dict, deps, data, package, transport, spro, func, forms, adobe, styles, debug, cds**
- ICF service `/sap/bc/icf/iconela/` registered, V1 API path conventions
- Authorization layer based on `ZICN_T_ACL` table (V1 auth model)
- Audit logging in `ZICN_T_LOG`
- Built on ABAP Platform 7.58 (S/4HANA 2023, S4CORE 108, SAP_BASIS 758)

### Notes
- This package mirrors the version that was successfully imported into Sumol DEC (mandante 888) on 2026-05-12 via STMS_IMPORT
- Does NOT include the cockpit UI, V2 auth, or the pre-flight syntax-check hotfix — those land in v0.21.0 (TR Q01K905330, see Unreleased above)

---

## Pre-distribution history

Earlier ZICN versions (0.19.x and below) were never published through this repo. Historical changelog lives in the private `iconela/zicn` source repository. Contact `support@iconela.ai` for sprint-by-sprint detail if needed.

Key milestones (for context):
- **0.19.x → 0.20.x** (early May 2026): Adobe Forms domain (`adobe/check_ads`, `adobe/preview`, `adobe/upload`), SPRO IMG full-tree dump with cross-tree orphan resolution (`STREE_HIERARCHY_READ_ALL_SUBS`)
- **0.18.x → 0.19.x**: Forms/Styles parity (preview, upload, lifecycle)
- **0.17.x → 0.18.x**: Tier 1 quick wins — CDS, package, transport variants
- **0.17.x and below**: Sprint 4 N+3 — DDIC (TABL, TTYP, SHLP, ENQU), function-group creation, class shell + method add

[0.20.0]: https://github.com/Iconela/zicn-releases/releases/tag/v0.20.0
