#!/usr/bin/env node
// After an Agent tool fires, write a reminder file so the next turn can call ScheduleWakeup
const fs = require('fs');
const path = require('path');

const chunks = [];
process.stdin.on('data', d => chunks.push(d));
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(Buffer.concat(chunks).toString());
    const toolName = input.tool_name || '';
    if (toolName !== 'Task' && toolName !== 'Agent') return;

    const agentType = input.tool_input?.subagent_type || '';
    const prompt = (input.tool_input?.prompt || '').toLowerCase();
    const isCodex = agentType.includes('codex') || prompt.includes('codex');
    if (!isCodex) return;

    const reminderPath = path.join(process.env.USERPROFILE || process.env.HOME || '', '.cursor', 'BACKGROUND-TASKS.md');
    const timestamp = new Date().toISOString();
    const entry = `\n- [${timestamp}] Codex agent dispatched. Prompt: ${(input.tool_input?.prompt || '').slice(0, 120)}...\n`;

    fs.appendFileSync(reminderPath, entry, 'utf8');
  } catch (_) {}
});
