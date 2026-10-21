"""Static checks for the two car-model variants (full detail / low poly).

These do NOT load the models in Godot: they verify the files exist, the low
variant is genuinely lighter and keeps the node names the tuning applicator
looks for, and that the code wires the variant to the quality preset.
"""
import json
import re
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

LOW_TRIANGLE_LIMIT = {"lada_vaz_2110_rigged_low.glb": 160000, "priora_rigged_low.glb": 60000}
REQUIRED_NODES = {"Body", "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"}


def glb_document(path):
    data = path.read_bytes()
    magic, version, size = struct.unpack_from("<4sII", data)
    assert magic == b"glTF" and version == 2 and size == len(data), path
    count, kind = struct.unpack_from("<II", data, 12)
    assert kind == 0x4E4F534A
    return json.loads(data[20:20 + count])


def triangle_count(document):
    total = 0
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            if "indices" in primitive:
                total += document["accessors"][primitive["indices"]]["count"] // 3
    return total


class QualityVariantTests(unittest.TestCase):
    def test_low_variants_exist_and_are_lighter(self):
        pairs = [
            ("lada_vaz_2110_rigged.glb", "lada_vaz_2110_rigged_low.glb"),
            ("priora_rigged.glb", "priora_rigged_low.glb"),
        ]
        for full_name, low_name in pairs:
            full = ROOT / full_name
            low = ROOT / low_name
            self.assertTrue(full.exists(), full_name)
            self.assertTrue(low.exists(), low_name)
            full_tris = triangle_count(glb_document(full))
            low_tris = triangle_count(glb_document(low))
            self.assertLess(low_tris, full_tris, low_name)
            self.assertLessEqual(low_tris, LOW_TRIANGLE_LIMIT[low_name], low_name)

    def test_low_variants_keep_required_nodes(self):
        for name in LOW_TRIANGLE_LIMIT:
            nodes = {node.get("name") for node in glb_document(ROOT / name).get("nodes", [])}
            self.assertTrue(REQUIRED_NODES <= nodes, f"{name} is missing {REQUIRED_NODES - nodes}")

    def test_definitions_point_to_existing_low_variants(self):
        for name in ["lada_vaz_2110.tres", "priora.tres"]:
            text = (ROOT / "data/vehicles" / name).read_text(encoding="utf-8")
            match = re.search(r'visual_path_low = "res://([^"]+)"', text)
            self.assertIsNotNone(match, name)
            self.assertTrue((ROOT / match.group(1)).exists(), match.group(1))

    def test_variant_selection_and_owner_reset(self):
        source = (ROOT / "scripts/tuning/vehicle_tuning_applicator.gd").read_text(encoding="utf-8")
        self.assertIn("variant_for_quality", source)
        self.assertIn('return "high" if quality == "high" else "low"', source)
        self.assertIn("visual_variant", source)
        self.assertIn("body.owner = null", source)
        self.assertIn("mesh.owner = null", source)
        self.assertIn("_attach_visual", source)

    def test_quality_preset_matrix(self):
        source = (ROOT / "scripts/quality_settings.gd").read_text(encoding="utf-8")
        self.assertIn('0.9 if preset == "balanced"', source)
        self.assertIn("MSAA_4X", source)
        self.assertIn("MSAA_DISABLED", source)


if __name__ == "__main__":
    unittest.main()
