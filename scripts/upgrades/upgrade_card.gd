class_name UpgradeCard
## One selectable reward on the level-up screen (GDD section 6).
##
## A card is data plus an apply() callback, so the pool stays declarative and the
## UI never needs to know what a reward actually does.
extends RefCounted

var title := ""
var description := ""
var accent := Color("#ffe9a8")
var _apply: Callable

func _init(p_title: String, p_description: String, p_accent: Color, p_apply: Callable) -> void:
	title = p_title
	description = p_description
	accent = p_accent
	_apply = p_apply

## Applies the reward to the live player node.
func apply(player: Node) -> void:
	if _apply.is_valid():
		_apply.call(player)
