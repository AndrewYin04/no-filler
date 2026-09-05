#!/usr/bin/env node
// Add or remove the no-filler Stop hook in a Claude Code settings file.
//
//   node settings-hook.js add    <settings.json> <hook command>
//   node settings-hook.js remove <settings.json>
//   node settings-hook.js status <settings.json>
//
// The hook entry is recognised by the marker "no-filler/scripts/stop-check.js"
// in its command, so add is idempotent and remove touches nothing else. A
// backup of the file is written beside it before any change. Exit 0 on
// success (status: 0 when installed, 1 when not), 2 on a malformed file.

'use strict';
const fs = require('fs');

const MARKER = 'no-filler/scripts/stop-check.js';

function load(file) {
  if (!fs.existsSync(file)) return {};
  const raw = fs.readFileSync(file, 'utf8');
  if (!raw.trim()) return {};
  return JSON.parse(raw);
}

function isOurs(entry) {
  return Array.isArray(entry && entry.hooks) &&
    entry.hooks.some((h) => h && typeof h.command === 'string' && h.command.includes(MARKER));
}

function main(argv) {
  const [op, file, command] = argv;
  if (!op || !file || (op === 'add' && !command)) {
    process.stderr.write('usage: settings-hook.js add|remove|status <settings.json> [hook command]\n');
    return 2;
  }
  let settings;
  try {
    settings = load(file);
  } catch (e) {
    process.stderr.write(`settings-hook: ${file} is not valid JSON (${e.message}); fix it or move it aside\n`);
    return 2;
  }
  const stops = (settings.hooks && Array.isArray(settings.hooks.Stop)) ? settings.hooks.Stop : [];
  const installed = stops.some(isOurs);

  if (op === 'status') {
    process.stdout.write(installed ? 'installed\n' : 'not installed\n');
    return installed ? 0 : 1;
  }
  if (op === 'add' && installed) {
    process.stdout.write(`already present in ${file}\n`);
    return 0;
  }
  if (op === 'remove' && !installed) {
    process.stdout.write(`not present in ${file}\n`);
    return 0;
  }
  if (fs.existsSync(file)) {
    const backup = `${file}.bak-${new Date().toISOString().replace(/[:.]/g, '-')}`;
    fs.copyFileSync(file, backup);
    process.stdout.write(`backup: ${backup}\n`);
  }
  settings.hooks = settings.hooks || {};
  if (op === 'add') {
    settings.hooks.Stop = stops.concat([{ hooks: [{ type: 'command', command, timeout: 15 }] }]);
    process.stdout.write(`added the no-filler Stop hook to ${file}\n`);
  } else {
    settings.hooks.Stop = stops.filter((e) => !isOurs(e));
    if (settings.hooks.Stop.length === 0) delete settings.hooks.Stop;
    if (Object.keys(settings.hooks).length === 0) delete settings.hooks;
    process.stdout.write(`removed the no-filler Stop hook from ${file}\n`);
  }
  fs.writeFileSync(file, JSON.stringify(settings, null, 2) + '\n');
  return 0;
}

process.exit(main(process.argv.slice(2)));
