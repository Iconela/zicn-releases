<#
.SYNOPSIS
    Iconela team script: cut a new ZICN release from a SAP TR.

.DESCRIPTION
    Pulls cofile + datafile from the SAP application server (via CG3Y over SAP RFC
    OR SCP if you have shell access), regenerates manifest.json, commits the manifest,
    tags the repo, pushes the tag, and uploads assets to a GitHub release.

    Prerequisites:
      - Local clone of Iconela/zicn-releases (this repo)
      - `gh` CLI authenticated for the iconela org (gh auth login)
      - Python 3 in PATH
      - SCP or SAP GUI access to download the TR files

.EXAMPLE
    .\release_zicn.ps1 -Version 0.22.0 -Tr Q01K905340 `
        -CofilePath C:\Temp\K905340.Q01 -DatafilePath C:\Temp\R905340.Q01 `
        -Highlights "Fix X","New feature Y","Bug 47 resolved"

.EXAMPLE
    # Dry-run (manifest update only, no git push, no gh release):
    .\release_zicn.ps1 -Version 0.22.0 -Tr Q01K905340 `
        -CofilePath C:\Temp\K905340.Q01 -DatafilePath C:\Temp\R905340.Q01 `
        -Highlights "..." -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Version,
    [Parameter(Mandatory=$true)][string]$Tr,
    [Parameter(Mandatory=$true)][string]$CofilePath,
    [Parameter(Mandatory=$true)][string]$DatafilePath,
    [Parameter(Mandatory=$true)][string[]]$Highlights,
    [string]$Channel = "stable",
    [string]$BuildLabel = "",
    [string]$MinVersion = "0.18.0",
    [switch]$Breaking,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Step($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }

# 1. Sanity checks
Step 1 "Sanity checks"
if (-not (Test-Path $CofilePath))   { throw "cofile not found: $CofilePath" }
if (-not (Test-Path $DatafilePath)) { throw "datafile not found: $DatafilePath" }
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "version must be semver: $Version" }
if ($Tr -notmatch '^[A-Z]\d{2}[A-Z]\d{6}$') { throw "TR format must be like Q01K905340: $Tr" }
$existing = git tag --list "v$Version"
if ($existing) { throw "tag v$Version already exists locally - bump version" }

# 2. Regenerate manifest
Step 2 "Regenerating manifest.json"
$breakingFlag = if ($Breaking) { '--breaking' } else { '' }
$hlArgs = $Highlights | ForEach-Object { '"' + ($_ -replace '"','`"') + '"' }
$cmd = "python scripts/gen_manifest.py --version $Version --tr $Tr --channel $Channel --min-version $MinVersion --build-label `"$BuildLabel`" $breakingFlag --cofile `"$CofilePath`" --datafile `"$DatafilePath`" --highlights $($hlArgs -join ' ')"
Write-Host "  $cmd"
Invoke-Expression $cmd
if ($LASTEXITCODE -ne 0) { throw "gen_manifest.py failed with exit $LASTEXITCODE" }

# 3. Stage manifest
Step 3 "Staging manifest in git"
git add manifest.json CHANGELOG.md 2>$null
$diff = git diff --cached --stat
if (-not $diff) { Write-Host "  (no changes staged)" } else { Write-Host $diff }

if ($DryRun) {
    Step "DRY" "DryRun set - stopping before commit/tag/push"
    Write-Host "  Would commit: 'Release v$Version ($Tr)'"
    Write-Host "  Would tag:    v$Version"
    Write-Host "  Would create GH release with assets:"
    Write-Host "    - $CofilePath"
    Write-Host "    - $DatafilePath"
    exit 0
}

# 4. Commit
Step 4 "Committing"
git commit -m "Release v$Version ($Tr)" -m "$(($Highlights | ForEach-Object { "- $_" }) -join "`n")"

# 5. Tag (signed if user has gpg configured)
Step 5 "Tagging v$Version"
$gpgKey = git config user.signingkey
if ($gpgKey) {
    Write-Host "  GPG key configured ($gpgKey) - creating signed tag"
    git tag -s "v$Version" -m "ZICN v$Version - $Tr"
} else {
    Write-Host "  no GPG signing key - creating annotated tag (see SECURITY.md to set up)"
    git tag -a "v$Version" -m "ZICN v$Version - $Tr"
}

# 6. Push commit + tag
Step 6 "Pushing to origin"
git push origin HEAD "v$Version"

# 7. Create GH release with assets
Step 7 "Creating GitHub release"
$notes = @"
**TR**: ``$Tr``
**Build label**: ``$BuildLabel``
**Channel**: ``$Channel``

## Highlights

$(($Highlights | ForEach-Object { "- $_" }) -join "`n")

## How to install

See [README.md - How to apply a release](https://github.com/Iconela/zicn-releases#how-to-apply-a-release).

Verify integrity before STMS_IMPORT:
``````powershell
.\scripts\verify_release.ps1 -Version $Version -Cofile K$((($Tr -split 'K')[1])).$((($Tr.Substring(0,3)))) -Datafile R$((($Tr -split 'K')[1])).$((($Tr.Substring(0,3))))
``````
"@
$notesFile = New-TemporaryFile
Set-Content -Path $notesFile -Value $notes -Encoding UTF8
gh release create "v$Version" $CofilePath $DatafilePath `
    --title "ZICN v$Version" `
    --notes-file $notesFile `
    --repo Iconela/zicn-releases
Remove-Item $notesFile

Write-Host "`nDone. https://github.com/Iconela/zicn-releases/releases/tag/v$Version" -ForegroundColor Green
