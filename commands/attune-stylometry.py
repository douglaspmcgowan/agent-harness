#!/usr/bin/env python3
# attune-stylometry.py -- stdlib-only stylometric feature extraction for /tune.
# Reimplements the well-established metrics directly (no faststylometry / pystylometry:
# one has a known numpy-compatibility issue, the other's maintenance is unclear).
# Usage:  python attune-stylometry.py <mode_label> [--claim-min N] [--claim-max N]
#                                     [--compare REF_FILE] file1 [file2 ...]
#         (or pipe text on stdin and pass no files)
# --compare: also report cosine similarity (function words + char 3-grams) between
#            the measured text and REF_FILE (e.g. a register corpus) -- the light
#            in-session stand-in for Cosine Delta authorship distance.
# --compare also reports biber_delta: the piece's Biber dimension scores minus the reference's.
# --impostor FILE (repeatable): with --compare, runs the impostor-method verification:
#            the measured text's similarity to the Douglas corpus is ranked against its
#            similarity to each impostor text. Rank 1 of N on both feature sets =
#            consistent with Douglas. Needs 2+ impostors to mean anything.
# Output: one JSON object of measured features for that register, on stdout.
import sys, re, json, math, statistics
from collections import Counter

FUNCTION_WORDS = set("""
a an the of to in for on with at by from up about into over after under
and or but nor so yet because although though while if unless since as than
i you he she it we they me him her us them my your his its our their
this that these those is are was were be been being am do does did
have has had will would can could should may might must shall
not no there here what which who whom whose when where why how then
""".split())

# Douglas's signature markers (voice-detail.md recurring words/phrases + transcript profile)
MARKER_PHRASES = [
    "i think", "i don't think", "honestly", "the thing is", "the truth is",
    "in sum", "the goal is", "fundamentally", "basically", "go ahead and",
    "keep reading", "this entails", "make sure", "in fact",
]
# Hype/intensifier tells (he never writes hype -- a rising rate here is drift)
HYPE_WORDS = set("""
very truly incredibly extremely amazing exciting remarkable revolutionary
transformative thrilled delighted stunning phenomenal
""".split())

def sentences(text):
    # a markdown table would merge into one giant pseudo-sentence and corrupt the
    # sentence-length stdev -- drop table rows ('|'-led) and ---/=== separator rules first
    kept = []
    for ln in text.split('\n'):
        s = ln.strip()
        if s.startswith('|') or re.fullmatch(r'[-=|:\s]{3,}', s):
            continue
        kept.append(ln)
    t = '\n'.join(kept)
    # protect decimals (551.7) and a few abbreviations from the sentence splitter
    t = re.sub(r'(\d)\.(\d)', r'\1<DOT>\2', t)
    t = re.sub(r'\b(Mr|Mrs|Ms|Dr|vs|etc|Fig|Eq|e\.g|i\.e)\.',
               lambda m: m.group(0).replace('.', '<DOT>'), t)
    out = []
    # a blank-line paragraph break ends a sentence even without terminal punctuation
    for p in re.split(r'(?<=[.!?])\s+|\n\s*\n', t):
        p = p.replace('<DOT>', '.').strip()
        if p and re.search(r'[A-Za-z0-9]', p):
            out.append(p)
    return out

def words(text):
    return re.findall(r"[A-Za-z']+", text)

def _mtld_pass(tokens, threshold=0.72):
    factors, types, count = 0.0, set(), 0
    for tok in tokens:
        count += 1
        types.add(tok)
        if count and len(types) / count <= threshold:
            factors += 1
            types, count = set(), 0
    if count > 0:                                   # partial trailing factor
        ttr = len(types) / count
        denom = 1 - threshold
        factors += (1 - ttr) / denom if denom else 0
    return len(tokens) / factors if factors > 0 else float('nan')

def mtld(tokens):
    # MTLD is unreliable below ~50 tokens -- return null rather than fabricate a number
    if len(tokens) < 50:
        return None
    f = _mtld_pass(tokens)
    b = _mtld_pass(list(reversed(tokens)))
    return round((f + b) / 2, 1)

