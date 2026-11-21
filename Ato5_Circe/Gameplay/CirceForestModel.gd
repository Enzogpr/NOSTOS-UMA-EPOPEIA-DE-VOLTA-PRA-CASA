extends RefCounted
## The forest owns traversal, never campaign persistence. All time comes from tick.
signal feedback(message: String)
signal cue(kind: String)
signal flower_collected
signal completed
signal failed(reason: String)
signal checkpoint_reached(index: int)
const DATA := "res://Ato5_Circe/Gameplay/CirceForestLevel.json"
const TRICKERY := preload("res://Ato5_Circe/Gameplay/CirceTrickery.gd")
const BODY := Vector2(28, 76)
const GRAVITY := 1620.0
const JUMP := 690.0
const DASH_SPEED := 920.0
enum Phase { SEARCH, RETURN, COMPLETE, FAILED }
var level: Dictionary
var trickery: TRICKERY
var trickery_enabled := true
var jump_serial := 0
var dash_serial := 0
var checkpoint_clock := 0.0
var checkpoint_dash_fraction := 0.0
var platforms: Array[Rect2] = []
var surface_items: Array = []
var surface_rects: Array[Rect2] = []
var crumble_ages: Dictionary = {}
var tree_ages: Array[float] = []
var support := -1
var crouching := false
var memory_gate_open := false
var gate_opening := 0.0
var memory_reveal_count := 0
var _crouch_held := false
var checkpoint := 0
var checkpoint_position := Vector2(180, 540)
var position := Vector2(180, 540)
var velocity := Vector2.ZERO
var phase := Phase.SEARCH
var grounded := true
var facing := 1.0
var clock := 0.0
var distance_walked := 0.0
var hermes_met := false
var palace_seen := false
var has_flower := false
var flower_reveal := 0.0
var focus := 0.0
var focus_remaining := 0.0
var dash_remaining := 0.0
var dash_recharge := 0.0
var dash_cooldown := 3.0
var coyote := 0.12
var jump_buffer := 0.0
var invulnerable := 0.0
var hit_flash := 0.0
var max_hp := 10
var hp := 10
var speed_mult := 1.0
var intellect := 5
var retries := 0
var hints_seen: Dictionary = {}
var _initialized_stats := false
var _input_axis := 0.0
var _jump_held := false
var _observe_held := false

func _init(enable_tricks: bool = true) -> void:
	trickery_enabled=enable_tricks
	level = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	trickery=TRICKERY.new(level.tricks)
	for tree in level.return_trees: tree_ages.append(-1.0)
	_rebuild_platforms()

func _rebuild_platforms() -> void:
	surface_items = level.platforms.duplicate(true)
	if has_flower: surface_items.append_array(level.shortcuts.duplicate(true))
	_update_surfaces(0)

func surface_position(index: int) -> Vector2:
	var item: Array = surface_items[index]
	var point := Vector2(item[0],item[1])
	for motion: Dictionary in level.motions:
		if float(motion.x)==float(item[0]):
			point.y += sin(clock*TAU/float(motion.period))*float(motion.amplitude)
	var age: float = float(crumble_ages.get(str(item[0]),-1.0))
	var delay := crumble_delay(float(item[0]))
	if age>=delay and delay>0: point.y += minf(1100,pow(age-delay,2)*850)
	elif age>0: point.y += sin(clock*53)*age/delay*2.0
	if trickery_enabled: point+=trickery.surface_shift(float(item[0]))
	return point

func crumble_delay(x: float) -> float:
	for item: Dictionary in level.crumbling:
		if float(item.x)==x: return float(item.delay)
	return -1.0

