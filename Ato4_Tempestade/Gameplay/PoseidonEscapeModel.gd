extends RefCounted
## Continuous platform physics. Position is the centre of the character's feet.
signal feedback(text: String, kind: String)
signal phase_changed
signal attack_started(kind: String)
signal impact(kind: String)
signal ship_sunk(index: int)
signal completed(record: Dictionary)
signal failed(reason: String)
enum Phase { READY, TRAVERSAL, FINAL_SHIP, ESCAPING, COMPLETE, FAILED }
const STAND_HEIGHT := 76.0
const CROUCH_HEIGHT := 52.0
const HALF_WIDTH := 14.0
const SEA_LEVEL := 624.0
const WATER_SURFACE_Y := 558.0
var phase: Phase = Phase.READY
var level: Dictionary
var platforms: Array[Dictionary] = []
var boats: Array[Dictionary] = []
var obstacles: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var sunk_at: Array[float] = []
var position := Vector2(145,480)
var velocity := Vector2.ZERO
var facing := 1.0
var grounded := true
var crouching := false
var support := 0
var clock := 0.0
var phase_clock := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var invulnerable := 0.0
var hit_flash := 0.0
var impact_flash := 0.0
var landing_flash := 0.0
var hit_stun := 0.0
var balance := 100.0
var max_x := 145.0
var visited_boat := 0
var jumps := 0
var hits := 0
var retries := 0
var ducked_attacks := 0
var cleared_attacks := 0
var completion_count := 0
var final_attacks := 0
var final_next_attack := 1.1
var final_pattern := 0
var bindings: Array[float] = [0.0,0.0,0.0]
var has_bag := false
var bag_progress := 0.0
var wind_progress := 0.0
var mast_broken := false
var failure_reason := ""
var checkpoint: Dictionary = {}
var final_origin := 0.0
var bag_point := Vector2.ZERO
var exit_point := Vector2.ZERO
var binding_points: Array[Vector2] = []
var interaction_active := false
var random_seed: int

func _init(seed_value: int = 614) -> void:
	random_seed = seed_value
	level = JSON.parse_string(FileAccess.get_file_as_string("res://Ato4_Tempestade/Gameplay/PoseidonPlatformLevel.json"))
	_build_level()
	for i in 11: sunk_at.append(-1.0)

func _add_platform(rect: Rect2, kind: String, boat: int, bob: float = 0.0) -> void:
	platforms.append({"rect":rect,"kind":kind,"boat":boat,"bob":bob,"touched":-1.0,"gone":false,"drop_at":-1.0})

func _build_level() -> void:
	var x := 80.0
	for i in level.boats.size():
		var config: Dictionary = level.boats[i]
		var rect := Rect2(x,float(config.y),float(config.width),24)
		boats.append({"rect":rect,"entered":-1.0,"warning":-1.0,"attacked":false,"collapse":-1.0})
		_add_platform(rect,"deck",i)
		x += float(config.width)+float(config.gap)
	final_origin = boats[10].rect.position.x
	for i in 10:
		var a: Rect2 = boats[i].rect
		var b: Rect2 = boats[i+1].rect
		var gap: float = b.position.x-a.end.x
		var wreck_count: int = int(level.boats[i].wrecks)
		for j in wreck_count:
			var f: float = float(j+1)/float(wreck_count+1)
			_add_platform(Rect2(a.end.x+gap*f-63,540,126,18),"wreck",i,5.0+float(j)*2)
		var type: String = level.boats[i].obstacle
		if type == "crate": obstacles.append({"rect":Rect2(a.position.x+155,a.position.y-43,57,43),"kind":"crate","boat":i})
		if type == "beam": obstacles.append({"rect":Rect2(a.position.x+176,a.position.y-93,140,34),"kind":"beam","boat":i})
	for r in [Rect2(205,390,155,20),Rect2(390,320,165,20),Rect2(605,366,150,20),Rect2(810,400,140,20)]:
		r.position.x += final_origin
		_add_platform(r,"rigging",10)
	binding_points = [Vector2(final_origin+115,470),Vector2(final_origin+470,320),Vector2(final_origin+1015,470)]
	bag_point = Vector2(final_origin+680,366)
	exit_point = Vector2(final_origin+65,470)

func start() -> void:
	if phase != Phase.READY: return
	_change(Phase.TRAVERSAL)
	_enter_boat(0)
	_save_checkpoint()
	feedback.emit("A bolsa está no seu navio. Atravesse a frota!","notice")

