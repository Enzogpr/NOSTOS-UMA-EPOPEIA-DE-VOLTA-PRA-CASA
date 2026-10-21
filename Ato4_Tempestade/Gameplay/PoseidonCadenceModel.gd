extends "res://Ato4_Tempestade/Gameplay/PoseidonEscapeModel.gd"
const BOARDING := preload("res://Ato4_Tempestade/Gameplay/PoseidonWaterBoarding.gd")
const DASH_DURATION := 0.2
# Preserve the campaign dash/run ratio at this scene's larger pixel scale.
const DASH_SPEED_RATIO := 400.0/120.0
## Musical phrases author attacks; free platform controls remain authoritative.
signal encounter_cue(kind: String)
signal checkpoint_created
signal music_seek_requested(snapshot: Dictionary)
signal score_section_requested(section: String)

var final_index := 10
var score_time := 0.0
var score_beat := 0.0
var score_beat_seconds := 60.0/113.25
var score_section := "surge"
var score_snapshot: Dictionary = {}
var route_clock := 0.0
var elapsed_total := 0.0
var encounter_state := "traversal"
var route_beat := "Atravesse a frota até o navio de Odisseu."
var god_presence := 0.0
var tension := 0.6
var quiet := 0.15
var front_active := false
var front_x := -1000.0
var mobile_landings := 0
var returned_lower := false
var split_age := 0.0
var chart_events: Array[Dictionary] = []
var state_history: Array[Dictionary] = []
var local_checkpoint: Dictionary = {}
var next_attack_score := 3.0
var attack_number := 0
var simulation_delta := 1.0/120.0
var final_middle := -1
var last_landing_boat := -1
var last_beat_impact := -1.0
var wave_profile: Dictionary = {}
var pending_sinks: Array[Dictionary] = []
var split_at_score := -1.0
var externally_directed_escape := false
var escape_score_age := -1.0
var escape_release_at := 3.273
var escape_duration := 16.35
var wind_released := false
var boarding := BOARDING.new()
var combat_attack := false
var combat_guard := false
var fleet_assaults: Array[Dictionary] = []
var fleet_next_score := 8.0*60.0/113.25
var background_sunk_at := -1.0
var dash_time := 0.0
var dash_cooldown_remaining := 0.0
var dash_cooldown_seconds := 3.0
var dash_speed := 305.0*DASH_SPEED_RATIO
var dash_direction := 1.0
var dash_requested := false
var dashes := 0

func _init(seed_value: int = 614) -> void:
	super(seed_value)
	position = Vector2(145,480)
	level.physics.run_speed = 305
	level.physics.crouch_speed = 143
	level.physics.acceleration = 2700
	level.physics.air_acceleration = 1850
	level.physics.jump_speed = 690
	level.physics.gravity = 1620
	level.final.bag_seconds = 0.28
	level.final.release_seconds = 0.6
	wave_profile = JSON.parse_string(FileAccess.get_file_as_string("res://Ato4_Tempestade/Gameplay/PoseidonWaveProfile.json"))

