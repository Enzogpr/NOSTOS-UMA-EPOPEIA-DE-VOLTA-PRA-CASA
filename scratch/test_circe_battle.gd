extends SceneTree
const MODEL := preload("res://Ato5_Circe/Gameplay/CirceBattleModel.gd")
const PROBE := preload("res://scratch/CirceBattleProbe.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
	else: print("PASS ",label)
func advance(m: RefCounted,seconds: float) -> void:
	for i in ceili(seconds*120): m.tick(1.0/120)
func fresh(which := MODEL.Phase.DUEL) -> RefCounted:
	var result := MODEL.new(); result.begin()
	if which!=MODEL.Phase.DUEL: result._enter_phase(which)
	result.boss_age=-1000
	return result
func path_exists(m: RefCounted,destination: Vector2) -> bool:
	var origin := Vector2(111,234)
	var start := Vector2i(8,15)
	var queue: Array[Vector2i]=[start]
	var visited := {start:true}
	var cursor := 0
	while cursor<queue.size():
		var cell := queue[cursor]; cursor+=1
		var point := origin+Vector2(cell)*16
		if point.distance_to(destination)<25: return true
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+offset
			var at := origin+Vector2(next)*16
			if not visited.has(next) and m.walkable(at) and not m.palace.pit_at(at,13):
				visited[next]=true; queue.append(next)
	return false
func run() -> void:
	var gm: Node=root.get_node("GameManager"); gm.persistence_enabled=false
	var original := FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH) if FileAccess.file_exists(gm.SAVE_FILE_PATH) else PackedByteArray()
	var m := MODEL.new(); m.begin()
	var last := m.phase
	for i in 40000:
		if not m.active(): break
		PROBE.drive(m,1.0/120)
		if m.phase!=last:
			print("PHASE ",m.phase," t=",m.clock," hp=",m.hp," boss=",m.boss_hp," position=",m.position); last=m.phase
	print("ROUTE phase=",m.phase," hp=",m.hp," boss=",m.boss_hp," t=",m.clock," traps=",m.palace.events.size())
	check(m.phase==MODEL.Phase.WON,"three offline phases are winnable with base attributes and actual movement/sword inputs")
	var palace_events: Array = m.palace.events.map(func(event: Dictionary) -> String: return event.id)
	check("west_column" in palace_events and "east_column" in palace_events and m.protected_spells>0,"complete route includes automatic protection and both column events")
	var directions := [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]
	var moves := true
	for direction in directions:
		var actor := fresh(); actor.position=Vector2(625,405); var before: Vector2=actor.position
		actor.set_input(direction,direction,false,false); advance(actor,0.2)
		if (actor.position-before).dot(direction)<20: moves=false
	check(moves,"WASD-style inputs move in all four ground directions")
	var diagonal := fresh(); diagonal.position=Vector2(625,405); diagonal.set_input(Vector2(1,1),Vector2.RIGHT,false,false); advance(diagonal,0.2)
	var straight := fresh(); straight.position=Vector2(625,405); straight.set_input(Vector2.RIGHT,Vector2.RIGHT,false,false); advance(straight,0.2)
	check(diagonal.position.distance_to(Vector2(625,405))<=straight.position.distance_to(Vector2(625,405))+0.1,"diagonal movement is normalized and gives no speed exploit")
	var aged := fresh(); aged.apply_player_stats({"max_hp":4,"current_hp":2,"damage":9,"speed_mult":0.5,"dash_cooldown":4.2,"intellect":15})
	check(aged.hp==2 and aged.max_hp==4 and aged.damage==9 and aged.speed_mult==0.5,"entry preserves sacrificed health, current wounds, damage and movement")
	aged.request_dash(); check(is_equal_approx(aged.dash_recharge,4.2),"dash uses the campaign cooldown")
	var safe := fresh(); safe.apply_player_stats({"max_hp":4,"current_hp":2}); safe.attack_kind="enchant"; safe._resolve_attack()
	check(safe.hp==2 and safe.flower_flash>0 and safe.protected_spells==1,"flower blocks enchantments automatically without defense, E or a network request")
	safe.guarding=true; safe.tables=[{"p":safe.position-Vector2(30,0),"v":Vector2(430,0),"age":0.0,"angle":0.0}]; advance(safe,0.02)
	check(safe.hp==0,"flower never makes Odisseu immune to physical furniture")
	var dodge := fresh(); dodge.set_input(Vector2.DOWN,Vector2.RIGHT,false,false); dodge.request_dash()
	dodge.tables=[{"p":dodge.position-Vector2(15,0),"v":Vector2(430,0),"age":0.0,"angle":0.0}]; advance(dodge,0.05)
	check(dodge.hp==10 and is_equal_approx(dodge.position.y,440.0),"a directional dash crosses a physical attack safely")
	dodge.set_input(Vector2.ZERO,Vector2.RIGHT,false,false)
	advance(dodge,0.28)
	check(is_equal_approx(dodge.position.y,500.0) and dodge.velocity==Vector2.ZERO,"dash covers 80 pixels and stops without residual movement")
	var charge := fresh()
	charge.request_dash()
	advance(charge,1.5)
	charge.apply_player_stats({"dash_cooldown":4.0})
	check(is_equal_approx(charge.dash_recharge,2.0),"changing cooldown preserves the progress shown on the dash meter")
	var root_case := fresh(); root_case.roots=[{"p":root_case.position,"age":0.0,"hit":false}]; advance(root_case,0.5)
	check(root_case.hp==10,"roots have a readable formation period before damage")
	advance(root_case,0.5); check(root_case.hp==9,"remaining on a grown root causes physical damage")
	var escape := fresh(); escape.roots=[{"p":escape.position,"age":0.0,"hit":false}]; escape.set_input(Vector2.UP,Vector2.UP,false,false); advance(escape,1)
	check(escape.hp==10,"moving upward escapes roots, not just left/right movement")
	var sword := fresh(); sword.position=sword.boss_position-Vector2(103,0); sword.set_input(Vector2.ZERO,Vector2.RIGHT,false,false)
	sword.damage = 9
	sword.attack_kind = "roots"
	sword._begin_windup()
	var before_hit: Vector2 = sword.boss_position
	sword.request_attack()
	# Both attacks would resolve on the next tick. The sword should take priority.
	sword.attack_age = 0.095
	sword.boss_age = 0.699
	sword.tick(1.0/120.0)
	check(sword.boss_hp==int(sword.tuning.boss_hp)-9,"the sword uses saved damage while Circe is preparing an attack")
	check(sword.boss_position.distance_to(before_hit)>=130 and sword.walkable(sword.boss_position) and sword.boss_state=="windup","a landed hit teleports Circe and starts a counterattack")
	check(sword.roots.is_empty(),"the sword cancels the root attack due on the same tick")
	check(sword.tables.is_empty() and sword.attack_origin==sword.boss_position,"the counterattack prepares from Circe's new position")
	advance(sword,0.71)
	check(sword.attack_kind=="table" and sword.tables.size()==1 and sword.roots.is_empty() and sword.boss_state=="recovery","only the counterattack fires after the new windup")
	var threshold := fresh()
	threshold.boss_hp=int(threshold.tuning.mirror_threshold)+1
	threshold.position=threshold.boss_position-Vector2(70,0)
	threshold.set_input(Vector2.ZERO,Vector2.RIGHT,false,false)
	threshold.boss_state="recovery"; threshold.boss_recovery=99
	threshold.request_attack(); advance(threshold,0.2)
	check(threshold.phase==MODEL.Phase.MIRRORS and threshold.boss_state=="windup" and threshold.counter_index==1,"a hit that changes phase still starts the counterattack")
	var moving := fresh(MODEL.Phase.MIRRORS)
	var start_at: Vector2 = moving.boss_position
	var copy_at: Vector2 = moving.clone_positions[0]
	moving.boss_age = 0.45
	advance(moving,0.35)
	check(moving.boss_state=="reposition" and moving.boss_position.distance_to(start_at)>35 and moving.clone_positions[0].distance_to(copy_at)>25,"Circe and her copies move between attacks")
	advance(moving,0.13)
	var cast_at: Vector2 = moving.boss_position
	advance(moving,0.20)
	check(moving.boss_state=="windup" and moving.boss_position==cast_at,"Circe plants her feet while preparing the cast")
	var wrong := fresh(MODEL.Phase.MIRRORS); wrong.boss_hp=int(wrong.tuning.mirror_threshold); wrong.position=wrong.mirror_spots[0]+Vector2(0,65)
	wrong.set_input(Vector2.ZERO,Vector2.UP,false,false); wrong.request_attack(); advance(wrong,0.2)
	check(wrong.boss_hp==int(wrong.tuning.mirror_threshold) and wrong.illusion_hits==1 and wrong.attack_recharge>0,"attacking a copy wastes the sword opportunity and never damages Circe")
	var observe := fresh(MODEL.Phase.MIRRORS); var at: Vector2=observe.position
	observe.set_input(Vector2.UP,Vector2.RIGHT,false,true); advance(observe,0.35)
	check(observe.position==at and observe.reveal_time==0,"holding E locks both movement axes and requires charging")
	observe.set_input(Vector2.UP,Vector2.RIGHT,false,false); advance(observe,0.1)
	check(observe.observe_progress==0 and observe.reveal_time==0 and observe.position.y<at.y,"releasing E cancels an incomplete reveal and restores movement")
	observe.set_input(Vector2.UP,Vector2.RIGHT,false,true); advance(observe,0.8)
	check(observe.reveal_time>0 and observe.focus<85,"a completed hold reveals the true caster and consumes clarity")
	var clever := fresh(MODEL.Phase.MIRRORS); clever.intellect=15; clever.set_input(Vector2.ZERO,Vector2.RIGHT,false,true); advance(clever,0.62)
	check(clever.reveal_time>2.5,"intellect speeds observation and extends its duration")
	var room := fresh(MODEL.Phase.PALACE)
	check(room.palace.events.size()==1,"final phase begins with only its entry event")
	room.palace.notify("dash",Vector2(245,420)); room.palace.notify("hit",Vector2.ZERO); room.palace.notify("hit",Vector2.ZERO)
	room.palace.tick(1.6,Vector2(700,400),13)
	check(room.palace.events.size()==4 and room.palace.solids().size()==3,"dash, crossing and landed hits trigger the fixed floor/column/gate sequence")
	check(not room.walkable(Vector2(420,342)) and room.palace.pit_at(Vector2(245,420)),"changed floor and fallen columns affect real gameplay, not just artwork")
	var connected := true
	for spot in room.mirror_spots: connected=connected and path_exists(room,spot)
	check(connected,"all boss positions remain reachable after every obstruction has activated")
	var gate_room := fresh(MODEL.Phase.PALACE); gate_room.palace.arm(Vector2(400,400))
	gate_room.palace.tick(2,Vector2(610,315),13)
	var gate_open := false
	for event in gate_room.palace.events:
		if event.kind=="gate": gate_open=event.progress<1
	check(gate_open,"closing gate waits for an occupying player and cannot crush/pin them")
	gate_room.palace.tick(1,Vector2(700,400),13)
	check(gate_room.palace.solids().size()==2,"gate completes its closure after the passage is clear")
	room.apply_player_stats({"max_hp":4,"current_hp":1,"damage":9})
	room.boss_hp = 3
	room._hurt(1,room.position)
	room.retry()
	check(room.phase==MODEL.Phase.DUEL and room.boss_hp==int(room.tuning.boss_hp) and room.hp==4 and room.damage==9 and room.palace.events.is_empty(),"retry after defeat restarts the first phase and clears the palace hazards while preserving stats")
	var dead := MODEL.new(); dead.apply_player_stats({"current_hp":0,"max_hp":4}); dead.begin()
	check(dead.phase==MODEL.Phase.FAILED and dead.hp==0,"entry never heals or revives Odisseu automatically")
	# Actual scene input, campaign gate, completion, map and isolated persistence.
	gm.reset()
	var locked: Control=load("res://Ato5_Circe/Gameplay/CirceBattle.tscn").instantiate(); locked.audio_enabled=false
	root.add_child(locked); await process_frame; locked.begin()
	check(not locked.gate_open and locked.model.phase==MODEL.Phase.READY,"campaign requires the completed flower search")
	locked.queue_free(); await process_frame
	gm.complete_act4(); gm.collect_circe_moly(); gm.complete_circe_search()
	var scene: Control=load("res://Ato5_Circe/Gameplay/CirceBattle.tscn").instantiate(); scene.audio_enabled=false
	root.add_child(scene); current_scene=scene; await process_frame; scene.begin()
	var initial_y: float=scene.model.position.y
	var up := InputEventKey.new(); up.keycode=KEY_W; up.physical_keycode=KEY_W; up.pressed=true; Input.parse_input_event(up)
	Input.flush_buffered_events()
	for frame in 12: await physics_frame
	up.pressed=false; Input.parse_input_event(up)
	check(scene.model.position.y<initial_y-10,"real W input reaches the controller and moves upward")
	var motion := InputEventMouseMotion.new(); motion.position=Vector2(800,330); motion.global_position=motion.position
	Input.parse_input_event(motion); Input.flush_buffered_events(); await process_frame
	var click := InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=Vector2(800,330); click.global_position=click.position
	Input.parse_input_event(click); Input.flush_buffered_events(); await physics_frame
	check(scene.model.attack_recharge>0,"real mouse click attacks without being swallowed by fullscreen controls")
	var release := click.duplicate() as InputEventMouseButton; release.pressed=false; Input.parse_input_event(release)
	check(not scene.has_method("_mount_drawing") and scene.find_children("*","HTTPRequest",true,false).is_empty(),"battle has no creation screen, API client or network dependency")
	if "--capture" in OS.get_cmdline_user_args(): await capture(scene)
	scene.model._enter_phase(MODEL.Phase.MIRRORS)
	scene.model.boss_hp = 40
	scene.model._hurt(scene.model.hp,scene.model.position)
	var retry_button := scene.failure.find_children("*","Button",true,false)[0] as Button
	retry_button.pressed.emit()
	check(scene.model.phase==MODEL.Phase.DUEL and scene.model.boss_hp==80 and not scene.failure.visible,"the retry button restarts the whole fight without showing the intro again")
	scene.model._enter_phase(MODEL.Phase.PALACE); scene.model.boss_hp=3; scene.model.boss_state="recovery"; scene.model.boss_recovery=99
	scene.model.position=scene.model.boss_position-Vector2(70,0); scene.model.set_input(Vector2.ZERO,Vector2.RIGHT,false,false); scene.model.request_attack(); advance(scene.model,0.2)
	check(gm.circe_battle_completed and scene.result.visible,"actual victory records the existing battle milestone")
	scene.queue_free(); await process_frame
	var map: Control=load("res://Scenes/WorldMap.tscn").instantiate(); root.add_child(map); current_scene=map; await process_frame
	check(map.stops.size()==12 and map.DATA.chapter_completed(map.destination("aeaea").chapters[1]),"new battle retains the same map slot and saved progression")
	map.queue_free(); await process_frame
	check(original==(FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH) if FileAccess.file_exists(gm.SAVE_FILE_PATH) else PackedByteArray()),"test preserves the real campaign save")
	print("CIRCE_BATTLE ",checks," CHECKS ",failures," FAILURES")
	quit(0 if failures==0 else 1)

