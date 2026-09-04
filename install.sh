#!/usr/bin/env bash
# Install the no-filler writing skill for Claude Code by linking
#   ~/.claude/skills/no-filler  ->  <this repo>/skills/no-filler
#
# Usage:
#   ./install.sh              install (symlink; on Windows falls back to a junction)
#   ./install.sh --uninstall  remove the link (never touches the repo)
#
# Override the skills directory with CLAUDE_SKILLS_DIR if yours is elsewhere.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$here/skills/no-filler"
skills_dir="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
dest="$skills_dir/no-filler"

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

# cmd.exe must get mklink's arguments separately: a single quoted command string
# loses its inner quotes, and MSYS would otherwise rewrite /J and /D as paths.
wincmd() { MSYS_NO_PATHCONV=1 cmd /c "$@"; }

if [ "${1:-}" = "--uninstall" ]; then
  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "not installed: $dest does not exist"
    exit 0
  fi
  if ! is_link "$dest"; then
    echo "refusing: $dest is a real directory, not a link. Remove it yourself if you mean it." >&2
    exit 1
  fi
  if is_windows; then
    wincmd rmdir "$(cygpath -w "$dest")"
  else
    rm "$dest"
  fi
  echo "removed $dest"
  exit 0
fi

[ -f "$src/SKILL.md" ] || { echo "missing $src/SKILL.md; run from the repo root" >&2; exit 1; }
mkdir -p "$skills_dir"

if [ -e "$dest" ] || [ -L "$dest" ]; then
  if is_link "$dest" && [ -f "$dest/SKILL.md" ] && cmp -s "$dest/SKILL.md" "$src/SKILL.md"; then
    echo "already installed: $dest"
    exit 0
  fi
  echo "refusing: $dest already exists and is not a link to this repo. Remove it first." >&2
  exit 1
fi

kind=""
if is_windows; then
  wsrc="$(cygpath -w "$src")"
  wdest="$(cygpath -w "$dest")"
  # A real symlink needs Developer Mode or an elevated shell; a junction needs neither.
  if wincmd mklink /D "$wdest" "$wsrc" >/dev/null 2>&1; then
    kind="symlink"
  elif wincmd mklink /J "$wdest" "$wsrc" >/dev/null 2>&1; then
    kind="junction"
  else
    echo "could not create a symlink or a junction at $wdest" >&2
    exit 1
  fi
else
  ln -s "$src" "$dest"
  kind="symlink"
fi

[ -f "$dest/SKILL.md" ] || { echo "link created but SKILL.md is not readable through it" >&2; exit 1; }
echo "installed ($kind): $dest -> $src"
echo "In any project, run: /no-filler <file>  (Claude also loads it on its own when writing prose)"
