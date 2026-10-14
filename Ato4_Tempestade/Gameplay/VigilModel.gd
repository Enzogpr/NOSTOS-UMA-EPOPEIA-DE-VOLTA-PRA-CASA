extends RefCounted
## Narrative survival: performance changes the record, never the ninth-day event.
signal day_started(day: int)
signal day_finished(day: int, perfect: bool)
signal ending_started
signal completed(record: Dictionary)
signal feedback(text: String, kind: String)

enum State { READY, PLAYING, DAY_BREAK, ENDING, COMPLETE }
const TOTAL_DAYS: int = 9
const WAKE_START: float = 60.0
const WAKE_END: float = 92.0
const ENDING_SECONDS: float = 12.0
var state: State = State.READY
var day: int = 1
var day_duration: float = 25.0
var day_clock: float = 0.0
var break_clock: float = 0.0
var ending_clock: float = 0.0
var fatigue: float = 12.0
var look_side: int = -1
var wake_cooldown: float = 0.0
var shout_cooldown: float = 0.0
var spawn_clock: float = 5.0
var wake_flash: float = 0.0
var microsleep_flash: float = 0.0
var crew: Array[Dictionary] = []
var perfect_days: Array[int] = []
var day_perfect: bool = true
var prevented: int = 0
var missed: int = 0
var successful_wakes: int = 0
var early_wakes: int = 0
var microsleeps: int = 0
var next_crew_id: int = 0
var bag_sealed: bool = true
var rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

func start() -> void:
	if state != State.READY:
		return
	state = State.PLAYING
	day_started.emit(day)
	feedback.emit("Mantenha a bolsa fechada. Espere os olhos pesarem para despertar.","notice")

func fatigue_rate() -> float:
	return 2.6+float(day)*0.75

func approach_seconds() -> float:
	return maxf(6.2,11.0-float(day)*0.5)

func spawn_interval() -> float:
	return maxf(3.7,8.0-float(day)*0.48)

func day_progress() -> float:
	return clampf(day_clock/day_duration,0.0,1.0)

func night_amount() -> float:
	# Each day passes dawn, afternoon, night, then another dawn.
	return smoothstep(0.30,0.60,day_progress())*(1.0-smoothstep(0.88,1.0,day_progress()))

func vision_amount() -> float:
	if day < 5 or state not in [State.PLAYING,State.ENDING]:
		return 0.0
	var pulse: float = pow(maxf(0.0,sin(day_progress()*PI)),4.0)
	return pulse*clampf((fatigue-38.0)/55.0,0.0,1.0)*(0.28+float(day-5)*0.06)

func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	wake_cooldown = maxf(0.0,wake_cooldown-delta)
	shout_cooldown = maxf(0.0,shout_cooldown-delta)
	wake_flash = maxf(0.0,wake_flash-delta)
	microsleep_flash = maxf(0.0,microsleep_flash-delta)
	match state:
		State.PLAYING:
			day_clock = minf(day_duration,day_clock+delta)
			fatigue = minf(100.0,fatigue+fatigue_rate()*(1.0+night_amount()*0.18)*delta)
			if fatigue >= 100.0:
				microsleeps += 1
				day_perfect = false
				fatigue = 56.0
				microsleep_flash = 0.65
				feedback.emit("Um breve cochilo. Odisseu segura a bolsa e volta a vigiar.","miss")
			_tick_crew(delta)
			spawn_clock -= delta
			if spawn_clock <= 0.0:
				_spawn_crew()
				spawn_clock = spawn_interval()+rng.randf_range(-0.5,0.7)
			if day_clock >= day_duration:
				_finish_day()
		State.DAY_BREAK:
			break_clock += delta
			if break_clock >= 1.65:
				day += 1
				day_clock = 0.0
				day_perfect = true
				fatigue = minf(fatigue,43.0)+2.0
				spawn_clock = 3.6
				state = State.PLAYING
				day_started.emit(day)
		State.ENDING:
			ending_clock = minf(ENDING_SECONDS,ending_clock+delta)
			fatigue = lerpf(70.0,100.0,minf(ending_clock/2.2,1.0))
			bag_sealed = ending_clock < 7.3
			if ending_clock >= ENDING_SECONDS:
				state = State.COMPLETE
				completed.emit(record())

func _tick_crew(delta: float) -> void:
	for index in range(crew.size()-1,-1,-1):
		var visitor: Dictionary = crew[index]
		if visitor.retreating:
			visitor.progress = maxf(0.0,float(visitor.progress)-delta*0.5)
			if float(visitor.progress) <= 0.0:
				crew.remove_at(index)
			continue
		visitor.progress = minf(1.0,float(visitor.progress)+delta/approach_seconds())
		if float(visitor.progress) >= 1.0:
			visitor.retreating = true
			missed += 1
			day_perfect = false
			fatigue = minf(99.0,fatigue+10.0)
			feedback.emit("Perto demais! Odisseu protege a bolsa, mas perde concentração.","miss")

func _spawn_crew() -> void:
	var capacity: int = 1 if day <= 3 else 2
	if crew.size() >= capacity or (day == 9 and day_progress() > 0.72):
		return
	var side: int = -1 if rng.randf() < 0.5 else 1
	for visitor in crew:
		if int(visitor.side) == side:
			side = -side
	var occupied: bool = false
	for visitor in crew:
		occupied = occupied or int(visitor.side) == side
	if occupied:
		return
	crew.append({"id":next_crew_id,"side":side,"progress":0.0,"retreating":false})
	next_crew_id += 1
	feedback.emit("Passos à esquerda." if side < 0 else "Passos à direita.","steps")

func look(side: int) -> void:
	if state == State.PLAYING:
		look_side = -1 if side < 0 else 1

func wake() -> bool:
	if state != State.PLAYING or wake_cooldown > 0.0:
		return false
	wake_cooldown = 0.8
	if fatigue < WAKE_START:
		early_wakes += 1
		fatigue = minf(99.0,fatigue+2.5)
		feedback.emit("Ainda está alerta. Espere os olhos pesarem.","notice")
		return false
	var timely: bool = fatigue <= WAKE_END
	fatigue = maxf(10.0,fatigue-(36.0 if timely else 24.0))
	successful_wakes += 1
	wake_flash = 0.65
	feedback.emit("Odisseu desperta a tempo." if timely else "No último instante!","wake")
	return true

func warn_crew() -> bool:
	if state != State.PLAYING or shout_cooldown > 0.0:
		return false
	var chosen: Dictionary = {}
	for visitor in crew:
		if int(visitor.side) == look_side and not visitor.retreating and float(visitor.progress) >= 0.18:
			if chosen.is_empty() or float(visitor.progress) > float(chosen.progress):
				chosen = visitor
	if chosen.is_empty():
		feedback.emit("Olhe para o tripulante que está se aproximando.","notice")
		return false
	chosen.retreating = true
	shout_cooldown = 1.05
	prevented += 1
	fatigue = minf(99.0,fatigue+3.0)
	feedback.emit("Afaste-se da bolsa!","warn")
	return true

func _finish_day() -> void:
	if day_perfect:
		perfect_days.append(day)
	day_finished.emit(day,day_perfect)
	crew.clear()
	if day == TOTAL_DAYS:
		state = State.ENDING
		ending_started.emit()
	else:
		state = State.DAY_BREAK
		break_clock = 0.0

func record() -> Dictionary:
	return {"days":day,"prevented":prevented,"successful_wakes":successful_wakes,"microsleeps":microsleeps,"missed":missed,"perfect_days":perfect_days.duplicate(),"story_complete":state == State.COMPLETE}
