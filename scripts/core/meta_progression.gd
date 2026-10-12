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

## Pre-run terminal perk; applied once on run start (session-scoped).
var starting_perk := ""

## --- NG+ loop (GDD_ROADMAP §6) ---
## Current NG+ level (0 = first run). Winning bumps it by 1, up to 9.
var ng_level := 0
## Total victories across all runs.
var wins := 0
## Cumulative souls ever collected (loose campaign counter).
var total_souls := 0.0
## Permanent perks chosen after each victory; applied in Player._ready().
var perm_hp_bonus := 0.0
var perm_dmg_mult := 1.0
var perm_speed_mult := 1.0

## --- Soul shop (E4) ---
## Permanent upgrades bought with cumulative souls. Each entry: level purchased.
var meta_upgrades: Dictionary = {}
const UPGRADE_COSTS := {
	"hp": 50,
	"dmg": 40,
	"speed": 40,
	"spell": 100,
}
const UPGRADE_MAX := {
	"hp": 10,
	"dmg": 10,
	"speed": 10,
	"spell": 7,   ## spells 4..0 (7 locked total)
}

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
		ng_level = int(cfg.get_value("campaign", "ng_level", 0))
		wins = int(cfg.get_value("campaign", "wins", 0))
		total_souls = float(cfg.get_value("campaign", "total_souls", 0.0))
		perm_hp_bonus = float(cfg.get_value("campaign", "perm_hp_bonus", 0.0))
		perm_dmg_mult = float(cfg.get_value("campaign", "perm_dmg_mult", 1.0))
		perm_speed_mult = float(cfg.get_value("campaign", "perm_speed_mult", 1.0))
		if cfg.has_section_key("campaign", "meta_upgrades"):
			var stored_up: Variant = cfg.get_value("campaign", "meta_upgrades", {})
			if stored_up is Dictionary:
				meta_upgrades = stored_up

## Writes the current unlocks back to disk.
func save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked_spells", unlocked_spells)
	cfg.set_value("campaign", "ng_level", ng_level)
	cfg.set_value("campaign", "wins", wins)
	cfg.set_value("campaign", "total_souls", total_souls)
	cfg.set_value("campaign", "perm_hp_bonus", perm_hp_bonus)
	cfg.set_value("campaign", "perm_dmg_mult", perm_dmg_mult)
	cfg.set_value("campaign", "perm_speed_mult", perm_speed_mult)
	cfg.set_value("campaign", "meta_upgrades", meta_upgrades)
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

# --- Soul shop API ---------------------------------------------------------

## How many levels of an upgrade the player owns.
func upgrade_level(id: String) -> int:
	return int(meta_upgrades.get(id, 0))

## Cost in souls for the next level of an upgrade (0 = maxed).
func upgrade_cost(id: String) -> int:
	if not UPGRADE_COSTS.has(id):
		return 0
	if upgrade_level(id) >= int(UPGRADE_MAX.get(id, 0)):
		return 0
	return int(UPGRADE_COSTS[id])

## True when the upgrade can be bought right now.
func can_buy(id: String) -> bool:
	return upgrade_cost(id) > 0 and total_souls >= upgrade_cost(id)

## Buys one level of an upgrade with souls. Returns true on success.
func buy_upgrade(id: String) -> bool:
	if not can_buy(id):
		return false
	total_souls -= upgrade_cost(id)
	meta_upgrades[id] = upgrade_level(id) + 1
	if id == "spell":
		## Unlock the next locked spell (GDD numbering 4..9, then 0).
		for sid in [4, 5, 6, 7, 8, 9, 0]:
			if not is_unlocked(sid):
				unlock_spell(sid)
				break
	save_meta()
	return true

## Total souls available to spend.
func souls_available() -> float:
	return total_souls
