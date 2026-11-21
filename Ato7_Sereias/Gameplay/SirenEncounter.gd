extends RefCounted

signal cue(kind: String, at: Vector2)

enum Phase { READY, ACTIVE, ENTHRALLED, LOST, WON }
enum Leg { CHASE, MIRAGE, CHARM }

const WATER := Rect2(61, 121, 1030, 428)
const START := Vector2(187, 333)
const SIREN_START := Vector2(465, 357)
const LIMIT := 75.0
const CHARM_DURATION := 2.8
const FIRST_ESCAPE_DELAY := 0.72
const NET_RANGE := 225.0
const NET_RADIUS := 43.0
const NET_FLIGHT := 0.38
const NET_COOLDOWN := 1.15
const REEL_RANGE := 164.0
const REEL_TIMES := [FIRST_ESCAPE_DELAY, 1.8, 3.15]
const LINE_TIMES := [FIRST_ESCAPE_DELAY, 8.5, 18.0]
const SONG_RADIUS := 230.0
const REEFS := [Vector3(415, 225, 44), Vector3(620, 432, 58), Vector3(885, 305, 45)]
const STRAIN_LIMIT := 0.70

class Siren:
	var position: Vector2
	var velocity := Vector2.ZERO
	var facing := PI
	var singing := 0.0
	var captured_age := -1.0

var phase := Phase.READY
var leg := Leg.CHASE
var position := START
var velocity := Vector2.ZERO
var heading := 0.0
var hp := 10
var max_hp := 10
var entry_hp := 10
var elapsed := 0.0
var clock := 0.0
var charm_age := 0.0
var encounter_age := 0.0
var interlude := 0.0
var window_left := 0.0
var dive_time := 0.0
var illusions := PackedVector2Array()
var song_strength := 0.0
var hit_cooldown := 0.0
var net_cooldown := 0.0
var siren := Siren.new()
var net_from := Vector2.ZERO
var net_to := Vector2.ZERO
var net_age := -1.0
var hooked := false
var line_age := 0.0
var line_tension := 0.0
var line_blocker := -1
var tug := 0.0
var reel_progress := 0.0
var touching_siren := false
var speed_factor := 1.0
var turn_factor := 1.0
var song_resistance := 1.0

func _init() -> void:
	siren.position = SIREN_START

func apply_attributes(stats: Dictionary) -> void:
	max_hp = int(stats.max_hp)
	hp = mini(hp, max_hp)
	speed_factor = clampf(sqrt(float(stats.speed_mult)), 0.7, 1.3)
	turn_factor = clampf(1.0 + (float(stats.intellect) - 5.0) * 0.02, 1.0, 1.2)
	song_resistance = clampf(1.0 - (float(stats.intellect) - 5.0) * 0.018, 0.62, 1.0)

func set_entry_health(current_hp: int) -> void:
	entry_hp = clampi(current_hp, 0, max_hp)
	hp = entry_hp

func begin() -> void:
	if phase == Phase.READY:
		phase = Phase.ACTIVE if hp > 0 else Phase.LOST

func restart() -> void:
	position = START
	velocity = Vector2.ZERO
	heading = 0.0
	hp = clampi(entry_hp, 1, max_hp)
	elapsed = 0.0
	clock = 0.0
	charm_age = 0.0
	hit_cooldown = 0.0
	net_cooldown = 0.0
	net_age = -1.0
	leg = Leg.CHASE
	siren.position = SIREN_START
	siren.velocity = Vector2.ZERO
	siren.singing = 0.0
	siren.facing = PI
	siren.captured_age = -1.0
	_reset_encounter()
	phase = Phase.ACTIVE

func _reset_encounter() -> void:
	encounter_age = 0.0
	interlude = 0.0
	window_left = 0.0
	dive_time = 0.0
	illusions.clear()
	song_strength = 0.0
	touching_siren = false
	_clear_line()

