"""Repository hygiene: no orphan UIDs, no leftovers, no dead feature code."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEAD_CLASSES = [
    "CameraShake", "CarPaint", "DialCluster", "DrivingAssists",
    "PostProcessing", "SpeedBlur", "TopDownCamera", "Screenshot",
]


class RepoTests(unittest.TestCase):
    def test_every_uid_has_a_source_file(self):
        orphans = []
        for uid in ROOT.rglob("*.uid"):
            if not uid.with_suffix("").exists():
                orphans.append(str(uid.relative_to(ROOT)))
        self.assertEqual(orphans, [], f"orphan .uid files: {orphans}")

    def test_no_workspace_leftovers(self):
        for name in ["run.json", "jobs.json", "get_jobs.ps1", "scenes/models/triumph_mall.blend1"]:
            self.assertFalse((ROOT / name).exists(), name)

    def test_dead_feature_code_is_gone(self):
        matches = []
        for pattern in ("*.gd", "*.tscn", "*.tres"):
            for path in ROOT.rglob(pattern):
                if ".godot" in path.parts or "source_assets" in path.parts:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore")
                for cls in DEAD_CLASSES:
                    if re.search(rf"\b{cls}\b", text):
                        matches.append(f"{path.relative_to(ROOT)}: {cls}")
        self.assertEqual(matches, [], matches)

    def test_gitignore_covers_local_artifacts(self):
        text = (ROOT / ".gitignore").read_text(encoding="utf-8")
        for entry in [".godot/", "*.ps1", "run.json", "jobs.json", "*.blend1"]:
            self.assertIn(entry, text)

    def test_assets_ledger_exists(self):
        ledger = ROOT / "docs/ASSET_LICENSES.md"
        self.assertTrue(ledger.exists())
        text = ledger.read_text(encoding="utf-8")
        self.assertIn("RED", text)


if __name__ == "__main__":
    unittest.main()
