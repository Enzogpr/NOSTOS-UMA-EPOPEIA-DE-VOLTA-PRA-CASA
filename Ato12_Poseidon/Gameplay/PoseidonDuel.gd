extends RefCounted

signal cue(kind: StringName)
signal phase_changed

enum Phase { READY, SURGE, GUARDS, DISARM, UNLEASH, DUEL, ENDING, WON, LOST }
enum State { WAIT, WINDUP, STRIKE, REST, EXPOSED, DISARMED }
enum Move { THRUST, SWEEP, WAVE }

const GUARDS := preload("res://Ato12_Poseidon/Gameplay/PoseidonArenaGuards.gd")
const WATER_GEOMETRY := preload("res://Ato12_Poseidon/Gameplay/PoseidonWaterGeometry.gd")
const CONFIG_PATH := "res://Ato12_Poseidon/Gameplay/PoseidonEncounter.json"
const ARENA := Rect2(99, 373, 954, 190)
const SWORD_REACH := 136.0
const TRIDENT_REACH := 183.0
const END_TIME := 12.6
const WIND_MAX := 3

var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
var phase := Phase.READY
var lost_from := Phase.SURGE
var checkpoint := Phase.SURGE
var hp := 10
var max_hp := 10
var entry_hp := 10
var checkpoint_hp := 10
var recovered_hp := 0
var recovery_until := 0.0
var health_pickups: Array[Dictionary] = []
var checkpoint_pickups: Array[Dictionary] = []
var damage := 3
var speed_mult := 1.0
var dash_cooldown := 3.0
var clock := 0.0
var phase_age := 0.0
var state := State.WAIT
var state_age := 0.0
var position := Vector2(576, 497)
var velocity := Vector2.ZERO
var axis := Vector2.ZERO
var look := Vector2.UP
var facing := Vector2.UP
var defend := false
var guard_age := 0.0
var dash_left := 0.0
var dash_recharge := 0.0
var dash_direction := Vector2.UP
var attack_age := -1.0
var attack_direction := Vector2.UP
var attack_applied := false
var hit_flash := 0.0
var boss_flash := 0.0
var last_boss_damage := 0
var boss_damage_at := Vector2.ZERO
var boss_damage_until := 0.0
var attack_feedback := ""
var attack_feedback_until := 0.0
var invulnerability := 0.0
var boss := Vector2(805, 426)
var boss_hp := 288
var boss_max_hp := 288
var move := Move.THRUST
var strike_origin := Vector2.ZERO
var strike_angle := PI
var strike_connected := false
var pursuit_from := Vector2.ZERO
var pursuit_to := Vector2.ZERO
var combo_step := 0
var combo_cycle := 0
var hits_in_opening := 0
var barrier_hits := 0
var anchor_hits := 0
var formation := 0
var formation_wait := -1.0
var disarm_age := 0.0
var release_age := 0.0
var guards := GUARDS.new()
var bag_open := false
var bag_emptied := false
var bag_untying := 0.0
var hold_interact := false
var has_trident := false
var trident := Vector2.ZERO
var trident_dropped := false
var wind_charges := WIND_MAX
var wind_refill := 0.0
var wind_cooldown := 0.0
var wind_cast := 0.0
var wind_point := Vector2(392, 395)
var projectiles: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var background_round := 0
var sequence_step := 0
var attack_count := 0
var opening_used := false
var opening_id := 0
var finisher := false
var next_attack := 1.4
var next_combo := 0.0
var storm := 0.0
var wind_force := Vector2.ZERO
var boss_shift := 0.0
var ending_step := 0
var total_hits_taken := 0

func apply_stats(stats: Dictionary) -> void:
	var previous := dash_cooldown
	max_hp = maxi(1, int(stats.max_hp))
	entry_hp = clampi(int(stats.current_hp), 0, max_hp)
	damage = maxi(1, int(stats.damage))
	speed_mult = maxf(0.3, float(stats.speed_mult))
	dash_cooldown = maxf(0.5, float(stats.dash_cooldown))
	dash_recharge *= dash_cooldown / maxf(previous, 0.5)
	if phase == Phase.READY:
		hp = entry_hp
	else:
		hp = mini(hp, max_hp)
		checkpoint_hp = mini(checkpoint_hp, max_hp)
		if hp <= 0 and phase not in [Phase.WON, Phase.LOST]:
			_enter(Phase.LOST)

