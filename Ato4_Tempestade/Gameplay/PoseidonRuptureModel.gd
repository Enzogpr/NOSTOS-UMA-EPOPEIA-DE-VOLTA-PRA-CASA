extends "res://Ato4_Tempestade/Gameplay/PoseidonEscapeModel.gd"
## Representative encounter. Shared platform controls, authored causal destruction.
signal encounter_cue(kind: String)
var encounter_state := "foreboding"
var route_beat := "O mar está recuando"
var route_clock := 0.0
var event_age := 0.0
var fracture := 0.0
var bow_broken := false
var ramp_ready := false
var ramp_start := Vector2(380,475)
var ramp_end := Vector2(1100,315)
var mast_angle := -PI/2
var sail_drop := 0.0
var front_x := -650.0
var front_active := false
var god_presence := 0.0
var tension := 0.15
var quiet := 0.75
var retreated := false
var ducked_sail := false
var crossed_ramp := false
var mobile_landings := 0
var events: Dictionary = {}
var local_checkpoint: Dictionary = {}
var checkpoint_title := "Primeiro convés"
var pursuit_start := -1.0
var last_support := 0
var previous_grounded := true
var trigger_x := 680.0
var elapsed_total := 0.0
var simulation_delta := 1.0/120.0

func _init(seed_value: int = 614) -> void:
	super(seed_value)
	position = Vector2(145,475)
	level.physics.run_speed = 305
	level.physics.crouch_speed = 145
	level.physics.acceleration = 2700
	level.physics.air_acceleration = 1850
	level.physics.jump_speed = 680
	level.physics.gravity = 1620
	final_origin = 4700

func _build_level() -> void:
	platforms.clear()
	boats.clear()
	obstacles.clear()
	for r in [Rect2(80,475,1100,24),Rect2(1510,450,850,24),Rect2(3000,435,590,24),Rect2(4700,420,650,24)]:
		boats.append({"rect":r,"entered":-1.0,"warning":-1.0,"attacked":false,"collapse":-1.0})
	proof_platform(Rect2(80,475,725,22),"deck",0)
	proof_platform(Rect2(805,475,375,22),"bow",0)
	proof_platform(Rect2(380,475,720,20),"ramp",0)
	platforms[2].gone = true
	proof_platform(Rect2(1240,385,145,20),"wreck",0,5,18)
	proof_platform(Rect2(1510,450,850,22),"deck",1)
	proof_platform(Rect2(2475,490,130,20),"wreck",1,7,22)
	proof_platform(Rect2(2670,410,145,20),"wreck",1,5,27)
	proof_platform(Rect2(2855,465,105,20),"wreck",1,6,16)
	proof_platform(Rect2(3000,435,590,22),"deck",2)
	proof_platform(Rect2(3260,355,155,18),"ledge",2)
	proof_platform(Rect2(3740,455,130,20),"wreck",2,8,18)
	proof_platform(Rect2(3950,370,135,20),"wreck",2,7,25)
	proof_platform(Rect2(4155,430,160,20),"wreck",2,7,30)
	proof_platform(Rect2(4385,350,145,20),"wreck",2,6,22)
	proof_platform(Rect2(4560,400,120,20),"wreck",2,5,15)
	proof_platform(Rect2(4700,420,650,22),"deck",3)
	obstacles.append({"rect":Rect2(240,432,56,43),"kind":"crate","boat":0,"active":true})
	obstacles.append({"rect":Rect2(490,200,140,215),"kind":"sail","boat":0,"active":false})
	obstacles.append({"rect":Rect2(1900,402,60,48),"kind":"crate","boat":1,"active":true})

func proof_platform(r: Rect2, kind: String, boat: int, bob := 0.0, drift := 0.0) -> void:
	platforms.append({"rect":r,"kind":kind,"boat":boat,"bob":bob,"drift":drift,"touched":-1.0,"gone":false,"drop_at":-1.0})

