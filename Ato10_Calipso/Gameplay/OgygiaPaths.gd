extends RefCounted

signal thought(text: String)
signal conversation_requested(key: String)
signal escape_requested(route: int)
signal completed
signal years_elapsed(total: int)

enum Place { SHORE, BENCH, HEADLAND }
enum Beat { SALVAGE, CARVE, CARVED, CAST, DRIFT, RECOVER, PLAN, GRIP_READY, LAUNCH, AT_SEA, REUNION, REPAIR, LEAVE_TOOLS, HEADLAND, COMPLETE }
enum Action { NONE, SALVAGE, WORK, CARRY, WEST, EAST, RECOVER, TELL, REUNION, LEAVE, CLIMB }

const WRECK := Vector2(477, 533)
const HOUSE := Vector2(270, 427)
const CALYPSO := Vector2(360, 440)
const CURRENTS := [Vector2(637, 398), Vector2(930, 365)]
const PATH := Vector2(1005, 555)
const OVERLOOK := Vector2(856, 354)
const SHORE_BOUNDS := Rect2(120, 343, 920, 247)
const HEADLAND_BOUNDS := Rect2(260, 338, 660, 238)
const DRIFT_SECONDS := 7.0
const WORK_SECONDS := 2.8
const BENCH_ACTION_AT := Vector2(576, 516)

var place := Place.SHORE
var beat := Beat.SALVAGE
var position := Vector2(419, 551)
var velocity := Vector2.ZERO
var facing := Vector2.RIGHT
var speed_scale := 1.0
var clock := 0.0
var seasons := 0.0
var oar_condition := -1
var work := 0.0
var told_calypso := false
var cast_route := -1
var escape_route := -1
var drift_age := 0.0
var in_conversation := false
var time_cut := 0.0

var _cut_done := false

func apply_player_stats(stats: Dictionary) -> void:
	speed_scale = clampf(sqrt(maxf(0.0, float(stats.get("speed_mult", 1.0)))), 0.80, 1.25)

func targets() -> Dictionary:
	if in_conversation or place != Place.SHORE:
		return {}
	match beat:
		Beat.SALVAGE: return {Action.SALVAGE: WRECK}
		Beat.CARVE, Beat.REPAIR: return {Action.WORK: HOUSE}
		Beat.CAST, Beat.LAUNCH: return {Action.WEST: CURRENTS[0], Action.EAST: CURRENTS[1]}
		Beat.RECOVER: return {Action.RECOVER: marker_position()}
		Beat.PLAN:
			return {Action.WORK: HOUSE} if told_calypso else {Action.WORK: HOUSE, Action.TELL: CALYPSO}
		Beat.REUNION: return {Action.REUNION: reunion_position()}
		Beat.HEADLAND: return {Action.CLIMB: PATH}
	return {}

func reunion_position() -> Vector2:
	return CURRENTS[1 - escape_route] + Vector2(0, 46) if told_calypso else HOUSE

func nearby_action() -> Action:
	if place == Place.BENCH:
		if beat == Beat.LEAVE_TOOLS: return Action.LEAVE
		if beat in [Beat.CARVED, Beat.GRIP_READY]: return Action.CARRY
		return Action.NONE
	var nearest := 62.0
	var result := Action.NONE
	var points := targets()
	for action: Action in points:
		var distance := position.distance_to(points[action])
		if distance < nearest:
			nearest = distance
			result = action
	return result

func action_position(action: Action) -> Vector2:
	if action in [Action.CARRY, Action.LEAVE]:
		return BENCH_ACTION_AT
	return targets().get(action, position)

func action_label(action: Action) -> String:
	match action:
		Action.SALVAGE: return "RECOLHER A MADEIRA"
		Action.WORK: return "IR À BANCADA"
		Action.CARRY: return "PEGAR O REMO"
		Action.WEST, Action.EAST:
			var side := "ENSEADA" if action == Action.WEST else "PRAIA ABERTA"
			return ("LANÇAR A MADEIRA" if beat == Beat.CAST else "EMPURRAR A EMBARCAÇÃO") + " · " + side
		Action.RECOVER: return "RECOLHER A MADEIRA MARCADA"
		Action.TELL: return "CONTAR O PLANO A CALIPSO"
		Action.REUNION: return "FALAR COM CALIPSO" if told_calypso else "ENTRAR EM CASA"
		Action.LEAVE: return "DEIXAR AS FERRAMENTAS"
		Action.CLIMB: return "SEGUIR PELA TRILHA"
	return ""

