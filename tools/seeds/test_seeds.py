"""Tests for tools/seeds/seeds.py (docs/validate-seeds.md). No network: every case reads the tiny
CSVs in tools/seeds/fixtures/ or a temp copy of them, and a temp seed file; the last cases read the
repo's own defaults/Hearthstones.lua, tools/seeds/rulings.json and the newest bundle.

Mutation-checked (2026-11-15): with the rule-4 guard in `derive_hearthstones` broken (the
`out.pop(spell, None)` loop over EXCLUDED deleted), `test_rule_4_removes_excluded_ids` and
`test_four_rules` fail; restored, they pass.

Run: python3 -m pytest -q tools/seeds   (or: python3 -m unittest discover -s tools/seeds)
"""

from __future__ import annotations

import gzip
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import seeds  # noqa: E402

FIXTURES = HERE / "fixtures"

SEED = (
    "local _, NS = ...\r\n"
    "-- header\r\n"
    "\r\n"
    "NS.HEARTHSTONE_SPELLS = {\r\n"
    "    8690,     -- Hearthstone\r\n"
    "    222695,   -- Dalaran Hearthstone\r\n"
    "    171253,   -- Garrison Hearthstone\r\n"
    "    700001,   -- Scroll of Recall\r\n"
    "    700003,   -- Wrong Name\r\n"
    "    900001,   -- Old Toy\r\n"
    "    950000,   -- Gone\r\n"
    "}\r\n"
)


def fixture_tables(root: Path = FIXTURES) -> dict:
    return {table: root / ("%s.csv" % table) for table, _why in seeds.TABLES}


