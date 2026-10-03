import bpy
import mathutils
import json

def process_lada():
    print("=== PROCESSING LADA 2110 ===")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=r"c:\SemeyCarDriving v0.0.1\lada_vaz_2110.glb")

    # Rotate 180 deg around Z so it faces -Z in Godot (forward)
    rot_180_z = mathutils.Matrix.Rotation(3.141592653589793, 4, 'Z')
    for obj in bpy.context.scene.objects:
        if obj.parent is None:
            obj.matrix_world = rot_180_z @ obj.matrix_world

    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    wheel_groups = {
        "Wheel_FL": ["KAMA_E224_LF_rims_0", "KAMA_E224_LF_KAMA_0", "KAMA_E224_LF_KAMA wall_0", "KAMA_E224_LF_Disc details_0"],
        "Wheel_FR": ["KAMA_E224_RF_rims_0", "KAMA_E224_RF_KAMA_0", "KAMA_E224_RF_KAMA wall_0", "KAMA_E224_RF_Disc details_0"],
        "Wheel_RL": ["KAMA_E224_LB_rims_0", "KAMA_E224_LB_KAMA_0", "KAMA_E224_LB_KAMA wall_0", "KAMA_E224_LB_Disc details_0", "KAMA_E224_LB_Brakes 2.001_0", "KAMA_E224_LB_Brakes details.001_0"],
        "Wheel_RR": ["KAMA_E224_RB_rims_0", "KAMA_E224_RB_KAMA_0", "KAMA_E224_RB_KAMA wall_0", "KAMA_E224_RB_Disc details_0", "KAMA_E224_RB_Brakes 2.001_0", "KAMA_E224_RB_Brakes details.001_0"]
    }

    wheel_coords_godot = {}

    for w_name, member_names in wheel_groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        members = [bpy.data.objects.get(n) for n in member_names if bpy.data.objects.get(n)]
        if not members:
            continue
        
        for m in members:
            m.select_set(True)
        bpy.context.view_layer.objects.active = members[0]
        
        if len(members) > 1:
            bpy.ops.object.join()
        
        wheel_obj = bpy.context.view_layer.objects.active
        wheel_obj.name = w_name
        # Clear any parent
        bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
        
        # Origin to geometry center
        bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
        loc = wheel_obj.location.copy()
        
        # In glTF/Godot coordinates: X_godot = loc.x, Y_godot = loc.z, Z_godot = -loc.y
        wheel_coords_godot[w_name] = [loc.x, loc.z, -loc.y]
        
        # Now center the wheel mesh vertices around (0,0,0)
        wheel_obj.location = (0, 0, 0)
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

    # Group all remaining mesh objects under a parent Empty named Body
    body_parent = bpy.data.objects.new("Body", None)
    bpy.context.scene.collection.objects.link(body_parent)
    
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH' and obj.name not in wheel_groups:
            obj.parent = body_parent

    output_path = r"c:\SemeyCarDriving v0.0.1\lada_vaz_2110_rigged.glb"
    bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
    print("LADA_GODOT_COORDS:", json.dumps(wheel_coords_godot))


def process_priora():
    print("=== PROCESSING PRIORA ===")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=r"c:\SemeyCarDriving v0.0.1\priora.glb")

    trans_mat = mathutils.Matrix.Translation(mathutils.Vector((0.306, 0.0, 0.0)))
    scale_mat = mathutils.Matrix.Scale(0.468, 4)
    rot_180_z = mathutils.Matrix.Rotation(3.141592653589793, 4, 'Z')
    
    M = rot_180_z @ scale_mat @ trans_mat
    for obj in bpy.context.scene.objects:
        if obj.parent is None:
            obj.matrix_world = M @ obj.matrix_world

    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    wheel_groups = {
        "Wheel_FL": ["Object_159", "Object_160"],
        "Wheel_FR": ["Object_168", "Object_169"],
        "Wheel_RL": ["Object_162", "Object_163"],
        "Wheel_RR": ["Object_165", "Object_166"]
    }

    wheel_coords_godot = {}

    for w_name, member_names in wheel_groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        members = [bpy.data.objects.get(n) for n in member_names if bpy.data.objects.get(n)]
        if not members:
            continue
        
        for m in members:
            m.select_set(True)
        bpy.context.view_layer.objects.active = members[0]
        
        if len(members) > 1:
            bpy.ops.object.join()
        
        wheel_obj = bpy.context.view_layer.objects.active
        wheel_obj.name = w_name
        bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
        
        bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
        loc = wheel_obj.location.copy()
        
        wheel_coords_godot[w_name] = [loc.x, loc.z, -loc.y]
        
        wheel_obj.location = (0, 0, 0)
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

    body_parent = bpy.data.objects.new("Body", None)
    bpy.context.scene.collection.objects.link(body_parent)
    
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH' and obj.name not in wheel_groups:
            obj.parent = body_parent

    output_path = r"c:\SemeyCarDriving v0.0.1\priora_rigged.glb"
    bpy.ops.export_scene.gltf(filepath=output_path, export_format='GLB')
    print("PRIORA_GODOT_COORDS:", json.dumps(wheel_coords_godot))


process_lada()
process_priora()
