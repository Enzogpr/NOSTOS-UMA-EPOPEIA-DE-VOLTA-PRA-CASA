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
	_jump_checks()
	_sail_and_retreat_checks()
	_failure_and_checkpoint_checks()
	_completion_checks()
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
