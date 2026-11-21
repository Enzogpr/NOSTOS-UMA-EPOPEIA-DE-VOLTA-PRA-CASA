extends Node2D

const FIGHT := preload("res://Ato9_Motim/Gameplay/MutinyFight.gd")
const DASH_RECHARGE_BAR := preload("res://Code/DashRechargeBar.gd")
const HERO := preload("res://Assets/act5_circe/battle/odysseus_directions.png")
const CREW := preload("res://Assets/act4_friends/crew_poses_v3.png")
const EURY_UNARMED := preload("res://Assets/act4_luck/eurylochus_luck_poses.png")
const BRONZE := Color("f1c588")
const STEEL := Color("ade2e4")
const VIEW := Vector2(1152, 648)

var fight: FIGHT
var dash_bar := DASH_RECHARGE_BAR.new()
var deck_art: Texture2D
var eury_art: Texture2D
var flecks: Array[Dictionary] = []
var clock := 0.0
var pressure := 0.0

func _ready() -> void:
	add_child(dash_bar)
	deck_art = load("res://Assets/act9_mutiny/mutiny_deck.png")
	eury_art = load("res://Assets/act9_mutiny/eurylochus_greatsword.png")

func reset_effects() -> void:
	clock = 0.0
	pressure = 0.0
	flecks.clear()

func update_view(delta: float) -> void:
	dash_bar.update_at(fight.position, fight.dash_recharge, fight.dash_cooldown, fight.phase == FIGHT.Phase.DUEL)
	clock += delta
	pressure = move_toward(pressure, 1.0 if fight.pressured else 0.0, delta * 0.55)
	while not flecks.is_empty() and clock - float(flecks[0].clock) > 0.52:
		flecks.pop_front()
	queue_redraw()

func accent(kind: String) -> void:
	if kind in ["hit", "parry", "clang", "hurt", "disarm"]:
		var at := fight.position.lerp(fight.enemy, 0.58) + Vector2(0, -43)
		flecks.append({"clock": clock, "at": at, "color": STEEL if kind in ["clang", "parry"] else BRONZE})

func _draw() -> void:
	if fight == null or deck_art == null or eury_art == null:
		return
	draw_texture_rect(deck_art, Rect2(Vector2.ZERO, VIEW), false, Color("bbc6c4"))
	_draw_crew()
	_draw_shadow(fight.position)
	_draw_shadow(fight.enemy)
	var enemy_swing := fight.stance == FIGHT.Stance.STRIKE
	var enemy_guard := fight.stance == FIGHT.Stance.WINDUP
	var hero_direction := fight.attack_direction if fight.attack_age >= 0.0 else fight.dash_direction if fight.dash_time > 0.0 else fight.facing
	var hero_tint := Color("ffb8a1") if fight.hit_flash > 0.0 else Color.WHITE
	var enemy_tint := Color("ffd1a2") if fight.enemy_flash > 0.0 else Color("dbe0d4")
	if fight.dash_time > 0.0:
		for index in 3:
			_draw_actor(HERO, fight.position - fight.dash_direction * (13.0 + index * 12.0), hero_direction, true, false, false, false, Color(0.66, 0.83, 0.92, 0.24 - index * 0.057))
	if fight.position.y <= fight.enemy.y:
		_draw_actor(HERO, fight.position, hero_direction, fight.velocity.length() > 17.0, fight.attack_age >= 0.06, fight.guarding, fight.hit_flash > 0.0, hero_tint)
		_draw_enemy(enemy_swing, enemy_guard, enemy_tint)
	else:
		_draw_enemy(enemy_swing, enemy_guard, enemy_tint)
		_draw_actor(HERO, fight.position, hero_direction, fight.velocity.length() > 17.0, fight.attack_age >= 0.06, fight.guarding, fight.hit_flash > 0.0, hero_tint)
	_draw_swords()
	_draw_flecks()

func _draw_crew() -> void:
	for index in 7:
		var progress := pressure * (5.0 + 6.0 * sin(index * 2.1))
		var position := Vector2(250 + index * 107, 238 + progress + sin(clock * 1.8 + index) * 2.3)
		var source := Rect2(158, 614, 462, 640) if index % 2 == 0 else Rect2(749, 615, 352, 635)
		var dims := source.size * (0.14 + (index % 3) * 0.012)
		_draw_shadow(position)
		draw_texture_rect_region(CREW, Rect2(position - Vector2(dims.x * 0.5, dims.y), dims), source, Color(0.35, 0.42, 0.43, 0.8 + pressure * 0.16))

func _draw_enemy(swing: bool, guard: bool, tint: Color) -> void:
	if fight.phase != FIGHT.Phase.DISARMED:
		_draw_actor(eury_art, fight.enemy, fight.enemy_facing, fight.enemy_velocity.length() > 15.0, swing, guard, fight.enemy_flash > 0.0, tint)
		return
	var sword := fight.enemy + Vector2(33.0, 8.0)
	var axis := Vector2.from_angle(0.38)
	draw_line(sword - axis * 17.0, sword + axis * 48.0, Color("2c241a"), 7.0, true)
	var crossguard := axis.orthogonal()
	var blade := PackedVector2Array([sword - crossguard * 3.0, sword + crossguard * 3.0,
		sword + axis * 42.0 + crossguard * 1.7, sword + axis * 51.0, sword + axis * 42.0 - crossguard * 1.7])
	draw_colored_polygon(blade, Color("b6c1c3"))
	draw_line(sword - crossguard * 9.0, sword + crossguard * 9.0, Color("ae7f4c"), 3.0, true)
	var mirror := -1.0 if fight.enemy_facing.x < 0.0 else 1.0
	draw_set_transform(fight.enemy, -0.12 * mirror, Vector2(mirror, 1.0))
	draw_texture_rect_region(EURY_UNARMED, Rect2(-35, -98, 70, 101), Rect2(1067, 517, 326, 481), Color("c9c2a9"))
	draw_set_transform(Vector2.ZERO)

