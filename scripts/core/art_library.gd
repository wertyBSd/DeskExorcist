class_name ArtLibrary
## Loads the generated 2D art (see LEONARDO_PROMPTS.md) and falls back to the
## procedural placeholders when a file is missing.
##
## Built to mirror ModelLibrary: the naming convention in LEONARDO_PROMPTS.md is
## the only contract, so dropping a correctly named file into assets/ui/ is all
## it takes -- no import list, no per-icon wiring in the HUD.
##
## The digit in `spell_<n>.png` is the digit printed on the keycap the player
## sees, which is also the spell_id and the `spell_<n>` input action. It is NOT
## the array index: slot 0 is the key "1".

extends RefCounted

const ICON_DIR := "res://assets/ui/icons/"
const BG_DIR := "res://assets/ui/backgrounds/"

## Path of the icon for a spell id (0..9), matching the keycap convention.
static func spell_icon_path(spell_id: int) -> String:
	return ICON_DIR + "spell_%d.png" % spell_id

static func _menu_background_path() -> String:
	return BG_DIR + "menu.png"

## Generated texture if it exists, otherwise null. Callers decide the fallback
## so a missing file never leaves a hole in the UI.
static func _try_load(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

## True when a generated icon is present (tests use this to prove the file name
## convention is honoured end to end).
static func has_spell_icon(spell_id: int) -> bool:
	return ResourceLoader.exists(spell_icon_path(spell_id))

## True when the generated main-menu backdrop is present. Same contract as
## has_spell_icon: the file name is the whole wiring.
static func has_menu_background() -> bool:
	return ResourceLoader.exists(_menu_background_path())

## Spell icon for the ability bar, or the procedural placeholder.
static func spell_icon(spell_id: int) -> Texture2D:
	var tex := _try_load(spell_icon_path(spell_id))
	if tex != null:
		return tex
	return PlaceholderArt.spell_icon(spell_id)

## Main-menu backdrop, or a procedural one.
static func menu_background() -> Texture2D:
	var tex := _try_load(_menu_background_path())
	if tex != null:
		return tex
	return PlaceholderArt.menu_background()