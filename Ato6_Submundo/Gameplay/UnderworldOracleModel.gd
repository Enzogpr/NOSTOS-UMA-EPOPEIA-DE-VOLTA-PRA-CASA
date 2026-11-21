extends "res://Ato6_Submundo/Gameplay/UnderworldActorModel.gd"

signal vision_completed(index: int)

var level: Dictionary
var puzzle := 0
var room: Dictionary
var ground: Array[Rect2] = []
var bridges: Array[Rect2] = []
var pads := PackedVector2Array()
var pad_actors := PackedInt32Array()
var activated: Array[bool] = []
var sequence_step := 0
var sequence_deadline := 0.0
var last_stable := Vector2.ZERO
var prophet: Vector2
var conclusion_pending := false

var history: Array[Dictionary] = []
var echoes: Array[Dictionary] = []
var recording_clock := 0.0
var sample_clock := 0.0
var echo_interval := 2.4
var seal_charge := 0.0
var proof_progress := 0.0

func _init() -> void:
	level = JSON.parse_string(FileAccess.get_file_as_string("res://Ato6_Submundo/Gameplay/UnderworldLevel.json"))
	prophet = Vector2(level.prophet[0], level.prophet[1])
	resume(0)

func proof_count() -> int:
	return level.puzzles.size()

func resume(index: int) -> void:
	puzzle = clampi(index, 0, proof_count())
	room = level.puzzles[mini(puzzle, proof_count() - 1)]
	ground.clear()
	bridges.clear()
	pads.clear()
	pad_actors.clear()
	for bounds in room.floor:
		ground.append(Rect2(bounds[0], bounds[1], bounds[2], bounds[3]))
	for bounds in room.get("bridges", []):
		bridges.append(Rect2(bounds[0], bounds[1], bounds[2], bounds[3]))
	for entry in room.pads:
		pads.append(Vector2(entry[0], entry[1]))
		pad_actors.append(int(entry[2]))
	var spawn: Array = room.goal if puzzle == proof_count() else room.start
	position = Vector2(spawn[0], spawn[1])
	last_stable = position
	velocity = Vector2.ZERO
	movement = Vector2.ZERO
	dash_time = 0.0
	_update_interval()
	_reset_recording()

func apply_player_stats(stats: Dictionary) -> void:
	var old_speed := speed_mult
	super.apply_player_stats(stats)
	_update_interval()
	if absf(old_speed - speed_mult) > 0.001:
		_reset_recording()
		if not walkable(position): position = last_stable
		feedback.emit("O intervalo dos ecos acompanha o seu ritmo.")

func _update_interval() -> void:
	echo_interval = maxf(float(level.echo_delay), 1.1 + float(room.get("reach", 230.0)) / (SPEED * speed_mult))

func _reset_recording() -> void:
	history.clear()
	echoes.clear()
	recording_clock = 0.0
	sample_clock = 0.0
	seal_charge = 0.0
	proof_progress = 0.0
	sequence_step = 0
	sequence_deadline = 0.0
	activated.resize(pads.size())
	activated.fill(false)

func bridge_open(index: int) -> bool:
	return puzzle >= proof_count() or activated[int(room.bridges[index][4])]

func floor_rects() -> Array[Rect2]:
	var floor := ground.duplicate()
	for i in bridges.size():
		if bridge_open(i): floor.append(bridges[i])
	return floor

func walkable(at: Vector2) -> bool:
	return _supported(at, floor_rects())

func _supported(at: Vector2, floor: Array[Rect2]) -> bool:
	for offset in [Vector2.ZERO, Vector2(RADIUS, 0), Vector2(-RADIUS, 0), Vector2(0, RADIUS), Vector2(0, -RADIUS)]:
		var supported := false
		for rectangle in floor:
			if rectangle.has_point(at + offset):
				supported = true
				break
		if not supported: return false
	return true

