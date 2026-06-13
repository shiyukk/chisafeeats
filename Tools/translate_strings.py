#!/usr/bin/env python3
"""Generate full Localizable.strings for additional languages by translating
the English base via Google's keyless endpoint, preserving %-format specifiers."""
import re, json, sys, time, urllib.parse, urllib.request

BASE = "Resources/en.lproj/Localizable.strings"
# (folder code, google tl)
TARGETS = [("pl", "pl"), ("ru", "ru"), ("pt-BR", "pt"), ("fr", "fr"), ("uk", "uk")]

LINE = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$')
SPEC = re.compile(r'%(?:\d+\$)?(?:@|lld|ld|lf|d|f)')

def parse(path):
    items = []
    for line in open(path, encoding="utf-8"):
        m = LINE.match(line.strip())
        if m:
            items.append((m.group(1), m.group(2)))
    return items

def translate(text, tl):
    if not re.search(r'[A-Za-z]', text):   # nothing to translate (symbols/numbers)
        return text
    holds = []
    def repl(m):
        holds.append(m.group(0))
        return chr(0xE000 + len(holds) - 1)
    protected = SPEC.sub(repl, text)
    url = ("https://translate.googleapis.com/translate_a/single?client=gtx"
           "&sl=en&tl=%s&dt=t&q=%s" % (tl, urllib.parse.quote(protected)))
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=20) as r:
                data = json.load(r)
            out = "".join(seg[0] for seg in data[0] if seg[0])
            for i, h in enumerate(holds):
                out = out.replace(chr(0xE000 + i), h)
            return out
        except Exception as e:
            time.sleep(0.5 * (attempt + 1))
    print("  ! failed:", text[:40], file=sys.stderr)
    return text   # fall back to English on failure

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')

items = parse(BASE)
print("base keys:", len(items))
for folder, tl in TARGETS:
    out_path = "Resources/%s.lproj/Localizable.strings" % folder
    lines = ['/* %s — machine-translated from English */' % folder]
    for i, (key, val) in enumerate(items):
        t = translate(val, tl)
        lines.append('"%s" = "%s";' % (key, esc(t)))
        time.sleep(0.05)
    open(out_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("wrote", out_path, "(%d keys)" % len(items))
