extends RefCounted
## Two playable parts: collapsing fleet traversal, then three mandatory deck acts.
signal feedback(text: String, kind: String)
signal phase_changed
signal attack_started(kind: String)
signal impact(kind: String)
signal ship_sunk(index: int)
signal completed(record: Dictionary)
signal failed(reason: String)
enum Phase { READY, TRAVERSAL, ARRIVAL, SURVIVAL, FINAL_ATTACK, ESCAPING, COMPLETE, FAILED }
const BAG := Vector2(998,470)
const HELM := Vector2(190,464)
const MAST := Vector2(574,426)
const COVER := Rect2(429,438,145,104)
const CRATE_COVER := Rect2(885,450,130,95)
const ANCHORS := [Vector2(248,478),Vector2(529,469),Vector2(851,547)]
const WALK_AREA := Rect2(100,405,960,178)
const SHIP_X := [100.0,1110.0,2160.0,3200.0]
const ROUTE_WIDTH := 650.0
const START := Vector2(195,465)
const UNTIE_SECONDS := 4.2
const WIND_SECONDS := 0.9
const WIND_OPEN := 6.0
const WIND_CLOSE := 9.0
const FINAL_IMPACT := 10.0
const WRECK_SECONDS := 4.2
var phase: Phase = Phase.READY
var position := START
var velocity := Vector2.ZERO
var facing: float = 1.0
var clock: float = 0.0
var phase_clock: float = 0.0
var balance: float = 100.0
var invulnerable: float = 0.0
var stagger: float = 0.0
var dash_left: float = 0.0
var dash_cooldown: float = 0.0
var dash_direction := Vector2.RIGHT
var bracing: bool = false
var untying: bool = false
var bag_progress: float = 0.0
var has_bag: bool = false
var bag_secured: bool = false
var wind_progress: float = 0.0
var wind_armed: bool = false
var interaction_was_held: bool = false
var hazards: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var sunk_at: Array[float] = []
var hits: int = 0
var dodges: int = 0
var jumps: int = 0
var retries: int = 0
var final_attempts: int = 0
var completion_count: int = 0
var attack_count: int = 0
var resolved_attacks: int = 0
var hit_flash: float = 0.0
var impact_flash: float = 0.0
var route_index: int = 0
var act_index: int = 0
var event_index: int = 0
var rest_clock: float = 0.0
var extra_attack: float = 0.0
var gate_open: bool = false
var gate_age: float = 0.0
var airborne: bool = false
var arrival_deck: bool = false
var flight_age: float = 0.0
var landing_pause: float = 0.0
var flight_duration: float = 1.05
var flight_from := Vector2.ZERO
var flight_to := Vector2.ZERO
var mast_broken: bool = false
var crate_broken: bool = false
var failure_reason: String = ""
var checkpoint: Dictionary = {}
var assaults: Dictionary
var rng := RandomNumberGenerator.new()

func _init(random_seed: int = 614) -> void:
	rng.seed = random_seed
	assaults = JSON.parse_string(FileAccess.get_file_as_string("res://Ato4_Tempestade/Gameplay/PoseidonAssaults.json"))
	for i in 11: sunk_at.append(-1.0)

func start() -> void:
	if phase != Phase.READY: return
	_change(Phase.TRAVERSAL)
	_save_checkpoint()
	feedback.emit("O impacto te lançou para outro navio. Volte à embarcação de Odisseu!","notice")

func _change(value: Phase) -> void:
	phase = value
	phase_clock = 0.0
	phase_changed.emit()

func active() -> bool:
	return phase in [Phase.TRAVERSAL,Phase.SURVIVAL,Phase.FINAL_ATTACK]

func is_route() -> bool:
	return phase in [Phase.READY,Phase.TRAVERSAL] or (phase == Phase.ARRIVAL and phase_clock < 1.6) or (phase == Phase.FAILED and checkpoint.get("phase",Phase.TRAVERSAL) == Phase.TRAVERSAL)

func route_rect(index: int = -1) -> Rect2:
	var i: int = route_index if index < 0 else index
	return Rect2(SHIP_X[i],430,ROUTE_WIDTH,65)

func launch_point() -> Vector2:
	return Vector2(route_rect().end.x-27,463)

func route_anchor() -> Vector2:
	return Vector2(route_rect().position.x+285,465)

func fleet_remaining() -> int:
	var count: int = 12
	for time in sunk_at:
		if time >= 0.0: count -= 1
	return count

func fleet_gone() -> bool:
	for time in sunk_at:
		if time < 0.0 or clock-time < WRECK_SECONDS: return false
	return true

