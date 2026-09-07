#!/usr/bin/env bash
# Deterministic checks for the no-filler skill (seconds, no Claude session):
#   - the linter flags every known-bad fixture sentence at the intended tier
#   - the linter stays silent on clean prose, code, URLs, and blockquotes
#   - exit codes, stdin, and --json behave as documented
#   - the skill's own prose passes its linter (dogfood)
#   - every pattern the linter knows is documented in references/patterns.md
#   - frontmatter carries the fields the skill depends on
# Run before tests/e2e.sh; run both before pushing.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(dirname "$here")"
skill="$repo/skills/no-filler"
lint="$skill/scripts/filler-lint.js"
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  PASS  $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL  $1"; }

echo "=== known-bad sentences (tests/fixtures/ai-sentences.txt) ==="
# line -> the pattern name that must fire at block tier; "warn" lines must
# produce a warn-tier hit and no block-tier hit.
declare -A want=(
  [1]=announcing [3]=dash-slogan [4]=empty-clause-colon [5]=empty-clause-colon
  [6]=praise-opener [7]=aphorism [8]=unpack [9]=sentence-adverb [10]=em-dash
)
json="$(node "$lint" --all --json "$here/fixtures/ai-sentences.txt")"
for line in "${!want[@]}"; do
  name="${want[$line]}"
  if node -e 'const j=JSON.parse(process.argv[1]);process.exit(j.some(h=>h.line==process.argv[2]&&h.tier==="block"&&h.name===process.argv[3])?0:1)' "$json" "$line" "$name"; then
    ok "line $line flagged at block tier as $name"
  else
    bad "line $line not flagged at block tier as $name"
  fi
done
for line in 2 11; do
  if node -e 'const j=JSON.parse(process.argv[1]);const l=j.filter(h=>h.line==process.argv[2]);process.exit(l.length>0&&l.every(h=>h.tier==="warn")?0:1)' "$json" "$line"; then
    ok "line $line is warn-tier only (a clause with some content, reviewed by hand)"
  else
    bad "line $line should produce warn-tier hits and no block-tier hit"
  fi
done
if node "$lint" "$here/fixtures/ai-sentences.txt" >/dev/null; then bad "exit code 0 on a file with block-tier filler"; else ok "exit code 1 on a file with block-tier filler"; fi

