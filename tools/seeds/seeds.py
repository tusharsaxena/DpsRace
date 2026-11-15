#!/usr/bin/env python3
"""tools/seeds/seeds.py — re-validate DPS Race's seed lists against one wago.tools build.

WHAT THIS IS
    The contract `/dev-copilot:validate-seeds DpsRace retail` runs (docs/validate-seeds.md). DPS Race
    ships two id lists that mirror the client's own DB2 data:

    defaults/Hearthstones.lua   NS.HEARTHSTONE_SPELLS, every hearthstone variant's spell id (#8).
                                DERIVED: the file's header states the four rules it was built by,
                                and `derive` runs exactly those rules (derive_hearthstones).

    defaults/Dummies.lua, the training-dummy catalog, is NOT checked here. Its header says a row is
    added from a MEASUREMENT and never guessed, so it would take no candidates anyway; and its
    existence and name check has nothing to read: the client's Creature DB2 holds only the ~23k
    creatures the client needs data for (12.1.5.70783: ids 3 to 276385, 23167 rows), and not one of
    the catalog's 42 ids is among them, on 12.1.5.70575 or on 12.1.5.70783. A training dummy's name
    reaches the client from the server, so no DB2 table names it (docs/validate-seeds.md, Notes).

    Candidates (key `hearthstones:<id>`, ruled accept or reject): ids the build's rules derive that
    the list does not ship.

    Flags (key `shipped:<kind>:hearthstones:<id>`, ruled keep or remove), over every shipped id:
        unnamed    the build's SpellName has no row for it
        renamed    its name on the build disagrees with the comment beside it in the file
        unfit      it is named but the four rules no longer derive it

    A ruling is keyed by list and id, never by build, and holds until the thing it ruled on stops
    being proposed. So a re-run on a later build shows only what is new since the last ruled one.

HOW THE FOUR RULES READ (defaults/Hearthstones.lua's header)
    1. every spell with a SpellCategories row whose ChargeCategory is 2309 (any DifficultyID);
    2. plus every spell with a SpellEffect row of Effect 252 (teleport) and ImplicitTarget 9 (the
       bind point) in either target slot. The header adds "that a toy or an item casts", and rule 4
       then removes by id "the teleports home no item casts or that are test data": the 2026-10-28
       list was therefore every bind-point teleport less rule 4's ids. That reading is the one that
       reproduces the shipped list (three shipped ids, 191329, 431644 and 1286909, have no ItemEffect
       row of their own), so it is the one coded here; whether an item casts the spell, directly or
       through a spell whose EffectTriggerSpell it is, is reported on every candidate as a note for
       the ruling instead (ItemEffect, ItemXItemEffect, Toy);
    3. plus 222695 and 171253, by id;
    4. minus EXCLUDED, by id.
    A sentinel gate (SENTINELS) stops the run when the rules come up thin.

THE STEPS
    python3 tools/seeds/seeds.py status [--flavor retail]
    python3 tools/seeds/seeds.py derive --flavor retail --bundle docs/seed-research/<date>-retail --date <date> [--build V] [--replay]
    python3 tools/seeds/seeds.py check  --bundle docs/seed-research/<date>-retail
    python3 tools/seeds/seeds.py rule   --tsv <file> --bundle docs/seed-research/<date>-retail
    python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-retail --date <date>
    python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-retail --date <date>

    `derive` pins one build (`--build`, else the flavor's live build from the builds API), fetches
    every table into the git-ignored tools/seeds/.cache/ (streamed, never read whole), freezes them
    gzipped into the bundle's raw/, and writes SOURCES.md, DIFF.md and candidates.json. `--replay`
    reads only the bundle's raw/ and needs no network. `rule` is the only writer of
    tools/seeds/rulings.json. `check` exits 1 while anything is unruled. `report` writes RULINGS.md.
    `apply` refuses while anything is unruled, is idempotent, and keeps each file's line endings
    and layout. The date is always an argument; nothing here reads the clock.

    Patterns are copied from Aura Master's tools/spell-research/ (retail.py, sid_seeds.py), never
    imported across repos. Whether a shared helper should carry the build pin, the cache, the bundle
    and the rulings is LibKa0s#91.

Python 3.8+ and its standard library only.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import re
import shutil
import sys
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
RESEARCH = REPO / "docs" / "seed-research"
RULINGS_PATH = HERE / "rulings.json"
CACHE_DIR = HERE / ".cache"
HEARTH_FILE = REPO / "defaults" / "Hearthstones.lua"

BUILDS_URL = "https://wago.tools/api/builds"
CSV_URL = "https://wago.tools/db2/{table}/csv?build={build}"
# wago.tools answers HTTP 403 to urllib's default User-Agent; this says who is asking.
USER_AGENT = "ka0s-seed-validation (DpsRace tools/seeds)"
DOWNLOAD_CHUNK = 1 << 20  # SpellEffect is ~57 MB: always streamed, never read into one string

# The client a flavor validates and its own wago product (clients-§10). DPS Race is Retail only.
FLAVORS = {"retail": {"product": "wow", "title": "Retail"}}

# The fetch list IS the list SOURCES.md records, so a bundle never claims a table it did not read.
TABLES = (
    ("SpellCategories", "ChargeCategory: rule 1, the hearthstone charge category 2309"),
    ("SpellEffect", "Effect 252 + ImplicitTarget 9: rule 2; EffectTriggerSpell: the item-cast note"),
    ("SpellName", "every shipped hearthstone's name, for the unnamed and renamed flags"),
    ("ItemEffect", "the spell an item effect casts: the item-cast note on a rule 2 candidate"),
    ("ItemXItemEffect", "item effect -> item: which item casts it"),
    ("Toy", "item -> toy: whether the item that casts it is a toy"),
)

HEARTH_CHARGE_CATEGORY = "2309"
TELEPORT_EFFECT = "252"
BIND_POINT_TARGET = "9"
FIXED = {222695: "Dalaran Hearthstone: a cooldown of its own, a fixed destination (rule 3)",
         171253: "Garrison Hearthstone: a cooldown of its own, a fixed destination (rule 3)"}
EXCLUDED = {
    556: "Astral Recall, a class spell a player can add (rule 4)",
    1: "Word of Recall (OLD), test data (rule 4)",
    3: "Word of Mass Recall (OLD), test data (rule 4)",
    70195: "[PH] Portable Hole, a placeholder (rule 4)",
    307896: "Hearthstone - Ethereal - TEST, test data (rule 4)",
    1223998: "[DNT] Force Hearthstone, test data (rule 4)",
    49493: "Mole Machine Port to Hearth: no item casts it, not on the hearthstone cooldown (rule 4)",
    188816: "Teleport: no item casts it, not on the hearthstone cooldown (rule 4)",
}
# Ids the game, not this tool's output, says must be derived: the Hearthstone itself (rule 1) and
# rule 3's two. A run that misses one stops rather than proposing to remove half the list.
SENTINELS = {8690: "Hearthstone", 222695: "Dalaran Hearthstone", 171253: "Garrison Hearthstone"}

LISTS = ("hearthstones",)
CANDIDATE_RULINGS = ("accept", "reject")
FLAG_RULINGS = ("keep", "remove")
FLAG_KINDS = {"hearthstones": ("unnamed", "renamed", "unfit")}
KEY = re.compile(r"^(?:shipped:(?P<kind>[a-z-]+):)?(?P<list>[a-z]+):(?P<id>\d+)$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

HEARTH_TABLE_OPEN = re.compile(r"^NS\.HEARTHSTONE_SPELLS\s*=\s*\{\s*$")
HEARTH_ROW = re.compile(r"^\s+(\d+),\s*--\s*(.*?)\s*$")


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


# ---------------------------------------------------------------------------
# Files: CRLF in this repo (.gitattributes `* text=auto eol=crlf`), whatever Python's default is
# ---------------------------------------------------------------------------

def write_repo_text(path: Path, text: str) -> None:
    """Write a tracked text file with CRLF terminators, as bytes (tests/_kit/test_eol.lua checks)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8"))