func _update_surfaces(dt: float) -> void:
	var previous := surface_rects.duplicate()
	if grounded and support>=0 and support<surface_items.size():
		var key := str(surface_items[support][0])
		if crumble_delay(float(surface_items[support][0]))>0 and not crumble_ages.has(key):
			crumble_ages[key]=0.0
			cue.emit("crack")
	for key in crumble_ages: crumble_ages[key]=float(crumble_ages[key])+dt
	surface_rects.clear()
	platforms.clear()
	for i in surface_items.size():
		var item: Array = surface_items[i]
		var point := surface_position(i)
		var vanished: bool = crumble_delay(float(item[0]))>0 and float(crumble_ages.get(str(item[0]),-1.0))>=crumble_delay(float(item[0]))
		if trickery_enabled and trickery.surface_gone(float(item[0])): vanished=true
		var rect := Rect2(point,Vector2(float(item[2]),900-point.y if item[3]=="earth" else 24)) if not vanished else Rect2()
		surface_rects.append(rect)
		platforms.append(rect)
	if grounded and support>=0 and support<previous.size() and support<surface_rects.size():
		if surface_rects[support].has_area(): position += surface_rects[support].position-previous[support].position
		else: grounded=false
	for branch: Array in level.low_branches:
		platforms.append(Rect2(branch[0],branch[1],branch[2],branch[3]))
	if not has_flower and gate_opening<0.85:
		var g: Array=level.memory_gate
		platforms.append(Rect2(g[0],g[1],g[2],g[3]))
	for i in tree_ages.size():
		if has_flower and tree_ages[i]>=float(level.return_trees[i].warning)+float(level.return_trees[i].fall):
			var tree: Dictionary=level.return_trees[i]
			platforms.append(Rect2(float(tree.x)-float(tree.length),float(tree.y)-32,float(tree.length),32))

func tree_segment(index: int) -> PackedVector2Array:
	var tree: Dictionary=level.return_trees[index]
	var age: float=tree_ages[index]
	var fall: float=clampf((age-float(tree.warning))/float(tree.fall),0,1) if age>=0 else 0.0
	var angle: float=lerpf(-PI*0.5,-PI,smoothstep(0,1,fall))
	if age>=0 and age<float(tree.warning): angle+=sin(clock*30)*0.025
	var base:=Vector2(tree.x,float(tree.y)-16)
	return PackedVector2Array([base,base+Vector2(cos(angle),sin(angle))*float(tree.length)])

func _update_trees(dt: float) -> void:
	if not has_flower: return
	for i in tree_ages.size():
		var tree: Dictionary=level.return_trees[i]
		if tree_ages[i]<0 and position.x>float(tree.x)-float(tree.length)-100 and position.x<float(tree.x)+float(tree.trigger):
			tree_ages[i]=0.0
			cue.emit("crack")
		if tree_ages[i]<0: continue
		tree_ages[i]+=dt
		var age: float=tree_ages[i]
		if age<float(tree.warning) or age>float(tree.warning)+float(tree.fall): continue
		var segment:=tree_segment(i)
		var rect:=_body().grow(13)
		var corners:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
		var hit:=rect.has_point(segment[0]) or rect.has_point(segment[1])
		for edge in 4:
			if Geometry2D.segment_intersects_segment(segment[0],segment[1],corners[edge],corners[(edge+1)%4])!=null: hit=true
		if hit: _hurt(2,true)

func apply_player_stats(stats: Dictionary) -> void:
	var previous_cd := dash_cooldown
	max_hp = maxi(1, int(stats.get("max_hp", 10)))
	speed_mult = maxf(0.3, float(stats.get("speed_mult", 1.0)))
	intellect = int(stats.get("intellect", 5))
	dash_cooldown = maxf(0.5, float(stats.get("dash_cooldown", 3.0)))
	dash_recharge = dash_recharge / previous_cd * dash_cooldown
	hp = mini(hp, max_hp) if _initialized_stats else max_hp
	_initialized_stats = true

func set_input(axis: float, jump_held: bool, observe_held: bool, crouch_held: bool = false) -> void:
	_input_axis = clampf(axis, -1, 1)
	_jump_held = jump_held
	_observe_held = observe_held
	_crouch_held = crouch_held

func request_jump() -> void:
	if phase in [Phase.SEARCH, Phase.RETURN]: jump_buffer = 0.14

