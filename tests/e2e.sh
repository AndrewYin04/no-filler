#!/usr/bin/env bash
# End-to-end test for the no-filler skill.
#
# Drives the REAL entry point, `claude -p`, from a scratch folder outside this
# repo, so the skill has to resolve through ~/.claude/skills/no-filler (the
# link install.sh made). Two scenarios:
#
#   rewrite  /no-filler <file> on a fixture full of AI filler. The file must
#            come back with no block-tier filler, every fact intact, and the
#            reply must summarize the change without filler of its own.
#   auto     a plain writing request with no skill named. Checks whether
#            Claude loads the skill on its own (from its description) and
#            whether the prose passes the linter either way. This is the
#            probabilistic part; a failure here is a finding about the
#            description, not about the linter.
#
# Usage:  tests/e2e.sh [--scenario rewrite|auto|all] [--keep]
# Env:    E2E_WORKDIR  scratch directory (default: mktemp -d)
#         CLAUDE_BIN   claude binary (default: claude on PATH)
#         E2E_MODEL    optional --model override
#         E2E_TURN_TIMEOUT  seconds per turn (default 420)
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(dirname "$here")"
lint="$repo/skills/no-filler/scripts/filler-lint.js"
claude_bin="${CLAUDE_BIN:-claude}"
turn_timeout="${E2E_TURN_TIMEOUT:-420}"
scenario="all"
keep=0
while [ $# -gt 0 ]; do
  case "$1" in
    --scenario) scenario="$2"; shift ;;
    --keep) keep=1 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

work="${E2E_WORKDIR:-$(mktemp -d)}"
mkdir -p "$work"
export NO_FILLER_HOOK_DEBUG=1
pass=0; fail=0; turn=0; RESULT=""; RAW=""
log() { printf '%s\n' "$*"; }
ok()  { pass=$((pass + 1)); log "  PASS  $1"; }
bad() { fail=$((fail + 1)); log "  FAIL  $1"; }

# run "<prompt>" -> RESULT (final text), RAW (stream-json transcript), files turn-N.*
run() {
  turn=$((turn + 1))
  local prompt="$1"; shift
  # Skill is pre-allowed because a print-mode run cannot answer the "Execute
  # skill: no-filler" prompt that an interactive user would approve (or
  # silence with a Skill(no-filler) allow rule).
  local args=(-p "$prompt" --output-format stream-json --verbose --permission-mode acceptEdits
              --allowedTools "Bash(node *)" Read Edit Write Skill)
  [ -n "${E2E_MODEL:-}" ] && args+=(--model "$E2E_MODEL")
  args+=("$@")
  log ""
  log "turn $turn > $prompt"
  # MSYS_NO_PATHCONV keeps Git Bash from rewriting the leading "/" of the slash command.
  RAW="$(MSYS_NO_PATHCONV=1 timeout "$turn_timeout" "$claude_bin" "${args[@]}" 2>"$PWD/turn-$turn.stderr")" || true
  printf '%s\n' "$RAW" > "$PWD/turn-$turn.jsonl"
  RESULT="$(printf '%s\n' "$RAW" | node -e '
    const lines=require("fs").readFileSync(0,"utf8").split(/\r?\n/).filter(Boolean);
    let out="";
    for (const l of lines) { try { const j=JSON.parse(l); if (j.type==="result" && typeof j.result==="string") out=j.result; } catch (e) {} }
    process.stdout.write(out)')"
  printf '%s\n' "$RESULT" > "$PWD/turn-$turn.md"
  printf '%s\n' "$RESULT" | sed 's/^/    | /'
  [ -n "$RESULT" ] || bad "turn $turn produced no result (see turn-$turn.stderr)"
}

skill_loaded() { # did the transcript invoke the no-filler skill?
  printf '%s\n' "$RAW" | node -e '
    const lines=require("fs").readFileSync(0,"utf8").split(/\r?\n/).filter(Boolean);
    let hit=false;
    for (const l of lines) { try { const j=JSON.parse(l); const c=(j.message&&j.message.content)||[];
      for (const b of (Array.isArray(c)?c:[])) { if (b.type==="tool_use" && b.name==="Skill" && JSON.stringify(b.input).includes("no-filler")) hit=true; } } catch (e) {} }
    process.exit(hit?0:1)'
}