func _build_level() -> void:
	var chart: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Ato4_Tempestade/Gameplay/PoseidonCadenceLevel.json"))
	platforms.clear()
	boats.clear()
	obstacles.clear()
	var x := 80.0
	for i in chart.boats.size():
		var config: Dictionary = chart.boats[i]
		var deck := Rect2(x,float(config.y),float(config.width),24)
		boats.append({"rect":deck,"entered":-1.0,"warning":-1.0,"attacked":false,"collapse":-1.0,"layout":config.layout,"section":config.section,"split":false,"split_x":x+550,"damage_progress":0.0})
		if i == 10:
			final_origin = x
			_add_surface(Rect2(x,deck.position.y,550,24),"deck",i)
			final_middle = platforms.size()
			_add_surface(Rect2(x+550,deck.position.y,570,24),"deck",i)
			_add_surface(Rect2(x+1120,deck.position.y,480,24),"deck",i)
			# A continuous, intact arena; only the bag cargo occupies the far bow.
			_add_cargo(x+1360,deck.position.y,180,65,i)
		else:
			_add_surface(deck,"deck",i)
			match String(config.layout):
				"intro":
					_add_cargo(x+420,deck.position.y,100,45,i)
					_add_beam(x+960,deck.position.y,220,i)
				"cargo_low":
					_add_cargo(x+330,deck.position.y,120,58,i)
					_add_beam(x+780,deck.position.y,290,i)
					_add_cargo(x+float(config.width)-300,deck.position.y,85,45,i)
				"low_cargo":
					_add_beam(x+270,deck.position.y,260,i)
					_add_cargo(x+760,deck.position.y,140,70,i)
					_add_beam(x+float(config.width)-380,deck.position.y,210,i)
				"double_cargo":
					_add_cargo(x+300,deck.position.y,110,45,i)
					_add_cargo(x+650,deck.position.y,155,83,i)
					_add_beam(x+float(config.width)-450,deck.position.y,260,i)
			x += float(config.width)+float(config.gap)
		if i < 10:
			var gap: float = float(config.gap)
			for j in int(config.wrecks):
				var f := float(j+1)/float(int(config.wrecks)+1)
				_add_surface(Rect2(deck.end.x+gap*f-67,540,134,20),"wreck",i,8+float(j%2)*4)
	bag_point = Vector2(final_origin+1450,405)
	exit_point = Vector2(final_origin+120,470)
	binding_points.clear()

func _add_surface(r: Rect2, kind: String, boat: int, drift := 0.0) -> void:
	platforms.append({"rect":r,"kind":kind,"boat":boat,"bob":5.0 if kind == "wreck" else 0.0,"drift":drift,"touched":-1.0,"gone":false,"drop_at":-1.0})

func _add_cargo(x: float, deck_y: float, width: float, height: float, boat: int) -> void:
	obstacles.append({"rect":Rect2(x,deck_y-height,width,height),"kind":"crate","boat":boat,"active":true})

func _add_beam(x: float, deck_y: float, width: float, boat: int) -> void:
	obstacles.append({"rect":Rect2(x,deck_y-118,width,58),"kind":"beam","boat":boat,"active":true})

func set_score_time(seconds: float, beat: float = -1.0) -> void:
	score_time = maxf(0,seconds)
	score_beat = score_time/maxf(0.1,score_beat_seconds) if beat < 0 else beat

func capture_score(snapshot: Dictionary) -> void:
	score_snapshot = snapshot.duplicate(true)
	if not checkpoint.is_empty(): checkpoint["music"] = score_snapshot.duplicate(true)

func _request_section(section: String) -> void:
	if score_section == section: return
	score_section = section
	score_section_requested.emit(section)

func set_combat_input(attack_edge: bool, guard_held: bool) -> void:
	combat_attack = (combat_attack or attack_edge) if phase==Phase.FINAL_SHIP else false
	combat_guard = guard_held

func set_dash_input(pressed: bool) -> void:
	dash_requested = (dash_requested or pressed) if active() else false

func fleet_remaining() -> int:
	var remaining := 12
	for i in 10:
		if sunk_at[i]>=0: remaining-=1
	if background_sunk_at>=0: remaining-=1
	return remaining

func start() -> void:
	if phase != Phase.READY: return
	_change(Phase.TRAVERSAL)
	_enter_boat(0)
	_save_checkpoint()

func _set_state(state: String) -> void:
	if encounter_state == state: return
	encounter_state = state
	state_history.append({"state":state,"clock":clock,"score_time":score_time,"boat":visited_boat})
	phase_changed.emit()

