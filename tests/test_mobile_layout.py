"""Offline layout/source-contract checks, NOT Godot runtime or a device test."""
from pathlib import Path
import re
import unittest
ROOT=Path(__file__).resolve().parents[1]
SIZES=[(640,360),(800,480),(1024,768),(1280,720),(1280,800),(1920,1080),(2340,1080),(2400,1080),(2532,1170),(2048,1536),(2560,1600),(390,844)]
def clamp(value,low,high): return max(low,min(value,high))
def layout(width,height,scale=1.0,offset=20.0,insets=(0,0,0,0)):
    left,top,right,bottom=insets; w=width-left-right;h=height-top-bottom
    u=max(0.1,min(w/1280,h/720)); margin=16*u
    s=min(u*clamp(scale,.7,1.5),w*.32/340,h*.46/312)
    sw,sh=264*s,312*s;pw,ph=340*s,288*s
    lx=left+clamp(offset*u,margin,max(margin,w*.43-sw))
    rx=clamp(left+w-offset*u-pw,left+w*.57,left+w-margin-pw)
    ly=clamp(top+h-offset*u-sh,top+h*.42,top+h-margin-sh)
    ry=clamp(top+h-offset*u-ph,top+h*.42,top+h-margin-ph)
    rects={'steer':(lx,ly,sw,sh),'pedals':(rx,ry,pw,ph),'camera':(left+w-256*u,top+margin,128*u,96*u),'menu':(left+w-116*u,top+margin,100*u,96*u),'minimap':(left+margin,top+margin,148*u,148*u)}
    return (left,top,w,h),rects,u,s
class MobileTests(unittest.TestCase):
    def setUp(self): self.mobile=(ROOT/'scripts/ui/mobile_controls.gd').read_text(encoding="utf-8")
    def test_rectangle_math_grid(self):
        # Mirror the GDScript equations; engine execution remains a separate test.
        for w,h in SIZES:
            for scale in [.7,1.0,1.5]:
                for offset in [20,700]:
                    for insets in [(0,0,0,0),(30,0,25,18)]:
                        safe,rects,u,s=layout(w,h,scale,offset,insets)
                        for name,(x,y,rw,rh) in rects.items():
                            self.assertGreaterEqual(x+1e-6,safe[0],(w,h,name))
                            self.assertGreaterEqual(y+1e-6,safe[1],(w,h,name))
                            self.assertLessEqual(x+rw,safe[0]+safe[2]+1e-6,(w,h,name))
                            self.assertLessEqual(y+rh,safe[1]+safe[3]+1e-6,(w,h,name))
    def test_thumb_zones_do_not_overlap(self):
        for w,h in SIZES:
            for size in [.7,1.5]:
                safe,rects,u,s=layout(w,h,size,700)
                left=rects['steer'];right=rects['pedals']
                self.assertLess(left[0]+left[2],right[0])
                self.assertLessEqual(left[0]+left[2],safe[0]+safe[2]*.43+1e-6)
                self.assertGreaterEqual(right[0],safe[0]+safe[2]*.57-1e-6)
    def test_gauge_fits_safe_area(self):
        for w,h in SIZES:
            safe,rects,u,s=layout(w,h,insets=(30,0,25,18))
            cx=safe[0]+safe[2]*.5;cy=safe[1]+safe[3]-80*u;radius=65*u
            self.assertGreaterEqual(cy-radius,safe[1]);self.assertLessEqual(cy+radius,safe[1]+safe[3])
            self.assertGreater(cx-radius,rects['steer'][0]+rects['steer'][2]);self.assertLess(cx+radius,rects['pedals'][0])
    def test_child_controls_fit_clusters(self):
        for x,y,w,h in [(0,64,112,112),(136,64,112,112),(24,0,216,216),(64,222,136,88)]:
            self.assertLessEqual(x+w,264);self.assertLessEqual(y+h,312)
        for x,y,w,h in [(224,104,100,164),(112,120,98,148),(0,188,94,84),(0,92,94,88),(112,8,98,88),(224,8,100,88)]:
            self.assertLessEqual(x+w,340);self.assertLessEqual(y+h,288)
    def test_layout_constants_match_reference(self):
        source=(ROOT/'scripts/ui/mobile_layout.gd').read_text(encoding="utf-8")
        for snippet in ['Vector2(264, 312)','Vector2(340, 288)','safe.size.x * 0.32','safe.size.y * 0.46','safe.size.x * 0.43','safe.size.x * 0.57','256.0 * unit','116.0 * unit']:
            self.assertIn(snippet,source)
    def test_camera_has_touch_action(self):
        self.assertIn('"CameraButton", "КАМЕРА"',self.mobile)
        self.assertIn('camera_btn.button_down.connect(_cycle_camera)',self.mobile)
        self.assertIn('camera.cycle_camera_mode()',self.mobile)
        self.assertIn('camera.snap_to_target()',self.mobile)
    def test_menu_and_editor_pause_input(self):
        self.assertIn('process_mode = Node.PROCESS_MODE_ALWAYS',self.mobile)
        self.assertIn('return is_editing_hud or _menu_open',self.mobile)
        self.assertIn('_owns_pause',self.mobile)
        self.assertIn('mobile_controls.is_driving_blocked()', (ROOT/'scripts/semey_player_controller.gd').read_text(encoding="utf-8"))
    def test_display_panel_has_no_double_center_anchor(self):
        source=(ROOT/'scripts/semey_session.gd').read_text(encoding="utf-8")
        self.assertNotIn('PRESET_CENTER_TOP',source)
        self.assertNotIn('get_visible_rect().size.x * 0.5 - 300',source)
        self.assertIn('MobileLayoutUtil.place(_panel',source)
        self.assertIn('clip_text = true',source)
    def test_menu_uses_one_scroll_content(self):
        self.assertEqual(self.mobile.count('_menu_scroll.add_child('),1)
        self.assertIn('_menu_panel.add_child(_challenge_rows)',self.mobile)
    def test_minimap_resolves_before_ready(self):
        source=(ROOT/'scripts/semey_world_manager.gd').read_text(encoding="utf-8")
        self.assertLess(source.index('_minimap.car_node_path = vehicle.get_path()'),source.index('_map_root.add_child(_minimap)'))
    def test_world_bindings_and_profile_options(self):
        world=(ROOT/'scripts/semey_world_manager.gd').read_text(encoding="utf-8")
        for binding in ['respawn_requested.connect(respawn)','challenge_requested.connect(_session.start_challenge)','minimap_toggled.connect(_set_minimap_visible)']:
            self.assertIn(binding,world)
        profile=(ROOT/'scripts/profile_manager.gd').read_text(encoding="utf-8")
        self.assertIn('"minimap": true',profile);self.assertIn('"muted": false',profile)
    def test_phone_export_configuration(self):
        export=(ROOT/'export_presets.cfg').read_text(encoding="utf-8")
        self.assertIn('architectures/arm64-v8a=true',export)
        self.assertIn('application/export_project_only=true',export)
        self.assertIn('SemeyCarDriving-Xcode.zip',export)
        for item in ['permissions/internet=false','permissions/record_audio=false','orientation/landscape_left=true','orientation/landscape_right=true']:
            self.assertIn(item,export)

