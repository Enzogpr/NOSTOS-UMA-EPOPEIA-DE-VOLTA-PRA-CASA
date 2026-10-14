extends Node2D
const RIG := preload("res://Ato4_Tempestade/Cutscenes/LuckStage.gd")
const MODEL := preload("res://Ato4_Tempestade/Gameplay/VigilModel.gd")
const DECK := preload("res://Assets/act4_luck/deck_luck.png")
const HOME := preload("res://Assets/act4_vigil/deck_ithaca.png")
const FATIGUE := preload("res://Assets/act4_vigil/fatigue.gdshader")
var model: MODEL
var metadata: Dictionary
var camera: Node2D
var background: Sprite2D
var home: Sprite2D
var odysseus: RIG.Performer
var eurylochus: RIG.Performer
var penelope: RIG.Performer
var contact: RIG.Performer
var visitors: Dictionary = {}
var floor_effects: RIG.FloorEffects
var air_effects: RIG.AirEffects
var blur: ColorRect
var focus := Vector2(576,330)
var zoom: float = 1.0
var elapsed: float = 0.0
var burst: float = 0.0

func _ready() -> void:
	metadata = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_vigil/regions.json"))
	metadata.merge(JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_friends/regions.json")))
	metadata.merge(JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_luck/regions.json")))
	camera = Node2D.new()
	add_child(camera)
	background = _background(DECK)
	home = _background(HOME)
	home.modulate.a = 0.0
	penelope = _actor("penelope_vision",290)
	penelope.position = Vector2(365,410)
	penelope.pose(0)
	penelope.modulate.a = 0.0
	floor_effects = RIG.FloorEffects.new()
	floor_effects.director = self
	camera.add_child(floor_effects)
	odysseus = _actor("odysseus_vigil",350)
	odysseus.position = Vector2(576,553)
	odysseus.pose(0)
	eurylochus = _actor("eurylochus_luck_poses",375)
	eurylochus.pose(0)
	eurylochus.position = Vector2(-180,553)
	eurylochus.hide()
	contact = _actor("wind_bag_betrayal",450)
	contact.position = Vector2(472,553)
	contact.pose(0)
	contact.hide()
	air_effects = RIG.AirEffects.new()
	air_effects.director = self
	add_child(air_effects)
	blur = ColorRect.new()
	blur.size = Vector2(1152,648)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = FATIGUE
	blur.material = material
	add_child(blur)

func _background(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = Vector2(576,324)
	sprite.scale = Vector2(1260,709)/texture.get_size()
	camera.add_child(sprite)
	return sprite

func _actor(source: String, height: float) -> RIG.Performer:
	var actor := RIG.Performer.new(metadata,source)
	actor.height = height
	camera.add_child(actor)
	return actor

func _pose(actor: RIG.Performer, index: int, flip: bool = false) -> void:
	actor.pose(index)
	actor.sprites[actor.front].flip_h = flip

func _process(delta: float) -> void:
	if model == null:
		return
	elapsed += delta
	var ending: bool = model.state in [MODEL.State.ENDING,MODEL.State.COMPLETE]
	var age: float = model.ending_clock
	var target_focus := Vector2(576+model.look_side*38,330)
	var target_zoom: float = 1.04
	if ending:
		target_focus = Vector2(576,303) if age < 3.5 else Vector2(493,342)
		target_zoom = 1.48 if age < 3.5 else 1.26
	zoom = lerpf(zoom,target_zoom,minf(delta*1.8,1.0))
	focus = focus.lerp(target_focus,minf(delta*2.6,1.0))
	camera.scale = Vector2.ONE*zoom
	camera.position = Vector2(576,324)-focus*zoom
	camera.rotation = sin(elapsed*0.85)*0.002
	if ending and age > 7.3:
		camera.position += Vector2(sin(age*47),cos(age*38))*minf((age-7.3)*2.5,8.0)
	var tint := Color(0.98,0.97,1.0).lerp(Color(0.33,0.43,0.70),model.night_amount()*0.85)
	if ending:
		tint = Color(1.0,0.99,0.91).lerp(Color(0.38,0.46,0.63),smoothstep(7.3,10.0,age))
	var home_alpha: float = home.modulate.a
	background.modulate = tint
	home.modulate = tint
	var target_home_alpha: float = 1.0 if model.day == 9 else smoothstep(0.72,1.0,model.day_progress())*0.35 if model.day == 8 else 0.0
	if ending:
		target_home_alpha *= 1.0-smoothstep(8.0,10.8,age)
	home.modulate.a = move_toward(home_alpha,target_home_alpha,delta*1.4)
	for plate in [background,home]:
		var half_size: Vector2 = plate.texture.get_size()*plate.scale*0.5
		var top_left: Vector2 = -camera.position/zoom
		var bottom_right: Vector2 = (Vector2(1152,648)-camera.position)/zoom
		plate.position.x = clampf(576,bottom_right.x-half_size.x+6,top_left.x+half_size.x-6)
		plate.position.y = clampf(324,bottom_right.y-half_size.y+6,top_left.y+half_size.y-6)
	var pose: int = 3 if ending and age > 2.0 else 2 if model.wake_flash > 0 else 1 if model.fatigue >= MODEL.WAKE_START else 0
	var face_left: bool = ending or model.look_side < 0
	_pose(odysseus,pose,face_left if pose in [0,2] else not face_left)
	odysseus.lean = 0.045*smoothstep(45,95,model.fatigue) if not ending else 0.025
	odysseus.modulate = Color.WHITE.lerp(Color(0.71,0.78,0.94),model.night_amount()*0.4 if not ending else 0.0)
	penelope.modulate.a = lerpf(penelope.modulate.a,model.vision_amount() if not ending else 0.0,minf(delta*2.0,1.0))
	penelope.position.y = 410+sin(elapsed*0.8)*7
	_update_visitors(delta)
	eurylochus.visible = ending and age >= 3.5
	if eurylochus.visible:
		var arrival: float = smoothstep(3.5,6.8,age)
		eurylochus.position = Vector2(lerpf(125,430,arrival),552)
		eurylochus.walking = age < 6.8
		_pose(eurylochus,2 if age > 6.8 else 0)
		if age > 9.3:
			_pose(odysseus,2)
	contact.visible = ending and age >= 6.4
	if contact.visible:
		var blend: float = smoothstep(6.4,6.85,age)
		contact.modulate.a = blend
		odysseus.modulate.a = 1.0-blend
		eurylochus.modulate.a = 1.0-blend
		_pose(contact,1 if not model.bag_sealed else 0)
	burst = smoothstep(7.3,8.7,age) if ending else 0.0
	var closure: float = model.microsleep_flash/0.65 if not ending else smoothstep(0.0,2.4,age)*(1.0-smoothstep(3.5,4.7,age))
	var material := blur.material as ShaderMaterial
	material.set_shader_parameter("fatigue",model.fatigue/100.0 if not ending else 0.0)
	material.set_shader_parameter("closure",closure)
	material.set_shader_parameter("clock",elapsed)
	floor_effects.queue_redraw()
	air_effects.queue_redraw()

func _update_visitors(delta: float) -> void:
	var present_ids: Array[int] = []
	for visitor in model.crew:
		var id: int = visitor.id
		present_ids.append(id)
		if not visitors.has(id):
			var actor := _actor("crew_poses",350 if int(visitor.side) < 0 else 345)
			camera.move_child(actor,camera.get_child_count()-2)
			visitors[id] = actor
		var actor: RIG.Performer = visitors[id]
		var left: bool = int(visitor.side) < 0
		_pose(actor,0 if left else 2,left if visitor.retreating else not left)
		var progress: float = visitor.progress
		actor.position = Vector2(lerpf(-100,414,progress) if left else lerpf(1252,760,progress),552)
		actor.walking = true
		actor.lean = -0.01 if visitor.retreating else 0.015
		actor.modulate.a = smoothstep(0.0,0.16,progress)
		actor.modulate = actor.modulate.lerp(Color(0.62,0.70,0.89,actor.modulate.a),model.night_amount()*delta)
	for id in visitors.keys():
		if not present_ids.has(int(id)):
			visitors[id].queue_free()
			visitors.erase(id)

func draw_floor(canvas: Node2D) -> void:
	var actors: Array = [odysseus,eurylochus,contact]
	actors.append_array(visitors.values())
	for actor in actors:
		if actor != null and actor.visible:
			canvas.draw_set_transform(actor.position+Vector2(0,4),0,Vector2(2.9,0.24))
			canvas.draw_circle(Vector2.ZERO,34,Color(0.01,0.02,0.04,0.25*actor.modulate.a))
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func draw_air(canvas: Node2D) -> void:
	if model == null:
		return
	for visitor in model.crew:
		if visitor.retreating or float(visitor.progress) < 0.18:
			continue
		var actor: RIG.Performer = visitors.get(int(visitor.id))
		if actor == null:
			continue
		var center: Vector2 = camera.transform*(actor.position-Vector2(0,370))
		var urgent: bool = float(visitor.progress) > 0.72
		var color := Color(1.0,0.52,0.35) if urgent else Color(0.97,0.86,0.57)
		canvas.draw_circle(center,14,color)
		canvas.draw_string(ThemeDB.fallback_font,center+Vector2(-4,6),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(0.08,0.06,0.05))
	# Free winds visibly radiate from the bag, then engulf the ship.
	if burst > 0.0:
		var source: Vector2 = camera.transform*Vector2(585,350)
		for i in 15:
			var angle: float = i*TAU/15.0+model.ending_clock*0.85
			var radius: float = fposmod(model.ending_clock*220+i*73,850)
			var at: Vector2 = source+Vector2(cos(angle),sin(angle)*0.6)*radius
			canvas.draw_arc(at,42+i%3*14,angle,angle+2.4,20,Color(0.77,0.89,1.0,burst*0.50),5.0,true)
		canvas.draw_rect(Rect2(0,0,1152,648),Color(0.75,0.87,1.0,maxf(0.0,sin(elapsed*19))*burst*0.09))
