"""Offline regression checks. These are NOT a replacement for Godot/playtesting."""
import importlib.util
import json
import re
import struct
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("baker", ROOT / "tools/bake_osm_tiles.py")
baker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(baker)

def read_glb(path):
    data = path.read_bytes()
    magic, version, size = struct.unpack_from("<4sII", data)
    assert magic == b"glTF" and version == 2 and size == len(data)
    count, kind = struct.unpack_from("<II", data, 12)
    assert kind == 0x4E4F534A and count % 4 == 0
    document = json.loads(data[20:20+count])
    binary_size, binary_kind = struct.unpack_from("<II", data, 20+count)
    assert binary_kind == 0x004E4942 and binary_size % 4 == 0
    assert 28 + count + binary_size == size
    return document, binary_size

def stripped_code(text):
    # Lexical check only, not a GDScript parser/type checker.
    out=[]; i=0
    while i < len(text):
        if text[i] == '#':
            j=text.find('\n',i); i=len(text) if j < 0 else j
        elif text[i] in ['"', "'"]:
            delimiter = text[i] * (3 if text[i:i+3] == text[i]*3 else 1)
            i += len(delimiter)
            while i < len(text):
                if text[i] == '\\': i += 2
                elif text.startswith(delimiter, i): i += len(delimiter); break
                else: i += 1
            else: raise AssertionError('unterminated string')
            out.append('STRING')
        else:
            out.append(text[i]); i+=1
    return ''.join(out)

class TileTests(unittest.TestCase):
    def assembler(self):
        return baker.TileAssembler((8.00,49.00,8.02,49.02),200.0)
    def test_projection_origin(self):
        self.assertEqual(baker.latlon_to_local(49.01,8.01,49.01,8.01),(0.0,-0.0))
    def test_negative_floor(self):
        self.assertEqual(baker.pos_to_tile(-0.1,-200.1,200.0),(-1,-2))
    def test_long_segment_middle_tile(self):
        a=self.assembler();a.add_node(1,49.01,8.001,{});a.add_node(2,49.01,8.019,{})
        a.add_way(10,[1,2],{'highway':'residential'})
        self.assertIn(10,a.tile_ways[(0,0)])
    def test_segment_crosses_bbox_without_inside_nodes(self):
        a=self.assembler();a.add_node(1,49.01,7.999,{});a.add_node(2,49.01,8.021,{})
        a.add_way(10,[1,2],{'highway':'residential'})
        self.assertIn(10,a.tile_ways[(0,0)])
    def test_closed_polygon_interior(self):
        a=self.assembler()
        for n,lat,lon in [(1,49.001,8.001),(2,49.001,8.019),(3,49.019,8.019),(4,49.019,8.001)]:
            a.add_node(n,lat,lon,{})
        a.add_way(10,[1,2,3,4,1],{'landuse':'grass'})
        self.assertIn(10,a.tile_ways[(0,0)])
    def test_relation_inherits_segment_coverage(self):
        a=self.assembler();a.add_node(1,49.01,8.001,{});a.add_node(2,49.01,8.019,{})
        a.add_way(10,[1,2],{'highway':'residential'})
        a.add_relation(20,[{'type':'way','ref':10,'role':'outer'}],{'type':'multipolygon'})
        self.assertIn(20,a.tile_rels[(0,0)])
    def test_tile_reference_closure(self):
        a=self.assembler();a.add_node(1,49.01,8.001,{});a.add_node(2,49.01,8.019,{})
        a.add_way(10,[1,2],{'highway':'residential'})
        nodes,ways,relations=a.closure_for_tile((0,0))
        self.assertEqual(nodes,{1,2});self.assertEqual(ways,{10})
    def test_offline_write_manifest(self):
        a=self.assembler();a.add_node(1,49.01,8.01,{'highway':'traffic_signals'});a.finalize_standalone_nodes()
        with tempfile.TemporaryDirectory() as folder:
            manifest=a.write_tiles(Path(folder))
            self.assertEqual(manifest['version'],1)
            for entry in manifest['tiles']:
                ET.parse(Path(folder)/entry['file'])
    def test_tagged_outside_node_not_standalone(self):
        a=self.assembler();a.add_node(1,49.03,8.03,{'natural':'tree'});a.finalize_standalone_nodes()
        self.assertEqual(a.tile_keys(),[])
    def test_active_osm_references(self):
        root=ET.parse(ROOT/'data/triumph_600m.osm').getroot()
        ids={n.attrib['id'] for n in root.findall('node')}
        self.assertTrue(ids)
        for way in root.findall('way'):
            for node in way.findall('nd'): self.assertIn(node.attrib['ref'],ids)

