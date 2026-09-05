# no-filler

Stops Claude Code from writing the sentences that make prose sound like AI:
the sentence that announces the next one ("this is the subtle part"), the
empty clause before a colon ("the answer is strange the first time you hear
it: ..."), the slogan after a dash ("the bond operations are the tool, the
rate is the dial"), aphorism-shaped sentences ("it's not about X; it's about
Y"), praise openers, adjectives standing in for numbers, em-dashes inside
sentences. The rule behind all of them: every sentence must give the reader
something they did not have, and length is never the target.

It is three pieces that work together:

| Piece | Where it goes | What it does |
| --- | --- | --- |
| **Rule** | `~/.claude/rules/no-filler.md` | Loaded at the start of every Claude Code session, in every project. The always-on instruction. |
| **Stop hook** | `~/.claude/settings.json` | Lints every reply with `filler-lint.js` and refuses one that fails, quoting the sentences, so the rule is enforced rather than hoped for. |
| **Skill** | `~/.claude/skills/no-filler` | `/no-filler <file>` rewrites a file in place; `/no-filler <text>` rewrites pasted text. Also the home of the linter and the full pattern catalog. |

## Install

Clone anywhere, then run the installer. It links the skill, copies the rule,
adds the hook to your settings (after backing the file up), and installs git
hooks in the clone so `git pull` refreshes the rule copy.

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

Sessions already open do not pick up the rule or the hook; new ones do. To
confirm, run `/context` in a new session and look for `no-filler.md` under
Memory files.

Requirements: Claude Code (tested on 2.1.237), Node.js on PATH (the hook and
the linter), and on Windows, Git Bash.

Options: `--skill-only` (`-SkillOnly`) links the skill and installs nothing
else; `--uninstall` (`-Uninstall`) removes the link, the rule copy, the hook
entry, and the git hooks, and touches nothing else in your settings.

## Why the rule is a copy, and how it stays current

The skill is a link, so `git pull` updates it in place. The rule is a copy,
because Claude Code skips a symlinked rule file in Cowork sessions, and a copy
works everywhere. Keeping the copy current is automatic: the installer adds
`post-merge` and `post-checkout` hooks to the clone's `.git/hooks/`, so every
`git pull` (and any checkout) re-copies `rules/no-filler.md` into
`~/.claude/rules/`. If you ever clone fresh or the hooks are missing, run
`./install.sh` again (it is idempotent) or `./install.sh --refresh-rule` for
the copy alone.

## Use

Nothing to do for ordinary writing: the rule is in context and the hook
checks every reply. When the hook refuses a reply, Claude sees the flagged
sentences and rewrites them; you see only the corrected reply.

To rewrite an existing file:

```
/no-filler notes.md
```

Claude reads it, lints it, rewrites every filler sentence while keeping every
fact, number, and name, writes it back, lints again, and reports what
changed. `/no-filler <text>` does the same for pasted text and prints the
result.

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
  standing rule (no dashes inside sentences, no aphorisms). High precision;
  the Stop hook refuses a reply on it. Exit code 1.
- `warn`: usually filler, sometimes fine ("actually", "in other words", a long
  clause before a colon). Review by hand. Never changes the exit code.

Skipped so that documents can quote bad examples: fenced code, inline code,
URLs, YAML front matter, blockquotes, and phrases inside double quotes. Two
dash uses are structural and allowed: a dash in a heading, and a dash as the
separator after a bold label that opens a list item, as in
`- **Price** — a bond pays a fixed amount`. Every pattern is listed with its fix in
[`skills/no-filler/references/patterns.md`](skills/no-filler/references/patterns.md).

The [1-on-1 tutor](https://github.com/AndrewYin04/1-on-1-tutor) skill carries
a verbatim copy of the linter in its own Stop hook. This repo holds the
canonical copy.

## Where the rules came from

The catalog started from real tutoring replies about the Federal Reserve that
read as AI-written, plus the voice rules a set of cover-letter reviews had
already produced: show, don't tell; no aphorism-shaped sentences; no em-dashes
inside sentences; cut filler words but never content.

## Repository layout

```
no-filler/
├── rules/no-filler.md           the always-on rule (copied to ~/.claude/rules/)
├── skills/no-filler/            the skill (linked into ~/.claude/skills/)
│   ├── SKILL.md                 /no-filler: the patterns with rewrites and the rewrite procedure
│   ├── references/patterns.md   every linter pattern with tier and fix
│   ├── scripts/filler-lint.js   the linter (CLI and module)
│   ├── scripts/stop-check.js    the Stop hook (user-level via the installer; also declared by the skill)
│   └── evals/evals.json         test prompts and assertions in skill-creator format
├── tools/settings-hook.js       adds or removes the hook entry in settings.json, with a backup
├── tests/unit.sh                linter, hook, settings tool, rule file, docs sync; seconds, no Claude
├── tests/e2e.sh                 real `claude -p` runs: rewrite, the rule on a plain request, rule loaded, hook refusal
├── tests/fixtures/              the sentences that started this, clean prose, an AI-written page
├── install.sh / install.ps1     install, --skill-only, --refresh-rule, --uninstall
└── CLAUDE.md                    repo constitution for agents working on this repo
```

## Test

Deterministic checks, seconds, no Claude session:

```bash
tests/unit.sh
```

End to end, real `claude -p` sessions from a scratch folder against the
installed rule, hook, and skill, so run the installer first. Uses your Claude
account.

```bash
tests/e2e.sh                       # all four scenarios
tests/e2e.sh --scenario rewrite    # /no-filler on tests/fixtures/fed.md
tests/e2e.sh --scenario rule       # a plain writing request; the rule alone must produce clean prose
tests/e2e.sh --scenario loaded     # asks Claude what the rule says; proves the rule text is in context
tests/e2e.sh --scenario hook       # forces a dashed sentence; the hook must refuse it once
```

## Update

```bash
git pull
```

The skill link updates itself; the git hooks re-copy the rule. Run
`./install.sh` again if you cloned fresh.

## Maintaining this README

This file is the user-facing description of the project. Whenever the rule,
the skill's behavior, commands, install steps, file layout, or test procedure
changes, update the matching section here in the same change, without being
asked.
