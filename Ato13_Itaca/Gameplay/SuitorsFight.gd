extends RefCounted

signal cue(kind: StringName)
signal phase_changed

enum Phase { READY, BOW, FIGHT, BREATH, EPILOGUE, WON, LOST }
enum Role { SWORD, SHIELD, BOW, LEADER }
enum State { SEEK, DRAW, REST, STAGGER, DOWN }

const ARENA := Rect2(125, 257, 904, 289)
const START := Vector2(223, 435)
const BOW_ORIGIN := Vector2(218, 384)
const SWORD_REACH := 143.0
const CELL := 24
const PILLARS := [
	Rect2(331, 323, 68, 35), Rect2(753, 323, 68, 35),
	Rect2(331, 482, 68, 35), Rect2(753, 482, 68, 35),
]
const SPAWNS := [
	Vector2(941, 285), Vector2(949, 514), Vector2(578, 288),
	Vector2(577, 528), Vector2(223, 286), Vector2(250, 525),
]
# Role, spawn point, maximum health.
const ROUNDS := [
	[Vector3i(Role.SWORD, 0, 6), Vector3i(Role.SWORD, 3, 6), Vector3i(Role.BOW, 1, 3), Vector3i(Role.SWORD, 4, 6)],
	[Vector3i(Role.SHIELD, 2, 8), Vector3i(Role.BOW, 0, 4), Vector3i(Role.SWORD, 3, 6), Vector3i(Role.SHIELD, 1, 8), Vector3i(Role.SWORD, 4, 6)],
	[Vector3i(Role.LEADER, 2, 12), Vector3i(Role.SHIELD, 0, 8), Vector3i(Role.SWORD, 1, 6), Vector3i(Role.SWORD, 4, 6), Vector3i(Role.BOW, 3, 4), Vector3i(Role.SWORD, 5, 6)],
]
const END_TIME := 9.5
const BOW_REVEAL_TIME := 1.75

class Fighter:
	var role: Role
	var slot: int
	var position: Vector2
	var velocity := Vector2.ZERO
	var facing := Vector2.LEFT
	var direction := Vector2.LEFT
	var hp: int
	var max_hp: int
	var state := State.SEEK
	var age := 0.0
	var wait := 0.0
	var route: PackedVector2Array
	var route_index := 1
	var route_delay := 0.0
	var flash := 0.0
	var follow_up := false

class Arrow:
	var position: Vector2
	var direction: Vector2
	var age := 0.0

var phase := Phase.READY
var phase_age := 0.0
var clock := 0.0
var wave := 0
var checkpoint := -1
var checkpoint_hp := 10
var checkpoint_position := START
var entry_hp := 10
var max_hp := 10
var hp := 10
var damage := 3
var speed := 1.0
var dash_cooldown := 3.0
var position := START
var velocity := Vector2.ZERO
var facing := Vector2.RIGHT
var movement := Vector2.ZERO
var aim := Vector2.RIGHT
var guard := false
var guard_broken := false
var guard_age := 0.0
var guard_stamina := 1.0
var attack_age := -1.0
var attack_direction := Vector2.RIGHT
var attack_connected := false
var dash_left := 0.0
var dash_recharge := 0.0
var dash_direction := Vector2.RIGHT
var dash_connected := false
var invulnerability := 0.0
var flash := 0.0
var bow_draw := 0.0
var drawing := false
var bow_direction := Vector2.RIGHT
var bow_age := -1.0
var bow_passed := false
var bow_stop := 0.0
var bow_victory_age := -1.0
var fighters: Array[Fighter] = []
var arrows: Array[Arrow] = []
var navigation := AStarGrid2D.new()

func _init() -> void:
	navigation.region = Rect2i(0, 0, 48, 27)
	navigation.cell_size = Vector2(CELL, CELL)
	navigation.offset = Vector2.ONE * CELL * 0.5
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for y in navigation.region.size.y:
		for x in navigation.region.size.x:
			var id := Vector2i(x, y)
			var at := navigation.get_point_position(id)
			if not ARENA.has_point(at) or not clear_segment(at, at, 13):
				navigation.set_point_solid(id)