func start() -> void:
	health_pickups.clear()
	checkpoint_pickups.clear()
	checkpoint = Phase.SURGE
	checkpoint_hp = entry_hp
	clock = 0.0
	total_hits_taken = 0
	retry()

func retry() -> void:
	hp = checkpoint_hp
	health_pickups.assign(checkpoint_pickups.duplicate(true))
	recovered_hp = 0
	recovery_until = 0.0
	hit_flash = 0.0
	boss_flash = 0.0
	invulnerability = 0.0
	barrier_hits = 0 if checkpoint == Phase.SURGE else int(config.barrier_seals)
	anchor_hits = int(config.guard_formations) if checkpoint == Phase.DUEL else 0
	bag_open = checkpoint == Phase.DUEL
	bag_emptied = checkpoint == Phase.DUEL
	has_trident = checkpoint == Phase.DUEL
	_enter(checkpoint)
	if hp <= 0:
		_enter(Phase.LOST)

func _enter(next: Phase) -> void:
	var previous := phase
	if next == Phase.LOST:
		lost_from = phase
		phase = next
		phase_changed.emit()
		return
	phase = next
	phase_age = 0.0
	velocity = Vector2.ZERO
	dash_left = 0.0
	dash_recharge = 0.0
	attack_age = -1.0
	last_boss_damage = 0
	boss_damage_until = 0.0
	attack_feedback_until = 0.0
	projectiles.clear()
	hazards.clear()
	guards.clear()
	wind_charges = WIND_MAX
	wind_refill = 0.0
	wind_cooldown = 0.0
	wind_cast = 0.0
	state = State.WAIT
	state_age = 0.0
	background_round = 0
	sequence_step = 0
	attack_count = 0
	finisher = false
	opening_used = false
	trident = Vector2.ZERO
	trident_dropped = false
	formation_wait = -1.0
	disarm_age = 0.0
	release_age = 0.0
	bag_untying = 0.0
	storm = 1.0 if phase == Phase.DUEL else 0.0
	wind_force = Vector2.ZERO
	match phase:
		Phase.SURGE:
			position = Vector2(576, 497)
			next_attack = 2.0
		Phase.GUARDS:
			if previous != Phase.SURGE:
				position = Vector2(576, 511)
			formation = 0
			next_attack = 2.2
			_spawn_formation()
		Phase.DISARM:
			wind_point = Vector2(428,366)
			trident = Vector2(411,416)
			state = State.WINDUP
			cue.emit(&"trident_lower")
		Phase.UNLEASH:
			trident = Vector2.ZERO
			has_trident = true
			bag_untying = 0.0
			cue.emit(&"silence")
		Phase.DUEL:
			has_trident = true
			bag_emptied = true
			bag_open = true
			boss_max_hp = int(config.duel_hp)
			boss_hp = boss_max_hp
			if previous != Phase.UNLEASH:
				position = Vector2(351, 490)
			boss = Vector2(811, 435)
			pursuit_from = boss
			pursuit_to = boss
			combo_step = 0
			combo_cycle = 0
			next_combo = 1.7
		Phase.ENDING:
			ending_step = 0
			cue.emit(&"surrender")
	phase_changed.emit()

func set_input(movement: Vector2, aim: Vector2, guard: bool, interact_held: bool = false) -> void:
	axis = movement.limit_length()
	if aim.length_squared() > 1:
		look = aim.normalized()
	var guarding := guard and attack_age < 0 and wind_cast <= 0 and dash_left <= 0
	if guarding and not defend:
		guard_age = 0.0
	defend = guarding
	hold_interact = interact_held

func active() -> bool:
	return phase in [Phase.SURGE, Phase.GUARDS, Phase.DISARM, Phase.UNLEASH, Phase.DUEL]

func movement_speed() -> float:
	return 241.0 * clampf(sqrt(speed_mult), 0.84, 1.25)

func dash_recharge_duration() -> float:
	return dash_cooldown

func request_dash() -> void:
	if not active() or dash_left > 0 or dash_recharge > 0 or phase == Phase.UNLEASH:
		return
	dash_direction = axis.normalized() if axis.length_squared() > 0.01 else look
	dash_left = 0.20
	dash_recharge = dash_cooldown
	attack_age = -1.0
	bag_untying = maxf(0, bag_untying - 0.65)
	cue.emit(&"dash")

