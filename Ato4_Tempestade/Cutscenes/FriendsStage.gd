extends Node2D
## Two physical stages, a carried prop and cloud actors share one moving camera.
const RIG := preload("res://Ato4_Tempestade/Cutscenes/LuckStage.gd")
const TERRACE := preload("res://Assets/act4_friends/aeolia_terrace.png")
const DECK := preload("res://Assets/act4_luck/deck_luck.png")

var metadata: Dictionary
var camera: Node2D
var background: Sprite2D
var odysseus: RIG.Performer
var aeolus: RIG.Performer
var perimedes: RIG.Performer
var elpenor: RIG.Performer
var aeolus_anchor: Node2D
var winions: Array[RIG.Performer] = []
var bag: Sprite2D
var floor_effects: RIG.FloorEffects
var air_effects: RIG.AirEffects
var current_index: int = -1
var current_shot: String = "arrival"
var current_beat: Dictionary = {}
var phase: String = "palace"
var elapsed: float = 0.0
var shot_elapsed: float = 0.0
var privacy: float = 0.0
var speaking: bool = false
var zoom: float = 1.0
var focus := Vector2(576,310)
var motion_tween: Tween
var transition_progress: float = 1.0
var transitioning: bool = false
var destination: String = "palace"
var spirits: float = 0.0
var bag_owner: String = "aeolus"
var bag_sealed: bool = true
var ending: bool = false
var gesture_played: bool = false

func _ready() -> void:
	metadata = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_friends/regions.json"))
	camera = Node2D.new()
	camera.name = "CameraRig"
	add_child(camera)
	background = Sprite2D.new()
	camera.add_child(background)
	_set_background(TERRACE)
	floor_effects = RIG.FloorEffects.new()
	floor_effects.director = self
	camera.add_child(floor_effects)
	odysseus = _actor("odysseus_bag_poses",430)
	odysseus.position = Vector2(365,555)
	aeolus_anchor = Node2D.new()
	camera.add_child(aeolus_anchor)
	aeolus_anchor.position = Vector2(780,500)
	aeolus = _actor("aeolus_poses",390)
	aeolus.reparent(aeolus_anchor,false)
	perimedes = _actor("crew_poses",365)
	perimedes.position = Vector2(290,555)
	perimedes.pose(0)
	elpenor = _actor("crew_poses",350)
	elpenor.position = Vector2(515,555)
	elpenor.pose(2)
	perimedes.hide()
	elpenor.hide()
	bag = Sprite2D.new()
	bag.texture = load(metadata.wind_bag.texture)
	bag.region_enabled = true
	var rect: Array = metadata.wind_bag.regions[0]
	bag.region_rect = Rect2(rect[0],rect[1],rect[2],rect[3])
	bag.region_filter_clip_enabled = true
	bag.scale = Vector2.ONE*118.0/float(rect[3])
	bag.position = Vector2(665,318)
	bag.modulate.a = 0.0
	camera.add_child(bag)
	for i in 3:
		var spirit := _actor("winions_poses",115+i*8)
		spirit.pose(i%4)
		spirit.modulate.a = 0.0
		camera.move_child(spirit,2)
		winions.append(spirit)
	air_effects = RIG.AirEffects.new()
	air_effects.director = self
	add_child(air_effects)

func _actor(source: String, height: float) -> RIG.Performer:
	var actor := RIG.Performer.new(metadata,source)
	actor.height = height
	camera.add_child(actor)
	return actor

func _set_background(texture: Texture2D) -> void:
	background.texture = texture
	background.scale = Vector2(1380,776)/texture.get_size()
	background.position = Vector2(576,324)

func _pose(actor: RIG.Performer, index: int, flip: bool = false) -> void:
	actor.pose(index)
	# Keep the outgoing drawing's orientation during the pose dissolve.
	actor.sprites[actor.front].flip_h = flip

func present(index: int, beat: Dictionary) -> void:
	current_index = index
	current_shot = str(beat.shot)
	current_beat = beat
	shot_elapsed = 0.0
	gesture_played = false
	var desired: String = str(beat.phase)
	if transitioning:
		phase = destination
		transitioning = false
		transition_progress = 1.0
		_set_background(DECK if phase == "ship" else TERRACE)
	if desired != phase:
		destination = desired
		transitioning = true
		transition_progress = 0.0
	else:
		_stage_beat()

