extends SceneTree
var checks:=0
var failures:=0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func key(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	var gm: Node=root.get_node("GameManager")
	gm.persistence_enabled=false
	var save_before: PackedByteArray=FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH) if FileAccess.file_exists(gm.SAVE_FILE_PATH) else PackedByteArray()
	gm.reset()
	var normal: CharacterBody2D=load("res://Scenes/ShipPlayer.tscn").instantiate()
	root.add_child(normal)
	normal.set_physics_process(false)
	check(is_equal_approx(normal.handling_speed_factor,1.0) and is_equal_approx(normal.handling_turn_factor,1.0),"Navigation baseline attributes preserve authored handling")
	check(normal.max_hull==100 and normal.current_hull==100,"Captain attributes do not replace ship hull")
	key(KEY_W,true)
	await physics_frame
	normal._physics_process(0.1)
	var baseline_speed: float=normal.current_speed
	check(is_equal_approx(baseline_speed,11.0),"Default navigation acceleration remains110")
	gm.sacrifice_year()
	check(normal.handling_speed_factor>1.0,"Sacrifice signal refreshes existing navigation ship immediately")
	normal.current_speed=0
	normal._physics_process(0.1)
	check(normal.current_speed>baseline_speed,"Agility actually accelerates navigation ship faster")
	var young_factor: float=normal.handling_speed_factor
	normal.apply_player_stats({"speed_mult":1.08,"intellect":5,"max_hp":1,"damage":99})
	check(is_equal_approx(normal.handling_speed_factor,young_factor) and normal.max_hull==100,"Repeated stats update does not compound handling or change hull")
	normal.apply_player_stats({"speed_mult":100.0,"intellect":100})
	check(is_equal_approx(normal.handling_speed_factor,1.3) and is_equal_approx(normal.handling_turn_factor,1.2),"Ship handling bonuses remain bounded")
	normal.apply_player_stats({"speed_mult":0.3,"intellect":5})
	check(is_equal_approx(normal.handling_speed_factor,0.7),"Old-age ship handling penalty remains playable")
	key(KEY_W,false)
	var storm: CharacterBody2D=load("res://Ato4_Tempestade/Gameplay/StormShip.tscn").instantiate()
	root.add_child(storm)
	storm.set_physics_process(false)
	storm.set_process(false)
	storm.scripted_helm=true
	storm.helm=Vector2(1,1)
	storm.sailing=true
	storm.weather_damage=0
	storm.apply_player_stats({"speed_mult":1.0,"intellect":5})
	storm._physics_process(0.1)
	check(is_equal_approx(storm.speed,14.0),"Default storm acceleration remains140")
	var base_turn: float=storm.rotation
	storm.speed=0
	storm.rotation=0
	storm.apply_player_stats({"speed_mult":1.44,"intellect":15})
	storm._physics_process(0.1)
	check(storm.speed>14.0 and storm.rotation>base_turn,"Agility and intellect actually improve storm throttle and helm")
	check(is_equal_approx(storm.hull,100.0) and is_equal_approx(storm.max_hull,100.0),"Storm hull remains independent of character vitality")
	gm.player_speed_mult=1.0
	gm.player_intellect=5
	gm.player_stats_changed.emit()
	check(is_equal_approx(storm.handling_speed_factor,1.0) and is_equal_approx(storm.handling_turn_factor,1.0),"Live stat signal restores storm baseline without compounding")
	var lotus: Control=load("res://Ato2_Lotofagos/Fase1_IlhaDosLotofagos.tscn").instantiate()
	root.add_child(lotus)
	lotus.set_process(false)
	lotus.set_process_unhandled_input(false)
	# Tiny connected corridor fixture: branches reveal bordering walls, not
	# passages behind solid jungle. The production movement and timer stay intact.
	lotus.map_width=7
	lotus.map_height=5
	lotus.map=[
		[1,1,1,1,1,1,1],
		[1,0,0,0,1,0,1],
		[1,1,1,0,1,0,1],
		[1,0,0,0,1,0,1],
		[1,1,1,1,1,1,1],
	]
	lotus.player_pos=Vector2i(1,1)
	lotus.explored.clear()
	lotus.apply_player_stats({"intellect":5})
	check(lotus.navigation_memory_radius==1 and lotus.explored.size()==5,"Default intellect preserves immediate cross-shaped map discovery")
	check(not lotus.explored.has(Vector2i(3,1)),"Default memory cannot reveal distant corridor cells")
	gm.player_intellect=7
	gm.player_stats_changed.emit()
	check(lotus.navigation_memory_radius==2 and lotus.explored.has(Vector2i(3,1)),"Live intellect gain expands remembered connected route")
	gm.player_intellect=30
	gm.player_stats_changed.emit()
	check(lotus.navigation_memory_radius==3 and lotus.explored.has(Vector2i(3,2)),"Memory radius is capped at three cells")
	check(not lotus.explored.has(Vector2i(5,1)),"Higher intellect never reveals through solid jungle")
	check(is_equal_approx(lotus.time_left,300.0),"Intellect does not extend the five-minute deadline")
	var before: Vector2i=lotus.player_pos
	lotus.player_dir=1
	lotus._move_forward()
	check(lotus.player_pos==before+Vector2i.RIGHT,"Discrete movement still advances one cell per command")
	normal.queue_free()
	storm.queue_free()
	lotus.queue_free()
	await process_frame
	await process_frame
	check(save_before==(FileAccess.get_file_as_bytes(gm.SAVE_FILE_PATH) if FileAccess.file_exists(gm.SAVE_FILE_PATH) else PackedByteArray()),"Travel audit never writes the real save")
	print("SACRIFICE_TRAVEL_LOTUS ",checks," CHECKS ",failures," FAILURES")
	quit(0 if failures==0 else 1)
