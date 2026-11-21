extends RefCounted

signal checkpoint_reached(index: int)
signal rest_reached
signal mother_heard
signal feedback(text: String)
signal cue(kind: String)
signal completed
signal failed
signal dialogue_requested(key: String)

enum Phase { READY, ACTIVE, REST, MEMORY, COMPLETE, FAILED }
enum Obstacle { DEBRIS, PILLAR, LINTEL }
enum Move { NONE, JUMP, SLIDE }

const FINISH := 1410.0
const CHECKPOINTS := [0.0, 310.0, 720.0]
const FALSE_ARCHES := [200.0, 594.0]
const JUMP_DURATION := 0.8
const SLIDE_DURATION := 0.62
const MOVE_BUFFER := 0.14
# Each entry contains its distance, a bit mask for the left/middle/right lanes and its obstacle type.
const COURSE := [
	[42.0, 2, Obstacle.DEBRIS], [81.0, 1, Obstacle.PILLAR], [113.0, 4, Obstacle.PILLAR],
	[147.0, 3, Obstacle.LINTEL], [181.0, 6, Obstacle.PILLAR], [221.0, 7, Obstacle.DEBRIS],
	[257.0, 7, Obstacle.LINTEL], [287.0, 2, Obstacle.DEBRIS],
	[349.0, 1, Obstacle.DEBRIS], [382.0, 3, Obstacle.PILLAR], [416.0, 4, Obstacle.DEBRIS],
	[449.0, 6, Obstacle.PILLAR], [484.0, 7, Obstacle.DEBRIS], [516.0, 5, Obstacle.PILLAR],
	[550.0, 7, Obstacle.LINTEL], [584.0, 6, Obstacle.DEBRIS], [618.0, 3, Obstacle.PILLAR],
	[650.0, 7, Obstacle.DEBRIS], [684.0, 7, Obstacle.LINTEL],
	[756.0, 2, Obstacle.PILLAR], [778.0, 5, Obstacle.PILLAR], [806.0, 7, Obstacle.LINTEL],
	[838.0, 7, Obstacle.DEBRIS], [859.0, 6, Obstacle.PILLAR], [888.0, 3, Obstacle.LINTEL],
	[911.0, 5, Obstacle.PILLAR], [941.0, 7, Obstacle.DEBRIS], [973.0, 7, Obstacle.LINTEL],
	[994.0, 6, Obstacle.PILLAR], [1019.0, 3, Obstacle.DEBRIS], [1042.0, 5, Obstacle.PILLAR],
	[1070.0, 7, Obstacle.LINTEL], [1102.0, 7, Obstacle.DEBRIS], [1124.0, 3, Obstacle.PILLAR],
	[1147.0, 6, Obstacle.PILLAR], [1172.0, 2, Obstacle.DEBRIS], [1200.0, 7, Obstacle.LINTEL],
	[1232.0, 7, Obstacle.DEBRIS], [1254.0, 6, Obstacle.PILLAR], [1279.0, 5, Obstacle.PILLAR],
	[1305.0, 3, Obstacle.LINTEL], [1331.0, 7, Obstacle.DEBRIS], [1363.0, 7, Obstacle.LINTEL],
	[1384.0, 6, Obstacle.PILLAR],
]
const MESSAGES := {
	84.0: "A passagem parece próxima.",
	151.0: "A culpa estica o caminho diante dele.",
	537.0: "As almas se aproximam. A margem se afasta.",
	1285.0: "Desta vez, a luz permanece no lugar.",
}

var level: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Ato6_Submundo/Gameplay/UnderworldLevel.json"))
var phase := Phase.READY
var distance := 0.0
var clock := 0.0
var checkpoint := 0
var heard_mother := false
var target_lane := 0
var lane := 0.0
var pressure := 22.0
var stretch := 0.0
var jump_elapsed := JUMP_DURATION
var slide_time := 0.0
var queued_move := Move.NONE
var stumble_time := 0.0
var dash_time := 0.0
var dash_recharge := 0.0
var speed_mult := 1.0
var intellect := 5
var dash_cooldown := 3.0
var next_obstacle := 0

func apply_player_stats(stats: Dictionary) -> void:
	speed_mult = maxf(0.3, float(stats.get("speed_mult", speed_mult)))
	dash_cooldown = maxf(0.5, float(stats.get("dash_cooldown", dash_cooldown)))
	intellect = int(stats.get("intellect", intellect))

func resume(index: int, heard: bool) -> void:
	checkpoint = clampi(index, 0, CHECKPOINTS.size() - 1)
	heard_mother = heard
	_reset_run_state()

func _reset_run_state() -> void:
	distance = CHECKPOINTS[checkpoint]
	lane = 0.0
	target_lane = 0
	pressure = 22.0 + checkpoint * 7.0
	stretch = 0.0
	clock = 0.0
	jump_elapsed = JUMP_DURATION
	slide_time = 0.0
	queued_move = Move.NONE
	stumble_time = 0.0
	dash_time = 0.0
	dash_recharge = 0.0
	next_obstacle = 0
	while next_obstacle < COURSE.size() and COURSE[next_obstacle][0] < distance:
		next_obstacle += 1

func begin() -> void:
	if phase != Phase.READY:
		return
	if checkpoint == 2 and not heard_mother:
		_enter_rest()
	else:
		phase = Phase.ACTIVE

func change_lane(direction: int) -> void:
	if phase == Phase.ACTIVE:
		target_lane = clampi(target_lane + direction, -1, 1)

func request_jump() -> void:
	_request_move(Move.JUMP)