func capture(scene: Control) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scratch/circe_battle_preview"))
	root.size=Vector2i(1152,648); scene.size=Vector2(1152,648); scene._fit(); scene.set_physics_process(false); scene.notice.hide()
	scene.model.position=Vector2(540,430); scene.model.boss_position=Vector2(850,330); scene.model.boss_state="windup"; scene.model.attack_kind="table"; scene.model.boss_age=0.45
	scene.model.clock=4; scene._update_ui(); scene.visuals.update_visuals(0.1)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://scratch/circe_battle_preview/duel_4d.png")
	scene.model._enter_phase(MODEL.Phase.MIRRORS); scene.model.boss_hp=int(scene.model.tuning.mirror_threshold); scene.model.position=Vector2(540,430); scene.model.boss_state="windup"; scene.model.boss_age=0.4
	scene.model.clock=28; scene._update_ui(); scene.notice.hide()
	for i in 15: scene.visuals.update_visuals(0.02)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://scratch/circe_battle_preview/mirrors_4d.png")
	scene.model._enter_phase(MODEL.Phase.PALACE); scene.model.boss_hp=int(scene.model.tuning.palace_threshold)
	scene.model.palace.notify("dash",Vector2(380,455)); scene.model.palace.notify("hit",Vector2.ZERO); scene.model.palace.notify("hit",Vector2.ZERO)
	scene.model.palace.tick(2,Vector2(700,400),13)
	scene.model.position=Vector2(625,420); scene.model.clock=48; scene.model.roots=[{"p":Vector2(875,440),"age":1.0,"hit":false}]
	scene._update_ui(); scene.notice.hide(); scene.visuals.update_visuals(0.02)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://scratch/circe_battle_preview/palace_4d.png")
