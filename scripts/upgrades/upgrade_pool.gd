class_name UpgradePool
## Builds the pool of level-up rewards (GDD section 6).
##
## Stat cards scale the player; unlock cards flip `is_locked` off a spell so it
## becomes castable from the ability bar.  Each call returns a fresh array so
## the level-up screen can shuffle and slice it safely.
extends RefCounted

static func build(player: Node) -> Array[UpgradeCard]:
	var cards: Array[UpgradeCard] = []
	cards.append(UpgradeCard.new(
		"Крепкая Вера",
		"+25 к максимальному здоровью и полное исцеление.",
		Color("#9fe8ff"),
		func(p: Player) -> void:
			p.max_health += 25.0
			p.health = p.max_health
	))
	cards.append(UpgradeCard.new(
		"Скорость Клирика",
		"+12% к скорости передвижения.",
		Color("#bde3ff"),
		func(p: Player) -> void:
			p.move_speed *= 1.12
	))
	cards.append(UpgradeCard.new(
		"Гнев Праведника",
		"+15% к урону всех атак и заклинаний.",
		Color("#ffd166"),
		func(p: Player) -> void:
			p.damage_multiplier *= 1.15
	))
	cards.append(UpgradeCard.new(
		"Пастырская Забота",
		"+40 к радиусу сбора душ.",
		Color("#fff2b0"),
		func(p: Player) -> void:
			p.pickup_radius += 40.0
	))
	_add_unlocks(cards, player)
	return cards

## Adds a card for every spell that is still locked behind progression.
static func _add_unlocks(cards: Array[UpgradeCard], player: Node) -> void:
	if not (player is Player):
		return
	for spell in (player as Player).spells:
		if not spell.is_locked:
			continue
		var captured: BaseSpell = spell
		cards.append(UpgradeCard.new(
			"Откровение: %s" % captured.display_name,
			"Открывает заклинание «%s» на панели. %s" % [captured.display_name, captured.describe()],
			captured.colour,
			func(_p: Player) -> void:
				captured.is_locked = false
		))