func surface_endpoints(index: int, at_time: float = -1.0) -> Array[Vector2]:
	var p: Dictionary = platforms[index]
	var r: Rect2 = p.rect
	var t: float = clock if at_time < 0 else at_time
	var offset := Vector2.ZERO
	if p.kind == "wreck":
		offset.x = sin(t*0.95+float(index)*1.6)*float(p.get("drift",0))
		offset.y = water_height_at(r.get_center().x+offset.x,t)-18-r.position.y
	if p.drop_at >= 0: offset.y += pow(maxf(0,t-float(p.drop_at)),2)*(10.0 if p.kind=="deck" else 100.0)
	return [r.position+offset,Vector2(r.end.x,r.position.y)+offset]

func surface_y_at(index: int, x: float, at_time: float = -1.0) -> float:
	var ends := surface_endpoints(index,at_time)
	return lerpf(ends[0].y,ends[1].y,clampf((x-ends[0].x)/maxf(1,ends[1].x-ends[0].x),0,1))

func platform_rect(index: int, at_time: float = -1.0) -> Rect2:
	var ends := surface_endpoints(index,at_time)
	return Rect2(ends[0],Vector2(ends[1].x-ends[0].x,20))

func _obstacle_enabled(o: Dictionary) -> bool:
	return bool(o.get("active",true)) and (int(o.boat)==final_index or sunk_at[int(o.boat)]<0)

func can_stand() -> bool:
	for o in obstacles:
		if _obstacle_enabled(o) and body_rect(position,0).intersects(o.rect.grow(-0.1)): return false
	return true

func _step(dt: float, move: float, duck: bool, jump_held: bool, interact: bool) -> void:
	if not active() and phase != Phase.ESCAPING: return
	clock += dt
	route_clock += dt
	elapsed_total += dt
	phase_clock += dt
	score_time += dt
	score_beat = score_time/maxf(0.1,score_beat_seconds)
	simulation_delta = dt
	for field in ["hit_flash","impact_flash","landing_flash","invulnerable","hit_stun","jump_buffer"]:
		set(field,maxf(0,float(get(field))-dt))
	dash_cooldown_remaining=maxf(0,dash_cooldown_remaining-dt)
	if phase == Phase.ESCAPING:
		dash_time=0
		dash_requested=false
		# The director waits for the next phrase before starting the escape cue.
		# Standalone simulation uses the identical cue duration on its own clock.
		if externally_directed_escape:
			phase_clock=maxf(0,escape_score_age)
		else:
			escape_score_age=phase_clock
		if escape_score_age>=escape_release_at and not wind_released:
			wind_released=true
			encounter_cue.emit("gust")
			impact.emit("wind")
		if escape_score_age>=escape_duration:
			_change(Phase.COMPLETE)
			completion_count += 1
			completed.emit(record())
		return
	coyote = float(level.physics.coyote_seconds) if grounded else maxf(0,coyote-dt)
	if grounded and support >= 0 and not platforms[support].gone:
		position += surface_endpoints(support)[0]-surface_endpoints(support,clock-dt)[0]
	crouching = (duck and grounded) or (crouching and not can_stand())
	var speed: float = float(level.physics.crouch_speed if crouching else level.physics.run_speed)*(0.92 if has_bag else 1.0)
	var accel: float = float(level.physics.acceleration if grounded else level.physics.air_acceleration)
	if phase==Phase.FINAL_SHIP and combat_guard: speed*=0.48
	if dash_requested and dash_cooldown_remaining<=0 and hit_stun<=0 and not crouching and not combat_guard and boarding.player_attack_age<0:
		dash_direction=signf(move) if absf(move)>0.05 else facing
		facing=dash_direction
		dash_time=DASH_DURATION
		dash_cooldown_remaining=maxf(0.5,dash_cooldown_seconds)
		dashes+=1
		encounter_cue.emit("dash")
	dash_requested=false
	if hit_stun>0: dash_time=0
	if dash_time>0:
		velocity.x=dash_direction*dash_speed
	elif hit_stun <= 0:
		velocity.x = move_toward(velocity.x,move*speed,accel*dt)
	if absf(move)>0.05 and hit_stun<=0 and dash_time<=0: facing=signf(move)
	if jump_buffer>0 and coyote>0 and not crouching and hit_stun<=0:
		velocity.y=-float(level.physics.jump_speed)
		grounded=false
		coyote=0
		jump_buffer=0
		jumps+=1
	if not jump_held and velocity.y < -260: velocity.y=-260
	velocity.y=minf(900,velocity.y+float(level.physics.gravity)*dt)
	_move_horizontal(dt)
	_move_vertical(dt)
	if dash_time>0:
		dash_time=maxf(0,dash_time-dt) if absf(velocity.x)>0 else 0.0
		if dash_time<=0: velocity.x=clampf(velocity.x,-speed,speed)
	max_x=maxf(max_x,position.x)
	_update_world()
	_update_attacks(dt)
	interaction_active=false
	if phase == Phase.FINAL_SHIP:
		position.x=clampf(position.x,final_origin+24,final_origin+1576)
		_tick_boarding(dt)
		_final_interaction(dt,interact)
	if position.y>SEA_LEVEL+20: _fail("O mar tomou o apoio. Enter retoma o último trecho.")