func _change(value: Phase) -> void:
	phase = value
	phase_clock = 0
	phase_changed.emit()

func active() -> bool:
	return phase in [Phase.TRAVERSAL,Phase.FINAL_SHIP]

func fleet_remaining() -> int:
	var count := 12
	for time in sunk_at:
		if time >= 0: count -= 1
	return count

func water_height_at(x: float, at_time: float = -1.0) -> float:
	var time: float = clock if at_time < 0 else at_time
	return WATER_SURFACE_Y+sin(x*0.012+time*1.8)*4+sin(x*0.032-time*2.4)*2

func platform_rect(index: int, at_time: float = -1.0) -> Rect2:
	var p: Dictionary = platforms[index]
	var r: Rect2 = p.rect
	var time: float = clock if at_time < 0 else at_time
	if p.kind == "wreck": r.position.y = water_height_at(r.get_center().x,time)-18
	elif p.bob > 0: r.position.y += sin(time*1.65+index*1.9)*float(p.bob)
	if p.drop_at >= 0: r.position.y += pow(maxf(0,time-float(p.drop_at)),2)*180
	return r

func body_rect(at := Vector2.INF, low: int = -1) -> Rect2:
	var feet: Vector2 = position if at == Vector2.INF else at
	var height: float = CROUCH_HEIGHT if (crouching if low < 0 else bool(low)) else STAND_HEIGHT
	return Rect2(feet-Vector2(HALF_WIDTH,height),Vector2(HALF_WIDTH*2,height))

func can_stand() -> bool:
	for object in obstacles:
		if sunk_at[object.boat] < 0 and body_rect(position,0).intersects(object.rect.grow(-0.1)): return false
	return true

func tick(delta: float, move: float = 0.0, duck: bool = false, jump_pressed: bool = false, jump_held: bool = false, interact: bool = false) -> void:
	if not active() and phase != Phase.ESCAPING: return
	if jump_pressed: jump_buffer = float(level.physics.jump_buffer_seconds)
	var remaining: float = minf(maxf(delta,0),0.25)
	while remaining > 0.00001:
		var step: float = minf(remaining,1.0/120.0)
		_step(step,clampf(move,-1,1),duck,jump_held,interact)
		remaining -= step

func _step(dt: float, move: float, duck: bool, jump_held: bool, interact: bool) -> void:
	if phase in [Phase.FAILED,Phase.COMPLETE]: return
	clock += dt
	phase_clock += dt
	hit_flash = maxf(0,hit_flash-dt)
	impact_flash = maxf(0,impact_flash-dt)
	landing_flash = maxf(0,landing_flash-dt)
	if phase == Phase.ESCAPING:
		if phase_clock >= 4.8:
			_change(Phase.COMPLETE)
			completion_count += 1
			completed.emit(record())
		return
	invulnerable = maxf(0,invulnerable-dt)
	hit_stun = maxf(0,hit_stun-dt)
	jump_buffer = maxf(0,jump_buffer-dt)
	coyote = float(level.physics.coyote_seconds) if grounded else maxf(0,coyote-dt)
	if grounded and support >= 0 and not platforms[support].gone:
		position.y += platform_rect(support).position.y-platform_rect(support,clock-dt).position.y
	crouching = (duck and grounded) or (crouching and not can_stand())
	var speed: float = float(level.physics.crouch_speed if crouching else level.physics.run_speed)*(0.87 if has_bag else 1.0)
	var accel: float = float(level.physics.acceleration if grounded else level.physics.air_acceleration)
	if hit_stun <= 0: velocity.x = move_toward(velocity.x,move*speed,accel*dt)
	if absf(move) > 0.1 and hit_stun <= 0: facing = signf(move)
	if jump_buffer > 0 and coyote > 0 and not crouching and hit_stun <= 0:
		velocity.y = -float(level.physics.jump_speed)
		grounded = false
		coyote = 0
		jump_buffer = 0
		jumps += 1
	# Release early for a short hop. No dash, scripted arc, or double jump.
	if not jump_held and velocity.y < -260: velocity.y = -260
	velocity.y = minf(900,velocity.y+float(level.physics.gravity)*dt)
	_move_horizontal(dt)
	_move_vertical(dt)
	max_x = maxf(max_x,position.x)
	_update_world()
	_update_attacks(dt)
	interaction_active = false
	if phase == Phase.FINAL_SHIP: _final_interaction(dt,interact)
	if position.y > SEA_LEVEL+20: _fail("Odisseu caiu entre os destroços. Retome o último ponto seguro.")