func anchor_index() -> int:
	if is_route(): return 0 if position.distance_to(route_anchor()) < 55 else -1
	for i in ANCHORS.size():
		if position.distance_to(ANCHORS[i]) < 58.0: return i
	return -1

func sheltered() -> bool:
	return not is_route() and ((not mast_broken and COVER.has_point(position)) or (not crate_broken and act_index == 1 and CRATE_COVER.has_point(position)))

func wind_window() -> bool:
	return phase == Phase.FINAL_ATTACK and fleet_gone() and phase_clock >= WIND_OPEN and phase_clock < WIND_CLOSE

func tick(delta: float, direction := Vector2.ZERO, interact: bool = false, dash: bool = false) -> void:
	var remaining: float = maxf(0.0,delta)
	while remaining > 0.00001:
		var step: float = minf(remaining,0.02)
		_step(step,direction.limit_length(),interact,dash)
		dash = false
		remaining -= step

func _step(delta: float, direction: Vector2, interact: bool, dash: bool) -> void:
	if phase in [Phase.READY,Phase.COMPLETE,Phase.FAILED]: return
	var pressed: bool = interact and not interaction_was_held
	interaction_was_held = interact
	if not interact: wind_armed = false
	clock += delta
	phase_clock += delta
	hit_flash = maxf(0,hit_flash-delta)
	impact_flash = maxf(0,impact_flash-delta)
	if phase == Phase.ESCAPING:
		if phase_clock >= 6.6:
			_change(Phase.COMPLETE)
			completion_count += 1
			completed.emit(record())
		return
	if phase == Phase.ARRIVAL:
		if phase_clock >= 1.6 and not arrival_deck:
			arrival_deck = true
			position = Vector2(300,535)
		if phase_clock >= 2.8: _begin_act(0)
		return
	if phase == Phase.TRAVERSAL and landing_pause > 0:
		landing_pause = maxf(0,landing_pause-delta)
		phase_clock = 0
		velocity = Vector2.ZERO
		return
	invulnerable = maxf(0,invulnerable-delta)
	stagger = maxf(0,stagger-delta)
	dash_cooldown = maxf(0,dash_cooldown-delta)
	dash_left = maxf(0,dash_left-delta)
	bracing = false
	untying = false
	if airborne:
		_flight(delta)
		return
	if phase == Phase.TRAVERSAL and gate_open:
		gate_age += delta
		var near: bool = position.distance_to(launch_point()) < 62
		if near and ((route_index == 1 and pressed) or (route_index != 1 and dash)):
			_begin_flight()
			return
		if gate_age >= float(assaults.passage_seconds):
			_fail("A passagem fechou antes do salto. O navio está sendo esmagado.")
			return
	var carrying: bool = has_bag and not bag_secured
	if dash and dash_cooldown <= 0 and stagger <= 0 and phase != Phase.FINAL_ATTACK:
		dash_left = 0.2
		dash_cooldown = 0.85
		dash_direction = direction.normalized() if direction.length() > 0.1 else Vector2(facing,0)
		dodges += 1
	if stagger > 0:
		velocity = velocity.move_toward(Vector2.ZERO,delta*650)
	elif dash_left > 0:
		velocity = dash_direction*(430 if carrying else 510)
	elif interact:
		velocity = Vector2.ZERO
		if phase == Phase.SURVIVAL and not has_bag and position.distance_to(BAG) < 72:
			untying = true
			bag_progress = minf(1,bag_progress+delta/UNTIE_SECONDS)
			if bag_progress >= 1:
				has_bag = true
				feedback.emit("Bolsa recuperada. Continue resistindo aos ataques!","bag")
		elif phase == Phase.SURVIVAL and act_index == 1 and has_bag and not bag_secured and position.distance_to(HELM) < 78:
			if not bag_secured: feedback.emit("Bolsa presa junto ao leme. Prepare-se para a última sequência!","bag")
			bag_secured = true
		elif phase == Phase.FINAL_ATTACK and position.distance_to(HELM) < 80 and wind_window():
			if pressed: wind_armed = true
			if wind_armed: wind_progress += delta/WIND_SECONDS
			if wind_progress >= 1: _escape()
		elif anchor_index() >= 0:
			bracing = true
	else:
		velocity = velocity.move_toward(direction*(185 if carrying else 225),delta*1700)
	if phase == Phase.ESCAPING: return
	if not interact or stagger > 0 or not wind_window(): wind_progress = maxf(0,wind_progress-delta*2)
	if absf(velocity.x) > 12: facing = signf(velocity.x)
	_move(velocity*delta)
	if phase == Phase.FINAL_ATTACK:
		if phase_clock >= FINAL_IMPACT:
			_fail("A onda fechou a saída. Refaça a liberação dos ventos.")
		return
	if rest_clock > 0:
		rest_clock = maxf(0,rest_clock-delta)
		phase_clock = 0
		return
	_schedule()
	_tick_hazards(delta)
	_tick_projectiles(delta)
	if phase == Phase.FAILED: return
	var events: Array = _events()
	var duration: float = float(assaults.route_duration) if phase == Phase.TRAVERSAL else float(assaults.acts[act_index].duration)
	if event_index >= events.size() and phase_clock >= duration and hazards.is_empty() and projectiles.is_empty():
		if phase == Phase.TRAVERSAL and not gate_open:
			gate_open = true
			gate_age = 0
			feedback.emit("SALTE AGORA! O próximo navio está ao alcance." if route_index != 1 else "USE A CORDA! Aperte E na marca da proa.","warning")
		elif phase == Phase.SURVIVAL:
			var task_done: bool = has_bag if act_index == 0 else bag_secured if act_index == 1 else fleet_gone()
			if task_done:
				if act_index < 2: _begin_act(act_index+1)
				else: _begin_final()
			elif clock >= extra_attack:
				spawn_attack("jets")
				extra_attack = clock+3.7

