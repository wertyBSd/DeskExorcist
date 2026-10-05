# Builds the four low-poly Desk Exorcist models from BlenderInstruction.MD and
# exports them as .glb for Godot 4.  Run headless:
#   blender.exe --background --python tools/build_models.py
#
# Style: low-poly, flat shading, solid-colour materials (no textures).  The hero
# carries the Root / Position_Head / Position_SpellCast empties the GDD asks for.

import bpy
import math
import os

OUT_DIR = r"c:\research\games\Shooter\assets\models"


def enable_gltf():
    try:
        bpy.ops.preferences.addon_enable(module="io_scene_gltf2")
    except Exception:
        pass


def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures):
        for b in list(block):
            block.remove(b)


def mat(name, color, emission=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = 0.9
        if emission > 0.0:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = (color[0], color[1], color[2], 1.0)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emission
    return m


def box(name, loc, size, material, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0], size[1], size[2])
    o.data.materials.append(material)
    return o


def cyl(name, loc, radius, depth, material, verts=8, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, vertices=verts, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    return o


def ring(name, loc, major, minor, material):
    bpy.ops.mesh.primitive_torus_add(location=loc, major_radius=major, minor_radius=minor,
                                     major_segments=8, minor_segments=4)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    return o


def empty(name, loc):
    o = bpy.data.objects.new(name, None)
    o.empty_display_size = 0.2
    o.location = loc
    bpy.context.collection.objects.link(o)
    return o


def apply_flat(obj):
    for p in obj.data.polygons:
        p.use_smooth = False


def export(filepath):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=filepath, export_format='GLB', use_selection=True)
    print("[build_models] wrote", filepath)


# --- models ------------------------------------------------------------------

def build_hero():
    clear_scene()
    skin = mat("skin", (0.91, 0.73, 0.55))
    shirt = mat("shirt", (0.95, 0.94, 0.90))
    suit = mat("suit", (0.13, 0.13, 0.18))
    tie = mat("tie", (0.06, 0.06, 0.10))
    stole = mat("stole", (0.56, 0.18, 0.43))
    trim = mat("trim", (0.91, 0.76, 0.35))
    bags = mat("eyebags", (0.42, 0.29, 0.44))
    cross = mat("cross", (1.0, 0.91, 0.66), emission=1.0)

    box("LegL", (-0.13, 0.0, 0.45), (0.17, 0.18, 0.9), suit)
    box("LegR", (0.13, 0.0, 0.45), (0.17, 0.18, 0.9), suit)
    box("Torso", (0.0, 0.0, 1.15), (0.52, 0.30, 0.62), shirt)
    box("Collar", (0.0, 0.0, 1.44), (0.46, 0.30, 0.12), suit)
    box("Tie", (0.0, -0.16, 1.14), (0.10, 0.03, 0.52), tie)
    box("StoleL", (-0.20, -0.16, 1.08), (0.10, 0.04, 0.80), stole)
    box("StoleR", (0.20, -0.16, 1.08), (0.10, 0.04, 0.80), stole)
    box("StoleHem", (0.0, -0.17, 0.66), (0.52, 0.03, 0.10), trim)
    box("Head", (0.0, 0.0, 1.62), (0.28, 0.28, 0.30), skin)
    box("EyeBagL", (-0.07, -0.15, 1.60), (0.08, 0.02, 0.05), bags)
    box("EyeBagR", (0.07, -0.15, 1.60), (0.08, 0.02, 0.05), bags)
    box("ArmL", (-0.60, 0.0, 1.42), (0.68, 0.15, 0.15), shirt)
    box("ArmR", (0.60, 0.0, 1.42), (0.68, 0.15, 0.15), shirt)
    box("HandR", (0.92, 0.0, 1.42), (0.14, 0.16, 0.16), skin)
    box("Sprayer", (0.92, -0.10, 1.42), (0.10, 0.16, 0.10), cross)
    empty("Root", (0.0, 0.0, 0.0))
    empty("Position_Head", (0.0, 0.0, 1.62))
    empty("Position_SpellCast", (0.92, -0.10, 1.42))
    for o in bpy.data.objects:
        if o.type == 'MESH':
            apply_flat(o)
    export(os.path.join(OUT_DIR, "exorcist.glb"))



