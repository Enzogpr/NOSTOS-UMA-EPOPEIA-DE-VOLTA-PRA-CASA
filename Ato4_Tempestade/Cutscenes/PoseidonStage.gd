extends Node2D
## Deterministic shot clock: bodies, contacts, camera and water are separate tracks.
signal sound_cue(kind: String)
const RIG := preload("res://Ato4_Tempestade/Cutscenes/LuckStage.gd")
const ACTING := preload("res://Assets/act4_poseidon/acting.gdshader")
const DECK := preload("res://Assets/act4_released_winds/storm_deck.png")
const SEA := preload("res://Assets/act4_released_winds/storm_open_sea.png")
const SHIP := preload("res://Assets/act4_storm/ship_harpoon_side.png")
const WAVE := preload("res://Assets/act4_storm/wave_front.png")
var metadata: Dictionary
var camera: Node2D
var deck: Node2D
var ocean: Node2D
var plates: Array[Sprite2D] = []
var god: RIG.Performer
var sea_god: RIG.Performer
var face: RIG.Performer
var odysseus: RIG.Performer
var eurylochus: RIG.Performer
var kneeling: RIG.Performer
var contact: RIG.Performer
var horse: RIG.Performer
var fleet: Array[Sprite2D] = []
var floor_effects: RIG.FloorEffects
var air_effects: RIG.AirEffects
var current_shot: String = "recognition"
var beat: Dictionary = {}
var elapsed: float = 0.0
var age: float = 0.0
var duration: float = 6.2
var focus := Vector2(576,300)
var zoom: float = 1.0
var darkness: float = 0.0
var speaking: bool = false
var privacy: float = 0.0
var impact_fired: bool = false
var impact_wave: Sprite2D
var event_keys: Dictionary = {}
var ending: bool = false
var pose_requests: Dictionary = {}