func _clear_line() -> void:
	hooked = false
	line_age = 0.0
	line_tension = 0.0
	line_blocker = -1
	tug = 0.0
	reel_progress = 0.0

func aim_point(pointer: Vector2) -> Vector2:
	return position + (pointer - position).limit_length(NET_RANGE)

func cast_net(pointer: Vector2) -> void:
	if phase != Phase.ACTIVE or interlude > 0.0 or net_cooldown > 0.0 or hooked:
		return
	net_from = position
	net_to = aim_point(pointer)
	net_age = 0.0
	net_cooldown = NET_COOLDOWN
	cue.emit("cast", position)

func helm_inverted() -> bool:
	return phase == Phase.ACTIVE and leg == Leg.CHARM and interlude <= 0.0

func net_window_open() -> bool:
	return phase == Phase.ACTIVE and interlude <= 0.0 and dive_time <= 0.0 and (leg == Leg.CHASE or window_left > 0.0)

func tick(delta: float, steering: Vector2, reeling := false) -> void:
	if delta <= 0.0: return
	clock += delta
	if phase == Phase.WON:
		siren.captured_age += delta
		_advance_net(delta)
		return
	if phase == Phase.ENTHRALLED:
		_advance_charm(delta)
		return
	if phase != Phase.ACTIVE: return
	elapsed = minf(LIMIT, elapsed + delta)
	if elapsed >= LIMIT - 0.00001:
		elapsed = LIMIT
		phase = Phase.ENTHRALLED
		net_age = -1.0
		window_left = 0.0
		interlude = 0.0
		dive_time = 0.0
		illusions.clear()
		_clear_line()
		cue.emit("enthralled", siren.position)
		return
	hit_cooldown = maxf(0.0, hit_cooldown - delta)
	net_cooldown = maxf(0.0, net_cooldown - delta)
	interlude = maxf(0.0, interlude - delta)
	if interlude <= 0.0: encounter_age += delta
	if dive_time > 0.0:
		dive_time = maxf(0.0, dive_time - delta)
		if dive_time == 0.0: encounter_age = 0.0
	var pull := _advance_siren(delta, reeling)
	var direction := -steering if helm_inverted() else steering
	var helm := direction.limit_length(1.0) * 236.0 * speed_factor * (1.0 - song_strength * 0.25)
	_advance_boat(delta, helm + pull, direction)
	_update_window()
	_check_contact()
	if phase != Phase.ACTIVE: return
	_advance_net(delta)
	_advance_line(delta, reeling)

func _advance_siren(delta: float, reeling: bool) -> Vector2:
	song_strength = 0.0
	var toward_boat := siren.position.direction_to(position)
	var target := _patrol_target()
	var swim := (target - siren.position).limit_length(54.0) * 2.5
	var pull := Vector2.ZERO
	var distance := siren.position.distance_to(position)
	var max_speed := 151.0
	if interlude > 0.0:
		siren.singing = 0.0
		swim = (target - siren.position).limit_length(88.0) * 3.25
		max_speed = 245.0
	elif hooked:
		siren.singing = 0.0
		if leg == Leg.CHARM:
			tug = smoothstep(0.48, 0.9, 0.5 + 0.5 * sin((line_age - 0.48) * TAU / 2.65))
			var east := Vector2(1011.0, 304.0 + sin(line_age * 1.6) * 62.0)
			swim = (east - siren.position).limit_length(43.0) * (1.45 + tug * 0.55)
			if reeling and can_haul(): swim = toward_boat * 37.0 + swim * 0.27
			pull = -toward_boat * tug * (22.0 + line_tension * 23.0)
		else:
			swim = swim * 0.13 + toward_boat * (34.0 if reeling else 10.0)
	elif dive_time > 0.0:
		siren.singing = 0.0
		swim = swim * 0.55 - toward_boat * 20.0
	else:
		var opening := leg != Leg.CHASE and window_left > 0.0
		siren.singing = 0.18 if leg == Leg.CHASE else 0.80 if opening else 0.25
		var influence := (1.0 - smoothstep(55.0, SONG_RADIUS, distance)) * siren.singing * song_resistance
		song_strength = maxf(influence, 0.43 if leg == Leg.CHARM else 0.0)
		pull = -toward_boat * influence * (35.0 if leg == Leg.CHASE else 73.0)
		if opening:
			swim *= 0.52
		else:
			swim -= toward_boat * (1.0 - smoothstep(63.0, 130.0, distance)) * 56.0
	var next := _constrain(siren.position + swim.limit_length(max_speed) * delta, 9.0)
	siren.velocity = (next - siren.position) / delta
	siren.position = next
	if siren.velocity.length_squared() > 72.0:
		siren.facing = rotate_toward(siren.facing, siren.velocity.angle(), delta * 6.0)
	return pull