func apply_stats(stats: Dictionary) -> void:
	max_hp = int(stats.max_hp)
	entry_hp = clampi(int(stats.current_hp), 0, max_hp)
	damage = int(stats.damage)
	speed = float(stats.speed_mult)
	dash_cooldown = float(stats.dash_cooldown)
	if phase == Phase.READY:
		hp = entry_hp
	else:
		hp = mini(hp, max_hp)
		checkpoint_hp = mini(checkpoint_hp, max_hp)

func start() -> void:
	checkpoint = -1
	checkpoint_hp = entry_hp
	retry()

func retry() -> void:
	hp = checkpoint_hp
	guard_stamina = 1.0
	invulnerability = 0.0
	flash = 0.0
	dash_left = 0.0
	dash_recharge = 0.0
	attack_age = -1.0
	velocity = Vector2.ZERO
	facing = Vector2.RIGHT
	guard = false
	guard_broken = false
	arrows.clear()
	if hp <= 0:
		_enter(Phase.LOST)
	elif checkpoint < 0:
		position = BOW_ORIGIN
		drawing = false
		bow_draw = 0.0
		bow_age = -1.0
		bow_stop = 0.0
		bow_passed = false
		bow_victory_age = -1.0
		_enter(Phase.BOW)
	else:
		position = checkpoint_position
		_spawn_round(checkpoint)

func _enter(next: Phase) -> void:
	phase = next
	phase_age = 0.0
	phase_changed.emit()

func ring_at(index: int) -> Vector2:
	return Vector2(304 + index * 48, 377.0 - index * 4.2)

func set_input(axis: Vector2, look_at: Vector2, wants_guard: bool) -> void:
	movement = axis.limit_length(1.0)
	var origin := BOW_ORIGIN if phase == Phase.BOW else position
	if look_at.distance_to(origin) > 3.0:
		aim = origin.direction_to(look_at)
	if not wants_guard:
		guard_broken = false
	if wants_guard and attack_age >= 0.21:
		attack_age = -1.0
	if wants_guard and not guard and not guard_broken:
		guard_age = 0.0
	guard = wants_guard and not guard_broken and guard_stamina >= 0.06 and attack_age < 0.0

func attack_down() -> void:
	if phase == Phase.BOW and bow_age < 0.0 and bow_victory_age < 0.0:
		drawing = true
		bow_draw = 0.0
	elif phase == Phase.FIGHT and attack_age < 0.0 and dash_left <= 0.0 and not guard:
		attack_age = 0.0
		attack_direction = aim
		facing = aim
		attack_connected = false
		cue.emit(&"sword")

func attack_up() -> void:
	if phase != Phase.BOW or not drawing:
		return
	drawing = false
	if bow_draw < 0.31:
		cue.emit(&"weak_bow")
		return
	bow_direction = aim
	bow_age = 0.0
	bow_stop = 758.0 if aim.x > 0.0 else 210.0
	bow_passed = aim.x > 0.0
	for index in 12:
		if not bow_passed:
			break
		var ring := ring_at(index) - BOW_ORIGIN
		if absf(ring.y - ring.x * aim.y / aim.x) > 14.0:
			bow_stop = ring.length()
			bow_passed = false
	cue.emit(&"bow")

func dash() -> void:
	if phase != Phase.FIGHT or dash_recharge > 0.0:
		return
	dash_left = 0.19
	dash_recharge = dash_cooldown
	dash_direction = aim if movement == Vector2.ZERO else movement.normalized()
	facing = dash_direction
	attack_age = -1.0
	dash_connected = false
	cue.emit(&"dash")

func tick(delta: float) -> void:
	clock += delta
	phase_age += delta
	match phase:
		Phase.BOW:
			if bow_victory_age >= 0.0:
				bow_victory_age += delta
				if bow_victory_age >= BOW_REVEAL_TIME:
					checkpoint_position = START
					position = START
					checkpoint_hp = hp
					_spawn_round(0)
					cue.emit(&"entry")
				return
			if drawing:
				bow_draw = minf(0.72, bow_draw + delta)
			if bow_age >= 0.0:
				bow_age += delta
				if bow_age * 1040.0 >= bow_stop:
					bow_age = -1.0
					if bow_passed:
						bow_victory_age = 0.0
						cue.emit(&"hit")
					else:
						cue.emit(&"miss")
		Phase.FIGHT:
			_combat(delta)
		Phase.BREATH:
			guard_stamina = minf(1.0, guard_stamina + delta * 0.46)
			dash_recharge = maxf(0.0, dash_recharge - delta)
			for fighter in fighters:
				fighter.age += delta
			if phase_age >= 2.4:
				_spawn_round(wave + 1)
		Phase.EPILOGUE:
			if phase_age >= END_TIME:
				_enter(Phase.WON)

