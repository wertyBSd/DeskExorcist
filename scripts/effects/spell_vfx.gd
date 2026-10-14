class_name SpellVfx
## The shared visual vocabulary of the ten spells.
##
## Ten spells that all draw the same expanding disc read as one spell drawn ten
## times: the player cannot tell what they cast until the damage numbers arrive.
## So each spell gets its own shape -- a shockwave, a rune circle, a drain, a
## beam, a column of light, an arc, smoke, a blink, a dome, a judgement -- and
## this class holds the parts those shapes are built from, so they stay one
## family instead of ten.
##
## Everything here returns plain nodes: no assets, no .tscn. Additive blending
## throughout, because light adds to what is behind it -- a transparent sprite
## over a dark room is a grey smear, not a glow.
extends RefCounted

## How many nodes a single cast is allowed to add. Chain lightning is the worst
## case (a bolt and a flash per jump), and the arena can hold a dozen of those.
const MAX_NODES_PER_EFFECT := 96

## Metadata key every shape stamps itself with.
##
## This is the only reason "the ten spells look different" is a testable claim
## rather than a matter of taste: casting all ten and collecting their tags tells
## you which two share a vocabulary, and picking a shape nobody else uses becomes
## a deliberate act instead of an accident of copy-paste.
const TAG := "vfx_shape"

## How bright each shape is allowed to get on its own. The big flat ones need the
## most restraint: a ground ring covers a third of the screen, and additive
## light over that much floor clips to white long before it looks impressive.
const RING_GAIN := 0.5
const RUNE_GAIN := 0.34
const BURST_GAIN := 0.68
const STREAK_GAIN := 1.0
const SPIKE_GAIN := 0.55
const COLUMN_GAIN := 0.7
## A dome is a shell, not a solid: it has to be see-through or the caster
## disappears inside their own shield.
const DOME_GAIN := 0.22
## Smoke is dim on purpose. Additive blending cannot darken, so a "grey" puff
## over a mid-tone floor is only ever a pale smudge -- the way to make it read
## as smoke is to keep it low and let the censer itself be the bright thing.
const SMOKE_GAIN := 0.3

# --- materials ---------------------------------------------------------------

## Additive, unlit, double-sided: the one material every light in the game uses.
## UNSHADED is not a style choice here -- a glow that takes lighting is grey on
## the side facing away from the sun, which is most of a sphere at any moment.
static func glow(colour: Color, gain := 1.0, texture: Texture2D = null) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(colour.r * gain, colour.g * gain, colour.b * gain, colour.a)
	mat.albedo_texture = texture
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	return mat

## A flat, screen-facing card. `billboard` false lays it flat on the floor,
## which is what a ground ring wants.
##
## `gain` is what keeps a big shape from becoming a white hole. Additive light
## adds, so two overlapping rings at full strength over a mid-tone floor clip to
## white and the shape is gone -- which is the same failure as drawing a real
## blast twice as bright and calling it "more dramatic".
static func card(size: float, colour: Color, texture: Texture2D,
		billboard := true, gain := 1.0) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	var mat := glow(colour, gain, texture)
	mat.billboard_mode = (BaseMaterial3D.BILLBOARD_ENABLED if billboard
		else BaseMaterial3D.BILLBOARD_DISABLED)
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh

# --- shapes -----------------------------------------------------------------

## An expanding ring of light on the floor: the blast wave of anything that
## hits a radius. Two rings a beat apart read as a wave with a leading edge,
## where one reads as a circle that got bigger.
static func shockwave(host: Node3D, centre: Vector3, radius: float, colour: Color,
		duration := 0.45, flat := true) -> void:
	for i in 2:
		var ring := card(radius * 2.0, colour, TextureLibrary.ring(), not flat,
			RING_GAIN)
		_tag(ring, "wave")
		host.add_child(ring)
		ring.global_position = centre + Vector3(0.0, 0.06 + float(i) * 0.01, 0.0)
		if flat:
			ring.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		var tween := ring.create_tween()
		tween.set_parallel(true)
		var scale_from := 0.12 + 0.10 * float(i)
		tween.tween_property(ring, "scale", Vector3.ONE, duration)
		tween.tween_property(ring, "transparency", 1.0, duration)
		ring.scale = Vector3.ONE * scale_from
		tween.chain().tween_callback(ring.queue_free)