func _move_horizontal(dt: float) -> void:
	var old: float = position.x
	position.x = clampf(position.x+velocity.x*dt,50,final_origin+1070)
	for object in obstacles:
		if sunk_at[object.boat] >= 0: continue
		var r: Rect2 = object.rect
		if not body_rect().intersects(r.grow(-0.1)): continue
		if old+HALF_WIDTH <= r.position.x+2 and velocity.x > 0:
			position.x = r.position.x-HALF_WIDTH
			velocity.x = 0
		elif old-HALF_WIDTH >= r.end.x-2 and velocity.x < 0:
			position.x = r.end.x+HALF_WIDTH
			velocity.x = 0

func _move_vertical(dt: float) -> void:
	var old_y: float = position.y
	var was_grounded: bool = grounded
	position.y += velocity.y*dt
	grounded = false
	support = -1
	var best_y := INF
	if velocity.y >= 0:
		for i in platforms.size():
			if platforms[i].gone: continue
			var r: Rect2 = platform_rect(i)
			var previous: Rect2 = platform_rect(i,clock-dt)
			if position.x+HALF_WIDTH <= r.position.x or position.x-HALF_WIDTH >= r.end.x: continue
			if old_y <= maxf(r.position.y,previous.position.y)+3 and position.y >= r.position.y and r.position.y < best_y:
				best_y = r.position.y
				support = i
		for object in obstacles:
			if sunk_at[object.boat] >= 0: continue
			var r: Rect2 = object.rect
			if position.x+HALF_WIDTH > r.position.x and position.x-HALF_WIDTH < r.end.x and old_y <= r.position.y+1 and position.y >= r.position.y and r.position.y < best_y:
				best_y = r.position.y
				support = -1
		if best_y < INF:
			position.y = best_y
			velocity.y = 0
			grounded = true
			if not was_grounded: landing_flash = 0.1
	else:
		for object in obstacles:
			if sunk_at[object.boat] >= 0: continue
			var r: Rect2 = object.rect
			if body_rect().intersects(r) and old_y-STAND_HEIGHT >= r.end.y-2:
				position.y = r.end.y+STAND_HEIGHT
				velocity.y = 0
	if grounded and support >= 0:
		var p: Dictionary = platforms[support]
		if p.touched < 0: p.touched = clock
		if p.kind == "deck": _enter_boat(p.boat)
		elif p.kind == "wreck" and boats[p.boat].collapse < 0:
			# The ship is struck during the crossing, while it is still in view.
			boats[p.boat].warning = clock
			boats[p.boat].collapse = clock+0.7

func _enter_boat(index: int) -> void:
	if boats[index].entered >= 0: return
	boats[index].entered = clock
	visited_boat = maxi(visited_boat,index)
	if index > 0 and boats[index-1].collapse < 0:
		boats[index-1].collapse = clock+0.85
		boats[index-1].warning = clock-float(level.collapse.warning_seconds)+0.85
	if index == 10:
		_change(Phase.FINAL_SHIP)
		final_next_attack = clock+float(level.final.first_attack_delay)
		_sink(10) # The twelfth ship is in the background, not the captain's boat.
		balance = 100
		feedback.emit("Seu navio! Solte três amarras, pegue a bolsa e volte à popa.","notice")
		_save_checkpoint()
	elif index > 0 and index%2 == 0:
		balance = maxf(balance,70)
		_save_checkpoint()
		feedback.emit("Ponto seguro · navio %d de 10" % (index+1),"notice")

func _update_world() -> void:
	for i in 10:
		var boat: Dictionary = boats[i]
		if boat.entered < 0 or sunk_at[i] >= 0: continue
		var age: float = clock-boat.entered
		if boat.collapse < 0 and age >= float(level.collapse.deck_stay_seconds):
			boat.warning = clock
			boat.collapse = clock+float(level.collapse.warning_seconds)
		if boat.collapse >= 0 and clock >= boat.collapse: _sink(i)
		if phase == Phase.TRAVERSAL and not boat.attacked and age >= (1.1 if i == 0 else 0.2):
			boat.attacked = true
			_spawn_attack(level.boats[i].attack,i)
	for p in platforms:
		if p.gone or p.kind != "wreck" or p.touched < 0: continue
		if clock-p.touched > float(level.collapse.debris_stay_seconds) and p.drop_at < 0: p.drop_at = clock
		if p.drop_at >= 0 and clock-p.drop_at > 0.6: p.gone = true
	if phase == Phase.FINAL_SHIP and clock >= final_next_attack:
		var sequence := ["low","high","slam","low","slam","high"]
		_spawn_attack(sequence[final_pattern%sequence.size()],10)
		final_pattern += 1
		final_attacks += 1
		final_next_attack = clock+float(level.final.attack_interval)*(0.86 if mast_broken else 1.0)

