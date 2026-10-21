extends SceneTree
const Model = preload("res://Ato4_Tempestade/Gameplay/PoseidonCadenceModel.gd")
const Pilot = preload("res://scratch/PoseidonCadencePilot.gd")
var checks:=0
var failures:=0

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var m:=Model.new()
	check(m.boats.size()==11,"Ten intermediate boats plus captain ship")
	check(m.final_index==10,"Captain index retains existing integration")
	for i in m.platforms.size():
		if m.platforms[i].kind!="wreck" or m.platforms[i].gone: continue
		var r:=m.platform_rect(i)
		check(absf(r.position.y-m.water_height_at(r.get_center().x)+18)<0.01,"Wreck collision follows water surface")
	m.start()
	m.capture_score({"section":"surge","position":1.25,"loop":2})
	var checkpoint_clock:=m.clock
	var checkpoint_score:=m.score_time
	m.tick(0.2,1)
	m._fail("fixture")
	m.retry_checkpoint()
	check(m.clock==checkpoint_clock and m.score_time==checkpoint_score,"Exact physics and musical clocks restored")
	check(m.checkpoint.music.position==1.25,"Playback snapshot preserved")
	check(m.active() and m.retries==1,"Explicit retry only")
	# Sound playback is authoritative; phrase births align to beat boundaries.
	m.set_score_time(23.5,47)
	check(m.score_time==23.5 and m.score_beat==47,"Music clock input accepted")
	var chart:=Model.new()
	chart.start()
	chart.position.x=800
	chart.next_attack_score=2
	chart.set_score_time(1.99)
	chart.tick(0.02)
	check(chart.hazards.size()==1,"Crossing musical boundary births one physical attack")
	check(chart.hazards[0].x>chart.position.x+400,"Attack travels from ahead rather than spawning on body")
	check(chart.hazards[0].warning<0.9,"Only physical water formation, no long warning phase")
	var assaulted:=Model.new()
	assaulted.start()
	assaulted.position=assaulted.boats[1].rect.position+Vector2(100,0)
	assaulted._enter_boat(1)
	check(assaulted.sunk_at[0]<0 and assaulted.fleet_assaults.is_empty(),"Crossing onto another ship never destroys the previous hull immediately")
	assaulted.next_attack_score=100000
	assaulted.fleet_next_score=0
	assaulted.tick(0.2)
	check(assaulted.fleet_assaults.size()==1 and assaulted.sunk_at[0]<0,"Visible divine assault begins before its target ship sinks")
	for i in 16: assaulted.tick(0.2)
	check(assaulted.sunk_at[0]>=0,"The timed physical assault eventually destroys its selected ship")
	var final:=Model.new()
	final.start()
	final.position=Vector2(final.final_origin+120,final.boats[10].rect.position.y)
	final.grounded=true
	final._enter_boat(10)
	check(final.boarding.deck.end.x-75+31<final.final_origin+1360,"Giants walk and arrive before the bow cargo, never through its crate")
	check(final.boarding.active and not final.boarding.cleared,"Captain ship starts the boarding encounter")
	final.boarding.player_guarding=true
	final._hit("low",-1)
	check(final.balance==72,"A melee guard cannot block Poseidon's water attack")
	final._fail("guard fixture reset")
	final.retry_checkpoint()
	final.position=final.bag_point
	final._final_interaction(0.4,true)
	check(not final.has_bag and final.bag_progress==0,"Bag cannot be collected before the boarders are defeated")
	final.position=Vector2(final.final_origin+120,final.boats[10].rect.position.y)
	var saved_boarding: Dictionary=final.local_checkpoint.boarding.duplicate(true)
	var saved_fleet: Array=final.local_checkpoint.fleet_assaults.duplicate(true)
	final.boarding.enemies[0].hp=1
	final.boarding.enemies[0].position.x+=80
	final.balance=25
	final._fail("boarding checkpoint test")
	final.retry_checkpoint()
	check(final.boarding.snapshot()==saved_boarding and final.balance==100,"Retry restores all boarders and player endurance from the combat checkpoint")
	check(final.fleet_assaults==saved_fleet,"Retry restores in-flight divine assaults")
	var fighter:=Pilot.new()
	for frame in 60*90:
		if final.boarding.cleared or not final.active(): break
		var controls: Dictionary=fighter.controls(final)
		final.set_combat_input(controls.get("attack",false),controls.get("guard",false))
		final.tick(1.0/60,controls.move,controls.duck,controls.jump,controls.held,controls.interact)
	check(final.boarding.cleared and final.boarding.kills==3,"Actual combat inputs can defeat the three boarders while Poseidon attacks")
	check(not final.mast_broken and final.sunk_at[10]<0 and not final.platforms[final.final_middle].gone,"Captain ship remains intact after the entire fight")
	check(final.boarding.player_attack_age<0,"Victory releases the last sword pose instead of freezing the player mid-swing")
	final.position=Vector2(final.final_origin+700,470)
	final.grounded=true
	final.balance=1
	final._save_checkpoint()
	final._fail("Low-endurance victory checkpoint fixture")
	final.retry_checkpoint()
	var before_births:=final.chart_events.filter(func(event): return str(event.kind) in ["low","high","slam"]).size()
	for frame in 360: final.tick(1.0/60)
	check(final.active() and final.balance==1,"Winning with one endurance point leaves a viable checkpoint for reaching the bag")
	check(final.chart_events.filter(func(event): return str(event.kind) in ["low","high","slam"]).size()==before_births,"Poseidon creates no new attacks after the boarding battle is won")
	final.position=final.bag_point
	final.grounded=true
	final.hit_stun=0
	final._final_interaction(0.4,true)
	check(final.has_bag and final.encounter_state=="return","Defeating boarders unlocks the actual bag interaction")
	check(not final.mast_broken and not final.platforms[final.final_middle].gone,"Picking up the bag cannot fracture the captain ship")
	check(final.bindings_done()==3 and final.binding_points.is_empty(),"No mandatory three-binding task")
	check(not final.record().escaped,"Bag pickup alone never records escape")
	for i in 300:
		if final.fleet_remaining()==1: break
		final.tick(0.2)
	check(final.fleet_remaining()==1 and final.background_sunk_at>=0,"Divine assaults remove every other vessel, including the distant extra ship")
	final.position=final.exit_point
	final.grounded=true
	final.hit_stun=0
	final._final_interaction(0.8,true)
	check(final.phase==final.Phase.ESCAPING,"Release at stern begins escape")
	for i in 100: final.tick(0.2)
	check(final.phase==final.Phase.COMPLETE and final.record().escaped,"Completion emitted after instrumental escape")
	check(final.completion_count==1,"Completion only once")
	check(final.wind_released,"Wind releases on the escape musical cue")
	check(final.record().captain_ship_intact and final.record().water_soldiers_defeated==3,"Final record reports surviving intact ship and defeated boarders")
	var directed:=Model.new()
	directed.start()
	directed.externally_directed_escape=true
	directed._change(directed.Phase.ESCAPING)
	for i in 100: directed.tick(0.2)
	check(directed.phase==directed.Phase.ESCAPING and not directed.wind_released and directed.phase_clock==0,"External escape waits for the actual musical phrase")
	directed.escape_score_age=directed.escape_release_at
	directed.tick(0.01)
	check(directed.wind_released and directed.phase!=directed.Phase.COMPLETE,"Wind cue occurs before final completion")
	directed.escape_score_age=directed.escape_duration
	directed.tick(0.01)
	check(directed.phase==directed.Phase.COMPLETE and directed.completion_count==1,"Completion follows external escape duration")
	var frozen:=Model.new()
	frozen.start()
	frozen._fail("fixture")
	var frozen_clock:=frozen.clock
	var frozen_position:=frozen.position
	for i in 90: frozen.tick(1.0/60,1,true,true,true,true)
	check(frozen.phase==frozen.Phase.FAILED and frozen.clock==frozen_clock and frozen.position==frozen_position,"Failure freezes simulation; no automatic recovery")
	for spam in [false,true]:
		var trivial:=Model.new()
		trivial.start()
		for frame in 60*180:
			if not trivial.active(): break
			trivial.tick(1.0/60,1,false,spam and frame%30==0,spam,false)
		print("TRIVIAL_INPUT spam=",spam," boat=",trivial.visited_boat," phase=",trivial.phase)
		check(trivial.visited_boat<10,"Running or repeating jump cannot traverse the fleet")
	var early_attack:=Model.new()
	early_attack.start()
	early_attack.set_combat_input(true,false)
	check(not early_attack.combat_attack,"Traversal cannot buffer a sword input until the final ship")
	var route:=Model.new()
	route.start()
	var pilot:=Pilot.new()
	var old_hits:=0
	for frame in 60*260:
		if not route.active() and route.phase!=route.Phase.ESCAPING: break
		var input: Dictionary=pilot.controls(route)
		route.set_combat_input(input.get("attack",false),input.get("guard",false))
		route.tick(1.0/60,input.move,input.duck,input.jump,input.held,input.interact)
		if route.hits!=old_hits:
			print("PILOT_HIT ",route.clock," pos=",route.position," low=",route.crouching," hazards=",route.hazards)
			old_hits=route.hits
		if frame%600==0: print("ROUTE ",snappedf(route.clock,0.1)," x=",snappedf(route.position.x,0.1)," boat=",route.visited_boat," state=",route.encounter_state," hits=",route.hits)
	print("ROUTE_RESULT ",JSON.stringify(route.record())," phase=",route.phase," reason=",route.failure_reason," position=",route.position," support=",route.support)
	check(route.phase==route.Phase.COMPLETE,"Input-only pilot can traverse authored route and return")
	print("CADENCE_CHECKS ",checks," FAILURES ",failures)
	quit(0 if failures==0 else 1)
