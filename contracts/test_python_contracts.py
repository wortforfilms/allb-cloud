import importlib.util
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("siddham_contracts", ROOT / "generated/python/siddham_contracts.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

class ContractTests(unittest.TestCase):
    def test_valid_fixture_uses_generated_enums(self):
        fixture = json.loads((ROOT / "contracts/fixtures/valid-runtime-execute.json").read_text())
        self.assertEqual(fixture["schemaVersion"], MODULE.SCHEMA_VERSION)
        self.assertEqual(MODULE.ProtectedAction(fixture["action"]).value, "runtime:execute")
        self.assertEqual(MODULE.AssuranceLevel(fixture["assurance"]).value, "AAL3")

    def test_invalid_action_is_rejected(self):
        fixture = json.loads((ROOT / "contracts/fixtures/invalid-unknown-action.json").read_text())
        with self.assertRaises(ValueError):
            MODULE.ProtectedAction(fixture["action"])

if __name__ == "__main__":
    unittest.main()