def build_cooler():
    clear_scene()
    plastic = mat("plastic", (0.78, 0.76, 0.69))
    metal = mat("metal", (0.55, 0.58, 0.66))
    liquid = mat("liquid", (0.63, 0.24, 1.0), emission=1.2)
    maw = mat("maw", (0.10, 0.06, 0.12))
    tooth = mat("tooth", (0.93, 0.91, 0.84))
    claw = mat("claw", (0.30, 0.24, 0.34))

    box("Body", (0.0, 0.0, 0.62), (0.52, 0.52, 0.72), plastic)
    cyl("Bottle", (0.0, 0.0, 1.16), 0.28, 0.62, liquid, verts=10)
    box("Neck", (0.0, 0.0, 0.90), (0.18, 0.18, 0.12), metal)
    box("Mouth", (0.0, -0.26, 0.60), (0.36, 0.08, 0.28), maw)
    for i in range(4):
        box("Tooth%d" % i, (-0.13 + i * 0.086, -0.31, 0.70), (0.05, 0.03, 0.06), tooth)
        box("ToothL%d" % i, (-0.13 + i * 0.086, -0.31, 0.50), (0.05, 0.03, 0.06), tooth)
    for i in range(3):
        a = math.radians(120.0 * i)
        box("Leg%d" % i, (math.cos(a) * 0.26, math.sin(a) * 0.26, 0.16),
            (0.08, 0.08, 0.42), claw, rot=(math.sin(a) * 0.5, -math.cos(a) * 0.5, 0.0))
    for o in bpy.data.objects:
        if o.type == 'MESH':
            apply_flat(o)
    export(os.path.join(OUT_DIR, "water_cooler.glb"))



def build_phantom():
    clear_scene()
    paper = mat("paper", (0.90, 0.89, 0.83))
    ink = mat("ink", (0.42, 0.40, 0.37))
    core = mat("core", (0.42, 0.16, 0.78), emission=1.0)
    clip = mat("clip", (0.62, 0.66, 0.75))

    box("Core", (0.0, 0.0, 0.34), (0.20, 0.16, 0.26), core)
    for i in range(7):
        a = math.radians(51.0 * i)
        box("Sheet%d" % i, (math.cos(a) * 0.20, math.sin(a) * 0.20, 0.24 + 0.06 * (i % 3)),
            (0.30, 0.02, 0.20), paper, rot=(0.0, 0.0, a))
        box("Ink%d" % i, (math.cos(a) * 0.20, math.sin(a) * 0.20 - 0.02, 0.24 + 0.06 * (i % 3)),
            (0.18, 0.01, 0.03), ink, rot=(0.0, 0.0, a))
    ring("ClipA", (0.34, 0.0, 0.44), 0.09, 0.02, clip)
    ring("ClipB", (-0.30, 0.14, 0.18), 0.08, 0.02, clip)
    for o in bpy.data.objects:
        if o.type == 'MESH':
            apply_flat(o)
    export(os.path.join(OUT_DIR, "paperwork_phantom.glb"))


def build_copier():
    clear_scene()
    shell = mat("shell", (0.78, 0.76, 0.69))
    metal = mat("metal", (0.40, 0.43, 0.52))
    beam = mat("beam", (0.63, 0.24, 1.0), emission=1.6)
    rune = mat("rune", (0.82, 0.44, 1.0), emission=1.2)
    tray = mat("tray", (0.24, 0.24, 0.30))

    box("Base", (0.0, 0.0, 0.32), (0.92, 0.72, 0.64), shell)
    box("Top", (0.0, 0.0, 0.68), (0.86, 0.66, 0.12), metal)
    box("Tray", (0.0, -0.42, 0.46), (0.42, 0.24, 0.06), tray)
    box("Column", (0.0, 0.0, 1.14), (0.32, 0.32, 0.80), beam)
    box("Flare", (0.0, 0.0, 1.58), (0.48, 0.48, 0.12), beam)
    for i in range(4):
        box("Rune%d" % i, (-0.30 + i * 0.20, -0.37, 0.30), (0.10, 0.02, 0.10), rune)
        box("RuneS%d" % i, (-0.30 + i * 0.20, -0.37, 0.52), (0.10, 0.02, 0.10), rune)
    for o in bpy.data.objects:
        if o.type == 'MESH':
            apply_flat(o)
    export(os.path.join(OUT_DIR, "copier_portal.glb"))


# --- entry point -------------------------------------------------------------

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    enable_gltf()
    build_hero()
    build_cooler()
    build_phantom()
    build_copier()
    print("[build_models] done")


main()

