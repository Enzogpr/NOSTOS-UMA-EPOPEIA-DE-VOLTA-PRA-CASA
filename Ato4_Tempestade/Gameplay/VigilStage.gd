extends Node2D
const RIG := preload("res://Ato4_Tempestade/Cutscenes/LuckStage.gd")
const MODEL := preload("res://Ato4_Tempestade/Gameplay/VigilModel.gd")
const DECK := preload("res://Assets/act4_luck/deck_luck.png")
const HOME := preload("res://Assets/act4_vigil/deck_ithaca.png")
const FATIGUE := preload("res://Assets/act4_vigil/fatigue.gdshader")
const RELEASED_WINDS := preload("res://Ato4_Tempestade/Cutscenes/ReleasedWindsStage.gd")
var model: MODEL
var metadata: Dictionary
var camera: Node2D
var background: Sprite2D
var home: Sprite2D
var odysseus: RIG.Performer
var penelope: RIG.Performer
var visitors: Dictionary = {}
var floor_effects: RIG.FloorEffects
var air_effects: RIG.AirEffects
var blur: ColorRect
var mental_background: ColorRect
var thought_speaker: String = "Odisseu"
var speaking: bool = false
var focus := Vector2(576,330)
var vision_center := Vector2(0.5,0.48)
var zoom: float = 1.0
var elapsed: float = 0.0
var failed_clock: float = 0.0
var released_winds: Node2D

