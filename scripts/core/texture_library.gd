class_name TextureLibrary
## Seamless interior surfaces for the office: wallpaper, wainscot, trim wood,
## carpet, ceiling, the view through the windows, plus the soft gradients used
## for light pools and cove washes.
##
## Two rules make this useful rather than decorative:
##
## 1. **Everything tiles.**  A room surface is seen from 1-10 m away across a
##    56 x 40 m arena, so it is applied with UV1 triplanar projection at a fixed
##    world scale (see `material()`).  A texture that does not tile seamlessly
##    turns into a visible grid of repeats from across the room, so every
##    generator below wraps its noise lattice.
## 2. **A real file always wins.**  `assets/textures/<name>.png` overrides the
##    procedural version, exactly like `ModelLibrary` (glb) and `ArtLibrary`
##    (icons/backgrounds).  Drop a proper PBR texture in later and nothing has to
##    be rewired; delete it and the room falls back to the code-drawn version.
##
## On "do we need to GENERATE PICTURES of the walls, floor and ceiling":
## not as one composed image per surface. An image generator returns a scene
## with a viewpoint and objects baked in -- it cannot tile, so it cannot be a
## wall.  Room surfaces want one seamless material each, which is what lives
## here; `LEONARDO_PROMPTS.md` records the slot and the naming convention.
##
## Everything is generated once per process and cached: the first arena pays a
## few milliseconds, every floor transition after that is free.

## Tile resolution. 64 px over a 2 m tile is 32 px/m, which is plenty for flat
## stylised surfaces and keeps the generation under ~20 ms for the whole set.
const SIZE := 64

## Resolution of the head-on radial glow. Bigger than a surface tile because it
## is stretched over the whole quad it lights rather than repeated across a wall,
## and a soft gradient shows its steps long before a texture tile would.
const RADIAL_SIZE := 128

## Where a hand-made / generated surface is dropped in. One file per surface,
## same "the file name is the whole wiring" contract as ArtLibrary.
const TEX_DIR := "res://assets/textures/"

## Every surface this class can draw, in the order a room needs them.
const SURFACES := [
	"wallpaper", "wainscot", "wood", "carpet", "ceiling", "sky", "glow", "canvas",
]

static var _cache: Dictionary = {}
## Built once for `radial()`; kept out of `_cache` because they are not surfaces.
static var _radial: ImageTexture = null
static var _ring: ImageTexture = null
static var _puff: ImageTexture = null

# --- public API --------------------------------------------------------------

## Path a real texture would sit at. Naming rule: lower_snake_case, matching a
## name from SURFACES, `.png`.
static func surface_path(surface: String) -> String:
	return TEX_DIR + surface + ".png"

## True when a real file backs this surface (tests pin the convention, and the
## dressing logs which of its materials are the real ones).
static func has_override(surface: String) -> bool:
	return ResourceLoader.exists(surface_path(surface))

## The surface texture: the real file when present, otherwise the procedural
## one. Never returns null, so a missing file can never leave a bare white room.
static func surface(surface: String) -> Texture2D:
	if has_override(surface):
		var tex := load(surface_path(surface)) as Texture2D
		if tex != null:
			return tex
	if not _cache.has(surface):
		_cache[surface] = _generate(surface)
	return _cache[surface]

## Textured surface material. `uv_scale` is repeats per metre: 0.5 means the
## 2 m tile the generators were drawn for.
static func material(surface: String, tint: Color, roughness := 0.9, uv_scale := 0.5) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = surface(surface)
	mat.albedo_color = tint
	mat.roughness = roughness
	mat.metallic = 0.0
	# Triplanar: the level is built out of BoxMesh/ArrayMesh primitives whose
	# UVs are per-face 0..1, so without this a wallpaper would be stretched
	# across a whole 4 m wall cell and a 56 m floor would show one single copy.
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = false
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	return mat