func _sink(index: int) -> void:
	if sunk_at[index] >= 0: return
	sunk_at[index] = clock
	for p in platforms:
		if p.kind == "deck" and p.boat == index and index < 10: p.gone = true
	impact_flash = 0.45
	ship_sunk.emit(index)
	impact.emit("ship")

func _spawn_attack(kind: String, boat_index: int) -> void:
	var deck: Rect2 = boats[boat_index].rect
	var final: bool = boat_index == 10
	var target_x: float = clampf(position.x+velocity.x*0.14,deck.position.x+55,deck.end.x-55)
	var warning: float = 1.05 if final else 1.15 if boat_index == 0 else 0.95
	var h := {"kind":kind,"age":0.0,"warning":warning,"boat":boat_index,"x":deck.end.x+90,"y":deck.position.y,"target":target_x,"hit":false,"passed":false,"counted":false,"speed":510.0 if final else 440.0}
	if kind == "slam":
		h.x = target_x
		h.y = deck.position.y
		h.warning = 1.05 if final else 1.25
	hazards.append(h)
	attack_started.emit(kind)

func hazard_rect(h: Dictionary) -> Rect2:
	if h.kind == "slam":
		var reach: float = 1.0 if h.age < h.warning else smoothstep(0,0.12,maxf(0,float(h.age)-float(h.warning)))
		return Rect2(float(h.target)-47,float(h.y)-330,94,355*reach)
	var height: float = 31 if h.kind == "low" else 37
	var y: float = float(h.y)-31 if h.kind == "low" else float(h.y)-103
	return Rect2(float(h.x)-36,y,72,height)

func _update_attacks(dt: float) -> void:
	for h in hazards:
		h.age += dt
		if h.age < h.warning: continue
		if not h.counted:
			h.counted = true
			impact_flash = maxf(impact_flash,0.15)
			impact.emit(h.kind)
		if h.kind != "slam": h.x -= float(h.speed)*dt
		var live: bool = h.age-h.warning < (0.33 if h.kind == "slam" else 3.3)
		if live and not h.hit and body_rect().intersects(hazard_rect(h)) and invulnerable <= 0:
			h.hit = true
			_hit(h.kind,-1.0 if h.kind != "slam" else signf(position.x-float(h.target)))
		if not h.passed and h.kind != "slam" and h.x+38 < position.x:
			h.passed = true
			if not h.hit:
				cleared_attacks += 1
				if h.kind == "high" and crouching: ducked_attacks += 1
	for i in range(hazards.size()-1,-1,-1):
		var h: Dictionary = hazards[i]
		if h.age > h.warning+(0.7 if h.kind == "slam" else 3.4): hazards.remove_at(i)

func _hit(kind: String, side: float) -> void:
	hits += 1
	balance = maxf(0,balance-(35 if kind == "slam" else 28))
	invulnerable = 0.85
	hit_flash = 0.25
	hit_stun = 0.16
	velocity.x = (-1.0 if side == 0 else side)*190
	if not crouching: velocity.y = minf(velocity.y,-120)
	feedback.emit("Impacto! Procure apoio e continue.","hit")
	if balance <= 0: _fail("Os impactos interromperam a travessia. Retome o último ponto seguro.")

func bindings_done() -> int:
	var n := 0
	for value in bindings:
		if value >= 1: n += 1
	return n

func _final_interaction(dt: float, interact: bool) -> void:
	if not interact or not grounded or hit_stun > 0: return
	if bindings_done() < 3:
		for i in 3:
			if bindings[i] >= 1 or position.distance_to(binding_points[i]) > 50: continue
			interaction_active = true
			bindings[i] = minf(1,bindings[i]+dt/float(level.final.binding_seconds))
			if bindings[i] >= 1:
				feedback.emit("Amarra solta · %d/3" % bindings_done(),"bag")
				if bindings_done() == 2:
					mast_broken = true
					impact_flash = 0.65
					impact.emit("mast")
					feedback.emit("O mastro caiu! Alcance a bolsa.","warning")
			return
	elif not has_bag and position.distance_to(bag_point) < 52:
		interaction_active = true
		bag_progress = minf(1,bag_progress+dt/float(level.final.bag_seconds))
		if bag_progress >= 1:
			has_bag = true
			_save_checkpoint()
			feedback.emit("Volte à popa com a bolsa!","bag")
	elif has_bag and position.distance_to(exit_point) < 60:
		interaction_active = true
		wind_progress = minf(1,wind_progress+dt/float(level.final.release_seconds))
		if wind_progress >= 1:
			var wrecks_finished := true
			for time in sunk_at:
				if time < 0 or clock-time < float(level.collapse.wreck_seconds): wrecks_finished = false
			if wrecks_finished: _change(Phase.ESCAPING)

