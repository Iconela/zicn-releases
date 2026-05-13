# Security Policy

## Reporting a vulnerability

Email: **security@iconela.ai**

Please **do not** open a public GitHub issue for vulnerabilities. We aim to:
- Acknowledge receipt within 1 business day
- Provide a fix or mitigation timeline within 5 business days
- Coordinate disclosure with the reporter

## Verifying release integrity

Every release published in this repository is reproducible from the source repository (`iconela/zicn`, private) and the build chain logged in GitHub Actions. Two integrity layers are available:

### 1. SHA-256 hashes (always available)

[`manifest.json`](manifest.json) contains the SHA-256 hash of every cofile and datafile in each release. Before importing into your SAP system:

```bash
# Linux/Mac
sha256sum K905330.Q01 R905330.Q01

# Windows PowerShell
Get-FileHash K905330.Q01, R905330.Q01 -Algorithm SHA256
```

Compare the output against the `sha256` field for that version in `manifest.json`. If the hashes don't match, **do not import** — contact `security@iconela.ai`.

A helper script is provided: [`scripts/verify_release.ps1`](scripts/verify_release.ps1) (PowerShell) and [`scripts/verify_release.sh`](scripts/verify_release.sh) (bash).

### 2. Signed git tags (from v0.22.0 onwards)

Tags are signed with the Iconela release GPG key. Public key fingerprint:

```
TBD — published after first signed release
```

Verify via `git tag -v v0.22.0` after cloning this repo. GitHub also displays a "Verified" badge on signed commits/tags in the web UI.

## What's in the package

Each release contains only:
- **cofile** (`K<num>.<SID>`): transport metadata (TADIR entries, object keys). Plain text, ABAP-readable.
- **datafile** (`R<num>.<SID>`): object payload (source code, DDIC definitions). Binary, ABAP TR format.

There are **no executables, no binaries, no auto-run scripts** in the distribution. The only way to install is via the standard SAP transport tooling (STMS_IMPORT), which requires explicit basis admin action and logs every step to STMS history.

## What ZICN does at runtime

Once installed, ZICN exposes ~19 HTTP domains (catalog in cockpit). Behavior summary:

- **Read-only by default**: most domains (system, search, dict, deps, data preview, spro, cockpit) only query SAP metadata.
- **Mutating domains** (source, class, transport, forms, styles): require valid SAP user with `S_DEVELOP` authorization. Caller is the authenticated SICF user — ZICN does **not** elevate privileges.
- **Audit logging**: every call is logged in table `ZICN_T_LOG` with user, domain, action, success, duration, response size. The cockpit Logs tab surfaces this for inspection.
- **No outbound HTTP from ABAP**: ZICN does not initiate connections to external hosts. Updates discovery (`cockpit/updates`) is performed by the **browser** of the user viewing the cockpit, not by the ABAP server.
- **No telemetry to Iconela**: ZICN does not phone home. The only outbound traffic happens if a basis admin/developer's browser fetches `manifest.json` from this repo while on the Updates tab.

## What the cockpit can NOT do

- Import transports (always requires STMS_IMPORT in customer's SAP)
- Modify SICF service definitions or authorization objects
- Read user passwords, system parameters not exposed via standard ABAP RFC, or filesystem outside SAP-allowed paths
- Bypass SAP authorization (every action goes through `AUTHORITY-CHECK` or BAPI auth)

## Reproducible builds

Source-to-binary reproducibility is **not yet** guaranteed for ABAP transports — SAP's transport format includes timestamps and depends on the build system's ABAP platform version. We're tracking this. For now, integrity is established by SHA-256 + signed tags + GitHub Actions provenance attestation (see `.github/workflows/publish.yml`).