func _draw_shadow(at: Vector2) -> void:
	draw_set_transform(at, 0.0, Vector2(1, 0.34))
	draw_circle(Vector2.ZERO, 27, Color(0.025, 0.042, 0.05, 0.46))
	draw_set_transform(Vector2.ZERO)

func _draw_actor(texture: Texture2D, at: Vector2, direction: Vector2, moving: bool, attacking: bool, guarding: bool, staggering: bool, tint: Color) -> void:
	var row := 1 if direction.y < -0.58 else 0 if direction.y > 0.58 else 2
	var flip := direction.x < 0.0 and row == 2
	var frame: int = [0, 1, 0, 2][posmod(int(clock * 12), 4)] if moving else 0
	if attacking:
		frame = 3
	if guarding:
		frame = row
		row = 3
	if staggering:
		row = 3
		frame = 3
		flip = direction.x < 0.0
	var cell := texture.get_size() / 4.0
	var eury := texture == eury_art
	var foot := float([0.89, 0.89, 0.85, 0.84][row]) if eury else 0.97
	var size := 135.0 if eury else 111.0
	var lean := 0.0
	if eury and attacking:
		var progress := clampf(fight.stance_age / 0.21, 0.0, 1.0)
		lean = direction.x * sin(progress * PI) * (0.17 if fight.pattern == 2 else 0.10)
	draw_set_transform(at, lean, Vector2(-1.0 if flip else 1.0, 1.0))
	draw_texture_rect_region(texture, Rect2(-size * 0.5, -size * foot, size, size), Rect2(Vector2(frame, row) * cell, cell), tint)
	draw_set_transform(Vector2.ZERO)

func _draw_swords() -> void:
	if fight.attack_age >= 0.10 and fight.attack_age < 0.29:
		var fraction := (fight.attack_age - 0.10) / 0.19
		var angle := fight.attack_direction.angle() + fraction * 1.45 - 0.84
		var at := fight.position - Vector2(0, 27)
		draw_arc(at, FIGHT.SWORD_REACH, angle - 0.36, angle + 0.42, 20, Color(BRONZE, (1.0 - fraction) * 0.75), 3.3, true)
	if fight.stance == FIGHT.Stance.STRIKE:
		var spec: Dictionary = FIGHT.ATTACKS[fight.pattern]
		var fraction := clampf(fight.stance_age / 0.21, 0.0, 1.0)
		var at := fight.enemy - Vector2(0, 35)
		var fade := 1.0 - fraction
		var reach := float(spec.range)
		if spec.kind == "thrust":
			var side := fight.enemy_facing.orthogonal()
			var tip := at + fight.enemy_facing * reach
			var base := at + fight.enemy_facing * 55.0
			draw_colored_polygon(PackedVector2Array([base - side * 5.0, tip, base + side * 5.0]), Color(STEEL, fade * 0.26))
			draw_line(base, tip, Color(STEEL, fade * 0.78), 2.5, true)
		else:
			var angle := fight.enemy_facing.angle() + lerpf(-spec.angle, spec.angle, smoothstep(0.0, 0.78, fraction))
			var tail := angle - (0.76 if spec.kind == "sweep" else 0.48)
			draw_arc(at, reach - 4.0, tail, angle + 0.29, 24, Color(STEEL, fade * 0.25), 9.0, true)
			draw_arc(at, reach, tail, angle + 0.29, 24, Color(STEEL, fade * 0.76), 2.6, true)
	elif fight.stance == FIGHT.Stance.WINDUP:
		# A reflection runs along the raised sword as he commits his weight.
		var blade := fight.enemy + fight.enemy_facing * 32.0 - Vector2(0, 56)
		var glow := smoothstep(0.1, 0.48, fight.stance_age)
		draw_circle(blade, 2.3 + glow * 2.3, Color(BRONZE, glow * 0.77))
		draw_line(blade - Vector2(7, 0), blade + Vector2(7, 0), Color(BRONZE, glow * 0.51), 1.6, true)
	if fight.guarding:
		var direction := fight.facing.angle()
		draw_arc(fight.position - Vector2(0, 29), 43, direction - 0.54, direction + 0.54, 16, Color(STEEL, 0.32 + fight.guard / 250.0), 2.0, true)

func _draw_flecks() -> void:
	for event in flecks:
		var age := clock - float(event.clock)
		var fade := 1.0 - age / 0.52
		for index in 11:
			var direction := Vector2.from_angle(index * TAU / 11.0 + 0.26)
			var point: Vector2 = event.at + direction * (9.0 + age * (76.0 + index % 4 * 22.0))
			draw_line(point, point + direction * fade * 9.0, Color(event.color, fade), 2.0, true)
