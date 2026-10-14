extends RefCounted
## Real losses before day nine; its inevitable loss opens the inner monologue.
signal day_started(day: int)
signal day_finished(day: int, perfect: bool)
signal failed(reason: String)
signal ending_started
signal completed(record: Dictionary)
signal feedback(text: String, kind: String)

enum State { READY, PLAYING, DAY_BREAK, FAILED, ENDING, COMPLETE }
const TOTAL_DAYS: int = 9
const WAKE_START: float = 60.0
const WAKE_END: float = 92.0
const FATIGUE_RATES := [3.2,4.2,5.5,7.0,8.8,10.9,13.6,16.8,22.0]
const APPROACH_TIMES := [11.0,10.2,9.0,7.8,6.6,5.4,4.4,3.6,2.6]
const SPAWN_INTERVALS := [8.0,7.3,6.6,5.8,5.0,4.2,3.5,2.9,1.8]
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
var crew: Array[Dictionary] = []
var perfect_days: Array[int] = []
var day_perfect: bool = true
var days_completed: int = 0
var prevented: int = 0
var missed: int = 0
var successful_wakes: int = 0
var early_wakes: int = 0
var next_crew_id: int = 0
var bag_sealed: bool = true
var loss_reason: String = ""
var rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	if seed_value == 0: rng.randomize()
	else: rng.seed = seed_value

func start() -> void:
	if state != State.READY: return
	state = State.PLAYING
	day_started.emit(day)
	feedback.emit("Desperte antes de afastar a tripulação. Dormir ou deixar alguém chegar à bolsa encerra a vigília.","notice")

func fatigue_rate() -> float:
	var rate: float = FATIGUE_RATES[clampi(day-1,0,8)]
	# At day nine the rate overtakes even the maximum recovery per cooldown.
	return rate+120.0*pow(day_progress(),2.2) if day == 9 else rate

func approach_seconds() -> float:
	return APPROACH_TIMES[clampi(day-1,0,8)]

func spawn_interval() -> float:
	return SPAWN_INTERVALS[clampi(day-1,0,8)]

func day_progress() -> float:
	return clampf(day_clock/day_duration,0.0,1.0)

func night_amount() -> float:
	return smoothstep(0.30,0.60,day_progress())*(1.0-smoothstep(0.88,1.0,day_progress()))

func is_sleepy() -> bool:
	return fatigue >= WAKE_START

func vision_amount() -> float:
	if day < 5 or state != State.PLAYING: return 0.0
	return pow(maxf(0.0,sin(day_progress()*PI)),4.0)*clampf((fatigue-38.0)/55.0,0.0,1.0)*(0.28+float(day-5)*0.06)

func tick(delta: float) -> void:
	if delta <= 0.0: return
	wake_cooldown = maxf(0.0,wake_cooldown-delta)
	shout_cooldown = maxf(0.0,shout_cooldown-delta)
	wake_flash = maxf(0.0,wake_flash-delta)
	match state:
		State.PLAYING:
			day_clock = minf(day_duration,day_clock+delta)
			fatigue = minf(100.0,fatigue+fatigue_rate()*(1.0+night_amount()*0.18)*delta)
			if fatigue >= 100.0:
				_lose("sono")
				return
			_tick_crew(delta)
			if state != State.PLAYING: return
			spawn_clock -= delta
			if spawn_clock <= 0.0:
				_spawn_crew()
				spawn_clock = spawn_interval()+rng.randf_range(-0.2,0.3)
			if day_clock >= day_duration:
				if day == 9:
					fatigue = 100.0
					_lose("sono")
				else: _finish_day()
		State.DAY_BREAK:
			break_clock += delta
			if break_clock >= 1.65:
				day += 1
				day_clock = 0.0
				day_perfect = true
				# Dawn never restores alertness automatically.
				spawn_clock = minf(3.6,spawn_interval())
				state = State.PLAYING
				day_started.emit(day)
		State.ENDING:
			ending_clock += delta