func start() -> void:
	if phase != Phase.READY: return
	_change(Phase.TRAVERSAL)
	_set_state("foreboding","Alcance a proa. Observe o mar.")
	_save_checkpoint()

func _change(value: Phase) -> void:
	if value in [Phase.FAILED,Phase.COMPLETE]: velocity = Vector2.ZERO
	super(value)

func _set_state(value: String, text: String) -> void:
	encounter_state = value
	event_age = 0
	route_beat = text
	phase_changed.emit()

func _once(key: String, sound: String = "") -> bool:
	if events.has(key): return false
	events[key] = route_clock
	if not sound.is_empty(): encounter_cue.emit(sound)
	return true

func surface_endpoints(index: int, at_time: float = -1.0) -> Array[Vector2]:
	var p: Dictionary = platforms[index]
	var t: float = route_clock if at_time < 0 else at_time
	if p.kind == "ramp": return [ramp_start,ramp_end]
	var r: Rect2 = p.rect
	var offset := Vector2.ZERO
	if p.bob > 0:
		offset = Vector2(sin(t*1.1+index*1.6)*float(p.drift),sin(t*1.65+index*1.9)*float(p.bob))
	if p.drop_at >= 0: offset.y += pow(maxf(0,t-float(p.drop_at)),2)*160
	return [r.position+offset,Vector2(r.end.x,r.position.y)+offset]

func surface_y_at(index: int, x: float, at_time: float = -1.0) -> float:
	var ends: Array[Vector2] = surface_endpoints(index,at_time)
	return lerpf(ends[0].y,ends[1].y,clampf((x-ends[0].x)/maxf(1,ends[1].x-ends[0].x),0,1))

func platform_rect(index: int, at_time: float = -1.0) -> Rect2:
	var ends: Array[Vector2] = surface_endpoints(index,at_time)
	return Rect2(Vector2(ends[0].x,minf(ends[0].y,ends[1].y)),Vector2(ends[1].x-ends[0].x,absf(ends[1].y-ends[0].y)+20))

func _obstacle_enabled(o: Dictionary) -> bool:
	return o.active and (o.boat != 0 or sunk_at[0] < 0)

func can_stand() -> bool:
	for o in obstacles:
		if _obstacle_enabled(o) and body_rect(position,0).intersects(o.rect.grow(-0.1)): return false
	return true

func _step(dt: float, move: float, duck: bool, jump_held: bool, _interact: bool) -> void:
	if not active(): return
	clock += dt
	elapsed_total += dt
	simulation_delta = dt
	route_clock += dt
	phase_clock += dt
	event_age += dt
	hit_flash = maxf(0,hit_flash-dt)
	impact_flash = maxf(0,impact_flash-dt)
	landing_flash = maxf(0,landing_flash-dt)
	invulnerable = maxf(0,invulnerable-dt)
	hit_stun = maxf(0,hit_stun-dt)
	jump_buffer = maxf(0,jump_buffer-dt)
	coyote = float(level.physics.coyote_seconds) if grounded else maxf(0,coyote-dt)
	# Carry the contact point in both axes. Rendering consumes these same surfaces.
	if grounded and support >= 0 and not platforms[support].gone:
		var now: Array[Vector2] = surface_endpoints(support)
		var before: Array[Vector2] = surface_endpoints(support,route_clock-dt)
		var displacement: Vector2 = now[0]-before[0]
		position += displacement
	crouching = (duck and grounded) or (crouching and not can_stand())
	var speed: float = float(level.physics.crouch_speed if crouching else level.physics.run_speed)
	var accel: float = float(level.physics.acceleration if grounded else level.physics.air_acceleration)
	if hit_stun <= 0: velocity.x = move_toward(velocity.x,move*speed,accel*dt)
	if absf(move) > 0.05 and hit_stun <= 0: facing = signf(move)
	if jump_buffer > 0 and coyote > 0 and not crouching and hit_stun <= 0:
		velocity.y = -float(level.physics.jump_speed)
		grounded = false
		coyote = 0
		jump_buffer = 0
		jumps += 1
	if not jump_held and velocity.y < -260: velocity.y = -260
	velocity.y = minf(900,velocity.y+float(level.physics.gravity)*dt)
	_move_horizontal(dt)
	_move_vertical(dt)
	max_x = maxf(max_x,position.x)
	_update_world()
	_update_attacks(dt)
	if crouching:
		for o in obstacles:
			if o.kind == "sail" and o.active and position.x > o.rect.position.x-14 and position.x < o.rect.end.x+14: ducked_sail = true
	if position.y > SEA_LEVEL+20: _fail("Você perdeu o apoio. Enter retoma o último convés seguro.")
	if front_active and position.x-HALF_WIDTH < front_x and position.y > 230:
		_fail("A parede de água alcançou você. Retome o trecho e use os apoios à frente.")
	previous_grounded = grounded
	last_support = support