func _patrol_target() -> Vector2:
	match leg:
		Leg.CHASE:
			return Vector2(480.0 + sin(encounter_age * 1.28) * 108.0, 345.0 + sin(encounter_age * 1.05 + 0.16) * 66.0)
		Leg.MIRAGE:
			var side := 1.0 if floori(encounter_age / 6.4) % 2 == 0 else -1.0
			return Vector2(685.0 + sin(encounter_age * 1.42) * 47.0, 307.0 - side * (65.0 + sin(encounter_age * 1.05) * 11.0))
	return Vector2(965.0 + cos(encounter_age * 1.08) * 28.0, 324.0 + sin(encounter_age * 1.13 + 0.85) * 87.0)

func _update_window() -> void:
	if leg == Leg.CHASE or hooked or interlude > 0.0 or dive_time > 0.0: return
	var rhythm := fposmod(encounter_age, 6.4)
	var end := 4.55 if leg == Leg.MIRAGE else 4.45
	var previous := window_left
	window_left = end - rhythm if rhythm >= 1.3 and rhythm < end else 0.0
	if window_left > 0.0 and previous <= 0.0: cue.emit("window", siren.position)
	illusions.clear()
	if leg == Leg.MIRAGE and rhythm >= 0.60 and rhythm < 5.2:
		var side := 1.0 if floori(encounter_age / 6.4) % 2 == 0 else -1.0
		illusions.append(_constrain(Vector2(1370.0 - siren.position.x, 614.0 - siren.position.y), 39.0))
		illusions.append(_constrain(siren.position + Vector2(114.0 * side, 42.0 * side), 39.0))

func _dive(at: Vector2, reason: String, duration: float) -> void:
	dive_time = duration
	window_left = 0.0
	illusions.clear()
	touching_siren = false
	cue.emit(reason, at)

func _advance_boat(delta: float, desired: Vector2, steering: Vector2) -> void:
	velocity = velocity.move_toward(desired, delta * 620.0 * turn_factor)
	var next := _constrain(position + velocity * delta, 26.0)
	velocity = (next - position) / delta
	position = next
	var facing := steering if not steering.is_zero_approx() else velocity
	if facing.length_squared() > 0.01:
		heading = rotate_toward(heading, facing.angle(), delta * 6.0 * turn_factor)

func _constrain(at: Vector2, clearance: float) -> Vector2:
	for reef in REEFS:
		var center := Vector2(reef.x, reef.y)
		var offset := at - center
		if offset.length_squared() < pow(reef.z + clearance, 2):
			var outward := offset.normalized() if not offset.is_zero_approx() else Vector2.RIGHT
			at = center + outward * (reef.z + clearance)
	return at.clamp(WATER.position, WATER.end)

func _advance_net(delta: float) -> void:
	if net_age < 0.0: return
	var previous := net_age
	net_age += delta
	if previous < NET_FLIGHT and net_age >= NET_FLIGHT and phase == Phase.ACTIVE:
		_resolve_net()
	if net_age > NET_FLIGHT + 0.5: net_age = -1.0

