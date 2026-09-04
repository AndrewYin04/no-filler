---
name: no-filler
description: >-
  Writing rules that remove AI-sounding filler from prose: sentences that
  announce instead of say ("this is the subtle part"), an empty clause before
  a colon, a slogan after a dash, aphorism-shaped sentences ("X is not Y; it
  is Z"), praise openers, adjectives standing in for facts, em-dashes. Use
  whenever writing or rewriting prose a person will read (explanations,
  answers, docs, messages, essays, lessons) and when asked to make text sound
  less like AI, less wordy, or clearer. /no-filler <file> lints and rewrites a
  file in place; /no-filler <text> rewrites the text.
argument-hint: "[file to rewrite, or text]"
allowed-tools:
  - Read
  - "Bash(node ${CLAUDE_SKILL_DIR}/scripts/filler-lint.js *)"
triggers:
  - "/no-filler"
  - "sounds like AI"
  - "too wordy"
  - "cut the filler"
hooks:
  Stop:
    - hooks:
        - type: command
          command: "for f in \"$HOME/.claude/skills/no-filler/scripts/stop-check.js\" \"${CLAUDE_PROJECT_DIR}/.claude/skills/no-filler/scripts/stop-check.js\"; do if [ -f \"$f\" ]; then command -v cygpath >/dev/null 2>&1 && f=\"$(cygpath -w \"$f\")\"; exec node \"$f\"; fi; done; exit 0"
          timeout: 15
metadata:
  repo: https://github.com/AndrewYin04/no-filler
---

# No filler

Every sentence must give the reader something they did not have: a fact, a
number, a definition, an example, a step of reasoning, a consequence, a
decision. A sentence that fails that test is deleted or replaced with the
content it was pointing at. Length is not the target: a paragraph that needs
eight sentences gets eight, and a sentence that carries nothing goes even from
a short reply.

Write for a smart reader who is new to the subject: plain words, every term
defined before it is used, the concrete case before the general statement.
The rules cover everything the person will read: the file or document you
produce, and the chat reply about it.

## The patterns

Each pattern below shows the bad sentence (quoted), why it fails, and what to
write instead. Most came from real tutoring replies about how the Federal
Reserve moves interest rates.

### Announcing instead of saying

> This is the subtle part, and it's where the slide slows down.

The reader learned nothing about the subject; the sentence describes the
sentence that will follow. Delete it and write that one.

### An empty clause before a colon

> The answer is genuinely strange the first time you hear it: the Fed creates
> the money.

> Now the part you actually asked, which I've been asserting without proving:
> why does the quantity of money move the rate?

Everything before the colon is about the reply, not the subject, and the
reader holds an empty clause open while waiting for the content. Start at the
content: "The Fed creates the money. When it buys a bond from a bank, it pays
by adding reserves to that bank's account, and those reserves did not exist
before." A colon belongs after a clause that already said something, to
introduce a list or an example: "Two sets are convex: the disk and the square."

### A content-free clause explained by a second clause

> The Fed sits at one end of that same yield curve: it directly sets the
> shortest rate, and the market prices the 10-year partly by guessing where
> the Fed's rate will be over the next ten years.

The first clause is a metaphor the second clause then explains, so the reader
reads the idea twice and understands it once. Give the mechanism: "The Fed
sets only the overnight rate. The 10-year yield is the market's guess at the
average overnight rate over the next ten years, plus a premium for locking
money up that long."

### A slogan after a dash

> Your "control the money supply by buying and selling bonds" is how they
> enforce that target — the bond operations are the tool, the fed funds rate
> is the dial.

The clause after the dash restates the sentence as an aphorism and adds no
fact, and the reader has to decode a metaphor to get back to where they were.
Cut it, or write the contrast with a verb: "The Fed announces a target for the
fed funds rate, then buys or sells bonds until the overnight rate lands on it."

### Aphorism-shaped sentences

> It's not about the money; it's about the rate.

> The easy half was the proof, the hard half was the intuition.

"X is not Y; it is Z" and "the A was B, the C was D" read as robotic. Write the
plain sentence: what it is, with a verb. "The rate is what matters, because
every loan in the economy is priced off it."

### Dashes

No em-dashes and no double hyphens, anywhere: not in a sentence, not as the
separator after a bold label in a list item, not in a heading. Recast with a
comma, a colon, a semicolon, or two sentences; in a list, a colon after the
label. Check the rendered output, not only the source.

### Praise and agreement openers

> Great question. You're absolutely right that the Fed doesn't print bills.

Answer. When the reader is right, say what was right: "Right that the Fed
doesn't print bills; the Treasury prints them, and the Fed creates money as
bank reserves instead."

### Adjectives standing in for facts

> The 2008 expansion was massive and genuinely unprecedented.

Show, don't tell. Give the number, the mechanism, or the example: "The Fed's
balance sheet went from about $0.9 trillion in August 2008 to about $2.2
trillion by December, a larger change in four months than in the previous
twenty years."

### Commentary on the exposition

> As I said earlier, we'll get to open-market operations in a moment; let's
> unpack this first.

The reader cannot use any of it. Give the content now, or say nothing.

### Sentence adverbs and throat-clearing

> Interestingly, the disk is convex. Essentially, it has no dents.

Cut "interestingly", "importantly", "essentially", "basically", "at its core",
"simply put". If the point matters, the fact shows it.

### Restating

> The overlap stays inside both sets. In other words, the overlap is convex.

If the first phrasing was unclear, replace it. Do not say it twice.

### Closing offers

> I hope this helps! Let me know if you'd like me to go deeper.

Stop when the content stops.

## Cutting filler is not cutting content

Concise means no wasted words, not few words. Never delete a fact, a number, a
name, or a qualifier that changes the meaning in order to make text shorter.
If the only way to shorten something is to lose real content, keep the
content and say so.

## Prerequisites

- Node.js on PATH, for `scripts/filler-lint.js` and the Stop hook. Without
  it, apply the catalog above by hand and say that the linter did not run.
- While this skill is active, a Stop hook lints every reply at block tier
  and refuses one that fails, quoting the sentences. Fix exactly those, keep
  the rest, and stop.

## Step-by-Step Procedure

When writing new prose for a person:

1. Draft it.
2. Read every sentence and ask what the reader knows after it that they did
   not know before. Delete or replace each one that fails.
3. If the draft is a file, run
   `node ${CLAUDE_SKILL_DIR}/scripts/filler-lint.js --all <file>`. Lines
   tagged `[block]` must be fixed; lines tagged `[warn]` are reviewed and fixed
   when they are filler. `no filler found` with exit 0 means done.

When invoked as `/no-filler <file>`:

1. Read the file, then run the linter on it with `--all`.
2. Rewrite every flagged sentence and every other sentence that fails the
   test. Keep every fact, number, name, and defined term; keep the author's
   structure and headings; add nothing.
3. Write the file back in place.
4. Run the linter again. It must print no `[block]` line.
5. Reply with what changed: how many sentences were removed and how many
   rewritten, plus the three most representative before/after pairs. Put each
   "before" sentence on its own blockquote line (`> ...`), which the linter
   skips, so the reply itself passes the same check as the file.

When invoked as `/no-filler <text>` with text instead of a path: rewrite the
text under the same rules, print the rewrite, then run the linter on it (pipe
it to the script's stdin) and print the result.

## Rollback & Failure Handling

- The Stop hook refuses a reply: rewrite the sentences it quotes, move any
  deliberately quoted bad example into a blockquote, and stop.
- The linter exits 2 (file unreadable): check the path and retry.
- The linter still prints `[block]` lines after a rewrite: fix those lines
  specifically; do not delete the content around them.
- A flagged line is a deliberate quotation or code: put quoted examples in a
  blockquote and code in a fence. The linter skips both.
- Node is missing: apply the catalog by hand and say the linter did not run.

## Additional resources

- `references/patterns.md`: every linter pattern with its tier, what it
  matches, and the fix, plus the rules that came from cover-letter reviews.
- `scripts/filler-lint.js`: the linter (`--all` lists warn-tier hits,
  `--json` for tooling, `-` reads stdin; exit 1 on any block-tier hit).
- `scripts/stop-check.js`: the Stop hook declared above; runs the linter on
  each reply while the skill is active.
