extends Node
## Doorway audit (BUGS.md #19): what stands in each '+' opening of an arena?
##
##   godot --headless --path . res://tools/audit_doorways.tscn -- -1
##
## `-1` = every arena, n = one arena index.
##
## The level is built here with a bare `LevelBuilder`, NOT through
## `Game._build_level()`. Driving the live game means the run timer is running,
## and at 200 s / 400 s `Game._advance_floor()` rebuilds the arena underneath the
## audit -- so the map being measured is a different floor from the map in the
## printed heading.
##
## The probe stops 5 cm short of +/-DOOR_GAP/2. The flanking wall blocks begin at
## exactly that distance, so a ray that ENDS exactly there grazes their faces and
## reports a hit for a doorway that is in fact completely open -- which it did on
## two of Meeting Pods' four openings and looked, for a moment, like the reported
## bug.

func _ready() -> void:
	await get_tree().process_frame
	var only := -1
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			only = int(a)
	var indices: Array = range(LevelBuilder.LEVELS.size()) if only < 0 else [only]
	var total := 0
	var blocked_total := 0
	for i in indices:
		var level := LevelBuilder.new()
		add_child(level)
		level.build(i)
		await get_tree().physics_frame
		var space := level.get_world_3d().direct_space_state
		var half := LevelBuilder.DOOR_GAP * 0.5 - 0.05
		var doorways := 0
		var blocked := 0
		for z in level.cells_z:
			for x in level.cells_x:
				if level.glyph_at(x, z) != "+":
					continue
				doorways += 1
				var c: Vector3 = level.cell_centre(x, z) + Vector3(0.0, 1.4, 0.0)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
					c - Vector3(half, 0.0, 0.0), c + Vector3(half, 0.0, 0.0), 16))
				if hit.is_empty():
					continue
				blocked += 1
				var who: Object = hit["collider"]
				var at: Vector3 = hit["position"]
				print("  BLOCKED %s %s%d by %s '%s' at (%.2f, %.2f, %.2f), %.3f from the gap centre" % [
					LevelBuilder.LEVELS[i]["name"], String.chr(65 + x), z + 1,
					who.get_class(), who.name, at.x, at.y, at.z, absf(at.x - c.x)])
		total += doorways
		blocked_total += blocked
		print("%-18s doorways=%d blocked=%d" % [LevelBuilder.LEVELS[i]["name"], doorways, blocked])
		level.queue_free()
		await get_tree().process_frame
	print("TOTAL doorways=%d blocked=%d" % [total, blocked_total])
	get_tree().quit(0)