func _ready() -> void:
	metadata = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_vigil/regions.json"))
	metadata.merge(JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_friends/regions.json")))
	mental_background = ColorRect.new()
	mental_background.size = Vector2(1152,648)
	mental_background.color = Color(0.004,0.006,0.012)
	mental_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mental_background.hide()
	add_child(mental_background)
	camera = Node2D.new()
	add_child(camera)
	background = _background(DECK)
	home = _background(HOME)
	home.modulate.a = 0.0
	penelope = _actor("penelope_vision",310)
	penelope.position = Vector2(365,410)
	penelope.pose(0)
	penelope.modulate.a = 0.0
	floor_effects = RIG.FloorEffects.new()
	floor_effects.director = self
	camera.add_child(floor_effects)
	odysseus = _actor("odysseus_vigil",350)
	odysseus.position = Vector2(576,553)
	odysseus.pose(0)
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
	if model == null: return
	elapsed += delta
	if model.state in [MODEL.State.ENDING,MODEL.State.COMPLETE]:
		_process_thoughts(delta)
		return
	var failed: bool = model.state == MODEL.State.FAILED
	if failed: failed_clock += delta
	var target_focus := Vector2(576+model.look_side*38,330)
	zoom = lerpf(zoom,1.04,minf(delta*1.8,1.0))
	focus = focus.lerp(target_focus,minf(delta*2.6,1.0))
	camera.scale = Vector2.ONE*zoom
	camera.position = Vector2(576,324)-focus*zoom
	camera.rotation = sin(elapsed*0.85)*0.002
	var tint := Color(0.98,0.97,1.0).lerp(Color(0.33,0.43,0.70),model.night_amount()*0.85)
	var home_alpha: float = home.modulate.a
	background.modulate = tint
	home.modulate = tint
	var target_home_alpha: float = 1.0 if model.day == 9 else smoothstep(0.72,1.0,model.day_progress())*0.35 if model.day == 8 else 0.0
	home.modulate.a = move_toward(home_alpha,target_home_alpha,delta*1.4)
	for plate in [background,home]:
		var half_size: Vector2 = plate.texture.get_size()*plate.scale*0.5
		var top_left: Vector2 = -camera.position/zoom
		var bottom_right: Vector2 = (Vector2(1152,648)-camera.position)/zoom
		plate.position.x = clampf(576,bottom_right.x-half_size.x+6,top_left.x+half_size.x-6)
		plate.position.y = clampf(324,bottom_right.y-half_size.y+6,top_left.y+half_size.y-6)
	var pose: int = 3 if failed and model.loss_reason == "sono" else 2 if model.wake_flash > 0 else 1 if model.is_sleepy() else 0
	var face_left: bool = model.look_side < 0
	_pose(odysseus,pose,face_left if pose in [0,2] else not face_left)
	odysseus.lean = 0.045*smoothstep(45,95,model.fatigue)
	odysseus.modulate = Color.WHITE.lerp(Color(0.71,0.78,0.94),model.night_amount()*0.4)
	penelope.modulate.a = lerpf(penelope.modulate.a,model.vision_amount(),minf(delta*2.0,1.0))
	penelope.position.y = 410+sin(elapsed*0.8)*7
	_update_visitors(delta)
	vision_center = vision_center.lerp(Vector2(0.5+model.look_side*0.12,0.48),minf(delta*4.0,1.0))
	var material := blur.material as ShaderMaterial
	material.set_shader_parameter("fatigue",model.fatigue/100.0)
	material.set_shader_parameter("day_pressure",float(model.day-1)/8.0)
	material.set_shader_parameter("vision_center",vision_center)
	material.set_shader_parameter("closure",smoothstep(0.0,0.55,failed_clock) if failed else 0.0)
	material.set_shader_parameter("clock",elapsed)
	floor_effects.queue_redraw()
	air_effects.queue_redraw()

func _process_thoughts(delta: float) -> void:
	if released_winds != null:
		released_winds.speaking = speaking
		return
	# No deck, visitors, footsteps or opener are shown after the ninth-day loss.
	mental_background.show()
	background.hide()
	home.hide()
	for actor in visitors.values(): actor.hide()
	var alarm: bool = thought_speaker == "Penélope"
	zoom = lerpf(zoom,1.06,minf(delta*2.0,1.0))
	focus = focus.lerp(Vector2(576,327),minf(delta*3.0,1.0))
	camera.scale = Vector2.ONE*zoom
	camera.position = Vector2(576,324)-focus*zoom
	camera.rotation = 0.0
	odysseus.position = odysseus.position.lerp(Vector2(380 if alarm else 576,552),minf(delta*2.0,1.0))
	_pose(odysseus,2,false)
	odysseus.lean = -0.01
	odysseus.modulate = Color(0.74,0.79,0.89)
	odysseus.speaking = speaking and not alarm
	penelope.position = Vector2(806,451+sin(elapsed*0.9)*3.0)
	_pose(penelope,0,true)
	penelope.modulate = Color(0.84,0.91,1.0,move_toward(penelope.modulate.a,0.94 if alarm else 0.0,delta*2.0))
	penelope.speaking = speaking and alarm
	# The inner scene is clear against black, outside the failing real-world sight.
	blur.hide()
	floor_effects.hide()
	air_effects.hide()

func present_ending(beat: Dictionary) -> void:
	thought_speaker = str(beat.speaker)
	if beat.get("phase", "mind") != "storm": return
	if released_winds == null:
		released_winds = RELEASED_WINDS.new()
		add_child(released_winds)
		mental_background.hide()
		camera.hide()
		blur.hide()
		floor_effects.hide()
		air_effects.hide()
	released_winds.present(beat)

func _update_visitors(delta: float) -> void:
	var present_ids: Array[int] = []
	for visitor in model.crew:
		var id: int = visitor.id
		present_ids.append(id)
		if not visitors.has(id):
			var actor := _actor("crew_poses",350 if int(visitor.side) < 0 else 345)
			visitors[id] = actor
		var actor: RIG.Performer = visitors[id]
		var left: bool = int(visitor.side) < 0
		_pose(actor,0 if left else 2,left if visitor.retreating else not left)
		var progress: float = visitor.progress
		actor.position = Vector2(lerpf(-100,414,progress) if left else lerpf(1252,760,progress),552)
		actor.walking = model.state == MODEL.State.PLAYING
		actor.lean = -0.01 if visitor.retreating else 0.015
		actor.modulate.a = smoothstep(0.0,0.16,progress)
		actor.modulate = actor.modulate.lerp(Color(0.62,0.70,0.89,actor.modulate.a),model.night_amount()*delta)
	for id in visitors.keys():
		if not present_ids.has(int(id)):
			visitors[id].queue_free()
			visitors.erase(id)

func draw_floor(canvas: Node2D) -> void:
	var actors: Array = [odysseus]
	actors.append_array(visitors.values())
	for actor in actors:
		if actor != null and actor.visible:
			canvas.draw_set_transform(actor.position+Vector2(0,4),0,Vector2(2.9,0.24))
			canvas.draw_circle(Vector2.ZERO,34,Color(0.01,0.02,0.04,0.25*actor.modulate.a))
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func draw_air(canvas: Node2D) -> void:
	if model == null or model.state != MODEL.State.PLAYING: return
	for visitor in model.crew:
		if visitor.retreating or float(visitor.progress) < 0.18: continue
		var actor: RIG.Performer = visitors.get(int(visitor.id))
		if actor == null: continue
		var center: Vector2 = camera.transform*(actor.position-Vector2(0,370))
		var urgent: bool = float(visitor.progress) > 0.72
		var color := Color(1.0,0.52,0.35) if urgent else Color(0.97,0.86,0.57)
		canvas.draw_circle(center,14,color)
		canvas.draw_string(ThemeDB.fallback_font,center+Vector2(-4,6),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(0.08,0.06,0.05))