func _move_horizontal(dt: float) -> void:
	var old:=position.x
	position.x=clampf(position.x+velocity.x*dt,50,final_origin+1590)
	for o in obstacles:
		if not _obstacle_enabled(o): continue
		var r: Rect2=o.rect
		if not body_rect().intersects(r.grow(-0.1)): continue
		if old+HALF_WIDTH<=r.position.x+2 and velocity.x>0:
			position.x=r.position.x-HALF_WIDTH
			velocity.x=0
		elif old-HALF_WIDTH>=r.end.x-2 and velocity.x<0:
			position.x=r.end.x+HALF_WIDTH
			velocity.x=0

func _move_vertical(dt: float) -> void:
	var old_y:=position.y
	var was_grounded:=grounded
	position.y+=velocity.y*dt
	grounded=false
	support=-1
	var best:=INF
	if velocity.y>=0:
		for i in platforms.size():
			if platforms[i].gone: continue
			var r:=platform_rect(i)
			var previous:=platform_rect(i,clock-dt)
			if position.x+HALF_WIDTH<=r.position.x or position.x-HALF_WIDTH>=r.end.x: continue
			if old_y<=maxf(r.position.y,previous.position.y)+3 and position.y>=r.position.y and r.position.y<best:
				best=r.position.y
				support=i
		for o in obstacles:
			if not _obstacle_enabled(o): continue
			var r: Rect2=o.rect
			if position.x+HALF_WIDTH>r.position.x and position.x-HALF_WIDTH<r.end.x and old_y<=r.position.y+1 and position.y>=r.position.y and r.position.y<best:
				best=r.position.y
				support=-1
		if best<INF:
			position.y=best
			velocity.y=0
			grounded=true
			if not was_grounded:
				landing_flash=0.12
				if support>=0 and platforms[support].kind=="wreck":
					mobile_landings+=1
					if platforms[support].boat==final_index and has_bag: returned_lower=true
	else:
		for o in obstacles:
			if not _obstacle_enabled(o): continue
			var r: Rect2=o.rect
			var height:=CROUCH_HEIGHT if crouching else STAND_HEIGHT
			if body_rect().intersects(r) and old_y-height>=r.end.y-2:
				position.y=r.end.y+height
				velocity.y=0
	if grounded and support>=0:
		var p: Dictionary=platforms[support]
		if p.touched<0: p.touched=clock
		if p.kind=="deck": _enter_boat(int(p.boat))

