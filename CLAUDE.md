# no-filler: repo constitution

Read `README.md` before working here and keep it current (it says so itself).

## Tech stack and system overview

- Markdown instructions plus small Node.js scripts. No build step, no
  dependencies.
- Three installed pieces, each with its own file here:
  - `rules/no-filler.md`: the always-on rule. The installer copies it to
    `~/.claude/rules/no-filler.md`, where Claude Code loads it at the start
    of every session. It is a copy, not a link, because Cowork sessions skip
    symlinked rule files; git `post-merge` and `post-checkout` hooks that the
    installer writes into the clone re-copy it after every pull.
  - `skills/no-filler/`: linked into `~/.claude/skills/`. `/no-filler` is
    the manual rewrite command; model invocation is disabled because the rule
    already covers ordinary writing and auto-loading prompts the user.
  - `skills/no-filler/scripts/stop-check.js`: the Stop hook. The installer
    registers it user-wide in `~/.claude/settings.json` through
    `tools/settings-hook.js` (idempotent, backs the file up, recognises its
    entry by the marker `no-filler/scripts/stop-check.js`); the skill also
    declares it, so `/no-filler` turns are covered even with `--skill-only`.
- `skills/no-filler/scripts/filler-lint.js` is the deterministic core: a
  pattern list in two tiers (`block`, `warn`), a CLI, and a module. The 1-on-1
  tutor repo (https://github.com/AndrewYin04/1-on-1-tutor) carries a verbatim
  copy in its Stop hook; this repo is canonical. `tests/unit.sh` diffs the two
  when the sibling checkout exists.

## Essential commands

```bash
./install.sh                                        # or .\install.ps1; --skill-only, --refresh-rule, --uninstall
node skills/no-filler/scripts/filler-lint.js --all <file>
node tools/settings-hook.js status ~/.claude/settings.json
tests/unit.sh                                       # seconds; no Claude
tests/e2e.sh                                        # real claude -p runs; needs ./install.sh first
tests/e2e.sh --scenario hook --keep
```

## Invariants

1. A `block` pattern must be high precision: adding one requires a
   true-positive line in `tests/fixtures/ai-sentences.txt` (asserted by name
   in `tests/unit.sh`) and a near-miss that must pass. Anything that is
   sometimes fine goes in `warn`.
2. The linter skips fenced code, inline code, URLs, YAML front matter,
   blockquotes, and phrases in double quotes. Dashes are banned inside
   sentences only: a dash in a heading, or right after a bold, underscored,
   or code label that opens a list item, is structural and allowed. Bad
   examples in this repo's prose go in blockquotes or quotes; `tests/unit.sh`
   lints the rule, `SKILL.md`, `references/patterns.md`, `README.md`, and
   this file at block tier.
3. `rules/no-filler.md` stays under 60 lines: it costs context in every
   session. Detail and rewrites live in the skill and `patterns.md`.
4. Every pattern name in `PATTERNS` is documented in
   `references/patterns.md` under its backticked name; the unit test checks.
5. The Stop hook and `settings-hook.js` must never trap or damage: the hook
   allows the retry pass (`stop_hook_active`) and unreadable input; the
   settings tool refuses a malformed file (exit 2), backs up before writing,
   and removes only its own entry.
6. Frontmatter uses only fields the Claude Code docs define; `tests/unit.sh`
   checks every key against that list. An unknown key is ignored with no
   error, so a skill written with one looks configured and is not. `triggers:`
   was carried here until 2026-09-07 for exactly that reason and did nothing.
   `allowed-tools` is a YAML list so the Bash rule with spaces inside the
   parentheses is one item.
7. Rewrites never drop content: facts, numbers, names, and defined terms
   survive; `tests/e2e.sh` checks that on the fixture.

## Directory layout

```
rules/                rule file copied to ~/.claude/rules/
skills/no-filler/     SKILL.md, references/, scripts/, evals/
tools/                settings-hook.js
tests/                unit.sh, e2e.sh, fixtures/
install.sh, install.ps1
```