echo "=== clean prose, code, URLs, blockquotes (tests/fixtures/clean-sentences.txt) ==="
out="$(node "$lint" --all "$here/fixtures/clean-sentences.txt")"; rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "no filler found" ]; then ok "no hits at any tier, exit 0"; else bad "unexpected hits (exit $rc): $out"; fi
if printf 'A disk is convex.\n' | node "$lint" - >/dev/null; then ok "stdin via - is accepted"; else bad "stdin via - failed"; fi
if printf 'Great question! A disk is convex.\n' | node "$lint" >/dev/null; then bad "stdin without a file argument missed a praise opener"; else ok "stdin is the default input"; fi
node "$lint" "$here/fixtures/does-not-exist.txt" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then ok "exit code 2 on an unreadable file"; else bad "exit code $rc on an unreadable file (wanted 2)"; fi
one="$(printf 'Right.\nGreat question! Next.\n' | node "$lint" --json - | node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8"));process.stdout.write(j.map(h=>h.line+":"+h.name).join(","))')"
if [ "$one" = "2:praise-opener" ]; then ok "--json reports the flagged sentence's own line"; else bad "--json line/name wrong: $one"; fi
if printf 'Not quite. The Fed does not print bills; the Treasury does.\n' | node "$lint" - >/dev/null; then ok "a plain contrast with a verb is not an aphorism"; else bad "false positive on a plain contrast"; fi
if printf 'It held the number one spot on the chart for 37 weeks, and exactly seven singles charted.\n' | node "$lint" - >/dev/null; then ok "\"spot on\" and \"exactly\" inside a sentence are not agreement openers"; else bad "false positive on \"spot on\" or \"exactly\" mid-sentence"; fi
if printf 'Spot on. The disk is convex.\nExactly, and the ring is not.\n' | node "$lint" - >/dev/null; then bad "missed \"Spot on.\" and \"Exactly,\" as sentence openers"; else ok "\"Spot on.\" and \"Exactly,\" as openers are still caught"; fi
if printf 'The groove holds the waveform. Now the part that drives the whole design. A cartridge responds to velocity.\n' | node "$lint" - >/dev/null; then bad "missed \"Now the part that ...\" as an announcing sentence"; else ok "\"Now the part that ...\" is caught as announcing"; fi
if printf 'The part that failed was the pump, and now the pressure is back to normal.\n' | node "$lint" - >/dev/null; then ok "\"the part that failed\" mid-sentence is not announcing"; else bad "false positive on \"the part that failed\""; fi
if printf 'Slides 1-5 cover cones; pass `--all` to list warn-tier hits, and see the table below.\n\n| a | b |\n| --- | --- |\n' | node "$lint" - >/dev/null; then ok "hyphen ranges, inline code, and table rules are not dashes"; else bad "false positive on a hyphen range, inline code, or a table rule"; fi
if printf 'The answer is 4: two points on each side. The answer is no: the disk is convex.\n' | node "$lint" - >/dev/null; then ok "a short answer clause before a colon passes"; else bad "false positive on a content-bearing clause before a colon"; fi
if printf -- '- **Price** — a bond pays a fixed amount.\n1. __Reserves__ -- the Fed creates them.\n* `flag` — what it does.\n## Setup — first run\n' | node "$lint" - >/dev/null; then ok "a dash after a bold, underscored, or code list label, or in a heading, is allowed"; else bad "false positive on a structural dash (list label or heading)"; fi
if printf -- '- **Price** is fixed — the yield moves.\n- A bond — a loan you can buy — pays a fixed amount.\n' | node "$lint" - >/dev/null; then bad "missed a dash inside a sentence within a list item"; else ok "a dash inside a sentence is still caught, even in a list item"; fi
if printf 'The answer is genuinely strange the first time you hear it: the Fed creates the money.\n' | node "$lint" - >/dev/null; then bad "missed an empty clause before a colon"; else ok "an empty clause before a colon is still caught"; fi
if printf 'He wrote "this is the subtle part, and it is where the\nslide slows down" in the margin.\n' | node "$lint" - >/dev/null; then ok "a quoted phrase that wraps a line is skipped"; else bad "false positive inside a wrapped quotation"; fi
two="\"Now the part you actually asked, which I have been asserting without proving: why does the quantity of money move the rate? The answer is genuinely strange the first time you hear it, and it takes a moment to accept: the Fed creates the money from nothing at all.\""
if printf 'Before: %s became one sentence.\n' "$two" | node "$lint" - >/dev/null; then ok "a two-sentence quotation (over 200 characters) is skipped"; else bad "false positive inside a long quotation"; fi
if printf 'Quoted "a" then unquoted: Great question! The disk is convex.\n' | node "$lint" - >/dev/null; then bad "a short quote masked the filler after it"; else ok "text after a closed quote is still linted"; fi

