extends Node
## Meta-progression singleton (Autoload: Meta).  ROADMAP Stage 4 (optional).
##
## Stores what carries over between runs -- currently the set of unlocked spell
## ids -- in user://meta.cfg.  It is deliberately independent of a run: nothing
## writes to it yet, but the API is final, so a later "spend souls on a permanent
## unlock" screen only has to call unlock_spell().

const PATH := "user://meta.cfg"

## Spell ids unlocked before any meta progress (GDD: the first three are free).
const DEFAULT_UNLOCKED: Array[int] = [1, 2, 3]

var unlocked_spells: Array[int] = []

func _ready() -> void:
	load_meta()

## Reads user://meta.cfg (if present), falling back to the defaults.
func load_meta() -> void:
	unlocked_spells = DEFAULT_UNLOCKED.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		var stored: Variant = cfg.get_value("progress", "unlocked_spells", null)
		if stored is Array:
			unlocked_spells.clear()
			for id in stored:
				unlocked_spells.append(int(id))

## Writes the current unlocks back to disk.
func save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked_spells", unlocked_spells)
	cfg.save(PATH)

## True when a spell id (GDD numbering) is permanently unlocked.
func is_unlocked(spell_id: int) -> bool:
	return unlocked_spells.has(spell_id)

## Unlocks a spell id (no-op if already unlocked) and persists immediately.
func unlock_spell(spell_id: int) -> void:
	if unlocked_spells.has(spell_id):
		return
	unlocked_spells.append(spell_id)
	save_meta()

## How many spells are permanently unlocked.
func unlocked_count() -> int:
	return unlocked_spells.size()

## Restores the default three-spell loadout and persists it.
func reset() -> void:
	unlocked_spells = DEFAULT_UNLOCKED.duplicate()
	save_meta()
