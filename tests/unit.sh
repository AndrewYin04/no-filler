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
if [ "$r" = "2" ]; then ok "hook blocks em-dash separators in a list (exit 2)"; else bad "hook let em-dash separators through (exit $r)"; fi
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

echo "=== documentation and frontmatter ==="
names="$(node -e 'process.stdout.write(require(process.argv[1]).PATTERNS.map(p=>p.name).join("\n"))' "$lint")"
for n in $names; do
  if grep -q -- "\`$n\`" "$skill/references/patterns.md"; then ok "patterns.md documents $n"; else bad "patterns.md does not document $n"; fi
done
front="$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f' "$skill/SKILL.md")"
for key in "name: no-filler" "description:" "allowed-tools:" "filler-lint.js" "hooks:" "stop-check.js"; do
  if printf '%s\n' "$front" | grep -q -- "$key"; then ok "frontmatter has $key"; else bad "frontmatter lacks $key"; fi
done
if printf '%s\n' "$front" | grep -q "disable-model-invocation: true"; then bad "model invocation is disabled; Claude must be able to load this skill on its own"; else ok "model invocation stays enabled"; fi
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
