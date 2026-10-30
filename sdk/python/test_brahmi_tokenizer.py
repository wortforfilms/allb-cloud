"""Checks the Python mirror against the shared akshara fixture (ADR 0002)."""

import json
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from brahmi_tokenizer import BrahmiScriptTokenizer  # noqa: E402

FIXTURE = json.loads((ROOT / "tests" / "fixtures" / "brahmi_aksharas.json").read_text(encoding="utf-8"))


class BrahmiTokenizerFixtureTest(unittest.TestCase):
    def test_matches_shared_fixture(self):
        tokenizer = BrahmiScriptTokenizer()
        for case in FIXTURE["cases"]:
            with self.subTest(case=case["name"]):
                self.assertEqual(tokenizer.tokenize(case["input"]), case["aksharas"])

    def test_encode_decode_round_trip(self):
        tokenizer = BrahmiScriptTokenizer()
        for case in FIXTURE["cases"]:
            text = case["input"]
            if all(0x11000 <= ord(ch) <= 0x1107F for ch in text):
                with self.subTest(case=case["name"]):
                    self.assertEqual(tokenizer.decode(tokenizer.encode(text)), text)


if __name__ == "__main__":
    unittest.main()
