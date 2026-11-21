extends SceneTree

const DUEL := preload("res://Ato12_Poseidon/Gameplay/PoseidonDuel.gd")
const MANAGER := preload("res://Code/GameManager.gd")
const WATER := preload("res://Ato12_Poseidon/Gameplay/PoseidonWaterGeometry.gd")
const SCENE := "res://Ato12_Poseidon/Gameplay/FinalPoseidon.tscn"
const STEP := 1.0 / 60.0
var checks := 0
var failures := 0
var bot_motion := Vector2.ZERO
var bot_frames := 0
var phase_times: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func stats(hp: int = 10, speed: float = 1.0, damage: int = 3, cooldown: float = 3.0) -> Dictionary:
	return {"max_hp":10,"current_hp":hp,"speed_mult":speed,"damage":damage,"dash_cooldown":cooldown}

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click(button: MouseButton, at: Vector2 = Vector2(576,450)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func danger(model: DUEL, point: Vector2, future: float) -> float:
	var cost := 0.0
	for hazard in model.hazards:
		var age: float = hazard.age + future
		if age < hazard.lead or age > hazard.lead + hazard.hold or hazard.spent:
			continue
		var box: Rect2 = hazard.rect
		if hazard.has("velocity"):
			box.position += hazard.velocity * maxf(0.0, future-maxf(0.0,hazard.lead-hazard.age))
		if box.grow(21).has_point(point):
			if hazard.kind == "tide" and absf(point.y-hazard.gap)<hazard.gap_size*0.5-15:
				continue
			cost += 1700.0/(future+0.35)
	for enemy in model.guards.enemies:
		if enemy.hp <= 0 or enemy.state not in ["windup","strike"]:
			continue
		var predicted:=enemy.duplicate()
		predicted.age=enemy.age+future-(model.guards.windup_time(enemy) if enemy.state=="windup" else 0.0)
		predicted.state="strike"
		if predicted.kind=="thrust":
			predicted.position=predicted.origin+predicted.direction*(43 if predicted.role=="flanker" else 27)*smoothstep(0.025,0.18,predicted.age)
		if predicted.age >= -0.09 and predicted.age < 0.36:
			predicted.age=clampf(predicted.age,0.08,0.19)
		else:
			continue
		if WATER.soldier_hits(predicted,point):
			cost += 1700.0/(future+0.35)
	for arrow in model.guards.arrows:
		if arrow.spent:continue
		var predicted:=arrow.duplicate()
		predicted.position+=predicted.direction*390*future
		if WATER.arrow_hits(predicted,point):cost+=1700.0/(future+0.35)
	return cost

func choose_motion(model: DUEL, goal: Vector2) -> Vector2:
	var options: Array[Vector2] = [Vector2.ZERO,(goal-model.position).limit_length(55)/55]
	for n in 16:
		options.append(Vector2.from_angle(n*TAU/16))
	var best := INF
	var chosen := Vector2.ZERO
	var speed := model.movement_speed()*(0.70 if model.attack_age>=0 or model.wind_cast>0 else 1.0)
	for motion in options:
		var cost := 0.0
		for t: float in [0.06,0.14,0.25,0.4,0.6,0.84,1.12]:
			var point := (model.position+motion*speed*t).clamp(DUEL.ARENA.position,DUEL.ARENA.end)
			cost += danger(model,point,t)
		var end := (model.position+motion*speed*0.36).clamp(DUEL.ARENA.position,DUEL.ARENA.end)
		cost += end.distance_to(goal)*0.17
		cost += (motion-bot_motion).length()*2
		if end.distance_to(model.position)<3 and motion.length()>0.2:
			cost += 18
		if cost<best:
			best=cost
			chosen=motion
	return chosen

func environmental_goal(model: DUEL, base: Vector2) -> Vector2:
	var priority := 5.0
	var goal := base
	for hazard in model.hazards:
		if hazard.spent or hazard.age > hazard.lead + hazard.hold:
			continue
		var due: float = maxf(0, hazard.lead-hazard.age)
		if hazard.kind == "breaker" and due < priority:
			var safe_left := DUEL.ARENA.position.x
			var safe_right := DUEL.ARENA.end.x
			for other in model.hazards:
				if other.kind != "breaker": continue
				if other.rect.position.x < 100: safe_left=other.rect.end.x+23
				else: safe_right=other.rect.position.x-23
			goal=Vector2((safe_left+safe_right)*0.5,model.position.y)
			priority=due
		elif hazard.kind=="rain" and due<priority:
			for lane in 4:
				var x := DUEL.ARENA.position.x+(lane+0.5)*DUEL.ARENA.size.x/4
				var safe := true
				for other in model.hazards:
					if other.kind=="rain" and x>other.rect.position.x and x<other.rect.end.x: safe=false
				if safe:
					goal=Vector2(x,model.position.y)
					priority=due
		elif hazard.kind=="tide":
			var toward: float = (model.position.x-hazard.rect.get_center().x)/hazard.velocity.x
			if toward>=-0.1 and toward+due < priority:
				goal=Vector2(model.position.x,hazard.gap)
				priority=toward+due
	return goal

func bot_step(model: DUEL) -> void:
	bot_frames += 1
	var goal := Vector2(576,487)
	var aim := model.wind_point-model.position
	var want_attack := false
	var healing: Dictionary={}
	for pickup in model.health_pickups:
		if not pickup.collected and model.hp <= model.max_hp-int(pickup.amount):
			healing=pickup
			break
	if model.phase==DUEL.Phase.GUARDS and model.trident_dropped:
		goal=model.trident
	elif model.phase==DUEL.Phase.GUARDS and model.guards.remaining()>0:
		var nearest: Dictionary = {}
		var distance := INF
		for enemy in model.guards.enemies:
			if enemy.hp>0 and enemy.position.distance_to(model.position)<distance:
				distance=enemy.position.distance_to(model.position)
				nearest=enemy
		if not nearest.is_empty():
			aim=nearest.position-model.position
			goal=nearest.position+nearest.position.direction_to(model.position)*123
			var attack_safe: bool = nearest.state not in ["windup","strike","chain","arrive"]
			for attacker in model.guards.enemies:
				if attacker.hp<=0:continue
				if attacker.state in ["strike","chain"] and attacker.position.distance_to(model.position)<235:attack_safe=false
				if attacker.state=="windup" and attacker.position.distance_to(model.position)<235 and model.guards.windup_time(attacker)-attacker.age<0.43:attack_safe=false
			if not attack_safe:
				goal=nearest.position+nearest.position.direction_to(model.position)*174
			if distance<DUEL.SWORD_REACH+8 and attack_safe:
				want_attack=true
	elif model.state==DUEL.State.EXPOSED:
		goal=model.wind_point+Vector2(0,82)
	if model.phase in [DUEL.Phase.SURGE,DUEL.Phase.GUARDS]:
		if not healing.is_empty():goal=healing.position
		if bot_frames%3==0:
			bot_motion=choose_motion(model,environmental_goal(model,goal))
		var guarding:=false
		for enemy in model.guards.enemies:
			if enemy.hp<=0:continue
			var close_to_strike:bool=(enemy.state=="windup" and model.guards.windup_time(enemy)-enemy.age<0.065) or (enemy.state=="strike" and enemy.age<0.20)
			if close_to_strike and enemy.position.distance_to(model.position)<235:
				guarding=true
				aim=enemy.position-model.position
		if guarding and model.defend and model.guard_age>0.13:
			guarding=false
		model.set_input(bot_motion,aim,guarding)
		if want_attack and not guarding:model.request_attack()
		if model.state==DUEL.State.EXPOSED and not model.opening_used and model.guards.remaining()==0:
			model.request_wind()
		if model.phase==DUEL.Phase.GUARDS and model.trident_dropped:
			model.interact()
		if danger(model,model.position,0.12)>0 and model.dash_recharge<=0:
			model.request_dash()
		for enemy in model.guards.enemies:
			if enemy.hp>0 and enemy.elite and enemy.kind=="sweep" and enemy.state=="strike" and enemy.age>0.07 and enemy.age<0.12 and enemy.position.distance_to(model.position)<235 and model.dash_recharge<=0:
				model.request_dash()
	elif model.phase==DUEL.Phase.DISARM:
		var destination: Vector2=healing.position if not healing.is_empty() else model.trident if model.trident_dropped else Vector2(576,478)
		model.set_input(((destination-model.position)/30).limit_length(),model.wind_point-model.position,false)
		if model.state==DUEL.State.EXPOSED and not model.trident_dropped:
			model.request_wind()
		if model.trident_dropped:model.interact()
	elif model.phase==DUEL.Phase.UNLEASH:
		model.set_input(Vector2.ZERO,Vector2.UP*10,false,true)
	elif model.phase==DUEL.Phase.DUEL:
		duel_bot(model)
	if not healing.is_empty() and model.active() and model.position.distance_to(healing.position)<42:
		model.interact()
	model.tick(STEP)

func duel_bot(model: DUEL) -> void:
	var away := model.boss.direction_to(model.position)
	if away.length()<0.5: away=Vector2.LEFT
	var goal:=model.position
	var closest:=INF
	for n in 32:
		var candidate: Vector2=(model.boss+Vector2.from_angle(n*TAU/32)*263).clamp(DUEL.ARENA.position+Vector2(9,9),DUEL.ARENA.end-Vector2(9,9))
		if candidate.distance_to(model.boss)>243 and candidate.distance_to(model.position)<closest:
			closest=candidate.distance_to(model.position)
			goal=candidate
	var dodge:=false
	if model.state==DUEL.State.REST:
		goal=model.boss+away*145
		if model.position.distance_to(model.boss)<DUEL.TRIDENT_REACH-8:
			model.set_input(Vector2.ZERO,model.boss-model.position,false)
			model.request_attack()
	elif model.move==DUEL.Move.THRUST and model.state in [DUEL.State.WINDUP,DUEL.State.STRIKE]:
		var perpendicular:=Vector2.from_angle(model.strike_angle).orthogonal()
		if (model.position+perpendicular*120).distance_to(DUEL.ARENA.get_center()) > (model.position-perpendicular*120).distance_to(DUEL.ARENA.get_center()):
			perpendicular=-perpendicular
		goal=model.position+perpendicular*150
		var line:=Geometry2D.get_closest_point_to_segment(model.position,model.strike_origin,model.strike_origin+Vector2.from_angle(model.strike_angle)*344)
		dodge=model.state==DUEL.State.STRIKE and model.state_age<0.04 and line.distance_to(model.position)<38
	elif model.state in [DUEL.State.WINDUP,DUEL.State.STRIKE] and model.move==DUEL.Move.WAVE:
		var direction:=-1 if model.combo_cycle%2==0 else 1
		goal=Vector2(model.position.x,model.wave_gap_y())
		var before:=(model.wave_x()-model.position.x)*-direction
		dodge=model.state==DUEL.State.STRIKE and before<148 and before>24 and absf(model.position.y-model.wave_gap_y())>24
	var motion:=((goal-model.position)/30).limit_length()
	if not model.hazards.is_empty():
		motion=choose_motion(model,goal)
	model.set_input(motion,model.boss-model.position,false)
	if dodge: model.request_dash()

func capture(scene: Control, name: String) -> void:
	if DisplayServer.get_name()=="headless":
		return
	scene.stage.advance(0.18)
	scene._refresh()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://scratch/campaign_review/poseidon_arena/"+name+".png")

func model_checks() -> void:
	var model := DUEL.new()
	model.apply_stats(stats())
	model.start()
	model.tick(3)
	check(model.phase==DUEL.Phase.SURGE and model.barrier_hits==0,"Time does not solve the first phase")
	model.request_wind()
	model.tick(1)
	check(model.barrier_hits==0,"Wind outside an opening cannot advance the barrier")
	model._enter(DUEL.Phase.GUARDS)
	model._set_state(DUEL.State.EXPOSED)
	model._wind_hit()
	check(model.anchor_hits==0,"Living water soldiers protect the trident anchoring")
	model._enter(DUEL.Phase.UNLEASH)
	model.set_input(Vector2.ZERO,Vector2.UP*10,false,false)
	model.tick(3)
	check(not model.bag_emptied and model.phase==DUEL.Phase.UNLEASH,"The whole bag cannot open automatically")
	model.request_dash()
	model.set_input(Vector2.ZERO,Vector2.UP*10,false,true)
	model.tick(1.3)
	check(not model.bag_emptied and model.bag_untying>1,"Unfastening the bag takes a sustained action")
	model.set_input(Vector2.RIGHT,Vector2.UP*10,false,true)
	model.tick(0.6)
	check(model.bag_untying<1,"Moving interrupts untying the bag")
	model.set_input(Vector2.ZERO,Vector2.UP*10,false,true)
	model.tick(2.5)
	check(model.bag_emptied and model.phase==DUEL.Phase.UNLEASH,"Holding E releases the entire tempest before the duel")
	model.tick(2.9)
	model.tick(2.9)
	check(model.phase==DUEL.Phase.DUEL and model.storm==1 and model.has_trident,"The third phase starts inside the released storm with the trident")
	model.state=DUEL.State.WINDUP
	model.attack_direction=model.position.direction_to(model.boss)
	model.position=model.boss-Vector2(120,0)
	model._player_hit()
	check(model.boss_hp==model.boss_max_hp,"The god cannot be injured during a guarded attack")
	model.state=DUEL.State.REST
	model.hits_in_opening=0
	model.attack_direction=Vector2.RIGHT
	model._player_hit()
	var first_damage := model.boss_max_hp-model.boss_hp
	model._player_hit()
	model._player_hit()
	check(model.hits_in_opening==2 and model.boss_max_hp-model.boss_hp==first_damage*2,"Each counterattack opening allows two committed trident hits")
	model.hp=4
	model.apply_stats(stats(10,1.72,12,0.5))
	check(model.hp==4 and model.damage==12 and model.dash_cooldown==0.5,"Sacrificed years affect attributes without healing current life")
	model.checkpoint=DUEL.Phase.DUEL
	model.checkpoint_hp=4
	model.invulnerability=0
	model._hurt(10,false,model.boss)
	check(model.phase==DUEL.Phase.LOST and model.lost_from==DUEL.Phase.DUEL,"Death retains its visual scene")
	model.retry()
	check(model.phase==DUEL.Phase.DUEL and model.hp==4 and model.boss_hp==model.boss_max_hp and model.bag_emptied,"Retry resets the complete current phase and preserves the released bag")
	var idle:=DUEL.new()
	idle.start()
	for n in 5000:
		idle.tick(STEP)
		if idle.phase==DUEL.Phase.LOST: break
	check(idle.phase==DUEL.Phase.LOST,"Standing still loses the encounter")
	var spatial:=DUEL.new()
	spatial.apply_stats(stats(10,0.3,3,3))
	spatial.start()
	for x: float in [99.0,300.0,576.0,820.0,1053.0]:
		spatial.position=Vector2(x,490)
		spatial.hazards.clear()
		spatial._spawn_finisher()
		var left: Rect2=spatial.hazards[0].rect
		var right: Rect2=spatial.hazards[1].rect
		var safe_center: float=(left.end.x+right.position.x)*0.5
		check(absf(safe_center-x)+20<spatial.movement_speed()*1.65,"The finisher leaves a reachable channel at minimum agility, x %.0f" % x)
		spatial.hazards.clear()
		spatial._spawn_pattern("rain")
		var nearest:=INF
		for lane in 4:
			var center:=DUEL.ARENA.position.x+(lane+0.5)*DUEL.ARENA.size.x/4
			var safe:=true
			for h in spatial.hazards:
				if h.rect.has_point(Vector2(center,490)):safe=false
			if safe:
				var reachable_x:=clampf(x,center-DUEL.ARENA.size.x/8+25,center+DUEL.ARENA.size.x/8-25)
				nearest=minf(nearest,absf(reachable_x-x))
		check(nearest<spatial.movement_speed()*1.62,"Rain leaves an adjacent reachable channel at minimum agility, x %.0f" % x)
	spatial._enter(DUEL.Phase.DUEL)
	spatial.combo_cycle=0
	spatial.move=DUEL.Move.WAVE
	spatial.state=DUEL.State.STRIKE
	spatial.state_age=0.58
	spatial.position=Vector2(spatial.wave_x(),spatial.wave_gap_y())
	var protected_hp:=spatial.hp
	spatial._check_strike()
	check(spatial.hp==protected_hp,"The final wave has a physical escape channel without requiring a ready dash")
	spatial.position.y+=50
	spatial._check_strike()
	check(spatial.hp<protected_hp,"Leaving the wave channel causes real damage")
	spatial._enter(DUEL.Phase.GUARDS)
	var sword_target: Dictionary=spatial.guards.enemies[0]
	sword_target.state="approach"
	sword_target.position=spatial.position+Vector2(100,0)
	spatial.guards.hit(spatial.position,Vector2.RIGHT,DUEL.SWORD_REACH,3)
	var low_damage:int=sword_target.hp
	spatial.guards.hit(spatial.position,Vector2.RIGHT,DUEL.SWORD_REACH,9)
	check(low_damage-int(sword_target.hp)==9,"Campaign sword damage applies to the water soldiers")

func hitbox_checks() -> void:
	var model:=DUEL.new()
	model.apply_stats(stats())
	model.start()
	var pool: Dictionary={"kind":"pool","rect":Rect2(480,440,94,74),"age":1.5,"lead":1.15,"hold":2.85,"spent":false,"damage":1}
	model.position=pool.rect.end+Vector2(9,9)
	model.hazards.append(pool.duplicate())
	model._update_hazards(0.001)
	check(model.hp==10,"Passing through the old ten-pixel padding causes no damage")
	model.position=pool.rect.position+Vector2(2,2)
	model._update_hazards(0.001)
	check(model.hp==10,"The empty corner of a whirlpool rectangle causes no damage")
	model.position=pool.rect.get_center()
	model._update_hazards(0.001)
	check(model.hp==9,"The visible solid whirlpool still causes damage")
	var before:=pool.duplicate()
	before.age=before.lead-0.01
	check(not WATER.hazard_hits(before,pool.rect.get_center(),0),"Gathering water is harmless before impact")
	before.age=before.lead+before.hold+0.01
	check(not WATER.hazard_hits(before,pool.rect.get_center(),0),"The visual dissolution remains harmless after the active attack")
	var image:=WATER.ATLAS.get_image()
	if image.is_compressed():image.decompress()
	var part:=WATER.piece(5,Rect2(50,60,110,60),0.87,Vector2(400,200),0.72)
	var cell: Rect2=WATER.CELLS[5]
	for uv: Vector2 in [Vector2(0.01,0.01),Vector2(0.5,0.5),Vector2(0.99,0.99)]:
		var screen: Vector2=part.origin+(part.rect.position+uv*part.rect.size).rotated(part.angle)
		var alpha:=image.get_pixelv(Vector2i(cell.position+uv*cell.size)).a
		check(WATER.contains_pixel(part,screen)==(alpha*0.87>=WATER.SOLID_ALPHA),"Rotated sprite damage follows the actual atlas transparency at %s" % uv)
	part.opacity=0.1
	check(not WATER.contains_pixel(part,part.origin+(part.rect.get_center()).rotated(part.angle)),"Faint spray cannot create a solid hitbox")
	model._enter(DUEL.Phase.GUARDS)
	var enemy: Dictionary=model.guards.enemies[0]
	enemy.state="strike"
	enemy.position=Vector2(400,480)
	enemy.origin=enemy.position
	enemy.direction=Vector2.RIGHT
	enemy.facing=Vector2.RIGHT
	enemy.age=0.01
	var contacts:=model.guards.tick(0,Vector2(520,480),DUEL.ARENA)
	check(contacts.is_empty(),"A soldier cannot hit at full reach before its weapon extends")
	enemy.age=0.14
	contacts=model.guards.tick(0,Vector2(460,502),DUEL.ARENA)
	check(contacts.is_empty(),"A soldier cannot hit beside its visible weapon")
	var drawn_weapon:=WATER.soldier_segment(enemy)
	var past_tip: Vector2=drawn_weapon[1]+enemy.direction*22+Vector2(0,WATER.BODY_HEIGHT)
	contacts=model.guards.tick(0,past_tip,DUEL.ARENA)
	check(contacts.is_empty(),"A soldier cannot hit past the visible tip")
	drawn_weapon=WATER.soldier_segment(enemy)
	contacts=model.guards.tick(0,drawn_weapon[0].lerp(drawn_weapon[1],0.5)+Vector2(0,WATER.BODY_HEIGHT),DUEL.ARENA)
	check(contacts.size()==1,"Contact with the extended water weapon still causes damage")
	model._enter(DUEL.Phase.DUEL)
	model.state=DUEL.State.STRIKE
	model.move=DUEL.Move.THRUST
	model.strike_origin=Vector2(400,480)
	model.strike_angle=0
	model.state_age=0.18
	model.position=Vector2(500,502)
	var saved_hp:=model.hp
	model._check_strike()
	check(model.hp==saved_hp,"Poseidon's thrust no longer hits the oversized side margin")
	model.move=DUEL.Move.WAVE
	model.combo_cycle=0
	model.state_age=0.58
	model.position=Vector2(model.wave_x(),model.wave_gap_y()+30)
	model._check_strike()
	check(model.hp==saved_hp,"The complete visible corridor between final waves remains safe")

func recovery_checks() -> void:
	var model:=DUEL.new()
	model.apply_stats(stats(4))
	model.start()
	model.barrier_hits=2
	model._wind_hit()
	check(model.phase==DUEL.Phase.GUARDS and model.hp==4 and model.checkpoint_hp==4,"The first transition spawns healing without automatically increasing life")
	check(model.health_pickups.size()==1 and model.health_pickups[0].amount==2,"A two-HP item appears on the field after the first stage")
	model.position=model.health_pickups[0].position
	model.interact()
	check(model.hp==6 and model.health_pickups[0].collected,"E collects the first item and heals two HP")
	model.interact()
	check(model.hp==6,"A collected item cannot heal twice")
	model.retry()
	check(model.hp==4 and not model.health_pickups[0].collected,"Retry restores entry health and its uncollected item rather than farming healing")
	model.position=model.health_pickups[0].position
	model.interact()
	for wave in 3:
		for enemy in model.guards.enemies:
			enemy.hp=0
			enemy.state="dead"
		model.tick(1.3)
	check(model.phase==DUEL.Phase.DISARM and model.hp==6 and model.health_pickups.size()==2,"Clearing the army spawns the second item without automatic healing")
	check(model.health_pickups[1].amount==3,"The second healing item restores three HP")
	model.position=model.health_pickups[1].position
	model.interact()
	check(model.hp==9 and model.health_pickups[1].collected,"E collects the three-HP item before the final duel")
	model.tick(1.4)
	model._wind_hit()
	model.tick(0.9)
	model.position=model.trident
	model.interact()
	check(model.phase==DUEL.Phase.UNLEASH and model.hp==9,"Taking the trident does not add automatic healing")
	model.set_input(Vector2.ZERO,Vector2.UP*10,false,true)
	model.tick(2.5)
	model.tick(2.9)
	model.tick(2.9)
	check(model.phase==DUEL.Phase.DUEL and model.checkpoint_hp==9,"The final checkpoint records life actually recovered through items")
	model.hp=1
	model.retry()
	check(model.hp==9 and model.health_pickups[0].collected and model.health_pickups[1].collected,"A final-duel retry preserves consumed items and cannot grant extra healing")
	var capped:=DUEL.new()
	capped.apply_stats(stats(10))
	capped.start()
	capped._spawn_health_pickup(1,2,Vector2(576,515))
	capped.position=Vector2(576,515)
	capped.interact()
	check(capped.hp==10 and not capped.health_pickups[0].collected,"An item remains available when life is full")
	check(capped.wind_cast>0,"A full-life pickup does not block the wind command")
	capped.hp=9
	capped.interact()
	check(capped.hp==10 and capped.recovered_hp==1,"Pickup healing stops at maximum life")
	capped._spawn_health_pickup(1,2,Vector2(576,515))
	check(capped.health_pickups.size()==1 and capped.health_pickups[0].collected,"Spawning the same reward cannot duplicate an already consumed item")

func army_checks() -> void:
	var model:=DUEL.new()
	model.apply_stats(stats())
	model.start()
	model._enter(DUEL.Phase.GUARDS)
	check(model.guards.remaining()==5,"The first army wave contains five knights")
	check(model.guards.enemies.all(func(e): return not e.elite and e.role!="archer" and e.max_hp<=28),"The five opening knights are weak or medium strength")
	model.tick(3)
	check(model.hazards.is_empty() and model.attack_count==0,"Poseidon never starts background attacks during the army stage")
	model._wind_hit()
	check(model.anchor_hits==0,"Wind alone cannot skip an army wave")
	for wave in 3:
		for enemy in model.guards.enemies:
			enemy.hp=0
			enemy.state="dead"
		model.tick(1.3)
		check(model.anchor_hits==wave+1 and model.hazards.is_empty(),"Wave %d advances by defeating enemies without Poseidon attacks"%(wave+1))
		if wave==0:
			var alive:=model.guards.enemies.filter(func(e): return e.hp>0)
			check(alive.size()==1 and alive[0].elite and alive[0].max_hp==84,"The second wave contains one strong knight")
		if wave==1:
			var alive:=model.guards.enemies.filter(func(e): return e.hp>0)
			check(alive.size()==3 and alive.filter(func(e): return e.role=="archer").size()==1 and alive.filter(func(e): return e.role!="archer" and e.max_hp==20).size()==2,"The last wave contains one archer and two weak knights")
	check(model.phase==DUEL.Phase.DISARM and not model.has_trident,"The third wave ends with the earned disarm moment")
	model._wind_hit()
	check(not model.trident_dropped,"The trident remains held until the grip is exposed")
	model.tick(1.4)
	model.set_input(Vector2.ZERO,model.wind_point-model.position,false)
	model.request_wind()
	model.tick(1)
	check(model.trident_dropped,"A real wind projectile still disarms Poseidon")
	model.tick(0.9)
	model.position=model.trident
	model.interact()
	check(model.phase==DUEL.Phase.UNLEASH,"The trident must be collected before opening the whole bag")
	var army:=DUEL.GUARDS.new()
	army.spawn_formation(1,DUEL.ARENA,24,84)
	var captain: Dictionary=army.enemies[0]
	captain.position=Vector2(500,475)
	captain.facing=Vector2.RIGHT
	captain.state="approach"
	army.hit(Vector2(600,475),Vector2.LEFT,136,6)
	check(captain.hp==81,"The strong knight retains frontal armor")
	captain.state="recover"
	army.hit(Vector2(600,475),Vector2.LEFT,136,6)
	check(captain.hp==75,"Recovery exposes the strong knight to full damage")
	army.clear()
	army.spawn_formation(0,DUEL.ARENA,24,84)
	for i in army.enemies.size():
		army.enemies[i].state="approach"
		army.enemies[i].position=Vector2(576+(i-2)*28,450)
	army.tick(0.01,Vector2(576,480),DUEL.ARENA)
	check(army._attack_slots()==2,"Five knights still leave a maximum of two committed melee attacks at a time")
	army.clear()
	army.spawn_formation(0,DUEL.ARENA,24,84)
	var target: Dictionary=army.enemies[0]
	target.state="approach"
	target.position=Vector2(500,480)
	target.origin=target.position
	var before_hp:int=target.hp
	check(army.hit_by_wind(Vector2(400,480),Vector2(520,480),3),"Wind hits an actual knight")
	army.tick(0.1,Vector2(800,480),DUEL.ARENA)
	var push_distance:float=target.position.x-500
	check(target.hp<before_hp and push_distance>30,"Wind keeps its damage and physically pushes a knight")
	army.clear()
	army.spawn_formation(1,DUEL.ARENA,24,84)
	target=army.enemies[0]
	target.state="approach"
	target.position=Vector2(500,480)
	target.origin=target.position
	army.hit_by_wind(Vector2(400,480),Vector2(520,480),3)
	army.tick(0.1,Vector2(800,480),DUEL.ARENA)
	check(target.position.x>500 and target.position.x-500<push_distance,"The strong knight resists knockback without being immune")
	army.clear()
	army.spawn_formation(2,DUEL.ARENA,24,84)
	var archer: Dictionary=army.enemies[0]
	archer.position=Vector2(800,450)
	archer.state="aim"
	archer.age=1.01
	archer.direction=Vector2.LEFT
	army.tick(0.02,Vector2(400,425),DUEL.ARENA)
	check(army.arrows.size()==1,"The archer actually releases a projectile")
	var arrow_damage:=0
	for frame in 70:
		for hit in army.tick(STEP,Vector2(400,425),DUEL.ARENA):arrow_damage+=hit.damage
	check(arrow_damage==2,"A visible water arrow causes the configured damage")
	var arrow:Dictionary={"position":Vector2(500,480),"direction":Vector2.RIGHT}
	check(not WATER.arrow_hits(arrow,Vector2(500,503)),"The archer cannot hit outside the visible arrow")

func trident_checks() -> void:
	var model:=DUEL.new()
	model.apply_stats(stats())
	model._enter(DUEL.Phase.DUEL)
	model.position=model.boss-Vector2(100,0)
	model.combo_step=2
	model.move=DUEL.Move.THRUST
	model.strike_origin=model.boss
	model.strike_angle=-PI*0.5
	model._set_state(DUEL.State.STRIKE)
	model.state_age=model.strike_time()-0.16
	model.set_input(Vector2.ZERO,Vector2.RIGHT*10,false)
	model.request_attack()
	model.tick(0.12)
	check(model.boss_hp==model.boss_max_hp and not model.attack_applied,"A trident touching a guarded boss is not consumed before its active frames end")
	model.tick(0.12)
	var damage_done:=model.boss_max_hp-model.boss_hp
	check(damage_done>0 and model.hits_in_opening==1,"A swing already extending when the opening begins can deal damage")
	model.tick(0.07)
	check(model.boss_max_hp-model.boss_hp==damage_done,"One trident animation cannot deal damage on every active frame")
	check(model.last_boss_damage==damage_done and model.boss_damage_until>model.clock,"Successful hits expose the actual damage amount for feedback")
	model._set_state(DUEL.State.REST)
	model.hits_in_opening=0
	model.attack_age=0.105
	check(is_equal_approx(model.trident_extension()+66,DUEL.TRIDENT_REACH),"The visible trident tip reaches the same distance as its damaging thrust")
	model.hits_in_opening=2
	check(not model.boss_vulnerable(),"Two successful hits visibly close the guard for the current opening")
	model.combo_step=2
	model.move=DUEL.Move.THRUST
	model._set_state(DUEL.State.STRIKE)
	model.state_age=model.strike_time()-0.01
	model.attack_age=-1
	model.tick(0.03)
	check(model.state==DUEL.State.REST and model.hits_in_opening==0 and model.boss_vulnerable(),"Completing the next combo opens the guard again instead of locking damage after the first opening")

func mouse_trident_checks() -> void:
	var scene: Control=load(SCENE).instantiate()
	scene.audio_enabled=false
	root.add_child(scene)
	current_scene=scene
	scene.set_physics_process(false)
	scene.set_process(false)
	var model: DUEL=scene.duel
	model.apply_stats(stats(10,1.1,6,2))
	model._enter(DUEL.Phase.DUEL)
	model.boss=Vector2(600,480)
	model.position=Vector2(480,480)
	model._set_state(DUEL.State.REST)
	model.hits_in_opening=0
	scene._refresh()
	var target: Vector2=scene.frame.get_global_transform_with_canvas()*(model.boss-Vector2(24,30))
	var before:=model.boss_hp
	click(MOUSE_BUTTON_LEFT,target)
	model.tick(0.18)
	check(model.boss_hp<before,"A real left click on Poseidon's image deals damage during recovery")
	model.tick(0.33)
	click(MOUSE_BUTTON_LEFT,target)
	model.tick(0.18)
	check(model.hits_in_opening==2,"Two separate left clicks can connect in one opening")
	model.tick(0.33)
	before=model.boss_hp
	click(MOUSE_BUTTON_LEFT,target)
	model.tick(0.18)
	check(model.boss_hp==before and model.attack_feedback=="GUARDA REFEITA","Further clicks show the reformed guard instead of silently ignoring damage")
	model.attack_age=-1
	model._set_state(DUEL.State.REST)
	model.hits_in_opening=0
	scene.frame.scale=Vector2.ONE*1.25
	scene.frame.position=Vector2(15,5)
	target=scene.frame.get_global_transform_with_canvas()*(model.boss-Vector2(24,30))
	click(MOUSE_BUTTON_LEFT,target)
	model.tick(0.18)
	check(model.boss_hp<before and model.attack_direction.x>0.99,"Mouse attacks keep their aim when the game canvas is scaled")
	scene.queue_free()
	await process_frame

func run() -> void:
	var manager: Node=root.get_node("GameManager")
	manager.persistence_enabled=false
	manager.reset()
	manager.charybdis_completed=true
	model_checks()
	hitbox_checks()
	recovery_checks()
	army_checks()
	trident_checks()
	var model:=DUEL.new()
	model.apply_stats(stats(10,1.1,6,2.0))
	model.start()
	phase_times[model.phase]=0.0
	var retries := 0
	for frame in 60000:
		var before:=model.phase
		bot_step(model)
		if before!=model.phase:
			phase_times[model.phase]=snappedf(model.clock,0.1)
			print("BOT PHASE ",model.phase," at ",snappedf(model.clock,0.1)," HP ",model.hp," guard kills ",model.guards.kills)
		if model.phase == DUEL.Phase.WON: break
		if model.phase == DUEL.Phase.LOST:
			if retries >= 5: break
			retries += 1
			model.retry()
			bot_motion=Vector2.ZERO
			print("BOT RETRY ",retries," phase ",model.phase," HP ",model.hp)
	print("BOT RESULT phase ",model.phase," hp ",model.hp," seals ",model.barrier_hits," anchors ",model.anchor_hits," boss ",model.boss_hp," time ",model.clock)
	check(model.phase==DUEL.Phase.WON,"A complete encounter can be won with normal movement and attacks")
	check(model.barrier_hits==3 and model.anchor_hits==3,"The first two stages each finish after exactly three cleared waves")
	var scene: Control=load(SCENE).instantiate()
	scene.audio_enabled=false
	root.add_child(scene)
	current_scene=scene
	scene.set_physics_process(false)
	scene.set_process(false)
	await capture(scene,"00_comandos")
	press(KEY_ENTER)
	check(scene.duel.phase==DUEL.Phase.SURGE,"Enter starts the arena through normal input")
	scene._refresh()
	check(scene.dash_hint.visible and scene.objective.text.contains("vento"),"The first objective and dash key are visible before the first dodge")
	press(KEY_Q)
	check(scene.duel.dash_left>0,"Q activates the established dash")
	scene.stage.advance(0.1)
	check(scene.stage.dash_bar.visible and scene.stage.dash_bar.position==scene.duel.position,"Dash recharge remains attached to Odisseu")
	scene.duel.tick(0.3)
	click(MOUSE_BUTTON_LEFT)
	check(scene.duel.attack_age>=0 and scene.duel.projectiles.is_empty(),"Left mouse attacks with the weapon and never fires wind")
	scene.duel.tick(0.5)
	scene.duel.retry()
	click(MOUSE_BUTTON_RIGHT)
	check(scene.duel.dash_left>0 and scene.duel.projectiles.is_empty(),"Right mouse dashes exactly as in the other combat scenes and never fires wind")
	scene.duel.tick(0.3)
	press(KEY_E)
	check(scene.duel.projectiles.size()==1 and scene.duel.wind_cast>0 and scene.duel.dash_left==0,"E fires wind without taking over the mouse dash")
	scene.duel.retry()
	press(KEY_SPACE)
	check(scene.duel.dash_left>0 and scene.duel.projectiles.is_empty(),"Space provides an alternate dash without firing wind")
	scene.duel.tick(0.3)
	scene.duel._set_state(DUEL.State.EXPOSED)
	scene._refresh()
	check(scene.interaction_hint.visible and scene.interaction_hint.text.contains("VENTO"),"An exposed weak point identifies the wind command next to its target")
	await capture(scene,"01_mar")
	scene.duel._enter(DUEL.Phase.GUARDS)
	scene.duel.tick(1.5)
	await capture(scene,"02_soldados")
	scene.duel._enter(DUEL.Phase.DISARM)
	scene.duel.tick(1.4)
	await capture(scene,"03_punho_exposto")
	scene.duel._wind_hit()
	scene.duel.tick(0.9)
	scene.duel.trident_dropped=true
	scene.duel.trident=scene.duel.position
	press(KEY_E)
	check(scene.duel.phase==DUEL.Phase.UNLEASH and scene.duel.has_trident,"E picks up the earned trident")
	scene._refresh()
	check(scene.objective.text.contains("segure E") and scene.interaction_hint.visible,"The bag objective explains stopping and holding E next to Odisseu")
	var hold:=InputEventKey.new()
	hold.physical_keycode=KEY_E
	hold.pressed=true
	Input.parse_input_event(hold)
	Input.flush_buffered_events()
	for frame in 150:scene._physics_process(STEP)
	check(scene.duel.bag_emptied,"Holding physical E opens the whole bag through the actual controller")
	hold=hold.duplicate()
	hold.pressed=false
	Input.parse_input_event(hold)
	Input.flush_buffered_events()
	scene.duel.tick(2.8)
	await capture(scene,"03_bolsa_aberta")
	scene.duel.tick(2.8)
	scene.duel.tick(1.3)
	await capture(scene,"04_tempestade")
	check(not manager.final_poseidon_completed,"Entering the final duel does not count as victory")
	scene.duel._enter(DUEL.Phase.ENDING)
	scene.duel.tick(3)
	check(not manager.final_poseidon_completed,"The ending must finish before saving victory")
	for n in 4: scene.duel.tick(3)
	check(manager.final_poseidon_completed and manager.player_current_hp==scene.duel.hp,"Victory carries remaining HP into Ithaca")
	await capture(scene,"05_vitoria")
	scene.queue_free()
	await process_frame
	await mouse_trident_checks()
	print("FINAL_POSEIDON: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
