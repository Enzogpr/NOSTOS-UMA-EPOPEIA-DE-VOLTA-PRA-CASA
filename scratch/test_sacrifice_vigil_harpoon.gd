extends Node
const Vigil := preload("res://Ato4_Tempestade/Gameplay/VigilModel.gd")
const Harpoon := preload("res://Ato4_Tempestade/Gameplay/AeoliaHarpoon.gd")
var checks:=0
var failures:=0

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func optimal(v: Vigil) -> void:
	if v.is_sleepy(): v.wake()
	if v.is_sleepy() or v.shout_cooldown>0: return
	var chosen: Dictionary={}
	for visitor in v.crew:
		if not visitor.retreating and float(visitor.progress)>0.19:
			if chosen.is_empty() or float(visitor.progress)>float(chosen.progress): chosen=visitor
	if not chosen.is_empty():
		v.look(int(chosen.side))
		v.warn_crew()

func _ready() -> void:
	set_meta("hide_main_hud",true)
	await get_tree().process_frame
	var save_path: String=GameManager.SAVE_FILE_PATH
	var save_before:=FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()
	var original_speed: float=GameManager.player_speed_mult
	var original_hp: int=GameManager.player_max_hp
	var original_intellect: int=GameManager.player_intellect
	var original_combat: bool=GameManager.combat_mode
	var v:=Vigil.new(731)
	v.apply_player_stats({"max_hp":10,"intellect":5})
	check(v.fatigue_stat_factor==1.0 and is_equal_approx(v.fatigue_rate(),3.2),"Default age20 preserves the authored fatigue rate exactly")
	v.fatigue=63
	v.wake_cooldown=0.4
	v.shout_cooldown=0.5
	v.apply_player_stats({"max_hp":7,"intellect":11})
	check(v.fatigue==63 and v.wake_cooldown==0.4 and v.shout_cooldown==0.5,"Live attributes never wake Odysseus or reset cooldowns")
	check(v.fatigue_stat_factor<1,"Wisdom can outweigh a modest vitality loss")
	v.apply_player_stats({"max_hp":1,"intellect":5})
	check(is_equal_approx(v.fatigue_stat_factor,1.35),"Vitality penalty is bounded at35percent")
	v.apply_player_stats({"max_hp":10,"intellect":999})
	check(is_equal_approx(v.fatigue_stat_factor,0.8),"Concentration benefit is bounded at20percent")
	for stats in [{"max_hp":10,"intellect":5},{"max_hp":10,"intellect":999},{"max_hp":1,"intellect":5}]:
		var run:=Vigil.new(732)
		run.apply_player_stats(stats)
		run.start()
		for frame in 120*280:
			optimal(run)
			run.tick(1.0/120)
			if run.state in [Vigil.State.FAILED,Vigil.State.ENDING]: break
		check(run.state==Vigil.State.ENDING and run.day==9 and run.days_completed==8,"Responsive play reaches day9 but cannot defeat its authored inevitable loss")
		check(run.day_clock<run.day_duration and run.bag_sealed,"The real day9 mechanics overwhelm input before timeout without showing an opener")
	var early:=Vigil.new(733)
	early.apply_player_stats({"max_hp":10,"intellect":999})
	early.start()
	early.fatigue=99.99
	early.tick(0.1)
	check(early.state==Vigil.State.FAILED and not early.wake(),"Even maximum concentration cannot auto-rescue an early loss")
	var h: Control=preload("res://Ato4_Tempestade/Gameplay/AeoliaHarpoon.tscn").instantiate()
	h.transition_enabled=false
	h.play_climb_dialogue=false
	GameManager.player_speed_mult=1.0
	GameManager.player_intellect=5
	get_tree().root.add_child(h)
	h.set_physics_process(false)
	h.get_node("ShotSound").volume_db=-80
	check(h.effective_charge_seconds()==1.25 and h.wind_stat_factor==1.0,"Default harpoon charge and wind are unchanged")
	h.begin()
	h.start_charge()
	h._physics_process(0.25)
	check(is_equal_approx(h.charge,0.2),"Default charge gains20percent in0.25seconds")
	h.apply_player_stats({"speed_mult":1.44,"intellect":11})
	check(is_equal_approx(h.effective_charge_seconds(),1.25/1.2) and is_equal_approx(h.wind_stat_factor,0.85),"Agility speeds charging and wisdom reduces wind only modestly")
	h.apply_player_stats({"speed_mult":1.44,"intellect":11})
	check(h.charge_seconds==1.25 and is_equal_approx(h.effective_charge_seconds(),1.25/1.2),"Applying stats repeatedly cannot compound exported baselines")
	var charge_before: float=h.charge
	h._physics_process(0.25)
	check(is_equal_approx(h.charge-charge_before,0.24),"Charge progression uses the effective agility value")
	h.wind=20
	h.release_shot()
	check(is_equal_approx(h.shot_wind,17),"Launched trajectory uses the reduced wind read by its preview")
	h.apply_player_stats({"speed_mult":0.3,"intellect":999})
	check(h.effective_charge_seconds()>1.25 and h.wind_stat_factor==0.75,"Old-age speed penalty slows charge and wisdom wind reduction is capped")
	check(h.shot_wind==17,"Changing stats cannot bend an already launched projectile")
	var radius: float=h.anchor_shape.shape.radius
	GameManager.player_speed_mult=1.69
	GameManager.player_intellect=9
	GameManager.player_stats_changed.emit()
	check(is_equal_approx(h.charge_stat_factor,1.3) and is_equal_approx(h.wind_stat_factor,0.9),"Harpoon controller receives live campaign attribute changes")
	check(h.anchor_shape.shape.radius==radius,"Attributes do not inflate the target collider or create automatic hits")
	h.get_node("ShotSound").stop()
	h.get_node("ShotSound").stream=null
	h.queue_free()
	var scene: Control=preload("res://Ato4_Tempestade/Gameplay/NineDaysVigil.tscn").instantiate()
	scene.persist_record=false
	scene.audio_enabled=false
	scene.continue_to_poseidon=false
	get_tree().root.add_child(scene)
	scene.set_physics_process(false)
	scene.set_process(false)
	GameManager.player_max_hp=7
	GameManager.player_intellect=11
	scene.model.fatigue=55
	GameManager.player_stats_changed.emit()
	check(is_equal_approx(scene.model.fatigue_stat_factor,pow(10.0/7.0,0.2)*0.85) and scene.model.fatigue==55,"Vigil controller updates concentration and vitality without clearing fatigue")
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.player_speed_mult=original_speed
	GameManager.player_max_hp=original_hp
	GameManager.player_intellect=original_intellect
	GameManager.combat_mode=original_combat
	GameManager.player_stats_changed.emit()
	check(save_before==(FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()),"The integration audit never writes the player's real save")
	print("SACRIFICE_VIGIL_HARPOON ",checks," CHECKS ",failures," FAILURES")
	get_tree().quit(0 if failures==0 else 1)