func tick(delta: float) -> void:
	if phase != Phase.ACTIVE: return
	clock += delta
	recording_clock += delta
	braced = false
	move_actor(delta)
	_record_path(delta)
	if puzzle >= proof_count(): return
	for i in pads.size():
		var actor := pad_actors[i]
		if actor == 0:
			activated[i] = position.distance_to(pads[i]) < 27.0
		else:
			activated[i] = actor <= echoes.size() and Vector2(echoes[actor - 1].p).distance_to(pads[i]) < 27.0
	if _supported(position, ground):
		last_stable = position
	elif not walkable(position):
		position = last_stable
		velocity = Vector2.ZERO
		dash_time = 0.0
		feedback.emit("A ponte cedeu. Deixe seu eco mais tempo no selo.")
	if _solved(delta):
		puzzle += 1
		phase = Phase.MEMORY
		velocity = Vector2.ZERO
		cue.emit("vision")
		vision_completed.emit(puzzle)
		dialogue_requested.emit("vision_%d" % puzzle)

func _record_path(delta: float) -> void:
	sample_clock -= delta
	if sample_clock <= 0.0:
		sample_clock += 1.0 / 30.0
		history.append({"t": recording_clock, "p": position, "f": facing, "moving": velocity.length() > 15.0})
	while history.size() > 2 and history[1].t < recording_clock - echo_interval * 2.0 - 1.0:
		history.pop_front()
	echoes.clear()
	for i in (2 if pad_actors.has(2) else 1):
		var echo := sample_at(recording_clock - echo_interval * (i + 1))
		if echo.is_empty(): break
		if room.has("mirror"):
			echo.p = Vector2(float(room.mirror) * 2.0 - echo.p.x, echo.p.y)
			echo.f = Vector2(-echo.f.x, echo.f.y)
		echoes.append(echo)

func _solved(delta: float) -> bool:
	match room.rule:
		"cross":
			proof_progress = float(activated.count(true)) / pads.size()
			return position.distance_to(Vector2(room.goal[0], room.goal[1])) < 29.0
		"sequence":
			if recording_clock > sequence_deadline: sequence_step = 0
			if activated[sequence_step]:
				sequence_step += 1
				sequence_deadline = recording_clock + echo_interval * 1.25
			proof_progress = float(sequence_step) / pads.size()
			return sequence_step == pads.size()
		"together":
			var required := maxf(0.22, 0.42 - (intellect - 5) * 0.009)
			seal_charge = seal_charge + delta if not activated.has(false) else maxf(0, seal_charge - delta * 2.0)
			proof_progress = seal_charge / required
			return seal_charge >= required
	return false

func sample_at(time: float) -> Dictionary:
	if history.is_empty() or time < history.front().t: return {}
	for i in range(1, history.size()):
		if float(history[i].t) >= time:
			var a := history[i - 1]
			var b := history[i]
			var ratio := clampf((time - float(a.t)) / maxf(0.0001, float(b.t) - float(a.t)), 0, 1)
			return {"p": Vector2(a.p).lerp(b.p, ratio), "f": a.f, "moving": a.moving}
	return {"p": history.back().p, "f": history.back().f, "moving": history.back().moving}

func request_interact() -> void:
	if phase != Phase.ACTIVE: return
	if puzzle >= proof_count() and position.distance_to(prophet) < 75.0:
		conclusion_pending = true
		phase = Phase.MEMORY
		velocity = Vector2.ZERO
		dialogue_requested.emit("prophet")
	elif puzzle < proof_count():
		feedback.emit(room.hint)

func finish_dialogue(key: String) -> void:
	if key == "prophet" and conclusion_pending:
		phase = Phase.COMPLETE
		completed.emit()
		return
	if puzzle < proof_count(): resume(puzzle)
	else: _reset_recording()
	super.finish_dialogue(key)

func retry() -> void:
	retries += 1
	dash_recharge = 0.0
	resume(puzzle)
	phase = Phase.ACTIVE
	feedback.emit("Os ecos desta prova se dissiparam.")

func prompt() -> String:
	if puzzle >= proof_count():
		return "E · OUVIR TIRÉSIAS" if position.distance_to(prophet) < 75.0 else "ALCANCE O PROFETA"
	return "E · DICA DA PROVA"