func _enter_boat(index: int) -> void:
	if boats[index].entered>=0: return
	boats[index].entered=clock
	visited_boat=maxi(visited_boat,index)
	last_landing_boat=index
	attack_number=0
	next_attack_score=_next_beat(score_time,4)
	if index==final_index:
		_change(Phase.FINAL_SHIP)
		var arena: Rect2=boats[final_index].rect
		arena.size.x=1330 # The bow cargo is outside the soldiers' walking space.
		boarding.setup(arena)
		god_presence=1.0
		encounter_cue.emit("divine_rumble")
		_set_state("boarding")
		_request_section("bag")
		route_beat="Derrote os soldados de água e recupere a bolsa."
		balance=100
		hazards.clear()
		next_attack_score=_next_beat(score_time,12)
		_save_checkpoint()
	elif index in [3,6]:
		_set_state("traversal")
		_request_section("wrecks" if index==3 else "onslaught")
		balance=maxf(balance,75)
		_save_checkpoint()
	elif index in [2,5]:
		_set_state("refuge")
		route_beat="Um instante de abrigo. O seu navio ainda está adiante."
	else:
		_set_state("traversal")
		route_beat="Atravesse a frota até o navio de Odisseu."

func _next_beat(time: float, beats: int = 1) -> float:
	var unit:=maxf(0.1,score_beat_seconds)*float(beats)
	return (floorf(time/unit)+1)*unit

func _queue_sink(index: int) -> void:
	for event in pending_sinks:
		if int(event.index)==index: return
	pending_sinks.append({"index":index,"at":_next_beat(score_time)})

func _sink(index: int) -> void:
	# The captain vessel never participates in the loss ledger.
	if index<0 or index>=final_index or sunk_at[index]>=0: return
	sunk_at[index]=clock
	if index<final_index:
		boats[index].collapse=clock
		boats[index].damage_progress=0.01
		for p in platforms:
			if p.kind=="deck" and p.boat==index:
				p.drop_at=clock
				p.gone=false
	impact_flash=maxf(impact_flash,0.3)
	ship_sunk.emit(index)
	impact.emit("ship")
	encounter_cue.emit("wood_snap")
	chart_events.append({"kind":"ship","score_time":score_time,"clock":clock,"boat":index})

func _update_world() -> void:
	for i in range(pending_sinks.size()-1,-1,-1):
		if score_time>=float(pending_sinks[i].at):
			_sink(int(pending_sinks[i].index))
			pending_sinks.remove_at(i)
	_update_fleet_assaults()
	for p in platforms:
		if p.kind=="deck" and p.boat<final_index and p.drop_at>=0 and clock-float(p.drop_at)>=4.0: p.gone=true
	var current: Dictionary=boats[visited_boat]
	var refuge:=encounter_state=="refuge" or (phase==Phase.FINAL_SHIP and boarding.cleared)
	var is_boarding:=phase==Phase.FINAL_SHIP and not boarding.cleared
	quiet=0.85 if refuge else 0.1
	tension=0.3 if refuge else 0.72 if visited_boat<6 else 0.95
	god_presence=move_toward(god_presence,0.12,simulation_delta*0.35)
	for i in mini(visited_boat,10):
		if sunk_at[i]>=0: boats[i].damage_progress=smoothstep(0,3,clock-float(sunk_at[i]))
	# The phrase schedules births; attacks must still travel from on-screen space.
	if not refuge and score_time>=next_attack_score and position.x>current.rect.position.x+(60 if is_boarding else 120) and position.x<current.rect.end.x-(60 if is_boarding else 350):
		var pattern: Array=["low","high","low","slam"] if visited_boat<6 else ["high","low","slam","low"]
		var kind: String=pattern[attack_number%pattern.size()]
		if phase==Phase.FINAL_SHIP and has_bag: kind="high" if attack_number%2==0 else "low"
		# A low sweep must never demand a jump inside a solid overhead spar.
		for o in obstacles:
			if not _obstacle_enabled(o) or int(o.boat)!=visited_boat: continue
			var r: Rect2=o.rect
			if o.kind=="beam" and position.x>r.position.x-500 and position.x<r.end.x+50: kind="high"
		_spawn_attack(kind,visited_boat)
		attack_number+=1
		var interval_beats:=12 if is_boarding else 8 if visited_boat<3 else 6 if visited_boat<6 else 4
		next_attack_score=_next_beat(score_time,interval_beats)
		# A delayed entrance into the attack lane cannot create two births almost
		# together merely because the following bar is only a few frames away.
		if next_attack_score-score_time<score_beat_seconds*float(interval_beats-1):
			next_attack_score+=score_beat_seconds*float(interval_beats)
	# Spent wrecks settle into the same surface used by drawing and collision.
	for p in platforms:
		if p.kind!="wreck" or p.gone or p.touched<0: continue
		if clock-float(p.touched)>2.8 and p.drop_at<0: p.drop_at=clock
		if p.drop_at>=0 and clock-float(p.drop_at)>0.9: p.gone=true