func request_attack() -> void:
	if phase not in [Phase.SURGE, Phase.GUARDS, Phase.DUEL] or attack_age >= 0 or defend or dash_left > 0:
		return
	attack_age = 0.0
	attack_direction = look
	facing = look
	attack_applied = false
	cue.emit(&"trident" if has_trident else &"sword")

func interact() -> void:
	var pickup := nearby_health_pickup()
	if not pickup.is_empty():
		if hp < max_hp:
			pickup.collected = true
			_recover_health(int(pickup.amount))
			cue.emit(&"heal")
			return
	if phase == Phase.DISARM and trident_dropped and release_age >= 0.8 and position.distance_to(trident) < 78:
		_enter(Phase.UNLEASH)
		cue.emit(&"claim")
	elif phase in [Phase.SURGE, Phase.GUARDS, Phase.DISARM]:
		request_wind()

func _spawn_health_pickup(id: int, amount: int, at: Vector2) -> void:
	for pickup in health_pickups:
		if pickup.id == id:
			return
	health_pickups.append({"id":id,"amount":amount,"position":at,"collected":false})

func nearby_health_pickup() -> Dictionary:
	if not active():
		return {}
	for pickup in health_pickups:
		if not pickup.collected and position.distance_to(pickup.position) < 43:
			return pickup
	return {}

func _recover_health(amount: int) -> void:
	var previous := hp
	hp = mini(max_hp,hp+amount)
	recovered_hp = hp-previous
	recovery_until = clock+2.8 if recovered_hp > 0 else 0.0

func request_wind() -> void:
	if phase not in [Phase.SURGE, Phase.GUARDS, Phase.DISARM] or wind_charges <= 0 or wind_cooldown > 0 or dash_left > 0 or defend or trident_dropped:
		return
	wind_charges -= 1
	wind_cooldown = 0.94
	wind_refill = float(config.wind_recharge)
	wind_cast = 0.36
	facing = look
	projectiles.append({"position":position, "direction":look, "age":0.0, "trail":position})
	cue.emit(&"wind")

func tick(delta: float) -> void:
	var remaining := minf(maxf(0, delta), 3.0)
	while remaining > 0.000001 and (active() or phase == Phase.ENDING):
		var dt := minf(remaining, 1.0 / 120.0)
		remaining -= dt
		_step(dt)

func _step(dt: float) -> void:
	clock += dt
	phase_age += dt
	guard_age += dt
	hit_flash = maxf(0, hit_flash - dt)
	boss_flash = maxf(0, boss_flash - dt)
	invulnerability = maxf(0, invulnerability - dt)
	dash_recharge = maxf(0, dash_recharge - dt)
	wind_cooldown = maxf(0, wind_cooldown - dt)
	wind_cast = maxf(0, wind_cast - dt)
	if phase in [Phase.SURGE, Phase.GUARDS, Phase.DISARM]:
		wind_refill = maxf(0, wind_refill - dt)
		if wind_refill <= 0 and wind_charges < WIND_MAX:
			wind_charges += 1
			wind_refill = float(config.wind_recharge) if wind_charges < WIND_MAX else 0.0
	if phase == Phase.ENDING:
		storm = maxf(0, 1.0 - phase_age / END_TIME)
		if phase_age >= END_TIME:
			_enter(Phase.WON)
		return
	if phase == Phase.UNLEASH:
		_unleash_tick(dt)
		return
	_update_player(dt)
	_update_hazards(dt)
	if not active():
		return
	_update_projectiles(dt)
	if phase == Phase.SURGE:
		_background_tick(dt)
	elif phase == Phase.GUARDS:
		_guards_tick(dt)
	elif phase == Phase.DISARM:
		_disarm_tick(dt)
	else:
		_duel_tick(dt)
	if dash_left > 0:
		dash_left = maxf(0, dash_left - dt)

