extends Node
## Behavioral checks for the representative encounter; no renderer or campaign state.
const M := preload("res://Ato4_Tempestade/Gameplay/PoseidonRuptureModel.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func fresh() -> M:
	var m := M.new()
	m.start()
	return m

func advance(m: M, seconds: float, move := 0.0, duck := false, jump := false, held := false, rate := 120) -> void:
	for frame in int(round(seconds*rate)):
		m.tick(1.0/rate,move,duck,jump and frame == 0,held)

func fixture(rect := Rect2(80,475,1000,20), kind := "deck", bob := 0.0, drift := 0.0) -> M:
	var m := fresh()
	# Remove directed events to isolate contact behavior from encounter timing.
	m.encounter_state = "collision_fixture"
	m.platforms.clear()
	m.obstacles.clear()
	m.hazards.clear()
	m.proof_platform(rect,kind,0,bob,drift)
	m.position = Vector2(rect.position.x+100,rect.position.y)
	m.support = 0
	m.grounded = true
	return m

func _ready() -> void:
	_ramp_checks()
	_mobile_checks()
	_water_contact_checks()
	_jump_checks()
	_sail_and_retreat_checks()
	_failure_and_checkpoint_checks()
	_hazard_checkpoint_checks()
	_painted_pursuit_checks()
	_completion_checks()
	_run_route()
	print("POSEIDON RUPTURE: ",checks," checks; ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _ramp_checks() -> void:
	var m := fixture(Rect2(100,500,600,20),"ramp")
	m.ramp_start = Vector2(100,500)
	m.ramp_end = Vector2(700,350)
	m.position = Vector2(200,475)
	var endpoints: Array[Vector2] = m.surface_endpoints(0)
	check(endpoints[0] == m.ramp_start and endpoints[1] == m.ramp_end,"The collision surface must use the same two mast endpoints exposed to rendering.")
	var start_y := m.position.y
	var contact_ok := true
	for frame in 120:
		m.tick(1.0/120,1)
		contact_ok = contact_ok and m.grounded and m.support == 0 and absf(m.position.y-m.surface_y_at(0,m.position.x)) < 0.05
	check(contact_ok and m.position.x > 450 and m.position.y < start_y-60,"Running uphill must continuously follow the mast, without floating, hopping or tunneling.")
	var top := m.position
	advance(m,0.2,-1)
	var reverse_start := m.position
	contact_ok = true
	for frame in 105:
		m.tick(1.0/120,-1)
		contact_ok = contact_ok and m.grounded and m.support == 0 and absf(m.position.y-m.surface_y_at(0,m.position.x)) < 0.05
	check(contact_ok and m.position.x < reverse_start.x-200 and m.position.y > top.y+40,"Reversing downhill must retain contact with the same mast instead of dropping through it.")
	check(m.surface_endpoints(0) == endpoints,"Walking either way must not move the authored mast endpoints.")
	# A deck joins the high end at the exact same physical point.
	var joint := fixture(Rect2(100,500,600,20),"ramp")
	joint.ramp_start = Vector2(100,500)
	joint.ramp_end = Vector2(700,350)
	joint.proof_platform(Rect2(700,350,400,20),"deck",0)
	joint.position = Vector2(655,joint.surface_y_at(0,655))
	joint.velocity.x = 305
	advance(joint,0.45,1)
	check(joint.grounded and joint.support == 1 and is_equal_approx(joint.position.y,350),"The ramp-to-deck join must transfer support without an unintended gap or jump.")
	advance(joint,0.7,-1)
	check(joint.grounded and joint.support == 0 and absf(joint.position.y-joint.surface_y_at(0,joint.position.x)) < 0.05,"The same join must remain traversable from deck back onto the ramp.")

func _mobile_checks() -> void:
	var moving := fixture(Rect2(100,430,600,20),"wreck",22,72)
	moving.position = Vector2(300,moving.surface_y_at(0,300))
	var initial := moving.position
	var anchor: Vector2 = moving.surface_endpoints(0)[0]
	advance(moving,0.8)
	var expected := initial+(moving.surface_endpoints(0)[0]-anchor)
	check(moving.grounded and moving.support == 0 and moving.position.distance_to(expected) < 0.05,"An idle rider must be carried by the wreck's horizontal and vertical displacement.")
	moving.tick(1.0/120,0,false,true,true)
	check(not moving.grounded and moving.velocity.y < -600 and moving.jumps == 1,"Jumping from a moving wreck must detach immediately and preserve a real jump.")
	var airborne_x := moving.position.x
	advance(moving,0.15,0,false,false,true)
	check(absf(moving.position.x-airborne_x) < 0.05 and not moving.grounded,"An airborne character must no longer inherit the wreck's horizontal displacement.")
	var removed := fixture(Rect2(100,430,600,20),"wreck",14,40)
	removed.position = Vector2(300,removed.surface_y_at(0,300))
	var before := removed.position
	removed.platforms[0].gone = true
	advance(removed,0.2)
	check(not removed.grounded and removed.support == -1 and removed.position.y > before.y+20,"Removing a support underfoot must produce a fall, never relocation to another surface.")
	check(absf(removed.position.x-before.x) < 0.05,"A removed moving support must stop transporting its former rider.")

func _water_contact_checks() -> void:
	var m := fresh()
	var follows_water := true
	var future_drift := false
	for i in m.platforms.size():
		if m.platforms[i].kind != "wreck": continue
		for time in [0.0,0.35,2.2,8.75]:
			var ends: Array[Vector2] = m.surface_endpoints(i,time)
			var center_x: float = (ends[0].x+ends[1].x)*0.5
			follows_water = follows_water and absf(ends[0].y-(m.water_height_at(center_x,time)-18)) < 0.001 and ends[0].y == ends[1].y
			future_drift = future_drift or absf(ends[0].x-m.platforms[i].rect.position.x) > 10
	check(follows_water and future_drift,"Every floating wreck must sample the shared water at its horizontally drifting center, including future collision samples.")
	var before: Array[Vector2] = m.surface_endpoints(3,4.0)
	m.platforms[3].drop_at = 3.5
	var dropping: Array[Vector2] = m.surface_endpoints(3,4.0)
	check(is_equal_approx(dropping[0].y-before[0].y,40.0) and dropping[0].x == before[0].x,"A wreck's sinking motion must be added to its water contact without shifting the horizontal drift phase.")
	m.encounter_state = "mast_fall"
	m.position = Vector2(350,475)
	m.event_age = 1.45
	advance(m,0.15)
	var settled: Array[Vector2] = m.surface_endpoints(2)
	var tip: Vector2 = m.ramp_start+Vector2.from_angle(m.mast_angle)*m.ramp_start.distance_to(m.ramp_end)
	check(m.encounter_state == "crossing" and m.ramp_ready and not m.platforms[2].gone and settled[1] == Vector2(1100,540),"The completed mast fall must enable a physical ramp descending toward the water at y540.")
	check(tip.distance_to(settled[1]) < 0.01 and settled[1].y > settled[0].y,"The settled visual mast angle and collision endpoint must coincide on the descending passage.")
	var sinking := fresh()
	sinking.encounter_state = "pursuit"
	sinking.front_active = true
	sinking.front_x = 3421
	sinking.position = Vector2(3800,300)
	sinking.grounded = false
	sinking.support = -1
	sinking.tick(1.0/120)
	check(sinking.sunk_at[2] >= 0 and sinking.platforms[8].gone and sinking.platforms[9].gone,"Sinking the third hull must remove its deck and raised cargo support together, leaving no floating ledge collider.")
	sinking.encounter_state = "sunk_cargo_fixture"
	sinking.front_active = false
	sinking.position = Vector2(3330,355)
	sinking.grounded = true
	sinking.support = -1
	advance(sinking,0.2)
	check(not sinking.grounded and sinking.position.y > 375,"The sunk hull's cargo obstacle must also stop supporting the player after its deck and ledge are removed.")

func _jump_checks() -> void:
	var coyote := fixture(Rect2(80,430,400,20))
	coyote.position = Vector2(482,430)
	coyote.velocity.x = 305
	advance(coyote,0.06,1)
	check(not coyote.grounded,"The coyote-time fixture must actually leave the edge before requesting a jump.")
	coyote.tick(1.0/120,1,false,true,true)
	check(coyote.jumps == 1 and coyote.velocity.y < -600,"A jump just beyond the deck must retain the existing coyote-time forgiveness.")
	var late := fixture(Rect2(80,430,400,20))
	late.position = Vector2(482,430)
	late.velocity.x = 305
	advance(late,0.22,1)
	late.tick(1.0/120,1,false,true,true)
	check(late.jumps == 0 and late.velocity.y > 0,"Coyote time must expire; it cannot become an airborne second jump.")
	var buffered := fixture()
	buffered.position = Vector2(250,455)
	buffered.velocity.y = 220
	buffered.grounded = false
	buffered.support = -1
	advance(buffered,0.14,0,false,true,true)
	check(buffered.jumps == 1 and not buffered.grounded and buffered.velocity.y < 0,"A jump pressed shortly before landing must be buffered and fire after real contact.")
	var high := fixture()
	var low := fixture()
	var high_y := high.position.y
	var low_y := low.position.y
	for frame in 115:
		high.tick(1.0/120,0,false,frame==0,true)
		low.tick(1.0/120,0,false,frame==0,frame<4)
		high_y = minf(high_y,high.position.y)
		low_y = minf(low_y,low.position.y)
	check(high_y < low_y-80 and high.grounded and low.grounded,"Variable-height jump must remain controllable and both arcs must land back on the deck.")
	var fast := fixture()
	var slow := fixture()
	advance(fast,0.7,1,false,true,true,30)
	advance(slow,0.7,1,false,true,true,120)
	check(fast.position.distance_to(slow.position) < 0.1 and fast.grounded == slow.grounded,"Equivalent jump inputs at 30 and 120 fps must produce the same trajectory.")

func _sail_and_retreat_checks() -> void:
	var sail := fixture()
	sail.obstacles.append({"rect":Rect2(490,200,140,215),"kind":"sail","boat":0,"active":true})
	sail.position = Vector2(450,475)
	advance(sail,0.4,1)
	check(sail.position.x <= 476.1 and not sail.crouching,"The lowered sail must physically stop a standing character.")
	advance(sail,0.65,1,true)
	check(sail.position.x > 535 and sail.crouching and not sail.can_stand(),"Crouching must physically fit through the sail gap instead of bypassing its collision.")
	sail.tick(1.0/120,0,false)
	check(sail.crouching and sail.body_rect().size.y == M.CROUCH_HEIGHT,"Releasing duck under the sail must not expand the collider into its underside.")
	advance(sail,0.8,1)
	check(sail.position.x > 645 and not sail.crouching and sail.can_stand(),"The character must stand naturally once clear of the sail.")
	var retreat := fresh()
	retreat.position = Vector2(680,475)
	retreat.tick(1.0/120)
	advance(retreat,2.2)
	check(retreat.bow_broken and retreat.platforms[1].gone and retreat.encounter_state == "retreat","The announced bow rupture must remove the forward support while preserving the retreat deck.")
	advance(retreat,0.55,-1)
	check(retreat.position.x >= 643.9 and not retreat.retreated,"Standing retreat must be blocked by the actual fallen sail.")
	advance(retreat,2.1,-1,true)
	check(retreat.retreated and retreat.ducked_sail and retreat.encounter_state == "mast_fall","Reversing direction and crouching through the sail must reach the mast and cause the new route to form.")
	var right_only := fresh()
	for frame in 3600:
		right_only.tick(1.0/120,1,false,frame%54==0,frame%54<34)
		if right_only.phase in [M.Phase.FAILED,M.Phase.COMPLETE]: break
	check(right_only.phase != M.Phase.COMPLETE and not right_only.retreated,"Holding right and repeatedly jumping must not complete the authored retreat encounter.")
	check(not right_only.record().proof_complete and not right_only.record().escaped,"A failed or blocked forward-only attempt must never record a completed proof or campaign escape.")

func _failure_and_checkpoint_checks() -> void:
	var m := fresh()
	m.position = Vector2(350,475)
	m.encounter_state = "retreat"
	m.route_clock = 6.25
	m.clock = 6.25
	m.event_age = 2.3
	m.front_x = -23
	m.events = {"already_warned":2.0}
	m.bow_broken = true
	m.platforms[1].gone = true
	m.sail_drop = 1
	m.obstacles[1].active = true
	m.tick(1.0/120)
	check(m.encounter_state == "mast_fall" and m.local_checkpoint.state == "mast_fall","Reaching the retreat anchor must establish the next safe checkpoint through normal encounter progression.")
	var saved_position := m.position
	var saved_route := m.route_clock
	var saved_clock := m.clock
	var saved_age := m.event_age
	var saved_front := m.front_x
	var saved_events: Dictionary = m.events.duplicate(true)
	var saved_mobile: Array[Vector2] = m.surface_endpoints(3)
	var saved_objective := m.objective()
	advance(m,1.8)
	m.events["only_in_failed_attempt"] = m.route_clock
	m.front_x = 700
	m.position = Vector2(350,650)
	m.grounded = false
	m.support = -1
	m.tick(1.0/120)
	check(m.phase == M.Phase.FAILED and m.velocity == Vector2.ZERO,"A lost support must end the attempt and stop motion rather than auto-rescue the character.")
	var stopped_position := m.position
	var stopped_route := m.route_clock
	var stopped_elapsed := m.elapsed_total
	var stopped_clock := m.clock
	m.tick(3,1,true,true,true,true)
	check(m.phase == M.Phase.FAILED and m.position == stopped_position and m.clock == stopped_clock and m.route_clock == stopped_route and m.elapsed_total == stopped_elapsed,"Failure must freeze simulation even when all movement and interaction inputs are supplied.")
	m.retry_checkpoint()
	check(m.phase == M.Phase.TRAVERSAL and m.position == saved_position and m.retries == 1,"An explicit retry must restore the saved safe point and count the failed attempt.")
	check(is_equal_approx(m.route_clock,saved_route) and is_equal_approx(m.clock,saved_clock) and is_equal_approx(m.event_age,saved_age),"Retry must restore local, global and event clocks, preventing a pre-expired destruction sequence.")
	check(m.front_x == saved_front and not m.front_active and m.events == saved_events,"Retry must restore the water front and event ledger without events from the discarded attempt.")
	check(m.surface_endpoints(3) == saved_mobile and m.platforms[1].gone and m.platforms[2].gone,"Retry must restore the exact mobile-support phase and the checkpoint's broken bow / unavailable mast geometry.")
	check(m.elapsed_total == stopped_elapsed and m.elapsed_total > 1.7 and m.record().seconds >= 1.7,"Elapsed attempt statistics must remain cumulative even though the local challenge clock rewinds.")
	check(m.velocity == Vector2.ZERO and m.jump_buffer == 0 and m.grounded,"Retry must clear queued jumps and motion and put the player on a real safe support.")
	check(m.objective() == saved_objective,"The restored objective must describe the checkpoint's event rather than a later discarded route state.")

func _completion_checks() -> void:
	var m := fresh()
	m.encounter_state = "safe"
	m.front_active = false
	m.position = Vector2(5065,420)
	m.grounded = true
	m.support = 15
	m.velocity.x = 305
	var emitted: Array[Dictionary] = []
	m.completed.connect(func(data: Dictionary): emitted.append(data))
	advance(m,0.1,1)
	check(m.phase == M.Phase.COMPLETE and m.velocity == Vector2.ZERO and emitted.size() == 1,"Crossing the proof's safe endpoint must stop motion, complete it and emit one result.")
	check(m.record().proof_complete and not m.record().escaped and m.record().mode == "rupture_proof","The proof result must remain distinct from escaping Poseidon in the full campaign.")
	m.tick(4,1,false,true,true,true)
	check(emitted.size() == 1 and m.completion_count == 1,"Additional inputs after proof completion must never emit another completion.")

func _hazard_checkpoint_checks() -> void:
	var m := fresh()
	m.encounter_state = "checkpoint_fixture"
	m.route_clock = 9.25
	m.clock = 9.25
	m._spawn_attack("low",1)
	m.hazards[0].age = 0.37
	m.hazards[0].hit = true
	m.hazards[0].counted = true
	m.events = {"low_wave":8.88}
	m._save_checkpoint()
	var saved: Dictionary = m.hazards[0].duplicate(true)
	m.hazards[0].age = 3.0
	m.hazards[0].hit = false
	m.hazards[0].x += 400
	m.events["discarded_attack"] = 12.25
	check(m.local_checkpoint.hazards[0] == saved and not m.local_checkpoint.events.has("discarded_attack"),"A saved attack and event ledger must be independent of live dictionaries mutated later in the failed attempt.")
	m._fail("checkpoint hazard fixture")
	m.retry_checkpoint()
	check(m.hazards.size() == 1 and m.hazards[0] == saved and m.events == {"low_wave":8.88},"Retry must restore active attacks with their exact age, position, hit and counted flags, alongside the matching event ledger.")
	m.hazards[0].age += 0.1
	m.hazards[0].hit = false
	m.events["new_attempt"] = m.route_clock
	check(m.local_checkpoint.hazards[0] == saved and m.local_checkpoint.events == {"low_wave":8.88},"Restored attacks and events must remain deep copies, so a second failed attempt cannot corrupt the checkpoint.")
	m._fail("checkpoint hazard fixture second attempt")
	m.retry_checkpoint()
	check(m.hazards[0] == saved and m.events == {"low_wave":8.88},"A second retry must recover the original attack without replaying its spawn event or losing its hit state.")

func _painted_pursuit_checks() -> void:
	var source := fresh()
	var image := Image.new()
	image.load_png_from_buffer(FileAccess.get_file_as_bytes(str(source.wave_profile.texture)))
	check(not image.is_empty() and image.get_size() == Vector2i(int(source.wave_profile.source_size[0]),int(source.wave_profile.source_size[1])),"The pursuit collision profile must describe the dimensions of the actual painted wave asset.")
	var matches_paint := not image.is_empty()
	if matches_paint:
		for sample in source.wave_profile.opaque_right_edge:
			var run := 0
			var painted_edge := -1
			for x in image.get_width():
				if roundi(image.get_pixel(x,int(sample[0])).a*255) > int(source.wave_profile.alpha_threshold): run += 1
				else: run = 0
				if run >= int(source.wave_profile.minimum_opaque_run): painted_edge = x
			matches_paint = matches_paint and painted_edge == int(sample[1])
	check(matches_paint,"Every sampled collision edge must still match the substantial opaque water in the source image, excluding isolated spray pixels.")
	var m := fixture(Rect2(1000,450,1000,20))
	m.position = Vector2(1490,450)
	m.front_active = true
	m.front_x = 1500
	advance(m,0.05)
	check(m.phase == M.Phase.TRAVERSAL and m.position.x < m.front_x and not m._pursuit_touches_body(),"Passing the wave's nominal front must remain safe until the substantial painted water actually reaches the body.")
	advance(m,0.6)
	check(m.phase == M.Phase.FAILED and m._pursuit_touches_body(),"The same stationary character must be caught once the continuously advancing painted crest reaches him.")
	var profile := fresh()
	profile.front_x = 1500
	check(profile.pursuit_boundary_at(350) < profile.pursuit_boundary_at(530)-100,"The curling opening around y350 must recede substantially behind the lower water mass instead of using a flat lethal wall.")
	profile.position = Vector2(1400,350)
	check(profile.position.x-M.HALF_WIDTH > profile.pursuit_boundary_at(350) and profile._pursuit_touches_body(),"A character whose feet clear the curling opening must still be hit when his upper body touches the painted crest above it.")
	profile.position.y = 450
	var body: Rect2 = profile.body_rect()
	var limiting_edge := -INF
	for fraction in [0.05,0.25,0.5,0.75,0.95]:
		limiting_edge = maxf(limiting_edge,profile.pursuit_boundary_at(lerpf(body.position.y,body.end.y,fraction)))
	profile.position.x = limiting_edge+M.HALF_WIDTH+0.25
	var outside := not profile._pursuit_touches_body()
	profile.position.x -= 0.5
	check(outside and profile._pursuit_touches_body(),"Wave contact must follow the actual left body edge continuously, without snapping at a rounded nominal front coordinate.")
	profile.position = Vector2(500,-10)
	var above_safe := not profile._pursuit_touches_body() and profile.pursuit_boundary_at(-10) == -INF
	profile.position.y = 700
	check(above_safe and not profile._pursuit_touches_body() and profile.pursuit_boundary_at(700) == -INF,"Transparent space above and outside the wave image must not extend its lethal collision into an invisible infinite wall.")

func _run_route() -> void:
	var m := fresh()
	var pilot := preload("res://scratch/PoseidonRupturePilot.gd").new()
	for frame in 7200:
		var control: Dictionary = pilot.controls(m)
		m.tick(1.0/60,control.move,control.duck,control.jump,control.held,control.interact)
		if m.phase in [M.Phase.FAILED,M.Phase.COMPLETE]: break
	check(m.phase == M.Phase.COMPLETE and m.retreated and m.ducked_sail and m.crossed_ramp and m.mobile_landings >= 8,"The water-bound route must remain completable through real movement inputs, including retreat, crouch, mast crossing and the floating wrecks.")
	print("RUPTURE PHYSICS ROUTE ",m.record()," position ",m.position," state ",m.encounter_state," phase ",m.phase," reason ",m.failure_reason)