func _tick_crew(delta: float) -> void:
	for index in range(crew.size()-1,-1,-1):
		var visitor: Dictionary = crew[index]
		if visitor.retreating:
			visitor.progress = maxf(0.0,float(visitor.progress)-delta*0.7)
			if float(visitor.progress) <= 0.0: crew.remove_at(index)
			continue
		visitor.progress = minf(1.0,float(visitor.progress)+delta/approach_seconds())
		if float(visitor.progress) >= 1.0:
			missed += 1
			_lose("bolsa")
			return

func _spawn_crew() -> void:
	var capacity: int = 1 if day < 3 else 2
	if crew.size() >= capacity: return
	var side: int = -1 if rng.randf() < 0.5 else 1
	for visitor in crew:
		if int(visitor.side) == side: side = -side
	for visitor in crew:
		if int(visitor.side) == side: return
	var pair_chance: float = 1.0 if day >= 8 else 0.20+maxi(0,day-3)*0.15
	var paired: bool = crew.is_empty() and day >= 3 and rng.randf() < pair_chance
	_add_visitor(side)
	if paired:
		_add_visitor(-side)
		feedback.emit("Passos dos dois lados!","steps")
	else:
		feedback.emit("Passos à esquerda." if side < 0 else "Passos à direita.","steps")

func _add_visitor(side: int) -> void:
	crew.append({"id":next_crew_id,"side":side,"progress":0.0,"retreating":false})
	next_crew_id += 1

func look(side: int) -> void:
	if state == State.PLAYING: look_side = -1 if side < 0 else 1

func wake() -> bool:
	if state != State.PLAYING or wake_cooldown > 0.0: return false
	wake_cooldown = 0.8
	if not is_sleepy():
		early_wakes += 1
		day_perfect = false
		fatigue = minf(100.0,fatigue+2.5)
		feedback.emit("Ainda está alerta. Espere os olhos pesarem.","notice")
		if fatigue >= 100.0: _lose("sono")
		return false
	var timely: bool = fatigue <= WAKE_END
	fatigue = maxf(10.0,fatigue-(36.0 if timely else 24.0))
	successful_wakes += 1
	wake_flash = 0.65
	feedback.emit("Odisseu desperta a tempo." if timely else "No último instante!","wake")
	return true

func warn_crew() -> bool:
	if state != State.PLAYING or shout_cooldown > 0.0: return false
	if is_sleepy():
		feedback.emit("Desperte antes de afastar a tripulação.","notice")
		return false
	var chosen: Dictionary = {}
	for visitor in crew:
		if int(visitor.side) == look_side and not visitor.retreating and float(visitor.progress) >= 0.18:
			if chosen.is_empty() or float(visitor.progress) > float(chosen.progress): chosen = visitor
	if chosen.is_empty():
		feedback.emit("Olhe para o tripulante que está se aproximando.","notice")
		return false
	chosen.retreating = true
	shout_cooldown = 1.05
	prevented += 1
	fatigue = minf(100.0,fatigue+3.0)
	feedback.emit("Afaste-se da bolsa!","warn")
	return true

func _lose(reason: String) -> void:
	if state != State.PLAYING: return
	loss_reason = reason
	day_perfect = false
	if day == TOTAL_DAYS:
		state = State.ENDING
		ending_clock = 0.0
		crew.clear()
		# The real deck is hidden: the opener's identity is never disclosed.
		ending_started.emit()
	else:
		if reason == "bolsa": bag_sealed = false
		state = State.FAILED
		failed.emit(reason)

func _finish_day() -> void:
	days_completed += 1
	if day_perfect: perfect_days.append(day)
	day_finished.emit(day,day_perfect)
	crew.clear()
	state = State.DAY_BREAK
	break_clock = 0.0

func ending_alarm() -> void:
	if state == State.ENDING: bag_sealed = false

func finish_thoughts() -> void:
	if state != State.ENDING: return
	state = State.COMPLETE
	completed.emit(record())

func record() -> Dictionary:
	return {"days":day,"days_completed":days_completed,"prevented":prevented,"successful_wakes":successful_wakes,"missed":missed,"early_wakes":early_wakes,"perfect_days":perfect_days.duplicate(),"reason":loss_reason,"story_complete":state == State.COMPLETE}