func _update_player(dt: float) -> void:
	wind_force = Vector2.ZERO
	if phase == Phase.DUEL:
		var push := pow(maxf(0, sin(phase_age * 0.72)), 3)
		wind_force = Vector2(cos(floor(phase_age / 8) * PI) * 44 * push, 0)
	var desired := axis * movement_speed() + wind_force
	if defend:
		desired *= 0.53
	if attack_age >= 0 or wind_cast > 0:
		desired *= 0.70
	if dash_left > 0:
		desired = dash_direction * 795
	velocity = velocity.move_toward(desired, 3300 * dt)
	position = (position + velocity * dt).clamp(ARENA.position, ARENA.end)
	if axis.length_squared() > 0.01 and attack_age < 0 and wind_cast <= 0:
		facing = axis.normalized()
	if attack_age >= 0:
		attack_age += dt
		if attack_age >= 0.105 and not attack_applied:
			if phase == Phase.DUEL:
				# A visible extending trident can connect throughout its active frames.
				attack_applied = _player_hit()
				if attack_age >= 0.28:
					attack_applied = true
			else:
				attack_applied = true
				_player_hit()
		if attack_age > (0.48 if has_trident else 0.39):
			attack_age = -1.0

func boss_vulnerable() -> bool:
	return phase == Phase.DUEL and has_trident and bag_emptied and state == State.REST and hits_in_opening < 2

func trident_extension() -> float:
	if attack_age < 0:
		return 47.0
	var extension := smoothstep(0,0.105,attack_age)*(1-smoothstep(0.28,0.48,attack_age))
	return lerpf(47,TRIDENT_REACH-66,extension)

func _attack_failed(message: String) -> void:
	if clock >= attack_feedback_until or attack_feedback != message:
		attack_feedback = message
		attack_feedback_until = clock+0.9
		cue.emit(&"parry")

func _player_hit() -> bool:
	if phase == Phase.GUARDS:
		if guards.hit(position, attack_direction, SWORD_REACH, damage) > 0:
			cue.emit(&"water_hit")
			return true
	elif phase == Phase.DUEL:
		var offset := boss - position
		if not boss_vulnerable():
			if offset.length() <= TRIDENT_REACH+20:
				_attack_failed("GUARDA REFEITA" if state == State.REST and hits_in_opening >= 2 else "GUARDA FECHADA")
			return false
		if offset.length() > TRIDENT_REACH:
			_attack_failed("APROXIME-SE")
			return false
		if offset.normalized().dot(attack_direction) < 0.28:
			_attack_failed("MIRE EM POSEIDON")
			return false
		hits_in_opening += 1
		last_boss_damage = mini(boss_hp,6+roundi(damage*0.75))
		boss_damage_at = boss
		boss_damage_until = clock+0.75
		boss_hp = maxi(0,boss_hp-last_boss_damage)
		boss_flash = 0.24
		cue.emit(&"boss_hit")
		if boss_hp == 0:
			_enter(Phase.ENDING)
		return true
	return false

func _guards_tick(dt: float) -> void:
	# Soldiers own all attacks in this stage; Poseidon's arena hazards stay disabled.
	var previous_shots := guards.shots_fired
	for contact in guards.tick(dt,position,ARENA):
		_hurt(int(contact.damage),true,contact.origin)
		if phase == Phase.LOST:
			return
	if guards.shots_fired > previous_shots:
		cue.emit(&"arrow")
	if guards.remaining() > 0:
		return
	if formation_wait < 0:
		anchor_hits += 1
		guards.arrows.clear()
		formation_wait = 1.15
		cue.emit(&"formation_clear")
	formation_wait -= dt
	if formation_wait <= 0:
		if anchor_hits >= int(config.guard_formations):
			_spawn_health_pickup(2,3,Vector2(672,515))
			_enter(Phase.DISARM)
		else:
			formation = anchor_hits
			_spawn_formation()
			formation_wait = -1.0

func _disarm_tick(dt: float) -> void:
	disarm_age += dt
	state_age += dt
	if trident_dropped:
		release_age += dt
		trident = Vector2(411,416).lerp(Vector2(576,462),smoothstep(0,0.8,release_age))
	elif disarm_age >= 1.35 and state != State.EXPOSED:
		state = State.EXPOSED
		state_age = 0.0
		opening_used = false
		cue.emit(&"opening")

