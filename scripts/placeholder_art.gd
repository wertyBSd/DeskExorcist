class_name PlaceholderArt
## Procedural stand-in artwork.
##
## The real assets will be low-poly Blender models exported as .glb (see
## BlenderInstruction.MD). Until then this class paints flat, chunky
## approximations of exactly those models at runtime, so the game is playable
## and every silhouette already reads correctly from a top-down camera.
##
## Everything here is generated in code -- no binary assets, nothing to import.
## Swapping in the real model later only means assigning a texture to the
## Sprite2D; make_sprite() refuses to overwrite a texture that already exists.

# --- Palette: moody office-gothic --------------------------------------------
const C_CLEAR := Color(0, 0, 0, 0)
const C_OUTLINE := Color("#14121c")
const C_SKIN := Color("#e8b98c")
const C_SKIN_DARK := Color("#b98a63")
const C_EYE_BAG := Color("#6b4a6f")
const C_SHIRT := Color("#f2f0e6")
const C_SHIRT_DARK := Color("#c9c6b8")
const C_SUIT := Color("#22212e")
const C_SUIT_LIGHT := Color("#34324c")
const C_TIE := Color("#101019")
const C_STOLE := Color("#8f2f6d")
const C_STOLE_TRIM := Color("#e8c25a")
const C_CROSS := Color("#ffe9a8")
const C_CROSS_HOT := Color("#fffbe8")
const C_VIOLET := Color("#a03cff")
const C_VIOLET_DARK := Color("#5a1a9c")
const C_VIOLET_HOT := Color("#d79bff")
const C_ACID := Color("#9dff4d")
const C_PAPER := Color("#e6e2d3")
const C_PAPER_DARK := Color("#b0ab99")
const C_METAL := Color("#8d93a8")
const C_METAL_DARK := Color("#4c5163")
const C_COPIER := Color("#c8c3b0")
const C_GLASS := Color("#9fd8ff")
const C_BLOOD := Color("#c2364a")
const C_SHADOW := Color(0, 0, 0, 0.28)

## Texture assigned when a Sprite2D has no real (imported) artwork yet.
static func needs_placeholder(sprite: Sprite2D) -> bool:
	return sprite != null and sprite.texture == null

## Assigns placeholder art only when the sprite is still empty, so real
## Blender-exported art always wins once it is wired up.
static func make_sprite(sprite: Sprite2D, texture: Texture2D) -> void:
	if needs_placeholder(sprite):
		sprite.texture = texture

# --- Minimal software rasterizer ---------------------------------------------

