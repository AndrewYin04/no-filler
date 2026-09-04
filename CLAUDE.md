# no-filler: repo constitution

Read `README.md` before working here and keep it current (it says so itself).

## Tech stack and system overview

- A Claude Code skill: a markdown rule set plus one Node.js linter. No build
  step, no dependencies.
- `skills/no-filler/` is the unit that gets linked into `~/.claude/skills/`;
  everything else supports it.
- The skill is model-invocable on purpose (no `disable-model-invocation`), so
  Claude can load it from its description when writing prose; `/no-filler` is
  the explicit entry point for rewriting a file or pasted text.
- `scripts/filler-lint.js` is the deterministic half: a pattern list in two
  tiers (`block`, `warn`), a CLI, and a module (`lintText`). The 1-on-1 tutor
  repo (https://github.com/AndrewYin04/1-on-1-tutor) carries a verbatim copy
  in its Stop hook; this repo is canonical. `tests/unit.sh` diffs the two
  when the sibling checkout exists.
- `scripts/stop-check.js` is a Stop hook declared in the skill frontmatter.
  It lints each reply at block tier in any session where the skill was
  invoked and refuses the reply with the flagged sentences. It must allow the
  retry pass (`stop_hook_active`) and unreadable input, so it never traps a
  session. Skill hooks live in the invoking process, so a `claude -p` run
  gets the hook only on the turn that invoked the skill.

## Essential commands

```bash
./install.sh                                        # or .\install.ps1; --uninstall / -Uninstall to remove
node skills/no-filler/scripts/filler-lint.js --all <file>
tests/unit.sh                                       # seconds; no Claude
tests/e2e.sh                                        # real claude -p runs; needs the skill installed
tests/e2e.sh --scenario rewrite --keep
```

## Invariants

1. A `block` pattern must be high precision: adding one requires a
   true-positive line in `tests/fixtures/ai-sentences.txt` (asserted by name
   in `tests/unit.sh`) and a near-miss that must pass in
   `tests/fixtures/clean-sentences.txt` or the inline cases. Anything that is
   sometimes fine goes in `warn`.
2. The linter skips fenced code, inline code, URLs, YAML front matter,
   blockquotes, and phrases in double quotes, so documentation can quote bad
   sentences. Bad examples in this repo's prose go in blockquotes or quotes;
   `tests/unit.sh` lints `SKILL.md`, `references/patterns.md`, `README.md`,
   and this file at block tier.
3. Every pattern name in `PATTERNS` is documented in
   `references/patterns.md` under its backticked name; the unit test checks.
4. The `description` in `SKILL.md` stays under 1,536 characters (the skill
   listing truncates there) and leads with when to load the skill.
5. Frontmatter uses only fields Claude Code documents, plus `triggers` and
   `metadata` for the agent memory standard. `allowed-tools` is a YAML list so
   the Bash rule with spaces inside the parentheses is one item.
6. The linter reports the flagged sentence's own line, even when the regex
   anchored on the previous sentence's terminator.
7. Rewrites never drop content: facts, numbers, names, and defined terms
   survive; `tests/e2e.sh` checks that on the fixture.

## Directory layout

```
skills/no-filler/     SKILL.md, references/, scripts/, evals/
tests/                unit.sh, e2e.sh, fixtures/
install.sh, install.ps1
```
