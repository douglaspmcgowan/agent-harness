#!/usr/bin/env node
// Prevents accidental edits to firmware files (.hex, .bin, .elf, bootloader, etc.)
const chunks = [];
process.stdin.on('data', d => chunks.push(d));
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(Buffer.concat(chunks).toString());
    const path = input.tool_input?.file_path || '';
    const firmwarePatterns = [
      /firmware/i,
      /\.hex$/i,
      /\.elf$/i,
      /bootloader/i,
      /\.srec$/i,
      /\.ihex$/i,
    ];
    if (firmwarePatterns.some(p => p.test(path))) {
      process.stdout.write(JSON.stringify({
        continue: false,
        stopReason: `Blocked: "${path}" looks like a firmware file. Confirm explicitly to edit.`
      }));
    }
  } catch (_) {}
});