func _move_horizontal(dt: float) -> void:
	var old: float = position.x
	position.x = clampf(position.x+velocity.x*dt,65,5310)
	for o in obstacles:
		if not _obstacle_enabled(o): continue
		var r: Rect2 = o.rect
		if not body_rect().intersects(r.grow(-0.1)): continue
		if old+HALF_WIDTH <= r.position.x+3 and velocity.x > 0:
			position.x = r.position.x-HALF_WIDTH
			velocity.x = 0
		elif old-HALF_WIDTH >= r.end.x-3 and velocity.x < 0:
			position.x = r.end.x+HALF_WIDTH
			velocity.x = 0
		elif o.kind == "sail":
			# A descending sail can envelop the standing body between two steps.
			# It still blocks passage until the player actually crouches.
			position.x = old
			velocity.x = 0

func _move_vertical(dt: float) -> void:
	var old_y: float = position.y
	var was_grounded: bool = grounded
	var prior: int = support
	position.y += velocity.y*dt
	grounded = false
	support = -1
	var best := INF
	if velocity.y >= 0:
		for i in platforms.size():
			if platforms[i].gone: continue
			var ends: Array[Vector2] = surface_endpoints(i)
			if position.x+HALF_WIDTH <= ends[0].x or position.x-HALF_WIDTH >= ends[1].x: continue
			var y: float = surface_y_at(i,position.x)
			var previous_y: float = surface_y_at(i,position.x-velocity.x*dt,route_clock-dt)
			var on_slope: bool = was_grounded and prior == i and old_y <= previous_y+5
			if (on_slope or (old_y <= maxf(y,previous_y)+3 and position.y >= y)) and y < best:
				best = y
				support = i
		for o in obstacles:
			if not _obstacle_enabled(o): continue
			var r: Rect2 = o.rect
			if position.x+HALF_WIDTH > r.position.x and position.x-HALF_WIDTH < r.end.x and old_y <= r.position.y+1 and position.y >= r.position.y and r.position.y < best:
				best = r.position.y
				support = -1
		if best < INF:
			position.y = best
			velocity.y = 0
			grounded = true
			if not was_grounded:
				landing_flash = 0.12
				if support >= 0 and platforms[support].kind == "wreck": mobile_landings += 1
	else:
		for o in obstacles:
			if _obstacle_enabled(o) and body_rect().intersects(o.rect) and old_y-STAND_HEIGHT >= o.rect.end.y-2:
				position.y = o.rect.end.y+STAND_HEIGHT
				velocity.y = 0
	if grounded and support >= 0:
		if platforms[support].touched < 0: platforms[support].touched = route_clock
		if platforms[support].kind == "ramp": crossed_ramp = true

