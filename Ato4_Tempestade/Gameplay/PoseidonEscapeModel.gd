extends RefCounted
## Deck movement and attack rules are independent of rendering and campaign health.
signal feedback(text: String, kind: String)
signal phase_changed
signal attack_started(kind: String)
signal impact(kind: String)
signal ship_sunk(index: int)
signal completed(record: Dictionary)

enum Phase { READY, APPROACH, FREE_BAG, RETURN, FINAL_ATTACK, ESCAPING, COMPLETE }
const START := Vector2(215,535)
const BAG := Vector2(998,470)
const HELM := Vector2(190,464)
const MAST := Vector2(574,426)
const COVER := Rect2(429,438,145,104)
const ANCHORS := [Vector2(248,478),Vector2(529,469),Vector2(851,547)]
const WALK_AREA := Rect2(100,405,960,178)
const UNTIE_SECONDS := 3.4
const WIND_SECONDS := 0.85
const WIND_OPEN := 8.0
const WIND_CLOSE := 10.8
const FINAL_IMPACT := 11.5
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
var wind_progress: float = 0.0
var wind_armed: bool = false
var interaction_was_held: bool = false
var hazards: Array[Dictionary] = []
var sunk_at: Array[float] = []
var hits: int = 0
var dodges: int = 0
var final_attempts: int = 0
var completion_count: int = 0
var attack_count: int = 0
var next_attack: float = 2.8
var combo_due: float = -1.0
var final_sink_due: float = 0.7
var hit_flash: float = 0.0
var impact_flash: float = 0.0
var rng := RandomNumberGenerator.new()

func _init(random_seed: int = 614) -> void:
	rng.seed = random_seed
	for i in 11: sunk_at.append(-1.0)

func start() -> void:
	if phase != Phase.READY: return
	_change(Phase.APPROACH)
	feedback.emit("A bolsa está na proa. Atravesse o convés!","notice")

func _change(value: Phase) -> void:
	phase = value
	phase_clock = 0.0
	phase_changed.emit()

func active() -> bool:
	return phase in [Phase.APPROACH,Phase.FREE_BAG,Phase.RETURN,Phase.FINAL_ATTACK]

func fleet_remaining() -> int:
	var count: int = 12
	for time in sunk_at:
		if time >= 0.0: count -= 1
	return count

func anchor_index() -> int:
	for i in ANCHORS.size():
		if position.distance_to(ANCHORS[i]) < 63.0: return i
	return -1

func sheltered() -> bool:
	return COVER.has_point(position)

func wind_window() -> bool:
	return phase == Phase.FINAL_ATTACK and phase_clock >= WIND_OPEN and phase_clock < WIND_CLOSE

func tick(delta: float, direction := Vector2.ZERO, interact: bool = false, dash: bool = false) -> void:
	# Substeps keep moving fronts and interaction timing stable at low frame rates.
	var remaining: float = maxf(0.0,delta)
	while remaining > 0.00001:
		var step: float = minf(remaining,0.025)
		_step(step,direction.limit_length(),interact,dash)
		dash = false
		remaining -= step