func request_dash(direction: float = 0.0) -> bool:
	if phase not in [Phase.SEARCH, Phase.RETURN] or dash_recharge > 0 or crouching or (_observe_held and focus>0.1): return false
	if absf(direction)>0.1: facing=signf(direction)
	dash_remaining = 0.2
	dash_serial+=1
	dash_recharge = dash_cooldown
	velocity.x = facing * DASH_SPEED
	cue.emit("dash")
	return true

func interact() -> String:
	if phase not in [Phase.SEARCH, Phase.RETURN]: return ""
	if position.distance_to(Vector2(level.hermes[0], level.hermes[1])) < 125 and not hermes_met:
		hermes_met = true
		feedback.emit("Hermes: pétalas brancas, raiz negra. Procure a holimoli nas alturas da floresta.")
		cue.emit("hermes")
		return "hermes"
	if position.distance_to(palace_position()) < 110:
		palace_seen = true
		if not has_flower:
			feedback.emit("A magia de Circe impede a entrada. A voz de Hermes vem da floresta.")
			return "sealed"
		phase = Phase.COMPLETE
		velocity = Vector2.ZERO
		completed.emit()
		return "complete"
	if trickery_enabled and not has_flower and position.distance_to(Vector2(level.false_flower[0],level.false_flower[1]))<85 and not trickery.is_fired("false_flower"):
		trickery.fire("false_flower",self)
		feedback.emit("As pétalas se desfazem. A holimoli verdadeira está além da clareira.")
		return "mirage"
	if phase == Phase.SEARCH and hermes_met and position.distance_to(Vector2(level.flower[0], level.flower[1])) < 85:
		_collect_flower()
		return "flower"
	return ""

func _collect_flower() -> void:
	if has_flower: return
	has_flower = true
	flower_reveal = 1.0
	phase = Phase.RETURN
	checkpoint = 0
	checkpoint_position = Vector2(level.return_checkpoints[0][0], level.return_checkpoints[0][1])
	checkpoint_clock=clock
	checkpoint_dash_fraction=dash_recharge/dash_cooldown
	trickery.reset(true)
	trickery.jump_seen=jump_serial
	trickery.dash_seen=dash_serial
	crumble_ages.clear()
	support=-1
	_rebuild_platforms()
	flower_collected.emit()
	feedback.emit("A holimoli repele os feitiços. Volte ao palácio de Circe.")
	cue.emit("flower")

func resume_with_flower() -> void:
	hermes_met = true
	_collect_flower()
	position = checkpoint_position
	velocity = Vector2.ZERO
	grounded = true

func prompt() -> String:
	if phase not in [Phase.SEARCH, Phase.RETURN]: return ""
	if position.distance_to(Vector2(level.hermes[0], level.hermes[1])) < 125 and not hermes_met: return "Ouvir Hermes"
	if position.distance_to(palace_position()) < 110: return "Entrar no palácio" if has_flower else "Examinar o encantamento"
	if trickery_enabled and not has_flower and position.distance_to(Vector2(level.false_flower[0],level.false_flower[1]))<85 and not trickery.is_fired("false_flower"): return "Colher a holimoli"
	if hermes_met and not has_flower and position.distance_to(Vector2(level.flower[0], level.flower[1])) < 85: return "Colher a holimoli"
	if not has_flower and position.x > 2490 and position.x < 4000: return "Observar a rota"
	return ""

func palace_position() -> Vector2:
	return Vector2(level.palace[0],level.palace[1])+Vector2(trickery.palace_offset() if trickery_enabled else 0.0,0)

func checkpoint_points() -> Array:
	return level.return_checkpoints if has_flower else level.checkpoints

func objective() -> String:
	if has_flower: return "Volte ao palácio. A flor repele feitiços; árvores e quedas ainda são perigosas."
	if trickery_enabled and trickery.is_fired("false_flower"): return "A primeira flor era uma ilusão. A holimoli verdadeira está adiante."
	if not hermes_met: return "Os homens desapareceram. A voz de Hermes vem da floresta."
	if position.x < 2500: return "Siga as pétalas brancas pelas raízes e ruínas."
	if position.x < 4100: return "Nem todo caminho é real. Observe antes de saltar."
	return "A flor está acima das copas. Alcance a clareira."

