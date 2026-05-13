# ZICN Releases

Public release distribution for the **ZICN ABAP service** (Iconela's headless ABAP API exposed via SICF). Each release is a SAP transport pair (cofile + datafile) that customer basis admins import into their SAP system via STMS.

> **For end users**: open the **Cockpit → Updates** tab in your installed ZICN instance — it pulls this repo's `manifest.json` automatically and shows you which release is current vs latest, with one-click downloads.
>
> **For Iconela team**: see [`docs/release_process.md`](docs/release_process.md) for the cut-a-release runbook.

---

## What is ZICN

ZICN is a custom Z-namespace ABAP service that exposes ~19 domains (system, source, class, syntax, transport, data, spro, forms, styles, adobe, cockpit, …) over HTTP/JSON. It powers Iconela's AI integrations (SAP Helper desktop app, Claude/ChatGPT MCP servers, custom agents) by giving them a stable, audit-logged, authorization-aware API into ABAP development objects and runtime data.

Runs on **ECC 6.0 EHP7+** and **S/4HANA 1909+**, **ABAP Platform ≥ 7.40**. No third-party libraries, no CDN dependencies — vanilla ABAP + native SICF.

---

## How to apply a release (basis admin)

Each release ships two files attached to the GitHub release page:

| File | Purpose | Destination on SAP application server |
|---|---|---|
| `K<num>.<SID>` | **Cofile** (transport metadata) | `/usr/sap/trans/cofiles/` |
| `R<num>.<SID>` | **Datafile** (object payload) | `/usr/sap/trans/data/` |

Where `<num>` is the TR number (e.g. `905330`) and `<SID>` is the system ID of Iconela's build system (currently `Q01`). The destination filename **does not** need to be renamed for the target system.

### Step-by-step

1. **Download** cofile + datafile from the GitHub release page for the version you want
2. **Verify SHA-256** matches the manifest (optional but recommended):
   ```bash
   sha256sum K905330.Q01 R905330.Q01
   ```
   Compare with the `sha256` values in [`manifest.json`](manifest.json).
3. **Upload to SAP app server**:
   - SAP GUI → **CG3Z** → choose destination `/usr/sap/trans/cofiles/` for the `K*` file and `/usr/sap/trans/data/` for the `R*` file. Binary mode.
   - OR via OS (SSH/WinSCP as `<sid>adm` or root): `scp` then `chown <sid>adm:sapsys` + `chmod 660`
4. **Add to import queue**: transaction **STMS_IMPORT** (or `STMS_QA`) → menu **Extras → Other Requests → Add** → enter the TR number from the manifest → confirm
5. **Import**: select the TR in the import queue → click the truck icon → confirm import options. Typical safe options: Overwrite originals = ✓, Ignore invalid component version = ✓ (only if RC=8 from version mismatch)
6. **Verify** in **STMS_IMPORT_HIST** → RC=0 expected
7. **Confirm new version**: refresh the ZICN Cockpit (`/sap/bc/icf/iconela/v1/cockpit/ui`) → Dashboard should now show the new version

### Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| RC=8 on import "Program ID and object type mismatch" | Older S/4 vs ECC TADIR diff | Re-import with "Ignore invalid component version" |
| RC=12 "Source code line too long" | TR contains long includes built on newer ABAP platform | Check `compat.abapPlatform` in manifest — your system may be too old |
| Cockpit still shows old version after import | ICF service cache | SE80 → SICF → `/sap/bc/icf/iconela` → Service → "Refresh" |
| Activation errors in import log | DDIC / class dependencies pending | Re-run STMS_IMPORT for the same TR — usually resolves on second pass |

---

## Manifest schema

Cockpits fetch [`manifest.json`](manifest.json) via `https://raw.githubusercontent.com/Iconela/zicn-releases/main/manifest.json`. Schema:

```json
{
  "schemaVersion": 1,
  "product": "zicn",
  "publisher": "Iconela",
  "publishedAt": "ISO-8601 timestamp of latest manifest update",
  "latest": "semver of latest stable release",
  "channels": ["stable", "beta", "rc"],
  "releases": [
    {
      "version": "0.21.0",
      "channel": "stable",
      "releasedAt": "YYYY-MM-DD",
      "tr": "Q01K905330",
      "minZicnVersion": "0.18",
      "compat": {
        "sapSystem": ["ECC 6.0 EHP7+", "S/4HANA 1909+"],
        "abapPlatform": ">=7.40"
      },
      "highlights": ["Human-readable bullet list of major changes"],
      "breaking": false,
      "files": {
        "cofile":   { "url": "...", "size": 0, "sha256": "..." },
        "datafile": { "url": "...", "size": 0, "sha256": "..." }
      },
      "releaseNotesUrl": "https://github.com/Iconela/zicn-releases/releases/tag/v0.21.0"
    }
  ]
}
```

The manifest is **append-only** for `releases[]`: old versions stay so customers can pin or rollback. `latest` always points to the newest `channel: stable` entry.

---

## Versioning policy

- **SemVer** strictly: `MAJOR.MINOR.PATCH`
- `MAJOR` bumps = breaking change (action removed, response schema incompatible). `breaking: true` set in manifest.
- `MINOR` bumps = new domain/action, backward-compatible
- `PATCH` bumps = bug fix only
- Each release is its own immutable git tag. Tags are signed (see [`SECURITY.md`](SECURITY.md))

## Channels

- `stable` — production, default channel; cockpit shows these
- `beta` — opt-in via cockpit setting `updates.channel = "beta"` (not yet implemented)
- `rc` — release candidate, internal Iconela testing

## License & support

Commercial license. Customer entitlement and support contracts are managed via the Iconela portal. For support: `support@iconela.ai`.

This repo is intentionally **public** so that any basis admin can verify provenance, SHA-256, and history of releases without needing an Iconela account. Source code of ZICN itself is **not** open source — only the transport packages are distributed here.

## Related

- ZICN source repository (private): `iconela/zicn`
- Iconela platform docs: https://docs.iconela.ai
- SAP Helper desktop app (consumer of ZICN): https://saphelper.iconela.ai
