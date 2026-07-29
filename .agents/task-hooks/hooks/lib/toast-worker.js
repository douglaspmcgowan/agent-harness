'use strict';

const fs = require('fs');
const { stateFile, showPopup } = require('./notifications.js');

const token = process.argv[2];
if (!token) process.exit(0);

async function main() {
  const deadline = Date.now() + 120000;
  while (Date.now() < deadline) {
    await new Promise(resolve => setTimeout(resolve, 400));
    const file = stateFile();
    if (!fs.existsSync(file)) return;
    let state;
    try { state = JSON.parse(fs.readFileSync(file, 'utf8')); } catch (_) { return; }
    if (state.token !== token || state.cancelled || state.shown) return;
    if (Date.now() >= state.firesAt) {
      showPopup(state.title, state.message);
      state.shown = true;
      state.shownAt = Date.now();
      fs.writeFileSync(file, JSON.stringify(state), 'utf8');
      return;
    }
  }
}

main().catch(() => process.exit(0));
