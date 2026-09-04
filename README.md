# no-filler

A Claude Code skill that stops Claude from writing the sentences that make
prose sound like AI: the sentence that announces the next one ("this is the
subtle part"), the empty clause before a colon ("the answer is strange the
first time you hear it: ..."), the slogan after a dash ("the bond operations
are the tool, the rate is the dial"), aphorism-shaped sentences ("it's not
about X; it's about Y"), praise openers, adjectives standing in for numbers,
em-dashes. The rule behind all of them: every sentence must give the reader
something they did not have, and length is never the target.

It ships with a deterministic linter, `filler-lint.js`, that finds those
patterns in any text file, so a hook or a test can enforce the rule instead of
hoping the model remembers it.

## Install

Clone anywhere, then link the skill into your personal Claude Code skills
directory. The link means `git pull` updates the skill in place.

Windows (PowerShell or Git Bash):

```powershell
git clone https://github.com/AndrewYin04/no-filler.git
cd no-filler
.\install.ps1
```

macOS or Linux:

```bash
git clone https://github.com/AndrewYin04/no-filler.git
cd no-filler
./install.sh
```

The installer creates `~/.claude/skills/no-filler` pointing at
`skills/no-filler` in the clone (a symlink, or a directory junction on Windows
when symlinks need elevation; Claude Code follows both). Uninstall with
`./install.sh --uninstall` or `.\install.ps1 -Uninstall`.

Requirements: Claude Code (tested on 2.1.237) and Node.js on PATH for the
linter.

## Use

Three ways in:

1. **Automatic.** The skill is model-invocable, so Claude loads it on its own
   when a request matches its description: writing or rewriting prose a person
   will read, or making text sound less like AI. Claude Code asks once per
   session before running a skill Claude chose; approve it, or add this rule to
   `permissions.allow` in `~/.claude/settings.json` so it never asks:

   ```json
   "Skill(no-filler)"
   ```

   In a scripted `claude -p` run nobody can answer that prompt, so pass
   `--allowedTools Skill` (the test harness does).
2. **Rewrite a file in place.** `/no-filler notes.md` reads the file, lints
   it, rewrites every filler sentence while keeping every fact, number, and
   name, writes it back, lints again, and reports what changed.
3. **Rewrite pasted text.** `/no-filler <text>` prints the rewrite and the
   linter result.

To make the rules apply to every reply in every project, not only when the
description matches, add one line to `~/.claude/CLAUDE.md` (create the file
if it does not exist):

```
Follow ~/.claude/skills/no-filler/SKILL.md for all prose you write.
```

## The linter

```bash
node ~/.claude/skills/no-filler/scripts/filler-lint.js notes.md         # block-tier hits, exit 1 if any
node ~/.claude/skills/no-filler/scripts/filler-lint.js --all notes.md   # warn-tier hits too
node ~/.claude/skills/no-filler/scripts/filler-lint.js --json a.md b.md # for tooling
cat draft.txt | node ~/.claude/skills/no-filler/scripts/filler-lint.js  # stdin
```

Output is one line per hit: `file:line: [tier] pattern: "matched text" ->
fix`. Two tiers:

- `block`: the sentence carries no content for the reader, or breaks a
  standing rule (no dashes, no aphorisms). High precision; a Stop hook can
  refuse a reply on it. Exit code 1.
- `warn`: usually filler, sometimes fine ("actually", "in other words", a long
  clause before a colon). Review by hand. Never changes the exit code.

Fenced code, inline code, URLs, YAML front matter, blockquotes, and phrases
inside double quotes are skipped, so a document can quote a bad sentence as an
example. Every pattern is listed with its fix in
[`skills/no-filler/references/patterns.md`](skills/no-filler/references/patterns.md).

## The Stop hook

Once the skill is active in a session (you ran `/no-filler`, or Claude loaded
it), a Stop hook declared in the skill runs the linter on every reply and
refuses one that contains block-tier filler, quoting the sentences so Claude
rewrites them. That is what turns the rule from a request into a check: in
testing, Claude followed the written rule in the file it wrote and still put
em-dashes in its chat summary until the hook sent it back. The hook allows
the retry pass unconditionally, so it can never trap a session, and it is
inert in sessions where the skill was never invoked.

The [1-on-1 tutor](https://github.com/AndrewYin04/1-on-1-tutor) skill carries a
verbatim copy of the linter in its own Stop hook, so tutoring replies are
refused on the same patterns. This repo holds the canonical copy.

## Where the rules came from

The catalog started from real tutoring replies about the Federal Reserve that
read as AI-written, plus the voice rules a set of cover-letter reviews had
already produced: show, don't tell; no aphorism-shaped sentences; no em-dashes
or double hyphens; cut filler words but never content. Those are all in the
skill and the catalog.

## Repository layout

```
no-filler/
├── skills/no-filler/            the skill (this is what gets linked)
│   ├── SKILL.md                 the rule, the patterns with rewrites, the procedure
│   ├── references/patterns.md   every linter pattern with tier and fix
│   ├── scripts/filler-lint.js   the linter (CLI and module)
│   ├── scripts/stop-check.js    the Stop hook: lints each reply while the skill is active
│   └── evals/evals.json         test prompts and assertions in skill-creator format
├── tests/unit.sh                linter on known-bad and clean fixtures, dogfooding, docs sync
├── tests/e2e.sh                 real `claude -p` runs: /no-filler on a fixture, and an unprompted request
├── tests/fixtures/              the sentences that started this, clean prose, an AI-written page
├── install.sh / install.ps1     link the skill into ~/.claude/skills
└── CLAUDE.md                    repo constitution for agents working on this repo
```

## Test

Deterministic checks, seconds, no Claude session:

```bash
tests/unit.sh
```

End to end, real `claude -p` sessions from a scratch folder, so the skill must
be installed first. Uses your Claude account.

```bash
tests/e2e.sh                       # both scenarios
tests/e2e.sh --scenario rewrite    # /no-filler on tests/fixtures/fed.md
tests/e2e.sh --scenario auto       # a plain writing request; did Claude load the skill on its own?
```

The `auto` scenario is the probabilistic one: it reports whether Claude chose
to load the skill from its description alone, and whether the prose passed the
linter either way. A failure there is a finding about the description, not
about the linter.

## Update

```bash
git pull
```

Nothing else: the link points at the clone.

## Maintaining this README

This file is the user-facing description of the skill. Whenever the skill's
behavior, commands, install steps, file layout, or test procedure changes,
update the matching section here in the same change, without being asked.