def sentence_openers(sents):
    # First-word distribution: measures the "This + verb" backbone, "But" contrast,
    # claim-first openings -- the strongest qualitative claims in voice-detail.md, counted.
    firsts = []
    for s in sents:
        ws = words(s)
        if ws:
            firsts.append(ws[0].lower())
    n = len(firsts) or 1
    top = Counter(firsts).most_common(8)
    return {
        'per_100_sentences': {w: round(100 * c / n, 1) for w, c in top},
        'pct_this': round(100 * firsts.count('this') / n, 1),
        'pct_but': round(100 * firsts.count('but') / n, 1),
        'pct_i': round(100 * firsts.count('i') / n, 1),
        'pct_however': round(100 * firsts.count('however') / n, 1),
    }

def rhythm(slens):
    # Sequence, beyond the distribution: his signature is a long setup followed by a
    # blunt short verdict. AI drafts regress toward even alternation; flat rhythm is
    # the overcorrection tell the audit looks for.
    if len(slens) < 2:
        return None
    pairs = list(zip(slens, slens[1:]))
    punches = sum(1 for a, b in pairs if a >= 20 and b <= 8)
    return {
        'long_to_short_punch_per_100_pairs': round(100 * punches / len(pairs), 1),
        'mean_abs_successive_diff': round(statistics.mean(abs(a - b) for a, b in pairs), 1),
    }

def marker_rates(text, toks):
    low = ' ' + re.sub(r'\s+', ' ', text.lower()) + ' '
    total = len(toks) or 1
    phrases = {p: round(low.count(' ' + p + ' ') / total * 1000, 2) for p in MARKER_PHRASES}
    phrases = {p: v for p, v in phrases.items() if v > 0}
    contractions = sum(1 for t in toks if "'" in t and len(t) > 2)
    hype = sum(1 for t in toks if t in HYPE_WORDS)
    return {
        'marker_phrases_per_1000': phrases,
        'contractions_per_1000': round(contractions / total * 1000, 2),
        'hype_intensifiers_per_1000': round(hype / total * 1000, 2),
        'exclamations_per_1000': round(text.count('!') / total * 1000, 2),
    }

LATINATE_SUFFIX = re.compile(
    r"(tion|sion|ity|ment|ance|ence|ize|ise|ise|ate|ous|ify|ology|ical|ative|itude)$")
# common be+participle pairs that are adjectival, never passive
NOT_PASSIVE_PART = set("""
interested concerned excited tired married located situated based supposed
used called named known open closed done finished
""".split())

def diction(toks):
    # Tests voice-detail's Anglo-Saxon-vs-Latinate diction claim ("make" over "create",
    # "use" over "utilize") as a measured dial, via suffix rate + word length.
    total = len(toks) or 1
    latinate = sum(1 for t in toks if len(t) > 6 and LATINATE_SUFFIX.search(t))
    return {
        'latinate_suffix_per_1000': round(latinate / total * 1000, 2),
        'mean_word_length': round(sum(len(t) for t in toks) / total, 2),
        'pct_words_7plus_chars': round(100 * sum(1 for t in toks if len(t) >= 7) / total, 1),
    }

PASSIVE_RE = re.compile(
    r"\b(is|are|was|were|been|being|be|am)\s+(?:(?:not|also|often|already|then|thus|"
    r"still|never|being)\s+)?(\w+(?:ed|en))\b", re.IGNORECASE)

def passive_rate(sents):
    # Regex approximation (be-form + past participle, common adjectival pairs excluded).
    # Overcounts irregular adjectives and misses get-passives -- treat as a register
    # comparator, never an absolute grammar count.
    if not sents:
        return None
    hits = 0
    for s in sents:
        for m in PASSIVE_RE.finditer(s):
            if m.group(2).lower() not in NOT_PASSIVE_PART:
                hits += 1
                break                                   # count sentences, once each
    return {
        'pct_sentences_passive': round(100 * hits / len(sents), 1),
        'note': 'regex estimate (be + past participle); comparator across registers, '
                'never an absolute grammar count',
    }

