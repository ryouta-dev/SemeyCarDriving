"""Asset-ledger coverage: every shipped binary must be listed with a status."""
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("check_assets", ROOT / "tools/check_assets.py")
check_assets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check_assets)


class AssetLedgerTests(unittest.TestCase):
    def test_every_shipped_asset_is_listed(self):
        entries = check_assets.ledger_entries()
        missing = [str(p.relative_to(ROOT)) for p in check_assets.shipped_assets() if p.name not in entries]
        self.assertEqual(missing, [], f"missing from docs/ASSET_LICENSES.md: {missing}")

    def test_statuses_are_valid(self):
        entries = check_assets.ledger_entries()
        self.assertTrue(entries)
        self.assertTrue(set(entries.values()) <= {"GREEN", "YELLOW", "RED"})

    def test_known_procedural_asset_is_green(self):
        entries = check_assets.ledger_entries()
        self.assertEqual(entries.get("rain_generated.wav"), "GREEN")

    def test_known_red_assets_are_marked(self):
        entries = check_assets.ledger_entries()
        self.assertEqual(entries.get("lada_vaz_2110_rigged.glb"), "RED")
        self.assertEqual(entries.get("priora_rigged.glb"), "RED")


if __name__ == "__main__":
    unittest.main()
