#!/usr/bin/env python3
"""Re-extract Henge's user-visible English strings from the SwiftUI sources.

Run from anywhere:  python3 ios/Localization/extract_ui_keys.py > keys.json

SwiftUI text literals are LocalizedStringKeys, so the English text itself is the key
in zh-Hans.lproj/Localizable.strings. This lists the candidates; log messages and
SF Symbol names are filtered out. Missing keys fall back to English automatically.
"""
import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SWIFT = os.path.join(ROOT, 'ios', 'Henge', '**', '*.swift')

CTOR = re.compile(
    r'(?:Text|Button|Toggle|Label|DeskHeading|Section|Picker|Menu|Link|TextField|'
    r'SecureField|navigationTitle|accessibilityLabel|confirmationDialog|alert|help|'
    r'navigationBarTitle|DisclosureGroup)\s*\(\s*"((?:[^"\\]|\\.)*)"')
TERNARY = re.compile(r'\?\s*"((?:[^"\\]|\\.)*)"\s*:\s*"((?:[^"\\]|\\.)*)"')
NOISE = re.compile(
    r'\b(log|failed|rc ==|env |debug|snapshot|snap |knob|pointer |colorprobe|'
    r'made in code|unknown command|no answer|bytes=|HTTP )', re.I)

keys = []
for path in sorted(glob.glob(SWIFT, recursive=True)):
    src = open(path, encoding='utf-8').read()
    keys += [m.group(1) for m in CTOR.finditer(src)]
    for m in TERNARY.finditer(src):
        keys += [m.group(1), m.group(2)]

out = []
for k in keys:
    k = k.replace('\\n', '\n')
    if k in out or len(k) < 2 or not re.search(r'[A-Za-z]', k):
        continue
    if any(x in k for x in ('\\(', '%%', 'http', 'HV_', '.png', '.bin', '.gz', '.json')) and ' ' not in k:
        continue
    if NOISE.search(k):
        continue
    out.append(k)

print(json.dumps(out, ensure_ascii=False, indent=1))
