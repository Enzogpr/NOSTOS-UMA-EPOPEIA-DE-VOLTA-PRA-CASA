extends RefCounted
## Top-down physical duel. Moly resists enchantment automatically, entirely offline.
signal feedback(message: String)
signal cue(kind: String)
signal health_changed(value: int)
signal phase_changed
signal won
signal failed
const PALACE := preload("res://Ato5_Circe/Gameplay/CircePalace.gd")
const SIDESTEP_SPEED := 155.0
const COUNTER_ATTACKS := ["table","roots"]
enum Phase {READY, DUEL, MIRRORS, PALACE, WON, FAILED}
var tuning: Dictionary
var arena: Rect2
var phase := Phase.READY
var clock := 0.0
var phase_clock := 0.0
var hp := 10
var max_hp := 10
var damage := 3
var speed_mult := 1.0
var dash_cooldown := 3.0
var intellect := 5
var position := Vector2(245,420)
var velocity := Vector2.ZERO
var facing := Vector2.RIGHT
var input_axis := Vector2.ZERO
var aim := Vector2.RIGHT
var defend_held := false
var observe_held := false
var guarding := false
var guard_age := 9.0
var dash_direction := Vector2.RIGHT
var dash_time := 0.0
var dash_recharge := 0.0
var attack_age := -1.0
var attack_recharge := 0.0
var attack_direction := Vector2.RIGHT
var attack_connected := false
var invulnerability := 0.0
var hit_flash := 0.0
var flower_flash := 0.0
var impact_flash := 0.0
var focus := 100.0
var observing := false
var observe_progress := 0.0
var reveal_time := 0.0
var reveal_recharge := 0.0
var boss_hp: int
var boss_position := Vector2(850,330)
var boss_facing := Vector2.LEFT
var boss_velocity := Vector2.ZERO
var boss_step_direction := Vector2.ZERO
var boss_flash := 0.0
var boss_state := "idle"
var boss_age := 0.0
var boss_recovery := 0.0
var attack_kind := "enchant"
var attack_index := 0
var counter_index := 0
var attack_origin := Vector2.ZERO
var locked_target := Vector2.ZERO
var mirror_spots: Array[Vector2]=[]
var clone_positions: Array[Vector2]=[]
var real_slot := 1
var clone_flashes := [0.0,0.0,0.0]
var illusion_hits := 0
var protected_spells := 0
var tables: Array=[]
var roots: Array=[]
var effects: Array=[]
var palace: PALACE
var retries := 0
var last_safe := Vector2(245,420)

func _init() -> void:
	tuning=JSON.parse_string(FileAccess.get_file_as_string("res://Ato5_Circe/Gameplay/CirceBattleTuning.json"))
	var r: Array=tuning.arena; arena=Rect2(r[0],r[1],r[2],r[3])
	boss_hp=int(tuning.boss_hp)
	for p in tuning.mirror_spots: mirror_spots.append(Vector2(p[0],p[1]))
	clone_positions = mirror_spots.duplicate()
	palace=PALACE.new(tuning.palace_events)

func apply_player_stats(stats: Dictionary) -> void:
	max_hp=maxi(1,int(stats.get("max_hp",max_hp))); hp=clampi(int(stats.get("current_hp",hp)),0,max_hp)
	damage=maxi(1,int(stats.get("damage",damage)))
	speed_mult=maxf(0.3,float(stats.get("speed_mult",speed_mult)))
	var remaining_dash := clampf(dash_recharge/dash_cooldown,0.0,1.0)
	dash_cooldown=maxf(0.5,float(stats.get("dash_cooldown",dash_cooldown)))
	dash_recharge = dash_cooldown*remaining_dash
	intellect=int(stats.get("intellect",intellect))
	if hp<=0 and active(): _fail()

func active() -> bool: return phase in [Phase.DUEL,Phase.MIRRORS,Phase.PALACE]

func begin() -> void:
	if phase!=Phase.READY: return
	_enter_phase(Phase.DUEL)
	feedback.emit("A flor repele os encantamentos. Um acerto de espada interrompe o ataque de Circe.")
	if hp<=0: _fail()

