#!/usr/bin/env python3
"""Regenerate manifest.json from a release directory.

Usage (manual):
    python scripts/gen_manifest.py --version 0.22.0 --tr Q01K905340 \
        --cofile /path/to/K905340.Q01 --datafile /path/to/R905340.Q01 \
        --highlights "Bug fix X" "New feature Y"

Usage (from GitHub Action, with files already attached to release):
    python scripts/gen_manifest.py --from-release v0.22.0

The script is idempotent: re-running with the same version replaces that
release entry instead of duplicating it. The `latest` field is updated to
match the highest stable version.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MANIFEST = REPO / "manifest.json"
GH_OWNER = "Iconela"
GH_REPO = "zicn-releases"

SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:-([\w.-]+))?$")


def semver_key(v: str) -> tuple:
    m = SEMVER_RE.match(v)
    if not m:
        return (0, 0, 0, "")
    major, minor, patch, pre = m.groups()
    # No pre-release ranks higher than any pre-release
    return (int(major), int(minor), int(patch), pre or "~")


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def file_descriptor(local_path: Path | None, version: str, filename: str) -> dict:
    url = f"https://github.com/{GH_OWNER}/{GH_REPO}/releases/download/v{version}/{filename}"
    if local_path and local_path.exists():
        return {
            "url": url,
            "size": local_path.stat().st_size,
            "sha256": sha256_file(local_path),
        }
    return {"url": url, "size": 0, "sha256": "PENDING"}


def fetch_release_assets(version: str) -> tuple[Path | None, Path | None]:
    """Download cofile + datafile from GH release into /tmp, return paths.

    Used by --from-release mode in the GH Action. Requires `GITHUB_TOKEN` env
    for private repos; public is fine without.
    """
    api = f"https://api.github.com/repos/{GH_OWNER}/{GH_REPO}/releases/tags/v{version}"
    req = urllib.request.Request(api, headers={"Accept": "application/vnd.github+json"})
    tok = os.environ.get("GITHUB_TOKEN")
    if tok:
        req.add_header("Authorization", f"Bearer {tok}")
    with urllib.request.urlopen(req, timeout=30) as r:
        rel = json.load(r)
    cofile = datafile = None
    tmp = REPO / ".tmp_assets"
    tmp.mkdir(exist_ok=True)
    for asset in rel.get("assets", []):
        name = asset["name"]
        url = asset["browser_download_url"]
        dst = tmp / name
        if not dst.exists():
            print(f"  downloading {name} ...")
            urllib.request.urlretrieve(url, dst)
        if name.startswith("K"):
            cofile = dst
        elif name.startswith("R"):
            datafile = dst
    return cofile, datafile


def load_manifest() -> dict:
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    return {
        "schemaVersion": 1,
        "product": "zicn",
        "publisher": "Iconela",
        "publishedAt": "",
        "latest": "",
        "channels": ["stable", "beta", "rc"],
        "releases": [],
    }


def upsert_release(manifest: dict, entry: dict) -> dict:
    rels = [r for r in manifest["releases"] if r["version"] != entry["version"]]
    rels.append(entry)
    rels.sort(key=lambda r: semver_key(r["version"]), reverse=True)
    manifest["releases"] = rels
    stable = [r for r in rels if r.get("channel") == "stable"]
    if stable:
        manifest["latest"] = stable[0]["version"]
    manifest["publishedAt"] = dt.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    return manifest


def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", help="Semver, e.g. 0.22.0")
    ap.add_argument("--channel", default="stable", choices=["stable", "beta", "rc"])
    ap.add_argument("--tr", help="SAP transport request, e.g. Q01K905340")
    ap.add_argument("--build-label", default="")
    ap.add_argument("--min-version", default="0.18.0")
    ap.add_argument("--breaking", action="store_true")
    ap.add_argument("--cofile", type=Path, help="local path to K* cofile")
    ap.add_argument("--datafile", type=Path, help="local path to R* datafile")
    ap.add_argument("--highlights", nargs="*", default=[])
    ap.add_argument("--from-release", help="Pull assets from GH release tag (e.g. v0.22.0)")
    return ap.parse_args()


def main() -> int:
    args = parse_args()

    version = args.version
    cofile = args.cofile
    datafile = args.datafile

    if args.from_release:
        if not version:
            version = args.from_release.lstrip("v")
        cofile, datafile = fetch_release_assets(version)

    if not version:
        print("error: --version is required (or use --from-release vX.Y.Z)", file=sys.stderr)
        return 2

    if not args.tr:
        print("warning: --tr not provided; TR field will be empty", file=sys.stderr)

    # Compose filenames from TR (K905340.Q01 etc) if not derivable from local paths
    tr = args.tr or ""
    num = tr[len("Q01K"):] if tr.startswith("Q01K") else (tr[1:] if tr.startswith("K") else "")
    sid = tr[-3:] if len(tr) >= 3 else "Q01"
    cofile_name = cofile.name if cofile else f"K{num}.{sid}"
    datafile_name = datafile.name if datafile else f"R{num}.{sid}"

    entry = {
        "version": version,
        "channel": args.channel,
        "releasedAt": dt.date.today().isoformat(),
        "tr": tr,
        "buildLabel": args.build_label,
        "minZicnVersion": args.min_version,
        "compat": {
            "sapSystem": ["ECC 6.0 EHP7+", "S/4HANA 1909+"],
            "abapPlatform": ">=7.40",
        },
        "highlights": args.highlights,
        "breaking": args.breaking,
        "files": {
            "cofile":   file_descriptor(cofile, version, cofile_name),
            "datafile": file_descriptor(datafile, version, datafile_name),
        },
        "releaseNotesUrl": f"https://github.com/{GH_OWNER}/{GH_REPO}/releases/tag/v{version}",
    }

    manifest = load_manifest()
    manifest = upsert_release(manifest, entry)
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(f"manifest.json updated. latest={manifest['latest']}, releases={len(manifest['releases'])}")
    print(f"  added/replaced entry: {version} ({args.channel}) TR={tr}")
    print(f"  cofile   sha256={entry['files']['cofile']['sha256'][:16]}... size={entry['files']['cofile']['size']:,}")
    print(f"  datafile sha256={entry['files']['datafile']['sha256'][:16]}... size={entry['files']['datafile']['size']:,}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