def write_json(path: Path, doc) -> None:
    write_repo_text(path, json.dumps(doc, indent=1, sort_keys=True, ensure_ascii=False) + "\n")


def split_lines(text: str):
    """`(lines, newline)`: the file's lines without terminators, and the terminator it uses."""
    newline = "\r\n" if "\r\n" in text else "\n"
    return text.replace("\r\n", "\n").split("\n"), newline


# ---------------------------------------------------------------------------
# wago.tools
# ---------------------------------------------------------------------------

def http_get(url: str, accept: str = "*/*"):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": accept})
    try:
        return urllib.request.urlopen(req, timeout=300)
    except urllib.error.HTTPError as err:  # 400: no such table on this build; 403: the User-Agent
        raise SystemExit("HTTP %s fetching %s: %s" % (err.code, url, err.reason))
    except urllib.error.URLError as err:
        raise SystemExit("Could not reach %s: %s (a new run needs network access)" % (url, err.reason))


def live_build(product: str) -> str:
    """The newest build of `product` from the builds API (newest first per product)."""
    data = json.load(http_get(BUILDS_URL, accept="application/json"))
    builds = data.get(product) or []
    if not builds:
        raise SystemExit("The builds API returned no '%s' builds; pass --build." % product)
    return builds[0]["version"]