func _enter_phase(value: Phase) -> void:
	phase=value; phase_clock=0
	tables.clear(); roots.clear(); boss_state="idle"; boss_age=-0.8; attack_index=0
	boss_velocity = Vector2.ZERO
	boss_flash = 0.0
	observe_progress=0; observing=false; reveal_time=0; attack_age=-1; attack_recharge=0
	if value==Phase.MIRRORS:
		_shift_mirrors(1)
		feedback.emit("As cópias repetem os gestos. Segure E, parado, para enxergar a verdadeira Circe.")
	elif value==Phase.PALACE:
		palace.arm(position)
		feedback.emit("O salão reage aos seus passos. Observe as colunas, as correntes e as rachaduras.")
	phase_changed.emit()

func set_input(movement: Vector2,look: Vector2,defend: bool,observe: bool) -> void:
	input_axis=movement.limit_length(1)
	if look.length_squared()>0.01: aim=look.normalized()
	defend_held=defend; observe_held=observe

func request_attack() -> void:
	if not active() or attack_recharge>0 or dash_time>0 or observing or defend_held: return
	attack_age=0; attack_recharge=float(tuning.sword_cooldown)
	attack_direction=aim; attack_connected=false; cue.emit("sword")

func request_dash() -> void:
	if not active() or dash_recharge>0 or dash_time>0 or attack_age>=0: return
	dash_direction=input_axis.normalized() if input_axis.length_squared()>0.01 else aim
	dash_time=float(tuning.dash_duration); dash_recharge=dash_cooldown
	observing=false; observe_progress=0
	palace.notify("dash",position); cue.emit("dash")

func tick(delta: float) -> void:
	if not active(): return
	clock+=delta; phase_clock+=delta
	var dash_step := minf(dash_time,delta)
	for key in ["dash_time","dash_recharge","attack_recharge","invulnerability","hit_flash","flower_flash","impact_flash","boss_flash","reveal_time","reveal_recharge"]:
		set(key,maxf(0,float(get(key))-delta))
	for i in 3: clone_flashes[i]=maxf(0,float(clone_flashes[i])-delta)
	focus=minf(100,focus+delta*clampf(4+(intellect-5)*0.45,2,8))
	if dash_step<=0: _observe(delta)
	if aim.length_squared()>0.01 and attack_age<0 and dash_step<=0: facing=aim
	var was_guarding := guarding
	guarding=defend_held and not observing and dash_step<=0 and attack_age<0
	guard_age=guard_age+delta if was_guarding else 0.0
	var desired := input_axis*float(tuning.player_speed)*speed_mult
	if guarding: desired*=0.5
	if attack_age>=0: desired*=0.42
	if observing: desired=Vector2.ZERO
	if dash_step>0:
		invulnerability = maxf(invulnerability,dash_step)
		velocity = dash_direction*float(tuning.dash_speed)
		_move(dash_step)
		if dash_time<=0: velocity=Vector2.ZERO
	else:
		velocity=velocity.move_toward(desired,delta*2400)
		_move(delta)
	if attack_age>=0:
		attack_age+=delta
		if attack_age>=0.10 and not attack_connected: _sword_hit()
		if attack_age>0.31: attack_age=-1
	if not active(): return
	_boss_tick(delta); _tables_tick(delta); _roots_tick(delta)
	if phase==Phase.PALACE:
		for event in palace.tick(delta,position,float(tuning.player_radius)):
			cue.emit("impact"); impact_flash=0.25
			if event.kind=="column" and PALACE.rectangle(event).grow(13).has_point(position):
				_hurt(2,Vector2(event.pivot[0],event.pivot[1])); _evacuate()
		if palace.pit_at(position,5) and dash_time<=0 and invulnerability<=0:
			_hurt(2,position); position=last_safe; _evacuate()
		if not _boss_can_stand(boss_position):
			var previous := boss_position
			if _shift_mirrors(real_slot):
				_effect(previous,"teleport")
				_effect(boss_position,"teleport")
				if boss_state=="windup": _begin_windup()
	if not palace.pit_at(position,45) and walkable(position): last_safe=position
	for e in effects: e.age+=delta
	effects=effects.filter(func(e: Dictionary): return e.age<0.8)