func _update_fleet_assaults() -> void:
	# Poseidon's next strike selects a vessel; crossing a seam never destroys it.
	if score_time>=fleet_next_score:
		var target := -1
		for i in 10:
			if sunk_at[i]>=0: continue
			var already_targeted:=false
			for strike in fleet_assaults:
				if int(strike.boat)==i and not strike.resolved: already_targeted=true
			var entered: float=boats[i].entered
			if not already_targeted and (i<visited_boat or (i==visited_boat and entered>=0 and (position.x>boats[i].rect.end.x-400 or clock-entered>18.0))):
				target=i
			break
		if target<0 and visited_boat==final_index and fleet_remaining()==2 and background_sunk_at<0:
			target=11
		if target>=0:
			fleet_assaults.append({"boat":target,"age":0.0,"duration":2.2,"resolved":false})
			god_presence=1.0
			encounter_cue.emit("divine_rumble")
			chart_events.append({"kind":"fleet_assault","boat":target,"score_time":score_time,"clock":clock})
		fleet_next_score=_next_beat(score_time,8 if target>=0 else 4)
	for i in range(fleet_assaults.size()-1,-1,-1):
		var strike: Dictionary=fleet_assaults[i]
		strike.age=float(strike.age)+simulation_delta
		if not strike.resolved and float(strike.age)>=float(strike.duration):
			strike.resolved=true
			if int(strike.boat)==11:
				background_sunk_at=clock
				encounter_cue.emit("wood_snap")
				ship_sunk.emit(11)
			else: _sink(int(strike.boat))
		if float(strike.age)>float(strike.duration)+4.5: fleet_assaults.remove_at(i)

func _tick_boarding(dt: float) -> void:
	var was_cleared: bool=boarding.cleared
	var previous_wave: int=boarding.wave
	var action: Dictionary=boarding.tick(dt,position,facing,grounded,crouching,combat_attack and dash_time<=0,combat_guard and dash_time<=0)
	combat_attack=false
	if boarding.wave>previous_wave:
		god_presence=1.0
		encounter_cue.emit("divine_rumble")
	if float(action.damage)>0 and invulnerable<=0:
		dash_time=0
		hits+=1
		balance=maxf(0,balance-float(action.damage))
		invulnerable=0.7
		hit_flash=0.25
		hit_stun=0.14
		velocity.x=float(action.side)*120
		encounter_cue.emit("wood_snap")
		if balance<=0: _fail("Os soldados de água interromperam a fuga. Enter retoma o combate.")
	if action.cue=="sword_swing": encounter_cue.emit("sword_swing")
	elif action.cue=="sword_hit": encounter_cue.emit("splash")
	elif action.cue=="guard": encounter_cue.emit("splash")
	elif action.cue=="water_fall":
		impact_flash=0.22
		encounter_cue.emit("splash")
	if boarding.cleared and not was_cleared and phase==Phase.FINAL_SHIP:
		# Existing water keeps its visual follow-through; victory opens a safe gap.
		for hazard in hazards: hazard.hit=true
		encounter_cue.emit("splash")
		_set_state("bag")
		route_beat="Convés livre. Recupere a bolsa na proa."
		_save_checkpoint()