func request_slide() -> void:
	_request_move(Move.SLIDE)

func _request_move(move: Move) -> void:
	if phase != Phase.ACTIVE:
		return
	if jump_elapsed >= JUMP_DURATION and slide_time <= 0.0:
		_start_move(move)
	elif move == Move.JUMP and slide_time > 0.0 and slide_time <= MOVE_BUFFER:
		queued_move = move
	elif move == Move.SLIDE and jump_elapsed >= JUMP_DURATION - MOVE_BUFFER and jump_elapsed < JUMP_DURATION:
		queued_move = move

func _start_move(move: Move) -> void:
	queued_move = Move.NONE
	if move == Move.JUMP:
		jump_elapsed = 0.0
	else:
		slide_time = SLIDE_DURATION
		cue.emit("slide")

func jump_height() -> float:
	return sin(clampf(jump_elapsed / JUMP_DURATION, 0.0, 1.0) * PI)

func request_dash() -> void:
	if phase != Phase.ACTIVE or dash_recharge > 0.0:
		return
	dash_time = 0.32
	dash_recharge = dash_cooldown
	pressure = maxf(0.0, pressure - 11.0)
	cue.emit("dash")

func forward_speed() -> float:
	var progress := clampf(distance / FINISH, 0.0, 1.0)
	var pace := lerpf(26.0, 48.0, progress) * pow(clampf(speed_mult, 0.3, 2.0), 0.28)
	return pace * (0.61 if stumble_time > 0.0 else 1.0) * (1.37 if dash_time > 0.0 else 1.0)

func apparent_gap(gap: float) -> float:
	# Close hazards stay predictable. Guilt opens up space in the middle distance.
	return gap + stretch * 185.0 * smoothstep(9.0, 108.0, gap)

func _distortion_target() -> float:
	var distortion := 0.0
	for arch in FALSE_ARCHES:
		var remaining: float = arch - distance
		var wave := (1.0 - smoothstep(31.0, 105.0, remaining)) * smoothstep(-8.0, 15.0, remaining)
		distortion = maxf(distortion, wave * 0.85)
	var relief := 1.0 - smoothstep(FINISH - 152.0, FINISH - 30.0, distance)
	return clampf(distortion + pressure / 100.0 * 0.25, 0.0, 1.0) * relief

func tick(delta: float) -> void:
	if phase != Phase.ACTIVE:
		return
	clock += delta
	lane = move_toward(lane, float(target_lane), delta * 6.8)
	jump_elapsed = minf(JUMP_DURATION, jump_elapsed + delta)
	slide_time = maxf(0.0, slide_time - delta)
	if queued_move != Move.NONE and jump_elapsed >= JUMP_DURATION and slide_time <= 0.0:
		_start_move(queued_move)
	stumble_time = maxf(0.0, stumble_time - delta)
	dash_time = maxf(0.0, dash_time - delta)
	dash_recharge = maxf(0.0, dash_recharge - delta)
	var previous := distance
	distance = minf(FINISH, distance + forward_speed() * delta)
	var baseline := clampf(31.0 + checkpoint * 7.0 - (intellect - 5) * 0.28, 22.0, 51.0)
	pressure = move_toward(pressure, baseline, delta * (2.8 if pressure > baseline else 1.7))
	stretch = move_toward(stretch, _distortion_target(), delta * 1.8)

	for threshold: float in MESSAGES:
		if previous < threshold and distance >= threshold:
			feedback.emit(MESSAGES[threshold])

	while next_obstacle < COURSE.size() and COURSE[next_obstacle][0] <= distance:
		var row: Array = COURSE[next_obstacle]
		next_obstacle += 1
		if _hits(row):
			pressure = minf(100.0, pressure + 32.0)
			stumble_time = 0.62
			cue.emit("hit")
			if pressure >= 100.0:
				phase = Phase.FAILED
				cue.emit("lost")
				failed.emit()
				return

	if checkpoint + 1 < CHECKPOINTS.size() and distance >= CHECKPOINTS[checkpoint + 1]:
		checkpoint += 1
		pressure = 22.0 + checkpoint * 7.0
		checkpoint_reached.emit(checkpoint)
		cue.emit("checkpoint")
		if checkpoint == 2:
			distance = CHECKPOINTS[checkpoint]
			_enter_rest()
			return
		feedback.emit("A lanterna marca um ponto seguro.")

	if distance >= FINISH:
		phase = Phase.COMPLETE
		completed.emit()

func _hits(row: Array) -> bool:
	if row[2] == Obstacle.DEBRIS and jump_height() > 0.42:
		return false
	if row[2] == Obstacle.LINTEL and slide_time > 0.0:
		return false
	for index in 3:
		if (int(row[1]) & (1 << index)) != 0 and absf(lane - (index - 1)) < 0.55:
			return true
	return false

func _enter_rest() -> void:
	jump_elapsed = JUMP_DURATION
	slide_time = 0.0
	queued_move = Move.NONE
	phase = Phase.REST
	rest_reached.emit()

func leave_rest() -> void:
	if phase == Phase.REST:
		phase = Phase.ACTIVE

func request_interact() -> void:
	if phase == Phase.REST:
		phase = Phase.MEMORY
		dialogue_requested.emit("mother")

func finish_dialogue(key: String) -> void:
	if key == "mother" and phase == Phase.MEMORY:
		heard_mother = true
		mother_heard.emit()
		phase = Phase.REST

func retry() -> void:
	_reset_run_state()
	phase = Phase.ACTIVE
