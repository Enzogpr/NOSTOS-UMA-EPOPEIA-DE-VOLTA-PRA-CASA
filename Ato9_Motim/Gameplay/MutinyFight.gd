extends RefCounted

signal cue(kind: String)

enum Phase { READY, DUEL, LOST, DISARMED }
enum Stance { APPROACH, WINDUP, STRIKE, RECOVERY }

const DECK := Rect2(82, 251, 988, 242)
const RESOLVE_MAX := 15
const TURNING_POINT := 7
const SWORD_REACH := 119.0
const ENEMY_DAMAGE := 2
const ATTACKS := [
	{"kind": "sweep", "windup": 0.69, "angle": 1.27, "range": 144.0, "charge": 109.0},
	{"kind": "thrust", "windup": 0.76, "angle": 0.42, "range": 155.0, "charge": 300.0},
	{"kind": "heavy", "windup": 0.99, "angle": 0.74, "range": 162.0, "charge": 160.0},
]

var phase := Phase.READY
var stance := Stance.APPROACH
var position := Vector2(360, 401)
var enemy := Vector2(796, 394)
var velocity := Vector2.ZERO
var enemy_velocity := Vector2.ZERO
var facing := Vector2.RIGHT
var enemy_facing := Vector2.LEFT
var attack_direction := Vector2.RIGHT
var dash_direction := Vector2.RIGHT
var hp := 10
var max_hp := 10
var entry_hp := 10
var damage := 3
var agility := 1.0
var dash_cooldown := 3.0
var resolve := RESOLVE_MAX
var pressured := false
var clock := 0.0
var stance_age := 0.0
var recovery := 0.0
var pattern := 0
var pattern_index := 0
var contacted := false
var opening_used := false
var second_swing := false
var hit_flash := 0.0
var enemy_flash := 0.0
var guard := 100.0
var guarding := false
var guard_age := 0.0
var guard_break := 0.0
var hit_immunity := 0.0
var attack_age := -1.0
var attack_recharge := 0.0
var dash_time := 0.0
var dash_recharge := 0.0

func apply_attributes(stats: Dictionary) -> void:
	max_hp = int(stats.max_hp)
	hp = mini(hp, max_hp)
	damage = int(stats.damage)
	agility = float(stats.speed_mult)
	dash_cooldown = float(stats.dash_cooldown)
	if phase == Phase.READY:
		entry_hp = int(stats.current_hp)
		hp = entry_hp

func begin() -> void:
	if phase == Phase.READY:
		phase = Phase.DUEL if hp > 0 else Phase.LOST

func restart() -> void:
	phase = Phase.DUEL
	stance = Stance.APPROACH
	position = Vector2(360, 401)
	enemy = Vector2(796, 394)
	velocity = Vector2.ZERO
	enemy_velocity = Vector2.ZERO
	facing = Vector2.RIGHT
	enemy_facing = Vector2.LEFT
	hp = clampi(entry_hp, 1, max_hp)
	resolve = RESOLVE_MAX
	pressured = false
	clock = 0.0
	stance_age = 0.0
	pattern = 0
	pattern_index = 0
	contacted = false
	opening_used = false
	second_swing = false
	hit_flash = 0.0
	enemy_flash = 0.0
	guard = 100.0
	guard_age = 0.0
	guarding = false
	guard_break = 0.0
	hit_immunity = 0.0
	attack_age = -1.0
	attack_recharge = 0.0
	dash_time = 0.0
	dash_recharge = 0.0

func attack(aim: Vector2) -> void:
	if phase != Phase.DUEL or attack_recharge > 0.0 or guarding or dash_time > 0.0 or guard_break > 0.0:
		return
	attack_direction = facing if aim.is_zero_approx() else aim.normalized()
	attack_age = 0.0
	attack_recharge = 0.46
	cue.emit("sword")

func dash(axis: Vector2) -> void:
	if phase != Phase.DUEL or dash_recharge > 0.0 or guard_break > 0.0:
		return
	dash_direction = facing if axis.is_zero_approx() else axis.normalized()
	dash_time = 0.18
	dash_recharge = dash_cooldown
	attack_age = -1.0
	cue.emit("dash")