func _fail(reason: String) -> void:
	if not active(): return
	failure_reason = reason
	_change(Phase.FAILED)
	failed.emit(reason)

func _save_checkpoint() -> void:
	checkpoint = {"position":position,"phase":phase,"boats":boats.duplicate(true),"platforms":platforms.duplicate(true),"sunk_at":sunk_at.duplicate(),"bindings":bindings.duplicate(),"has_bag":has_bag,"bag_progress":bag_progress,"mast_broken":mast_broken,"visited_boat":visited_boat,"at":clock}

func retry_checkpoint() -> void:
	if phase != Phase.FAILED or checkpoint.is_empty(): return
	retries += 1
	position = checkpoint.position
	velocity = Vector2.ZERO
	boats = checkpoint.boats.duplicate(true)
	platforms = checkpoint.platforms.duplicate(true)
	sunk_at.assign(checkpoint.sunk_at)
	bindings.assign(checkpoint.bindings)
	has_bag = checkpoint.has_bag
	bag_progress = checkpoint.bag_progress
	mast_broken = checkpoint.mast_broken
	visited_boat = checkpoint.visited_boat
	# Rebase timers; waiting in the failure panel cannot sink the checkpoint.
	var offset: float = clock-float(checkpoint.at)
	for boat in boats:
		for field in ["entered","warning","collapse"]:
			if boat[field] >= 0: boat[field] += offset
	for p in platforms:
		for field in ["touched","drop_at"]:
			if p[field] >= 0: p[field] += offset
	for i in sunk_at.size():
		if sunk_at[i] >= 0: sunk_at[i] += offset
	hazards.clear()
	balance = 100
	invulnerable = 1
	hit_stun = 0
	grounded = false
	crouching = false
	coyote = 0
	jump_buffer = 0
	wind_progress = 0
	final_next_attack = clock+1.3
	_change(checkpoint.phase)
	feedback.emit("Ponto seguro retomado.","notice")

func objective() -> String:
	if phase == Phase.FAILED: return "TRAVESSIA INTERROMPIDA"
	if phase in [Phase.ESCAPING,Phase.COMPLETE]: return "UM ÚNICO NAVIO ESCAPOU"
	if phase == Phase.FINAL_SHIP:
		if has_bag: return "VOLTE À POPA E LIBERE OS VENTOS"
		if bindings_done() == 3: return "ALCANCE A BOLSA NA PLATAFORMA ALTA"
		return "SEU NAVIO · SOLTE AS AMARRAS  %d/3" % bindings_done()
	return "ATRAVESSE A FROTA · NAVIO %d/10" % (mini(visited_boat,9)+1)

func prompt() -> String:
	if phase == Phase.FINAL_SHIP:
		var points: Array = [exit_point] if has_bag else [bag_point] if bindings_done() == 3 else binding_points
		for i in points.size():
			if not has_bag and bindings_done() < 3 and bindings[i] >= 1: continue
			if position.distance_to(points[i]) < 60: return "SEGURE E · "+("LIBERAR OS VENTOS" if has_bag else "PEGAR A BOLSA" if bindings_done() == 3 else "SOLTAR AMARRA")
	if support >= 0 and platforms[support].kind == "wreck" and clock-platforms[support].touched > 2.8: return "O DESTROÇO ESTÁ AFUNDANDO!"
	if visited_boat == 0: return "ESPAÇO: PULAR · SEGURE PARA SALTAR MAIS ALTO"
	return ""

func record() -> Dictionary:
	return {"escaped":phase == Phase.COMPLETE,"seconds":snappedf(clock,0.1),"ships_lost":12-fleet_remaining(),"ships_remaining":fleet_remaining(),"boats_crossed":mini(visited_boat,10),"hits":hits,"jumps":jumps,"retries":retries,"ducked_attacks":ducked_attacks,"attacks_cleared":cleared_attacks,"bindings":bindings_done(),"mode":"platformer"}