func _background_tick(dt: float) -> void:
	state_age += dt
	if trident_dropped:
		return
	if state == State.EXPOSED:
		if state_age >= float(config.wind_opening):
			state = State.WAIT
			state_age = 0.0
			next_attack = phase_age + float(config.opening_recovery)
			sequence_step = 0
			background_round += 1
		return
	if finisher:
		if phase_age >= next_attack:
			finisher = false
			state = State.EXPOSED
			state_age = 0.0
			opening_used = false
			opening_id += 1
			var side := -1 if background_round % 2 == 0 else 1
			wind_point = Vector2(576 + side * 188, 398)
			cue.emit(&"opening")
		return
	if phase_age < next_attack:
		return
	var patterns: Array = config.background_sequence
	if sequence_step >= patterns.size():
		finisher = true
		state = State.WINDUP
		state_age = 0.0
		_spawn_finisher()
		next_attack = phase_age + float(config.finisher_duration)
		return
	var order := (sequence_step + background_round * 2) % patterns.size()
	_spawn_pattern(str(patterns[order]))
	sequence_step += 1
	attack_count += 1
	state = State.STRIKE
	state_age = 0.0
	next_attack = phase_age + float(config.attack_interval) - (0.14 if phase == Phase.GUARDS else 0.0)
	cue.emit(&"gather")

func _spawn_pattern(kind: String) -> void:
	var variant := background_round % 3
	match kind:
		"spears":
			for n in 3:
				var at := (position + Vector2((n - 1) * 116, 0)).clamp(ARENA.position + Vector2(38, 0), ARENA.end - Vector2(38, 0))
				_add_rect("spear", Rect2(at - Vector2(30, 25), Vector2(60, 50)), 0.85 + n * 0.16, 0.28, 2)
		"tide":
			var side := -1 if (attack_count + background_round) % 2 == 0 else 1
			var gap_y := 414.0 if variant % 2 == 0 else 528.0
			var x := ARENA.position.x - 75 if side < 0 else ARENA.end.x + 75
			hazards.append({"kind":"tide", "rect":Rect2(x - 32, ARENA.position.y, 64, ARENA.size.y), "age":0.0, "lead":0.68, "hold":2.65,
				"velocity":Vector2(443 * -side, 0), "gap":gap_y, "gap_size":68.0, "spent":false, "damage":2})
		"cross":
			for n in 2:
				var origin := Vector2(126 if n == 0 else 1026, 391 if (n + variant) % 2 == 0 else 550)
				var direction := origin.direction_to(position + Vector2(0, -7 if n == 0 else 7))
				hazards.append({"kind":"bolt", "rect":Rect2(origin - Vector2(18, 15), Vector2(36, 30)), "age":0.0, "lead":0.83 + n * 0.28, "hold":2.5,
					"velocity":direction * 382, "spent":false, "damage":2})
		"pools":
			for n in 2:
				var center := (position + Vector2((n * 2 - 1) * 69, 0)).clamp(ARENA.position + Vector2(51, 36), ARENA.end - Vector2(51, 36))
				_add_rect("pool", Rect2(center - Vector2(47, 37), Vector2(94, 74)), 1.15 + n * 0.15, 2.85, 1)
		"rain":
			var lane := clampi(int((position.x - ARENA.position.x) / (ARENA.size.x / 4)), 0, 3)
			var safe := clampi(lane + (-1 if background_round % 2 == 0 else 1), 0, 3)
			for n in 4:
				if n == safe:
					continue
				_add_rect("rain", Rect2(ARENA.position.x + n * ARENA.size.x / 4 + 8, ARENA.position.y, ARENA.size.x / 4 - 16, ARENA.size.y), 1.62, 0.38, 2)

func _spawn_finisher() -> void:
	# Both banks surge toward a visibly quiet channel. It always remains reachable.
	var safe_x := clampf(position.x + (-116 if background_round % 2 == 0 else 116), 255, 897)
	_add_rect("breaker", Rect2(ARENA.position.x, ARENA.position.y, safe_x - 70 - ARENA.position.x, ARENA.size.y), 1.65, 0.50, 3)
	_add_rect("breaker", Rect2(safe_x + 70, ARENA.position.y, ARENA.end.x - safe_x - 70, ARENA.size.y), 1.65, 0.50, 3)
	cue.emit(&"wave")

func _add_rect(kind: String, rect: Rect2, lead: float, hold: float, hurt: int) -> void:
	hazards.append({"kind":kind, "rect":rect, "age":0.0, "lead":lead, "hold":hold, "spent":false, "damage":hurt})

