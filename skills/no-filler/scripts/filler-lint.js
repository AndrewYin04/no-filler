#!/usr/bin/env node
// filler-lint: flags AI-sounding filler in prose.
//
// Usage:  node filler-lint.js [--all] [--json] [file ...]     (stdin when no file, or "-")
// Exit 1 when any block-tier pattern matches, else 0. Warn-tier patterns are
// listed only with --all and never change the exit code.
//
// Skipped on purpose: fenced code, inline code, URLs, YAML front matter,
// blockquote lines (">"), and phrases inside double quotes, so a document can
// quote a bad sentence as an example without being flagged for it. Line
// numbers refer to the original text.
//
// Two tiers:
//   block  the sentence carries no content for the reader, or breaks a
//          standing rule (no dashes, no aphorisms). High precision; a Stop hook
//          can refuse a reply on these.
//   warn   usually filler, sometimes fine. Review by hand.
//
// This file is shared verbatim by the no-filler skill and the 1-on-1 tutor
// skill; the canonical copy lives at https://github.com/AndrewYin04/no-filler.

'use strict';

const PATTERNS = [
  {
    name: 'praise-opener', tier: 'block',
    re: /\b(?:great|good|excellent|fantastic|wonderful|awesome|brilliant|fascinating|interesting|nice) (?:question|observation|connection|point|catch|insight|instinct|thinking)\b/gi,
    fix: 'Delete it. Answer, or say specifically what was right.',
  },
  {
    name: 'agreement-opener', tier: 'block',
    // "Spot on" and "exactly right" only as sentence openers: "the number
    // one spot on the chart" is ordinary prose.
    re: /\byou(?:'re| are) (?:absolutely|exactly|completely|totally|so) right\b|(?:^|[.!?]\s+|\n\s*)(?:spot on|exactly right|exactly|well said|nailed it|correct)(?=[.!,:]\s|[.!]$)/gi,
    fix: 'Say what was right instead of that they were right.',
  },
  {
    name: 'announcing', tier: 'block',
    re: /\b(?:this|here|that|now) is (?:the|where) (?:subtle|tricky|hard|important|key|interesting|crucial|clever|fun|beautiful|surprising|counterintuitive|really interesting|really important|central|essential) (?:part|bit|piece|thing|idea|point|step|move|insight)\b|\bhere(?:'s| is) (?:the thing|the catch|the kicker|the key|the twist|the subtle part|the tricky part|the important part|where it gets|why it matters)\b|\b(?:this|that) is where it gets\b|\bthe (?:subtle|tricky|hard|interesting|important|key|clever) part is\b|(?:^|[.!?]\s+|\n\s*)(?:and |so )?now,? (?:for )?the (?:part|bit|piece|question|thing) (?:that|you|I|we|which|everyone)\b/gi,
    fix: 'The sentence announces content instead of giving it. Delete it and write the content it points at.',
  },
  {
    name: 'empty-clause-colon', tier: 'block',
    // At least three more words and no digit before the colon: "The answer is
    // 4: ..." and "The answer is no: ..." carry content and pass.
    re: /(?:^|[.!?]\s+|\n\s*)(?:now,? |and |so |but |ok(?:ay)?,? |first,? |then )?(?:the|here(?:'s| is) the|this is the|that(?:'s| is) the) (?:answer|short answer|real answer|part|thing|key|reason|trick|catch|point|upshot|short version|real question|question you (?:actually )?asked|part you (?:actually )?asked|bit you (?:actually )?asked|piece you (?:actually )?asked)\b(?![^:\n]*\d)(?:[ ,]+[^\s:.!?,]+){3,}[^:.!?\n]{0,60}:\s+(?=\S)/gi,
    fix: 'Everything before the colon is about the sentence, not the subject. Start at the content after the colon.',
  },
  {
    name: 'dash-slogan', tier: 'block',
    re: /[—–-]{1,2}\s*[^.!?\n—]{1,60}\b(?:is|are|was|were) the \w+,\s+(?:and )?[^.!?\n]{1,60}\b(?:is|are|was|were) the \w+/gi,
    fix: 'The clause after the dash restates the sentence as a slogan. Cut it, or write the contrast as a plain sentence with a verb.',
  },
  {
    name: 'aphorism', tier: 'block',
    re: /\b(?:it|this|that|which|here)(?:'s| is| was) not (?:about |just |merely |only |simply |really )?[^.!?\n;,]{1,60}[;,]\s*(?:it|this|that)(?:'s| is| was) (?:about )?/gi,
    fix: 'Aphorism-shaped ("X is not Y; it is Z"). Write the plain sentence: what it is, with a verb.',
  },
  {
    name: 'em-dash', tier: 'block',
    re: /—|(?<!-)--(?!-)/g,
    fix: 'No em-dashes or double hyphens. Recast with a comma, a colon, or two sentences.',
  },
  {
    name: 'unpack', tier: 'block',
    re: /\blet(?:'s| us| me) (?:unpack|dive in|dive into|dig in|dig into|break (?:this|it|that) down|take a step back|zoom out)\b|\bbuckle up\b|\bbear with me\b|\bstay with me\b/gi,
    fix: 'Delete; start with the first fact.',
  },
  {
    name: 'ai-vocabulary', tier: 'block',
    re: /\bdelv(?:e|es|ed|ing)\b|\ba testament to\b|\btapestry\b|\bnavigat(?:e|es|ing) the (?:complexities|landscape|nuances)\b|\bin today's (?:fast-paced|ever-changing|rapidly evolving)\b|\bgame[- ]changer\b|\bunlock the (?:power|potential|secrets)\b/gi,
    fix: 'Replace with the plain word, or cut.',
  },
  {
    name: 'sentence-adverb', tier: 'block',
    re: /(?:^|[.!?]\s+|\n\s*)(?:Interestingly|Importantly|Crucially|Notably|Essentially|Basically|Fundamentally|Ultimately|Simply put|In essence|At its core|At the end of the day|Needless to say|It goes without saying(?: that)?),?\s/g,
    fix: 'Cut the adverb. If the point matters, the fact shows it.',
  },
  {
    name: 'self-commentary', tier: 'warn',
    re: /\b(?:as (?:I|we) (?:said|mentioned|noted|promised|saw|discussed)(?: earlier| above| before)?|which I(?:'ve| have) been (?:asserting|saying|claiming)|I(?:'ve| have) been (?:asserting|saying|claiming)|we(?:'ll| will) (?:get|come) (?:back )?to (?:that|this)|more on (?:that|this) (?:later|below|in a moment)|(?:as|which) (?:we'll|we will) see)\b/gi,
    fix: 'Commentary on the exposition; the reader cannot use it. Cut, or give the content now.',
  },
  {
    name: 'colon-joined-clauses', tier: 'warn',
    re: /\b[a-z][^:\n.!?]{25,}: [a-z]/g,
    fix: 'A colon joining two clauses. Check that the first clause says something on its own; if it only sets up the second, start at the second.',
  },
  {
    name: 'intensifier', tier: 'warn',
    re: /\b(?:genuinely|truly|really|actually|honestly|quite|very|extremely|incredibly|remarkably|deeply|profoundly|surprisingly|arguably)\b/gi,
    fix: 'Replace with the fact that makes it true, or cut.',
  },
  {
    name: 'worth-noting', tier: 'warn',
    re: /\b(?:it(?:'s| is) worth (?:noting|mentioning|pointing out|remembering)|note that|keep in mind(?: that)?|remember that|it should be noted|one thing to (?:note|notice))\b/gi,
    fix: 'Cut the frame and state the thing.',
  },
  {
    name: 'rhetorical-question', tier: 'warn',
    re: /\b(?:Why|How|What)\?\s+(?:Because|Well|Simple)\b|\bSo what(?:'s| is) (?:going on|happening|the deal)\b/g,
    fix: 'A question you then answer yourself. State the answer.',
  },
  {
    name: 'restating', tier: 'warn',
    re: /\b(?:in other words|put (?:simply|differently|another way)|to put it (?:simply|another way|differently)|that is to say|said differently|the bottom line is|long story short)\b/gi,
    fix: 'If the first phrasing was unclear, replace it. Do not say it twice.',
  },
  {
    name: 'vague-adjective', tier: 'warn',
    re: /\b(?:huge|massive|crucial|critical|vital|powerful|robust|seamless|elegant|profound|nuanced|sophisticated|comprehensive|holistic)\b/gi,
    fix: 'Give the number, the mechanism, or the example instead of the adjective.',
  },
  {
    name: 'closing-offer', tier: 'warn',
    re: /\b(?:I hope this helps|hope that helps|let me know if you(?:'d| would) like|feel free to|happy to (?:help|elaborate|dig deeper)|don't hesitate to)\b/gi,
    fix: 'Stop when the content stops.',
  },
];

// Replace skipped regions with spaces of equal length so offsets and line
// numbers stay aligned with the original text.
function blank(match) {
  return match.replace(/[^\n]/g, ' ');
}

function maskSkipped(text) {
  let t = String(text);
  if (t.startsWith('---\n')) {
    const end = t.indexOf('\n---', 4);
    if (end !== -1) t = blank(t.slice(0, end + 4)) + t.slice(end + 4); // YAML front matter
  }
  return t
    .replace(/```[\s\S]*?```/g, blank)                  // fenced code
    .replace(/`[^`\n]*`/g, blank)                        // inline code
    .replace(/https?:\/\/\S+/g, blank)                   // URLs
    .replace(/^[ \t]*>[^\n]*/gm, blank)                  // blockquotes (quoted examples)
    .replace(/"[^"]{1,400}"|“[^”]{1,400}”/g, blank)     // quoted spans up to two sentences, wrapped lines included (naming a bad phrase is not using it)
    .replace(/^[ \t]*\|?[ \t]*:?-{3,}[-|: \t]*$/gm, blank); // table rules and horizontal rules
}

function lineOf(text, index) {
  let n = 1;
  for (let i = 0; i < index; i++) if (text.charCodeAt(i) === 10) n++;
  return n;
}

// lintText(text, {tiers}) -> [{line, tier, name, match, fix}]
function lintText(text, opts) {
  const tiers = (opts && opts.tiers) || ['block', 'warn'];
  const masked = maskSkipped(text);
  const hits = [];
  for (const p of PATTERNS) {
    if (!tiers.includes(p.tier)) continue;
    p.re.lastIndex = 0;
    let m;
    while ((m = p.re.exec(masked)) !== null) {
      const raw = m[0];
      // A pattern anchored to the previous sentence's end matches ". " first;
      // report the line and text of the flagged sentence, not that boundary.
      const skip = raw.match(/^[.!?]?\s*/)[0].length;
      const match = raw.slice(skip).trim().replace(/\s+/g, ' ');
      hits.push({ line: lineOf(masked, m.index + skip), tier: p.tier, name: p.name, match, fix: p.fix });
      if (m.index === p.re.lastIndex) p.re.lastIndex++;
    }
  }
  hits.sort((a, b) => a.line - b.line || (a.tier === b.tier ? 0 : a.tier === 'block' ? -1 : 1));
  return hits;
}

function main(argv) {
  const files = [];
  let all = false;
  let json = false;
  for (const a of argv) {
    if (a === '--all') all = true;
    else if (a === '--json') json = true;
    else if (a === '-h' || a === '--help') {
      process.stdout.write('usage: filler-lint.js [--all] [--json] [file ...]\n');
      return 0;
    } else files.push(a);
  }
  const fs = require('fs');
  const inputs = files.length === 0 ? ['-'] : files;
  const tiers = all ? ['block', 'warn'] : ['block'];
  let blocks = 0;
  const report = [];
  for (const f of inputs) {
    let text;
    try {
      text = f === '-' ? fs.readFileSync(0, 'utf8') : fs.readFileSync(f, 'utf8');
    } catch (e) {
      process.stderr.write(`filler-lint: cannot read ${f}: ${e.message}\n`);
      return 2;
    }
    const hits = lintText(text, { tiers });
    for (const h of hits) {
      if (h.tier === 'block') blocks++;
      report.push({ file: f === '-' ? 'stdin' : f, ...h });
    }
  }
  if (json) {
    process.stdout.write(JSON.stringify(report, null, 2) + '\n');
  } else {
    for (const h of report) {
      process.stdout.write(`${h.file}:${h.line}: [${h.tier}] ${h.name}: "${h.match}" -> ${h.fix}\n`);
    }
    if (report.length === 0) process.stdout.write('no filler found\n');
  }
  return blocks > 0 ? 1 : 0;
}

module.exports = { PATTERNS, lintText, maskSkipped };

if (require.main === module) {
  process.exit(main(process.argv.slice(2)));
}