func _observe(delta: float) -> void:
	observing=observe_held and phase in [Phase.MIRRORS,Phase.PALACE] and focus>=float(tuning.observe_cost) and reveal_recharge<=0 and attack_age<0 and dash_time<=0
	if not observing: observe_progress=0; return
	velocity=Vector2.ZERO; observe_progress+=delta
	var required := maxf(0.46,float(tuning.observe_charge)-(intellect-5)*0.012)
	if observe_progress>=required:
		focus-=float(tuning.observe_cost)
		reveal_time=float(tuning.observe_duration)+clampf((intellect-5)*0.09,0,1.5)
		reveal_recharge=2.8; observe_progress=0; observing=false
		cue.emit("reveal"); _effect(boss_position,"gold")

func solid_rects() -> Array[Rect2]:
	var solids := palace.solids()
	for i in [0,3]:
		var definition: Dictionary=tuning.palace_events[i]
		var is_fallen := false
		for event in palace.events:
			if event.id==definition.id and event.progress>=1: is_fallen=true
		if not is_fallen:
			var pivot := Vector2(definition.pivot[0],definition.pivot[1])
			solids.append(Rect2(pivot-Vector2(18,13),Vector2(36,26)))
	return solids

func walkable(at: Vector2) -> bool:
	if not arena.grow(-float(tuning.player_radius)).has_point(at): return false
	for rect in solid_rects():
		if rect.grow(float(tuning.player_radius)).has_point(at): return false
	return true

func _move(delta: float) -> void:
	var next := position+Vector2(velocity.x*delta,0)
	if walkable(next): position.x=next.x
	else: velocity.x=0
	next=position+Vector2(0,velocity.y*delta)
	if walkable(next): position.y=next.y
	else: velocity.y=0
	var separation := position-boss_position
	if separation.length()<34:
		var pushed := boss_position+separation.normalized()*34 if separation.length()>0.01 else boss_position+Vector2(-34,0)
		if walkable(pushed): position=pushed

func _evacuate() -> void:
	if walkable(position) and not palace.pit_at(position,15): return
	for distance in [35,65,100,145,200]:
		for i in 16:
			var at: Vector2=position+Vector2.from_angle(i*TAU/16)*float(distance)
			if walkable(at) and not palace.pit_at(at,15): position=at; return
	position=Vector2(245,420)

func _boss_tick(delta: float) -> void:
	boss_velocity = Vector2.ZERO
	boss_age+=delta
	match boss_state:
		"idle":
			if boss_age>=0.45: _start_attack()
		"reposition":
			_move_boss(boss_step_direction,SIDESTEP_SPEED,delta,true)
			if boss_age>=0.46: _begin_windup()
		"approach":
			_move_boss(boss_position.direction_to(position),135.0,delta)
			boss_facing = boss_position.direction_to(position)
			if boss_position.distance_to(position)<112 or boss_age>1.2:
				_begin_windup()
		"windup":
			if boss_age>=0.70: _resolve_attack()
		"recovery":
			if boss_age>=boss_recovery:
				boss_state="idle"; boss_age=0
				if phase in [Phase.MIRRORS,Phase.PALACE]:
					_shift_mirrors([1,0,2,0,1,2][attack_index%6])

func _boss_can_stand(at: Vector2) -> bool:
	return walkable(at) and not palace.pit_at(at,18.0)

func _move_boss(direction: Vector2,speed: float,delta: float,move_copies := false) -> void:
	for turn in [0.0,PI/4.0,-PI/4.0,PI/2.0,-PI/2.0]:
		var step := direction.rotated(turn)*speed*delta
		var next := boss_position+step
		if not _boss_can_stand(next) or next.distance_to(position)<38.0:
			continue
		boss_position = next
		boss_velocity = step/delta
		if move_copies and phase in [Phase.MIRRORS,Phase.PALACE]:
			for index in clone_positions.size():
				var clone_next := clone_positions[index]+step
				if index!=real_slot and _boss_can_stand(clone_next):
					clone_positions[index] = clone_next
		return

