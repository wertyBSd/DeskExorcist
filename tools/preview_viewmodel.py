# Renders viewmodel_arms.glb from the caster's own camera, i.e. exactly how the
# hands appear in play.  The shared contact sheet (preview_models.py) shows every
# model from the side, which tells you nothing about a first-person viewmodel.
#   blender.exe --background --python tools/preview_viewmodel.py
#
# Writes build/preview_viewmodel_ingame.png and build/preview_viewmodel_pose.png
# (build/ is git-ignored).

import bpy
import math
import mathutils
import os

ROOT = r"c:\research\games\Shooter"
MODEL = os.path.join(ROOT, "assets", "models", "viewmodel_arms.glb")
OUT_INGAME = os.path.join(ROOT, "build", "preview_viewmodel_ingame.png")
OUT_POSE = os.path.join(ROOT, "build", "preview_viewmodel_pose.png")

# Viewmodel.REST, verbatim. Keep in step with scripts/player/viewmodel.gd.
# This camera looks along +Y with +Z up (the Godot-to-Blender axis swap), so the
# Godot -Z push becomes +Y here and the Godot -Y drop becomes +Z.
REST = (0.0, 0.0, -0.20)


def place():
    bpy.ops.import_scene.gltf(filepath=MODEL)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    root = bpy.data.objects.new("Viewmodel", None)
    bpy.context.collection.objects.link(root)
    for o in meshes:
        o.parent = root
    root.location = (REST[0], -REST[2], -REST[1])
    return root


def add_camera(lens, location, rotation):
    cam_data = bpy.data.cameras.new("Eye")
    cam_data.sensor_fit = 'VERTICAL'
    cam_data.sensor_height = 13.2
    cam_data.lens = lens
    cam_data.clip_start = 0.05
    cam = bpy.data.objects.new("Eye", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = location
    cam.rotation_euler = rotation
    return cam


def main():
    os.makedirs(os.path.dirname(OUT_INGAME), exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
        sh = scene.display.shading
        sh.light = 'STUDIO'
        sh.color_type = 'MATERIAL'
        sh.show_cavity = True
    except TypeError:
        scene.render.engine = 'BLENDER_EEVEE_NEXT'

    place()

    # 13.2 mm sensor with an 8.6 mm lens reproduces Camera3D's fov = 75 deg, the
    # vertical FOV Godot actually uses. Anything wider lies about framing.
    scene.camera = add_camera(8.6, (0.0, 0.0, 0.0), (math.radians(90.0), 0.0, 0.0))

    light = bpy.data.objects.new("Key", bpy.data.lights.new("Key", 'SUN'))
    light.data.energy = 3.0
    bpy.context.collection.objects.link(light)
    light.rotation_euler = (0.9, 0.2, 0.4)

    scene.world = bpy.data.worlds.new("W")
    scene.world.color = (0.10, 0.11, 0.14)
    scene.render.resolution_x = 900
    scene.render.resolution_y = 560
    scene.render.image_settings.file_format = 'PNG'

    scene.render.filepath = OUT_INGAME
    bpy.ops.render.render(write_still=True)
    print("[preview_viewmodel] saved", OUT_INGAME)

    # Pulled back to the side: what the hands actually look like, which the
    # in-game framing crops to a couple of dozen pixels each. A track-to empty
    # beats hand-written Euler angles here -- the model moves whenever the pose
    # is retouched and the camera should follow without being re-derived.
    target = bpy.data.objects.new("PoseTarget", None)
    bpy.context.collection.objects.link(target)
    target.location = (0.0, 0.14, -0.05)
    scene.camera = add_camera(30.0, (1.30, -1.25, 0.75), (0.0, 0.0, 0.0))
    track = scene.camera.constraints.new('TRACK_TO')
    track.target = target
    track.track_axis = 'TRACK_NEGATIVE_Z'
    track.up_axis = 'UP_Y'
    scene.render.resolution_x = 900
    scene.render.resolution_y = 560
    scene.render.filepath = OUT_POSE
    bpy.ops.render.render(write_still=True)
    print("[preview_viewmodel] saved", OUT_POSE)


main()
