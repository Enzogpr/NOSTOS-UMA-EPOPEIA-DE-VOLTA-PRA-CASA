extends Node2D

const FIGHT := preload("res://Ato13_Itaca/Gameplay/SuitorsFight.gd")
const DASH_RECHARGE_BAR := preload("res://Code/DashRechargeBar.gd")
const HALL := preload("res://Assets/act13_ithaca/hall.png")
const SUITORS := preload("res://Assets/act13_ithaca/suitors.png")
const ENDING := preload("res://Assets/act13_ithaca/homecoming.png")
const ARCHER := preload("res://Assets/act13_ithaca/odysseus_bow.png")
const ANTINOUS := preload("res://Assets/act13_ithaca/antinous.png")
const HERO := preload("res://Assets/act5_circe/battle/odysseus_directions.png")
const PROPS := preload("res://Assets/act5_circe/battle/palace_props.png")
const VIEW := Vector2(1152, 648)
const GOLD := Color("ffdca0")
const REGIONS := [
	Rect2(62, 73, 503, 505), Rect2(673, 66, 473, 515),
	Rect2(68, 629, 437, 604), Rect2(673, 652, 485, 581),
]

var fight: FIGHT
var dash_bar := DASH_RECHARGE_BAR.new()
var time := 0.0
var clang := 0.0
var reveal := 0.0

func _ready() -> void:
	add_child(dash_bar)

func advance(delta: float) -> void:
	time += delta
	clang = maxf(0.0, clang - delta)
	reveal = maxf(0.0, reveal - delta)
	var active := fight.phase in [FIGHT.Phase.FIGHT, FIGHT.Phase.BREATH]
	dash_bar.update_at(fight.position, fight.dash_recharge, fight.dash_cooldown, active)
	queue_redraw()

func react(kind: StringName) -> void:
	if kind == &"block":
		clang = 0.24
	elif kind == &"entry":
		reveal = 0.55

func _draw() -> void:
	if fight.phase in [FIGHT.Phase.EPILOGUE, FIGHT.Phase.WON]:
		_draw_home()
		return
	var dim := 0.81 if fight.wave == 2 else 0.95
	draw_texture_rect(HALL, Rect2(Vector2.ZERO, VIEW), false, Color(dim, dim * 0.95, dim * 0.91))
	_draw_lamps()
	if fight.phase in [FIGHT.Phase.READY, FIGHT.Phase.BOW]:
		_draw_trial()
	else:
		_draw_combat()
	if reveal > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.29, 0.13, 0.036, reveal * 0.52))
	if fight.flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.63, 0.12, 0.09, fight.flash * 0.53))

func _draw_lamps() -> void:
	for origin: Vector2 in [Vector2(124, 112), Vector2(427, 102), Vector2(751, 103), Vector2(1063, 161)]:
		var flicker := 0.68 + sin(time * 11.0 + origin.x) * 0.15 + sin(time * 17.1) * 0.09
		draw_set_transform(origin, 0.0, Vector2(0.95, 0.65))
		for ring in 4:
			draw_circle(Vector2.ZERO, 22 + ring * 17.0, Color(1.0, 0.62, 0.25, 0.023 * flicker))
		draw_set_transform(Vector2.ZERO)
		for index in 9:
			var cycle := fposmod(time * (0.44 + index * 0.02) + index * 0.24, 1.0)
			var offset := Vector2(sin(index * 3.3 + time) * 14.0 * cycle, -cycle * (58.0 + index % 3 * 12))
			draw_circle(origin + offset, 0.9 + index % 2 * 0.50, Color(GOLD, sin(cycle * PI) * 0.55))

func _draw_trial() -> void:
	var origin := FIGHT.BOW_ORIGIN
	var tension := clampf(fight.bow_draw / 0.72, 0.0, 1.0) if fight.drawing else 0.0
	var passed := fight.bow_victory_age >= 0.0
	var arrow_at := origin + fight.bow_direction * minf(fight.bow_age * 1040.0, fight.bow_stop)
	for index in 12:
		var ring := fight.ring_at(index)
		var glow := (passed or (fight.bow_age >= 0.0 and arrow_at.x > ring.x)) and fight.bow_passed
		_draw_axe(ring, index, glow)
	var leader_at := Vector2(982, 429)
	var fall := smoothstep(0.05, 0.6, fight.bow_victory_age)
	_shadow(leader_at, 30.0, 0.61)
	draw_set_transform(leader_at + Vector2(fall * 21.0, 0), -fall * 1.30)
	_sprite(ANTINOUS, Rect2(168, 2, 650, 1530), Vector2.ZERO, 122.0, Color(0.88, 0.80, 0.72))
	draw_set_transform(Vector2.ZERO)
	_shadow(origin + Vector2(-40, 101), 37.0, 0.54)
	var bounds := Rect2(0, 0, ARCHER.get_width(), ARCHER.get_height())
	_sprite(ARCHER, bounds, origin + Vector2(-41.0 - tension * 6.0, 106), 148.0)
	if fight.drawing:
		var length := lerpf(144.0, 720.0, tension)
		draw_dashed_line(origin, origin + fight.aim * length, Color(GOLD, lerpf(0.13, 0.53, tension)), 1.35, 7.0, true, true)
	if fight.bow_age >= 0.0:
		_draw_arrow(arrow_at, fight.bow_direction, true)

