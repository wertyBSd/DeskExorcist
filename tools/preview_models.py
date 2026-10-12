# Renders a contact sheet of every exported .glb so the silhouettes can be
# eyeballed without launching the game.  Workbench studio shading keeps it fast
# and matches the flat low-poly look the assets are authored in.
#   blender.exe --background --python tools/preview_models.py
#
# Writes build/preview.png (build/ is git-ignored).

import bpy
import math
import os

ROOT = r"c:\research\games\Shooter"
MODEL_DIR = os.path.join(ROOT, "assets", "models")
OUT = os.path.join(ROOT, "build", "preview.png")

ORDER = [
    "exorcist.glb", "survivor.glb", "water_cooler.glb", "paperwork_phantom.glb",
    "email_wraith.glb", "enemy_runner.glb", "enemy_tank.glb", "enemy_bomber.glb",
    "copier_portal.glb", "boss_director.glb",
]
# Normalise every model to a comparable display height so a 3 m boss and a
# 1 m imp are both legible on the same sheet.
DISPLAY_H = 1.8
COLS = 5


def pick_engine(scene):
    """Prefer Workbench (flat studio shading matches the low-poly look), but ask
    the scene what it accepts instead of trusting a hardcoded id."""
    for want in ("BLENDER_WORKBENCH", "BLENDER_EEVEE_NEXT", "CYCLES"):
        try:
            scene.render.engine = want
            if scene.render.engine == want:
                return want
        except TypeError:
            continue
    return scene.render.engine


def import_one(name):
    """Imports one .glb into the CURRENT scene and parents the new meshes to a
    positioned root.  The scene is deliberately not reset: every model stays put
    so they end up side by side on one contact sheet."""
    path = os.path.join(MODEL_DIR, name)
    if not os.path.exists(path):
        return None
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o not in before]
    if not meshes:
        return None
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for o in meshes:
        for corner in o.bound_box:
            w = o.matrix_world @ __import__("mathutils").Vector(corner)
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
    height = max(hi[2] - lo[2], 1e-4)
    scale = DISPLAY_H / height
    root = bpy.data.objects.new("PREVIEW_" + name.replace(".glb", ""), None)
    bpy.context.collection.objects.link(root)
    for o in meshes:
        o.parent = root
    # Sit the model on the floor and centre it on X so the grid is even.
    root.scale = (scale, scale, scale)
    root.location = (-(lo[0] + hi[0]) * 0.5 * scale, -(lo[1] + hi[1]) * 0.5 * scale,
                     -lo[2] * scale)
    return root


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    engine = pick_engine(scene)
    print("[preview] engine:", engine)

    spacing = 2.6
    for i, name in enumerate(ORDER):
        root = import_one(name)
        if root is None:
            print("[preview] MISSING", name)
            continue
        # One straight row viewed from the side: with an orthographic camera a
        # tilted multi-row grid squeezes depth and the silhouettes overlap.
        root.location.x += (i - (len(ORDER) - 1) * 0.5) * spacing
        print("[preview] placed", name)

    width = len(ORDER) * spacing

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = width
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (0.0, -width * 0.4, DISPLAY_H * 0.5)
    cam.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scene.camera = cam

    light = bpy.data.objects.new("Key", bpy.data.lights.new("Key", 'SUN'))
    light.data.energy = 4.0
    bpy.context.collection.objects.link(light)
    light.rotation_euler = (0.9, 0.2, 0.4)

    scene.render.engine = engine
    scene.render.resolution_x = 2000
    scene.render.resolution_y = 620
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("W")
    scene.world.color = (0.10, 0.11, 0.14)
    if engine == 'BLENDER_WORKBENCH':
        sh = scene.display.shading
        sh.light = 'STUDIO'
        sh.color_type = 'MATERIAL'
        sh.show_cavity = True
        sh.show_shadows = True
    else:
        scene.world.use_nodes = True
        bg = scene.world.node_tree.nodes.get("Background")
        if bg:
            bg.inputs[0].default_value = (0.10, 0.11, 0.14, 1.0)
            bg.inputs[1].default_value = 1.0

    scene.render.filepath = OUT
    scene.render.image_settings.file_format = 'PNG'
    bpy.ops.render.render(write_still=True)
    print("[preview] wrote", OUT)


main()