<#
.SYNOPSIS
    Verify the SHA-256 hashes of downloaded ZICN release files against the manifest.

.DESCRIPTION
    Compares the SHA-256 of local cofile + datafile against the published manifest.json
    for a given version. Exits 0 on match, 1 on mismatch. Run before STMS_IMPORT.

.EXAMPLE
    .\verify_release.ps1 -Version 0.21.0 -Cofile K905330.Q01 -Datafile R905330.Q01

.EXAMPLE
    .\verify_release.ps1 -Version 0.21.0 -Cofile K905330.Q01 -Datafile R905330.Q01 -ManifestUrl https://raw.githubusercontent.com/Iconela/zicn-releases/main/manifest.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Version,
    [Parameter(Mandatory=$true)][string]$Cofile,
    [Parameter(Mandatory=$true)][string]$Datafile,
    [string]$ManifestUrl = "https://raw.githubusercontent.com/Iconela/zicn-releases/main/manifest.json"
)

$ErrorActionPreference = 'Stop'

function Fail($msg) { Write-Host "FAIL: $msg" -ForegroundColor Red; exit 1 }
function Ok($msg)   { Write-Host "  OK: $msg" -ForegroundColor Green }

if (-not (Test-Path $Cofile))   { Fail "cofile not found: $Cofile" }
if (-not (Test-Path $Datafile)) { Fail "datafile not found: $Datafile" }

Write-Host "Fetching manifest from $ManifestUrl ..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$manifest = Invoke-RestMethod -Uri $ManifestUrl -UseBasicParsing -TimeoutSec 30

$release = $manifest.releases | Where-Object { $_.version -eq $Version }
if (-not $release) {
    Fail "version $Version not found in manifest. Available: $(($manifest.releases | ForEach-Object { $_.version }) -join ', ')"
}

Write-Host ""
Write-Host "Release: v$Version (TR $($release.tr), channel=$($release.channel))"
Write-Host "Released: $($release.releasedAt)"
Write-Host ""

$expectedCo = $release.files.cofile.sha256
$expectedDt = $release.files.datafile.sha256

if ($expectedCo -eq 'PENDING' -or $expectedCo -eq 'PENDING_FIRST_RELEASE') {
    Fail "manifest contains placeholder sha256 for v$Version - this version was not properly published yet"
}

$actualCo = (Get-FileHash $Cofile   -Algorithm SHA256).Hash.ToLower()
$actualDt = (Get-FileHash $Datafile -Algorithm SHA256).Hash.ToLower()

Write-Host "Cofile   ($Cofile):"
Write-Host "  expected: $expectedCo"
Write-Host "  actual:   $actualCo"
if ($actualCo -eq $expectedCo.ToLower()) { Ok "cofile hash matches" } else { Fail "cofile SHA-256 mismatch - DO NOT IMPORT" }

Write-Host "Datafile ($Datafile):"
Write-Host "  expected: $expectedDt"
Write-Host "  actual:   $actualDt"
if ($actualDt -eq $expectedDt.ToLower()) { Ok "datafile hash matches" } else { Fail "datafile SHA-256 mismatch - DO NOT IMPORT" }

Write-Host ""
Write-Host "All checks passed. Safe to STMS_IMPORT." -ForegroundColor Green
Write-Host "Next: see README.md section 'How to apply a release'"
exit 0