func _spawn_round(index: int) -> void:
	wave = index
	checkpoint = index
	fighters.clear()
	arrows.clear()
	for order in ROUNDS[wave].size():
		var spec: Vector3i = ROUNDS[wave][order]
		var fighter := Fighter.new()
		fighter.role = spec.x as Role
		fighter.slot = spec.y
		fighter.position = SPAWNS[spec.y]
		if fighter.position.distance_to(position) < 132.0:
			fighter.position = SPAWNS[(spec.y + 3) % SPAWNS.size()]
		fighter.hp = spec.z
		fighter.max_hp = spec.z
		fighter.wait = 0.32 + order * 0.31
		fighters.append(fighter)
	_enter(Phase.FIGHT)

func clear_segment(from: Vector2, to: Vector2, padding: float = 0.0) -> bool:
	for pillar: Rect2 in PILLARS:
		var rect := pillar.grow(padding)
		if rect.has_point(from) or rect.has_point(to):
			return false
		if Geometry2D.segment_intersects_segment(from, to, rect.position, Vector2(rect.end.x, rect.position.y)) != null:
			return false
		if Geometry2D.segment_intersects_segment(from, to, rect.end, Vector2(rect.end.x, rect.position.y)) != null:
			return false
		if Geometry2D.segment_intersects_segment(from, to, rect.position, Vector2(rect.position.x, rect.end.y)) != null:
			return false
		if Geometry2D.segment_intersects_segment(from, to, rect.end, Vector2(rect.position.x, rect.end.y)) != null:
			return false
	return true

func _slide(at: Vector2, offset: Vector2, padding: float) -> Vector2:
	for step: Vector2 in [Vector2(offset.x, 0), Vector2(0, offset.y)]:
		var destination := (at + step).clamp(ARENA.position, ARENA.end)
		if clear_segment(at, destination, padding):
			at = destination
	return at