func _ready() -> void:
	metadata = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_poseidon/regions.json"))
	metadata.merge(JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_luck/regions.json")))
	camera = Node2D.new()
	add_child(camera)
	ocean = Node2D.new()
	camera.add_child(ocean)
	plates.append(_plate(SEA,ocean))
	for index in 9:
		var ship := Sprite2D.new()
		ship.texture = SHIP
		ship.z_index = 1
		ocean.add_child(ship)
		fleet.append(ship)
	_build_sea_actors()
	deck = Node2D.new()
	camera.add_child(deck)
	plates.append(_plate(DECK,deck))
	floor_effects = RIG.FloorEffects.new()
	floor_effects.director = self
	deck.add_child(floor_effects)
	god = _actor("poseidon",470,deck)
	face = _actor("god_faces",530,deck)
	odysseus = _actor("odysseus_luck_poses",385,deck)
	eurylochus = _actor("eurylochus_luck_poses",365,deck)
	kneeling = _actor("kneeling",235,deck)
	contact = _actor("contact",450,deck)
	for sprite in contact.sprites:
		(sprite.material as ShaderMaterial).set_shader_parameter("contact",1.0)
	impact_wave = Sprite2D.new()
	impact_wave.texture = WAVE
	impact_wave.z_index = 8
	impact_wave.scale = Vector2(2.6,0.78)
	impact_wave.hide()
	add_child(impact_wave)
	air_effects = RIG.AirEffects.new()
	air_effects.director = self
	air_effects.z_index = 9
	add_child(air_effects)
	seek(0.0,0.0)

func _build_sea_actors() -> void:
	horse = _actor("horse",485,ocean)
	sea_god = _actor("poseidon",445,ocean)
	sea_god.z_index = 2

func _plate(texture: Texture2D, parent: Node2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(1450,816)/texture.get_size()
	sprite.position = Vector2(576,324)
	sprite.z_index = 0
	parent.add_child(sprite)
	return sprite

func _actor(asset: String, height: float, parent: Node2D) -> RIG.Performer:
	var actor := RIG.Performer.new(metadata,asset)
	actor.height = height
	parent.add_child(actor)
	for sprite in actor.sprites:
		var material := ShaderMaterial.new()
		material.shader = ACTING
		sprite.material = material
	actor.pose(0)
	return actor

func _pose(actor: RIG.Performer, index: int, flip: bool = false, height: float = -1.0) -> void:
	if height < 0.0 and pose_requests.has(actor): height = float(pose_requests[actor].height)
	pose_requests[actor] = {"index":index,"flip":flip,"height":height}

func _apply_poses() -> void:
	for actor in pose_requests:
		if not actor.visible: continue
		var request: Dictionary = pose_requests[actor]
		if request.height > 0.0 and not is_equal_approx(actor.height,request.height):
			actor.height = request.height
			actor.pose_index = -1
		actor.pose(int(request.index))
		actor.sprites[actor.front].flip_h = request.flip
		if actor == contact:
			for sprite in actor.sprites:
				(sprite.material as ShaderMaterial).set_shader_parameter("contact",1.0 if request.index == 0 else 2.0 if request.index == 1 else 0.0)

func _emerge(actor: RIG.Performer, value: float) -> void:
	for sprite in actor.sprites:
		(sprite.material as ShaderMaterial).set_shader_parameter("emergence",value)

func present(_index: int, next_beat: Dictionary) -> void:
	beat = next_beat
	current_shot = str(beat.shot)
	duration = float(beat.duration)
	age = 0.0
	event_keys.clear()
	seek(0.0,0.0)

func _phase(start: float, finish: float) -> float:
	return smoothstep(start,finish,age)

func _once(key: String, when: float, cue: String) -> void:
	if age >= when and not event_keys.has(key):
		event_keys[key] = true
		sound_cue.emit(cue)

func _camera(at: Vector2, magnification: float, delta: float, cut: bool = false) -> void:
	var weight: float = 1.0 if cut else 1.0-exp(-delta*3.2)
	focus = focus.lerp(at,weight)
	zoom = lerpf(zoom,magnification,weight)
	camera.scale = Vector2.ONE*zoom
	var agitation: float = 0.6 if current_shot in ["head_grip","resist","twist","throw"] else 0.12
	if current_shot == "impact": agitation = _phase(1.2,1.5)*3.5
	camera.position = Vector2(576,309)-focus*zoom+Vector2(sin(elapsed*27.0),cos(elapsed*21.0))*agitation
	camera.rotation = sin(elapsed*0.9)*0.0015
	for plate in plates:
		var half_size := plate.texture.get_size()*plate.scale*0.5
		var top_left := -camera.position/zoom
		var bottom_right := (Vector2(1152,648)-camera.position)/zoom
		plate.position = Vector2(clampf(576,bottom_right.x-half_size.x+15,top_left.x+half_size.x-15),clampf(324,bottom_right.y-half_size.y+15,top_left.y+half_size.y-15))

func seek(time: float, delta: float) -> void:
	age = time
	elapsed += delta
	pose_requests.clear()
	var p: float = clampf(age/maxf(duration,0.1),0.0,1.0)
	var target := Vector2(576,302)
	var target_zoom: float = 1.08
	var cut: bool = false
	deck.show()
	ocean.hide()
	for actor in [god,sea_god,face,odysseus,eurylochus,kneeling,contact,horse]:
		actor.hide()
		actor.modulate = Color.WHITE
		actor.walking = false
		actor.speaking = false
		actor.lean = 0.0
		_emerge(actor,1.0)
		for sprite in actor.sprites:
			(sprite.material as ShaderMaterial).set_shader_parameter("pressure",0.0)
	god.position = Vector2(810,558)
	face.position = Vector2(810,620)
	odysseus.position = Vector2(390,558)
	eurylochus.position = Vector2(183,558)
	kneeling.position = Vector2(470,558)
	contact.position = Vector2(680,558)
	impact_wave.hide()
	horse.position = Vector2(800,503)
	horse.z_index = 2
	sea_god.position = Vector2(810,506)
	_pose(god,0,true)
	_pose(odysseus,0)
	_pose(eurylochus,0)
	_pose(horse,0,false,485)
	_pose(sea_god,0,true)
	_pose(contact,0,false,450)
	var current_dark: float = 0.0
	match current_shot:
		"recognition":
			if age < 1.7:
				odysseus.show()
				eurylochus.show()
				target = Vector2(397,280)
				target_zoom = 1.65
			else:
				deck.hide()
				ocean.show()
				horse.show()
				sea_god.show()
				horse.modulate.a = 1.0-_phase(3.8,5.6)
				_emerge(sea_god,_phase(4.1,5.8))
				sea_god.position.y += (1.0-_phase(3.8,5.5))*70
				cut = age < 1.8
				_once("rise",2.0,"surge")
		"calm_eye", "stern", "judge", "verdict", "darken":
			face.show()
			var expression: int = 0 if current_shot == "calm_eye" and p < 0.42 else 1 if current_shot == "calm_eye" and p < 0.65 else 2
			if current_shot in ["judge","verdict"]: expression = 5
			if current_shot == "darken": expression = 4
			_pose(face,expression,true)
			target = Vector2(810,233)
			target_zoom = lerpf(1.16,1.39,p)
			if current_shot in ["judge","darken"]: current_dark = 0.25+0.35*p
		"calm", "offer", "above":
			god.show()
			_pose(god,1 if current_shot == "calm" else 3,true)
			target = Vector2(800,260 if current_shot != "above" else 230)
			target_zoom = 1.55
			if current_shot == "above":
				kneeling.show()
				_pose(kneeling,1,false,180)
				target = Vector2(623,352)
				target_zoom = 1.16
		"wrist", "suspended", "denial":
			contact.show()
			_pose(contact,0)
			contact.position.y -= sin(minf(age,2.0)*2.0)*2.5
			if current_shot == "wrist":
				contact.modulate.a = _phase(0.55,0.90)
				if age < 0.9:
					god.show()
					odysseus.show()
					_pose(god,2,false)
					odysseus.position.x = lerpf(390,575,_phase(0.12,0.8))
					odysseus.position.y -= _phase(0.3,0.8)*20
					god.modulate.a = 1.0-contact.modulate.a
					odysseus.modulate.a = god.modulate.a
					eurylochus.show()
				_once("grip",0.6,"grip")
				target = Vector2(665,300)
				target_zoom = 1.15
			elif current_shot == "suspended" and age < 1.7:
				target = Vector2(583,504)
				target_zoom = 2.4
				cut = age < 0.1
			else:
				target = Vector2(575,230)
				target_zoom = 1.95
		"release":
			god.show()
			odysseus.show()
			_pose(god,3,true)
			_pose(odysseus,3)
			odysseus.position.x = lerpf(575,450,_phase(0.0,0.8))
			odysseus.position.y -= (1.0-_phase(0.0,0.5))*20
			odysseus.lean = -0.04*(1.0-_phase(0.3,1.3))
			target = Vector2(640,295)
			target_zoom = 1.25
		"coil", "encircle":
			deck.hide()
			ocean.show()
			horse.show()
			_pose(horse,0,false,360)
			var angle: float = age*1.1+(2.8 if current_shot == "encircle" else 0.0)
			horse.position = Vector2(576+sin(angle)*400,390+cos(angle)*65)
			horse.modulate.a = _phase(0.0,0.8)
			horse.z_index = 2 if cos(angle) > 0 else 0
			target = Vector2(576,325)
		"railing":
			odysseus.show()
			_pose(odysseus,3)
			odysseus.position.y += sin(elapsed*1.6)*2.0
			target = Vector2(390,275)
			target_zoom = 1.85
		"gallop":
			deck.hide()
			ocean.show()
			horse.show()
			_pose(horse,1+int(age*5.0)%2,false,255)
			horse.position = Vector2(lerpf(-100,1110,clampf(age/9.0,0.0,1.0)),390-absf(sin(age*7.8))*16)
			horse.blend = minf(1.0,horse.blend+delta/0.08)
			target = Vector2(clampf(horse.position.x,350,830),320)
			target_zoom = 1.12
			if age >= 2.0 and age < 4.8:
				target = Vector2(horse.position.x,horse.position.y-24)
				target_zoom = 2.25
			if age > 9.0:
				_pose(horse,0,false,485)
				horse.position = Vector2(790,503)
				target = Vector2(665,220)
				target_zoom = 1.9
			if int(age*4.0) != int(maxf(0,age-delta)*4.0) and age < 9.0: sound_cue.emit("hoof")
		"leap":
			deck.hide()
			ocean.show()
			horse.show()
			var jump: float = clampf((age-0.8)/3.6,0,1)
			_pose(horse,3,false,280)
			horse.position = Vector2(lerpf(230,830,jump),410-sin(jump*PI)*215)
			if age > 4.4:
				_pose(horse,4,false,340)
				horse.position = Vector2(830,lerpf(225,730,_phase(4.4,5.35)))
				horse.modulate.a = 1.0-_phase(5.0,5.4)
				sea_god.show()
				sea_god.modulate.a = _phase(5.45,6.6)
				target = Vector2(810,310)
			_once("jump",0.8,"surge")
			_once("splash",5.2,"splash")
		"fall":
			target = Vector2(435,350)
			target_zoom = 1.14
			if age < 2.7:
				odysseus.show()
				_pose(odysseus,5)
				var flight: float = _phase(0.0,2.6)
				odysseus.position = Vector2(600-flight*170,558-sin(flight*PI)*120)
				odysseus.lean = -sin(flight*PI)*0.75
			else:
				kneeling.show()
				_pose(kneeling,0,false,235)
				kneeling.position.x = 430
				kneeling.lean = 0.04*(1.0-_phase(2.7,4.3))
				eurylochus.show()
			_once("deck",2.7,"deck")
		"ground", "wounded", "small", "reform", "water_cup", "crush", "loom":
			kneeling.show()
			_pose(kneeling,0,false,235)
			if current_shot in ["reform","water_cup","crush","loom"]:
				god.show()
				if current_shot == "reform": _emerge(god,_phase(0.4,2.8))
				_pose(god,5 if current_shot in ["water_cup","crush"] else 4 if current_shot == "loom" else 0,current_shot != "loom")
				if current_shot == "crush" and age > 0.55: _pose(god,3,true)
				target = Vector2(795,270)
				target_zoom = 1.6
				if current_shot == "loom":
					god.position.x -= _phase(0.0,1.7)*55
					target = Vector2(641,325)
					target_zoom = 1.35
			else:
				target = Vector2(465,408)
				target_zoom = 1.7 if current_shot != "small" else 1.05
				if current_shot == "small":
					god.show()
					_pose(god,0,true)
					_pose(kneeling,2,false,310)
					target = Vector2(625,310)
					target_zoom = 1.05
					current_dark = 0.25
		"head_grip", "resist", "twist", "throw":
			contact.show()
			_pose(contact,2 if current_shot == "throw" else 1)
			contact.lean = sin(elapsed*7.0)*0.008
			target = Vector2(615,250)
			target_zoom = 1.55
			if current_shot == "head_grip":
				contact.modulate.a = _phase(0.0,0.24)
				_once("pressure",0.25,"grip")
			if current_shot == "twist": target_zoom = 1.95
			var pressure: float = _phase(0.0,1.0)*0.35 if current_shot == "head_grip" else 0.4+sin(age*4.0)*0.13 if current_shot == "resist" else _phase(0.0,0.85)*0.9 if current_shot == "twist" else 0.0
			for sprite in contact.sprites:
				(sprite.material as ShaderMaterial).set_shader_parameter("pressure",pressure)
			if current_shot == "twist": _once("twist",0.65,"grip")
			if current_shot == "throw":
				target = Vector2(515,325)
				target_zoom = 1.2
				_once("release",0.7,"surge")
				if age > 0.9 and age < 2.8:
					contact.hide()
					god.show()
					_pose(god,2,false)
					odysseus.show()
					_pose(odysseus,5)
					var flight: float = _phase(0.9,2.8)
					odysseus.position = Vector2(lerpf(505,245,flight),558-sin(flight*PI)*95)
					odysseus.lean = -sin(flight*PI)*0.48
					eurylochus.show()
				elif age >= 2.8:
					_pose(contact,3,false,355)
					contact.position = Vector2(300,558)
					_once("catch",2.8,"deck")
		"support":
			contact.show()
			_pose(contact,3,false,355)
			contact.position = Vector2(300,558)
			contact.lean = -0.02*(1.0-_phase(2.0,5.0))
			target = Vector2(300,329)
			target_zoom = 1.45
			if age > duration-2.4:
				target = Vector2(395,525)
				target_zoom = 1.85
		"kneel":
			kneeling.show()
			if age < 1.2:
				_pose(kneeling,2,false,310)
				kneeling.position.y -= (1.0-_phase(0.0,1.2))*34
			elif age < 3.1:
				_pose(kneeling,0,false,235)
			else: _pose(kneeling,1,false,180)
			target = Vector2(470,455)
			target_zoom = 1.5
			_once("knees",1.2,"deck")
		"plea_hand", "plea_explain", "plea_chest", "plea_eyes":
			kneeling.show()
			_pose(kneeling,3 if current_shot in ["plea_chest","plea_eyes"] else 2,false,310)
			kneeling.lean = -0.008 if current_shot == "plea_explain" else 0.007
			target = Vector2(470,378)
			target_zoom = 1.7 if current_shot != "plea_eyes" else 1.85
		"dissolve", "jaw", "impact":
			deck.hide()
			ocean.show()
			horse.show()
			_pose(horse,5,false,610)
			horse.position = Vector2(830,570)
			current_dark = 0.45
			target = Vector2(690,280)
			target_zoom = 1.28
			if current_shot == "dissolve":
				sea_god.show()
				sea_god.modulate.a = 1.0-_phase(0.0,1.6)
				horse.modulate.a = _phase(0.2,1.6)
			if current_shot == "impact":
				_once("impact",1.8,"impact")
				impact_fired = age >= 1.8
				impact_wave.visible = age >= 1.0
				impact_wave.position = Vector2(lerpf(2200,180,_phase(1.0,2.8)),340+sin(elapsed*3.0)*8)
				impact_wave.modulate.a = _phase(1.0,1.45)
				if age > 0.75 and age < 1.12:
					ocean.hide()
					deck.show()
					kneeling.show()
					_pose(kneeling,1,false,180)
					target = Vector2(470,445)
					target_zoom = 1.65
					cut = true
	var god_speaks: bool = beat.get("speaker","") == "Poseidon" and speaking
	_apply_poses()
	for actor in [god,sea_god,face]: actor.speaking = god_speaks
	odysseus.speaking = speaking and beat.get("speaker","") == "Odisseu"
	kneeling.speaking = odysseus.speaking
	contact.speaking = speaking
	for actor in [god,face,odysseus,kneeling,contact]:
		var tension: float = 0.9 if current_shot in ["head_grip","resist","twist","throw","impact"] else 0.5 if actor == kneeling else 0.0
		for sprite in actor.sprites:
			(sprite.material as ShaderMaterial).set_shader_parameter("tension",tension)
	var tint := Color.WHITE.lerp(Color(0.31,0.44,0.56),current_dark)
	deck.modulate = tint
	ocean.modulate = tint
	darkness = current_dark
	for index in fleet.size():
		var ship: Sprite2D = fleet[index]
		var row: int = index/3
		ship.position = Vector2(175+index%3*200+row*52,342+row*48+sin(elapsed*1.4+index)*6)
		ship.scale = Vector2.ONE*(125.0+row*32.0)/SHIP.get_width()
		var hit_at: float = 1.8+(1.0-ship.position.x/800.0)*0.45
		ship.rotation = sin(elapsed*1.6+index)*0.045-(_phase(hit_at,hit_at+0.65)*(0.22+index*0.025) if current_shot == "impact" else 0.0)
		ship.modulate = Color(0.60+row*0.1,0.72+row*0.06,0.78+row*0.05)
	_camera(target,target_zoom,delta,cut)
	floor_effects.queue_redraw()
	air_effects.queue_redraw()

func draw_floor(canvas: Node2D) -> void:
	for actor in [god,odysseus,eurylochus,kneeling,contact]:
		if actor.visible:
			canvas.draw_set_transform(actor.position,0,Vector2(5.0 if actor == contact else 2.5,0.18))
			canvas.draw_circle(Vector2.ZERO,30,Color(0.01,0.02,0.03,actor.modulate.a*0.35))
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func draw_air(canvas: Node2D) -> void:
	for i in 70:
		var point := Vector2(fposmod(i*139.3-elapsed*320.0,1300.0)-80,fposmod(i*74.1+elapsed*270.0,760.0)-60)
		canvas.draw_line(point,point+Vector2(-12,23),Color(0.65,0.84,0.91,0.10),1.0,true)
	var water: bool = ocean.visible or current_shot in ["wrist","reform","crush","head_grip"]
	if water:
		var center: Vector2 = camera.transform*(Vector2(810,506) if ocean.visible else Vector2(810,550))
		for line in 9:
			var points := PackedVector2Array()
			for step in 30:
				var t: float = float(step)/29.0
				var height: float = 240.0 if current_shot in ["recognition","reform","dissolve"] else 75.0
				points.append(center+Vector2(sin(t*10.0+elapsed*3.0+line)*lerpf(55,130,t),-t*height))
			canvas.draw_polyline(points,Color(0.43,0.79,0.88,0.10),2.0,true)
	if ocean.visible:
		for band in 7:
			var points := PackedVector2Array()
			for step in 40:
				var x: float = step*33.0-50.0
				points.append(Vector2(x,370+band*27+sin(step*0.35-elapsed*1.5+band)*9))
			canvas.draw_polyline(points,Color(0.56,0.81,0.86,0.07),2.0,true)
	if current_shot in ["leap","fall"]:
		var splash: float = 0.0
		if current_shot == "leap": splash = maxf(0,1.0-absf(age-5.3)/0.65)
		if current_shot == "fall": splash = maxf(0,1.0-absf(age-2.7)/0.5)*0.35
		for band in 18:
			var points := PackedVector2Array()
			for step in 44:
				var x: float = step*30.0-60
				var y: float = 690-splash*(360+band*15)+sin(step*0.24+elapsed*2.0+band)*17
				points.append(Vector2(x,y))
			canvas.draw_polyline(points,Color(0.53+band*0.02,0.83,0.89,splash*0.18),15.0,true)
	if current_shot == "impact" and age > 2.65:
		canvas.draw_rect(Rect2(0,0,1152,648),Color(0.005,0.013,0.025,_phase(2.65,3.65)))