## Untextured material for the parts that are not "surfaces": glass, metal,
## glowing strips, light pools.
static func plain(tint: Color, roughness := 0.5, metallic := 0.0,
		emission := 0.0, unshaded := false, additive := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = roughness
	mat.metallic = metallic
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = tint
		mat.emission_energy_multiplier = emission
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if additive:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		# A glow quad is a decal: it must be visible from both sides and must not
		# write depth, or it clips into the wall it is washing.
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.no_depth_test = false
	return mat

## Drop every cached surface. Only needed by tooling that reloads textures.
static func clear_cache() -> void:
	_cache.clear()
	_radial = null
	_ring = null
	_puff = null

## Soft radial falloff for a light source seen head-on: solid in the middle,
## gone well before the edge. A quad carrying it reads as a glow instead of a
## lit square, which is the whole point -- the charge orb used to be surrounded
## by a torus, and a torus is a ring, not a glow.
##
## Deliberately NOT one of the SURFACES: this never tiles, nothing drops a file
## over it, and it is shared by the orb and anything else that wants a lamp.
static func radial() -> ImageTexture:
	if _radial != null:
		return _radial
	var img := Image.create_empty(RADIAL_SIZE, RADIAL_SIZE, false, Image.FORMAT_RGBA8)
	var half := float(RADIAL_SIZE) * 0.5
	for y in RADIAL_SIZE:
		for x in RADIAL_SIZE:
			var d := Vector2(float(x) - half + 0.5, float(y) - half + 0.5).length() / half
			# Two-part falloff: a bright core inside a third of the radius, then a
			# long tail. A single power curve either blooms into a flat disc or
			# dies before it reaches the edge, and both read as a decal.
			var a := 0.0
			if d < 1.0:
				a = 0.45 * pow(1.0 - d / 0.34, 2.0) if d < 0.34 else 0.0
				a += 0.55 * pow(maxf(1.0 - d, 0.0), 2.6)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_radial = ImageTexture.create_from_image(img)
	return _radial

## A soft-edged annulus, transparent in the middle and at the rim: the texture
## behind every shockwave and ground ring. A hard-edged ring drawn as geometry
## reads as a wireframe hoop, which is the exact thing a blast wave must not
## look like.
static func ring() -> ImageTexture:
	if _ring != null:
		return _ring
	var img := Image.create_empty(RADIAL_SIZE, RADIAL_SIZE, false, Image.FORMAT_RGBA8)
	var half := float(RADIAL_SIZE) * 0.5
	for y in RADIAL_SIZE:
		for x in RADIAL_SIZE:
			var d := Vector2(float(x) - half + 0.5, float(y) - half + 0.5).length() / half
			# Gaussian-ish band centred on 0.78 of the radius: close enough to the
			# edge that the quad's own boundary is always fully transparent, which
			# is what lets the same texture serve a ring of any radius.
			var a := exp(-pow((d - 0.78) / 0.11, 2.0))
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_ring = ImageTexture.create_from_image(img)
	return _ring

## A soft, lumpy blob for smoke and dust. The radial gradient is too perfectly
## round to read as smoke: real smoke has an edge that wanders, so the falloff
## is pushed around by a little tiling noise.
static func puff() -> ImageTexture:
	if _puff != null:
		return _puff
	var img := Image.create_empty(RADIAL_SIZE, RADIAL_SIZE, false, Image.FORMAT_RGBA8)
	var half := float(RADIAL_SIZE) * 0.5
	var noise := _lattice(12, 7)
	for y in RADIAL_SIZE:
		for x in RADIAL_SIZE:
			var u := float(x) / float(RADIAL_SIZE)
			var v := float(y) / float(RADIAL_SIZE)
			var d := Vector2(float(x) - half + 0.5, float(y) - half + 0.5).length() / half
			var lump := (_sample(noise, 12, u, v) - 0.5) * 0.30
			var a := 0.0
			if d + lump < 1.0:
				a = pow(1.0 - (d + lump), 1.5)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_puff = ImageTexture.create_from_image(img)
	return _puff

# --- generators --------------------------------------------------------------

static func _generate(surface: String) -> Texture2D:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	match surface:
		"wallpaper": _draw_wallpaper(img)
		"wainscot": _draw_wainscot(img)
		"wood": _draw_wood(img)
		"carpet": _draw_carpet(img)
		"ceiling": _draw_ceiling(img)
		"sky": _draw_sky(img)
		"glow": _draw_glow(img)
		"canvas": _draw_canvas(img)
		_: _draw_wallpaper(img)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Office wallpaper: a wide vertical stripe with a thin gold pinstripe down its
## centre, blotched by two octaves of tiling value noise. Dark violet-grey so it
## sits next to the gold trim without fighting the portal violet. The stripe
## count is deliberately low: at one repeat per 2 m, eight stripes a tile is a
## pinstripe every 25 cm, and from across the room that reads as noise.
static func _draw_wallpaper(img: Image) -> void:
	var base := Color("#37324a")
	var stripe := Color("#3f3854")
	var gold := Color("#5c5136")
	var blotch := _lattice(4, 11)
	var grain := _lattice(16, 29)
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / float(SIZE)
			var v := float(y) / float(SIZE)
			var c := base.lerp(stripe, _saw(u * 2.0) * 0.6)
			# Pinstripe: a narrow band centred in each half of the tile (50 cm).
			var pin := absf(fposmod(u * 4.0, 2.0) - 1.0)
			c = c.lerp(gold, 0.5 * (1.0 - smoothstep(0.0, 0.06, pin)))
			c = c.lerp(base.darkened(0.35), 0.4 * (1.0 - _sample(blotch, 4, u, v)))
			c = c.lerp(c.lightened(0.18), 0.25 * _sample(grain, 16, u, v))
			img.set_pixel(x, y, c)

## Painted wainscot board: flat dark paint, faint vertical brush grain, and a
## scuff line near the bottom edge (that is where chairs and trolleys hit it).
static func _draw_wainscot(img: Image) -> void:
	var base := Color("#2b2738")
	var grain := _lattice(16, 47)
	var scuff := _lattice(8, 83)
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / float(SIZE)
			var v := float(y) / float(SIZE)
			var c := base.lerp(base.lightened(0.22), 0.5 * _sample(grain, 16, u, v * 0.25))
			c = c.lerp(base.darkened(0.5), 0.5 * (1.0 - _sample(scuff, 8, u, v)) * smoothstep(0.55, 0.95, v))
			img.set_pixel(x, y, c)

## Trim wood (baseboards, rails, door leaves, window frames): long grain along
## the U axis, with a couple of darker knots.
static func _draw_wood(img: Image) -> void:
	var base := Color("#4a3a30")
	var light := Color("#5c483a")
	var dark := Color("#2e241e")
	var grain := _lattice(8, 61)
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / float(SIZE)
			var v := float(y) / float(SIZE)
			# Stretched noise = grain lines running the length of the board.
			var g := _sample(grain, 8, u * 0.25, v)
			var ring := 0.5 + 0.5 * sin(g * 18.0 + v * 3.0)
			var c := base.lerp(light, 0.6 * ring)
			c = c.lerp(dark, 0.5 * smoothstep(0.55, 1.0, 1.0 - ring))
			img.set_pixel(x, y, c)

## Carpet tile: fine two-tone speckle with a faint 0.5 m grid line, so the
## floor reads as laid tiles and the player gets a sense of distance while
## running at it.
static func _draw_carpet(img: Image) -> void:
	var base := Color("#23222c")
	var fleck := Color("#2d2b3a")
	var seam := Color("#191822")
	var grain := _lattice(32, 5)
	var blotch := _lattice(8, 71)
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / float(SIZE)
			var v := float(y) / float(SIZE)
			var c := base.lerp(fleck, 0.5 * _sample(grain, 32, u, v))
			c = c.lerp(base.lightened(0.12), 0.35 * _sample(blotch, 8, u, v))
			# Two grid lines per tile = a 0.5 m laid-tile grid at uv_scale 0.5.
			var gu := minf(fposmod(u * 2.0, 1.0), fposmod(-u * 2.0, 1.0))
			var gv := minf(fposmod(v * 2.0, 1.0), fposmod(-v * 2.0, 1.0))
			c = c.lerp(seam, 0.8 * (1.0 - smoothstep(0.0, 0.045, minf(gu, gv))))
			img.set_pixel(x, y, c)

## Suspended ceiling tile: a 2x2 grid of 1 m panels with darker grout and the
## speckled acoustic surface real offices have.
static func _draw_ceiling(img: Image) -> void:
	var base := Color("#a8abb6")
	var grout := Color("#6f727d")
	var speck := _lattice(32, 17)
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / float(SIZE)
			var v := float(y) / float(SIZE)
			var c := base.lerp(base.darkened(0.18), 0.6 * _sample(speck, 32, u, v))
			var gu := minf(fposmod(u * 2.0, 1.0), fposmod(-u * 2.0, 1.0))
			var gv := minf(fposmod(v * 2.0, 1.0), fposmod(-v * 2.0, 1.0))
			c = c.lerp(grout, smoothstep(0.06, 0.0, minf(gu, gv)))
			img.set_pixel(x, y, c)

## What is outside the glass: deep violet space with a cold glow low down (the
## city/planet the office tower hangs over) and a scatter of stars. Level 1 is
## a spaceport lobby, and every floor of the tower looks out at the same sky.
static func _draw_sky(img: Image) -> void:
	var top := Color("#120c22")
	var bottom := Color("#3a2358")
	var glow := Color("#8f5fd6")
	var stars := _lattice(16, 101)
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / float(SIZE)
			var v := float(y) / float(SIZE)
			var c := top.lerp(bottom, v * v)
			c = c.lerp(glow, 0.6 * pow(v, 5.0))
			var s := _sample(stars, 16, u, v)
			c = c.lerp(Color("#e8eeff"), smoothstep(0.86, 1.0, s) * 0.95)
			img.set_pixel(x, y, c)

## Vertical falloff used by the light decals: opaque white at the top (V = 1)
## fading to nothing at the bottom, softened at both ends so a strip has no hard
## edge. Alpha is the carrier -- these are additive/multiplied decals.
static func _draw_glow(img: Image) -> void:
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / float(SIZE)
			var v := float(y) / float(SIZE)
			var a := pow(v, 1.6)
			# Soften the left/right ends so the strip fades out along the wall.
			a *= smoothstep(0.0, 0.12, u) * smoothstep(1.0, 0.88, u)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))