func _events() -> Array:
	return assaults.routes[route_index] if phase == Phase.TRAVERSAL else assaults.acts[act_index].events

func _schedule() -> void:
	var events: Array = _events()
	while event_index < events.size() and phase_clock >= float(events[event_index].at):
		var event: Dictionary = events[event_index]
		spawn_attack(event.kind,float(event.lane),int(event.sink),str(event.damage))
		event_index += 1

func _move(offset: Vector2) -> void:
	position += offset
	var area: Rect2 = route_rect() if phase == Phase.TRAVERSAL else WALK_AREA
	position.x = clampf(position.x,area.position.x,area.end.x)
	position.y = clampf(position.y,area.position.y,area.end.y)
	if phase == Phase.TRAVERSAL:
		var foot := Vector2(route_rect().position.x+418,448)
		var contact: Vector2 = (position-foot)/Vector2(27,18)
		if contact.length() < 1:
			if contact.length() < 0.01: contact = Vector2.DOWN
			position = foot+contact.normalized()*Vector2(27,18)
		return
	var relative: Vector2 = (position-MAST)/Vector2(55,29)
	if relative.length() < 1:
		if relative.length() < 0.001: relative = Vector2.DOWN
		position = MAST+relative.normalized()*Vector2(55,29)
		position.y = maxf(position.y,WALK_AREA.position.y)

func _begin_flight() -> void:
	airborne = true
	flight_age = 0
	flight_duration = 1.6 if route_index == 1 else 1.05
	flight_from = position
	flight_to = Vector2(SHIP_X[route_index+1]+60,463)
	velocity = Vector2.ZERO
	hazards.clear()
	projectiles.clear()
	jumps += 1

func _flight(delta: float) -> void:
	flight_age += delta
	position = flight_from.lerp(flight_to,smoothstep(0,1,flight_age/flight_duration))
	if flight_age < flight_duration: return
	airborne = false
	_sink_specific(route_index)
	_sink_specific(3+route_index)
	impact.emit("ship")
	impact_flash = 0.5
	route_index += 1
	if route_index == 3:
		arrival_deck = false
		_change(Phase.ARRIVAL)
		feedback.emit("NAVIO DE ODISSEU · Agora proteja a bolsa e resista à fúria de Poseidon.","notice")
	else:
		phase_clock = 0
		landing_pause = 1.6
		gate_open = false
		gate_age = 0
		event_index = 0
		balance = 100
		_save_checkpoint()
		phase_changed.emit()

func _begin_act(index: int) -> void:
	act_index = index
	event_index = 0
	gate_open = false
	hazards.clear()
	projectiles.clear()
	velocity = Vector2.ZERO
	balance = 100
	stagger = 0
	rest_clock = 2.2 if index > 0 else 0
	_change(Phase.SURVIVAL)
	_save_checkpoint()
	feedback.emit("ATO %d / 3 · %s" % [index+1,assaults.acts[index].name],"notice")

func _begin_final() -> void:
	if not fleet_gone() or act_index != 2: return
	final_attempts += 1
	wind_progress = 0
	wind_armed = false
	hazards.clear()
	projectiles.clear()
	_change(Phase.FINAL_ATTACK)
	_save_checkpoint()
	feedback.emit("Só resta o seu navio. Volte ao leme e espere a abertura!","final")

