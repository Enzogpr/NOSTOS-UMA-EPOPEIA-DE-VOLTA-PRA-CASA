extends SceneTree
const MODEL:=preload("res://Ato5_Circe/Gameplay/CirceForestModel.gd")
const PROBE:=preload("res://scratch/CirceDevilProbe.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)
func set_age(model: RefCounted, id: String, value: float) -> void:
	for i in model.trickery.definitions.size():
		if model.trickery.definitions[i].id==id: model.trickery.ages[i]=value

func run() -> void:
	var gm: Node=root.get_node("GameManager")
	gm.persistence_enabled=false
	gm.reset()
	var original:=FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH) if FileAccess.file_exists(gm.SAVE_FILE_PATH) else PackedByteArray()
	var blind:=MODEL.new()
	check(not PROBE.drive(blind,false,90,false) and blind.phase==MODEL.Phase.FAILED and blind.trickery.is_fired("jump_teeth"),"The former platform-only approach is defeated by action-triggered teeth")
	var route:=MODEL.new()
	check(PROBE.drive(route,false),"Authored solution reaches the real flower with all trickery enabled")
	check(route.trickery.is_fired("false_flower") and route.trickery.is_fired("jump_column") and route.trickery.is_fired("last_bough"),"Successful traversal really clears the deception chains rather than disabling them")
	if route.phase!=MODEL.Phase.FAILED:
		check(route.interact()=="flower" and route.has_flower,"Only the real flower grants protection")
		check(PROBE.drive(route,true),"Authored return solves the changing final doorway")
		check(route.interact()=="complete","The real palace ends the search after all escape trials")
	var lure:=MODEL.new()
	lure.hermes_met=true
	lure.position=Vector2(5430,230)
	var collected: Array=[]
	lure.flower_collected.connect(func(): collected.append(true))
	check(lure.interact()=="mirage" and not lure.has_flower and collected.is_empty() and lure.phase==MODEL.Phase.SEARCH,"False flower never grants protection or emits the inventory acquisition event")
	var fired_count: int=lure.trickery.fired_ids.size()
	lure.interact()
	check(lure.trickery.fired_ids.size()==fired_count,"Repeated interaction cannot duplicate or restart a trap")
	lure.position=Vector2(6150,230)
	check(lure.interact()=="flower" and collected.size()==1 and lure.phase==MODEL.Phase.RETURN,"The true flower emits acquisition exactly once and starts the return")
	var floor:=MODEL.new()
	floor.position=Vector2(1940,540)
	floor.trickery.fire("false_rest",floor)
	var floor_index:=0
	for i in floor.surface_items.size():
		if float(floor.surface_items[i][0])==1990: floor_index=i
	floor.tick(0.12)
	check(floor.surface_rects[floor_index].has_area(),"False resting place briefly remains solid before its local collapse")
	floor.tick(0.16)
	check(not floor.surface_rects[floor_index].has_area() and floor.surface_position(floor_index).y>540,"Falling floor and collider use the same event state")
	var retreat:=MODEL.new()
	retreat.position=Vector2(1950,540)
	retreat.velocity.x=-100
	retreat.set_input(-1,false,false)
	retreat.tick(0.01)
	check(not retreat.trickery.is_fired("retreat_punished"),"Retreat trap cannot fire before the false resting place is activated")
	retreat.trickery.fire("false_rest",retreat)
	retreat.tick(0.01)
	check(retreat.trickery.is_fired("retreat_punished"),"Backing away from a discovered trap activates its authored follow-up")
	var high:=MODEL.new()
	high.position=Vector2(1260,540)
	high.trickery.fire("bridge_betrayal",high)
	set_age(high,"bridge_betrayal",0.5)
	high.tick(0.01)
	check(high.phase==MODEL.Phase.FAILED and high.hp==0,"A standing hero cannot tank the high thorn sweep")
	var low:=MODEL.new()
	low.position=Vector2(1260,540)
	low.trickery.fire("bridge_betrayal",low)
	set_age(low,"bridge_betrayal",0.5)
	low.set_input(0,false,false,true)
	low.tick(0.01)
	check(low.phase==MODEL.Phase.SEARCH and low.hp==10,"Crouching is a real geometric counter to the same sweep")
	var reaction:=MODEL.new()
	reaction.facing=1
	check(reaction.request_dash(-1) and reaction.velocity.x<0 and reaction.facing== -1,"A same-frame retreat dash follows the newly pressed direction instead of stale facing")
	var reset:=MODEL.new()
	reset.position=Vector2(1940,540)
	reset.checkpoint=3
	reset.checkpoint_position=reset.position
	reset.checkpoint_clock=4.0
	reset.checkpoint_dash_fraction=0.5
	reset.trickery.fire("false_rest",reset)
	reset.tick(0.4)
	reset._fail("verification")
	reset.apply_player_stats({"max_hp":7,"speed_mult":1.32,"dash_cooldown":2.0})
	reset.retry()
	check(reset.clock==4.0 and reset.position==Vector2(1940,540) and not reset.trickery.is_fired("false_rest"),"Retry reconstructs the safe checkpoint and clears lingering trap choreography")
	check(reset.max_hp==7 and reset.hp==7 and reset.speed_mult==1.32 and is_equal_approx(reset.dash_recharge,1.0),"Retry keeps permanent sacrifice costs and restores cooldown as a fraction of the current attribute")
	reset.trickery.fire("false_rest",reset)
	reset.tick(0.12)
	var first_state: Array=[reset.position,reset.clock,reset.trickery.hazards().duplicate(true),reset.surface_rects.duplicate()]
	reset._fail("same input replay")
	reset.retry()
	reset.trickery.fire("false_rest",reset)
	reset.tick(0.12)
	check(first_state==[reset.position,reset.clock,reset.trickery.hazards(),reset.surface_rects],"Same checkpoint and inputs reproduce identical geometry and trap timing")
	var door:=MODEL.new()
	door.resume_with_flower()
	door.position=Vector2(970,540)
	door.trickery.fire("last_door",door)
	door.tick(0.6)
	check(is_equal_approx(door.palace_position().x,665),"The final doorway physically recedes instead of completing at the old coordinates")
	door.position=Vector2(835,540)
	check(door.interact()!="complete","The old apparent exit cannot finish the trial")
	door.position=door.palace_position()
	check(door.interact()=="complete","Interaction follows the visible real doorway")
	root.size=Vector2i(1152,648)
	var scene: Control=load("res://Ato5_Circe/Gameplay/CirceForest.tscn").instantiate()
	scene.audio_enabled=false
	root.add_child(scene)
	current_scene=scene
	scene.set_physics_process(false)
	await process_frame
	scene.model.checkpoint_position=Vector2(1940,540)
	scene.model.checkpoint_clock=5.0
	scene.model.position=Vector2(2200,540)
	root.get_node("PauseMenu")._on_restart_pressed()
	check(scene.model.position==Vector2(1940,540) and scene.model.retries==1 and not paused,"Pause-menu restart uses the local trial rather than reloading the whole forest")
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://scratch/circe_preview")
		for shot in [["devil_lure",Vector2(5400,230),"",0.0],["devil_lure_break",Vector2(5520,230),"false_flower",0.5],["devil_column",Vector2(2860,488),"jump_column",0.3],["devil_sweep",Vector2(1260,540),"bridge_betrayal",0.5]]:
			scene.model.trickery.reset(false)
			scene.model.position=shot[1]
			scene.model.clock=3.5
			scene.model.hermes_met=true
			scene.model.crouching=shot[0]=="devil_sweep"
			if shot[2]!="":
				scene.model.trickery.fire(shot[2],scene.model)
				set_age(scene.model,shot[2],shot[3])
			scene.model._update_surfaces(0)
			scene.message_panel.hide()
			scene._update_ui()
			scene.visuals.reset_camera()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://scratch/circe_preview/%s.png" % shot[0])
	scene.queue_free()
	await process_frame
	check(original==(FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH) if FileAccess.file_exists(gm.SAVE_FILE_PATH) else PackedByteArray()),"Devil-stage verification never changes the player's real save")
	print("CIRCE_DEVIL ",checks," CHECKS ",failures," FAILURES")
	quit(0 if failures==0 else 1)
