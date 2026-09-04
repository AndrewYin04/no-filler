#!/usr/bin/env node
// Stop hook for the no-filler skill.
//
// Claude Code runs this when the assistant finishes a turn, in any session
// where the skill was invoked (by the user or by Claude). It lints the reply
// with filler-lint.js at block tier and refuses the reply when a pattern
// matches, handing back the flagged sentences so the model rewrites them.
// It allows the retry pass (stop_hook_active) unconditionally and allows
// unreadable input, so it can never trap a session.
//
// Exit 2 + stderr = block and hand the reason to the model. Exit 0 = allow.

'use strict';
const fs = require('fs');
const path = require('path');
const { lintText } = require('./filler-lint.js');

const MAX_SHOWN = 6;

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch (_) {
    return '';
  }
}

function debug(cwd, line) {
  if (!process.env.NO_FILLER_HOOK_DEBUG) return;
  try {
    fs.appendFileSync(path.join(cwd, '.no-filler-hook.log'), `${new Date().toISOString()} ${line}\n`);
  } catch (_) { /* ignore */ }
}

function main() {
  let input = {};
  try {
    input = JSON.parse(readStdin() || '{}');
  } catch (_) {
    process.exit(0);
  }
  const cwd = input.cwd || process.cwd();
  if (input.stop_hook_active) {
    debug(cwd, 'retry pass: allowing');
    process.exit(0);
  }
  const msg = typeof input.last_assistant_message === 'string' ? input.last_assistant_message : '';
  if (!msg.trim()) {
    debug(cwd, 'no last_assistant_message: allowing');
    process.exit(0);
  }
  let hits = [];
  try { hits = lintText(msg, { tiers: ['block'] }); } catch (_) { /* ignore */ }
  debug(cwd, `filler=${hits.length}`);
  if (hits.length === 0) process.exit(0);
  const shown = hits.slice(0, MAX_SHOWN)
    .map((h) => `"${h.match}" (${h.name}: ${h.fix})`).join('; ');
  const more = hits.length > MAX_SHOWN ? `; and ${hits.length - MAX_SHOWN} more` : '';
  process.stderr.write(
    `no-filler: the reply contains filler. ${shown}${more}. Rewrite those ` +
    'sentences so each states a fact, an example, or a decision; keep every ' +
    'other sentence; put quoted bad examples in a blockquote; then stop.\n'
  );
  process.exit(2);
}

main();