## A ring that collapses INWARD. Pride drains rather than blasts, and an
## expanding ring would say the opposite.
static func implode(host: Node3D, centre: Vector3, radius: float, colour: Color,
		duration := 0.4) -> void:
	var ring := card(radius * 2.0, colour, TextureLibrary.ring(), true, RING_GAIN)
	_tag(ring, "implode")
	host.add_child(ring)
	ring.global_position = centre + Vector3(0.0, 0.8, 0.0)
	ring.scale = Vector3.ONE
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(0.05, 0.05, 0.05), duration)
	tween.tween_property(ring, "transparency", 1.0, duration)
	tween.chain().tween_callback(ring.queue_free)

## A bright ball that blooms and dies: the flash at the heart of an impact.
static func burst(host: Node3D, centre: Vector3, size: float, colour: Color,
		duration := 0.3, texture: Texture2D = null) -> MeshInstance3D:
	var ball := card(size, colour, texture if texture != null else TextureLibrary.radial(),
		true, BURST_GAIN)
	_tag(ball, "burst")
	host.add_child(ball)
	ball.global_position = centre
	ball.scale = Vector3(0.25, 0.25, 0.25)
	var tween := ball.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ball, "scale", Vector3.ONE, duration * 0.35)
	tween.tween_property(ball, "transparency", 1.0, duration)
	tween.chain().tween_callback(ball.queue_free)
	return ball

## A pillar of light between two points, narrow and hot.
##
## This is the "something fell on the floor from the sky" shape: a telegraph
## that narrows as it descends, then the hit. Drawn as concentric cylinders
## rather than one, because a single translucent tube always reads as a pipe.
static func light_column(host: Node3D, from: Vector3, to: Vector3, radius: float,
		colour: Color, duration := 0.5) -> void:
	var height := maxf(0.1, (from - to).length())
	var tint := colour.lerp(Color.WHITE, 0.55)
	for pass_index in 2:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = radius * (1.0 if pass_index == 0 else 0.42)
		cylinder.bottom_radius = radius * (1.0 if pass_index == 0 else 0.42)
		cylinder.height = height
		cylinder.radial_segments = 12
		cylinder.rings = 1
		var mesh := MeshInstance3D.new()
		mesh.mesh = cylinder
		# The sheath is the spell's colour and the core is near-white: a single
		# cylinder is a flat colour no matter how bright it is.
		mesh.material_override = glow(colour if pass_index == 0 else tint,
			COLUMN_GAIN if pass_index == 0 else COLUMN_GAIN * 1.5,
			TextureLibrary.surface("glow"))
		# The glow ramp fades at both its ends; sampling only the flat middle
		# keeps the fade along the column and drops the wrap-around.
		mesh.material_override.uv1_scale = Vector3(0.5, 1.0, 1.0)
		mesh.material_override.uv1_offset = Vector3(0.25, 0.0, 0.0)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tag(mesh, "column")
		host.add_child(mesh)
		mesh.global_position = (from + to) * 0.5
		_orient(mesh, from, to)
		var tween := mesh.create_tween()
		tween.set_parallel(true)
		tween.tween_property(mesh, "transparency", 1.0, duration)
		tween.chain().tween_callback(mesh.queue_free)

## A jagged bolt between two points -- the one shape that can only mean lightning.
##
## Built as a single ribbon mesh rather than a chain of boxes: a chain of six
## bolts is 80 draw calls on screen at once, and the whole point of a chain
## lightning is that there are five of them. The ribbon is built square to the
## camera at the moment it is struck, which for a 0.25 s flash is the same thing
## as billboarding it properly.
static func bolt(host: Node3D, from: Vector3, to: Vector3, colour: Color,
		duration := 0.25, width := 0.16, jag := 0.5) -> MeshInstance3D:
	var mesh := _ribbon(host, _jag(from, to, jag, width * 6.0), width, colour)
	_tag(mesh, "bolt")
	host.add_child(mesh)
	var tween := mesh.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh, "transparency", 1.0, duration)
	tween.chain().tween_callback(mesh.queue_free)
	return mesh

## Splits a segment into a jagged polyline: the jaggedness is perpendicular to
## the segment, never along it, so the bolt still starts and ends where it must.
static func _jag(from: Vector3, to: Vector3, amount: float, segment_length: float) -> PackedVector3Array:
	var axis := to - from
	var length := axis.length()
	var points := PackedVector3Array()
	if length < 0.001:
		return points
	var steps := maxi(3, int(length / maxf(0.25, segment_length)))
	var forward := axis / length
	var side := forward.cross(Vector3.UP)
	if side.length() < 0.01:
		side = forward.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(forward).normalized()
	for i in steps + 1:
		var t := float(i) / float(steps)
		# The ends stay put: a bolt whose root wanders is a bolt that misses.
		var taper := sin(t * PI)
		var wobble := amount * taper * (0.35 if i == 0 or i == steps else 1.0)
		points.append(from.lerp(to, t)
			+ side * randf_range(-wobble, wobble)
			+ up * randf_range(-wobble, wobble))
	return points