class Workspace(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.seed = self.tmp / "Hearthstones.lua"
        self.seed.write_bytes(SEED.encode("utf-8"))
        self.facts = seeds.Facts(fixture_tables())

    def tearDown(self):
        shutil.rmtree(self.tmp)


class TestRules(Workspace):
    def test_four_rules(self):
        derived = seeds.derive_hearthstones(self.facts)
        self.assertEqual(sorted(derived), [8690, 171253, 222695, 700001, 700003, 700010, 700011,
                                           700012, 1310840])

    def test_rule_1_reads_every_difficulty_and_rule_2_either_target_slot(self):
        derived = seeds.derive_hearthstones(self.facts)
        self.assertIn("rule 1: ChargeCategory 2309", derived[700003], "a DifficultyID 1 row counts")
        self.assertIn("rule 2: Effect 252, ImplicitTarget 9", derived[700010], "slot 0")
        self.assertIn("rule 2: Effect 252, ImplicitTarget 9", derived[700011], "slot 1")
        self.assertNotIn(700013, derived, "a teleport elsewhere is no hearthstone")
        self.assertNotIn(700002, derived, "another charge category is not the hearthstone's")

    def test_rule_4_removes_excluded_ids(self):
        derived = seeds.derive_hearthstones(self.facts)
        self.assertNotIn(556, derived)
        self.assertNotIn(1223998, derived)

    def test_sentinel_gate_stops_a_thin_run(self):
        self.facts.spell_names.pop(8690)
        with self.assertRaises(SystemExit) as err:
            seeds.derive_hearthstones(self.facts)
        self.assertIn("8690", str(err.exception))

    def test_item_note(self):
        self.assertEqual(self.facts.item_note(700010), "cast by toy 5000")
        self.assertEqual(self.facts.item_note(700001), "cast by item 5002")
        self.assertEqual(self.facts.item_note(700011), "triggered by 700020, which an item casts")
        self.assertEqual(self.facts.item_note(700012), "no item casts it")


class TestFindings(Workspace):
    def test_candidates_and_flags(self):
        doc = seeds.derive_doc(fixture_tables(), "retail", "1.2.3.4", "2026-01-02", self.seed)
        self.assertEqual([c["key"] for c in doc["candidates"]],
                         ["hearthstones:700010", "hearthstones:700011", "hearthstones:700012",
                          "hearthstones:1310840"])
        self.assertEqual(sorted(f["key"] for f in doc["flags"]),
                         ["shipped:renamed:hearthstones:700003", "shipped:unfit:hearthstones:900001",
                          "shipped:unnamed:hearthstones:950000"])
        self.assertEqual(doc["shipped"], {"hearthstones": 7})
        renamed = next(f for f in doc["flags"] if f["kind"] == "renamed")
        self.assertEqual((renamed["name"], renamed["comment"]), ("Heroic Hearthstone", "Wrong Name"))

    def test_replay_from_gzipped_raw_matches(self):
        bundle = self.tmp / "2026-01-02-retail"
        raw = bundle / "raw"
        raw.mkdir(parents=True)
        for table, path in fixture_tables().items():
            with path.open("rb") as src, gzip.open(raw / ("%s.csv.gz" % table), "wb") as dst:
                shutil.copyfileobj(src, dst)
        replayed = seeds.freeze_tables(bundle, "1.2.3.4", self.tmp / "cache", replay=True)
        a = seeds.derive_doc(fixture_tables(), "retail", "1.2.3.4", "2026-01-02", self.seed)
        b = seeds.derive_doc(replayed, "retail", "1.2.3.4", "2026-01-02", self.seed)
        self.assertEqual(a, b)
        (raw / "Toy.csv.gz").unlink()
        with self.assertRaises(SystemExit):
            seeds.freeze_tables(bundle, "1.2.3.4", self.tmp / "cache", replay=True)

    def test_freeze_from_cache_is_byte_stable(self):
        cache = self.tmp / "cache"
        cache.mkdir()
        for table, path in fixture_tables().items():
            shutil.copyfile(path, cache / ("%s-1.2.3.4.csv" % table))
        bundle = self.tmp / "b-retail"
        seeds.freeze_tables(bundle, "1.2.3.4", cache, replay=False)
        first = (bundle / "raw" / "SpellName.csv.gz").read_bytes()
        seeds.freeze_tables(bundle, "1.2.3.4", cache, replay=False)
        self.assertEqual(first, (bundle / "raw" / "SpellName.csv.gz").read_bytes())


class TestRulings(unittest.TestCase):
    def test_set_ruling_validates(self):
        rulings = {}
        seeds.set_ruling(rulings, "hearthstones:5", "accept", "a toy")
        seeds.set_ruling(rulings, "shipped:unnamed:hearthstones:6", "keep", "harmless")
        self.assertEqual(rulings["hearthstones:5"], {"ruling": "accept", "reason": "a toy"})
        for key, ruling, reason in (("dummies:5", "accept", "x"), ("hearthstones:5", "keep", "x"),
                                    ("shipped:unnamed:hearthstones:6", "accept", "x"),
                                    ("shipped:bogus:hearthstones:6", "keep", "x"),
                                    ("hearthstones:5", "accept", ""), ("hearthstones:5", "accept", "a\nb")):
            with self.assertRaises(SystemExit, msg=key):
                seeds.set_ruling({}, key, ruling, reason)

    def test_status_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.assertEqual(seeds.status_line("9.9", seeds.bundles(root, "retail")), "NEW 9.9 (no bundle yet)")
            b = root / "2026-01-02-retail"
            b.mkdir()
            (b / "candidates.json").write_text(json.dumps({"build": "9.8"}))
            self.assertEqual(seeds.status_line("9.8", seeds.bundles(root, "retail")),
                             "CURRENT 9.8 (2026-01-02-retail)")
            self.assertTrue(seeds.status_line("9.9", seeds.bundles(root, "retail")).startswith("NEW 9.9 (last ruled 9.8"))


class TestApply(Workspace):
    def doc(self):
        return seeds.derive_doc(fixture_tables(), "retail", "1.2.3.4", "2026-01-02", self.seed)

    def test_apply_refuses_while_unruled(self):
        with self.assertRaises(SystemExit):
            seeds.apply_doc(self.doc(), {}, self.seed)
        self.assertEqual(self.seed.read_bytes(), SEED.encode("utf-8"))

    def test_apply_inserts_in_order_removes_keeps_crlf_and_is_idempotent(self):
        doc = self.doc()
        rulings = {k: {"ruling": "reject", "reason": "x"} for k in seeds.all_keys(doc)}
        rulings["hearthstones:700010"] = {"ruling": "accept", "reason": "a toy"}
        rulings["hearthstones:700011"] = {"ruling": "accept", "reason": "an item"}
        for f in doc["flags"]:
            rulings[f["key"]] = {"ruling": "keep", "reason": "x"}
        rulings["shipped:unnamed:hearthstones:950000"] = {"ruling": "remove", "reason": "gone"}
        changes = seeds.apply_doc(doc, rulings, self.seed)
        self.assertEqual(len(changes), 3)
        text = self.seed.read_bytes().decode("utf-8")
        self.assertNotIn("\n", text.replace("\r\n", ""), "every terminator stays CRLF")
        rows = [r["id"] for r in seeds.read_hearthstones(self.seed)]
        self.assertEqual(rows, [8690, 222695, 171253, 700001, 700003, 700010, 700011, 900001])
        self.assertIn("    700010,   -- Toy Hearthstone\r\n", text)
        self.assertTrue(text.startswith("local _, NS = ...\r\n-- header\r\n"))
        before = self.seed.read_bytes()
        self.assertEqual(seeds.apply_doc(doc, rulings, self.seed), [])
        self.assertEqual(self.seed.read_bytes(), before)


class TestRepo(unittest.TestCase):
    def test_shipped_file_parses(self):
        rows = seeds.read_hearthstones(seeds.HEARTH_FILE)
        ids = [r["id"] for r in rows]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(ids[:3], [8690, 222695, 171253])

    def test_newest_bundle_is_fully_ruled(self):
        found = seeds.bundles(seeds.RESEARCH, "retail")
        if not found:
            self.skipTest("no bundle yet")
        doc = seeds.load_doc(found[-1])
        self.assertEqual(seeds.unruled_keys(doc, seeds.load_rulings(seeds.RULINGS_PATH)), [])


if __name__ == "__main__":
    unittest.main()