NOMINAL_RE = re.compile(r"^[a-z]{3,}(tion|sion|ment|ness|ity|ance|ence|ancy|ency|ism)s?$")
NOMINAL_EXEMPT = set("""
nation station mention question business city community moment government
experience evidence audience sentence science office difference century
""".split())
PARTICIPLE_CLAUSE_RE = re.compile(r",\s+(?:thereby\s+|thus\s+)?([a-z]{3,}ing)\b")
PARTICIPLE_EXEMPT = set("including according during regarding following nothing something "
                        "anything everything thing things being".split())

def noun_density(toks, text, sents):
    # Reinhart et al. (PNAS 2025): instruction-tuned models use nominalizations at
    # ~1.5-2x and comma-led present-participle clauses (", highlighting the need")
    # at ~2-5x the human rate. Suffix and regex estimates -- a comparator across
    # drafts and registers, never an absolute grammar count.
    total = len(toks) or 1
    nominal = sum(1 for t in toks if NOMINAL_RE.match(t) and t not in NOMINAL_EXEMPT)
    clauses = sum(1 for m in PARTICIPLE_CLAUSE_RE.finditer(text.lower())
                  if m.group(1) not in PARTICIPLE_EXEMPT)
    return {
        'nominalizations_per_1000': round(nominal / total * 1000, 2),
        'participle_clauses_per_100_sentences': round(clauses / (len(sents) or 1) * 100, 1),
        'note': 'suffix/regex estimates; compare against the corpus baseline, not as absolute counts',
    }

# Biber's six register dimensions (Biber 1988), approximated with word lists and
# regexes instead of a part-of-speech tagger. Each dimension score is the sum of its
# positive features minus its negative features, in occurrences per 1,000 words.
# Raw scores are NOT on Biber's published scale; read them against --compare or
# against other drafts, never as absolutes.
def _ws(s):
    return set(s.split())
BIBER = {
    'private_verbs': _ws("think thinks thought feel feels felt believe believes believed know knows knew "
                         "guess suppose supposed mean meant want wanted hope hoped wonder wondered realize "
                         "realized remember remembered understand understood assume assumed suspect figure figured"),
    'first_person': _ws("i me my mine myself we us our ours ourselves"),
    'second_person': _ws("you your yours yourself yourselves"),
    'hedges_amplifiers': _ws("maybe probably perhaps really very totally so pretty quite basically actually"),
    'be_do_present': _ws("is are am isn't aren't do does don't doesn't"),
    'prepositions': _ws("of in on at by for with from into about over under through between across"),
    'third_person': _ws("he she him her his hers himself herself they them their theirs themselves"),
    'past_irregular': _ws("was were had did said went came took made got saw knew thought told found gave "
                          "felt left kept began ran stood sat heard brought held"),
    'time_adverbs': _ws("now then today tomorrow yesterday soon later already afterwards eventually immediately"),
    'place_adverbs': _ws("here there above below nearby outside inside away behind ahead around abroad"),
    'prediction_modals': _ws("will would shall won't wouldn't"),
    'necessity_modals': _ws("must should ought need needs shouldn't"),
    'possibility_modals': _ws("can could may might can't couldn't"),
    'conditional': _ws("if unless"),
    'suasive_verbs': _ws("suggest suggests recommend recommends propose proposes insist insists urge urges "
                         "demand demands ensure ensures require requires request requests"),
    'conjuncts': _ws("however therefore thus moreover furthermore consequently hence nevertheless "
                     "nonetheless accordingly instead otherwise"),
    'demonstratives': _ws("this these those"),
}
CONTRACTION_RE = re.compile(r"\b\w+'(?:t|re|ve|ll|m|d)\b|\b(?:it|that|there|what|he|she)'s\b", re.IGNORECASE)
WH_RELATIVE_RE = re.compile(r"\w[,]?\s+(?:which|who|whom|whose)\b", re.IGNORECASE)
THAT_CLAUSE_RE = re.compile(r"\b(?:say|says|said|think|thinks|thought|know|knows|knew|believe|believes|"
                            r"believed|show|shows|showed|suggest|suggests|suggested|argue|argues|argued|"
                            r"mean|means|meant|find|finds|found|claim|claims|claimed|note|notes|noted)\s+that\b",
                            re.IGNORECASE)
ATTRIB_ADJ_RE = re.compile(r"^[a-z]{4,}(?:al|ive|ous|ic|able|ible|ary|ful|less)$")