func _shift_mirrors(preferred_slot: int,previous := Vector2.INF,clearance := 42.0) -> bool:
	for offset in mirror_spots.size():
		var slot := (preferred_slot+offset)%mirror_spots.size()
		var next := mirror_spots[slot]
		if not _boss_can_stand(next) or next.distance_to(position)<clearance or next.distance_to(previous)<130.0:
			continue
		_place_boss(slot,next)
		return true
	return false

func _place_boss(slot: int,at: Vector2) -> void:
	real_slot = slot
	boss_position = at
	boss_velocity = Vector2.ZERO
	clone_positions = mirror_spots.duplicate()

func _counterattack(hit_at: Vector2) -> void:
	var slot := (real_slot+1)%mirror_spots.size()
	if not _shift_mirrors(slot,hit_at,135.0):
		# Falling columns and pits can cut off the usual mirror positions.
		for fraction: Vector2 in [Vector2(0.18,0.25),Vector2(0.82,0.75),Vector2(0.18,0.75),Vector2(0.82,0.25)]:
			var next := arena.position+arena.size*fraction
			if _boss_can_stand(next) and next.distance_to(position)>=135.0 and next.distance_to(hit_at)>=130.0:
				_place_boss(slot,next)
				break
	_effect(hit_at,"teleport")
	_effect(boss_position,"teleport")
	boss_flash = 0.12
	attack_kind = COUNTER_ATTACKS[counter_index%COUNTER_ATTACKS.size()]
	counter_index += 1
	_begin_windup()

func _start_attack() -> void:
	attack_kind=tuning.attack_pattern[attack_index%tuning.attack_pattern.size()]
	attack_index+=1
	var toward := boss_position.direction_to(position)
	var spacing := clampf((boss_position.distance_to(position)-210.0)/90.0,-1.0,0.75)
	var side := 1.0 if attack_index%2==0 else -1.0
	boss_step_direction = (toward*spacing+toward.orthogonal()*side).normalized()
	boss_state = "approach" if attack_kind=="staff" else "reposition"
	boss_age = 0.0

func _begin_windup() -> void:
	attack_origin = boss_position
	locked_target = position
	boss_facing = boss_position.direction_to(locked_target)
	boss_state = "windup"
	boss_age = 0.0
	cue.emit("cast")

func _resolve_attack() -> void:
	if attack_kind=="enchant":
		protected_spells+=1; flower_flash=0.65
		_effect(position,"gold"); _effect(boss_position,"violet"); cue.emit("flower"); boss_recovery=2.3
	elif attack_kind=="table":
		var direction := (locked_target-boss_position).normalized()
		tables.append({"p":boss_position+direction*38,"v":direction*float(tuning.table_speed),"age":0.0,"angle":0.0})
		boss_recovery=1.85
	elif attack_kind=="roots":
		roots.append({"p":locked_target,"age":0.0,"hit":false})
		if phase==Phase.PALACE: roots.append({"p":last_safe,"age":-0.25,"hit":false})
		boss_recovery=1.9
	else:
		var difference := position-boss_position
		if difference.length()<128 and difference.normalized().dot(boss_facing)>0.1: _hurt(2,boss_position,true)
		_effect(boss_position+boss_facing*65,"staff"); cue.emit("staff"); boss_recovery=1.8
	boss_state="recovery"; boss_age=0

func _tables_tick(delta: float) -> void:
	for i in range(tables.size()-1,-1,-1):
		var table: Dictionary=tables[i]
		table.age+=delta; table.angle+=delta*2.2
		var previous: Vector2=table.p; table.p+=table.v*delta
		var collided := false
		if Geometry2D.get_closest_point_to_segment(position,previous,table.p).distance_to(position)<36:
			_hurt(2,table.p); collided=true
		for rect in solid_rects():
			if rect.grow(18).has_point(table.p): collided=true
		if collided or not arena.grow(45).has_point(table.p) or table.age>3.0:
			_effect(table.p,"wood"); tables.remove_at(i); cue.emit("impact")