## One mesh, two triangles per segment, always square to `viewer`.
static func _ribbon(host: Node3D, points: PackedVector3Array, width: float,
		colour: Color) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var viewer := _viewer(host)
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var axis := b - a
		if axis.length() < 0.0001:
			continue
		var side := axis.normalized().cross((viewer - (a + b) * 0.5)).normalized()
		if side.length() < 0.01:
			side = axis.normalized().cross(Vector3.UP)
		side = side.normalized() * (width * 0.5)
		# Tapered: a bolt that keeps one width all the way reads as a ribbon.
		var taper_a := 1.0 - 0.55 * float(i) / float(maxi(1, points.size() - 1))
		var taper_b := 1.0 - 0.55 * float(i + 1) / float(maxi(1, points.size() - 1))
		surface.set_color(colour)
		surface.add_vertex(a - side * taper_a)
		surface.add_vertex(a + side * taper_a)
		surface.add_vertex(b + side * taper_b)
		surface.add_vertex(a - side * taper_a)
		surface.add_vertex(b + side * taper_b)
		surface.add_vertex(b - side * taper_b)
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = glow(colour, 1.15)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh

## Sparks and embers drifting up out of a point. Continuous zones call this on
## a timer; one-shot blasts call it once with a burst.
static func motes(host: Node3D, centre: Vector3, count: int, colour: Color,
		spread := 0.6, rise := 1.6, life := 1.1, size := 0.12,
		texture: Texture2D = null) -> void:
	var tex := texture if texture != null else TextureLibrary.radial()
	for i in count:
		var spark := card(size, colour, tex, true, BURST_GAIN * 0.8)
		_tag(spark, "mote")
		var start := centre + Vector3(randf_range(-spread, spread), 0.0,
			randf_range(-spread, spread))
		host.add_child(spark)
		spark.global_position = start
		var drift := Vector3(randf_range(-0.4, 0.4), rise * randf_range(0.6, 1.3),
			randf_range(-0.4, 0.4))
		var tween := spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", start + drift, life)
		tween.tween_property(spark, "scale", Vector3(0.15, 0.15, 0.15), life)
		tween.tween_property(spark, "transparency", 1.0, life * 0.75)
		tween.chain().tween_callback(spark.queue_free)

## A dome of light rising off the floor. Used by the Mirror, and by anything
## that wants to say "this space is closed".
static func dome(host: Node3D, centre: Vector3, radius: float, colour: Color,
		duration := 0.6) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.is_hemisphere = true
	sphere.radial_segments = 18
	sphere.rings = 9
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.material_override = glow(colour, DOME_GAIN)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tag(mesh, "dome")
	host.add_child(mesh)
	mesh.global_position = centre + Vector3(0.0, 0.06, 0.0)
	mesh.scale = Vector3(1.0, 0.05, 1.0)
	var tween := mesh.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3.ONE, duration * 0.3)
	tween.tween_property(mesh, "transparency", 1.0, duration)
	tween.chain().tween_callback(mesh.queue_free)

## A tapered streak between two points: the path of a blink or a beam, and the
## difference between "something travelled" and "two things blinked".
static func streak(host: Node3D, from: Vector3, to: Vector3, width: float,
		colour: Color, duration := 0.25) -> MeshInstance3D:
	var length := maxf(0.05, (to - from).length())
	var cone := CylinderMesh.new()
	cone.top_radius = width * 0.15
	cone.bottom_radius = width * 0.5
	cone.height = length
	cone.radial_segments = 10
	cone.rings = 1
	var mesh := MeshInstance3D.new()
	mesh.mesh = cone
	var mat := glow(colour, STREAK_GAIN, TextureLibrary.surface("glow"))
	mat.uv1_scale = Vector3(0.5, 1.0, 1.0)
	mat.uv1_offset = Vector3(0.25, 0.0, 0.0)
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tag(mesh, "streak")
	host.add_child(mesh)
	mesh.global_position = (from + to) * 0.5
	_orient(mesh, to, from)
	var tween := mesh.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh, "transparency", 1.0, duration)
	tween.chain().tween_callback(mesh.queue_free)
	return mesh