func interact() -> void:
	if in_conversation:
		return
	var action := nearby_action()
	match action:
		Action.SALVAGE:
			beat = Beat.CARVE
			thought.emit("Reconheço a marca na madeira. Era do nosso navio.")
		Action.WORK:
			place = Place.BENCH
			work = 0.0
			_cut_done = false
			velocity = Vector2.ZERO
		Action.CARRY:
			beat = Beat.CAST if beat == Beat.CARVED else Beat.LAUNCH
			_to_shore(HOUSE + Vector2(0, 37))
		Action.WEST, Action.EAST:
			var route := 0 if action == Action.WEST else 1
			if beat == Beat.CAST:
				cast_route = route
				drift_age = 0.0
				beat = Beat.DRIFT
				thought.emit("Marquei a madeira. Quero ver para onde essa corrente vai levar.")
			else:
				escape_route = route
				beat = Beat.AT_SEA
				velocity = Vector2.ZERO
				escape_requested.emit(route)
		Action.RECOVER:
			beat = Beat.PLAN
			thought.emit("A mesma marca. A corrente trouxe a madeira pelo outro lado.")
		Action.TELL:
			told_calypso = true
			in_conversation = true
			conversation_requested.emit("plan")
		Action.REUNION:
			in_conversation = true
			conversation_requested.emit("return_shore" if told_calypso else "return_home")
		Action.LEAVE:
			beat = Beat.HEADLAND
			_to_shore(HOUSE + Vector2(-19, 32))
			thought.emit("Hoje eu só quero ouvir o mar longe desta casa.")
		Action.CLIMB:
			place = Place.HEADLAND
			position = Vector2(358, 533)
			velocity = Vector2.ZERO

func finish_conversation() -> void:
	if beat == Beat.REUNION:
		beat = Beat.REPAIR
	in_conversation = false

func return_from_sea() -> void:
	if beat != Beat.AT_SEA:
		return
	beat = Beat.REUNION
	oar_condition = 1
	_to_shore(CURRENTS[1 - escape_route] + Vector2(-37, 81))

func retry_escape() -> void:
	if beat == Beat.AT_SEA:
		beat = Beat.LAUNCH
		_to_shore(CURRENTS[escape_route] + Vector2(0, 70))

func _to_shore(at: Vector2) -> void:
	place = Place.SHORE
	position = at
	velocity = Vector2.ZERO

func marker_position() -> Vector2:
	if cast_route < 0:
		return Vector2.ZERO
	var start: Vector2 = CURRENTS[cast_route] + Vector2(0, -28)
	var other: Vector2 = CURRENTS[1 - cast_route]
	if drift_age <= 3.5:
		var out := smoothstep(0.0, 3.5, drift_age)
		return start.lerp(Vector2(789, 232), out) + Vector2(sin(out * PI) * (-78 if cast_route == 0 else 93), 0)
	var back := smoothstep(3.5, DRIFT_SECONDS, drift_age)
	return Vector2(789, 232).lerp(other + Vector2(8, 1), back) + Vector2(sin(back * PI) * (111 if cast_route == 0 else -104), 0)

func tick(delta: float, movement: Vector2, working: bool) -> void:
	if in_conversation or beat in [Beat.AT_SEA, Beat.COMPLETE]:
		return
	clock += delta
	if beat == Beat.DRIFT:
		drift_age = minf(drift_age + delta, DRIFT_SECONDS)
		if drift_age >= DRIFT_SECONDS:
			beat = Beat.RECOVER
	if place == Place.BENCH:
		_work_at_bench(delta, working)
		return
	velocity = velocity.move_toward(movement.limit_length() * 232.0 * speed_scale, delta * 1850.0)
	if movement.length_squared() > 0.03:
		facing = movement.normalized()
	var bounds := HEADLAND_BOUNDS if place == Place.HEADLAND else SHORE_BOUNDS
	position = (position + velocity * delta).clamp(bounds.position, bounds.end)
	if place == Place.SHORE:
		var beach_edge := lerpf(422.0, 349.0, smoothstep(370.0, 1025.0, position.x))
		if position.x < 255.0:
			beach_edge += 46.0 * (1.0 - smoothstep(128.0, 255.0, position.x))
		position.y = maxf(position.y, beach_edge)
	if place == Place.HEADLAND and position.distance_to(OVERLOOK) < 60.0:
		beat = Beat.COMPLETE
		velocity = Vector2.ZERO
		completed.emit()

func _work_at_bench(delta: float, working: bool) -> void:
	if not can_work():
		return
	if time_cut > 0.0:
		time_cut = maxf(0.0, time_cut - delta)
		var phase_length := 3.45 if beat == Beat.REPAIR else 2.35
		var season_start := 3.0 if beat == Beat.REPAIR else 0.0
		var season_end := 7.0 if beat == Beat.REPAIR else 3.0
		var previous_year := floori(seasons)
		seasons = lerpf(season_start, season_end, smoothstep(0.0, phase_length, phase_length - time_cut))
		if floori(seasons) > previous_year:
			years_elapsed.emit(floori(seasons))
		if beat == Beat.REPAIR and time_cut < 0.96:
			oar_condition = 2
		return
	if not working:
		return
	work = minf(1.0, work + delta / WORK_SECONDS)
	if not _cut_done and beat != Beat.CARVE and work >= 0.48:
		time_cut = 3.45 if beat == Beat.REPAIR else 2.35
		_cut_done = true
		return
	if work >= 1.0:
		match beat:
			Beat.CARVE:
				oar_condition = 0
				beat = Beat.CARVED
			Beat.PLAN:
				beat = Beat.GRIP_READY
			Beat.REPAIR:
				beat = Beat.LEAVE_TOOLS

func can_work() -> bool:
	return place == Place.BENCH and beat in [Beat.CARVE, Beat.PLAN, Beat.REPAIR]
