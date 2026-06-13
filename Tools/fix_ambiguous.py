#!/usr/bin/env python3
"""Re-translate a few ambiguity-prone keys using clearer English source, and
patch them into the generated language files (fixes e.g. 'Issue'->publication)."""
import re, json, time, urllib.parse, urllib.request

TARGETS = [("pl", "pl"), ("ru", "ru"), ("pt-BR", "pt"), ("fr", "fr"), ("uk", "uk")]
# key -> clearer English to translate
OVERRIDES = {
    "status.problem": "Problem",
    "result.pass": "Passed",
    "result.fail": "Failed",
    "result.conditions": "Passed with conditions",
    "result.noEntry": "No entry (could not inspect)",
    "result.notReady": "Not ready for inspection",
    "result.notLocated": "Could not be located",
    "legend.unchecked": "Not yet inspected",
}

def tr(text, tl):
    url = ("https://translate.googleapis.com/translate_a/single?client=gtx"
           "&sl=en&tl=%s&dt=t&q=%s" % (tl, urllib.parse.quote(text)))
    with urllib.request.urlopen(url, timeout=20) as r:
        data = json.load(r)
    return "".join(seg[0] for seg in data[0] if seg[0])

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')

for folder, tl in TARGETS:
    path = "Resources/%s.lproj/Localizable.strings" % folder
    lines = open(path, encoding="utf-8").read().splitlines()
    new = {}
    for key, src in OVERRIDES.items():
        new[key] = esc(tr(src, tl)); time.sleep(0.05)
    out = []
    for line in lines:
        m = re.match(r'^"([^"]+)"\s*=', line)
        if m and m.group(1) in new:
            out.append('"%s" = "%s";' % (m.group(1), new[m.group(1)]))
        else:
            out.append(line)
    open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print("patched", folder)