def fetch_table(table: str, build: str, cache_dir: Path) -> Path:
    """One table's CSV for `build`, from the cache or streamed into it (renamed only when whole)."""
    cache_dir.mkdir(parents=True, exist_ok=True)
    dest = cache_dir / ("%s-%s.csv" % (table, build))
    if dest.exists():
        log("  %-16s cached (%.1f MB)" % (table, dest.stat().st_size / 1e6))
        return dest
    url = CSV_URL.format(table=table, build=build)
    tmp = dest.with_suffix(".csv.part")
    log("  %-16s fetching %s" % (table, url))
    with http_get(url, accept="text/csv") as response, tmp.open("wb") as handle:
        shutil.copyfileobj(response, handle, DOWNLOAD_CHUNK)
    tmp.replace(dest)
    return dest


def freeze_tables(bundle: Path, build: str, cache_dir: Path, replay: bool) -> dict:
    """`{table: raw member}`: every TABLES member in the bundle's raw/, gzipped from the cache
    unless `replay`, where the bundle must already hold each one."""
    raw = bundle / "raw"
    raw.mkdir(parents=True, exist_ok=True)
    out = {}
    for table, _why in TABLES:
        member = raw / ("%s.csv.gz" % table)
        if replay:
            if not member.exists():
                raise SystemExit("--replay: %s is missing raw/%s.csv.gz; a bundle that cannot hand "
                                 "back every table it read cannot reproduce its numbers." % (bundle, table))
        else:
            source = fetch_table(table, build, cache_dir)
            # mtime=0 and no file name in the header: the same CSV always freezes to the same bytes.
            with source.open("rb") as src, member.open("wb") as raw_out, \
                    gzip.GzipFile(filename="", mode="wb", compresslevel=9, fileobj=raw_out, mtime=0) as dst:
                shutil.copyfileobj(src, dst, DOWNLOAD_CHUNK)
        out[table] = member
    return out


def iter_csv(path: Path):
    """Each row as a dict, one at a time; a `.gz` member is decompressed on the fly. Columns are
    addressed by header name, never by position (clients-§10)."""
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            yield row


def _int(value) -> int:
    try:
        return int(value or 0)
    except ValueError:
        return 0


# ---------------------------------------------------------------------------
# The build's facts
# ---------------------------------------------------------------------------