func _update_hazards(dt: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[i]
		hazard.age += dt
		if hazard.age > hazard.lead + hazard.hold + 0.42:
			hazards.remove_at(i)
			continue
		if hazard.age < hazard.lead or hazard.age > hazard.lead + hazard.hold:
			continue
		if hazard.has("velocity"):
			hazard.rect.position += hazard.velocity * dt
		if not hazard.spent and WATER_GEOMETRY.hazard_hits(hazard,position,clock):
			if _hurt(int(hazard.damage), hazard.kind in ["spear", "bolt"], hazard.rect.get_center()):
				hazard.spent = true
			if phase == Phase.LOST:
				return

func _update_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		if i >= projectiles.size():
			continue
		var shot: Dictionary = projectiles[i]
		shot.age += dt
		shot.trail = shot.position
		shot.position += shot.direction * dt * 725
		if phase == Phase.GUARDS:
			if guards.hit_by_wind(shot.trail,shot.position,maxi(1,roundi(damage*0.5))):
				projectiles.remove_at(i)
				cue.emit(&"water_hit")
			elif shot.age > 1.75:
				projectiles.remove_at(i)
			continue
		var closest := Geometry2D.get_closest_point_to_segment(wind_point, shot.trail, shot.position)
		if state == State.EXPOSED and not opening_used and closest.distance_to(wind_point) < 44:
			projectiles.remove_at(i)
			_wind_hit()
		elif shot.age > 1.75:
			projectiles.remove_at(i)
		if phase not in [Phase.SURGE, Phase.GUARDS, Phase.DISARM]:
			return

func _wind_hit() -> void:
	if phase not in [Phase.SURGE, Phase.DISARM]:
		return
	if phase == Phase.DISARM and state != State.EXPOSED:
		return
	opening_used = true
	boss_flash = 0.32
	cue.emit(&"boss_hit")
	if phase == Phase.SURGE:
		barrier_hits += 1
		if barrier_hits >= int(config.barrier_seals):
			_spawn_health_pickup(1,2,Vector2(576,515))
			checkpoint = Phase.GUARDS
			checkpoint_hp = hp
			checkpoint_pickups.assign(health_pickups.duplicate(true))
			_enter(Phase.GUARDS)
			cue.emit(&"guard_arrive")
	elif state == State.EXPOSED and not trident_dropped:
		trident_dropped = true
		release_age = 0.0
		state = State.DISARMED
		cue.emit(&"disarm")

func _spawn_formation() -> void:
	guards.spawn_formation(formation, ARENA, int(config.guard_hp), int(config.captain_hp))
	cue.emit(&"guard_arrive")

func _unleash_tick(dt: float) -> void:
	if not bag_emptied:
		var desired := axis * movement_speed()
		if hold_interact and axis.length_squared() < 0.01 and dash_left <= 0:
			bag_untying = minf(2.3, bag_untying + dt)
			desired = Vector2.ZERO
		else:
			bag_untying = maxf(0, bag_untying - dt * 0.8)
		velocity = velocity.move_toward(desired, dt * 2600)
		position = (position + velocity * dt).clamp(ARENA.position, ARENA.end)
		if bag_untying >= 2.3:
			bag_emptied = true
			bag_open = true
			state_age = 0.0
			cue.emit(&"unleash")
	else:
		state_age += dt
		storm = smoothstep(0.0, 4.2, state_age)
		if state_age >= 5.2:
			checkpoint = Phase.DUEL
			checkpoint_hp = hp
			checkpoint_pickups.assign(health_pickups.duplicate(true))
			_enter(Phase.DUEL)
			cue.emit(&"duel_start")
	if not bag_emptied and phase_age >= 2.0:
		# The god presses down; opening the whole bag counters this approaching wall.
		storm = minf(0.24, (phase_age - 2.0) * 0.013)
		if phase_age >= 15.0:
			_hurt(2, false, Vector2(576, 80))

func duel_tier() -> int:
	return clampi(2 - int(ceil(float(boss_hp) / maxf(1, boss_max_hp) * 3)) + 1, 0, 2)

func _duel_tick(dt: float) -> void:
	state_age += dt
	match state:
		State.WAIT:
			boss = pursuit_from.lerp(pursuit_to, smoothstep(0, 0.72, state_age))
			if state_age >= next_combo:
				combo_step = 0
				_begin_duel_attack()
		State.WINDUP:
			if state_age < windup() - 0.22:
				strike_angle = strike_origin.angle_to_point(position)
			if state_age >= windup():
				_set_state(State.STRIKE)
				cue.emit(&"wave" if move == Move.WAVE else &"strike")
		State.STRIKE:
			_check_strike()
			if phase != Phase.DUEL:
				return
			if state_age >= strike_time():
				combo_step += 1
				var combo: Array = config.duel_combos[duel_tier()]
				if combo_step >= combo.size():
					_set_state(State.REST)
					hits_in_opening = 0
					cue.emit(&"opening")
				else:
					_set_state(State.DISARMED)
		State.DISARMED:
			if state_age >= 0.28:
				_begin_duel_attack()
		State.REST:
			if state_age >= 1.72 - duel_tier() * 0.09:
				combo_cycle += 1
				pursuit_from = boss
				var destinations := [Vector2(287, 422), Vector2(831, 519), Vector2(798, 405), Vector2(315, 526)]
				pursuit_to = destinations[combo_cycle % destinations.size()]
				next_combo = 0.95
				_set_state(State.WAIT)
				if duel_tier() > 0:
					var at := position + Vector2(-70 if combo_cycle % 2 == 0 else 70, 0)
					_add_rect("pool", Rect2(at - Vector2(35, 28), Vector2(70, 56)), 1.15, 1.7, 1)

func _begin_duel_attack() -> void:
	var combo: Array = config.duel_combos[duel_tier()]
	var kind := str(combo[mini(combo_step, combo.size() - 1)])
	move = Move.THRUST if kind == "thrust" else Move.SWEEP if kind == "sweep" else Move.WAVE
	strike_origin = boss
	strike_angle = boss.angle_to_point(position)
	_set_state(State.WINDUP)
	cue.emit(&"gather")

func _set_state(next: State) -> void:
	state = next
	state_age = 0.0
	strike_connected = false

func windup() -> float:
	return (0.83 if move == Move.THRUST else 0.92 if move == Move.WAVE else 0.76) - duel_tier() * 0.055

func strike_time() -> float:
	return 0.40 if move == Move.THRUST else 1.17 if move == Move.WAVE else 0.54

func thrust_tip() -> Vector2:
	var progress := smoothstep(0.0, 0.25, state_age)
	return strike_origin + Vector2.from_angle(strike_angle) * lerpf(48, 344, progress)

func sweep_tip() -> Vector2:
	return strike_origin + Vector2.from_angle(strike_angle + lerpf(-1.18, 1.18, clampf(state_age / strike_time(), 0, 1))) * 214

func wave_x() -> float:
	var right := combo_cycle % 2 == 0
	return lerpf(ARENA.end.x + 70 if right else ARENA.position.x - 70, ARENA.position.x - 70 if right else ARENA.end.x + 70, clampf(state_age / strike_time(), 0, 1))

func wave_gap_y() -> float:
	return 414.0 if combo_cycle % 2 == 0 else 528.0

func _check_strike() -> void:
	if strike_connected:
		return
	if move == Move.WAVE:
		if absf(position.x-wave_x()) < 27 and absf(position.y-wave_gap_y()) > 34 and WATER_GEOMETRY.hits_player(WATER_GEOMETRY.wave_parts(wave_x(),wave_gap_y(),ARENA,clock),position):
			if _hurt(2, false, Vector2(wave_x(), position.y)):
				strike_connected = true
		return
	var tip := thrust_tip() if move == Move.THRUST else sweep_tip()
	var contact := Geometry2D.get_closest_point_to_segment(position,strike_origin,tip)
	if contact.distance_to(position) < 14 and WATER_GEOMETRY.hits_player(WATER_GEOMETRY.duel_parts(strike_origin,tip,clock),position):
		if _hurt(2, true, boss):
			strike_connected = true

func _hurt(amount: int, blockable: bool, origin: Vector2) -> bool:
	if not active() or dash_left > 0 or invulnerability > 0 or (phase == Phase.UNLEASH and bag_emptied):
		return false
	if blockable and defend and position.direction_to(origin).dot(look) > 0.18:
		amount = 0 if guard_age <= 0.21 else maxi(0, amount - 1)
		cue.emit(&"parry")
	if amount <= 0:
		return true
	hp = maxi(0, hp - amount)
	total_hits_taken += 1
	hit_flash = 0.28
	invulnerability = 0.82
	bag_untying = maxf(0, bag_untying - 0.7)
	cue.emit(&"hurt")
	if hp <= 0:
		_enter(Phase.LOST)
	return true
