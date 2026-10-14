# Reports polycount + bounds for every exported .glb so the budgets in
# BlenderInstruction.MD (500-800 tris small, 1500-2000 characters) stay honest.
#   blender.exe --background --python tools/check_models.py

import bpy
import os

MODEL_DIR = r"c:\research\games\Shooter\assets\models"

# name -> (budget_low, budget_high, note)
BUDGETS = {
    "exorcist.glb": (1500, 2000, "hero"),
    "water_cooler.glb": (1500, 2000, "large enemy"),
    "paperwork_phantom.glb": (500, 800, "small enemy"),
    "email_wraith.glb": (500, 800, "small enemy"),
    "copier_portal.glb": (500, 800, "prop"),
    "enemy_runner.glb": (500, 800, "small enemy"),
    "enemy_tank.glb": (1500, 2000, "large enemy"),
    "enemy_bomber.glb": (500, 800, "small enemy"),
    "survivor.glb": (500, 800, "npc"),
    "boss_director.glb": (1500, 2000, "boss"),
    # A viewmodel is one pair of hands, always on screen and 0.4 m from the lens,
    # so it gets a bigger budget than the "small enemies and props" 500-800: the
    # phalanges, knuckles and wrist strap are what make it read as a gloved hand
    # instead of a beige blob. The charge orb is NOT in here -- it is a
    # ChargeOrb built at runtime, shared with the holy bolt.
    "viewmodel_arms.glb": (700, 1100, "first-person gloved hands"),
}


def report():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rows = []
    for name in sorted(os.listdir(MODEL_DIR)):
        if not name.endswith(".glb"):
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.join(MODEL_DIR, name))
        tris = 0
        lo = [1e9] * 3
        hi = [-1e9] * 3
        empties = 0
        for obj in bpy.data.objects:
            if obj.type == 'EMPTY':
                empties += 1
                continue
            if obj.type != 'MESH':
                continue
            obj.data.calc_loop_triangles()
            tris += len(obj.data.loop_triangles)
            for corner in obj.bound_box:
                world = obj.matrix_world @ __import__("mathutils").Vector(corner)
                for i in range(3):
                    lo[i] = min(lo[i], world[i])
                    hi[i] = max(hi[i], world[i])
        size = [hi[i] - lo[i] for i in range(3)]
        low, high, note = BUDGETS.get(name, (0, 99999, ""))
        if tris > high:
            flag = "OVER"
        elif tris < low:
            flag = "under"
        else:
            flag = "OK "
        if name == "survivor.glb" and abs(size[2] - 1.7) > 0.05:
            flag = "TALL"
        rows.append((flag, name, tris, "%.2f x %.2f x %.2f" % (size[0], size[1], size[2]),
                     empties, note))
    print("\n=== model check ===")
    for flag, name, tris, size, empties, note in rows:
        print("  [%s] %-24s tris=%-5d size=%-20s empties=%d  %s" % (flag, name, tris, size, empties, note))


report()