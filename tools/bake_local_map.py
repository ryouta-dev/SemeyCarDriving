#!/usr/bin/env python3
"""Bake the supplied XML map offline; no network/osmium dependency required."""
from pathlib import Path
import xml.etree.ElementTree as ET
from bake_osm_tiles import TileAssembler
root = Path(__file__).resolve().parents[1]
xml = ET.parse(root / "data/triumph_600m.osm").getroot()
b = xml.find("bounds").attrib
bounds = tuple(float(b[key]) for key in ["minlon", "minlat", "maxlon", "maxlat"])
a = TileAssembler(bounds, 200.0)
def tags(node):
    return {t.attrib["k"]: t.attrib["v"] for t in node.findall("tag")}
for node in xml.findall("node"):
    a.add_node(int(node.attrib["id"]), float(node.attrib["lat"]), float(node.attrib["lon"]), tags(node))
for way in xml.findall("way"):
    a.add_way(int(way.attrib["id"]), [int(n.attrib["ref"]) for n in way.findall("nd")], tags(way))
for relation in xml.findall("relation"):
    members = [{"type": n.attrib["type"], "ref": int(n.attrib["ref"]), "role": n.attrib.get("role", "")} for n in relation.findall("member")]
    a.add_relation(int(relation.attrib["id"]), members, tags(relation))
a.finalize_standalone_nodes()
manifest = a.write_tiles(root / "data/tiles")
print("Baked", len(manifest["tiles"]), "tiles. Remove data/tiles to use the whole-map fallback.")