## Radiating spikes on the floor: the "a blast went off here" texture that an
## expanding ring alone does not carry.
static func spikes(host: Node3D, centre: Vector3, count: int, length: float,
		colour: Color, duration := 0.35) -> void:
	for i in count:
		var angle := TAU * float(i) / float(count)
		var from := centre + Vector3(cos(angle), 0.05, sin(angle)) * length * 0.15
		var to := centre + Vector3(cos(angle), 0.05, sin(angle)) * length
		var spike := streak(host, from, to, length * 0.12, colour, duration)
		_tag(spike, "spike")
		var mat := spike.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(colour.r * SPIKE_GAIN, colour.g * SPIKE_GAIN,
				colour.b * SPIKE_GAIN, colour.a)
		var tween := spike.create_tween()
		tween.tween_property(spike, "scale", Vector3(0.1, 0.1, 0.1), duration)

## A standing rune circle: an outer band, an inner band and a ring of ticks,
## returned as one node the caller rotates. A flat disc alone says "this floor
## is highlighted"; three concentric bands with ticks say "this floor is
## consecrated and it is still working".
static func rune_circle(host: Node3D, centre: Vector3, radius: float,
		colour: Color, ticks := 12) -> Node3D:
	var root := Node3D.new()
	root.name = "RuneCircle"
	_tag(root, "runes")
	host.add_child(root)
	root.global_position = centre
	for band in [[1.0, 0.85], [0.62, 0.75], [0.34, 0.55]]:
		var disc := card(radius * 2.0 * float(band[0]), colour, TextureLibrary.ring(),
			false, RUNE_GAIN)
		_tag(disc, "rune_band")
		disc.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		disc.position = Vector3(0.0, 0.05 + 0.01 * float(band[1]), 0.0)
		(disc.material_override as StandardMaterial3D).albedo_color.a = float(band[1])
		root.add_child(disc)
	for i in ticks:
		var angle := TAU * float(i) / float(ticks)
		var tick := card(radius * 0.16, colour, TextureLibrary.radial(), false,
			RUNE_GAIN * 2.0)
		_tag(tick, "rune_tick")
		tick.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		tick.position = Vector3(cos(angle), 0.07, sin(angle)) * radius * 0.78
		root.add_child(tick)
	return root

## One puff of smoke. Spawned repeatedly by anything that burns or smoulders;
## the drift and the growth are what make it read as smoke rather than as a
## grey dot on a fading timer.
static func puff(host: Node3D, at: Vector3, colour: Color, size := 0.5,
		life := 1.3, drift := Vector3(0.25, 1.1, 0.1)) -> MeshInstance3D:
	var cloud := card(size, colour, TextureLibrary.puff(), true, SMOKE_GAIN)
	_tag(cloud, "puff")
	host.add_child(cloud)
	cloud.global_position = at
	var tween := cloud.create_tween()
	tween.set_parallel(true)
	tween.tween_property(cloud, "global_position",
		at + drift * randf_range(0.7, 1.3), life)
	tween.tween_property(cloud, "scale", Vector3(2.1, 2.1, 2.1), life)
	tween.tween_property(cloud, "transparency", 1.0, life * 0.8)
	tween.chain().tween_callback(cloud.queue_free)
	return cloud

# --- helpers -----------------------------------------------------------------

## Stamps a node with the shape it is; see TAG.
static func _tag(node: Node, kind: String) -> void:
	node.set_meta(TAG, kind)

## Every shape a cast of `node` put into the scene, sorted and de-duplicated.
## Used by the test suite to prove the ten spells do not share one picture.
static func shapes_of(node: Node) -> Array[String]:
	var found: Array[String] = []
	_collect(node, found)
	found.sort()
	return found

static func _collect(node: Node, found: Array[String]) -> void:
	if node.has_meta(TAG):
		var kind := str(node.get_meta(TAG))
		if not found.has(kind):
			found.append(kind)
	for child in node.get_children():
		_collect(child, found)

## Where the player is looking from, so a ribbon can be built square to it.
static func _viewer(host: Node3D) -> Vector3:
	var tree := host.get_tree()
	if tree == null or tree.root == null:
		return Vector3.FORWARD
	var cam := tree.root.get_camera_3d()
	if cam != null:
		return cam.global_position
	for node in tree.get_nodes_in_group("player"):
		if node is Node3D:
			return (node as Node3D).global_position + Vector3.UP * 1.6
	return Vector3.ZERO

## Aims a node's +Y along `to - from` (cylinders are built around +Y).
static func _orient(mesh: Node3D, from: Vector3, to: Vector3) -> void:
	var dir := to - from
	if dir.length() < 0.0001:
		return
	var up := Vector3.UP
	if absf(dir.normalized().dot(up)) > 0.99:
		up = Vector3.RIGHT
	mesh.look_at_from_position((from + to) * 0.5, to, up)
	# look_at aims -Z at the target, and a cylinder's axis is +Y.
	mesh.rotate_object_local(Vector3.RIGHT, PI * 0.5)