func hazard_state(hazard: Dictionary) -> float:
	return fmod(clock + float(hazard.offset), float(hazard.period)) / float(hazard.period)

func hazard_rect(hazard: Dictionary) -> Rect2:
	return Rect2(float(hazard.x), float(hazard.y) - float(hazard.height), float(hazard.width), float(hazard.height))

func tick(delta: float) -> void:
	if phase not in [Phase.SEARCH, Phase.RETURN]: return
	# A fixed upper step keeps collision sweeps stable during window stalls.
	var remaining := delta
	while remaining > 0.00001:
		var step := minf(remaining, 1.0 / 120.0)
		_step(step)
		remaining -= step
		if phase not in [Phase.SEARCH, Phase.RETURN]: break

func _step(dt: float) -> void:
	clock += dt
	_update_trees(dt)
	if phase==Phase.FAILED: return
	_update_surfaces(dt)
	invulnerable = maxf(0, invulnerable - dt)
	hit_flash = maxf(0, hit_flash - dt)
	dash_recharge = maxf(0, dash_recharge - dt)
	var was_dashing := dash_remaining > 0
	dash_remaining = maxf(0, dash_remaining - dt)
	if was_dashing and dash_remaining <= 0:
		velocity.x = clampf(velocity.x,-285.0*speed_mult,285.0*speed_mult)
	jump_buffer = maxf(0, jump_buffer - dt)
	flower_reveal = maxf(0, flower_reveal - dt * 0.45)
	focus_remaining = maxf(0, focus_remaining - dt)
	if _crouch_held and grounded: crouching=true
	elif crouching:
		var standing:=Rect2(position-Vector2(14,76),Vector2(28,75))
		var blocked:=false
		for rect in platforms:
			if standing.intersects(rect): blocked=true
		if not blocked: crouching=false
	if grounded: coyote = 0.12
	else: coyote = maxf(0, coyote - dt)
	var observing: bool = _observe_held and grounded and absf(_input_axis) < 0.1 and dash_remaining <= 0
	focus = move_toward(focus, 1.0 if observing else 0.0, dt * 1.8)
	if focus >= 0.99:
		focus_remaining = minf(7.0,4.0+maxf(0,intellect-5)*0.25)
		if position.x>2490 and position.x<4000 and not memory_gate_open:
			memory_gate_open=true
			memory_reveal_count+=1
			cue.emit("hermes")
			feedback.emit("Memorize os galhos dourados. As cópias se desfazem quando você observa.")
	gate_opening=move_toward(gate_opening,1.0 if memory_gate_open or has_flower else 0.0,dt*1.8)
	var axis: float = 0.0 if observing else _input_axis
	if absf(axis) > 0.1: facing = signf(axis)
	if jump_buffer > 0 and coyote > 0 and not crouching:
		velocity.y = -JUMP
		grounded = false
		coyote = 0
		jump_buffer = 0
		jump_serial+=1
		cue.emit("jump")
	if velocity.y < -250 and not _jump_held: velocity.y = maxf(velocity.y, -250)
	if dash_remaining <= 0:
		velocity.x = move_toward(velocity.x, axis * (133.0 if crouching else 285.0) * speed_mult, (2250.0 if grounded else 1500.0) * dt)
	else: velocity.x = facing * DASH_SPEED
	velocity.y = minf(1000, velocity.y + GRAVITY * dt)
	var before := position
	_move_horizontal(velocity.x * dt)
	_move_vertical(velocity.y * dt)
	distance_walked += absf(position.x - before.x)
	position.x = clampf(position.x, 24, float(level.width) - 24)
	if trickery_enabled:
		trickery.tick(dt,self)
		for hazard: Dictionary in trickery.hazards():
			if hazard.active and _body().intersects(hazard.rect):
				hp=0
				cue.emit("hurt")
				_fail("A floresta enganou Odisseu. Tente outra reação neste trecho.")
				return
	# Hermes also calls to a player who runs past the interaction prompt.
	# Guidance never needs an invisible wall or a return across the entire island.
	if not hermes_met and position.x > 575:
		hermes_met = true
		feedback.emit("Hermes: pétalas brancas, raiz negra. Procure a holimoli nas alturas da floresta.")
		cue.emit("hermes")
	if position.y > 880:
		_fail("A floresta engoliu o caminho. Retome do último ponto seguro.")
		return
	for i in level.hazards.size():
		var hazard: Dictionary = level.hazards[i]
		var state := hazard_state(hazard)
		if state >= 0.22 and state < 0.52 and _body().intersects(hazard_rect(hazard)) and not has_flower:
			_hurt(2)
	if phase == Phase.FAILED: return
	if grounded:
		var points:=checkpoint_points()
		var candidates: Array=range(checkpoint+1,points.size())
		for i: int in candidates:
			var point := Vector2(points[i][0], points[i][1])
			if position.distance_to(point) < 75:
				checkpoint = i
				checkpoint_position = point
				checkpoint_clock=clock
				checkpoint_dash_fraction=dash_recharge/dash_cooldown
				checkpoint_reached.emit(i)
				cue.emit("checkpoint")
	if position.x > 2500 and not hints_seen.has("illusion"):
		hints_seen.illusion = true
		feedback.emit("Hermes: observe junto às raízes seladas. Memorize a rota antes que o brilho desapareça.")