class Facts:
    """What the rules and the flags read off one build's tables."""

    def __init__(self, tables: dict):
        self.spell_names = {_int(r["ID"]): r["Name_lang"] for r in iter_csv(tables["SpellName"])}
        self.charge = {_int(r["SpellID"]) for r in iter_csv(tables["SpellCategories"])
                       if r["ChargeCategory"] == HEARTH_CHARGE_CATEGORY}
        self.teleports, self.triggered_by = set(), {}
        for r in iter_csv(tables["SpellEffect"]):
            spell = _int(r["SpellID"])
            if r["Effect"] == TELEPORT_EFFECT and BIND_POINT_TARGET in (r["ImplicitTarget_0"], r["ImplicitTarget_1"]):
                self.teleports.add(spell)
            trigger = _int(r["EffectTriggerSpell"])
            if trigger:
                self.triggered_by.setdefault(trigger, set()).add(spell)
        effect_spell = {_int(r["ID"]): _int(r["SpellID"]) for r in iter_csv(tables["ItemEffect"])}
        toys = {_int(r["ItemID"]) for r in iter_csv(tables["Toy"])}
        self.cast_by = {}  # spell -> {(item, is_toy)}
        for r in iter_csv(tables["ItemXItemEffect"]):
            spell = effect_spell.get(_int(r["ItemEffectID"]))
            if spell:
                item = _int(r["ItemID"])
                self.cast_by.setdefault(spell, set()).add((item, item in toys))

    def item_note(self, spell: int) -> str:
        """Who casts `spell`: a toy, an item, or a spell an item casts (one EffectTriggerSpell hop)."""
        direct = sorted(self.cast_by.get(spell, ()))
        if direct:
            return "cast by " + ", ".join("%s %d" % ("toy" if toy else "item", item) for item, toy in direct[:4])
        parents = sorted(p for p in self.triggered_by.get(spell, ()) if p in self.cast_by)
        if parents:
            return "triggered by %s, which an item casts" % ", ".join(str(p) for p in parents[:4])
        return "no item casts it"


def derive_hearthstones(facts: Facts) -> dict:
    """`{id: [rules]}`: the four rules of defaults/Hearthstones.lua's header, as the docstring reads
    them. Raises SystemExit when a sentinel is not derived."""
    out = {}
    for spell in facts.charge:
        out.setdefault(spell, []).append("rule 1: ChargeCategory 2309")
    for spell in facts.teleports:
        out.setdefault(spell, []).append("rule 2: Effect 252, ImplicitTarget 9")
    for spell in FIXED:
        out.setdefault(spell, []).append("rule 3: by id")
    for spell in EXCLUDED:
        out.pop(spell, None)
    missing = ["%d %s" % (s, n) for s, n in sorted(SENTINELS.items()) if s not in out or s not in facts.spell_names]
    if missing:
        raise SystemExit("Hearthstone sentinel gate FAILED: %s not derived. Fix the rules before ruling."
                         % ", ".join(missing))
    return out


# ---------------------------------------------------------------------------
# The seed files
# ---------------------------------------------------------------------------

def read_hearthstones(path: Path) -> list:
    """`[{id, name}]`, in file order, from the NS.HEARTHSTONE_SPELLS table."""
    lines, _nl = split_lines(path.read_bytes().decode("utf-8"))
    rows, inside = [], False
    for line in lines:
        if HEARTH_TABLE_OPEN.match(line):
            inside = True
            continue
        if inside:
            if line.strip() == "}":
                return rows
            match = HEARTH_ROW.match(line)
            if not match:
                raise SystemExit("%s: %r is not an `<id>, -- <name>` row." % (path, line))
            rows.append({"id": int(match.group(1)), "name": match.group(2)})
    raise SystemExit("%s: no closed NS.HEARTHSTONE_SPELLS table." % path)


# ---------------------------------------------------------------------------
# Candidates and flags
# ---------------------------------------------------------------------------

def _flag(kind: str, lst: str, row: dict, build_name: str) -> dict:
    return {"key": "shipped:%s:%s:%d" % (kind, lst, row["id"]), "kind": kind, "list": lst,
            "id": row["id"], "name": build_name or "", "comment": row["name"]}


def hearth_findings(facts: Facts, derived: dict, shipped: list):
    """`(candidates, flags)` for the hearthstone list."""
    ids = {row["id"] for row in shipped}
    candidates = [{"key": "hearthstones:%d" % s, "list": "hearthstones", "id": s,
                   "name": facts.spell_names.get(s, ""), "notes": derived[s] + [facts.item_note(s)]}
                  for s in sorted(derived) if s not in ids]
    flags = []
    for row in shipped:
        name = facts.spell_names.get(row["id"])
        if not name:
            flags.append(_flag("unnamed", "hearthstones", row, ""))
            continue
        if name.lower() != row["name"].lower():
            flags.append(_flag("renamed", "hearthstones", row, name))
        if row["id"] not in derived:
            flags.append(_flag("unfit", "hearthstones", row, name))
    return candidates, flags