class ProjectTests(unittest.TestCase):
    def test_no_credentials_or_editor_cache(self):
        forbidden={'.env','export_credentials.cfg'}
        for p in ROOT.rglob('*'):
            # `.godot` is a local editor cache: it may exist on a developer
            # machine (and legitimately does), it must just never be committed.
            if '.godot' in p.relative_to(ROOT).parts:
                continue
            self.assertFalse(any(part in forbidden for part in p.relative_to(ROOT).parts),str(p))
            self.assertNotIn(p.suffix, ['.keystore','.p12','.pem'])
        gitignore=(ROOT/'.gitignore').read_text(encoding='utf-8')
        self.assertIn('.godot/',gitignore)
        self.assertIn('.env',gitignore)
    def test_no_active_blender_dependencies(self):
        for p in list((ROOT/'scripts').rglob('*.gd'))+list((ROOT/'scenes').rglob('*.tscn')):
            self.assertFalse(re.search(r'res://[^"\s]+\.blend',p.read_text(encoding="utf-8")),str(p))
        self.assertTrue((ROOT/'source_assets/.gdignore').exists())
    def test_portable_glb_integrity(self):
        paths=list((ROOT/'scenes/models').glob('*.glb'))
        self.assertGreaterEqual(len(paths),12)
        for p in paths:
            document,size=read_glb(p)
            self.assertLessEqual(document['buffers'][0]['byteLength'],size)
            self.assertNotIn('uri',document['buffers'][0])
            for view in document.get('bufferViews',[]):
                self.assertLessEqual(view.get('byteOffset',0)+view['byteLength'],size,p.name)
    def test_rigged_cars_have_body_and_four_wheels(self):
        for name in ['lada_vaz_2110_rigged.glb','priora_rigged.glb']:
            document,size=read_glb(ROOT/name)
            names={n.get('name') for n in document['nodes']}
            self.assertTrue({'Body','Wheel_FL','Wheel_FR','Wheel_RL','Wheel_RR'} <= names)
    def test_resource_references(self):
        optional={'res://data/map.dem.png','res://data/map.dem.json','res://data/tiles'}
        for p in ROOT.rglob('*'):
            if 'source_assets' in p.parts or '.godot' in p.parts or p.suffix not in ['.gd','.tscn','.tres','.godot']:continue
            for ref in re.findall(r'res://[^\s"\'<>\)]+',p.read_text(encoding="utf-8")):
                if any(c in ref for c in ['*','%','`']):continue
                ref=ref.rstrip('.,;')
                if ref in optional:continue
                self.assertTrue((ROOT/ref[6:]).exists(),f'{p}: {ref}')
    def test_gdscript_lexical_delimiters(self):
        closing={')':'(',']':'[','}':'{'}
        for p in list((ROOT/'scripts').rglob('*.gd'))+list((ROOT/'addons').rglob('*.gd'))+list((ROOT/'tests').glob('*.gd')):
            stack=[]
            for c in stripped_code(p.read_text(encoding="utf-8")):
                if c in '([{':stack.append(c)
                elif c in ')]}':
                    self.assertTrue(stack,f'{p}: extra {c}')
                    self.assertEqual(stack.pop(),closing[c],str(p))
            self.assertEqual(stack,[],str(p))
    def test_no_duplicate_global_classes(self):
        seen={}
        for folder in ['scripts','addons']:
            for p in (ROOT/folder).rglob('*.gd'):
                for name in re.findall(r'^class_name\s+(\w+)',p.read_text(encoding="utf-8"),re.M):
                    self.assertNotIn(name,seen,f'{name}: {p} and {seen.get(name)}');seen[name]=p
    def test_tuning_idempotence_contract(self):
        s=(ROOT/'scripts/tuning/vehicle_tuning_applicator.gd').read_text(encoding="utf-8")
        self.assertNotIn('spring_rate *=',s)
        self.assertIn('tuning_physics_signature',s)
        v=(ROOT/'addons/gevp/scripts/vehicle.gd').read_text(encoding="utf-8")
        recalc=v[v.index('func recalculate_physics'):v.index('func _physics_process')]
        self.assertIn('_rebuild_drivetrain()',recalc)
        self.assertIn('_refresh_body_inertia()',recalc)
    def test_force_positions_relative_to_body(self):
        w=(ROOT/'addons/gevp/scripts/wheel.gd').read_text(encoding="utf-8")
        self.assertIn('to_global(Vector3.FORWARD * tire_radius) - vehicle.global_position',w)
        self.assertIn('to_global(Vector3.BACK * tire_radius) - vehicle.global_position',w)
    def test_profile_transaction_and_section_writes(self):
        s=(ROOT/'scripts/profile_manager.gd').read_text(encoding="utf-8")
        for symbol in ['BACKUP_PATH','TEMP_PATH','validate_profile','save_sections','file.flush()','DirAccess.rename_absolute']:
            self.assertIn(symbol,s)
        garage=(ROOT/'scripts/garage_controller.gd').read_text(encoding="utf-8")
        self.assertNotIn('save_profile(_current_profile)',garage)
    def test_mobile_lifecycle_contract(self):
        for name in ['touch_button.gd','virtual_steering_wheel.gd','mobile_controls.gd']:
            s=(ROOT/'scripts/ui'/name).read_text(encoding="utf-8")
            self.assertIn('NOTIFICATION_APPLICATION_PAUSED',s)
            self.assertIn('reset_input',s)
    def test_export_includes_osm_and_legal_notices(self):
        s=(ROOT/'export_presets.cfg').read_text(encoding="utf-8")
        self.assertIn('data/*.osm',s)
        self.assertIn('THIRD_PARTY_NOTICES.txt',s)
        self.assertNotIn('ABCDE12345',s)
    def test_no_masked_ci_import_errors(self):
        s=(ROOT/'.github/workflows/export.yml').read_text(encoding="utf-8")
        self.assertNotIn('|| true',s)
        self.assertIn('runtime_tests.gd',s)
        self.assertIn('pull_request:',s)
        self.assertNotIn('CODE_SIGNING_ALLOWED=NO',s)

if __name__ == '__main__':
    unittest.main()
