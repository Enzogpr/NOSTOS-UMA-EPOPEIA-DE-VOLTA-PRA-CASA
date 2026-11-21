extends SceneTree
const MODEL := preload("res://Ato5_Circe/Gameplay/CirceForestModel.gd")
const MANAGER := preload("res://Code/GameManager.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func drive_route(m: RefCounted, direction: int, target: float, max_seconds := 150.0) -> bool:
	var next_surface := Rect2()
	var in_jump := false
	for step in int(max_seconds*120):
		if m.phase==MODEL.Phase.FAILED:
			print("Route failed at ",m.position," HP ",m.hp," time ",m.clock)
			return false
		if absf(m.position.x-target)<38 and m.grounded:
			m.set_input(0,false,false)
			return true
		var axis := float(direction)
		if not m.level.hazards.is_empty() and direction>0 and m.grounded and m.position.x>5200 and m.position.x>float(m.level.hazards.back().x)-115 and m.position.x<float(m.level.hazards.back().x)-30 and not m.has_flower:
			m.request_jump()
		if not m.has_flower and not m.memory_gate_open and m.position.x>2530 and m.position.x<2650 and m.grounded:
			m.set_input(0,false,true)
			m.tick(1.0/120)
			continue
		if m.memory_gate_open and m.gate_opening<0.99:
			m.set_input(0,false,true)
			m.tick(1.0/120)
			continue
		var duck:=false
		for branch: Array in m.level.low_branches:
			var test_body: Rect2=m._body()
			test_body.position.x+=direction*35
			if test_body.intersects(Rect2(branch[0],branch[1],branch[2],branch[3])): duck=true
		if m.has_flower:
			for i in m.tree_ages.size():
				var tree: Dictionary=m.level.return_trees[i]
				if direction<0 and m.position.x>float(tree.x)+45 and m.position.x<float(tree.x)+float(tree.trigger) and m.tree_ages[i]<float(tree.warning)+float(tree.fall)+0.15:
					axis=0
				if direction<0 and m.position.x>float(tree.x) and m.position.x<float(tree.x)+90 and m.grounded and m.tree_ages[i]>float(tree.warning)+float(tree.fall):
					m.request_jump()
		if m.grounded:
			in_jump=false
			var support := Rect2()
			for surface: Rect2 in m.surface_rects:
				if not surface.has_area(): continue
				if absf(m.position.y-surface.position.y)<1.0 and m.position.x>=surface.position.x-13 and m.position.x<=surface.end.x+13:
					if support.size.x==0 or (direction>0 and surface.end.x>support.end.x) or (direction<0 and surface.position.x<support.position.x): support=surface
			var best_distance := INF
			for surface: Rect2 in m.surface_rects:
				if not surface.has_area(): continue
				var si: int=m.surface_rects.find(surface)
				if m.speed_mult<0.6 and m.crumble_delay(float(m.surface_items[si][0]))>0: continue
				if surface==support: continue
				var ahead: bool = surface.position.x>support.position.x if direction>0 else surface.end.x<support.end.x
				if not ahead: continue
				var distance: float = surface.position.x-m.position.x if direction>0 else m.position.x-surface.end.x
				if distance<best_distance and distance>=-13:
					best_distance=distance
					next_surface=surface
			if support.size.x>0 and next_surface.size.x>0:
				var gap: float = next_surface.position.x-support.end.x if direction>0 else support.position.x-next_surface.end.x
				var edge_distance: float = support.end.x-m.position.x if direction>0 else m.position.x-support.position.x
				var rising: bool = next_surface.position.y<support.position.y-10
				var launch: bool = (rising and best_distance<80) or (gap>5 and edge_distance<48)
				if launch and not duck and axis!=0:
					if m.speed_mult<0.6 and gap>25 and m.dash_recharge>0: axis=0
					else:
						m.request_jump()
						in_jump=true
		if in_jump and not m.grounded and next_surface.size.x>0:
			var landing_margin:=24.0 if next_surface.position.x>=5200 else minf(100,next_surface.size.x*0.5)
			var landing: float = next_surface.position.x+landing_margin if direction>0 else next_surface.end.x-minf(100,next_surface.size.x*0.5)
			if (m.position.x-landing)*direction>0: axis=0
			if (m.speed_mult<0.6 or next_surface.position.x>=5200) and absf(landing-m.position.x)>110 and m.position.y<next_surface.position.y-5 and m.velocity.y<0: m.request_dash()
		m.set_input(axis,true,false,duck)
		m.tick(1.0/120)
	print("Route timed out at ",m.position," target ",target," next ",next_surface)
	return false

func run() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.persistence_enabled=false
	var original := FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH) if FileAccess.file_exists(gm.SAVE_FILE_PATH) else PackedByteArray()
	gm.reset()
	var m := MODEL.new(false)
	m.apply_player_stats({"max_hp":10})
	m.position=Vector2(835,540)
	check(m.interact()=="sealed" and m.phase==MODEL.Phase.SEARCH,"Palace cannot be entered before the flower; crew are not rescued")
	m.position=Vector2(440,540)
	check(m.interact()=="hermes" and m.hermes_met,"Hermes provides the search objective")
	m.position=Vector2(180,540)
	# Traverse the authored collision course with real movement, not teleports.
	var route := MODEL.new(false)
	route.apply_player_stats({"max_hp":10})
	check(drive_route(route,1,6150),"Baseline collision course remains traversable with the event director disabled")
	check(route.hermes_met,"Running past the prompt still receives Hermes's guidance")
	if route.phase!=MODEL.Phase.FAILED:
		check(route.interact()=="flower" and route.has_flower and route.phase==MODEL.Phase.RETURN,"Flower is collectible at the end of the actual traversal")
		check(drive_route(route,-1,835),"Protected return route reaches the original palace entrance")
		check(route.interact()=="complete" and route.phase==MODEL.Phase.COMPLETE,"Search ends at the palace, before battle and rescue")
	var old := MODEL.new(false)
	old.apply_player_stats({"max_hp":1,"speed_mult":0.3,"dash_cooldown":4.0})
	old.level.hazards=[]
	check(drive_route(old,1,6150,240),"Minimum campaign speed can cross the baseline geometry with dash")
	var sealed:=MODEL.new(false)
	sealed.hermes_met=true
	sealed.position=Vector2(2580,540)
	sealed.set_input(1,false,false)
	sealed.tick(0.8)
	check(sealed.position.x<=2636 and not sealed.memory_gate_open,"Running into the memory crossing cannot bypass observation")
	sealed.set_input(0,false,true)
	sealed.tick(1.3)
	check(sealed.memory_gate_open and sealed.gate_opening>0.99 and sealed.focus_remaining>3,"Observing unseals the crossing and reveals a timed memory route")
	sealed.set_input(0,false,false)
	sealed.tick(4.3)
	check(sealed.focus_remaining==0 and sealed.memory_gate_open,"Clarity expires without removing an occupied physical branch or relocking the entrance")
	var duck:=MODEL.new(false)
	duck.hermes_met=true
	duck.position=Vector2(1240,540)
	duck.set_input(1,false,false)
	duck.tick(0.6)
	check(duck.position.x<=1276,"Standing character collides with the low branch")
	duck.set_input(1,false,false,true)
	duck.tick(0.9)
	check(duck.position.x>1350 and duck.crouching,"Crouching changes the real hitbox and crosses the low passage")
	duck.set_input(0,false,false,false)
	duck.tick(0.05)
	check(duck.crouching,"Releasing crouch under a branch cannot force the hero into its collider")
	var wood:=MODEL.new(false)
	wood.level.hazards=[]
	wood.hermes_met=true
	var wood_index:=0
	for i in wood.surface_items.size():
		if float(wood.surface_items[i][0])==1010: wood_index=i
	wood.position=Vector2(1090,wood.surface_rects[wood_index].position.y)
	wood.support=wood_index
	wood.grounded=true
	wood.set_input(0,false,false)
	wood.tick(0.25)
	check(wood.crumble_ages.has(str(wood.surface_items[wood_index][0])) and wood.surface_rects[wood_index].has_area(),"Bark cracks while the moving root still supports the player")
	wood.tick(0.75)
	check(not wood.surface_rects[wood_index].has_area() and not wood.grounded,"A neglected cracked root really loses collision and drops")
	var carried:=MODEL.new(false)
	carried.level.hazards=[]
	carried.hermes_met=true
	var branch_index:=0
	for i in carried.surface_items.size():
		if float(carried.surface_items[i][0])==4700: branch_index=i
	carried.position=Vector2(4750,carried.surface_rects[branch_index].position.y)
	carried.support=branch_index
	carried.grounded=true
	carried.set_input(0,false,false)
	carried.tick(0.1)
	check(carried.grounded and absf(carried.position.y-carried.surface_rects[branch_index].position.y)<0.01,"Moving bough carries feet using the same surface rendered on screen")
	var tree_test:=MODEL.new(false)
	tree_test.apply_player_stats({"max_hp":10})
	tree_test.resume_with_flower()
	tree_test.position=Vector2(3910,520)
	tree_test.tree_ages[0]=1.45
	tree_test.set_input(0,false,false)
	tree_test.tick(0.1)
	check(tree_test.hp<10 and tree_test.has_flower,"Falling wood still hurts the protected hero; moly only stops spells")
	var retry_tree:=MODEL.new(false)
	retry_tree.resume_with_flower()
	retry_tree.position=Vector2(4160,540)
	retry_tree.tick(0.01)
	check(retry_tree.checkpoint==3,"Return traversal acquires nearby safe checkpoints instead of resetting the whole return")
	retry_tree._fail("return retry")
	retry_tree.retry()
	check(retry_tree.position==Vector2(4160,540) and retry_tree.has_flower and retry_tree.tree_ages[0]<0,"Return retry resets physical choreography and retains permanent protection")
	var magic := MODEL.new(false)
	magic.apply_player_stats({"max_hp":10})
	magic.hermes_met=true
	var hazard: Dictionary = magic.level.hazards[0]
	magic.position=Vector2(hazard.x+20,hazard.y)
	magic.clock=float(hazard.period)*0.30-float(hazard.offset)
	magic.set_input(0,false,false)
	magic.tick(0.01)
	check(magic.hp==8,"Active enchantment deals real health damage before protection")
	magic.resume_with_flower()
	magic.position=Vector2(hazard.x+20,hazard.y)
	magic.invulnerable=0
	magic.clock=float(hazard.period)*0.30-float(hazard.offset)
	magic.tick(0.01)
	check(magic.hp==8,"Moly blocks enchantments automatically without healing the previous hit")
	magic._fail("checkpoint test")
	magic.apply_player_stats({"max_hp":7,"speed_mult":1.32,"dash_cooldown":1.75})
	magic.retry()
	check(magic.has_flower and magic.hp==7 and magic.max_hp==7 and magic.speed_mult==1.32,"Retry preserves flower and current permanent sacrifice costs")
	var focus := MODEL.new(false)
	focus.set_input(0,false,true)
	focus.tick(0.7)
	check(focus.focus_remaining>3 and focus.focus_remaining<5,"Observation reveals a short memory window without consuming an item")
	var first := MODEL.new(false)
	var second := MODEL.new(false)
	first.set_input(1,false,false)
	second.set_input(1,false,false)
	for i in 120: first.tick(1.0/120)
	for i in 30: second.tick(1.0/30)
	check(first.position.distance_to(second.position)<0.01,"Movement remains deterministic at 30 and 120 simulation steps")
	var save_path := "user://circe_verification_%d.json" % OS.get_process_id()
	var manager := MANAGER.new()
	manager.save_file_path=save_path
	manager.player_age=37
	manager.player_damage=11
	manager.collect_circe_moly()
	manager.collect_circe_moly()
	manager.complete_circe_search()
	var restored := MANAGER.new()
	restored.save_file_path=save_path
	check(restored.load_game() and restored.circe_moly_found and restored.circe_search_completed,"Flower and palace milestone survive a fresh manager loading the save")
	check(restored.player_age==37 and restored.player_damage==11 and restored.inventory.size()==1,"Quest persistence preserves attributes and never duplicates the flower")
	restored.reset()
	check(not restored.circe_moly_found and not restored.circe_search_completed and restored.inventory.is_empty(),"New campaign clears Circe quest progress")
	manager.free()
	restored.free()
	DirAccess.remove_absolute(save_path)
	gm.reset()
	root.size=Vector2i(1152,648)
	var scene: Control=load("res://Ato5_Circe/Gameplay/CirceForest.tscn").instantiate()
	scene.audio_enabled=false
	root.add_child(scene)
	current_scene=scene
	scene.set_physics_process(false)
	await process_frame
	check(scene.model.max_hp==10 and scene.visuals.actor.texture!=null,"Full scene mounts with existing Odisseu sprites and campaign attributes")
	scene.model.dash_recharge=1.5
	gm.sacrifice_year()
	check(scene.model.speed_mult==gm.player_speed_mult and is_equal_approx(scene.model.dash_recharge,gm.player_dash_cooldown*0.5),"Live sacrifice changes movement and preserves remaining dash fraction")
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://scratch/circe_preview")
		for shot in [["entrance",Vector2(610,540)],["ruins",Vector2(2030,540)],["illusions",Vector2(3120,420)],["flower",Vector2(5480,230)],["revealed",Vector2(3120,420)]]:
			scene.model.position=shot[1]
			scene.model.clock=3.6
			scene.message_time=0
			scene.message_panel.hide()
			scene.model.hermes_met=true
			scene.model.focus_remaining=3.8 if shot[0]=="revealed" else 0.0
			scene._update_ui()
			scene.visuals.reset_camera()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://scratch/circe_preview/%s.png" % shot[0])
			if shot[0]=="illusions":
				var saved_camera: Vector2=scene.visuals.camera
				scene.model.clock+=0.7
				scene.visuals.update_visuals(0.7)
				scene.visuals.camera=saved_camera
				scene.visuals.update_visuals(0)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://scratch/circe_preview/illusions_motion.png")
	scene.queue_free()
	await process_frame
	current_scene=null
	gm.collect_circe_moly()
	var music_player: AudioStreamPlayer=root.get_node("AudioManager").music_player
	var previous_paused: bool=music_player.stream_paused
	var previous_stream: AudioStream=music_player.stream
	var previous_playing: bool=music_player.playing
	var previous_volume: float=music_player.volume_db
	music_player.stream=load("res://Assets/act5_circe/forest_ambience.wav")
	music_player.volume_db=-80
	music_player.play()
	var resumed: Control=load("res://Ato5_Circe/Gameplay/CirceForest.tscn").instantiate()
	root.add_child(resumed)
	current_scene=resumed
	resumed.set_physics_process(false)
	await process_frame
	check(resumed.model.has_flower and resumed.model.phase==MODEL.Phase.RETURN and resumed.model.position==resumed.model.checkpoint_position,"Reentering after collection resumes the return beside the permanent flower checkpoint")
	check(resumed.ambience.stream!=null and root.get_node("AudioManager").music_player.stream_paused,"Forest ambience replaces the previous music while the stage is active")
	if "--capture" in OS.get_cmdline_user_args():
		resumed.model.position=Vector2(760,540)
		resumed.visuals.return_glow=1
		resumed.message_panel.hide()
		resumed.visuals.reset_camera()
		resumed._update_ui()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://scratch/circe_preview/return.png")
	resumed.queue_free()
	await process_frame
	check(root.get_node("AudioManager").music_player.stream_paused==previous_paused,"Leaving the forest restores the prior music pause state")
	music_player.stop()
	music_player.stream=previous_stream
	music_player.volume_db=previous_volume
	if previous_playing: music_player.play()
	music_player.stream_paused=previous_paused
	gm.complete_circe_search()
	var replayed: Control=load("res://Ato5_Circe/Gameplay/CirceForest.tscn").instantiate()
	replayed.audio_enabled=false
	root.add_child(replayed)
	current_scene=replayed
	replayed.set_physics_process(false)
	await process_frame
	check(replayed.model.phase==MODEL.Phase.SEARCH and not replayed.model.has_flower and gm.circe_moly_found and gm.circe_search_completed and gm.has_item("holimoli"),"Replaying a completed chapter restores its full challenge without erasing permanent inventory or progress")
	var offers_drawing := false
	for button in replayed.find_children("*","Button",true,false):
		if button.text.contains("IMAGINAÇÃO") or button.text.contains("DESENHO"): offers_drawing=true
	check(not offers_drawing and not replayed.has_method("open_manifestation_workshop"),"forest and its result no longer offer drawing before Circe's battle")
	replayed.queue_free()
	await process_frame
	gm.reset()
	var map: Control=load("res://Scenes/WorldMap.tscn").instantiate()
	root.add_child(map)
	current_scene=map
	await process_frame
	check(map.stops.size()==19 and not map.stops[7].is_unlocked() and not map.stops[8].is_unlocked(),"Map includes Circe search and battle, locked before their prerequisites")
	gm.complete_act4()
	check(map.stops[7].is_unlocked() and not map.stops[7].is_completed(),"Only completed Poseidon aftermath unlocks the flower search")
	gm.collect_circe_moly()
	check(not map.stops[7].is_completed(),"Picking the flower alone does not mark return to palace complete")
	gm.complete_circe_search()
	check(map.stops[7].is_completed() and map.stops[8].is_unlocked() and not map.stops[8].is_completed() and map.progress_label.text.begins_with("8 / 19"),"Returning to palace completes the search and unlocks the separate Circe confrontation")
	if "--capture" in OS.get_cmdline_user_args():
		map.player.snap_to(map.stops[7])
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://scratch/circe_preview/map.png")
	map.queue_free()
	await process_frame
	check(original==(FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH) if FileAccess.file_exists(gm.SAVE_FILE_PATH) else PackedByteArray()),"All verification leaves the player's real save unchanged")
	print("CIRCE_FOREST ",checks," CHECKS ",failures," FAILURES")
	quit(0 if failures==0 else 1)
