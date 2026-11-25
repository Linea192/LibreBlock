#!/usr/bin/env python3
"""Generates Shared/DefaultRules.swift with the precompiled default rule
JSON per blocker group, by running the same ABP->WebKit translation the
Swift RuleCompiler implements (a faithful Python port used ONLY for build-
time defaults; runtime compilation is the Swift code).

Reads Resources/filters/*.txt and writes the compact JSON into the
rawJSON dictionary of DefaultRules.swift.
"""

import json
import os
import re
from collections import defaultdict

import pathlib
BASE = str(pathlib.Path(__file__).resolve().parent.parent)
FILTERS = os.path.join(BASE, "Resources/filters")
OUT = os.path.join(BASE, "Shared/DefaultRules.swift")

# Which bundled lists feed which group (matches BlockerCatalog).
GROUP_LISTS = {
    "ads": ["mobile-ads", "popups"],
    "privacy": ["mobile-trackers"],
    "social": ["social-widgets"],
    "safety": ["nocoin"],
    "others": ["cookies", "webfonts"],
    "custom": [],
}

RESOURCE_MAP = {
    "script": "script", "image": "image", "stylesheet": "style-sheet",
    "xmlhttprequest": "rawfile", "subdocument": "document",
    "font": "font", "media": "media",
}
DROPPABLE_OPTIONS = {"match-case", "elemhide", "generichide",
                     "genericblock", "popup"}


def abp_to_regex(pattern: str) -> str | None:
    out = ""
    if pattern.startswith("||"):
        out = "^[a-z][a-z0-9+.-]*://(?:[^/]+\\.)?"
        pattern = pattern[2:]
    elif pattern.startswith("|"):
        out = "^"
        pattern = pattern[1:]
    suffix = ""
    if pattern.endswith("|"):
        suffix = "$"
        pattern = pattern[:-1]
    if not pattern:
        return None
    for ch in pattern:
        if ch == "*":
            out += ".*"
        elif ch == "^":
            out += "(?:[^a-zA-Z0-9_.%-]|$)"
        elif ch in "\\+?.()[]{}|$":
            out += "\\" + ch
        else:
            out += ch
    return out + suffix


def partition_domains(raw):
    inc, exc = [], []
    for d in raw:
        neg = d.startswith("~")
        d = d.lstrip("~").lower()
        if not d or not re.fullmatch(r"[a-z0-9.\-_*]+", d):
            continue
        (exc if neg else inc).append("*" + d)
    return inc, exc


def compile_network(line):
    is_exception = line.startswith("@@")
    body = line[2:] if is_exception else line

    options = []
    if "$" in body:
        body, _, optstr = body.rpartition("$")
        if optstr and not any(c.isspace() for c in optstr):
            options = optstr.split(",")
        else:
            # Not a valid options section; treat as literal.
            body = line[2:] if is_exception else line
            options = []

    if not body or len(body) > 300:
        return None
    if body.startswith("/") and body.endswith("/") and len(body) > 2:
        return None  # regex filter

    url_filter = abp_to_regex(body)
    if url_filter is None:
        return None

    trigger = {"url-filter": url_filter}
    resource_types = set()
    load_type = None
    inc, exc = [], []

    for raw_opt in options:
        opt = raw_opt.lower()
        neg = opt.startswith("~")
        tok = opt.lstrip("~")
        if tok in RESOURCE_MAP:
            if neg:
                return None
            resource_types.add(RESOURCE_MAP[tok])
        elif tok == "third-party":
            load_type = "first-party" if neg else "third-party"
        elif tok == "domain":
            if "=" not in raw_opt:
                return None
            vals = raw_opt.split("=", 1)[1].split("|")
            i, e = partition_domains(vals)
            inc += i
            exc += e
        elif tok in DROPPABLE_OPTIONS:
            pass
        else:
            return None

    if resource_types:
        trigger["resource-type"] = sorted(resource_types)
    if load_type:
        trigger["load-type"] = [load_type]
    if inc:
        trigger["if-domain"] = sorted(set(inc))
    if exc:
        trigger["unless-domain"] = sorted(set(exc))
    action = {"type": "ignore-previous-rules" if is_exception else "block"}
    return {"trigger": trigger, "action": action}


def compile_cosmetic(line):
    if "#?#" in line or "#%#" in line or "##+js(" in line:
        return None
    best = None
    best_off = len(line)
    for marker, is_exc in (("##", False), ("#@#", True)):
        off = line.find(marker)
        if off != -1 and off < best_off:
            domains_part = line[:off]
            selector = line[off + len(marker):].strip()
            best = (domains_part, selector, is_exc)
            best_off = off
    if best is None or not best[1]:
        return None
    domains_part, selector, is_exc = best
    if any(f in selector for f in ("::", ":-abp-", "{", "}", "+js(")):
        return None
    trigger = {"url-filter": ".*"}
    inc, exc = partition_domains(
        [d.strip() for d in domains_part.split(",") if d.strip()])
    if inc:
        trigger["if-domain"] = inc
    if exc:
        trigger["unless-domain"] = exc
    action = ({"type": "ignore-previous-rules"} if is_exc
              else {"type": "css-display-none", "selector": selector})
    return {"trigger": trigger, "action": action}


def compile_list(text):
    network, cosmetic, exceptions = [], [], []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("!") or line.startswith("["):
            continue
        if "##" in line or "#@#" in line:
            rule = compile_cosmetic(line)
            if rule:
                (exceptions if rule["action"]["type"] == "ignore-previous-rules"
                 else cosmetic).append(rule)
        else:
            rule = compile_network(line)
            if rule:
                (exceptions if rule["action"]["type"] == "ignore-previous-rules"
                 else network).append(rule)
    return network + cosmetic + exceptions


group_json = {}
for group, list_ids in GROUP_LISTS.items():
    combined = []
    for lid in list_ids:
        path = os.path.join(FILTERS, f"{lid}.txt")
        with open(path, encoding="utf-8") as f:
            rules = compile_list(f.read())
        combined.extend(rules)
    # custom group stays empty (user rules are runtime-compiled)
    group_json[group] = json.dumps(combined, separators=(",", ":"), sort_keys=True)

swift = """import Foundation

/// Build-time generated default rule sets, one per blocker group.
///
/// Generated by scripts/gen_default_rules.py from the bundled filter lists.
/// Extensions bundle this file so they serve correct rules on first launch
/// even when no App Group container exists (free developer accounts).
/// Do not edit by hand; regenerate instead.
public enum DefaultRules {
    /// Raw compact JSON of WebKit content blocker rules, keyed by group.
    static let rawJSON: [String: String] = [
"""

for group in ["ads", "privacy", "social", "safety", "others", "custom"]:
    payload = group_json[group]
    # Swift string literal safety: escape backslash and quote.
    escaped = payload.replace("\\", "\\\\").replace('"', '\\"')
    swift += f'        "{group}": "{escaped}",\n'

swift += """    ]

    /// The compiled rules for one group as JSON data.
    public static func json(for group: BlockerGroup) -> Data {
        guard let raw = rawJSON[group.rawValue], !raw.isEmpty else {
            return Data("[]".utf8)
        }
        return Data(raw.utf8)
    }
}
"""

with open(OUT, "w", encoding="utf-8") as f:
    f.write(swift)

total = sum(len(json.loads(v)) for v in group_json.values())
print(f"wrote {OUT}")
print(f"rule counts: " + ", ".join(f"{g}={len(json.loads(v))}" for g, v in sorted(group_json.items())))
print(f"total: {total}")