def derive_doc(tables: dict, flavor: str, build: str, date: str, hearth: Path) -> dict:
    facts = Facts(tables)
    derived = derive_hearthstones(facts)
    shipped_h = read_hearthstones(hearth)
    candidates, flags = hearth_findings(facts, derived, shipped_h)
    return {
        "client": flavor, "product": FLAVORS[flavor]["product"], "build": build, "date": date,
        "tool": "tools/seeds/seeds.py derive",
        "shipped": {"hearthstones": len(shipped_h)},
        "derived": {"hearthstones": [{"id": s, "name": facts.spell_names.get(s, ""), "rules": derived[s]}
                                     for s in sorted(derived)]},
        "candidates": candidates, "flags": flags,
    }


# ---------------------------------------------------------------------------
# Bundles
# ---------------------------------------------------------------------------

def bundles(root: Path, flavor: str) -> list:
    """Every bundle of `flavor` under `root` that holds a candidates.json, oldest first."""
    return sorted(p for p in root.glob("*-" + flavor) if (p / "candidates.json").exists())


def bundle_build(bundle: Path) -> str:
    return json.loads((bundle / "candidates.json").read_text(encoding="utf-8"))["build"]


def status_line(live: str, found: list) -> str:
    """`CURRENT <build> (<bundle>)`, or `NEW <build> ...`; the first word is what the command reads."""
    if not found:
        return "NEW %s (no bundle yet)" % live
    built = bundle_build(found[-1])
    if built == live:
        return "CURRENT %s (%s)" % (live, found[-1].name)
    return "NEW %s (last ruled %s, %s)" % (live, built, found[-1].name)


def sources_md(flavor: str, build: str, date: str, replay: bool) -> str:
    info = FLAVORS[flavor]
    lines = ["# Sources — seed validation, %s (%s)" % (date, flavor), "",
             "Generated by `tools/seeds/seeds.py derive`. Frozen: this directory is never edited after",
             "the run, apart from the hand-written `ANALYSIS.md`.", "",
             "| Field | Value |", "| --- | --- |",
             "| Client | `%s` (%s, wago product `%s`) |" % (flavor, info["title"], info["product"]),
             "| Build | `%s` |" % build,
             "| Fetched | %s%s |" % (date, " (replayed from raw/)" if replay else ""),
             "| Builds API | <%s> |" % BUILDS_URL, "", "## Tables", "",
             "| Table | Why | URL |", "| --- | --- | --- |"]
    lines += ["| `%s` | %s | <%s> |" % (t, why, CSV_URL.format(table=t, build=build)) for t, why in TABLES]
    lines += ["", "The gzipped exports are in `raw/`. Re-derive offline with `--replay`; a new run needs",
              "network access to wago.tools.", ""]
    return "\n".join(lines)


def diff_md(doc: dict) -> str:
    cands = doc["candidates"]
    lines = ["# Diff — derived against shipped, %s (build %s)" % (doc["date"], doc["build"]), "",
             "Generated by `tools/seeds/seeds.py derive`.", "",
             "| List | Shipped | Derived | Derived, not shipped | Flags |", "| --- | --- | --- | --- | --- |",
             "| `hearthstones` | %d | %d | %d | %d |" % (
                 doc["shipped"]["hearthstones"], len(doc["derived"]["hearthstones"]), len(cands),
                 len(doc["flags"])), ""]
    lines += ["## Derived, not shipped", ""] + (["- `%d` %s" % (c["id"], c["name"] or "(no name)") for c in cands]
                                                 or ["None."])
    lines += ["", "## Shipped, flagged", ""] + (["- `%s` %s (file: %s)" % (f["key"], f["name"] or "(no row)", f["comment"])
                                                  for f in doc["flags"]] or ["None."])
    return "\n".join(lines + [""])


def load_doc(bundle: Path) -> dict:
    path = bundle / "candidates.json"
    if not path.exists():
        raise SystemExit("%s has no candidates.json: run seeds.py derive first." % bundle)
    return json.loads(path.read_text(encoding="utf-8"))


