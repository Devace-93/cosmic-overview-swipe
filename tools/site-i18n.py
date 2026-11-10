#!/usr/bin/env python3
"""Site translations for cosmic-swipe.3m4.net.

  tools/site-i18n.py extract   write site/i18n/en.json from the English text in site/index.html
  tools/site-i18n.py build     check every site/i18n/<lang>.json against en.json and write site/i18n.js

Keys come from data-i18n (plain text), data-i18n-html (inline markup) and
data-i18n-alt (an image's alt text) attributes, plus the meta keys below.
"""
import html
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
I18N = SITE / "i18n"
LANGS = ["en", "es", "fr", "de", "it", "pt", "nl", "sv", "pl", "cs", "ro", "el", "uk", "ru", "tr", "ar", "hi",
         "zh", "ja", "ko", "vi", "id", "th"]
META = {
    "metaTitle": "COSMIC Overview Swipe — touchpad swipes in the workspace overview",
    "metaDescription": "Swipe between workspaces inside the COSMIC workspace overview on Pop!_OS, with the strip following your fingers like macOS Mission Control. Prebuilt, no sudo, easy to remove.",
    "copy": "Copy",
}


def extract():
    src = (SITE / "index.html").read_text()
    out = dict(META)
    for m in re.finditer(r'<(\w+)([^>]*?)\sdata-i18n(-html)?="(\w+)"([^>]*)>(.*?)</\1>', src, re.S):
        key, is_html, body = m.group(4), m.group(3), m.group(6)
        text = " ".join(body.split())
        out[key] = text if is_html else html.unescape(text)
    for m in re.finditer(r'<img[^>]*\salt="([^"]*)"[^>]*data-i18n-alt="(\w+)"', src):
        out[m.group(2)] = html.unescape(m.group(1))
    I18N.mkdir(exist_ok=True)
    (I18N / "en.json").write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n")
    print(f"en.json: {len(out)} keys")


def tags(s):
    return sorted(re.findall(r"</?\w+", s))


def build():
    en = json.loads((I18N / "en.json").read_text())
    framework = (SITE / "i18n-framework.js").read_text()
    parts = [framework.rstrip() + "\n"]
    ok = True
    for lang in LANGS:
        path = I18N / f"{lang}.json"
        if not path.exists():
            print(f"missing {path.name}")
            ok = False
            continue
        cat = json.loads(path.read_text())
        missing = sorted(set(en) - set(cat))
        extra = sorted(set(cat) - set(en))
        if missing or extra:
            print(f"{lang}: missing {missing} extra {extra}")
            ok = False
        for k, v in cat.items():
            if k in en and tags(v) != tags(en[k]):
                print(f"{lang}.{k}: markup differs from English")
                ok = False
        parts.append(f"CosmicSwipeI18n.CATALOG.{lang} = {json.dumps(cat, ensure_ascii=False, indent=1)};\n")
    if not ok:
        sys.exit(1)
    (SITE / "i18n.js").write_text("\n".join(parts))
    print(f"i18n.js: {len(LANGS)} catalogs, {len(en)} keys each")


if __name__ == "__main__":
    {"extract": extract, "build": build}[sys.argv[1] if len(sys.argv) > 1 else "build"]()