func _stage_beat() -> void:
	if motion_tween and motion_tween.is_running():
		motion_tween.kill()
	var on_ship: bool = phase == "ship"
	perimedes.visible = on_ship
	elpenor.visible = on_ship
	aeolus.visible = not on_ship
	_pose(odysseus,int(current_beat.ody))
	_pose(aeolus,int(current_beat.aeolus),int(current_beat.aeolus) == 0)
	_pose(perimedes,1 if current_shot == "perimedes" else 0)
	_pose(elpenor,3 if current_shot == "assent" else 2)
	var ody_position := Vector2(835,555) if on_ship else Vector2(365,555)
	var divine_position := Vector2(780,500)
	var target_focus := Vector2(585,305)
	var target_zoom: float = 1.14
	var duration: float = 1.05
	var target_spirits: float = 0.0
	match current_shot:
		"arrival": target_zoom = 1.04
		"plea", "appeal":
			target_zoom = 1.9
			target_focus = Vector2(375,272)
		"storm":
			target_zoom = 1.45
			target_focus = Vector2(480,280)
		"laugh", "divine_close":
			target_zoom = 1.95
			target_focus = Vector2(755,234)
		"reaction", "shock":
			duration = 0.8
			target_zoom = 2.0
			target_focus = Vector2(365,260)
		"offer", "agreement":
			divine_position = Vector2(670,507)
			target_zoom = 1.38
			target_focus = Vector2(515,280)
		"conjure":
			bag_owner = "aeolus"
			bag.position = Vector2(650,315)
			divine_position = Vector2(770,505)
			target_zoom = 1.4
			target_focus = Vector2(620,285)
		"bag":
			target_zoom = 2.1
			target_focus = Vector2(650,326)
		"handoff":
			_pose(odysseus,1)
			divine_position = Vector2(655,508)
			target_zoom = 1.4
			target_focus = Vector2(490,300)
			bag.position = Vector2(570,330)
			bag_owner = "transferring"
		"ody_bag":
			target_zoom = 1.85
			target_focus = Vector2(365,292)
		"chorus", "orbit", "warning":
			target_spirits = 1.0
			divine_position = Vector2(730 if current_shot == "orbit" else 690,485)
			target_zoom = 1.22 if current_shot == "orbit" else 1.36
			target_focus = Vector2(550,290)
		"farewell":
			target_spirits = 0.8
			divine_position = Vector2(960,425)
			target_zoom = 1.08
		"return":
			odysseus.position = Vector2(995,510)
			odysseus.walking = true
			duration = 2.4
			target_zoom = 1.05
		"crew_two", "assent":
			target_zoom = 1.70
			target_focus = Vector2(400,318)
		"protect", "ship_shock", "captain":
			target_zoom = 1.85
			target_focus = Vector2(835,283)
		"treasure":
			target_spirits = 1.0
			target_zoom = 1.24
			target_focus = Vector2(660,297)
		"winions_exit":
			target_spirits = 1.0
			target_zoom = 1.07
		"perimedes":
			target_zoom = 1.96
			target_focus = Vector2(305,337)
		"elpenor":
			target_zoom = 2.00
			target_focus = Vector2(515,345)
		"stop":
			target_zoom = 1.26
			target_focus = Vector2(640,305)
		"sealed", "knot", "storm_bag":
			target_zoom = 2.05 if current_shot == "knot" else 1.70
			target_focus = Vector2(900,230)
	if current_index > 11:
		bag_owner = "odysseus"
	bag.visible = current_shot in ["conjure","bag","handoff"]
	odysseus.walking = current_shot == "return"
	motion_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion_tween.tween_property(self,"zoom",target_zoom,duration)
	motion_tween.tween_property(self,"focus",target_focus,duration)
	motion_tween.tween_property(self,"spirits",target_spirits,0.65)
	motion_tween.tween_property(odysseus,"position",ody_position,duration)
	motion_tween.tween_property(aeolus_anchor,"position",divine_position,duration)
	if current_shot == "conjure":
		bag.modulate.a = 0.0
		motion_tween.tween_property(bag,"modulate:a",1.0,0.85)
	if current_shot == "handoff":
		bag.modulate.a = 1.0
		motion_tween.tween_property(bag,"position",Vector2(365,365),1.2)

func prepare_journey() -> void:
	ending = true
	current_shot = "journey"
	if motion_tween and motion_tween.is_running():
		motion_tween.kill()
	if phase != "ship":
		phase = "ship"
		_set_background(DECK)
	transitioning = false
	transition_progress = 1.0
	bag_owner = "odysseus"
	odysseus.walking = false
	bag.hide()
	aeolus.hide()
	perimedes.show()
	elpenor.show()
	_pose(odysseus,3)
	_pose(perimedes,0)
	_pose(elpenor,3)
	motion_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	motion_tween.tween_property(self,"zoom",1.12,1.8)
	motion_tween.tween_property(self,"focus",Vector2(576,300),1.8)
	motion_tween.tween_property(self,"spirits",0.0,0.7)
	motion_tween.tween_property(odysseus,"position",Vector2(820,555),1.8)