filler_hits() { node "$lint" "$1" 2>/dev/null | grep -v '^no filler found$' | sed -E 's/^[^:]+:([0-9]+): /\1: /; s/ -> .*//' | tr '\n' ';'; }
assert_clean_file()  { local h; h="$(filler_hits "$1")"; if [ -z "$h" ]; then ok "$1 has no block-tier filler"; else bad "$1 still has filler: $h"; fi; }
assert_clean_reply() { local h; h="$(printf '%s\n' "$RESULT" | node "$lint" - 2>/dev/null | grep -v '^no filler found$' | sed -E 's/ -> .*//' | tr '\n' ';')"; if [ -z "$h" ]; then ok "reply has no block-tier filler"; else bad "reply has filler: $h"; fi; }
assert_file_has()    { if grep -qiE -- "$2" "$1"; then ok "$1 keeps /$2/"; else bad "$1 lost /$2/"; fi; }
assert_contains()    { if printf '%s' "$RESULT" | grep -qiE -- "$1"; then ok "reply mentions /$1/"; else bad "reply lacks /$1/"; fi; }
assert_hook_ran()    { if [ -f .no-filler-hook.log ] && grep -qE "filler=|retry pass" .no-filler-hook.log; then ok "Stop hook ran inside Claude Code ($(tr '\n' ';' < .no-filler-hook.log | sed -E 's/[0-9T:.Z-]{20,} //g'))"; else bad "Stop hook left no trace in .no-filler-hook.log"; fi; }

scenario_rewrite() {
  log "=== scenario: rewrite (/no-filler <file>) ==="
  local dir="$work/rewrite"; rm -rf "$dir"; mkdir -p "$dir"; cd "$dir"
  cp "$here/fixtures/fed.md" fed.md
  local before; before="$(node "$lint" fed.md | grep -c '\[block\]')"
  log "fixture starts with $before block-tier hits"
  run "/no-filler fed.md"
  if ! cmp -s fed.md "$here/fixtures/fed.md"; then ok "fed.md was rewritten in place"; else bad "fed.md is unchanged"; fi
  assert_clean_file fed.md
  for fact in '1 million' 'reserves' 'overnight' '10-year' 'fed funds' 'bond'; do assert_file_has fed.md "$fact"; done
  if grep -q '^# How the Fed moves rates' fed.md; then ok "heading preserved"; else bad "heading lost"; fi
  assert_contains "rewr|remov|cut|sentence"
  assert_clean_reply
  assert_hook_ran
  local after_words before_words
  before_words="$(wc -w < "$here/fixtures/fed.md")"; after_words="$(wc -w < fed.md)"
  log "words: $before_words before, $after_words after"
  if [ "$after_words" -ge $((before_words / 2)) ]; then ok "rewrite kept at least half the words (content, not just length, survived)"; else bad "rewrite dropped to $after_words words from $before_words; content was probably cut"; fi
}

scenario_auto() {
  log "=== scenario: auto (no skill named; does Claude load it, and is the prose clean?) ==="
  local dir="$work/auto"; rm -rf "$dir"; mkdir -p "$dir"; cd "$dir"
  run "Write two paragraphs for a high schooler explaining why the Fed buying bonds lowers interest rates. Save it to fed-explainer.md."
  if skill_loaded; then ok "Claude loaded the no-filler skill on its own"; else bad "Claude did not load the no-filler skill on its own (description may need strengthening)"; fi
  if [ -f fed-explainer.md ]; then ok "fed-explainer.md written"; assert_clean_file fed-explainer.md; else bad "fed-explainer.md not written"; fi
  assert_clean_reply
  assert_hook_ran
}

log "workdir: $work"
log "claude:  $("$claude_bin" --version 2>/dev/null || echo unknown)"
case "$scenario" in
  rewrite) scenario_rewrite ;;
  auto) scenario_auto ;;
  all) scenario_rewrite; scenario_auto ;;
  *) echo "unknown scenario: $scenario" >&2; exit 2 ;;
esac
log ""
log "=== result: $pass passed, $fail failed ==="
log "transcripts: $work/*/turn-*.md"
if [ "$keep" -eq 0 ] && [ "$fail" -eq 0 ] && [ -z "${E2E_WORKDIR:-}" ]; then rm -rf "$work"; fi
[ "$fail" -eq 0 ]