static func _canvas(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(C_CLEAR)
	return img

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for py in range(maxi(0, y), mini(img.get_height(), y + h)):
		for px in range(maxi(0, x), mini(img.get_width(), x + w)):
			img.set_pixel(px, py, c)

static func _frame(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	_rect(img, x, y, w, 1, c)
	_rect(img, x, y + h - 1, w, 1, c)
	_rect(img, x, y, 1, h, c)
	_rect(img, x + w - 1, y, 1, h, c)

static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	var rr := r * r
	for py in range(maxi(0, cy - r), mini(img.get_height(), cy + r + 1)):
		for px in range(maxi(0, cx - r), mini(img.get_width(), cx + r + 1)):
			var dx := px - cx
			var dy := py - cy
			if dx * dx + dy * dy <= rr:
				img.set_pixel(px, py, c)

static func _ring(img: Image, cx: int, cy: int, r: int, thick: int, c: Color) -> void:
	var ro := r * r
	var ri := maxi(0, r - thick) * maxi(0, r - thick)
	for py in range(maxi(0, cy - r), mini(img.get_height(), cy + r + 1)):
		for px in range(maxi(0, cx - r), mini(img.get_width(), cx + r + 1)):
			var dx := px - cx
			var dy := py - cy
			var d := dx * dx + dy * dy
			if d <= ro and d >= ri:
				img.set_pixel(px, py, c)

static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	var x := x0
	var y := y0
	while true:
		_px(img, x, y, c)
		if x == x1 and y == y1:
			break
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy

static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

# --- Actors ------------------------------------------------------------------

## "The Desk Exorcist": tired clerk, white shirt, black tie, priest stole.
## Top-down, so the face reads as hair + eye bags and the stole crosses the chest.
static func player_exorcist() -> Texture2D:
	var img := _canvas(32, 32)
	_disc(img, 16, 24, 10, C_SHADOW)
	_rect(img, 6, 12, 20, 14, C_SUIT)
	_frame(img, 6, 12, 20, 14, C_OUTLINE)
	_rect(img, 6, 12, 20, 3, C_SUIT_LIGHT)
	_rect(img, 13, 12, 6, 5, C_SHIRT)
	_rect(img, 9, 13, 3, 13, C_STOLE)
	_rect(img, 20, 13, 3, 13, C_STOLE)
	_rect(img, 9, 13, 3, 2, C_STOLE_TRIM)
	_rect(img, 20, 13, 3, 2, C_STOLE_TRIM)
	_rect(img, 15, 13, 2, 8, C_TIE)
	_disc(img, 16, 8, 6, C_SKIN)
	_ring(img, 16, 8, 6, 1, C_OUTLINE)
	_rect(img, 10, 3, 12, 4, C_SUIT)
	_rect(img, 10, 3, 2, 7, C_SUIT)
	_rect(img, 20, 3, 2, 7, C_SUIT)
	_rect(img, 11, 8, 4, 2, C_EYE_BAG)
	_rect(img, 17, 8, 4, 2, C_EYE_BAG)
	_px(img, 12, 8, C_OUTLINE)
	_px(img, 19, 8, C_OUTLINE)
	_rect(img, 24, 16, 3, 2, C_METAL_DARK)
	_rect(img, 25, 12, 1, 8, C_CROSS)
	_rect(img, 24, 14, 3, 1, C_CROSS)
	_rect(img, 5, 17, 3, 3, C_SKIN_DARK)
	return _tex(img)

## "Water Cooler Demon": glowing violet bottle on three spindly demon legs.
static func water_cooler_demon() -> Texture2D:
	var img := _canvas(32, 32)
	_disc(img, 16, 24, 10, C_SHADOW)
	_line(img, 9, 22, 4, 29, C_OUTLINE)
	_line(img, 9, 22, 5, 28, C_VIOLET_DARK)
	_line(img, 23, 22, 28, 29, C_OUTLINE)
	_line(img, 23, 22, 27, 28, C_VIOLET_DARK)
	_line(img, 16, 24, 16, 30, C_OUTLINE)
	_line(img, 16, 24, 16, 29, C_VIOLET_DARK)
	_rect(img, 9, 13, 14, 10, C_SHIRT)
	_frame(img, 9, 13, 14, 10, C_OUTLINE)
	_rect(img, 10, 17, 12, 4, C_TIE)
	for i in range(6):
		_rect(img, 11 + i * 2, 17, 1, 2, C_SHIRT)
		_rect(img, 11 + i * 2, 19, 1, 2, C_SHIRT)
	_rect(img, 11, 3, 10, 10, C_GLASS)
	_frame(img, 11, 3, 10, 10, C_OUTLINE)
	_rect(img, 12, 4, 8, 8, C_VIOLET)
	_disc(img, 14, 7, 2, C_VIOLET_HOT)
	_disc(img, 18, 10, 1, C_VIOLET_HOT)
	_rect(img, 14, 1, 4, 2, C_METAL)
	return _tex(img)

## "Paperwork Phantom": a swirl of crumpled reports shaped like a weeping ghost.
static func paperwork_phantom() -> Texture2D:
	var img := _canvas(32, 32)
	_disc(img, 16, 22, 9, C_SHADOW)
	_rect(img, 7, 8, 18, 16, C_PAPER)
	_frame(img, 7, 8, 18, 16, C_OUTLINE)
	for i in range(6):
		var torn := 2 + (i % 2) * 2
		_rect(img, 7 + i * 3, 22, 3, torn, C_PAPER)
		_frame(img, 7 + i * 3, 22, 3, torn, C_OUTLINE)
	for i in range(4):
		_rect(img, 10, 11 + i * 3, 10 - i, 1, C_PAPER_DARK)
	_rect(img, 10, 11, 6, 1, C_OUTLINE)
	_disc(img, 12, 14, 2, C_OUTLINE)
	_disc(img, 19, 14, 2, C_OUTLINE)
	_rect(img, 12, 16, 1, 3, C_GLASS)
	_ring(img, 5, 12, 2, 1, C_METAL)
	_ring(img, 27, 10, 2, 1, C_METAL)
	_ring(img, 25, 25, 2, 1, C_METAL)
	return _tex(img)

## "Possessed Copier Portal": copier spewing a column of violet light.
static func copier_portal() -> Texture2D:
	var img := _canvas(48, 48)
	_disc(img, 24, 40, 18, C_SHADOW)
	_rect(img, 17, 4, 14, 24, C_VIOLET_DARK)
	_rect(img, 20, 4, 8, 26, C_VIOLET)
	_rect(img, 22, 6, 4, 24, C_VIOLET_HOT)
	_rect(img, 8, 26, 32, 16, C_COPIER)
	_frame(img, 8, 26, 32, 16, C_OUTLINE)
	_rect(img, 12, 22, 24, 4, C_METAL)
	_frame(img, 12, 22, 24, 4, C_OUTLINE)
	_rect(img, 20, 18, 8, 4, C_PAPER)
	for i in range(4):
		_rect(img, 11 + i * 7, 30, 3, 1, C_VIOLET)
		_rect(img, 11 + i * 7, 33, 3, 1, C_VIOLET)
	_disc(img, 14, 37, 2, C_BLOOD)
	_rect(img, 10, 42, 5, 3, C_METAL_DARK)
	_rect(img, 33, 42, 5, 3, C_METAL_DARK)
	return _tex(img)

# --- Effects and pickups -----------------------------------------------------

## Player's holy-water bolt.
static func holy_bolt() -> Texture2D:
	var img := _canvas(12, 12)
	_disc(img, 6, 6, 4, C_CROSS)
	_disc(img, 6, 6, 2, C_CROSS_HOT)
	return _tex(img)

## Enemy projectile (violet hex bolt).
static func hex_bolt() -> Texture2D:
	var img := _canvas(12, 12)
	_disc(img, 6, 6, 4, C_VIOLET_DARK)
	_disc(img, 6, 6, 2, C_VIOLET_HOT)
	return _tex(img)

## Holy ground / aura puddle used by radius spells.  `radius` is in pixels.
static func aura(radius: int, c: Color) -> Texture2D:
	var d := radius * 2
	var img := _canvas(d, d)
	_disc(img, radius, radius, radius - 1, Color(c.r, c.g, c.b, 0.30))
	_ring(img, radius, radius, radius - 1, 2, c)
	return _tex(img)

## A single collected saint soul (XP pickup).
static func soul_orb() -> Texture2D:
	var img := _canvas(12, 12)
	_disc(img, 6, 6, 5, C_CROSS)
	_disc(img, 6, 6, 3, C_CROSS_HOT)
	_px(img, 6, 4, C_OUTLINE)
	return _tex(img)

## Orbiting censer (spell 7).
static func censer() -> Texture2D:
	var img := _canvas(16, 16)
	_disc(img, 8, 10, 5, C_METAL)
	_ring(img, 8, 10, 5, 1, C_OUTLINE)
	_disc(img, 8, 5, 3, C_STOLE)
	_disc(img, 8, 3, 2, C_VIOLET)
	return _tex(img)

# --- Ability bar icons (keys 1..0) ------------------------------------------

## Flat 24x24 icon for a spell slot.  Shapes mirror the spell's area of effect.
static func spell_icon(spell_id: int) -> Texture2D:
	var img := _canvas(24, 24)
	var gold := C_CROSS
	match spell_id:
		1:
			_ring(img, 12, 12, 9, 2, gold)
			_ring(img, 12, 12, 5, 2, C_STOLE)
		2:
			_ring(img, 12, 12, 9, 2, gold)
			_disc(img, 12, 12, 3, gold)
		3:
			_ring(img, 12, 12, 8, 2, C_STOLE)
			_disc(img, 12, 12, 3, C_BLOOD)
		4:
			_rect(img, 3, 10, 18, 4, gold)
			_rect(img, 18, 8, 4, 8, C_VIOLET_HOT)
		5:
			_ring(img, 12, 12, 6, 2, gold)
			_rect(img, 11, 2, 2, 8, gold)
		6:
			_line(img, 4, 4, 12, 12, gold)
			_line(img, 12, 12, 20, 6, gold)
			_disc(img, 12, 12, 2, C_VIOLET_HOT)
		7:
			_disc(img, 12, 12, 3, C_METAL)
			_ring(img, 12, 12, 9, 1, C_STOLE)
		8:
			_line(img, 3, 18, 20, 5, gold)
			_disc(img, 20, 5, 2, C_CROSS_HOT)
		9:
			_ring(img, 12, 12, 9, 2, C_GLASS)
			_disc(img, 12, 12, 4, Color(0.6, 0.85, 1.0, 0.5))
		0:
			_rect(img, 11, 2, 2, 20, C_BLOOD)
			_rect(img, 3, 11, 18, 2, C_BLOOD)
			_disc(img, 12, 12, 3, C_CROSS_HOT)
		_:
			_ring(img, 12, 12, 7, 2, C_METAL_DARK)
	return _tex(img)