class ParserRegressionTests(unittest.TestCase):
    def test_editor_handler_has_no_match_lambda(self):
        source=(ROOT/'scripts/ui/mobile_controls.gd').read_text(encoding="utf-8")
        self.assertIn('button.pressed.connect(_on_editor_action.bind(action))',source)
        self.assertIn('func _on_editor_action(action: String) -> void:',source)
        self.assertNotIn('"save": exit_hud_editor(true))',source)
    def test_layout_consumers_preload_dependency(self):
        for path in ROOT.rglob('*.gd'):
            source=path.read_text(encoding="utf-8")
            if 'MobileLayoutUtil.' in source:
                self.assertIn('const MobileLayoutUtil = preload("res://scripts/ui/mobile_layout.gd")',source,str(path))

class HeaderRegressionTests(unittest.TestCase):
    def test_global_class_precedes_body_statements(self):
        import re
        for path in ROOT.rglob('*.gd'):
            lines=path.read_text(encoding="utf-8").splitlines()
            declarations=[i for i,line in enumerate(lines) if re.match(r'^class_name\s+',line)]
            if not declarations:continue
            class_line=declarations[0]
            body=[i for i,line in enumerate(lines) if re.match(r'^(const |var |signal |func |@export)',line)]
            if body:self.assertLess(class_line,min(body),str(path))
    def test_resource_header_uids_are_unique(self):
        import re
        owners={}
        for extension in ['*.tscn','*.tres']:
            for path in ROOT.rglob(extension):
                lines=path.read_text(encoding="utf-8").splitlines()
                if not lines:continue
                match=re.search(r'uid="(uid://[^"]+)"',lines[0])
                if not match:continue
                uid=match.group(1)
                self.assertNotIn(uid,owners,(str(path),str(owners.get(uid))))
                owners[uid]=path