def biber_dimensions(text, toks, sents):
    total = len(toks) or 1
    per = lambda n: n / total * 1000
    count = lambda key: sum(1 for t in toks if t in BIBER[key])
    f = {k: per(count(k)) for k in BIBER}
    f['contractions'] = per(len(CONTRACTION_RE.findall(text)))
    f['past_tense'] = per(sum(1 for t in toks if t.endswith('ed') and len(t) > 4)) + f['past_irregular']
    f['nominalizations'] = per(sum(1 for t in toks if NOMINAL_RE.match(t) and t not in NOMINAL_EXEMPT))
    f['wh_relatives'] = per(len(WH_RELATIVE_RE.findall(text)))
    f['that_clauses'] = per(len(THAT_CLAUSE_RE.findall(text)))
    f['attributive_adjectives'] = per(sum(1 for t in toks if ATTRIB_ADJ_RE.match(t)))
    f['mean_word_length'] = sum(len(t) for t in toks) / total
    pas = passive_rate(sents)
    f['passive_sentences_pct'] = pas['pct_sentences_passive'] if pas else 0.0
    d = {
        '1_involved_vs_informational': (f['private_verbs'] + f['first_person'] + f['second_person']
                                        + f['contractions'] + f['hedges_amplifiers'] + f['be_do_present'])
                                       - (f['nominalizations'] + f['prepositions'] + f['attributive_adjectives']
                                          + 10 * f['mean_word_length']),
        '2_narrative': f['past_tense'] + f['third_person'] - f['be_do_present'],
        '3_explicit_vs_situation_dependent': f['wh_relatives'] + f['nominalizations']
                                             - (f['time_adverbs'] + f['place_adverbs']),
        '4_overt_persuasion': f['prediction_modals'] + f['necessity_modals'] + f['possibility_modals']
                              + f['conditional'] + f['suasive_verbs'],
        '5_abstract': f['conjuncts'] + f['passive_sentences_pct'],
        '6_online_elaboration': f['that_clauses'] + f['demonstratives'],
    }
    return {
        'dimensions': {k: round(v, 1) for k, v in d.items()},
        'features_per_1000': {k: round(v, 2) for k, v in sorted(f.items())},
        'note': 'word-list/regex approximation of Biber (1988); raw scores are not on Biber\'s scale -- '
                'compare against the corpus (see compare.biber_delta) or other drafts, never as absolutes. '
                'Dimension 1 subtracts 10x mean word length as a stand-in for noun density.',
    }

# Syntactic templates (Shaib et al., EMNLP 2024, arXiv 2407.00211): part-of-speech
# sequences that recur across a text, such as DT JJ NN IN DT JJ NN ("a romantic comedy
# about a corporate executive"). Models reuse them far more than people: ~95% of model
# outputs vs ~38% of human references contained one in their study. Optional: needs spaCy
# and en_core_web_sm; without them this returns available=False and the rest still runs.
def syntactic_templates(text, n=6, min_count=3):
    try:
        import spacy, gzip
        nlp = spacy.load('en_core_web_sm', disable=['ner', 'lemmatizer'])
    except Exception as exc:                      # missing package or model
        return {'available': False,
                'note': f'needs spaCy + en_core_web_sm ({type(exc).__name__}); skipped'}
    doc = nlp(text)
    sents = [[t for t in s if not t.is_space] for s in doc.sents]
    sents = [s for s in sents if len(s) >= n]
    grams = Counter()
    per_sent = []
    for s in sents:
        tags = [t.tag_ for t in s]
        g = [tuple(tags[i:i + n]) for i in range(len(tags) - n + 1)]
        per_sent.append((s, g))
        grams.update(set(g))                       # count sentences containing each n-gram
    templates = {g for g, c in grams.items() if c >= min_count}
    hit = sum(1 for _, g in per_sent if any(x in templates for x in g))
    examples = []
    for g, c in grams.most_common():
        if g not in templates or len(examples) >= 5:
            continue
        for s, gs in per_sent:
            if g in gs:
                i = gs.index(g)
                examples.append({'tags': ' '.join(g), 'sentences': c,
                                 'example': ' '.join(t.text for t in s[i:i + n])})
                break
    pos_string = ' '.join(t.tag_ for t in doc if not t.is_space).encode()
    ntok = sum(len(s) for s in sents) or 1
    return {
        'available': True,
        'ngram_length': n,
        'min_sentences': min_count,
        'template_count': len(templates),
        'pct_sentences_with_template': round(100 * hit / (len(sents) or 1), 1),
        'templates_per_1000_tokens': round(sum(1 for _, g in per_sent for x in g if x in templates) / ntok * 1000, 1),
        'pos_compression_ratio': round(len(pos_string) / len(gzip.compress(pos_string)), 3) if pos_string else None,
        'top_templates': examples,
        'note': 'a template is a POS 6-gram found in 3+ sentences; rates and compression ratio grow with text length, '
                'so compare samples of similar size',
    }

