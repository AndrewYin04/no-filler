<#
.SYNOPSIS
  Install the no-filler writing skill for Claude Code by linking
    ~/.claude/skills/no-filler  ->  <this repo>/skills/no-filler

.DESCRIPTION
  Tries a real symbolic link first (needs Developer Mode or an elevated shell)
  and falls back to a directory junction, which needs neither. Claude Code
  follows both.

.EXAMPLE
  .\install.ps1
  .\install.ps1 -Uninstall
#>
[CmdletBinding()]
param(
  [switch]$Uninstall,
  [string]$SkillsDir = $(if ($env:CLAUDE_SKILLS_DIR) { $env:CLAUDE_SKILLS_DIR } else { Join-Path $HOME ".claude\skills" })
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here "skills\no-filler"
$dest = Join-Path $SkillsDir "no-filler"

function Test-IsLink([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { return $false }
  $item = Get-Item -LiteralPath $p -Force
  return ($null -ne $item.LinkType)
}

if ($Uninstall) {
  if (-not (Test-Path -LiteralPath $dest)) { Write-Output "not installed: $dest does not exist"; exit 0 }
  if (-not (Test-IsLink $dest)) { Write-Error "refusing: $dest is a real directory, not a link. Remove it yourself if you mean it."; exit 1 }
  # Remove the reparse point only, never the target's contents.
  [System.IO.Directory]::Delete($dest)
  Write-Output "removed $dest"
  exit 0
}

if (-not (Test-Path -LiteralPath (Join-Path $src "SKILL.md"))) { Write-Error "missing $src\SKILL.md; run from the repo root"; exit 1 }
New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null

if (Test-Path -LiteralPath $dest) {
  $existing = Get-Item -LiteralPath $dest -Force
  if ((Test-IsLink $dest) -and (Test-Path -LiteralPath (Join-Path $dest "SKILL.md"))) {
    Write-Output "already installed ($($existing.LinkType)): $dest -> $($existing.Target)"
    exit 0
  }
  Write-Error "refusing: $dest already exists and is not a link to this repo. Remove it first."
  exit 1
}

$kind = $null
try {
  New-Item -ItemType SymbolicLink -Path $dest -Target $src -ErrorAction Stop | Out-Null
  $kind = "symlink"
} catch {
  New-Item -ItemType Junction -Path $dest -Target $src -ErrorAction Stop | Out-Null
  $kind = "junction"
}

if (-not (Test-Path -LiteralPath (Join-Path $dest "SKILL.md"))) { Write-Error "link created but SKILL.md is not readable through it"; exit 1 }
Write-Output "installed ($kind): $dest -> $src"
Write-Output "In any project, run: /no-filler <file>  (Claude also loads it on its own when writing prose)"