func _update_world() -> void:
	match encounter_state:
		"foreboding":
			god_presence = smoothstep(0,2,route_clock)*0.25
			if position.x >= trigger_x:
				_set_state("fracture","A proa vai ceder. Recue até o mastro!")
				encounter_cue.emit("creak")
				encounter_cue.emit("divine_rumble")
				feedback.emit(route_beat,"warning")
		"fracture":
			god_presence = smoothstep(0,0.65,event_age)
			fracture = smoothstep(1.1,2.0,event_age)
			sail_drop = smoothstep(0.25,0.8,event_age)
			obstacles[1].active = sail_drop > 0.8
			if event_age >= 1.6 and not bow_broken:
				bow_broken = true
				platforms[1].gone = true
				impact_flash = 0.6
				encounter_cue.emit("wood_snap")
				encounter_cue.emit("splash")
			if event_age >= 2.1: _set_state("retreat","Volte pelo convés. Passe abaixado sob a vela.")
		"retreat":
			fracture = 1
			sail_drop = 1
			god_presence = move_toward(god_presence,0.25,0.4*simulation_delta)
			if position.x <= 365 and grounded:
				retreated = true
				_set_state("mast_fall","O mastro está caindo. Prepare a travessia por cima.")
				encounter_cue.emit("creak")
				_save_checkpoint()
		"mast_fall":
			mast_angle = lerpf(-PI/2,(ramp_end-ramp_start).angle(),smoothstep(0.1,1.5,event_age))
			sail_drop = 1-smoothstep(0.4,1.25,event_age)
			obstacles[1].active = sail_drop > 0.8
			if event_age >= 1.55:
				ramp_ready = true
				platforms[2].gone = false
				_set_state("crossing","O mastro abriu um caminho. Alcance o próximo barco.")
				encounter_cue.emit("wood_snap")
				impact_flash = 0.35
		"crossing":
			god_presence = 0.15
			if position.x > 1540 and grounded:
				_set_state("pursuit","A água vem atrás. Use os destroços e ganhe distância.")
				front_active = true
				front_x = 1100
				pursuit_start = route_clock
				sunk_at[0] = clock
				platforms[0].gone = true
				platforms[2].gone = true
				encounter_cue.emit("splash")
				checkpoint_title = "Além do mastro"
				_save_checkpoint()
		"pursuit":
			if position.x > 2150 and _once("low_wave","gust"):
				_spawn_attack("low",1)
			if position.x > 3010 and grounded and _once("mid_checkpoint"):
				checkpoint_title = "Abrigo entre as ondas"
				_save_checkpoint()
			if position.x > 3140 and _once("god_returns","divine_rumble"):
				god_presence = 1
			if position.x > 3270 and _once("mark","warning"): _spawn_attack("slam",2)
			if position.x > 3630 and _once("second_loss","wood_snap"):
				sunk_at[1] = clock
				platforms[4].gone = true
			if position.x > 4760 and grounded:
				front_active = false
				_set_state("safe","Um instante de abrigo. A travessia continua.")
				encounter_cue.emit("gust")
		"safe":
			god_presence = 0.1
			if position.x > 5070:
				_set_state("finished","Trecho de prova concluído.")
				_change(Phase.COMPLETE)
				completion_count += 1
				completed.emit(record())
	if front_active:
		front_x += 282.0*simulation_delta
		if front_x > 2180 and sunk_at[1] < 0:
			sunk_at[1] = clock
			platforms[4].gone = true
		if front_x > 3420 and sunk_at[2] < 0:
			sunk_at[2] = clock
			platforms[8].gone = true
	for p in platforms:
		if p.kind != "wreck" or p.gone or p.touched < 0: continue
		if route_clock-p.touched > 3.6 and p.drop_at < 0: p.drop_at = route_clock
		if p.drop_at >= 0 and route_clock-p.drop_at > 0.8: p.gone = true
	tension = 0.25 if encounter_state == "foreboding" else 0.95 if front_active else 0.7
	quiet = 0.85 if encounter_state in ["foreboding","fracture","safe"] else 0.1