func _step(delta: float, direction: Vector2, interact: bool, dash: bool) -> void:
	if phase in [Phase.READY,Phase.COMPLETE]: return
	var just_interacted: bool = interact and not interaction_was_held
	interaction_was_held = interact
	if not interact: wind_armed = false
	clock += delta
	phase_clock += delta
	hit_flash = maxf(0.0,hit_flash-delta)
	impact_flash = maxf(0.0,impact_flash-delta)
	if phase == Phase.ESCAPING:
		if phase_clock >= 6.6:
			_change(Phase.COMPLETE)
			completion_count += 1
			completed.emit(record())
		return
	invulnerable = maxf(0.0,invulnerable-delta)
	stagger = maxf(0.0,stagger-delta)
	dash_cooldown = maxf(0.0,dash_cooldown-delta)
	dash_left = maxf(0.0,dash_left-delta)
	bracing = false
	untying = false
	var at_bag: bool = position.distance_to(BAG) < 75.0 and not has_bag
	var at_helm: bool = position.distance_to(HELM) < 82.0 and has_bag
	if dash and dash_cooldown <= 0.0 and stagger <= 0.0 and phase != Phase.FINAL_ATTACK:
		dash_left = 0.22
		dash_cooldown = 1.0
		dash_direction = direction.normalized() if direction.length() > 0.1 else Vector2(facing,0)
		dodges += 1
		feedback.emit("","dodge")
	if stagger > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO,delta*520)
	elif dash_left > 0.0:
		velocity = dash_direction*(450.0 if has_bag else 540.0)
	elif interact:
		velocity = Vector2.ZERO
		if at_bag:
			if phase == Phase.APPROACH: _change(Phase.FREE_BAG)
			untying = true
			bag_progress = minf(1.0,bag_progress+delta/UNTIE_SECONDS)
			if bag_progress >= 1.0:
				has_bag = true
				untying = false
				_change(Phase.RETURN)
				feedback.emit("Bolsa recuperada! Leve-a até Euríloco, no leme.","bag")
		elif at_helm and phase == Phase.RETURN:
			_begin_final()
		elif at_helm and wind_window():
			if just_interacted: wind_armed = true
			if wind_armed: wind_progress += delta/WIND_SECONDS
			if wind_progress >= 1.0:
				_escape()
		elif anchor_index() >= 0:
			bracing = true
	else:
		var target: Vector2 = direction*(172.0 if has_bag else 216.0)
		velocity = velocity.move_toward(target,delta*1350)
	if phase == Phase.ESCAPING: return
	if not interact or stagger > 0.0 or not at_helm or not wind_window():
		wind_progress = maxf(0.0,wind_progress-delta*1.2)
	if absf(velocity.x) > 12: facing = signf(velocity.x)
	_move(velocity*delta)
	if stagger <= 0.0: balance = minf(100.0,balance+delta*7.0)
	if phase == Phase.FINAL_ATTACK:
		_final_tick()
	else:
		next_attack -= delta
		if next_attack <= 0.0:
			var pattern := ["jets","sweep","hoof","jets"]
			spawn_attack(pattern[attack_count%pattern.size()])
			attack_count += 1
			next_attack = 5.5 if phase == Phase.APPROACH else 4.9
			if phase == Phase.RETURN and attack_count%4 == 0: combo_due = clock+0.75
		if combo_due > 0.0 and clock >= combo_due:
			spawn_attack("jets")
			combo_due = -1.0
	_tick_hazards(delta)

func _move(offset: Vector2) -> void:
	position += offset
	position.x = clampf(position.x,WALK_AREA.position.x,WALK_AREA.end.x)
	position.y = clampf(position.y,WALK_AREA.position.y,WALK_AREA.end.y)
	# Mast footprint: slide around its base rather than crossing solid timber.
	var relative: Vector2 = (position-MAST)/Vector2(58,30)
	if relative.length() < 1.0:
		if relative.length() < 0.001: relative = Vector2.DOWN
		position = MAST+relative.normalized()*Vector2(58,30)
		if position.y < WALK_AREA.position.y:
			position.y = WALK_AREA.position.y
			var side: float = signf(relative.x) if absf(relative.x) > 0.01 else -facing
			position.x = MAST.x+side*sqrt(1.0-pow((position.y-MAST.y)/30.0,2))*58.0

func spawn_attack(kind: String) -> void:
	var warning: float = 3.25 if kind == "hoof" else 3.5 if kind == "sweep" else 1.3
	var points: Array[Vector2] = [position]
	for i in 2:
		points.append(Vector2(rng.randf_range(300,990),rng.randf_range(430,555)))
	hazards.append({"kind":kind,"age":0.0,"warning":warning,"points":points,"player_hit":false,"fleet_hit":false})
	attack_started.emit(kind)
	feedback.emit("ATRÁS DO MASTRO! A água vai varrer o convés." if kind == "sweep" else "AGARRE UMA CORDA! Segure E junto de um ponto marcado." if kind == "hoof" else "SAIA DAS MARCAS! Jatos de água estão subindo.","warning")