func spawn_attack(kind: String, lane: float = 0, sink: int = -1, damage: String = "") -> void:
	var warning: float = 2.4 if kind == "hoof" else 1.45 if kind == "wave" else 1.2
	var points: Array[Vector2] = [position]
	var area: Rect2 = route_rect() if phase == Phase.TRAVERSAL else WALK_AREA
	if lane == 0: lane = area.get_center().y
	if kind == "jets" and phase == Phase.SURVIVAL:
		for i in 2: points.append(Vector2(rng.randf_range(180,1000),rng.randf_range(425,565)))
	hazards.append({"kind":kind,"age":0.0,"warning":warning,"points":points,"player_hit":false,"fired":false,"lane":lane,"sink":sink,"damage":damage,"area":area,"target":position})
	attack_count += 1
	attack_started.emit(kind)
	feedback.emit("","warning")

func _tick_hazards(delta: float) -> void:
	for hazard in hazards:
		hazard.age += delta
		var t: float = hazard.age-hazard.warning
		if t < 0: continue
		if not hazard.fired:
			hazard.fired = true
			if hazard.sink >= 0: _sink_specific(hazard.sink)
			if hazard.damage == "mast": mast_broken = true
			if hazard.damage == "crate": crate_broken = true
			impact.emit(hazard.kind)
			impact_flash = 0.16 if hazard.kind in ["fan","aimed"] else 0.32
			if hazard.kind in ["fan","aimed"]: _fire_projectiles(hazard)
		if hazard.player_hit: continue
		var danger: bool = false
		var guard: bool = false
		match str(hazard.kind):
			"jets":
				if t < 0.6:
					for point in hazard.points:
						if position.distance_to(point) < (37 if is_route() else 49): danger = true
			"crush": danger = t < 0.4 and absf(position.x-hazard.target.x) < 66
			"wave":
				var front: float = hazard.area.end.x+60-t*650
				danger = absf(position.x-front) < 45 and absf(position.y-hazard.lane) > (13 if is_route() else 26)
				guard = sheltered()
			"hoof":
				danger = t < 0.35
				guard = bracing
		if danger and guard:
			hazard.player_hit = true
			feedback.emit("Impacto resistido!","guard")
		elif danger and invulnerable <= 0 and (dash_left <= 0 or hazard.kind in ["hoof","crush"]):
			hazard.player_hit = true
			_hit(hazard.kind)
			if phase == Phase.FAILED: return
	for i in range(hazards.size()-1,-1,-1):
		if hazards[i].age > hazards[i].warning+2.0:
			hazards.remove_at(i)
			resolved_attacks += 1

func _fire_projectiles(hazard: Dictionary) -> void:
	var area: Rect2 = hazard.area
	if hazard.kind == "fan":
		var spacing: float = 19 if is_route() else 35
		var y: float = area.position.y+10
		while y < area.end.y:
			if absf(y-hazard.lane) > (14 if is_route() else 31):
				projectiles.append({"position":Vector2(area.end.x+45,y),"velocity":Vector2(-440,0),"age":0.0,"area":area,"radius":8.0})
			y += spacing
	else:
		var source := Vector2(area.end.x+65,area.position.y-35)
		var aim: Vector2 = (hazard.target-source).normalized()
		for angle in [-0.1,0.0,0.1]:
			projectiles.append({"position":source,"velocity":aim.rotated(angle)*420,"age":0.0,"area":area,"radius":9.0})