echo "=== stop hook ==="
hookrun() { # hookrun <json> -> exit code
  printf '%s' "$1" | node "$skill/scripts/stop-check.js" 2>/dev/null; echo $?
}
msg() { node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$1"; }
r="$(hookrun "{\"last_assistant_message\":$(msg 'The disk is convex: every segment between two of its points stays inside it.')}")"
if [ "$r" = "0" ]; then ok "hook allows a clean reply (exit 0)"; else bad "hook blocked a clean reply (exit $r)"; fi
r="$(hookrun "{\"last_assistant_message\":$(msg $'1. **Price** — a bond pays a fixed amount.\n2. **Reserves** — the Fed creates them.')}")"
if [ "$r" = "0" ]; then ok "hook allows dashes as list-label separators (exit 0)"; else bad "hook blocked structural dashes after bold labels (exit $r)"; fi
r="$(hookrun "{\"last_assistant_message\":$(msg 'A bond — a loan you can buy — pays a fixed amount.')}")"
if [ "$r" = "2" ]; then ok "hook blocks a dash inside a sentence (exit 2)"; else bad "hook let a sentence dash through (exit $r)"; fi
r="$(hookrun "{\"last_assistant_message\":$(msg 'Great question! The disk is convex.')}")"
if [ "$r" = "2" ]; then ok "hook blocks a praise opener (exit 2)"; else bad "hook let a praise opener through (exit $r)"; fi
r="$(hookrun "{\"stop_hook_active\":true,\"last_assistant_message\":$(msg 'Great question! The disk is convex.')}")"
if [ "$r" = "0" ]; then ok "hook allows the retry pass unconditionally"; else bad "hook blocked the retry pass (exit $r)"; fi
r="$(printf 'not json' | node "$skill/scripts/stop-check.js" 2>/dev/null; echo $?)"
if [ "$r" = "0" ]; then ok "hook allows garbage input"; else bad "hook failed on garbage input (exit $r)"; fi
reason="$(printf '%s' "{\"last_assistant_message\":$(msg 'Great question! The disk is convex.')}" | node "$skill/scripts/stop-check.js" 2>&1 >/dev/null)"
if printf '%s' "$reason" | grep -q '"Great question" (praise-opener'; then ok "hook reason quotes the flagged sentence and pattern"; else bad "hook reason unhelpful: $reason"; fi

echo "=== dogfood ==="
for f in skills/no-filler/SKILL.md skills/no-filler/references/patterns.md README.md CLAUDE.md; do
  if node "$lint" "$repo/$f" >/dev/null; then ok "$f has no block-tier filler"; else bad "$f contains block-tier filler:"; node "$lint" "$repo/$f" | head -n 5; fi
done

echo "=== rule file, settings hook tool, installer refresh ==="
rule="$repo/rules/no-filler.md"
if [ -f "$rule" ]; then ok "rules/no-filler.md exists"; else bad "rules/no-filler.md missing"; fi
rl="$(wc -l < "$rule")"
if [ "$rl" -le 60 ]; then ok "rule is $rl lines (loads into every session, so it stays short)"; else bad "rule is $rl lines; keep it under 60"; fi
if node "$lint" "$rule" >/dev/null; then ok "rule passes its own linter"; else bad "rule contains block-tier filler:"; node "$lint" "$rule" | head -n 5; fi
for phrase in "announce" "colon" "slogan" "aphorism" "dash" "praise" "adjective" "not cutting content" "Stop hook"; do
  if grep -qi -- "$phrase" "$rule"; then ok "rule covers: $phrase"; else bad "rule does not mention: $phrase"; fi
done
tmp="${TMPDIR:-/tmp}/no-filler-unit-$$"; mkdir -p "$tmp"; trap 'rm -rf "$tmp"' EXIT
tool="$repo/tools/settings-hook.js"
cat > "$tmp/settings.json" <<'EOF'
{
  "permissions": { "allow": ["Read"] },
  "hooks": {
    "Stop": [ { "hooks": [ { "type": "command", "command": "echo other-stop-hook" } ] } ],
    "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": "echo pre" } ] } ]
  }
}
EOF
cmd='f="/x/no-filler/scripts/stop-check.js"; exec node "$f"'
if node "$tool" status "$tmp/settings.json" >/dev/null; then bad "status reports installed on a fresh file"; else ok "status: not installed on a fresh file"; fi
node "$tool" add "$tmp/settings.json" "$cmd" >/dev/null && node "$tool" add "$tmp/settings.json" "$cmd" >/dev/null
n="$(node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write(String(s.hooks.Stop.filter(e=>JSON.stringify(e).includes("no-filler/scripts/stop-check.js")).length))' "$tmp/settings.json")"
if [ "$n" = "1" ]; then ok "add is idempotent (one entry after two adds)"; else bad "add produced $n entries"; fi
if node "$tool" status "$tmp/settings.json" >/dev/null; then ok "status: installed after add"; else bad "status wrong after add"; fi
keep="$(node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write([s.permissions.allow[0], s.hooks.Stop.length, s.hooks.PreToolUse.length].join(","))' "$tmp/settings.json")"
if [ "$keep" = "Read,2,1" ]; then ok "other settings and hooks preserved on add"; else bad "add disturbed other settings: $keep"; fi
if ls "$tmp"/settings.json.bak-* >/dev/null 2>&1; then ok "backup written before the change"; else bad "no backup written"; fi
node "$tool" remove "$tmp/settings.json" >/dev/null
keep="$(node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write([s.permissions.allow[0], s.hooks.Stop.length, s.hooks.PreToolUse.length].join(","))' "$tmp/settings.json")"
if [ "$keep" = "Read,1,1" ]; then ok "remove takes out only our entry"; else bad "remove disturbed other settings: $keep"; fi
printf 'not json' > "$tmp/broken.json"
node "$tool" status "$tmp/broken.json" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then ok "malformed settings file exits 2 and is left alone"; else bad "malformed settings file exit $rc (wanted 2)"; fi
if [ ! -f "$tmp/nothing.json" ] && node "$tool" add "$tmp/nothing.json" "$cmd" >/dev/null && node "$tool" status "$tmp/nothing.json" >/dev/null; then ok "add creates a missing settings file"; else bad "add failed on a missing settings file"; fi
if CLAUDE_RULES_DIR="$tmp/rules" "$repo/install.sh" --refresh-rule >/dev/null && cmp -s "$rule" "$tmp/rules/no-filler.md"; then ok "install.sh --refresh-rule copies the rule"; else bad "install.sh --refresh-rule did not copy the rule"; fi

