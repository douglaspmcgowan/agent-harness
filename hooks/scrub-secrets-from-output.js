#!/usr/bin/env node
// PostToolUse hook — scrubs API key patterns from Bash/PowerShell tool output
// before it enters the transcript / Claude's context.
//
// Triggered after the bug on 2026-05-19 where a trailing-newline in
// OPENAI_API_KEY caused httpx to throw LocalProtocolError with the
// raw key embedded in the error message, leaking it to the transcript.
//
// Patterns covered (anchored to the alphabet of real-world key formats):
//   - OpenAI:        sk-proj-..., sk-live-..., sk-test-..., sk- (legacy 48ch)
//   - Anthropic:     sk-ant-api03-...
//   - Google:        AIza[A-Za-z0-9_-]{35}
//   - AWS:           AKIA[0-9A-Z]{16}
//   - Stripe:        sk_live_..., sk_test_..., rk_live_..., rk_test_...
//   - GitHub:        ghp_[A-Za-z0-9]{36}, gho_[A-Za-z0-9]{36}, ghs_[A-Za-z0-9]{36}
//   - Slack:         xox[baprs]-[A-Za-z0-9-]{10,}
//   - Generic bearer tokens 24+ chars
//
// If any pattern matches in stdout/stderr, the hook returns:
//   - The output text with the secret replaced by `<REDACTED-<TYPE>>`
//   - An additionalContext note telling Claude that a secret was scrubbed
//
// Does NOT block the tool call — the call has already happened. This is a
// defensive scrub of what enters Claude's context window.

const chunks = [];
process.stdin.on('data', d => chunks.push(d));
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(Buffer.concat(chunks).toString());
    const resp = input.tool_response || {};

    // Patterns: [regex, label]
    const patterns = [
      [/sk-proj-[A-Za-z0-9_-]{16,}/g,            'OPENAI-PROJ-KEY'],
      [/sk-live-[A-Za-z0-9_-]{16,}/g,            'OPENAI-LIVE-KEY'],
      [/sk-test-[A-Za-z0-9_-]{16,}/g,            'OPENAI-TEST-KEY'],
      [/sk-ant-api\d{2}-[A-Za-z0-9_-]{40,}/g,    'ANTHROPIC-KEY'],
      [/sk-[A-Za-z0-9]{40,}/g,                   'OPENAI-LEGACY-KEY'],
      [/AIza[A-Za-z0-9_-]{35}/g,                 'GOOGLE-API-KEY'],
      [/AKIA[0-9A-Z]{16}/g,                      'AWS-ACCESS-KEY'],
      [/(sk|rk)_(live|test)_[A-Za-z0-9]{24,}/g,  'STRIPE-KEY'],
      [/gh[pous]_[A-Za-z0-9]{36}/g,              'GITHUB-TOKEN'],
      [/xox[baprs]-[A-Za-z0-9-]{20,}/g,          'SLACK-TOKEN'],
      [/Bearer\s+[A-Za-z0-9._-]{24,}/g,          'BEARER-TOKEN'],
    ];

    let scrubbedAny = false;
    const scrubbedTypes = new Set();

    function scrub(text) {
      if (typeof text !== 'string') return text;
      let out = text;
      for (const [re, label] of patterns) {
        out = out.replace(re, () => {
          scrubbedAny = true;
          scrubbedTypes.add(label);
          return `<REDACTED-${label}>`;
        });
      }
      return out;
    }

    const cleaned = {};
    for (const k of Object.keys(resp)) {
      cleaned[k] = scrub(resp[k]);
    }

    if (scrubbedAny) {
      const reply = {
        // Replace the tool response with the scrubbed version
        tool_response: cleaned,
        additionalContext: `[secret-scrub hook] Redacted secrets of type(s) ${[...scrubbedTypes].join(', ')} from tool output before they entered the transcript. The original tool ran normally — only the displayed output was sanitized. Rotate any leaked key as a precaution.`,
      };
      process.stdout.write(JSON.stringify(reply));
    } else {
      // No-op — emit empty object so the harness leaves the response alone
      process.stdout.write('{}');
    }
  } catch (e) {
    // Never break the hook — fail silently with empty no-op
    process.stdout.write('{}');
  }
});