func _tick_hazards(delta: float) -> void:
	for hazard in hazards:
		hazard.age += delta
		var t: float = hazard.age-hazard.warning
		if t < 0.0: continue
		if not hazard.fleet_hit:
			hazard.fleet_hit = true
			_sink_one(9)
			impact.emit(hazard.kind)
			impact_flash = 0.28
		if hazard.player_hit: continue
		var dangerous: bool = false
		var protected: bool = false
		match str(hazard.kind):
			"jets":
				if t < 0.65:
					for point in hazard.points:
						if position.distance_to(point) < 53: dangerous = true
			"sweep":
				var front: float = 1230.0-t*1500.0
				dangerous = position.x > front-38 and position.x < front+85
				protected = sheltered()
			"hoof":
				dangerous = t < 0.4
				protected = bracing
		if dangerous and protected:
			hazard.player_hit = true
			feedback.emit("Você resistiu ao impacto.","guard")
		elif dangerous and dash_left <= 0.0 and invulnerable <= 0.0:
			hazard.player_hit = true
			_hit(str(hazard.kind))
	for i in range(hazards.size()-1,-1,-1):
		if hazards[i].age > hazards[i].warning+1.4: hazards.remove_at(i)

func _hit(kind: String) -> void:
	hits += 1
	var power: float = 46.0 if kind == "hoof" else 34.0
	balance = maxf(0.0,balance-power)
	stagger = 1.65 if balance <= 0.0 else 0.66
	if balance <= 0.0: balance = 24.0
	invulnerable = stagger+0.5
	dash_left = 0.0
	velocity = Vector2(-210,38) if kind != "jets" else Vector2(-115,80)
	hit_flash = 0.45
	untying = false
	bracing = false
	feedback.emit("O impacto te arrastou! Recupere o equilíbrio.","hit")

func _sink_one(limit: int = 11) -> void:
	var sunk: int = 12-fleet_remaining()
	if sunk >= limit: return
	sunk_at[sunk] = clock
	ship_sunk.emit(sunk)

func _begin_final() -> void:
	hazards.clear()
	combo_due = -1.0
	wind_progress = 0.0
	wind_armed = false
	final_sink_due = 0.7
	final_attempts += 1
	_change(Phase.FINAL_ATTACK)
	feedback.emit("Poseidon está preparando o golpe final. Espere uma abertura!","final")

func _final_tick() -> void:
	if phase_clock >= final_sink_due and fleet_remaining() > 1:
		_sink_one()
		final_sink_due += 0.64
	if phase_clock >= FINAL_IMPACT:
		_hit("hoof")
		impact.emit("hoof")
		wind_progress = 0.0
		_change(Phase.RETURN)
		next_attack = 4.0
		feedback.emit("A onda fechou a passagem! Volte ao leme para tentar outra abertura.","hit")

func _escape() -> void:
	if phase != Phase.FINAL_ATTACK or not wind_window(): return
	while fleet_remaining() > 1: _sink_one()
	hazards.clear()
	velocity = Vector2.ZERO
	wind_progress = 1.0
	_change(Phase.ESCAPING)
	feedback.emit("Os ventos abriram uma passagem!","escape")

func objective() -> String:
	match phase:
		Phase.READY,Phase.APPROACH: return "1 / 3   ALCANCE A BOLSA NA PROA"
		Phase.FREE_BAG: return "1 / 3   SOLTE A BOLSA DOS DESTROÇOS"
		Phase.RETURN: return "2 / 3   LEVE A BOLSA ATÉ O LEME"
		Phase.FINAL_ATTACK: return "3 / 3   LIBERE OS VENTOS NA ABERTURA"
		_: return "A FROTA FOI PERDIDA. UM NAVIO ESCAPOU."

func prompt() -> String:
	if stagger > 0.0: return "RECUPERANDO O EQUILÍBRIO"
	if phase == Phase.FINAL_ATTACK:
		if wind_window():
			if interaction_was_held and not wind_armed: return "SOLTE E, ENTÃO SEGURE NOVAMENTE PARA LIBERAR OS VENTOS"
			return "AGORA! SEGURE E PARA LIBERAR OS VENTOS"
		return "ESPERE A ONDA ABRIR UMA PASSAGEM"
	if has_bag and position.distance_to(HELM) < 82: return "SEGURE E · PREPARAR A FUGA"
	if not has_bag and position.distance_to(BAG) < 75: return "SEGURE E · SOLTAR AS CORDAS DA BOLSA"
	if anchor_index() >= 0: return "SEGURE E · AGARRAR A CORDA"
	return ""

func record() -> Dictionary:
	return {"escaped":phase == Phase.COMPLETE,"seconds":snappedf(clock,0.1),"ships_lost":12-fleet_remaining(),"ships_remaining":fleet_remaining(),"hits":hits,"dodges":dodges,"final_attempts":final_attempts}
