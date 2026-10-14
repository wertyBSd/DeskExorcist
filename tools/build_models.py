# Builds the four low-poly Desk Exorcist models from BlenderInstruction.MD and
# exports them as .glb for Godot 4.  Run headless:
#   blender.exe --background --python tools/build_models.py
#
# Style: low-poly, flat shading, solid-colour materials (no textures).  The hero
# carries the Root / Position_Head / Position_SpellCast empties the GDD asks for.

import bpy
import math
import mathutils
import os

OUT_DIR = r"c:\research\games\Shooter\assets\models"


def V3(x, y, z):
    """mathutils.Vector takes one sequence, but joint lists read far better as
    three numbers; this is the shorthand the pose code below is written in."""
    return mathutils.Vector((x, y, z))


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


def ball(name, loc, radius, material, subdivisions=1, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius,
                                          location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    return o


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


def ring(name, loc, major, minor, material, major_segments=8, minor_segments=4,
         rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_torus_add(location=loc, major_radius=major, minor_radius=minor,
                                     major_segments=major_segments,
                                     minor_segments=minor_segments, rotation=rot)
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

def limb(name, start, end, width, material):
    """Box stretched between two points and aimed along them, so forearms and
    fingers can be placed by their joints instead of by hand-tuned Euler angles.
    The cube is built at size 1 and scaled, so the length follows the segment."""
    a = mathutils.Vector(start)
    b = mathutils.Vector(end)
    length = (b - a).length
    o = box(name, (a + b) * 0.5, (width, length, width), material)
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = (b - a).to_track_quat('Y', 'Z')
    return o


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


def build_wraith():
    """Enemy 3 - the Email Wraith: a blue courier-ghost that fires from range.
    Same low-poly flat-shaded language as the other lots; only the palette and
    silhouette change so it reads instantly against the violet phantoms."""
    clear_scene()
    core = mat("wraith_core", (0.18, 0.49, 1.0), emission=1.0)
    cloth = mat("wraith_cloth", (0.55, 0.72, 0.95))
    paper = mat("wraith_paper", (0.90, 0.93, 1.0))
    ink = mat("wraith_ink", (0.20, 0.28, 0.55))
    glyph = mat("wraith_glyph", (0.70, 0.90, 1.0), emission=1.2)

    box("Core", (0.0, 0.0, 0.36), (0.24, 0.20, 0.32), core)
    cyl("Hood", (0.0, 0.0, 0.62), 0.20, 0.26, cloth, verts=8)
    for side in (-1.0, 1.0):
        box("Wing%d" % int(side), (side * 0.30, 0.0, 0.48), (0.36, 0.03, 0.24),
            paper, rot=(0.0, 0.0, side * 0.35))
        box("WingInk%d" % int(side), (side * 0.30, -0.02, 0.46), (0.22, 0.01, 0.04),
            ink, rot=(0.0, 0.0, side * 0.35))
    box("Letter", (0.0, -0.22, 0.50), (0.26, 0.02, 0.18), paper)
    box("LetterInk", (0.0, -0.24, 0.50), (0.18, 0.01, 0.03), ink)
    ring("ClipA", (0.26, 0.0, 0.30), 0.07, 0.015, glyph)
    ring("ClipB", (-0.24, 0.10, 0.22), 0.06, 0.015, glyph)
    for o in bpy.data.objects:
        if o.type == 'MESH':
            apply_flat(o)
    export(os.path.join(OUT_DIR, "email_wraith.glb"))


def build_runner():
    """WIRE_RUNNER - the 'Demon Cleaner': a small monolithic orb on two legs
    swinging an oversized broom-whip. Lean and fast, so the silhouette reads as
    a streak rather than a mass (ASSETS_MODELS.md #2)."""
    clear_scene()
    shell = mat("runner_shell", (0.55, 0.16, 0.10))
    plate = mat("runner_plate", (0.32, 0.30, 0.34))
    grip = mat("runner_grip", (0.16, 0.14, 0.18))
    bristle = mat("runner_bristle", (0.74, 0.66, 0.34))
    spark = mat("runner_spark", (1.0, 0.45, 0.18), emission=1.4)

    ball("Body", (0.0, 0.0, 0.98), 0.36, shell, subdivisions=2)
    box("Collar", (0.0, 0.0, 0.74), (0.46, 0.42, 0.14), plate)
    # Single glowing eye band: a runner is a blur, not a face.
    box("Eye", (0.0, -0.32, 1.02), (0.26, 0.05, 0.09), spark)
    for side in (-1.0, 1.0):
        box("Leg%d" % int(side), (side * 0.16, 0.0, 0.34), (0.09, 0.11, 0.46), grip)
        box("Foot%d" % int(side), (side * 0.16, -0.06, 0.05), (0.13, 0.22, 0.09), plate)
    # Broom-whip carried out to the side, in the XZ plane: angled along Y it would
    # point straight at the camera and foreshorten into an invisible stub.
    box("Grip", (0.22, -0.10, 1.10), (0.14, 0.16, 0.16), grip)
    box("Handle", (0.78, -0.02, 1.14), (1.02, 0.06, 0.06), grip, rot=(0.0, -0.12, 0.0))
    box("Bristle", (1.32, -0.02, 1.18), (0.18, 0.34, 0.34), bristle, rot=(0.0, -0.12, 0.0))
    box("SparkTip", (1.48, -0.02, 1.22), (0.09, 0.09, 0.09), spark)
    for o in bpy.data.objects:
        if o.type == 'MESH':
            apply_flat(o)
    export(os.path.join(OUT_DIR, "enemy_runner.glb"))


def build_tank():
    """FILING_CABINET_TANK - the 'Hard Drive' tank: a toppled server chassis
    rolling on tank treads. Wide, low and slow, so the player reads it as a wall
    that has to be gone around rather than dodged (ASSETS_MODELS.md #2)."""
    clear_scene()
    chassis = mat("tank_chassis", (0.13, 0.13, 0.16))
    steel = mat("tank_steel", (0.30, 0.32, 0.38))
    tread = mat("tank_tread", (0.08, 0.08, 0.10))
    bay = mat("tank_bay", (0.18, 0.20, 0.24))
    eye = mat("tank_eye", (1.0, 0.22, 0.16), emission=1.5)

    box("Chassis", (0.0, 0.0, 0.92), (1.70, 1.10, 0.72), chassis)
    box("Vent", (0.0, 0.0, 1.30), (1.46, 0.90, 0.08), steel)
    for i in range(4):
        box("DriveBay%d" % i, (-0.60 + i * 0.40, -0.56, 0.92), (0.32, 0.05, 0.46), bay)
    box("EyeSlot", (0.0, -0.58, 1.12), (1.10, 0.04, 0.10), eye)
    # Treads: two long belts on either side, each riding three road wheels.
    for side in (-1.0, 1.0):
        box("Tread%d" % int(side), (side * 0.82, 0.0, 0.34), (0.30, 1.24, 0.44), tread)
        for w in range(3):
            cyl("Wheel%d_%d" % (int(side), w), (side * 0.82, -0.40 + w * 0.40, 0.30),
                0.17, 0.32, steel, verts=8, rot=(0.0, 0.0, math.radians(90.0)))
    for o in bpy.data.objects:
        if o.type == 'MESH':
            apply_flat(o)
    export(os.path.join(OUT_DIR, "enemy_tank.glb"))


def build_bomber():
    """PAPER_BOMBER - a wheeled shredder bin packed with burning documents and
    a live fuse. It is the one demon that dies on contact, so the silhouette has
    to telegraph 'about to go off' from across the room (ASSETS_MODELS.md #2)."""
    clear_scene()
    bin_body = mat("bomber_bin", (0.34, 0.35, 0.40))
    rim = mat("bomber_rim", (0.16, 0.16, 0.20))
    paper = mat("bomber_paper", (0.86, 0.80, 0.66))
    ember = mat("bomber_ember", (1.0, 0.42, 0.10), emission=1.8)
    hot = mat("bomber_hot", (1.0, 0.76, 0.24), emission=2.0)

    cyl("Bin", (0.0, 0.0, 0.46), 0.36, 0.84, bin_body, verts=10)
    cyl("Rim", (0.0, 0.0, 0.88), 0.40, 0.10, rim, verts=10)
    # The lid is thrown back off the burning load.
    box("Lid", (0.0, 0.34, 1.06), (0.74, 0.06, 0.52), rim, rot=(-0.62, 0.0, 0.0))
    # Burning documents spilling out of the top.
    for i in range(6):
        a = math.radians(60.0 * i)
        box("Sheet%d" % i, (math.cos(a) * 0.22, math.sin(a) * 0.22, 0.96 + 0.05 * (i % 2)),
            (0.26, 0.03, 0.20), paper, rot=(0.0, 0.0, a))
    ball("Fire", (0.0, 0.0, 1.06), 0.24, ember, subdivisions=1)
    box("Fuse", (0.0, -0.30, 1.18), (0.07, 0.07, 0.22), hot, rot=(0.24, 0.0, 0.0))
    for side in (-1.0, 1.0):
        box("Wheel%d" % int(side), (side * 0.30, -0.12, 0.13), (0.10, 0.22, 0.22), rim,
            rot=(0.0, math.radians(90.0), 0.0))
    for o in bpy.data.objects:
        if o.type == 'MESH':
            apply_flat(o)
    export(os.path.join(OUT_DIR, "enemy_bomber.glb"))


def build_survivor():
    """NPC survivor: a calm, clearly-human figure with the arms down at the
    sides.  The T-pose hero read as 'a monster with its arms out' (BUGS.md #2),
    so this silhouette deliberately keeps every limb below the shoulders
    (ASSETS_MODELS.md #4)."""
    clear_scene()
    skin = mat("survivor_skin", (0.91, 0.72, 0.55))
    shirt = mat("survivor_shirt", (0.56, 0.61, 0.71))
    vest = mat("survivor_vest", (0.78, 0.82, 0.90))
    trousers = mat("survivor_trousers", (0.23, 0.25, 0.33))
    hair = mat("survivor_hair", (0.28, 0.20, 0.16))

    for side in (-1.0, 1.0):
        box("Leg%d" % int(side), (side * 0.11, 0.0, 0.44), (0.16, 0.18, 0.88), trousers)
        box("Shoe%d" % int(side), (side * 0.11, -0.05, 0.05), (0.17, 0.26, 0.10), hair)
        # Arms hang straight down: the one thing that must not change.
        box("Arm%d" % int(side), (side * 0.30, 0.0, 1.06), (0.13, 0.15, 0.62), shirt)
        box("Hand%d" % int(side), (side * 0.30, 0.0, 0.72), (0.12, 0.13, 0.12), skin)
    box("Torso", (0.0, 0.0, 1.12), (0.46, 0.26, 0.56), shirt)
    box("Vest", (0.0, -0.14, 1.12), (0.42, 0.05, 0.52), vest)
    box("Collar", (0.0, 0.0, 1.40), (0.40, 0.26, 0.10), vest)
    box("Head", (0.0, 0.0, 1.55), (0.26, 0.26, 0.28), skin)
    box("Hair", (0.0, 0.02, 1.68), (0.28, 0.26, 0.09), hair)
    empty("Root", (0.0, 0.0, 0.0))
    for o in bpy.data.objects:
        if o.type == 'MESH':
            apply_flat(o)
    export(os.path.join(OUT_DIR, "survivor.glb"))


def build_boss_director():
    """The final boss - 'the Demon Director': a creature fused with the office
    furniture of its own chair.  Binder beard, plaster tie, a throne of office
    chairs, paperclip horns and two burning lamp-eyes (ASSETS_MODELS.md #1).
    Replaces the water-cooler placeholder the boss used to be scaled from."""
    clear_scene()
    suit = mat("boss_suit", (0.10, 0.09, 0.14))
    leather = mat("boss_leather", (0.22, 0.16, 0.26))
    chair = mat("boss_chair", (0.19, 0.22, 0.32))
    steel = mat("boss_steel", (0.52, 0.55, 0.62))
    lamp = mat("boss_lamp", (1.0, 0.78, 0.32), emission=2.2)
    soul = mat("boss_soul", (0.60, 0.18, 0.95), emission=1.3)
    # Binder-beard palette: the office folders it grew out of.
    folders = [mat("binder_%d" % i, c) for i, c in enumerate([
        (0.55, 0.16, 0.18), (0.16, 0.28, 0.52), (0.18, 0.44, 0.26),
        (0.72, 0.58, 0.28), (0.42, 0.24, 0.52),
    ])]

    # --- throne: five office chairs melted into one seat ---------------------
    cyl("Base", (0.0, 0.0, 0.06), 0.44, 0.12, steel, verts=10)
    for i in range(5):
        a = math.radians(72.0 * i)
        box("ChairLeg%d" % i, (math.cos(a) * 0.52, math.sin(a) * 0.52, 0.08),
            (0.34, 0.34, 0.16), chair, rot=(0.0, 0.0, a))
    box("Seat", (0.0, 0.0, 0.52), (1.46, 1.36, 0.22), chair)
    box("Back", (0.0, 0.56, 1.14), (1.42, 0.20, 1.14), chair)
    for side in (-1.0, 1.0):
        box("Arm%d" % int(side), (side * 0.72, 0.0, 0.92), (0.20, 1.20, 0.24), chair)
    # --- body ----------------------------------------------------------------
    box("Torso", (0.0, 0.0, 1.58), (1.62, 1.04, 1.28), suit)
    box("PlasterTie", (0.0, -0.54, 1.46), (0.30, 0.06, 0.86), leather)
    box("TieKnot", (0.0, -0.54, 1.92), (0.26, 0.06, 0.22), leather)
    box("ShoulderL", (-1.02, 0.0, 1.86), (0.52, 0.76, 0.56), suit)
    box("ShoulderR", (1.02, 0.0, 1.86), (0.52, 0.76, 0.56), suit)
    for side in (-1.0, 1.0):
        box("UpperArm%d" % int(side), (side * 1.18, 0.0, 1.46), (0.36, 0.40, 0.62), suit)
        box("Forearm%d" % int(side), (side * 1.22, -0.22, 0.98), (0.34, 0.36, 0.56), leather,
            rot=(0.30, 0.0, 0.0))
        for f in range(3):
            box("Claw%d_%d" % (int(side), f), (side * 1.22 + (f - 1) * 0.13, -0.36, 0.60),
                (0.08, 0.10, 0.30), steel, rot=(0.42, 0.0, 0.0))
    # --- binder beard: stacked folders ---------------------------------------
    for row in range(3):
        for i in range(5 - row):
            w = 0.30
            x = (i - (4 - row) * 0.5) * (w + 0.02)
            box("Binder%d_%d" % (row, i), (x, -0.52 - row * 0.05, 1.20 - row * 0.26),
                (w, 0.16, 0.26), folders[(row * 5 + i) % len(folders)], rot=(0.0, 0.0, 0.0))
    # --- head: two burning lamp-eyes and paperclip horns ---------------------
    box("Head", (0.0, 0.0, 2.50), (0.92, 0.86, 0.74), suit)
    box("Jaw", (0.0, -0.10, 2.22), (0.66, 0.70, 0.22), leather)
    for side in (-1.0, 1.0):
        cyl("EyeLamp%d" % int(side), (side * 0.26, -0.46, 2.52), 0.17, 0.22, lamp, verts=8,
            rot=(math.radians(90.0), 0.0, 0.0))
        ring("Horn%d" % int(side), (side * 0.30, 0.04, 3.02), 0.17, 0.045, steel)
        box("HornStem%d" % int(side), (side * 0.30, 0.04, 2.86), (0.07, 0.07, 0.34), steel)
    box("Crest", (0.0, 0.10, 2.86), (0.20, 0.52, 0.10), soul)
    for o in bpy.data.objects:
        if o.type == 'MESH':
            apply_flat(o)
    export(os.path.join(OUT_DIR, "boss_director.glb"))


def build_viewmodel():
    """First-person viewmodel: two hands held up in the casting gesture, right
    palm up carrying the charge, left steadying it from below.

    Deliberately NOT full arms from the shoulder. A viewmodel is cropped at the
    forearm: the far end is pushed behind the eye and clipped by the near plane,
    so what reaches the screen is a hand plus a stub of sleeve. Authored full
    (shoulder -> fingertips) the forearms pass within 4 cm of the lens and read
    as two black pillars.

    The pose is held LOW -- cut ends below the eye line -- so the forearms enter
    frame from the bottom corners. Level with the eyes they come in from the top
    corners instead and the result reads as arms thrust out front.

    The cut end sits at y = +0.30 (Blender -Y is the caster's forward, so +Y is
    behind); after the orientation flip at the bottom of this function that
    becomes Godot +Z, which is where viewmodel.gd wants it.
    """
    clear_scene()
    # The hands are GLOVES, and everything about the palette exists to make that
    # unmistakable at 40 px: dark leather against a dark suit would be mush, so
    # the glove is a warm brown-black, the knuckles and fingertips are scuffed
    # lighter, and there is a tan strap with a steel buckle at the wrist. A bare
    # low-poly hand is a beige blob -- nobody reads it as a hand at this size.
    leather = mat("leather", (0.20, 0.15, 0.13))
    worn = mat("leather_worn", (0.34, 0.27, 0.22))
    strap = mat("strap", (0.52, 0.36, 0.19))
    steel = mat("buckle", (0.62, 0.63, 0.66))
    # Dark office suit, not a white shirt: a near-white sleeve at 0.4 m from the
    # lens reads as a glare bar across the lower screen, not as an arm.
    suit = mat("sleeve", (0.17, 0.17, 0.23))
    shirt = mat("cuff", (0.74, 0.73, 0.68))
    stole = mat("stole", (0.56, 0.18, 0.43))

    # Three phalanges per finger, each shorter, thinner and more curled than the
    # last. This is what stops a finger reading as a dowel.
    PHALANX_LEN = (0.030, 0.026, 0.021)
    PHALANX_W = (0.025, 0.023, 0.020)
    PHALANX_CURL = (0.0, 0.34, 0.72)

    def finger(name, root, direction, face, length_scale):
        at = root
        d = direction.normalized()
        for k in range(3):
            nd = (d + face * PHALANX_CURL[k]).normalized()
            end = at + nd * PHALANX_LEN[k] * length_scale
            limb("%s%d" % (name, k), at, end, PHALANX_W[k], leather)
            at = end
            d = nd
        return at

    def hand(tag, cut, wrist, palm, tip, inward):
        """One gloved hand. `inward` tilts the palm off pure side-on so the two
        palms cup the charge instead of facing it edge-first."""
        sign = 1.0 if tag == "R" else -1.0
        arm = (wrist - cut).normalized()

        limb("Forearm" + tag, cut, wrist, 0.088, suit)
        # Shirt cuff: the one bright band, then the glove on top of it. Two
        # stacked bands of different colour is the "this is a glove over a
        # sleeve" read, and it is the single strongest cue at small size.
        limb("Shirt" + tag, wrist + arm * 0.012, wrist + arm * 0.042, 0.101, shirt)
        limb("GloveCuff" + tag, wrist + arm * 0.040, wrist + arm * 0.082,
             0.113, worn)
        limb("Strap" + tag, wrist + arm * 0.052, wrist + arm * 0.070, 0.121, strap)
        buckle = box("Buckle" + tag, wrist + arm * 0.061 + V3(0.0, 0.0, -0.060),
                     (0.030, 0.022, 0.010), steel)
        buckle.rotation_mode = 'QUATERNION'
        buckle.rotation_quaternion = arm.to_track_quat('Y', 'Z')

        # Build the palm in a real frame: local Y along the fingers, local Z along
        # the palm face (pointing inward at the other hand). Euler angles cannot
        # express "face the other hand" once the fingers also point forward.
        fwd = (tip - palm).normalized()
        face = mathutils.Vector((-sign, 0.0, 0.0))
        # Positive tilt swings the palm face inward AND up, so the two hands cup
        # the charge instead of both staring at the floor.
        face.rotate(mathutils.Quaternion(V3(0.0, 1.0, 0.0),
                                         math.radians(sign * inward)))
        face.normalize()
        side = fwd.cross(face).normalized()
        basis = mathutils.Matrix((side, fwd, face)).transposed().to_quaternion()

        thick = 0.044
        p = box("Palm" + tag, palm, (0.100, 0.118, thick), leather)
        p.rotation_mode = 'QUATERNION'
        p.rotation_quaternion = basis
        # Taper the heel of the palm so the hand narrows towards the wrist.
        heel = box("Heel" + tag, palm - fwd * 0.062, (0.092, 0.055, thick * 0.86), leather)
        heel.rotation_mode = 'QUATERNION'
        heel.rotation_quaternion = basis

        curl = (fwd + face * 0.40).normalized()
        # Spread wider than the fingers are thick: gaps between digits are the
        # other thing that makes a hand read as a hand.
        knuckle = palm + curl * 0.052 + face * (thick * 0.5)
        for i in range(4):
            root = knuckle + side * ((i - 1.5) * 0.031)
            spread = 1.0 - abs(i - 1.2) * 0.12
            digit_dir = (curl + side * ((i - 1.5) * 0.07 * spread)).normalized()
            # Middle finger longest, index and ring close, little finger short.
            scale = (1.04, 1.10, 1.06, 0.88)[i]
            at = finger("Finger%s%d" % (tag, i), root, digit_dir, face, scale)
            limb("Tip%s%d" % (tag, i), at, at + digit_dir * 0.010, 0.017, worn)
            ball("Knuckle%s%d" % (tag, i), root - face * 0.008, 0.016, worn, subdivisions=1)

        # Thumb: two segments, swung well off the hand and lower than the fingers.
        thumb = palm + side * (-sign * 0.066) + curl * 0.024
        t1 = thumb + side * (-sign * 0.026) + face * 0.022 + fwd * 0.030
        t2 = t1 + side * (-sign * 0.020) + face * 0.024 + fwd * 0.022
        limb("Thumb%s0" % tag, thumb, t1, 0.030, leather)
        limb("Thumb%s1" % tag, t1, t2, 0.026, leather)
        ball("ThumbTip" + tag, t2, 0.016, worn, subdivisions=1)

    # Hands kept close together (x ~ +/-0.15): spread them wider and they sit
    # outside a 75-degree frustum at viewmodel range, leaving only a pair of
    # sleeves poking into the bottom corners.
    #
    # Everything sits BELOW the origin, not above it. With the cut ends level
    # with the eye the forearms enter frame from the upper corners and the whole
    # thing reads as arms thrust out front -- walking-zombie posture. Hands held
    # low, elbows down, is what fixes that.
    right = (V3(0.23, 0.30, -0.03), V3(0.17, 0.02, -0.07),
             V3(0.15, -0.10, -0.12), V3(0.14, -0.22, -0.16))
    hand("R", right[0], right[1], right[2], right[3], 38.0)
    left = (V3(-0.26, 0.33, -0.06), V3(-0.19, 0.07, -0.13),
            V3(-0.16, -0.05, -0.17), V3(-0.15, -0.16, -0.21))
    hand("L", left[0], left[1], left[2], left[3], 30.0)

    # Stole tail on each forearm: the one bit of colour that identifies the
    # caster when all you can see is a pair of hands.
    for side, arm in ((1.0, right), (-1.0, left)):
        box("Stole%d" % int(side),
            arm[0].lerp(arm[1], 0.62) + V3(0.0, 0.0, -0.050),
            (0.075, 0.19, 0.022), stole,
            rot=(math.radians(12.0), math.radians(side * 14.0), 0.0))

    # The charge itself is NOT modelled here. It lives in the game as a
    # `ChargeOrb`, the same object the holy bolt is built from, hung between the
    # palms at Viewmodel.ORB_AT. Modelling it twice is how the orb and the bolt
    # would drift apart, and it puts a light effect in a file whose whole job is
    # to be a pair of hands.

    # --- orientation fix ---------------------------------------------------------
    # Everything above is authored facing Blender -Y, exactly like the rest of
    # the cast. The glTF exporter maps blender_z to Godot's up and blender_y to
    # Godot's -forward, so that pose lands at Godot +Z -- i.e. BEHIND the camera.
    # The world models get away with it because look_at() spins them at runtime,
    # but a viewmodel is parented to the camera and never rotated, so it has to
    # be authored the right way round.
    #
    # The flip has to happen about the WORLD origin, not each box's own centre:
    # rotating a centred cube about itself changes nothing, and the pose lives in
    # the box positions, not the box shapes. So bake location/rotation/scale into
    # the mesh first, leaving every object origin at (0,0,0), then spin the
    # vertex data.
    bpy.ops.object.select_all(action='DESELECT')
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    if not meshes:
        return
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    flip = mathutils.Matrix.Rotation(math.pi, 4, 'Z')
    for o in meshes:
        o.data.transform(flip)

    for o in bpy.data.objects:
        if o.type == 'MESH':
            apply_flat(o)
    bpy.context.view_layer.update()
    _report_bounds("viewmodel_arms")
    export(os.path.join(OUT_DIR, "viewmodel_arms.glb"))


def _report_bounds(name):
    """Prints the mesh bounds in Blender axes. Cheap guard against silently
    shipping a pose that is rotated the wrong way -- a viewmodel is never
    rotated at runtime, so a bad export shows up as hands behind the camera."""
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for o in bpy.data.objects:
        if o.type != 'MESH':
            continue
        for corner in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(corner)
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
    print("[build_models] %s bounds x[%.2f,%.2f] y[%.2f,%.2f] z[%.2f,%.2f]" % (
        name, lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))


# --- entry point -------------------------------------------------------------

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    enable_gltf()
    build_hero()
    build_cooler()
    build_phantom()
    build_copier()
    build_wraith()
    build_runner()
    build_tank()
    build_bomber()
    build_survivor()
    build_boss_director()
    build_viewmodel()
    print("[build_models] done")


main()