func _draw_axe(ring: Vector2, index: int, lit: bool) -> void:
	var tint := GOLD if lit else Color("b88c55")
	var handle_end := ring + Vector2(0, 53.0 - index * 0.38)
	draw_line(handle_end, handle_end + Vector2(-15, 6), Color("160c14a5"), 4.8, true)
	draw_line(ring + Vector2(-4, 5), handle_end, Color("603b28"), 4.7, true)
	draw_line(ring + Vector2(-5, 4), handle_end + Vector2(-1, 0), Color("a57542"), 1.5, true)
	var blade := PackedVector2Array([ring + Vector2(6, -12), ring + Vector2(22, -16), ring + Vector2(24, -5), ring + Vector2(20, 10), ring + Vector2(6, 8)])
	draw_colored_polygon(blade, Color("776050"))
	draw_polyline(PackedVector2Array([blade[1], blade[2], blade[3]]), Color("c4a782"), 1.4, true)
	draw_set_transform(ring, 0, Vector2(0.72, 1))
	draw_circle(Vector2.ZERO, 8.0, Color("251918cd"))
	draw_arc(Vector2.ZERO, 9.0, 0, TAU, 26, tint, 2.5, true)
	draw_set_transform(Vector2.ZERO)

func _draw_combat() -> void:
	var sorted: Array[Dictionary] = [{"y": fight.position.y, "kind": "hero"}]
	for fighter in fight.fighters:
		sorted.append({"y": fighter.position.y, "kind": "enemy", "fighter": fighter})
	for pillar: Rect2 in FIGHT.PILLARS:
		sorted.append({"y": pillar.end.y, "kind": "pillar", "pillar": pillar})
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.y < b.y)
	for item in sorted:
		match item.kind:
			"hero": _draw_player()
			"enemy": _draw_fighter(item.fighter)
			"pillar": _draw_pillar(item.pillar)
	for arrow in fight.arrows:
		_draw_arrow(arrow.position - Vector2(0, 26), arrow.direction, false)

func _draw_pillar(pillar: Rect2) -> void:
	var base := Vector2(pillar.get_center().x, pillar.end.y)
	_shadow(base + Vector2(10, 2), 49.0, 0.52)
	draw_texture_rect_region(PROPS, Rect2(base - Vector2(38, 150), Vector2(76, 153)), Rect2(1064, 3, 178, 538), Color("ba9a84"))

