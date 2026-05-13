#!/usr/bin/env bash
# Verify SHA-256 of downloaded ZICN release against published manifest.
#
# Usage:
#   ./verify_release.sh 0.21.0 K905330.Q01 R905330.Q01
#
# Optional env: ZICN_MANIFEST_URL (default = main branch raw URL)
set -euo pipefail

VERSION="${1:?usage: $0 <version> <cofile> <datafile>}"
COFILE="${2:?usage: $0 <version> <cofile> <datafile>}"
DATAFILE="${3:?usage: $0 <version> <cofile> <datafile>}"
MANIFEST_URL="${ZICN_MANIFEST_URL:-https://raw.githubusercontent.com/Iconela/zicn-releases/main/manifest.json}"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
fail()  { red "FAIL: $*"; exit 1; }

[ -f "$COFILE"   ] || fail "cofile not found: $COFILE"
[ -f "$DATAFILE" ] || fail "datafile not found: $DATAFILE"

echo "Fetching manifest from $MANIFEST_URL ..."
manifest=$(curl -fsSL --max-time 30 "$MANIFEST_URL")

# extract release entry via jq (recommended) or python fallback
if command -v jq >/dev/null 2>&1; then
    release=$(echo "$manifest" | jq -r --arg v "$VERSION" '.releases[] | select(.version == $v)')
    [ -n "$release" ] || fail "version $VERSION not found in manifest"
    expected_co=$(echo "$release" | jq -r '.files.cofile.sha256')
    expected_dt=$(echo "$release" | jq -r '.files.datafile.sha256')
    tr=$(echo "$release" | jq -r '.tr')
    ch=$(echo "$release" | jq -r '.channel')
    rel_at=$(echo "$release" | jq -r '.releasedAt')
else
    py=$(cat <<'PY'
import sys, json
m = json.load(sys.stdin)
v = sys.argv[1]
for r in m.get("releases", []):
    if r["version"] == v:
        print(f"{r['files']['cofile']['sha256']}|{r['files']['datafile']['sha256']}|{r.get('tr','')}|{r.get('channel','')}|{r.get('releasedAt','')}")
        sys.exit(0)
sys.exit(2)
PY
)
    parsed=$(echo "$manifest" | python3 -c "$py" "$VERSION") || fail "version $VERSION not found in manifest"
    IFS='|' read -r expected_co expected_dt tr ch rel_at <<< "$parsed"
fi

echo
echo "Release: v$VERSION (TR $tr, channel=$ch, $rel_at)"
echo

case "$expected_co" in
    PENDING|PENDING_FIRST_RELEASE)
        fail "manifest has placeholder sha256 for v$VERSION - not yet published"
        ;;
esac

actual_co=$(sha256sum "$COFILE"   | awk '{print $1}')
actual_dt=$(sha256sum "$DATAFILE" | awk '{print $1}')

echo "Cofile   ($COFILE):"
echo "  expected: $expected_co"
echo "  actual:   $actual_co"
[ "$actual_co" = "$expected_co" ] && green "  OK cofile matches" || fail "cofile SHA-256 mismatch - DO NOT IMPORT"

echo "Datafile ($DATAFILE):"
echo "  expected: $expected_dt"
echo "  actual:   $actual_dt"
[ "$actual_dt" = "$expected_dt" ] && green "  OK datafile matches" || fail "datafile SHA-256 mismatch - DO NOT IMPORT"

echo
green "All checks passed. Safe to STMS_IMPORT."
echo "Next: see README.md section 'How to apply a release'"
