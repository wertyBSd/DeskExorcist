class_name MeshBatch
## One ArrayMesh assembled out of a pile of little boxes, cones and quads.
##
## The room dressing in RoomDressing is a few hundred small pieces per floor
## (baseboards, dado panels, window frames, door leaves, lamp shades). One
## MeshInstance3D each would mean hundreds of nodes and hundreds of draw calls,
## rebuilt from scratch on every floor transition. MeshBatch appends every
## primitive into shared vertex arrays with per-face (flat) normals and hands
## back a single mesh, so a fully dressed office costs about ten nodes.
##
## Winding: Godot's front face is CLOCKWISE seen from the front, while every
## corner loop in here is written counter-clockwise seen from OUTSIDE the solid
## (that is how the loop order is easy to reason about). `_polygon` additionally
## re-checks the loop with a signed area along the intended normal and flips it
## if a caller got the order wrong, so a mistake degrades to "still visible"
## instead of "silently inside out".

var _verts := PackedVector3Array()
var _norms := PackedVector3Array()
var _uvs := PackedVector2Array()
var _idx := PackedInt32Array()

## Axis index of the two axes left over by a face's own axis, ordered so that
## u x v == +axis (see add_box). Keeps the corner loop counter-clockwise.
const _UV_AXES := [1, 2, 0]

func is_empty() -> bool:
	return _idx.is_empty()

func vertex_count() -> int:
	return _verts.size()

## Axis-aligned-in-local-space box. `uv_scale` converts metres to texture
## repeats so callers can keep world-space proportions in their measurements.
func add_box(centre: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY, uv_scale := 1.0) -> void:
	var h := size * 0.5
	for f in [[0, 1.0], [0, -1.0], [1, 1.0], [1, -1.0], [2, 1.0], [2, -1.0]]:
		var a: int = f[0]
		var s: float = f[1]
		var u_ax: int = _UV_AXES[a]
		var v_ax: int = _UV_AXES[(a + 1) % 3]
		if s < 0.0:
			# Swapping u and v negates the face normal, which is exactly what
			# the -X/-Y/-Z side of the box needs.
			var tmp := u_ax
			u_ax = v_ax
			v_ax = tmp
		var half := Vector3.ZERO
		half[a] = h[a] * s
		var corners := PackedVector3Array()
		var uvs := PackedVector2Array()
		# (lo, lo) -> (hi, lo) -> (hi, hi) -> (lo, hi) in the face's own axes.
		var face_size := Vector2(h[u_ax] * 2.0, h[v_ax] * 2.0) * uv_scale
		for pair in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
			var local := half
			local[u_ax] = h[u_ax] * pair[0]
			local[v_ax] = h[v_ax] * pair[1]
			corners.append(centre + basis * local)
			# 0..1 across the face, scaled to the face's real size in metres so a
			# shared texture keeps its world-space repeat rate.
			uvs.append(Vector2(pair[0] * 0.5 + 0.5, pair[1] * 0.5 + 0.5) * face_size)
		var axis := Vector3.ZERO
		axis[a] = s
		_polygon(corners, (basis * axis).normalized(), uvs)

## Truncated cone (a cylinder when both radii are equal): the lamp shades.
## `segments` is kept low on purpose -- flat shading over 10-12 sides reads as
## deliberate low-poly, and a cone per lamp is cheap either way.
func add_cone(centre: Vector3, radius_bottom: float, radius_top: float, height: float,
		segments := 12, basis: Basis = Basis.IDENTITY) -> void:
	var half := height * 0.5
	var bottom := PackedVector3Array()
	var top := PackedVector3Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		var radial := Vector3(cos(a), 0.0, sin(a))
		bottom.append(centre + basis * (radial * radius_bottom + Vector3(0.0, -half, 0.0)))
		top.append(centre + basis * (radial * radius_top + Vector3(0.0, half, 0.0)))
	for i in segments:
		var j := (i + 1) % segments
		var mid := (bottom[i] + top[i] + bottom[j] + top[j]) * 0.25 - centre
		var normal := Vector3(mid.x, 0.0, mid.z)
		normal = basis * (normal.normalized() if normal.length() > 0.001 else Vector3.RIGHT)
		_quad([bottom[i], top[i], top[j], bottom[j]], normal)
	# Caps (skipped when the radius is zero: a cone tip has no lid).
	var up := (basis * Vector3.UP).normalized()
	if radius_bottom > 0.001:
		_polygon(_ring(centre - up * half, radius_bottom, basis, up), -up)
	if radius_top > 0.001:
		_polygon(_ring(centre + up * half, radius_top, basis, -up), up)

## A flat polygon (the window "sky", light pools, cove washes, picture
## canvases). Corners run counter-clockwise seen from the front; `normal` is the
## facing. UVs are given explicitly so gradients (glow strips, pools) can run
## in the direction they are meant to.
func add_quad(corners: Array, normal: Vector3, uvs: Array = []) -> void:
	var packed := PackedVector3Array()
	for c in corners:
		packed.append(c)
	var uv := PackedVector2Array()
	for u in uvs:
		uv.append(u)
	if uv.size() != packed.size():
		uv = PackedVector2Array()
		for i in packed.size():
			uv.append(Vector2(float(i % 2), float(i / 2)))
	_polygon(packed, normal, uv)

## Bakes everything collected so far into a single MeshInstance3D with
## `material` on every surface, or null when nothing was added. Shadow casting
## is off by default: the dressing sits flush on walls that already cast their
## own shadows, and a second set of shadow casters per room is not worth it.
func build(material: Material, node_name := "Batch", shadows := false) -> MeshInstance3D:
	if is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _norms
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The dressing never blocks anything -- it is all trim on surfaces the level
	# collider already owns -- so it stays out of the visgraph's occluder pass.
	mi.extra_cull_margin = 0.0
	return mi

# --- internals ---------------------------------------------------------------

## Ring of `segments` points on a circle, wound counter-clockwise about `normal`.
func _ring(centre: Vector3, radius: float, basis: Basis, normal: Vector3, segments := 12) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(centre + basis * (Vector3(cos(a), 0.0, sin(a)) * radius))
	return pts

## Same as add_quad but for already-packed arrays.
func _quad(corners: Array, normal: Vector3) -> void:
	var packed := PackedVector3Array()
	for c in corners:
		packed.append(c)
	_polygon(packed, normal)

func _polygon(corners: PackedVector3Array, normal: Vector3, uvs := PackedVector2Array()) -> void:
	if corners.size() < 3:
		return
	var n := normal.normalized()
	# Signed area about `n`: positive means the loop already runs
	# counter-clockwise seen from the front. Flip it rather than trust the caller.
	var area := 0.0
	for i in corners.size():
		area += corners[i].cross(corners[(i + 1) % corners.size()]).dot(n)
	var c := corners
	var uv := uvs
	if area < 0.0:
		c = PackedVector3Array()
		for i in corners.size() - 1:
			c.append(corners[corners.size() - 1 - i])
		if uv.size() == corners.size():
			uv = PackedVector2Array()
			for i in corners.size() - 1:
				uv.append(uvs[uvs.size() - 1 - i])
	var base := _verts.size()
	for i in c.size():
		_verts.append(c[i])
		_norms.append(n)
		_uvs.append(uv[i] if i < uv.size() else Vector2.ZERO)
	# Clockwise front faces: every counter-clockwise fan triangle reversed.
	for i in range(1, c.size() - 1):
		_idx.append(base)
		_idx.append(base + i + 1)
		_idx.append(base + i)