func _combat(delta: float) -> void:
	if hp <= 0:
		_enter(Phase.LOST)
		return
	dash_recharge = maxf(0.0, dash_recharge - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	flash = maxf(0.0, flash - delta)
	guard_age += delta
	if not guard:
		guard_stamina = minf(1.0, guard_stamina + delta * 0.46)
	if attack_age < 0.0 and dash_left <= 0.0:
		facing = aim
	var desired := movement * 280.0 * speed
	if guard: desired *= 0.56
	if attack_age >= 0.0: desired *= 0.57
	velocity = velocity.move_toward(desired, delta * 2440.0)
	if dash_left > 0.0:
		velocity = dash_direction * 795.0
	var offset := velocity * delta
	if dash_left <= 0.0:
		for fighter in fighters:
			if fighter.hp > 0 and fighter.position.distance_to(position + offset) < 37.0:
				var normal := fighter.position.direction_to(position)
				if offset.dot(normal) < 0.0:
					offset = offset.slide(normal)
	position = _slide(position, offset, 12)
	if dash_left > 0.0:
		if not dash_connected:
			_dash_contact()
		dash_left = maxf(0.0, dash_left - delta)
	if attack_age >= 0.0:
		attack_age += delta
		if attack_age >= 0.11 and not attack_connected:
			attack_connected = true
			_swing()
		if attack_age >= 0.40:
			attack_age = -1.0
	for fighter in fighters:
		_fighter_tick(fighter, delta)
		if phase != Phase.FIGHT:
			return
	_arrows_tick(delta)
	if phase == Phase.FIGHT and remaining() == 0:
		arrows.clear()
		guard = false
		velocity = Vector2.ZERO
		attack_age = -1.0
		dash_left = 0.0
		if wave == ROUNDS.size() - 1:
			_enter(Phase.EPILOGUE)
			cue.emit(&"silence")
		else:
			checkpoint_position = position
			checkpoint_hp = hp
			checkpoint = wave + 1
			_enter(Phase.BREATH)

func remaining() -> int:
	var alive := 0
	for fighter in fighters:
		if fighter.hp > 0:
			alive += 1
	return alive

func _swing() -> void:
	for fighter in fighters:
		var offset := fighter.position - position
		if fighter.hp <= 0 or offset.length() > SWORD_REACH or offset.normalized().dot(attack_direction) < 0.44:
			continue
		if not clear_segment(position, fighter.position):
			continue
		if fighter.role == Role.SHIELD and fighter.state == State.SEEK and fighter.facing.dot(-offset.normalized()) > 0.24:
			cue.emit(&"block")
			continue
		fighter.hp = maxi(0, fighter.hp - damage)
		fighter.flash = 0.22
		_set_fighter(fighter, State.STAGGER if fighter.hp > 0 else State.DOWN)
		cue.emit(&"hit")

func _dash_contact() -> void:
	for fighter in fighters:
		if fighter.hp <= 0 or fighter.position.distance_to(position) > 45.0:
			continue
		if dash_direction.dot(position.direction_to(fighter.position)) > 0.12 and clear_segment(position, fighter.position):
			_set_fighter(fighter, State.STAGGER)
			dash_connected = true
			cue.emit(&"block")
			return

func _set_fighter(fighter: Fighter, next: State) -> void:
	fighter.state = next
	fighter.age = 0.0
	if next == State.SEEK:
		fighter.route_delay = 0.0
		fighter.wait = 0.32
		fighter.follow_up = false

func windup(fighter: Fighter) -> float:
	match fighter.role:
		Role.BOW: return 0.72
		Role.SHIELD: return 0.71
		Role.LEADER: return 0.50
		_: return 0.49

func _fighter_tick(fighter: Fighter, delta: float) -> void:
	fighter.age += delta
	fighter.flash = maxf(0.0, fighter.flash - delta)
	fighter.velocity = Vector2.ZERO
	match fighter.state:
		State.DOWN:
			return
		State.STAGGER:
			if fighter.age >= 0.83: _set_fighter(fighter, State.SEEK)
		State.REST:
			if fighter.role == Role.BOW and fighter.age < 0.82:
				var cover := _cover_near(fighter.position)
				if cover.distance_to(fighter.position) > 9.0:
					_move_fighter(fighter, cover, delta)
			if fighter.age >= (1.0 if fighter.role == Role.BOW else 0.70):
				_set_fighter(fighter, State.SEEK)
		State.DRAW:
			if fighter.age >= windup(fighter):
				_enemy_attack(fighter)
				if fighter.state == State.DRAW:
					if fighter.role == Role.LEADER and not fighter.follow_up:
						fighter.follow_up = true
						fighter.age = windup(fighter) - 0.33
						fighter.direction = fighter.position.direction_to(position)
					else:
						_set_fighter(fighter, State.REST)
		State.SEEK:
			_seek(fighter, delta)

func _seek(fighter: Fighter, delta: float) -> void:
	fighter.wait = maxf(0.0, fighter.wait - delta)
	var distance := fighter.position.distance_to(position)
	var sees_player := clear_segment(fighter.position, position, 6)
	var ranged := fighter.role == Role.BOW
	var range_limit := 535.0 if ranged else (102.0 if fighter.role == Role.LEADER else 82.0)
	var active_melee := 0
	if not ranged:
		for other in fighters:
			if other.state == State.DRAW and other.role != Role.BOW:
				active_melee += 1
	if distance <= range_limit and sees_player and fighter.wait == 0.0 and active_melee < 2:
		fighter.direction = fighter.position.direction_to(position)
		fighter.facing = fighter.direction
		_set_fighter(fighter, State.DRAW)
		return
	var target := position
	if ranged and distance < 194.0:
		target = fighter.position + position.direction_to(fighter.position) * 160.0
	elif ranged and not sees_player:
		var side := -1.0 if fighter.slot % 2 == 0 else 1.0
		target = Vector2(fighter.position.x, clampf(position.y + side * 100.0, 267.0, 535.0))
		if fighter.position.distance_to(target) < 32.0:
			target = position
	elif fighter.role == Role.SWORD and distance > 126.0 and distance < 335.0:
		var side := -1.0 if fighter.slot % 2 == 0 else 1.0
		target += Vector2(0, side * 86.0)
	_move_fighter(fighter, target, delta)

func _cover_near(at: Vector2) -> Vector2:
	var nearest := at
	var distance := 280.0
	for pillar: Rect2 in PILLARS:
		var center := pillar.get_center()
		var away := position.direction_to(center)
		var candidate := center + away * 65.0
		if ARENA.has_point(candidate) and at.distance_to(candidate) < distance and not clear_segment(position, candidate):
			nearest = candidate
			distance = at.distance_to(candidate)
	return nearest

func _move_fighter(fighter: Fighter, destination: Vector2, delta: float) -> void:
	var target := destination.clamp(ARENA.position + Vector2.ONE * 6.0, ARENA.end - Vector2.ONE * 6.0)
	if not clear_segment(target, target, 13):
		target = position
	if not clear_segment(fighter.position, target, 13):
		fighter.route_delay -= delta
		if fighter.route_delay <= 0.0:
			var from := Vector2i((fighter.position / CELL).floor())
			var to := Vector2i((target / CELL).floor())
			fighter.route = navigation.get_point_path(from, to, true)
			fighter.route_index = 1
			fighter.route_delay = 0.24
		while fighter.route_index < fighter.route.size() - 1 and fighter.route[fighter.route_index].distance_to(fighter.position) < 15.0:
			fighter.route_index += 1
		if fighter.route_index < fighter.route.size():
			target = fighter.route[fighter.route_index]
	var direction := fighter.position.direction_to(target)
	var separation := Vector2.ZERO
	for other in fighters:
		var offset := fighter.position - other.position
		var gap := offset.length()
		if other != fighter and other.hp > 0 and gap < 48.0 and gap > 0.0:
			separation += offset.normalized() * (1.0 - gap / 48.0)
	var speed_limit: float = [152.0, 115.0, 139.0, 179.0][fighter.role]
	var intent := (direction + separation * 0.92).limit_length(1.0) * speed_limit
	var next := _slide(fighter.position, intent * delta, 11)
	if next.distance_to(position) < 46.0 and next.distance_to(position) < fighter.position.distance_to(position):
		return
	fighter.velocity = (next - fighter.position) / delta
	fighter.position = next
	fighter.facing = fighter.position.direction_to(position)

func _enemy_attack(fighter: Fighter) -> void:
	if fighter.role == Role.BOW:
		var arrow := Arrow.new()
		arrow.position = fighter.position + fighter.direction * 16.0
		arrow.direction = fighter.direction
		arrows.append(arrow)
		cue.emit(&"bow")
	else:
		var reach := 122.0 if fighter.role == Role.LEADER else 104.0
		var offset := position - fighter.position
		cue.emit(&"enemy")
		if offset.length() <= reach and offset.normalized().dot(fighter.direction) > 0.54 and clear_segment(position, fighter.position):
			_hurt(fighter.position, fighter)

func _arrows_tick(delta: float) -> void:
	for index in range(arrows.size() - 1, -1, -1):
		var arrow := arrows[index]
		var next := arrow.position + arrow.direction * 615.0 * delta
		arrow.age += delta
		if not ARENA.grow(8).has_point(next) or not clear_segment(arrow.position, next):
			arrows.remove_at(index)
		elif dash_left <= 0.0 and Geometry2D.get_closest_point_to_segment(position, arrow.position, next).distance_to(position) < 17.0:
			arrows.remove_at(index)
			_hurt(arrow.position - arrow.direction * 31.0)
		else:
			arrow.position = next

func _hurt(source: Vector2, attacker: Fighter = null) -> void:
	if dash_left > 0.0 or invulnerability > 0.0:
		return
	if guard and position.direction_to(source).dot(facing) > 0.17:
		if guard_age < 0.20:
			if attacker != null: _set_fighter(attacker, State.STAGGER)
		else:
			guard_stamina = maxf(0.0, guard_stamina - 0.42)
			if guard_stamina == 0.0:
				guard = false
				guard_broken = true
		invulnerability = 0.16
		cue.emit(&"block")
		return
	hp -= 1
	flash = 0.24
	invulnerability = 0.70
	cue.emit(&"hurt")
	if hp <= 0:
		_enter(Phase.LOST)