func _roots_tick(delta: float) -> void:
	for root in roots:
		root.age+=delta
		if root.age>=float(tuning.root_warning) and not root.hit and root.p.distance_to(position)<43:
			root.hit=true; _hurt(1,root.p)
	roots=roots.filter(func(r: Dictionary): return r.age<float(tuning.root_warning)+1.2)

func _sword_hit() -> void:
	attack_connected=true
	if phase in [Phase.MIRRORS,Phase.PALACE]:
		for i in 3:
			if i==real_slot or float(clone_flashes[i])>0: continue
			if _in_sword(clone_positions[i]):
				clone_flashes[i]=1.3; illusion_hits+=1; _effect(clone_positions[i],"violet"); cue.emit("illusion")
				if boss_state=="idle": boss_age=maxf(boss_age,0.3)
	if _in_sword(boss_position):
		var hit_at := boss_position
		boss_hp=maxi(0,boss_hp-damage); boss_flash=0.2
		palace.notify("hit",position); _effect(hit_at,"gold"); cue.emit("hit")
		if phase==Phase.DUEL and boss_hp<=int(tuning.mirror_threshold):
			boss_hp=int(tuning.mirror_threshold); _enter_phase(Phase.MIRRORS)
		elif phase==Phase.MIRRORS and boss_hp<=int(tuning.palace_threshold):
			boss_hp=int(tuning.palace_threshold); _enter_phase(Phase.PALACE)
		elif boss_hp<=0:
			tables.clear(); roots.clear(); phase=Phase.WON; cue.emit("victory"); won.emit()
			return
		_counterattack(hit_at)

func _in_sword(at: Vector2) -> bool:
	var difference := at-position
	return difference.length()<float(tuning.sword_range) and difference.normalized().dot(attack_direction)>0.12

func _hurt(amount: int,source: Vector2,blockable := false) -> void:
	if invulnerability>0 or not active(): return
	if blockable and guarding and (source-position).normalized().dot(facing)>0.1:
		amount=0 if guard_age<0.2 else 1; cue.emit("guard")
	if amount<=0: return
	hp=maxi(0,hp-amount); invulnerability=0.85; hit_flash=0.28; impact_flash=0.2
	observe_progress=0; observing=false; attack_age=-1; velocity=(position-source).normalized()*190
	health_changed.emit(hp); cue.emit("hurt")
	if hp<=0: _fail()

func _fail() -> void:
	if phase==Phase.FAILED: return
	phase=Phase.FAILED; failed.emit()

func retry() -> void:
	if phase==Phase.WON: return
	retries+=1; hp=max_hp; position=Vector2(245,420); last_safe=position; velocity=Vector2.ZERO
	clock = 0.0
	facing = Vector2.RIGHT
	aim = Vector2.RIGHT
	boss_position=Vector2(850,330); real_slot=1; palace=PALACE.new(tuning.palace_events)
	boss_facing = Vector2.LEFT
	attack_kind = "enchant"
	clone_positions = mirror_spots.duplicate()
	tables.clear(); roots.clear(); effects.clear(); clone_flashes=[0.0,0.0,0.0]
	dash_time=0; dash_recharge=0; invulnerability=0; guard_age=9; guarding=false; defend_held=false
	hit_flash = 0.0
	flower_flash = 0.0
	impact_flash = 0.0
	observe_progress=0; reveal_time=0; reveal_recharge=0; focus=100; observe_held=false
	attack_recharge=0; input_axis=Vector2.ZERO
	counter_index=0
	illusion_hits = 0
	protected_spells = 0
	boss_hp = int(tuning.boss_hp)
	_enter_phase(Phase.DUEL)
	health_changed.emit(hp)

func _effect(at: Vector2,kind: String) -> void: effects.append({"p":at,"kind":kind,"age":0.0})