## Canvas behind a picture frame: a dark field with one wide violet sweep and a
## thin gold band. Purely decorative, but a wall of blank wallpaper is what made
## the rooms read as boxes in the first place.
static func _draw_canvas(img: Image) -> void:
	var field := Color("#241a3a")
	var violet := Color("#4b2a7a")
	var gold := Color("#a8853c")
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / float(SIZE)
			var v := float(y) / float(SIZE)
			var d := fposmod(u * 0.75 + v * 0.55, 1.0)
			var c := field.lerp(violet, smoothstep(0.05, 0.55, d) * (1.0 - smoothstep(0.6, 0.95, d)))
			var g := absf(d - 0.28)
			c = c.lerp(gold, 0.7 * (1.0 - smoothstep(0.0, 0.05, g)))
			c = c.lerp(field.darkened(0.35), v * 0.5)
			img.set_pixel(x, y, c)

# --- tiling noise ------------------------------------------------------------

## A `n` x `n` grid of random values in 0..1. Sampling it with wrapped
## coordinates is what makes every texture here seamless: the lattice wraps, so
## opposite edges of the tile meet with the same value they started with.
static func _lattice(n: int, salt: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n * n)
	for y in n:
		for x in n:
			out[y * n + x] = _hash2(x, y, salt)
	return out

## Smoothed bilinear sample of a lattice at normalised tile coordinates.
static func _sample(lat: PackedFloat32Array, n: int, u: float, v: float) -> float:
	var fx := u * float(n)
	var fy := v * float(n)
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var tx := fx - float(ix)
	var ty := fy - float(iy)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var v00 := lat[(iy % n) * n + (ix % n)]
	var v10 := lat[(iy % n) * n + ((ix + 1) % n)]
	var v01 := lat[((iy + 1) % n) * n + (ix % n)]
	var v11 := lat[((iy + 1) % n) * n + ((ix + 1) % n)]
	return lerpf(lerpf(v00, v10, tx), lerpf(v01, v11, tx), ty)

## Integer hash -> 0..1. Deterministic across runs and platforms: the arena must
## look identical every time a floor is rebuilt.
static func _hash2(x: int, y: int, salt: int) -> float:
	var h := (x * 374761393 + y * 668265263 + salt * 1442695041) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	h = (h ^ (h >> 16)) & 0xFFFF
	return float(h) / 65535.0

## Triangle wave in 0..1 -- cheaper stripes than a texture fetch.
static func _saw(t: float) -> float:
	return absf(fposmod(t, 2.0) - 1.0)