def all_keys(doc: dict) -> list:
    return [c["key"] for c in doc["candidates"]] + [f["key"] for f in doc["flags"]]


def unruled_keys(doc: dict, rulings: dict) -> list:
    return [key for key in all_keys(doc) if key not in rulings]


# ---------------------------------------------------------------------------
# Rulings (data, keyed by list and id, never by build)
# ---------------------------------------------------------------------------

def load_rulings(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def save_rulings(path: Path, rulings: dict) -> None:
    write_repo_text(path, json.dumps(rulings, indent=2, sort_keys=True, ensure_ascii=False) + "\n")


def read_tsv(path: Path) -> list:
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 3:
            raise SystemExit("%s: a ruling line is key<TAB>ruling<TAB>reason; got %r" % (path, line))
        out.append(tuple(p.strip() for p in parts))
    return out


def set_ruling(rulings: dict, key: str, ruling: str, reason: str) -> None:
    """Record one ruling; a malformed key, ruling or reason is a SystemExit naming it."""
    match = KEY.match(key)
    if not match or match.group("list") not in LISTS:
        raise SystemExit("%r is not <list>:<id> or shipped:<kind>:<list>:<id>." % key)
    kind, lst = match.group("kind"), match.group("list")
    if kind and kind not in FLAG_KINDS[lst]:
        raise SystemExit("%r: %s has no flag kind %r." % (key, lst, kind))
    allowed = FLAG_RULINGS if kind else CANDIDATE_RULINGS
    if ruling not in allowed:
        raise SystemExit("the ruling for %s must be %s; got %r." % (key, " or ".join(allowed), ruling))
    reason = (reason or "").strip()
    if not reason or "\n" in reason:
        raise SystemExit("the reason for %s must be one non-empty line." % key)
    rulings[key] = {"ruling": ruling, "reason": reason}


# ---------------------------------------------------------------------------
# Apply
# ---------------------------------------------------------------------------

def hearth_line(spell: int, name: str) -> str:
    return "    " + (str(spell) + ",").ljust(10) + "-- " + name


def apply_hearthstones(path: Path, inserts: list, removals: set) -> list:
    """Insert accepted ids in ascending order after rule 3's fixed rows, remove ruled ids; returns
    the change log. Keeps the file's own newline and every other byte."""
    lines, newline = split_lines(path.read_bytes().decode("utf-8"))
    start = next(i for i, line in enumerate(lines) if HEARTH_TABLE_OPEN.match(line))
    end = next(i for i in range(start + 1, len(lines)) if lines[i].strip() == "}")
    changes, body = [], []
    for line in lines[start + 1:end]:
        spell = int(HEARTH_ROW.match(line).group(1))
        if spell in removals:
            changes.append("hearthstones: -%d" % spell)
            continue
        body.append((spell, line))
    present = {spell for spell, _line in body}
    for spell, name in sorted(inserts):
        if spell in present:
            continue
        at = len(body)
        for i, (other, _line) in enumerate(body):
            if other not in FIXED and other > spell:
                at = i
                break
        body.insert(at, (spell, hearth_line(spell, name)))
        present.add(spell)
        changes.append("hearthstones: +%d %s" % (spell, name))
    if changes:
        out = lines[:start + 1] + [line for _s, line in body] + lines[end:]
        path.write_bytes(newline.join(out).encode("utf-8"))
    return changes


def apply_doc(doc: dict, rulings: dict, hearth: Path) -> list:
    unruled = unruled_keys(doc, rulings)
    if unruled:
        raise SystemExit("apply refused: %d key(s) unruled (seeds.py check lists them)." % len(unruled))
    inserts = [(c["id"], c["name"]) for c in doc["candidates"] if rulings[c["key"]]["ruling"] == "accept"]
    removals = {f["id"] for f in doc["flags"] if rulings[f["key"]]["ruling"] == "remove"}
    return apply_hearthstones(hearth, inserts, removals)


# ---------------------------------------------------------------------------
# RULINGS.md
# ---------------------------------------------------------------------------

def _cell(text) -> str:
    return (text or "").replace("|", "\\|")


def rulings_md(doc: dict, rulings: dict, date: str) -> str:
    tally = {}
    for key in all_keys(doc):
        r = rulings.get(key, {}).get("ruling", "unruled")
        tally[r] = tally.get(r, 0) + 1
    unruled = unruled_keys(doc, rulings)
    lines = ["# Rulings — seed validation, %s (%s, build %s)" % (doc["date"], doc["client"], doc["build"]), "",
             "Generated by `tools/seeds/seeds.py report` on %s from this bundle's `candidates.json` and" % date,
             "`tools/seeds/rulings.json`. Do not edit by hand.", "",
             "Shipped: %d hearthstones. %d candidates, %d flags: %s." % (
                 doc["shipped"]["hearthstones"], len(doc["candidates"]),
                 len(doc["flags"]), ", ".join("%d %s" % (n, r) for r, n in sorted(tally.items())) or "none"), ""]
    if unruled:
        lines += ["## Unruled — %d" % len(unruled), ""] + ["- `%s`" % k for k in unruled] + [""]
    lines += ["## Candidates — hearthstones", ""]
    if doc["candidates"]:
        lines += ["| Id | Name | Notes | Ruling | Reason |", "| --- | --- | --- | --- | --- |"]
        for c in doc["candidates"]:
            r = rulings.get(c["key"], {})
            lines.append("| `%d` | %s | %s | %s | %s |" % (c["id"], _cell(c["name"]), _cell("; ".join(c["notes"])),
                                                           r.get("ruling", "**unruled**"), _cell(r.get("reason"))))
    else:
        lines.append("None: the rules derive nothing the list does not ship.")
    lines += ["", "## Shipped-id flags — %d" % len(doc["flags"]), ""]
    if doc["flags"]:
        lines += ["| Kind | List | Id | Build name | File name | Ruling | Reason |",
                  "| --- | --- | --- | --- | --- | --- | --- |"]
        for f in doc["flags"]:
            r = rulings.get(f["key"], {})
            lines.append("| %s | %s | `%d` | %s | %s | %s | %s |" % (
                f["kind"], f["list"], f["id"], _cell(f["name"]) or "(no row)", _cell(f["comment"]),
                r.get("ruling", "**unruled**"), _cell(r.get("reason"))))
    else:
        lines.append("None.")
    return "\n".join(lines + [""])


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def _date(value: str) -> str:
    if not DATE_RE.match(value):
        raise argparse.ArgumentTypeError("a date is YYYY-MM-DD; got %r" % value)
    return value


def cmd_status(args) -> int:
    print(status_line(live_build(FLAVORS[args.flavor]["product"]), bundles(args.root, args.flavor)))
    return 0


def cmd_derive(args) -> int:
    if not args.bundle.name.endswith("-" + args.flavor):
        raise SystemExit("--bundle %s: a %s bundle is named <date>-%s." % (args.bundle, args.flavor, args.flavor))
    if args.replay:
        build = args.build or (bundle_build(args.bundle) if (args.bundle / "candidates.json").exists() else None)
        if not build:
            raise SystemExit("--replay %s has no candidates.json to take its build from; pass --build." % args.bundle)
    else:
        build = args.build or live_build(FLAVORS[args.flavor]["product"])
    log("Build %s (%s)" % (build, args.flavor))
    tables = freeze_tables(args.bundle, build, args.cache_dir, args.replay)
    doc = derive_doc(tables, args.flavor, build, args.date, args.hearthstones)
    write_json(args.bundle / "candidates.json", doc)
    write_repo_text(args.bundle / "SOURCES.md", sources_md(args.flavor, build, args.date, args.replay))
    write_repo_text(args.bundle / "DIFF.md", diff_md(doc))
    unruled = unruled_keys(doc, load_rulings(args.rulings))
    log("hearthstones: %d shipped, %d derived, %d candidates" % (
        doc["shipped"]["hearthstones"], len(doc["derived"]["hearthstones"]), len(doc["candidates"])))
    log("%d candidates, %d flags, %d unruled" % (len(doc["candidates"]), len(doc["flags"]), len(unruled)))
    return 0


def cmd_rule(args) -> int:
    todo = [(key, args.ruling, args.reason) for key in (args.key or ())]
    if args.tsv:
        todo += read_tsv(args.tsv)
    if not todo:
        raise SystemExit("rule needs --key (with --ruling and --reason) or --tsv.")
    known = set(all_keys(load_doc(args.bundle))) if args.bundle else None
    rulings = load_rulings(args.rulings)
    for key, ruling, reason in todo:
        if known is not None and key not in known:
            raise SystemExit("%s is not a candidate or flag in %s/candidates.json." % (key, args.bundle))
        set_ruling(rulings, key, ruling, reason)
    save_rulings(args.rulings, rulings)
    log("Recorded %d ruling(s) in %s" % (len(todo), args.rulings))
    return 0


def cmd_check(args) -> int:
    doc = load_doc(args.bundle)
    unruled = unruled_keys(doc, load_rulings(args.rulings))
    if not unruled:
        print("OK: every candidate and flag in %s is ruled." % args.bundle.name)
        return 0
    rows = {c["key"]: c for c in doc["candidates"]}
    rows.update({f["key"]: f for f in doc["flags"]})
    print("%d unruled:" % len(unruled))
    for key in unruled:
        row = rows[key]
        print("  %s  %s (file: %s)" % (key, row["name"] or "(no row)", row.get("comment") or "-"))
    return 1


def cmd_report(args) -> int:
    write_repo_text(args.bundle / "RULINGS.md", rulings_md(load_doc(args.bundle), load_rulings(args.rulings), args.date))
    log("Wrote %s" % (args.bundle / "RULINGS.md"))
    return 0


def cmd_apply(args) -> int:
    changes = apply_doc(load_doc(args.bundle), load_rulings(args.rulings), args.hearthstones)
    for line in changes:
        log("  " + line)
    log("%d change(s)" % len(changes))
    return 0


def parse_args(argv):
    parser = argparse.ArgumentParser(description="Re-validate DPS Race's seed lists against a wago.tools build.",
                                     epilog="The contract: docs/validate-seeds.md.")
    parser.add_argument("--rulings", type=Path, default=RULINGS_PATH)
    parser.add_argument("--hearthstones", type=Path, default=HEARTH_FILE)
    parser.add_argument("--cache-dir", type=Path, default=CACHE_DIR)
    sub = parser.add_subparsers(dest="command", required=True)
    status = sub.add_parser("status", help="is there a live build newer than the newest bundle?")
    status.add_argument("--flavor", choices=sorted(FLAVORS), default="retail")
    status.add_argument("--root", type=Path, default=RESEARCH)
    derive = sub.add_parser("derive", help="freeze one build's tables; candidates and flags into candidates.json")
    derive.add_argument("--flavor", choices=sorted(FLAVORS), required=True)
    derive.add_argument("--bundle", type=Path, required=True)
    derive.add_argument("--date", type=_date, required=True)
    derive.add_argument("--build", default=None, help="pin this build (default: the flavor's live build)")
    derive.add_argument("--replay", action="store_true", help="read only the bundle's raw/, no network")
    rule = sub.add_parser("rule", help="record rulings (the only writer of the rulings file)")
    rule.add_argument("--key", action="append")
    rule.add_argument("--ruling")
    rule.add_argument("--reason")
    rule.add_argument("--tsv", type=Path, help="key<TAB>ruling<TAB>reason lines")
    rule.add_argument("--bundle", type=Path, help="refuse keys this bundle's candidates.json lacks")
    for name, helptext in (("check", "exit 1 while anything is unruled"),
                           ("report", "write the bundle's RULINGS.md"),
                           ("apply", "write accepted ids and ruled removals into the seed file")):
        cmd = sub.add_parser(name, help=helptext)
        cmd.add_argument("--bundle", type=Path, required=True)
        if name != "check":
            cmd.add_argument("--date", type=_date, required=True)
    return parser.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    return {"status": cmd_status, "derive": cmd_derive, "rule": cmd_rule, "check": cmd_check,
            "report": cmd_report, "apply": cmd_apply}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