func _resolve_net() -> void:
	var distance := siren.position.distance_to(net_to)
	for image in illusions:
		var false_distance := image.distance_to(net_to)
		if false_distance <= NET_RADIUS and false_distance < distance:
			_dive(image, "false_target", 1.6)
			return
	if not net_window_open() or distance > NET_RADIUS:
		cue.emit("splash", net_to)
		return
	_clear_line()
	hooked = true
	window_left = 0.0
	illusions.clear()
	cue.emit("hook", siren.position)

func reel_time() -> float:
	return REEL_TIMES[leg]

func line_limit() -> float:
	return LINE_TIMES[leg]

func can_haul() -> bool:
	if not hooked or leg == Leg.CHASE or position.distance_to(siren.position) > REEL_RANGE:
		return false
	return leg != Leg.CHARM or (line_blocker < 0 and line_tension < STRAIN_LIMIT and tug < 0.54)

func reef_in_line(target: Vector2) -> int:
	for i in REEFS.size():
		var reef: Vector3 = REEFS[i]
		var center := Vector2(reef.x, reef.y)
		var closest := Geometry2D.get_closest_point_to_segment(center, position, target)
		if center.distance_to(closest) < reef.z + 7.0: return i
	return -1

func _advance_line(delta: float, reeling: bool) -> void:
	if not hooked: return
	line_age += delta
	if leg == Leg.CHASE:
		if line_age >= FIRST_ESCAPE_DELAY: _escape_into(Leg.MIRAGE)
		return
	var distance := position.distance_to(siren.position)
	if leg == Leg.CHARM:
		line_blocker = reef_in_line(siren.position)
		var stretch := smoothstep(118.0, 261.0, distance)
		if line_blocker >= 0:
			line_tension += delta * (0.88 if reeling else 0.42)
		elif reeling:
			line_tension += delta * lerpf(-0.34, 1.36, clampf(tug * 0.89 + stretch * 0.32, 0.0, 1.0))
		else:
			line_tension = move_toward(line_tension, 0.09 + tug * 0.42 + stretch * 0.11, delta * 1.15)
		line_tension = clampf(line_tension, 0.0, 1.0)
	if distance > NET_RANGE + (76.0 if leg == Leg.CHARM else 42.0) or line_age >= line_limit() or line_tension >= 1.0:
		_clear_line()
		_dive(siren.position, "escape", 1.9)
		return
	if not reeling or not can_haul(): return
	reel_progress += delta
	if reel_progress < reel_time(): return
	if leg == Leg.MIRAGE:
		_escape_into(Leg.CHARM)
		return
	siren.captured_age = 0.0
	siren.singing = 0.0
	_clear_line()
	song_strength = 0.0
	phase = Phase.WON
	velocity = Vector2.ZERO
	cue.emit("capture", siren.position)

func _escape_into(next: Leg) -> void:
	leg = next
	_reset_encounter()
	interlude = 1.35
	cue.emit("break_free", siren.position)

func _advance_charm(delta: float) -> void:
	charm_age += delta
	siren.singing = smoothstep(0.0, 0.8, charm_age)
	song_strength = siren.singing
	var drift := (siren.position - position).limit_length(104.0) * siren.singing
	_advance_boat(delta, drift, Vector2.ZERO)
	if charm_age >= CHARM_DURATION:
		phase = Phase.LOST
		velocity = Vector2.ZERO

func _check_contact() -> void:
	if interlude > 0.0 or dive_time > 0.0 or hooked: return
	var axis := Vector2.from_angle(heading) * 36.0
	var near := Geometry2D.get_closest_point_to_segment(siren.position, position - axis, position + axis)
	var touching := siren.position.distance_to(near) < 31.0
	if touching and not touching_siren and hit_cooldown <= 0.0:
		hp -= 1
		hit_cooldown = 0.85
		velocity += (position - siren.position).normalized() * 90.0
		cue.emit("hurt", siren.position)
		if hp <= 0: phase = Phase.LOST
	touching_siren = touching
