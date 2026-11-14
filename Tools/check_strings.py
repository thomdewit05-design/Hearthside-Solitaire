#!/usr/bin/env python3
"""Checks that every localization key used in Swift exists in Localizable.xcstrings
with the right number of placeholders, including dynamic keys from HearthsideCore catalogs."""
import glob, json, os, re, sys

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

doc = json.load(open("Hearthside/Resources/Localizable.xcstrings"))["strings"]
by_base = {}
for key in doc:
    by_base.setdefault(key.split(" ")[0], []).append(key)

SKIP_PREFIX = ("com.", "ca-app", "hearthside.", "back_", "table_", "fire_")
SF_SYMBOL = re.compile(r"^(arrow|bag|chart|checkmark|crown|door|drop|flame|gearshape|gift|heat|house\.(fill|lodge)|leaf|lightbulb|list|lock|play|rectangle|square|suit|sun|trophy|wand|window)\b")
errors = []
for path in glob.glob("Hearthside/**/*.swift", recursive=True):
    src = open(path).read()
    for m in re.finditer(r'"((?:[a-z0-9_]+\.)+[a-z0-9_]+)((?: \\\((?:[^()]|\([^()]*\))*\))*)"', src):
        base, rest = m.group(1), m.group(2)
        if base.startswith(SKIP_PREFIX) or SF_SYMBOL.match(base) or base[0].isdigit():
            continue
        args = rest.count("\\(")
        candidates = by_base.get(base, [])
        if not candidates:
            errors.append(f"{path}: missing key {base}")
        elif not any(c.count("%") == args for c in candidates):
            errors.append(f"{path}: {base} used with {args} args, have {candidates}")

# Dynamic keys built from enums in HearthsideCore.
core = open("Packages/HearthsideCore/Sources/HearthsideCore/Economy/Village.swift").read()
kinds = re.findall(r"case (\w+)\s+//", core.split("enum MeasureKind")[1].split("public var phase")[0])
dynamic = [f"measure.{k}.{s}" for k in kinds for s in ("name", "tip")]
dynamic += [f"house.{h}.{s}" for h in re.findall(r'house\("(\w+)"', core) for s in ("name", "story")]
dec = open("Packages/HearthsideCore/Sources/HearthsideCore/Progress/DailyChallenge.swift").read()
dynamic += [f"decoration.{d.strip()}" for d in dec.split("case lanternPost")[0:1] and
            ("lanternPost," + dec.split("case lanternPost,")[1].split("\n\n")[0]).replace("\n", "").split(",") if d.strip()]
prog = open("Packages/HearthsideCore/Sources/HearthsideCore/Progress/PlayerProgress.swift").read()
dynamic += [f"cosmetic.{i}" for i in re.findall(r'CosmeticItem\(id: "(\w+)"', prog)]
dynamic += [f"cosmetic.category.{c}" for c in ("cardBack", "table", "fire")]
dynamic += [f"difficulty.{d}" for d in ("easy", "normal", "hard")] + [f"phase.{i}" for i in range(1, 5)]
dynamic += [f"rank.{r}" for r in ["ace", "jack", "queen", "king"] + list(range(2, 11))]
dynamic += [f"suit.{s}" for s in ("spades", "hearts", "clubs", "diamonds")]
for key in dynamic:
    if key not in doc:
        errors.append(f"dynamic key missing: {key}")

for key, value in doc.items():
    for lang, loc in value["localizations"].items():
        if loc["stringUnit"]["value"].count("%") != key.count("%"):
            errors.append(f"placeholder mismatch in {key} [{lang}]")

print("\n".join(errors) if errors else f"OK: {len(doc)} keys, {len(dynamic)} dynamic keys verified")
sys.exit(1 if errors else 0)