func _spawn_attack(kind: String, boat_index: int) -> void:
	var deck: Rect2=boats[boat_index].rect
	var from_x:=clampf(position.x+620,deck.position.x+180,deck.end.x+100)
	var target:=clampf(position.x+velocity.x*0.42,deck.position.x+80,deck.end.x-80)
	var formation:=0.6 if kind!="slam" else 0.78
	var speed:=440.0+float(mini(boat_index,9))*9
	hazards.append({"kind":kind,"age":0.0,"warning":formation,"boat":boat_index,"x":target if kind=="slam" else from_x,"y":deck.position.y,"target":target,"hit":false,"passed":false,"counted":false,"speed":speed,"musical_beat":score_beat,"formation":formation})
	chart_events.append({"kind":kind,"score_time":score_time,"clock":clock,"boat":boat_index})
	if kind=="slam": god_presence=1.0
	attack_started.emit(kind)

func _hit(kind: String, side: float) -> void:
	dash_time=0
	hits+=1
	balance=maxf(0,balance-(34 if kind=="slam" else 28))
	invulnerable=0.8
	hit_flash=0.25
	hit_stun=0.12
	velocity.x=side*100
	encounter_cue.emit("splash")
	if balance<=0: _fail("Poseidon quebrou sua resistência. Enter retoma o último trecho.")

func bindings_done() -> int:
	return 3 # Compatibility only: this version contains no binding minigame.

func _final_interaction(dt: float, interact: bool) -> void:
	if not interact or not grounded or hit_stun>0 or dash_time>0: return
	if not has_bag and boarding.cleared and position.distance_to(bag_point)<62:
		interaction_active=true
		bag_progress=minf(1,bag_progress+dt/float(level.final.bag_seconds))
		if bag_progress>=1:
			has_bag=true
			_set_state("return")
			route_beat="Volte à popa e libere os ventos."
			_save_checkpoint()
	elif has_bag and position.distance_to(exit_point)<65:
		interaction_active=true
		wind_progress=minf(1,wind_progress+dt/float(level.final.release_seconds))
		if wind_progress>=1 and fleet_remaining()==1:
			escape_score_age=-1
			wind_released=false
			_change(Phase.ESCAPING)
			_set_state("escaping")
			_request_section("escape")

func _save_checkpoint() -> void:
	super()
	checkpoint["music"]=score_snapshot.duplicate(true)
	local_checkpoint={"score_time":score_time,"score_beat":score_beat,"score_section":score_section,"next_attack_score":next_attack_score,"attack_number":attack_number,"route_clock":route_clock,"encounter_state":encounter_state,"route_beat":route_beat,"obstacles":obstacles.duplicate(true),"hazards":hazards.duplicate(true),"support":support,"grounded":grounded,"returned_lower":returned_lower,"split_age":split_age,"chart_events":chart_events.duplicate(true),"state_history":state_history.duplicate(true),"wind_progress":wind_progress,"balance":balance}
	local_checkpoint["pending_sinks"]=pending_sinks.duplicate(true)
	local_checkpoint["split_at_score"]=split_at_score
	local_checkpoint["escape_score_age"]=escape_score_age
	local_checkpoint["wind_released"]=wind_released
	local_checkpoint["phase_clock"]=phase_clock
	local_checkpoint["god_presence"]=god_presence
	local_checkpoint["tension"]=tension
	local_checkpoint["quiet"]=quiet
	local_checkpoint["boarding"]=boarding.snapshot()
	local_checkpoint["fleet_assaults"]=fleet_assaults.duplicate(true)
	local_checkpoint["fleet_next_score"]=fleet_next_score
	local_checkpoint["background_sunk_at"]=background_sunk_at
	local_checkpoint["dash_time"]=dash_time
	local_checkpoint["dash_cooldown_remaining"]=dash_cooldown_remaining
	local_checkpoint["dash_direction"]=dash_direction
	checkpoint_created.emit()