func _spawn_attack(kind: String, boat_index: int) -> void:
	super(kind,boat_index)
	if kind == "low":
		hazards[-1].x = 2400
		hazards[-1].warning = 0.85
	elif kind == "slam": hazards[-1].warning = 1.3

func _hit(kind: String, side: float) -> void:
	# Small scrape knockback is recoverable on a ledge; missed jumps still fail.
	hits += 1
	balance = maxf(0,balance-30)
	invulnerable = 0.85
	hit_flash = 0.22
	hit_stun = 0.1
	velocity.x = side*105
	encounter_cue.emit("splash")
	if balance <= 0: _fail("Os impactos interromperam a travessia. Enter retoma o ponto seguro.")

func _save_checkpoint() -> void:
	super()
	local_checkpoint = {"route_clock":route_clock,"state":encounter_state,"route_beat":route_beat,"event_age":event_age,"front_x":front_x,"front_active":front_active,"fracture":fracture,"bow_broken":bow_broken,"ramp_ready":ramp_ready,"mast_angle":mast_angle,"sail_drop":sail_drop,"events":events.duplicate(true),"pursuit_start":pursuit_start,"obstacles":obstacles.duplicate(true),"title":checkpoint_title,"retreated":retreated,"ducked_sail":ducked_sail,"crossed_ramp":crossed_ramp}

func retry_checkpoint() -> void:
	if phase != Phase.FAILED: return
	# The base snapshot supplies campaign-independent geometry; local time is restored exactly.
	var data: Dictionary = local_checkpoint.duplicate(true)
	var snapshot: Dictionary = checkpoint.duplicate(true)
	super()
	boats = snapshot.boats.duplicate(true)
	clock = snapshot.at
	platforms = snapshot.platforms.duplicate(true)
	sunk_at.assign(snapshot.sunk_at)
	route_clock = data.route_clock
	encounter_state = data.state
	route_beat = data.route_beat
	event_age = data.event_age
	front_x = data.front_x
	front_active = data.front_active
	fracture = data.fracture
	bow_broken = data.bow_broken
	ramp_ready = data.ramp_ready
	mast_angle = data.mast_angle
	sail_drop = data.sail_drop
	events = data.events.duplicate(true)
	pursuit_start = data.pursuit_start
	obstacles = data.obstacles.duplicate(true)
	checkpoint_title = data.title
	retreated = data.retreated
	ducked_sail = data.ducked_sail
	crossed_ramp = data.crossed_ramp
	grounded = true
	support = -1
	for i in platforms.size():
		if not platforms[i].gone and absf(position.y-surface_y_at(i,position.x)) < 3 and platform_rect(i).grow(1).has_point(position): support = i
	velocity = Vector2.ZERO
	jump_buffer = 0
	feedback.emit(checkpoint_title+" · ponto seguro retomado.","notice")

func objective() -> String:
	if phase == Phase.FAILED: return "TRAVESSIA INTERROMPIDA"
	return route_beat

func prompt() -> String:
	if encounter_state == "retreat": return "← VOLTE · S / ↓ PARA ABAIXAR"
	if encounter_state == "mast_fall": return "O MASTRO ESTÁ ABRINDO A PASSAGEM"
	if encounter_state == "foreboding": return "A / D · CORRER     ESPAÇO · SALTO COM ALTURA VARIÁVEL"
	return ""

func record() -> Dictionary:
	return {"escaped":false,"proof_complete":phase == Phase.COMPLETE,"seconds":snappedf(elapsed_total,0.1),"route_seconds":snappedf(route_clock,0.1),"ships_lost":12-fleet_remaining(),"ships_remaining":fleet_remaining(),"hits":hits,"jumps":jumps,"retries":retries,"retreated":retreated,"ducked_sail":ducked_sail,"crossed_ramp":crossed_ramp,"mobile_landings":mobile_landings,"mode":"rupture_proof"}