func tick(delta: float, axis: Vector2, aim: Vector2, wants_guard: bool) -> void:
	if phase != Phase.DUEL:
		return
	clock += delta
	dash_time = maxf(0.0, dash_time - delta)
	dash_recharge = maxf(0.0, dash_recharge - delta)
	attack_recharge = maxf(0.0, attack_recharge - delta)
	guard_break = maxf(0.0, guard_break - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	enemy_flash = maxf(0.0, enemy_flash - delta)
	hit_immunity = maxf(0.0, hit_immunity - delta)
	var was_guarding := guarding
	guarding = wants_guard and guard_break <= 0.0 and attack_age < 0.0 and dash_time <= 0.0
	guard_age = (guard_age + delta if was_guarding else 0.0) if guarding else 0.0
	if not guarding and not wants_guard:
		guard = minf(100.0, guard + delta * 29.0)
	if not aim.is_zero_approx() and attack_age < 0.0:
		facing = aim.normalized()
	var desired := axis.limit_length(1.0) * 236.0 * agility
	if guarding or attack_age >= 0.0:
		desired *= 0.46
	if dash_time > 0.0:
		desired = dash_direction * 630.0
		velocity = desired
	else:
		velocity = velocity.move_toward(desired, delta * 1820.0)
	position = _walk(position + velocity * delta, enemy, 33.0)
	_tick_enemy(delta)
	if phase == Phase.DUEL:
		_tick_attack(delta)

func _walk(at: Vector2, other: Vector2, clearance: float) -> Vector2:
	var bounded := at.clamp(DECK.position, DECK.end)
	var offset := bounded - other
	if not offset.is_zero_approx() and offset.length_squared() < clearance * clearance:
		bounded = other + offset.normalized() * clearance
	return bounded.clamp(DECK.position, DECK.end)

func _tick_attack(delta: float) -> void:
	if attack_age < 0.0:
		return
	var previous := attack_age
	attack_age += delta
	var to_enemy := enemy - position
	if previous < 0.145 and attack_age >= 0.145 and to_enemy.length() <= SWORD_REACH and attack_direction.dot(to_enemy.normalized()) > 0.48:
		if stance == Stance.RECOVERY and not opening_used:
			opening_used = true
			resolve = maxi(0, resolve - damage)
			recovery = minf(recovery, stance_age + 0.28)
			enemy_flash = 0.28
			cue.emit("hit")
			if not pressured and resolve <= TURNING_POINT:
				resolve = maxi(resolve, 1)
				pressured = true
				cue.emit("crew")
			if resolve == 0:
				phase = Phase.DISARMED
				cue.emit("disarm")
		else:
			cue.emit("clang")
	if attack_age >= 0.31:
		attack_age = -1.0

func windup_duration() -> float:
	var spec: Dictionary = ATTACKS[pattern]
	return float(spec.windup) * (0.66 if second_swing else 0.86 if pressured else 1.0)

func _start_windup(next_pattern: int, follow_up: bool) -> void:
	pattern = next_pattern
	second_swing = follow_up
	stance = Stance.WINDUP
	stance_age = 0.0
	contacted = false
	enemy_velocity = Vector2.ZERO
	cue.emit("ready")

func _tick_enemy(delta: float) -> void:
	stance_age += delta
	var toward := position - enemy
	var attack_spec: Dictionary = ATTACKS[pattern]
	enemy_velocity = Vector2.ZERO
	match stance:
		Stance.APPROACH:
			enemy_facing = toward.normalized()
			enemy_velocity = enemy_facing * (173.0 if pressured else 135.0)
			var next_pattern := pattern_index % ATTACKS.size()
			if toward.length() < float(ATTACKS[next_pattern].range) - 20.0:
				_start_windup(next_pattern, false)
				pattern_index += 1
		Stance.WINDUP:
			var duration := windup_duration()
			if stance_age < duration * 0.57:
				enemy_facing = toward.normalized()
			if stance_age >= duration:
				stance = Stance.STRIKE
				stance_age = 0.0
				cue.emit("enemy_swing")
		Stance.STRIKE:
			enemy_velocity = enemy_facing * float(attack_spec.charge)
			if not contacted and stance_age >= 0.045 and toward.length() <= float(attack_spec.range) and absf(enemy_facing.angle_to(toward)) <= float(attack_spec.angle):
				contacted = true
				_resolve_enemy_hit()
			if stance == Stance.STRIKE and stance_age >= 0.21:
				if pressured and pattern == 0:
					_start_windup(1, true)
				else:
					_recover(0.78 if pressured else 0.93)
		Stance.RECOVERY:
			if stance_age >= recovery:
				stance = Stance.APPROACH
				stance_age = 0.0
	enemy = _walk(enemy + enemy_velocity * delta, position, 33.0)

func _resolve_enemy_hit() -> void:
	var toward_enemy := position.direction_to(enemy)
	if guarding and facing.dot(toward_enemy) > 0.48 and guard >= 26.0:
		var parry := guard_age <= 0.17
		guard -= 15.0 if parry else 34.0
		guard = maxf(0.0, guard)
		velocity -= toward_enemy * (76.0 if parry else 133.0)
		_recover(1.23 if parry else 0.72)
		cue.emit("parry" if parry else "clang")
		return
	if guarding:
		guarding = false
		guard_break = 0.62
	if hit_immunity > 0.0:
		return
	hp = maxi(0, hp - ENEMY_DAMAGE)
	hit_flash = 0.31
	hit_immunity = 0.54
	attack_age = -1.0
	velocity -= toward_enemy * 235.0
	cue.emit("hurt")
	if hp == 0:
		phase = Phase.LOST

func _recover(duration: float) -> void:
	stance = Stance.RECOVERY
	stance_age = 0.0
	recovery = duration
	opening_used = false
	enemy_velocity = Vector2.ZERO