func _tick_projectiles(delta: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var shot: Dictionary = projectiles[i]
		shot.position += shot.velocity*delta
		shot.age += delta
		if shot.position.distance_to(position) < shot.radius+10 and invulnerable <= 0 and dash_left <= 0:
			projectiles.remove_at(i)
			_hit("projectile")
			if phase == Phase.FAILED: return
		elif shot.age > 3.0 or shot.position.x < shot.area.position.x-80:
			projectiles.remove_at(i)

func _hit(kind: String) -> void:
	hits += 1
	balance = maxf(0,balance-(42 if kind == "hoof" else 35 if kind == "crush" else 28))
	stagger = 0.45
	invulnerable = 0.9
	dash_left = 0
	velocity = Vector2(-165,15)
	hit_flash = 0.4
	untying = false
	bracing = false
	if balance <= 0: _fail("Você perdeu o equilíbrio e Poseidon bloqueou a fuga.")
	else: feedback.emit("Impacto sofrido! Mude de posição.","hit")

func _sink_specific(index: int) -> void:
	if index < 0 or index >= sunk_at.size() or sunk_at[index] >= 0: return
	sunk_at[index] = clock
	ship_sunk.emit(index)

func _escape() -> void:
	if not wind_window() or not fleet_gone(): return
	velocity = Vector2.ZERO
	wind_progress = 1
	_change(Phase.ESCAPING)
	feedback.emit("Os ventos abriram uma passagem!","escape")

func _save_checkpoint() -> void:
	checkpoint = {"phase":phase,"route":route_index,"act":act_index,"position":position,"sunk":sunk_at.duplicate(),"bag":has_bag,"secured":bag_secured,"progress":bag_progress,"mast":mast_broken,"crate":crate_broken}

func _fail(reason: String) -> void:
	if phase == Phase.FAILED: return
	failure_reason = reason
	velocity = Vector2.ZERO
	airborne = false
	_change(Phase.FAILED)
	failed.emit(reason)

func retry_checkpoint() -> void:
	if phase != Phase.FAILED or checkpoint.is_empty(): return
	retries += 1
	route_index = checkpoint.route
	act_index = checkpoint.act
	position = checkpoint.position
	has_bag = checkpoint.bag
	bag_secured = checkpoint.secured
	bag_progress = checkpoint.progress
	mast_broken = checkpoint.mast
	crate_broken = checkpoint.crate
	for i in 11: sunk_at[i] = clock-WRECK_SECONDS-1 if checkpoint.sunk[i] >= 0 else -1.0
	hazards.clear()
	projectiles.clear()
	velocity = Vector2.ZERO
	stagger = 0
	invulnerable = 0
	balance = 100
	event_index = 0
	gate_open = false
	gate_age = 0
	landing_pause = 0
	dash_left = 0
	dash_cooldown = 0
	wind_progress = 0
	wind_armed = false
	interaction_was_held = false
	rest_clock = 1.0
	_change(checkpoint.phase)

func objective() -> String:
	if phase == Phase.FAILED: return "FUGA INTERROMPIDA · RETOME ESTE TRECHO"
	if phase == Phase.ARRIVAL: return "NAVIO DE ODISSEU · A SEGUNDA PARTE VAI COMEÇAR"
	if is_route(): return "PARTE I · TRAVESSIA  %d / 3" % (route_index+1)
	if phase == Phase.SURVIVAL: return "PARTE II · ATO %d / 3 · %s" % [act_index+1,assaults.acts[act_index].name]
	if phase == Phase.FINAL_ATTACK: return "ÚLTIMO NAVIO · LIBERE OS VENTOS NA ABERTURA"
	return "A FROTA FOI PERDIDA. UM NAVIO ESCAPOU."

func prompt() -> String:
	if stagger > 0: return "RECUPERANDO O EQUILÍBRIO"
	if phase == Phase.TRAVERSAL:
		if airborne: return "SEGURE FIRME!" if route_index == 1 else "SALTO ENTRE EMBARCAÇÕES"
		if gate_open: return ("E · BALANÇAR PELA CORDA" if route_index == 1 else "ESPAÇO · SALTAR PARA O PRÓXIMO NAVIO")+"   ·   %.1fs" % maxf(0,assaults.passage_seconds-gate_age)
		return "ESQUIVE DOS ATAQUES ATÉ O PRÓXIMO NAVIO SE APROXIMAR"
	if phase == Phase.FINAL_ATTACK:
		if wind_window(): return "SOLTE E, ENTÃO SEGURE NOVAMENTE" if interaction_was_held and not wind_armed else "AGORA! SEGURE E PARA LIBERAR OS VENTOS"
		return "VOLTE AO LEME E ESPERE A ABERTURA"
	if phase == Phase.SURVIVAL:
		if not has_bag and position.distance_to(BAG) < 72: return "SEGURE E · SOLTAR AS CORDAS DA BOLSA"
		if act_index == 1 and not bag_secured and position.distance_to(HELM) < 78: return "SEGURE E · PRENDER A BOLSA JUNTO AO LEME"
		if anchor_index() >= 0: return "SEGURE E · AGARRAR A CORDA"
	return ""

func record() -> Dictionary:
	return {"escaped":phase == Phase.COMPLETE,"seconds":snappedf(clock,0.1),"ships_lost":12-fleet_remaining(),"ships_remaining":fleet_remaining(),"hits":hits,"dodges":dodges,"jumps":jumps,"retries":retries,"final_attempts":final_attempts,"attacks_resolved":resolved_attacks,"acts_completed":3 if phase in [Phase.ESCAPING,Phase.COMPLETE] else act_index}
