"""Stance GLB → decimate + UV + simple armature + auto-weights + Skin/Hair/Clothing.
Run: blender --background --python tools/skin_emily_stance.py
"""
import bpy
import bmesh
from mathutils import Vector
from pathlib import Path

ROOT = Path("/workspace/skateboard-game")
SRC = ROOT / "assets/characters/emily_skater_stance.glb"
OUT = ROOT / "assets/characters/emily_skater_skinned.glb"
TARGET_FACES = 22000


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes) + list(bpy.data.armatures) + list(bpy.data.materials) + list(bpy.data.actions):
        bpy.data.batch_remove([block])


def import_glb(path: Path):
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("No mesh in %s" % path)
    # Join into one
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "EmilyBody"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return body


def decimate(obj, target_faces: int):
    me = obj.data
    faces = len(me.polygons)
    print("faces before decimate:", faces)
    if faces <= target_faces:
        return
    ratio = max(0.02, float(target_faces) / float(faces))
    mod = obj.modifiers.new(name="Decimate", type="DECIMATE")
    mod.ratio = ratio
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    print("faces after decimate:", len(obj.data.polygons))


def smart_uv(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")


def make_materials():
    slots = {
        "Skin": (0.82, 0.64, 0.52, 1.0),
        "Hair": (0.72, 0.62, 0.42, 1.0),
        "Clothing": (0.10, 0.11, 0.13, 1.0),
    }
    mats = {}
    for name, col in slots.items():
        mat = bpy.data.materials.new(name=name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = col
            bsdf.inputs["Roughness"].default_value = 0.75
        mats[name] = mat
    return mats


def assign_slot_materials(obj, mats):
    obj.data.materials.clear()
    for key in ("Skin", "Hair", "Clothing"):
        obj.data.materials.append(mats[key])
    # Height bands in object local space
    bbox = [Vector(c) for c in obj.bound_box]
    ys = [v.z for v in bbox]  # glTF Y-up often becomes Z-up in Blender
    # After glTF import Blender uses Z-up; character height is usually Z.
    zs = [v.z for v in bbox]
    zmin, zmax = min(zs), max(zs)
    span = max(zmax - zmin, 1e-5)
    hair_cut = zmin + span * 0.82
    cloth_cut = zmin + span * 0.55

    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    for f in bm.faces:
        cz = sum((v.co.z for v in f.verts)) / 3.0
        if cz >= hair_cut:
            f.material_index = 1  # Hair
        elif cz <= cloth_cut:
            f.material_index = 2  # Clothing
        else:
            f.material_index = 0  # Skin
    bmesh.update_edit_mesh(obj.data)
    bpy.ops.object.mode_set(mode="OBJECT")


def build_armature(obj):
    bbox = [Vector(c) for c in obj.bound_box]
    xs = [v.x for v in bbox]
    ys = [v.y for v in bbox]
    zs = [v.z for v in bbox]
    xmin, xmax = min(xs), max(xs)
    ymin, ymax = min(ys), max(ys)
    zmin, zmax = min(zs), max(zs)
    cx = 0.5 * (xmin + xmax)
    cy = 0.5 * (ymin + ymax)
    h = zmax - zmin
    # Approximate bone chain along height (stance skate pose).
    def z_at(t):
        return zmin + h * t

    bpy.ops.object.armature_add(enter_editmode=True, location=(cx, cy, zmin))
    arm = bpy.context.view_layer.objects.active
    arm.name = "EmilyArmature"
    eb = arm.data.edit_bones
    root = eb[0]
    root.name = "Root"
    root.head = (cx, cy, z_at(0.02))
    root.tail = (cx, cy, z_at(0.08))

    def add_bone(name, parent, t0, t1, xoff=0.0, yoff=0.0):
        b = eb.new(name)
        b.head = (cx + xoff, cy + yoff, z_at(t0))
        b.tail = (cx + xoff, cy + yoff, z_at(t1))
        b.parent = parent
        b.use_connect = False
        return b

    hips = add_bone("Hips", root, 0.08, 0.18)
    spine = add_bone("Spine", hips, 0.18, 0.38)
    chest = add_bone("Chest", spine, 0.38, 0.55)
    neck = add_bone("Neck", chest, 0.55, 0.62)
    head = add_bone("Head", neck, 0.62, 0.78)
    # Arms
    shoulder_w = (xmax - xmin) * 0.22
    add_bone("UpperArm.L", chest, 0.52, 0.40, xoff=shoulder_w)
    add_bone("LowerArm.L", eb["UpperArm.L"], 0.40, 0.28, xoff=shoulder_w * 1.15)
    add_bone("Hand.L", eb["LowerArm.L"], 0.28, 0.22, xoff=shoulder_w * 1.25)
    add_bone("UpperArm.R", chest, 0.52, 0.40, xoff=-shoulder_w)
    add_bone("LowerArm.R", eb["UpperArm.R"], 0.40, 0.28, xoff=-shoulder_w * 1.15)
    add_bone("Hand.R", eb["LowerArm.R"], 0.28, 0.22, xoff=-shoulder_w * 1.25)
    # Legs
    hip_w = (xmax - xmin) * 0.12
    add_bone("Thigh.L", hips, 0.18, 0.10, xoff=hip_w)
    add_bone("Shin.L", eb["Thigh.L"], 0.10, 0.04, xoff=hip_w)
    add_bone("Foot.L", eb["Shin.L"], 0.04, 0.01, xoff=hip_w, yoff=(ymax - ymin) * 0.08)
    add_bone("Thigh.R", hips, 0.18, 0.10, xoff=-hip_w)
    add_bone("Shin.R", eb["Thigh.R"], 0.10, 0.04, xoff=-hip_w)
    add_bone("Foot.R", eb["Shin.R"], 0.04, 0.01, xoff=-hip_w, yoff=(ymax - ymin) * 0.08)

    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def cleanup_mesh(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def bind(obj, arm):
    cleanup_mesh(obj)
    # Ensure armature modifier path: parent with empty groups then heat-weight
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    # Try automatic weights; if heat fails, fall back to envelopes
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    except Exception as e:
        print("ARMATURE_AUTO failed:", e)
        bpy.ops.object.parent_set(type="ARMATURE_ENVELOPE")
    # Verify vertex groups exist
    if obj.vertex_groups and sum(len(g.weight(i) if False else 0) for g in []) == 0:
        pass
    has_weights = False
    for g in obj.vertex_groups:
        # sample: if any group has name matching bones
        has_weights = True
        break
    # If heat weighting left empty groups, paint crude height weights onto Hips/Spine/Head
    if has_weights:
        # Check if any vertex has weight
        me = obj.data
        total = 0.0
        # Use bmesh to check deform layer? simpler: check group count vs zero weights via foreach
        import numpy as np
        # Fallback envelope if auto produced no armature modifier skin
    mods = [m for m in obj.modifiers if m.type == "ARMATURE"]
    print("armature modifiers:", len(mods), "vgroups:", len(obj.vertex_groups))
    if not mods:
        mod = obj.modifiers.new(name="Armature", type="ARMATURE")
        mod.object = arm
        mod.use_vertex_groups = True
    # If bone heat failed, assign crude volumetric weights by bone proximity
    if len(obj.vertex_groups) == 0 or True:
        # Always reinforce with proximity weights so export has JOINTS
        bpy.context.view_layer.objects.active = obj
        # Clear empty groups from failed heat
        obj.vertex_groups.clear()
        for bone in arm.data.bones:
            obj.vertex_groups.new(name=bone.name)
        # Assign each vertex to nearest bone
        bone_pairs = []
        for bone in arm.data.bones:
            head = arm.matrix_world @ bone.head_local
            tail = arm.matrix_world @ bone.tail_local
            bone_pairs.append((bone.name, head, tail))
        me = obj.data
        mw = obj.matrix_world
        for vi, v in enumerate(me.vertices):
            pw = mw @ v.co
            best = None
            best_d = 1e9
            for name, head, tail in bone_pairs:
                # distance to segment
                ab = tail - head
                t = 0.0 if ab.length_squared < 1e-10 else max(0.0, min(1.0, ((pw - head).dot(ab)) / ab.length_squared))
                proj = head + ab * t
                d = (pw - proj).length
                if d < best_d:
                    best_d = d
                    best = name
            if best:
                obj.vertex_groups[best].add([vi], 1.0, "REPLACE")
        if not any(m.type == "ARMATURE" for m in obj.modifiers):
            mod = obj.modifiers.new(name="Armature", type="ARMATURE")
            mod.object = arm
            mod.use_vertex_groups = True
        print("applied proximity skin weights")


def export_glb(path: Path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        if o.type in {"MESH", "ARMATURE"}:
            o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_animations=False,
        export_apply=False,
    )


def main():
    if not SRC.exists():
        raise SystemExit("missing source %s" % SRC)
    clear_scene()
    body = import_glb(SRC)
    cleanup_mesh(body)
    decimate(body, TARGET_FACES)
    smart_uv(body)
    mats = make_materials()
    assign_slot_materials(body, mats)
    arm = build_armature(body)
    bind(body, arm)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    export_glb(OUT)
    print("WROTE", OUT, "size", OUT.stat().st_size)


if __name__ == "__main__":
    main()