echo "=== documentation and frontmatter ==="
names="$(node -e 'process.stdout.write(require(process.argv[1]).PATTERNS.map(p=>p.name).join("\n"))' "$lint")"
for n in $names; do
  if grep -q -- "\`$n\`" "$skill/references/patterns.md"; then ok "patterns.md documents $n"; else bad "patterns.md does not document $n"; fi
done
front="$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f' "$skill/SKILL.md")"
for key in "name: no-filler" "description:" "allowed-tools:" "filler-lint.js" "hooks:" "stop-check.js"; do
  if printf '%s\n' "$front" | grep -q -- "$key"; then ok "frontmatter has $key"; else bad "frontmatter lacks $key"; fi
done
if printf '%s\n' "$front" | grep -q "disable-model-invocation: true"; then ok "model invocation is disabled (the always-on rule covers ordinary writing; /no-filler is the manual tool)"; else bad "model invocation enabled; the rule makes auto-loading redundant and it prompts the user"; fi
# Claude Code ignores an unknown frontmatter key without an error, so a skill
# written with one looks configured and is not. This is the documented set
# (code.claude.com/docs/en/skills, frontmatter reference).
documented="agent allowed-tools argument-hint arguments background compatibility context description disable-model-invocation disallowed-tools effort hooks license metadata model name paths shell user-invocable when_to_use"
unknown=""
for k in $(printf '%s\n' "$front" | grep -E '^[a-z_-]+:' | sed 's/:.*//'); do
  case " $documented " in *" $k "*) ;; *) unknown="$unknown $k" ;; esac
done
if [ -z "$unknown" ]; then ok "frontmatter uses only documented fields"; else bad "undocumented frontmatter key(s):$unknown (Claude Code ignores unknown keys silently)"; fi
desc_len="$(awk '/^description: >-/{f=1;next} f&&/^[a-z-]+:/{exit} f' "$skill/SKILL.md" | tr -s ' \n' ' ' | wc -c)"
if [ "$desc_len" -le 1536 ]; then ok "description is $desc_len characters (listing truncates at 1,536)"; else bad "description is $desc_len characters; the listing truncates at 1,536"; fi
tutor_copy="$repo/../1-on-1-tutor/skills/1-on-1-tutor-mode/scripts/filler-lint.js"
if [ -f "$tutor_copy" ]; then
  if diff -q "$lint" "$tutor_copy" >/dev/null; then ok "the 1-on-1-tutor copy of filler-lint.js is identical"; else bad "the 1-on-1-tutor copy of filler-lint.js differs; copy this one over"; fi
else
  echo "  SKIP  no sibling 1-on-1-tutor checkout to compare filler-lint.js against"
fi

echo ""
echo "=== result: $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
