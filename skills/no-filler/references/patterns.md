# The pattern catalog

Every pattern `scripts/filler-lint.js` knows, by name, with its tier, what it
matches, and the fix. The linter is deterministic, so a hit is a place to
look, and the rule in `SKILL.md` (does the sentence give the reader something
they did not have?) decides.

Two tiers:

- `block`: the sentence carries no content, or breaks a standing rule. The
  match is high precision, so a Stop hook may refuse a reply on it. Adding a
  pattern here needs a true-positive case and a near-miss case in
  `tests/unit.sh`.
- `warn`: usually filler, sometimes fine. Listed with `--all`; never changes
  the exit code.

## Block tier

`praise-opener`. "Great question", "good catch", "fascinating point".
Delete; answer, or say specifically what was right.

`agreement-opener`. "You're absolutely right" anywhere; "Spot on", "Exactly",
"Exactly right", "Well said", "Nailed it", "Correct" as a sentence of their
own or the opening words of one. Say what was right instead of that they
were right. Mid-sentence uses ("the number one spot on the chart", "exactly
seven singles") are not matched.

`announcing`. "This is the subtle part", "here's the thing", "here's where it
gets interesting", "the tricky part is", and a sentence opening "Now the part
that ..." or "Now the question you ...". The sentence announces content
instead of giving it. Delete it and write the content it points at.

`empty-clause-colon`. A sentence that opens with "the answer", "the part you
asked", "the thing", "the key", "the trick", "the short version" and runs to a
colon. Everything before the colon is about the sentence, not the subject.
Start at the content after the colon. A colon after a clause with content is
fine: "Two sets are convex: the disk and the square."

`dash-slogan`. A dash followed by "X is the A, Y is the B". The clause after
the dash restates the sentence as a slogan. Cut it, or write the contrast as a
plain sentence with a verb.

`aphorism`. "It's not about X; it's about Y", "this is not X, it's Y". Write
the plain sentence: what it is, with a verb. The rule also covers shapes the
regex cannot see, such as "the easy half was A, the hard half was B"; those
are caught by reading, not by the linter.

`em-dash`. An em-dash (`—`) or a double hyphen (`--`) outside code. Recast
with a comma, a colon, a semicolon, or two sentences. Runs of three or more
hyphens (tables, horizontal rules) are not matched.

`unpack`. "Let's unpack", "let's dive in", "let me break this down", "buckle
up", "bear with me". Delete; start with the first fact.

`ai-vocabulary`. "Delve", "a testament to", "tapestry", "navigate the
complexities", "game-changer", "unlock the potential". Replace with the plain
word, or cut.

`sentence-adverb`. A sentence opening with "Interestingly", "Importantly",
"Crucially", "Notably", "Essentially", "Basically", "Fundamentally",
"Ultimately", "Simply put", "In essence", "At its core", "At the end of the
day", "Needless to say". Cut the adverb; if the point matters, the fact shows
it.

## Warn tier

`self-commentary`. "As I said", "as we'll see", "which I've been asserting",
"we'll come back to that", "more on that later". Commentary on the
exposition; the reader cannot use it. Cut, or give the content now.

`colon-joined-clauses`. A colon joining two clauses where the first is long.
Check that the first clause says something on its own; if it only sets up the
second, start at the second. This is the shape of "The Fed sits at one end of
that same yield curve: it directly sets the shortest rate", which the regex
cannot separate from a legitimate colon, so it is a warning.

`intensifier`. "Genuinely", "truly", "really", "actually", "honestly",
"very", "extremely", "incredibly", "remarkably", "surprisingly", "arguably".
Replace with the fact that makes it true, or cut.

`worth-noting`. "It's worth noting", "note that", "keep in mind", "remember
that", "it should be noted". Cut the frame and state the thing.

`rhetorical-question`. "Why? Because", "So what's going on". A question you
then answer yourself. State the answer.

`restating`. "In other words", "put simply", "that is to say", "the bottom
line is", "long story short". If the first phrasing was unclear, replace it.
Do not say it twice.

`vague-adjective`. "Huge", "massive", "crucial", "critical", "powerful",
"robust", "seamless", "elegant", "nuanced", "comprehensive", "holistic". Give
the number, the mechanism, or the example.

`closing-offer`. "I hope this helps", "let me know if you'd like", "feel free
to", "happy to help". Stop when the content stops.

## Rules the linter cannot check

These came from reviews of cover letters and resumes and apply to all prose:

- **Show, don't tell.** Active voice, a concrete subject, and a number
  wherever one exists. "Cut p99 latency from 340 ms to 90 ms across 12
  services" instead of "performance-focused".
- **No adjectives standing in for numbers.** "High-throughput, low-latency"
  needs a figure or it goes.
- **Name the firsthand specific.** The chip, the dataset, the failure that
  was hit. A list of tools reads as assembled from a job description; the
  specific reads as having been there.
- **Prefer concise, but keep the content.** Cut filler words to reclaim
  space; never delete a fact, a number, a name, or a keyword to win it. If the
  only way to shorten is to lose real content, say so instead of deciding
  alone.
- **Write the plain sentence.** Every aphorism-shaped sentence, whatever its
  exact form, is replaced by a sentence with a subject, a verb, and the fact.

## Skipped regions

The linter blanks these before matching, so line numbers stay correct and a
document can quote a bad sentence as an example:

- fenced code blocks and inline code
- URLs
- YAML front matter
- blockquote lines (starting with `>`)
- table rules and horizontal rules (runs of three or more hyphens)
