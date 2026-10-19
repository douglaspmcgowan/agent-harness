#!/usr/bin/env python3
# antislop-generate.py -- text-level backtracking generation for Claude models.
#
# Adapts the Antislop sampler (Paech et al., ICLR 2026, arXiv 2510.15061) to an API
# model whose token probabilities and assistant prefill are unavailable. Current Claude
# models reject a partial assistant turn (prefill returns 400), so the partial text is
# passed back inside the user turn instead:
#   1. Stream the reply and scan the accumulated text for banned patterns.
#   2. On a hit, stop the stream and cut the text back to where the hit begins.
#   3. Ask the model to continue the cut text, naming the phrase that triggered the cut.
#   4. If the same pattern reappears at the same spot, cut back to the sentence start;
#      after --max-retries at one spot, keep the text and move on.
#
# Usage: python antislop-generate.py "prompt text" [--model claude-opus-5-5]
#            [--ban-file bans.txt] [--max-retries 3] [--max-backtracks 20] [--no-fallback]
#        (or pipe the prompt on stdin)
# --ban-file: one regex per line ('#' comments allowed); replaces the default list.
# Output: the final text on stdout; a JSON backtrack report on stderr.
# Needs the `anthropic` package and Anthropic credentials (ANTHROPIC_API_KEY or `ant auth login`).
import sys, re, json, argparse

DEFAULT_BANS = [
    r"\bhere'?s\b",
    r"\bquietly\b",
    r"\bload-bearing\b",
    r"\bgenuinely\b",
    r"\bthis matters\b",
    r"\bwhy (?:\w+ ){0,3}matters\b",
    r"\bit'?s worth noting\b",
    r"\blet'?s break (?:it|this) down\b",
    r"\bthe (?:honest|short|real) (?:answer|version|truth)\b",
    r"\bdelve\w*\b",
    r"\btapestry\b",
    r"\btestament to\b",
    r"\bnot (?:just|only|merely) [^.;:!?]{1,60}?,? but\b",
    r"\b(?:it|this|that)(?: i|')s not [^.;:!?]{1,60}?[,;.]\s*(?:it|this|that)(?: i|')s\b",
    r"\bno \w+\. no \w+\. just\b",
    "—",
]

CONTINUE_TEMPLATE = (
    "{prompt}\n\n"
    "A draft of the response was started and is shown between the <draft> tags. "
    "Continue it from exactly where it stops, mid-sentence if needed. Output only the "
    "continuation: do not repeat the draft, do not comment on it, and do not wrap your output in tags. "
    "The draft was cut just before the phrase \"{hit}\"; do not use that phrase or a close variant there."
    "\n\n<draft>\n{draft}\n</draft>"
)

SYSTEM = ("Write plain, specific prose. Never use any of these patterns (regular expressions): {bans}")


def load_bans(path):
    if not path:
        return DEFAULT_BANS
    with open(path, encoding='utf-8') as fh:
        return [ln.strip() for ln in fh if ln.strip() and not ln.lstrip().startswith('#')]


def first_hit(text, start, patterns):
    """Earliest banned match beginning at or after `start`, as (pos, pattern, matched)."""
    best = None
    for p in patterns:
        m = p.search(text, start)
        if m and (best is None or m.start() < best[0]):
            best = (m.start(), p.pattern, m.group(0))
    return best


def sentence_start(text, pos):
    cut = max(text.rfind('. ', 0, pos), text.rfind('? ', 0, pos), text.rfind('! ', 0, pos),
              text.rfind('\n', 0, pos))
    return 0 if cut < 0 else cut + (1 if text[cut] == '\n' else 2)


class ClaudeStreamer:
    """Yields text chunks for one request; closing the generator early closes the stream."""

    def __init__(self, model, fallback):
        import anthropic
        self.client = anthropic.Anthropic()
        self.model = model
        self.fallback = fallback

    def __call__(self, system, user):
        kwargs = dict(model=self.model, max_tokens=64000, system=system,
                      messages=[{"role": "user", "content": user}])
        if self.fallback:
            stream_cm = self.client.beta.messages.stream(
                betas=["server-side-fallback-2026-07-01"], fallbacks="default", **kwargs)
        else:
            stream_cm = self.client.messages.stream(**kwargs)
        with stream_cm as stream:
            for chunk in stream.text_stream:
                yield chunk
            final = stream.get_final_message()
            if final.stop_reason == "refusal":
                raise RuntimeError("model declined the request (stop_reason=refusal)")


def generate(prompt, streamer, bans, max_retries=3, max_backtracks=20):
    patterns = [re.compile(b, re.IGNORECASE) for b in bans]
    system = SYSTEM.format(bans="; ".join(bans))
    text = ""
    committed = 0          # banned patterns that start before this offset are accepted
    retries = {}           # (cut position, pattern) -> attempts
    report = []
    user = prompt
    while True:
        cut = None
        gen = streamer(system, user)
        try:
            for chunk in gen:
                text += chunk
                hit = first_hit(text, committed, patterns)
                if hit:
                    cut = hit
                    break
        finally:
            gen.close()
        if cut is None:
            return text, report
        pos, pat, matched = cut
        key = (pos, pat)
        retries[key] = retries.get(key, 0) + 1
        if retries[key] > max_retries or len(report) >= max_backtracks:
            # Give up on this spot: accept the text through the end of the match. Past the
            # backtrack budget, stop scanning entirely so generation can finish.
            report.append({'pos': pos, 'pattern': pat, 'matched': matched, 'action': 'accepted'})
            committed = pos + len(matched)
            if len(report) > max_backtracks:
                patterns = []
            user = CONTINUE_TEMPLATE.format(prompt=prompt, hit=matched, draft=text[:committed])
            text = text[:committed]
            continue
        back_to = sentence_start(text, pos) if retries[key] > 1 else pos
        report.append({'pos': pos, 'pattern': pat, 'matched': matched,
                       'action': 'backtrack-to-sentence' if back_to != pos else 'backtrack'})
        text = text[:back_to]
        user = CONTINUE_TEMPLATE.format(prompt=prompt, hit=matched, draft=text)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('prompt', nargs='?')
    ap.add_argument('--model', default='claude-opus-5-5')
    ap.add_argument('--ban-file')
    ap.add_argument('--max-retries', type=int, default=3)
    ap.add_argument('--max-backtracks', type=int, default=20)
    ap.add_argument('--no-fallback', action='store_true',
                    help='skip the server-side refusal fallback (on by default for Opus 5.5)')
    a = ap.parse_args()
    prompt = a.prompt if a.prompt is not None else sys.stdin.read()
    if not prompt.strip():
        ap.error('no prompt given')
    streamer = ClaudeStreamer(a.model, fallback=not a.no_fallback)
    text, report = generate(prompt, streamer, load_bans(a.ban_file), a.max_retries, a.max_backtracks)
    print(text)
    print(json.dumps({'backtracks': report, 'count': len(report)}, indent=1), file=sys.stderr)


if __name__ == '__main__':
    main()