func retry_checkpoint() -> void:
	if phase!=Phase.FAILED or checkpoint.is_empty(): return
	var data:=local_checkpoint.duplicate(true)
	var base:=checkpoint.duplicate(true)
	super()
	clock=base.at
	boats=base.boats.duplicate(true)
	platforms=base.platforms.duplicate(true)
	sunk_at.assign(base.sunk_at)
	for field in ["score_time","score_beat","score_section","next_attack_score","attack_number","route_clock","encounter_state","route_beat","support","grounded","returned_lower","split_age","wind_progress","balance"]: set(field,data[field])
	obstacles=data.obstacles.duplicate(true)
	hazards=data.hazards.duplicate(true)
	chart_events=data.chart_events.duplicate(true)
	state_history=data.state_history.duplicate(true)
	pending_sinks.assign(data.pending_sinks.duplicate(true))
	split_at_score=data.split_at_score
	escape_score_age=data.escape_score_age
	wind_released=data.wind_released
	phase_clock=data.phase_clock
	god_presence=data.god_presence
	tension=data.tension
	quiet=data.quiet
	boarding.restore(data.boarding)
	fleet_assaults.assign(data.fleet_assaults.duplicate(true))
	fleet_next_score=data.fleet_next_score
	background_sunk_at=data.background_sunk_at
	dash_time=data.get("dash_time",0.0)
	dash_cooldown_remaining=data.get("dash_cooldown_remaining",0.0)
	dash_direction=data.get("dash_direction",facing)
	dash_requested=false
	combat_attack=false
	combat_guard=false
	velocity=Vector2.ZERO
	jump_buffer=0
	hit_stun=0
	invulnerable=0
	crouching=false
	if base.has("music"):
		score_snapshot=base.music.duplicate(true)
		music_seek_requested.emit(score_snapshot)
	feedback.emit("Trecho retomado.","notice")

func objective() -> String:
	if phase==Phase.FAILED: return "TRAVESSIA INTERROMPIDA"
	if phase in [Phase.ESCAPING,Phase.COMPLETE]: return "UM ÚNICO NAVIO ESCAPOU"
	if has_bag: return "VOLTE À POPA · LIBERE OS VENTOS"
	if phase==Phase.FINAL_SHIP: return "DERROTE OS SOLDADOS DE ÁGUA · %d/3" % boarding.kills if not boarding.cleared else "ALCANCE A BOLSA NA PROA"
	return "ATRAVESSE A FROTA · NAVIO %d/10" % (mini(visited_boat,9)+1)

func prompt() -> String:
	if phase==Phase.FINAL_SHIP:
		if not has_bag and not boarding.cleared: return "SHIFT · DEFENDER     Q / BOTÃO DIREITO · DASH     PULE OU ABAIXE DOS GOLPES"
		if not has_bag and position.distance_to(bag_point)<62: return "SEGURE E · PEGAR A BOLSA"
		if has_bag and position.distance_to(exit_point)<65: return "SEGURE E · LIBERAR OS VENTOS"
	return ""

func record() -> Dictionary:
	return {"escaped":phase==Phase.COMPLETE,"seconds":snappedf(elapsed_total,0.1),"route_seconds":snappedf(clock,0.1),"ships_lost":12-fleet_remaining(),"ships_remaining":fleet_remaining(),"boats_crossed":mini(visited_boat,10),"hits":hits,"jumps":jumps,"retries":retries,"ducked_attacks":ducked_attacks,"attacks_cleared":cleared_attacks,"bindings":0,"has_bag":has_bag,"returned_lower":returned_lower,"mobile_landings":mobile_landings,"chart_events":chart_events.size(),"water_soldiers_defeated":boarding.kills,"captain_ship_intact":not mast_broken and sunk_at[10]<0,"mode":"ruthlessness_water_boarding"}
