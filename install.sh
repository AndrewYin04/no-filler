#!/usr/bin/env bash
# Install no-filler for Claude Code. Three pieces, each independent:
#   1. skill  ~/.claude/skills/no-filler  ->  <this repo>/skills/no-filler   (link: /no-filler and the linter)
#   2. rule   ~/.claude/rules/no-filler.md  <-  rules/no-filler.md            (copy: the always-on rule, loaded every session)
#   3. hook   a Stop hook in ~/.claude/settings.json                          (lints every reply in every session)
# Plus git post-merge and post-checkout hooks in this clone, so `git pull`
# re-copies the rule (the copy is deliberate: a symlinked rule is skipped in
# Cowork sessions).
#
# Usage:
#   ./install.sh                 install all three and the git hooks
#   ./install.sh --skill-only    link the skill only
#   ./install.sh --refresh-rule  re-copy the rule only (what the git hooks run)
#   ./install.sh --uninstall     remove the link, the rule copy, the settings hook, and the git hooks
#
# Overrides: CLAUDE_SKILLS_DIR, CLAUDE_RULES_DIR, CLAUDE_SETTINGS (default ~/.claude/...).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$here/skills/no-filler"
skills_dir="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
dest="$skills_dir/no-filler"
rule_src="$here/rules/no-filler.md"
rules_dir="${CLAUDE_RULES_DIR:-$HOME/.claude/rules}"
rule_dest="$rules_dir/no-filler.md"
settings="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
# The hook runs through Git Bash on Windows and sh elsewhere; cygpath turns the
# script path into one Node accepts on Windows.
hook_cmd="f=\"$dest/scripts/stop-check.js\"; if [ -f \"\$f\" ]; then command -v cygpath >/dev/null 2>&1 && f=\"\$(cygpath -w \"\$f\")\"; exec node \"\$f\"; fi; exit 0"
git_marker="# no-filler: re-copy the rule after a pull"

is_windows() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

# A junction is not a symlink to `test -L`, so on Windows ask PowerShell for the
# reparse-point type (Junction or SymbolicLink; empty for a real directory).
is_link() {
  if [ -L "$1" ]; then return 0; fi
  if is_windows && [ -d "$1" ]; then
    local kind
    kind="$(powershell.exe -NoProfile -Command "(Get-Item -LiteralPath '$(cygpath -w "$1")' -Force).LinkType" 2>/dev/null | tr -d '\r')"
    [ -n "$kind" ] && return 0
  fi
  return 1
}

wincmd() { MSYS_NO_PATHCONV=1 cmd /c "$@"; }

refresh_rule() {
  [ -f "$rule_src" ] || { echo "missing $rule_src" >&2; exit 1; }
  mkdir -p "$rules_dir"
  cp -f "$rule_src" "$rule_dest"
  echo "rule copied: $rule_dest (loads at the start of every Claude Code session)"
}

install_git_hooks() {
  [ -d "$here/.git" ] || { echo "not a git clone; skipping git hooks"; return 0; }
  local h hook
  for h in post-merge post-checkout; do
    hook="$here/.git/hooks/$h"
    if [ -f "$hook" ] && grep -qF "$git_marker" "$hook"; then continue; fi
    if [ ! -f "$hook" ]; then printf '#!/usr/bin/env bash\n' > "$hook"; fi
    printf '%s\nbash "%s/install.sh" --refresh-rule >/dev/null 2>&1 || true\n' "$git_marker" "$here" >> "$hook"
    chmod +x "$hook"
  done
  echo "git hooks installed: post-merge and post-checkout re-copy the rule after git pull"
}

remove_git_hooks() {
  [ -d "$here/.git" ] || return 0
  local h hook
  for h in post-merge post-checkout; do
    hook="$here/.git/hooks/$h"
    [ -f "$hook" ] && grep -qF "$git_marker" "$hook" || continue
    grep -vF "$git_marker" "$hook" | grep -vF "install.sh\" --refresh-rule" > "$hook.tmp" || true
    if [ "$(grep -cvE '^(#!.*|\s*)$' "$hook.tmp")" -eq 0 ]; then rm -f "$hook" "$hook.tmp"; else mv "$hook.tmp" "$hook"; fi
  done
  echo "git hooks removed"
}

link_skill() {
  [ -f "$src/SKILL.md" ] || { echo "missing $src/SKILL.md; run from the repo root" >&2; exit 1; }
  mkdir -p "$skills_dir"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if is_link "$dest" && [ -f "$dest/SKILL.md" ] && cmp -s "$dest/SKILL.md" "$src/SKILL.md"; then
      echo "skill already linked: $dest"
      return 0
    fi
    echo "refusing: $dest already exists and is not a link to this repo. Remove it first." >&2
    exit 1
  fi
  local kind=""
  if is_windows; then
    local wsrc wdest
    wsrc="$(cygpath -w "$src")"; wdest="$(cygpath -w "$dest")"
    if wincmd mklink /D "$wdest" "$wsrc" >/dev/null 2>&1; then kind="symlink"
    elif wincmd mklink /J "$wdest" "$wsrc" >/dev/null 2>&1; then kind="junction"
    else echo "could not create a symlink or a junction at $wdest" >&2; exit 1; fi
  else
    ln -s "$src" "$dest"; kind="symlink"
  fi
  [ -f "$dest/SKILL.md" ] || { echo "link created but SKILL.md is not readable through it" >&2; exit 1; }
  echo "skill linked ($kind): $dest -> $src"
}

unlink_skill() {
  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then echo "skill not linked: $dest does not exist"; return 0; fi
  if ! is_link "$dest"; then echo "refusing: $dest is a real directory, not a link. Remove it yourself if you mean it." >&2; exit 1; fi
  if is_windows; then wincmd rmdir "$(cygpath -w "$dest")"; else rm "$dest"; fi
  echo "skill unlinked: $dest"
}

case "${1:-}" in
  --refresh-rule)
    refresh_rule
    ;;
  --skill-only)
    link_skill
    echo "In any project, run: /no-filler <file>"
    ;;
  --uninstall)
    unlink_skill
    if [ -f "$rule_dest" ]; then rm -f "$rule_dest"; echo "rule removed: $rule_dest"; else echo "rule not installed: $rule_dest"; fi
    node "$here/tools/settings-hook.js" remove "$settings"
    remove_git_hooks
    ;;
  "")
    link_skill
    refresh_rule
    node "$here/tools/settings-hook.js" add "$settings" "$hook_cmd"
    install_git_hooks
    echo ""
    echo "Installed. New Claude Code sessions load the rule and run the hook; sessions already open do not."
    echo "Manual rewrite of a file: /no-filler <file>"
    ;;
  *)
    echo "usage: ./install.sh [--skill-only | --refresh-rule | --uninstall]" >&2
    exit 2
    ;;
esac