func _body() -> Rect2:
	var height:=40.0 if crouching else BODY.y
	return Rect2(position - Vector2(BODY.x * 0.5, height), Vector2(BODY.x,height))

func _move_horizontal(amount: float) -> void:
	position.x += amount
	for surface in platforms:
		if not _body().intersects(surface): continue
		if grounded and surface.position.y>=position.y-10 and surface.position.y<=position.y+1:
			position.y=surface.position.y
			continue
		position.x = surface.position.x - BODY.x * 0.5 if amount > 0 else surface.end.x + BODY.x * 0.5
		velocity.x = 0
		dash_remaining = 0

func _move_vertical(amount: float) -> void:
	var previous_y := position.y
	position.y += amount
	grounded = false
	support=-1
	for i in platforms.size():
		var surface: Rect2=platforms[i]
		if not _body().intersects(surface): continue
		if amount >= 0 and previous_y <= surface.position.y + 1:
			position.y = surface.position.y
			velocity.y = 0
			grounded = true
			support=i
		elif amount < 0:
			position.y = surface.end.y + (40.0 if crouching else BODY.y)
			velocity.y = 0

func _hurt(amount: int, physical: bool = false) -> void:
	if invulnerable > 0: return
	hp = maxi(0, hp - amount)
	invulnerable = 1.25
	hit_flash = 0.3
	dash_remaining = 0
	velocity.x = -facing * 150
	cue.emit("hurt")
	if hp <= 0: _fail("A árvore atingiu Odisseu. Espere a queda ou atravesse pela abertura." if physical else "Os feitiços venceram sua resistência. Observe o ritmo da floresta.")

func _fail(reason: String) -> void:
	if phase == Phase.FAILED: return
	phase = Phase.FAILED
	velocity = Vector2.ZERO
	failed.emit(reason)

func retry() -> void:
	if phase != Phase.FAILED: return
	retries += 1
	clock=checkpoint_clock
	position = checkpoint_position
	velocity = Vector2.ZERO
	phase = Phase.RETURN if has_flower else Phase.SEARCH
	hp = max_hp
	grounded = true
	support=-1
	invulnerable = 1.0
	dash_remaining = 0
	dash_recharge=checkpoint_dash_fraction*dash_cooldown
	jump_serial=0
	dash_serial=0
	trickery.reset(has_flower)
	# Current campaign attributes and permanent flower ownership are preserved.
	jump_buffer = 0
	focus = 0
	focus_remaining=0
	crouching=false
	crumble_ages.clear()
	memory_gate_open=has_flower or checkpoint_position.x>=3300
	gate_opening=1.0 if memory_gate_open else 0.0
	for i in tree_ages.size(): tree_ages[i]=-1.0
	_rebuild_platforms()
	set_input(0, false, false)
