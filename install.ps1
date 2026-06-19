#requires -Version 5.1
<#
    Windows installer for pycemrg-context.

    Copy-based counterpart to install.sh. Unlike the Unix script (which
    symlinks), this copies files into %USERPROFILE%\.claude. Copies require no
    Developer Mode / admin privileges, so they work on any Windows account.

    Trade-off: copies are a point-in-time snapshot. Re-run this script after
    `git pull` to refresh the installed files.
#>

$ErrorActionPreference = "Stop"

$RepoDir     = $PSScriptRoot
$ClaudeDir   = Join-Path $env:USERPROFILE ".claude"
$CommandsDir = Join-Path $ClaudeDir "commands"
$SkillsDir   = Join-Path $ClaudeDir "skills"
$PycemrgDir  = Join-Path $ClaudeDir "pycemrg-context"
$SourceDir   = Join-Path $PycemrgDir "source"

function Ensure-Dir($path) {
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }
}

# Copy a single file, overwriting any existing copy. Overwrite is intentional:
# re-running after `git pull` is how copy-mode installs pick up updates.
function Copy-File($src, $dst) {
    Copy-Item -LiteralPath $src -Destination $dst -Force
    Write-Host "  copied   $dst" -ForegroundColor Green
}

# Copy a directory tree, replacing any existing copy at the destination.
function Copy-Dir($src, $dst) {
    if (Test-Path -LiteralPath $dst) {
        Remove-Item -LiteralPath $dst -Recurse -Force
    }
    Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
    Write-Host "  copied   $dst" -ForegroundColor Green
}

Write-Host ""
Write-Host "Installing pycemrg-context into $ClaudeDir"
Write-Host ""

Ensure-Dir $CommandsDir
Ensure-Dir $PycemrgDir
Ensure-Dir $SourceDir
Ensure-Dir $SkillsDir

# Commands
Get-ChildItem -LiteralPath (Join-Path $RepoDir "commands") -Filter "*.md" -File |
    ForEach-Object {
        Copy-File $_.FullName (Join-Path $CommandsDir $_.Name)
    }

# Skills (each is a directory containing SKILL.md). Guarded so updating an older
# checkout that predates any skill still installs cleanly: absent or invalid
# skill dirs are simply skipped.
foreach ($skill in @("pycemrg-docs")) {
    $skillSrc = Join-Path $RepoDir $skill
    if (-not (Test-Path -LiteralPath $skillSrc -PathType Container)) { continue }
    if (-not (Test-Path -LiteralPath (Join-Path $skillSrc "SKILL.md"))) { continue }
    Copy-Dir $skillSrc (Join-Path $SkillsDir $skill)
}

# Data files
Copy-File (Join-Path $RepoDir "LIBRARY_REGISTRY.md") (Join-Path $PycemrgDir "LIBRARY_REGISTRY.md")
Copy-File (Join-Path $RepoDir "PYCEMRG_SUITE.md")    (Join-Path $PycemrgDir "PYCEMRG_SUITE.md")

# Source files (if any exist yet)
$repoSource = Join-Path $RepoDir "source"
if (Test-Path -LiteralPath $repoSource -PathType Container) {
    Get-ChildItem -LiteralPath $repoSource -Filter "*.md" -File |
        ForEach-Object {
            Copy-File $_.FullName (Join-Path $SourceDir $_.Name)
        }
}

Write-Host ""
Write-Host "Done. Start a new Claude Code session to pick up the changes."
Write-Host ""
