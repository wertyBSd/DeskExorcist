class_name UpgradePool
## Builds the pool of level-up rewards (GDD section 6).
##
## Three families of cards keep the roguelike choice interesting past the point
## where every spell is unlocked:
##   - stat cards   scale the caster (health, speed, damage, souls...);
##   - build cards  add projectile behaviour (extra bolts, pierce, regen...);
##   - unlock cards open a locked spell.
## Each call returns a fresh array so the level-up screen can shuffle and slice
## it safely.

static func build(player: Node) -> Array[UpgradeCard]:
	var cards: Array[UpgradeCard] = []
	_add_stat_cards(cards)
	_add_build_cards(cards)
	_add_unlocks(cards, player)
	return cards

# --- Stat cards --------------------------------------------------------------

static func _add_stat_cards(cards: Array[UpgradeCard]) -> void:
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
		"+4 м к радиусу сбора душ.",
		Color("#fff2b0"),
		func(p: Player) -> void:
			p.pickup_radius += 4.0
	))

# --- Build cards (new in ROADMAP Stage C) ------------------------------------

static func _add_build_cards(cards: Array[UpgradeCard]) -> void:
	cards.append(UpgradeCard.new(
		"Быстрые Уста",
		"−15% ко времени восстановления всех заклинаний.",
		Color("#ffd166"),
		func(p: Player) -> void:
			p.cooldown_multiplier *= 0.85
	))
	cards.append(UpgradeCard.new(
		"Двойной Залп",
		"+1 святой болт в залпе (веером).",
		Color("#ffe9a8"),
		func(p: Player) -> void:
			p.projectile_count += 1
	))
	cards.append(UpgradeCard.new(
		"Пронизывающий Свет",
		"Святые болты пробивают +1 врага насквозь.",
		Color("#fff3c4"),
		func(p: Player) -> void:
			p.projectile_pierce += 1
	))
	cards.append(UpgradeCard.new(
		"Благодать",
		"Восстанавливает 1.5 HP в секунду.",
		Color("#9fe8ff"),
		func(p: Player) -> void:
			p.regen += 1.5
	))
	cards.append(UpgradeCard.new(
		"Жажда Душ",
		"+40% к наполнению шкалы душ (быстрее ульта).",
		Color("#ffe9a8"),
		func(p: Player) -> void:
			p.soul_gain_multiplier *= 1.4
	))
	cards.append(UpgradeCard.new(
		"Поступь Паломника",
		"Ещё +10% к скорости и +1 м к сбору душ.",
		Color("#bde3ff"),
		func(p: Player) -> void:
			p.move_speed *= 1.10
			p.pickup_radius += 1.0
	))
	cards.append(UpgradeCard.new(
		"Несокрушимость",
		"+40 к максимальному здоровью.",
		Color("#9fe8ff"),
		func(p: Player) -> void:
			p.max_health += 40.0
			p.health += 40.0
	))
	# Cursed bargain: a big damage spike at the cost of speed.
	cards.append(UpgradeCard.new(
		"Кровавый Обет",
		"+35% к урону, но −10% к скорости передвижения.",
		Color("#e0567a"),
		func(p: Player) -> void:
			p.damage_multiplier *= 1.35
			p.move_speed *= 0.90
	))

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