func _process(delta: float) -> void:
	elapsed += delta
	shot_elapsed += delta
	if transitioning:
		transition_progress = minf(1.0,transition_progress+delta/2.2)
		if transition_progress >= 0.48 and phase != destination:
			phase = destination
			_set_background(DECK if phase == "ship" else TERRACE)
			zoom = 1.08
			focus = Vector2(576,305)
			_stage_beat()
		if transition_progress >= 1.0:
			transitioning = false
			shot_elapsed = 0.0
	camera.scale = Vector2.ONE*zoom
	camera.position = Vector2(576,310)-focus*zoom
	camera.rotation = sin(elapsed*0.55)*0.0015
	var half_size: Vector2 = background.texture.get_size()*background.scale*0.5
	var top_left: Vector2 = -camera.position/zoom
	var bottom_right: Vector2 = (Vector2(1152,648)-camera.position)/zoom
	background.position.x = clampf(576+sin(elapsed*0.24)*3,bottom_right.x-half_size.x+6,top_left.x+half_size.x-6)
	background.position.y = clampf(324,bottom_right.y-half_size.y+6,top_left.y+half_size.y-6)
	aeolus.position = Vector2(sin(elapsed*0.9)*7,sin(elapsed*1.25)*12)
	aeolus.lean = sin(elapsed*0.85)*0.025
	odysseus.speaking = speaking and current_beat.get("speaker","") == "Odisseu"
	aeolus.speaking = speaking and "Éolo" in str(current_beat.get("speaker",""))
	perimedes.speaking = speaking and "Perímedes" in str(current_beat.get("speaker",""))
	elpenor.speaking = speaking and "Elpenor" in str(current_beat.get("speaker",""))
	if current_shot == "handoff" and shot_elapsed > 1.2 and not gesture_played:
		gesture_played = true
		_pose(odysseus,2)
		bag.hide()
		bag_owner = "odysseus"
	if current_shot == "return" and shot_elapsed > 2.5 and not gesture_played:
		gesture_played = true
		odysseus.walking = false
		_pose(odysseus,2)
	for i in winions.size():
		var actor := winions[i]
		var center := Vector2(535,270) if phase == "palace" else Vector2(560,325)
		var theta: float = elapsed*0.75+i*TAU/3.0
		var target := center+Vector2(cos(theta)*300,sin(theta)*80)
		if current_shot == "treasure":
			var marks := [Vector2(590,180),Vector2(700,195),Vector2(1040,320)]
			target = marks[i]+Vector2(0,sin(theta)*12)
		elif current_shot == "winions_exit":
			target = Vector2(550+i*170,220)-Vector2(-120,260)*minf(shot_elapsed,3.0)
		actor.position = actor.position.lerp(target,minf(delta*2.5,1.0))
		actor.modulate.a = spirits*(1.0-smoothstep(0.8,2.2,shot_elapsed) if current_shot == "winions_exit" else 1.0)
		actor.rotation = sin(theta)*0.12
		actor.speaking = speaking
		var pose: int = 2 if current_shot == "treasure" else 3 if current_shot == "winions_exit" else 1 if current_shot == "warning" else 0
		actor.pose(pose)
	floor_effects.queue_redraw()
	air_effects.queue_redraw()

func draw_floor(canvas: Node2D) -> void:
	for actor in [odysseus,perimedes,elpenor]:
		if actor.visible:
			canvas.draw_set_transform(actor.position+Vector2(0,3),0,Vector2(2.6,0.23))
			canvas.draw_circle(Vector2.ZERO,30,Color(0.015,0.02,0.025,0.22))
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func draw_air(canvas: Node2D) -> void:
	# Wind trails and drifting motes continue between lines, below the captions.
	for i in 28:
		var x: float = fposmod(i*91+elapsed*(18+i%4*7),1252)-50
		var y: float = 65+fposmod(i*73,360)+sin(elapsed*0.6+i)*8
		canvas.draw_circle(Vector2(x,y),1.1+i%3*0.45,Color(1.0,0.89,0.64,0.15 if phase == "palace" else 0.05))
	if current_shot in ["conjure","bag","storm_bag"]:
		var glow: float = sin(shot_elapsed*2.7)*0.5+0.5
		canvas.draw_rect(Rect2(0,30,1152,440),Color(0.40,0.72,0.85,glow*0.035))
	if transitioning:
		# Clouds fill the screen before the background changes at the midpoint.
		var coverage: float = smoothstep(0.0,0.35,transition_progress)*(1.0-smoothstep(0.65,1.0,transition_progress))
		canvas.draw_rect(Rect2(0,0,1152,648),Color(0.84,0.92,0.95,coverage))
		for row in 4:
			for col in 7:
				var center := Vector2(col*210-50+sin(row*2.1)*45,row*190-30)
				center.x += (transition_progress-0.5)*230
				for softness in 5:
					canvas.draw_circle(center,180-softness*16,Color(0.93,0.97,1.0,coverage*0.035))