func _draw_player() -> void:
	var at := fight.position
	var moving := fight.velocity.length() > 16.0
	var direction := fight.facing
	if moving and fight.attack_age < 0.0 and not fight.guard:
		direction = fight.velocity.normalized()
	var row := 1 if direction.y < -0.55 else 0 if direction.y > 0.55 else 2
	var frame: int = [0, 1, 0, 2][posmod(int(time * 11.0), 4)] if moving else 0
	if fight.attack_age >= 0.0:
		frame = 3
	if fight.guard:
		frame = row
		row = 3
	if fight.dash_left > 0.0:
		for index in 6:
			var start := at - fight.dash_direction * (index * 9.0 + 16.0) + Vector2(0, -25 - index * 3.0)
			draw_line(start, start - fight.dash_direction * 39.0, Color(GOLD, 0.24 - index * 0.025), 1.5, true)
	_shadow(at, 23.0, 0.62)
	var cell := HERO.get_size() / 4.0
	draw_set_transform(at, 0, Vector2(-1 if direction.x < 0 and (row == 2 or (row == 3 and frame == 2)) else 1, 1))
	draw_texture_rect_region(HERO, Rect2(-52.5, -105.0, 105.0, 105.0), Rect2(Vector2(frame, row) * cell, cell), Color("efa88c") if fight.flash > 0.0 else Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	if fight.attack_age >= 0.08:
		_slash(at, fight.attack_direction, fight.attack_age / 0.40, FIGHT.SWORD_REACH - 17.0, GOLD)
	if fight.guard:
		var color := GOLD if fight.guard_age < 0.20 else Color("c1a981")
		draw_arc(at - Vector2(0, 34) + fight.facing * 16.0, 31.0, fight.facing.angle() - 0.91, fight.facing.angle() + 0.91, 24, Color(color, 0.59 + clang), 2.0, true)

func _draw_fighter(fighter: FIGHT.Fighter) -> void:
	var at := fighter.position
	var fallen := fighter.state == FIGHT.State.DOWN
	var flip := -1.0 if fighter.facing.x > 0.0 else 1.0
	var height := 114.0 if fighter.role == FIGHT.Role.LEADER else 96.0
	var walk := sin(time * 15.0 + fighter.slot) * 2.2 if fighter.velocity.length() > 12.0 else 0.0
	var tilt := 0.0
	var light := Color.WHITE
	if fighter.role == FIGHT.Role.SWORD and fighter.slot % 2 == 0:
		light = Color("d8b09d")
	if fighter.state == FIGHT.State.DRAW:
		var preparation := clampf(fighter.age / fight.windup(fighter), 0.0, 1.0)
		tilt = -flip * 0.22 * sin(preparation * PI * 0.7)
		at -= fighter.direction * (preparation * 11.0)
		if fighter.follow_up:
			var after_swing := fighter.age - (fight.windup(fighter) - 0.33)
			if after_swing < 0.23:
				_slash(at, fighter.facing, after_swing / 0.23, 65.0, Color("e6b792"))
	elif fighter.state == FIGHT.State.REST and fighter.role != FIGHT.Role.BOW:
		tilt = flip * 0.21 * exp(-fighter.age * 6.0)
		if fighter.age < 0.36:
			_slash(at, fighter.direction, fighter.age / 0.36, 57.0, Color("e6b792"))
	if fighter.flash > 0.0:
		light = Color("ffc296")
	if fallen:
		var fall := smoothstep(0.0, 0.32, fighter.age)
		tilt = flip * fall * 1.37
		light = Color(0.56, 0.50, 0.52, 1.0 - fall * 0.52)
	_shadow(at, 25.0, 0.55)
	draw_set_transform(at + Vector2(0, walk), tilt, Vector2(flip, 1.0))
	_sprite(SUITORS, REGIONS[fighter.role], Vector2.ZERO, height, light)
	draw_set_transform(Vector2.ZERO)
	if not fallen:
		var bar := Vector2(fighter.position.x - 21, fighter.position.y - height - 9)
		draw_rect(Rect2(bar, Vector2(42, 4)), Color("291c23"))
		draw_rect(Rect2(bar, Vector2(42.0 * fighter.hp / fighter.max_hp, 4)), GOLD if fighter.role == FIGHT.Role.LEADER else Color("b96549"))
		if fighter.role == FIGHT.Role.LEADER:
			draw_string(ThemeDB.fallback_font, bar + Vector2(-9, -5), "EURÍMACO", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, GOLD)
		if fighter.role == FIGHT.Role.BOW and fighter.state == FIGHT.State.DRAW:
			_draw_arrow(at + fighter.direction * 24.0 - Vector2(0, 53), fighter.direction, false)

func _slash(at: Vector2, direction: Vector2, progress: float, radius: float, tint: Color) -> void:
	var weight := sin(clampf(progress, 0.0, 1.0) * PI)
	var center := at - Vector2(0, 30) + direction * 17.0
	var angle := direction.angle() + lerpf(-0.42, 0.42, progress)
	draw_arc(center, radius, angle - 0.69, angle + 0.63, 30, Color(tint, weight * 0.78), 3.0, true)
	draw_arc(center, radius + 5.0, angle - 0.58, angle + 0.37, 23, Color(tint, weight * 0.34), 1.3, true)

func _draw_arrow(at: Vector2, direction: Vector2, glowing: bool) -> void:
	var back := at - direction * 27.0
	draw_line(at, back, Color("dfae72"), 2.0, true)
	draw_line(at, at - direction * 7 + direction.orthogonal() * 3, GOLD, 1.8, true)
	draw_line(at, at - direction * 7 - direction.orthogonal() * 3, GOLD, 1.8, true)
	if glowing:
		draw_line(back, back - direction * 39.0, Color(GOLD, 0.45), 1.4, true)

func _draw_home() -> void:
	var age := FIGHT.END_TIME if fight.phase == FIGHT.Phase.WON else fight.phase_age
	var zoom := 1.02 + smoothstep(0.0, FIGHT.END_TIME, age) * 0.033
	draw_texture_rect(ENDING, Rect2(VIEW * (1.0 - zoom) * 0.5, VIEW * zoom), false)
	_draw_lamps()
	var fade := 1.0 - smoothstep(0.0, 1.2, age)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.03, 0.018, 0.027, fade))

func _shadow(at: Vector2, radius: float, alpha: float) -> void:
	draw_set_transform(at + Vector2(2, 2), 0.0, Vector2(1.0, 0.33))
	draw_circle(Vector2.ZERO, radius, Color(0.09, 0.043, 0.047, alpha))
	draw_set_transform(Vector2.ZERO)

func _sprite(texture: Texture2D, region: Rect2, feet: Vector2, height: float, tint := Color.WHITE) -> void:
	var width := height * region.size.x / region.size.y
	draw_texture_rect_region(texture, Rect2(feet - Vector2(width * 0.5, height), Vector2(width, height)), region, tint)