def char3_counts(text):
    t = re.sub(r'\s+', ' ', text.lower())
    t = re.sub(r"[^a-z0-9 .,;:()\-']", '', t)
    return Counter(t[i:i + 3] for i in range(len(t) - 2))

def cosine(c1, c2):
    keys = set(c1) | set(c2)
    dot = sum(c1.get(k, 0) * c2.get(k, 0) for k in keys)
    n1 = math.sqrt(sum(v * v for v in c1.values()))
    n2 = math.sqrt(sum(v * v for v in c2.values()))
    return round(dot / (n1 * n2), 4) if n1 and n2 else None

def fw_vector(toks):
    total = len(toks) or 1
    return {w: c / total for w, c in Counter(t for t in toks if t in FUNCTION_WORDS).items()}

def main():
    argv = sys.argv[1:]
    mode = argv[0] if argv else 'unlabeled'
    claim_min = claim_max = None
    compare_file = None
    impostors = []
    files, i = [], 1
    while i < len(argv):
        if argv[i] == '--claim-min':
            claim_min = float(argv[i + 1]); i += 2
        elif argv[i] == '--claim-max':
            claim_max = float(argv[i + 1]); i += 2
        elif argv[i] == '--compare':
            compare_file = argv[i + 1]; i += 2
        elif argv[i] == '--impostor':
            impostors.append(argv[i + 1]); i += 2
        else:
            files.append(argv[i]); i += 1

    if files:
        text = "\n\n".join(open(f, encoding='utf-8', errors='replace').read() for f in files)
    else:
        text = sys.stdin.read()

    sents = sentences(text)
    slens = [len(words(s)) for s in sents if words(s)]
    toks = [w.lower() for w in words(text)]
    paras = [p for p in re.split(r'\n\s*\n', text.strip()) if p.strip()]
    para_counts = [len(sentences(p)) for p in paras]
    total = len(toks) or 1

    punct = {
        'em_dash': text.count('—'),
        'semicolon': text.count(';'),
        'colon': text.count(':'),
        'parenthesis_open': text.count('('),
        'comma': text.count(','),
    }
    fw = Counter(t for t in toks if t in FUNCTION_WORDS)

    para_q = 0
    for p in paras:
        ps = sentences(p)
        if ps and ps[0].rstrip().endswith('?'):
            para_q += 1

    result = {
        'mode': mode,
        'files': files or ['<stdin>'],
        'word_count': len(toks),
        'sentence_count': len(slens),
        'reliable': len(toks) >= 500,               # the 500-word floor for a meaningful pass
        'sentence_length': {
            'mean': round(statistics.mean(slens), 1) if slens else None,
            'median': statistics.median(slens) if slens else None,
            'min': min(slens) if slens else None,
            'max': max(slens) if slens else None,
            'stdev': round(statistics.pstdev(slens), 1) if len(slens) > 1 else None,
            'pct_punchy_3_8': round(100 * sum(1 for L in slens if 3 <= L <= 8) / len(slens), 1) if slens else None,
        },
        'sentence_openers': sentence_openers(sents),
        'rhythm': rhythm(slens),
        'ttr': round(len(set(toks)) / total, 3),
        'ttr_note': 'TTR is length-sensitive; compare only across similar-length texts. MTLD is the length-robust measure.',
        'mtld': mtld(toks),
        'function_word_per_1000': {w: round(c / total * 1000, 2) for w, c in fw.most_common(15)},
        'punctuation_per_1000_words': {k: round(v / total * 1000, 2) for k, v in punct.items()},
        'em_dash_check': {
            'count': punct['em_dash'],
            'target': 0,
            'pass': punct['em_dash'] == 0,
            'note': 'Hard gate per Douglas 2026-07-08: em-dashes are zero in every register. '
                    'Nonzero here is a fail regardless of register or corpus baseline.',
        },
        'diction': diction(toks),
        'passive_voice': passive_rate(sents),
        'noun_density': noun_density(toks, text, sents),
        'biber': biber_dimensions(text, toks, sents),
        'syntactic_templates': syntactic_templates(text),
        'markers': marker_rates(text, toks),
        'paragraph': {
            'count': len(paras),
            'mean_sentences': round(statistics.mean(para_counts), 1) if para_counts else None,
            'pct_single_sentence': round(100 * sum(1 for c in para_counts if c == 1) / len(para_counts), 1) if para_counts else None,
            'pct_question_opener': round(100 * para_q / len(paras), 1) if paras else None,
        },
    }
    if claim_min is not None and claim_max is not None and slens:
        within = sum(1 for L in slens if claim_min <= L <= claim_max)
        result['claimed_range'] = {
            'min': claim_min,
            'max': claim_max,
            'pct_within': round(100 * within / len(slens), 1),
            'mean_in_range': bool(claim_min <= statistics.mean(slens) <= claim_max),
        }
    if compare_file:
        ref_text = open(compare_file, encoding='utf-8', errors='replace').read()
        ref_toks = [w.lower() for w in words(ref_text)]
        ref_dims = biber_dimensions(ref_text, ref_toks, sentences(ref_text))['dimensions']
        result['compare'] = {
            'reference': compare_file,
            'cosine_similarity_function_words': cosine(fw_vector(toks), fw_vector(ref_toks)),
            'cosine_similarity_char3': cosine(char3_counts(text), char3_counts(ref_text)),
            'biber_delta': {k: round(v - ref_dims[k], 1) for k, v in result['biber']['dimensions'].items()},
            'biber_delta_note': 'piece minus reference, per dimension; positive = more of that dimension than the corpus',
            'note': 'Cosine similarity over relative-frequency vectors (1.0 = identical profile). '
                    'A lightweight stand-in for Cosine Delta: true Delta z-scores need a multi-document '
                    'reference set, which a single corpus file cannot provide.',
        }
        if impostors:
            # Impostor method (Koppel & Winter 2014, adapted): raw cosine alone has no
            # threshold, so calibrate by RANK -- is the piece closer to the Douglas
            # corpus than to each distractor text?
            my_fw, my_c3 = fw_vector(toks), char3_counts(text)
            candidates = [('DOUGLAS_CORPUS', ref_text)]
            for imp in impostors:
                candidates.append((imp, open(imp, encoding='utf-8', errors='replace').read()))
            scored = []
            for name, ctext in candidates:
                ctoks = [w.lower() for w in words(ctext)]
                scored.append({
                    'candidate': name,
                    'cosine_fw': cosine(my_fw, fw_vector(ctoks)),
                    'cosine_char3': cosine(my_c3, char3_counts(ctext)),
                })
            rank_fw = sorted(scored, key=lambda d: -(d['cosine_fw'] or 0))
            rank_c3 = sorted(scored, key=lambda d: -(d['cosine_char3'] or 0))
            pos_fw = 1 + [d['candidate'] for d in rank_fw].index('DOUGLAS_CORPUS')
            pos_c3 = 1 + [d['candidate'] for d in rank_c3].index('DOUGLAS_CORPUS')
            n = len(scored)
            result['impostor_verification'] = {
                'candidates': scored,
                'douglas_rank_function_words': f'{pos_fw} of {n}',
                'douglas_rank_char3': f'{pos_c3} of {n}',
                'consistent_with_douglas': bool(pos_fw == 1 and pos_c3 == 1),
                'note': 'Rank-calibrated verdict (impostor method): the piece is scored '
                        'consistent only if the Douglas corpus outranks every impostor on '
                        'BOTH feature sets. Confidence grows with impostor count; under 2 '
                        'impostors this is weak evidence either way.',
            }
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
