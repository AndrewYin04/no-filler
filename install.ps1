<#
.SYNOPSIS
  Install no-filler for Claude Code: the skill link, the always-on rule copy,
  the Stop hook in settings.json, and git hooks that re-copy the rule after
  `git pull`.

.DESCRIPTION
  1. skill  ~/.claude/skills/no-filler  ->  <this repo>\skills\no-filler   (symlink, or junction when symlinks need elevation)
  2. rule   ~/.claude/rules/no-filler.md  <-  rules\no-filler.md            (a copy; a symlinked rule is skipped in Cowork sessions)
  3. hook   a Stop hook entry in ~/.claude/settings.json                    (lints every reply in every session)
  Git post-merge and post-checkout hooks in this clone re-copy the rule.

.EXAMPLE
  .\install.ps1
  .\install.ps1 -SkillOnly
  .\install.ps1 -RefreshRule
  .\install.ps1 -Uninstall
#>
[CmdletBinding()]
param(
  [switch]$Uninstall,
  [switch]$SkillOnly,
  [switch]$RefreshRule,
  [string]$SkillsDir = $(if ($env:CLAUDE_SKILLS_DIR) { $env:CLAUDE_SKILLS_DIR } else { Join-Path $HOME ".claude\skills" }),
  [string]$RulesDir = $(if ($env:CLAUDE_RULES_DIR) { $env:CLAUDE_RULES_DIR } else { Join-Path $HOME ".claude\rules" }),
  [string]$Settings = $(if ($env:CLAUDE_SETTINGS) { $env:CLAUDE_SETTINGS } else { Join-Path $HOME ".claude\settings.json" })
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $here "skills\no-filler"
$dest = Join-Path $SkillsDir "no-filler"
$ruleSrc = Join-Path $here "rules\no-filler.md"
$ruleDest = Join-Path $RulesDir "no-filler.md"
$gitMarker = "# no-filler: re-copy the rule after a pull"
# Hooks run through Git Bash on Windows; the forward-slash form of the path is
# what that shell wants, and cygpath converts it for Node.
$destBash = ($dest -replace '\\', '/') -replace '^([A-Za-z]):', '/$1'
$destBash = $destBash.Substring(0, 2).ToLower() + $destBash.Substring(2)
$hookCmd = 'f="' + $destBash + '/scripts/stop-check.js"; if [ -f "$f" ]; then command -v cygpath >/dev/null 2>&1 && f="$(cygpath -w "$f")"; exec node "$f"; fi; exit 0'

function Test-IsLink([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) { return $false }
  $item = Get-Item -LiteralPath $p -Force
  return ($null -ne $item.LinkType)
}

function Copy-Rule {
  if (-not (Test-Path -LiteralPath $ruleSrc)) { Write-Error "missing $ruleSrc"; exit 1 }
  New-Item -ItemType Directory -Force -Path $RulesDir | Out-Null
  Copy-Item -LiteralPath $ruleSrc -Destination $ruleDest -Force
  Write-Output "rule copied: $ruleDest (loads at the start of every Claude Code session)"
}

function Install-GitHooks {
  $gitDir = Join-Path $here ".git"
  if (-not (Test-Path -LiteralPath $gitDir)) { Write-Output "not a git clone; skipping git hooks"; return }
  $hereBash = ($here -replace '\\', '/')
  foreach ($h in @("post-merge", "post-checkout")) {
    $hook = Join-Path $gitDir "hooks\$h"
    if ((Test-Path -LiteralPath $hook) -and ((Get-Content -LiteralPath $hook -Raw) -like "*$gitMarker*")) { continue }
    if (-not (Test-Path -LiteralPath $hook)) { [System.IO.File]::WriteAllText($hook, "#!/usr/bin/env bash`n") }
    [System.IO.File]::AppendAllText($hook, "$gitMarker`nbash `"$hereBash/install.sh`" --refresh-rule >/dev/null 2>&1 || true`n")
  }
  Write-Output "git hooks installed: post-merge and post-checkout re-copy the rule after git pull"
}

function Remove-GitHooks {
  $gitDir = Join-Path $here ".git"
  if (-not (Test-Path -LiteralPath $gitDir)) { return }
  foreach ($h in @("post-merge", "post-checkout")) {
    $hook = Join-Path $gitDir "hooks\$h"
    if (-not (Test-Path -LiteralPath $hook)) { continue }
    $lines = Get-Content -LiteralPath $hook
    if (-not ($lines -like "*$gitMarker*")) { continue }
    $kept = $lines | Where-Object { $_ -ne $gitMarker -and $_ -notlike '*install.sh" --refresh-rule*' }
    $content = $kept | Where-Object { $_ -notmatch '^(#!.*|\s*)$' }
    if ($content.Count -eq 0) { Remove-Item -LiteralPath $hook -Force } else { [System.IO.File]::WriteAllText($hook, (($kept -join "`n") + "`n")) }
  }
  Write-Output "git hooks removed"
}

function Link-Skill {
  if (-not (Test-Path -LiteralPath (Join-Path $src "SKILL.md"))) { Write-Error "missing $src\SKILL.md; run from the repo root"; exit 1 }
  New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
  if (Test-Path -LiteralPath $dest) {
    $existing = Get-Item -LiteralPath $dest -Force
    if ((Test-IsLink $dest) -and (Test-Path -LiteralPath (Join-Path $dest "SKILL.md"))) {
      Write-Output "skill already linked ($($existing.LinkType)): $dest -> $($existing.Target)"
      return
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
  Write-Output "skill linked ($kind): $dest -> $src"
}

function Unlink-Skill {
  if (-not (Test-Path -LiteralPath $dest)) { Write-Output "skill not linked: $dest does not exist"; return }
  if (-not (Test-IsLink $dest)) { Write-Error "refusing: $dest is a real directory, not a link. Remove it yourself if you mean it."; exit 1 }
  [System.IO.Directory]::Delete($dest)
  Write-Output "skill unlinked: $dest"
}

if ($RefreshRule) { Copy-Rule; exit 0 }
if ($SkillOnly) { Link-Skill; Write-Output "In any project, run: /no-filler <file>"; exit 0 }
if ($Uninstall) {
  Unlink-Skill
  if (Test-Path -LiteralPath $ruleDest) { Remove-Item -LiteralPath $ruleDest -Force; Write-Output "rule removed: $ruleDest" } else { Write-Output "rule not installed: $ruleDest" }
  & node (Join-Path $here "tools\settings-hook.js") remove $Settings
  Remove-GitHooks
  exit 0
}

Link-Skill
Copy-Rule
& node (Join-Path $here "tools\settings-hook.js") add $Settings $hookCmd
Install-GitHooks
Write-Output ""
Write-Output "Installed. New Claude Code sessions load the rule and run the hook; sessions already open do not."
Write-Output "Manual rewrite of a file: /no-filler <file>"
