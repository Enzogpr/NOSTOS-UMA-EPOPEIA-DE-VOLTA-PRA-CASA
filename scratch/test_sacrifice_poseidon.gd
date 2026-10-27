extends SceneTree
const Model = preload("res://Ato4_Tempestade/Gameplay/PoseidonCadenceModel.gd")
var checks:=0
var failures:=0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)
func run() -> void:
	var gm: Node=root.get_node("GameManager")
	gm.persistence_enabled=false
	var original: PackedByteArray=FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH) if FileAccess.file_exists(gm.SAVE_FILE_PATH) else PackedByteArray()
	var model:=Model.new()
	model.apply_player_stats({"max_hp":10,"damage":3,"speed_mult":1.0,"dash_cooldown":3.0})
	check(model.balance==100 and model.max_balance==100 and model.level.physics.run_speed==305,"Base age20 keeps authored Poseidon movement and endurance")
	model.start()
	model.set_dash_input(true)
	model.tick(0.05)
	var remaining: float=model.dash_cooldown_remaining
	model._save_checkpoint()
	model.apply_player_stats({"max_hp":9,"damage":4,"speed_mult":1.68,"dash_cooldown":1.65})
	check(model.boarding.player_damage==4 and is_equal_approx(model.level.physics.run_speed,512.4),"Applying current campaign stats updates sword damage and running immediately")
	check(model.balance==90 and model.max_balance==90,"Sacrificed health lowers the actual phase endurance cap")
	check(is_equal_approx(model.dash_cooldown_remaining,remaining/3.0*1.65),"Changing dash recharge preserves its unfinished fraction")
	model._fail("Attribute checkpoint fixture")
	model.retry_checkpoint()
	check(model.boarding.player_damage==4 and model.max_balance==90 and model.balance<=90,"Retry cannot rewind permanent sacrifice benefits or health costs")
	check(is_equal_approx(model.level.physics.run_speed,512.4) and is_equal_approx(model.dash_cooldown_remaining,remaining/3.0*1.65),"Retry combines authored checkpoint cooldown progress with current attributes")
	model.balance=43
	model.apply_player_stats({"max_hp":7,"damage":13,"speed_mult":1.32,"dash_cooldown":1.75})
	check(model.balance==43 and model.max_balance==70,"Attribute refresh cannot refill a damaged endurance bar")
	gm.reset()
	for i in 9: gm.sacrifice_year()
	var scene: Control=load("res://Ato4_Tempestade/Gameplay/PoseidonEscape.tscn").instantiate()
	scene.audio_enabled=false
	scene.persist_record=false
	scene.manual_score_clock=true
	root.add_child(scene)
	current_scene=scene
	scene.set_physics_process(false)
	scene.score.set_process(false)
	scene.visuals.set_process(false)
	scene.ready_delay=0
	scene.begin()
	check(gm.player_age==29 and scene.model.boarding.player_damage==3,"Actual controller imports the existing campaign before gameplay")
	scene.model.dash_cooldown_remaining=scene.model.dash_cooldown_seconds*0.5
	gm.sacrifice_year()
	check(gm.player_age==30 and scene.model.boarding.player_damage==gm.player_damage and gm.player_damage==4,"TAB sacrifice signal updates the live controller without reloading")
	check(scene.model.max_balance==90 and scene.model.balance==90 and scene.balance_bar.max_value==90,"Live health cost updates collision encounter and HUD together")
	check(is_equal_approx(scene.model.level.physics.run_speed,305.0*gm.player_speed_mult),"Live controller now respects the campaign speed multiplier")
	check(is_equal_approx(scene.model.dash_cooldown_remaining,gm.player_dash_cooldown*0.5),"Live dash recharge retains half progress after sacrifice")
	scene.model._fail("Permanent sacrifice survives retry")
	scene.retry_checkpoint()
	check(scene.model.boarding.player_damage==4 and scene.model.max_balance==90 and gm.player_age==30,"Real controller checkpoint cannot refund sacrificed years")
	for i in 10: gm.sacrifice_year()
	check(gm.player_age==40 and is_equal_approx(scene.model.dash_cooldown_seconds,gm.player_dash_cooldown),"Older-age dash penalty applies in the same running scene")
	scene.model.position=Vector2(scene.model.final_origin+120,scene.model.boats[10].rect.position.y)
	scene.model._enter_boat(10)
	check(scene.model.balance==70 and scene.model.max_balance==70,"Entering final ship refills only the sacrificed maximum, not fixed100")
	scene.model._fail("Age40 checkpoint")
	gm.sacrifice_year()
	scene.retry_checkpoint()
	check(scene.model.balance<=60 and scene.model.max_balance==60,"Sacrificing while failed cannot restore an obsolete larger endurance cap")
	scene.stop_audio()
	scene.queue_free()
	await process_frame
	await process_frame
	check(original==(FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH) if FileAccess.file_exists(gm.SAVE_FILE_PATH) else PackedByteArray()),"Tests preserve the user's real campaign save")
	print("SACRIFICE_POSEIDON ",checks," CHECKS ",failures," FAILURES")
	quit(0 if failures==0 else 1)
