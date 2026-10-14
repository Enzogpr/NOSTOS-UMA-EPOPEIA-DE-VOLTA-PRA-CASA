extends Node2D
## Continuous camera, grounded pose blending, tracked steps and contact shots.

const REGIONS := "res://Assets/act4_luck/regions.json"
const ACTOR_SHADER := preload("res://Assets/act4_luck/luck_actor.gdshader")
const DECK := preload("res://Assets/act4_luck/deck_luck.png")
const SKY := preload("res://Assets/act4_storm/aeolia_discovery.png")

class Performer extends Node2D:
	var metadata: Dictionary
	var asset: String
	var sprites: Array[Sprite2D] = []
	var front: int = 0
	var pose_index: int = -1
	var height: float = 430.0
	var blend: float = 1.0
	var clock: float = 0.0
	var speaking: bool = false
	var walking: bool = false
	var lean: float = 0.0

	func _init(data: Dictionary, source: String) -> void:
		metadata = data
		asset = source

	func _ready() -> void:
		for i in 2:
			var sprite := Sprite2D.new()
			sprite.region_enabled = true
			sprite.region_filter_clip_enabled = true
			var material := ShaderMaterial.new()
			material.shader = ACTOR_SHADER
			sprite.material = material
			add_child(sprite)
			sprites.append(sprite)

	func pose(index: int) -> void:
		if index == pose_index:
			return
		var first: bool = pose_index < 0
		front = 1-front
		var sprite := sprites[front]
		var entry: Dictionary = metadata[asset]
		var rect: Array = entry.regions[index]
		var source: String = str(entry.texture)
		var override: Dictionary = entry.get("pose_overrides",{}).get(str(index),{})
		if not override.is_empty():
			source = str(override.texture)
			rect = override.region
		sprite.texture = load(source)
		sprite.region_rect = Rect2(rect[0],rect[1],rect[2],rect[3])
		sprite.offset = Vector2(0,-float(rect[3])*0.5)
		sprite.scale = Vector2.ONE * height/float(rect[3])
		var texture_size := sprite.texture.get_size()
		(sprite.material as ShaderMaterial).set_shader_parameter("region",Vector4(float(rect[0])/texture_size.x,float(rect[1])/texture_size.y,float(rect[2])/texture_size.x,float(rect[3])/texture_size.y))
		pose_index = index
		blend = 1.0 if first else 0.0
		sprite.modulate.a = blend
		sprites[1-front].modulate.a = 1.0-blend

	func _process(delta: float) -> void:
		clock += delta
		blend = minf(1.0,blend+delta/0.28)
		var mix: float = smoothstep(0.0,1.0,blend)
		var breath: float = sin(clock*1.8)*0.003
		scale = Vector2(1.0+breath,1.0+breath*0.45)
		rotation = lerpf(rotation,lean + (sin(clock*8.0)*0.012 if walking else sin(clock*1.2)*0.002),minf(delta*7.0,1.0))
		for i in 2:
			var sprite := sprites[i]
			sprite.modulate.a = mix if i == front else 1.0-mix
			var material := sprite.material as ShaderMaterial
			material.set_shader_parameter("clock",clock)
			material.set_shader_parameter("speaking",1.0 if speaking else 0.0)
			material.set_shader_parameter("walking",1.0 if walking else 0.0)

class FloorEffects extends Node2D:
	var director: Node2D
	func _draw() -> void:
		director.draw_floor(self)

class AirEffects extends Node2D:
	var director: Node2D
	func _draw() -> void:
		director.draw_air(self)

var metadata: Dictionary
var camera: Node2D
var background: Sprite2D
var odysseus: Performer
var eurylochus: Performer
var brothers: Performer
var crew: Array[Performer] = []
var rope: Line2D
var floor_effects: FloorEffects
var air_effects: AirEffects
var current_index: int = -1
var current_shot: String = "rope"
var current_beat: Dictionary = {}
var shot_elapsed: float = 0.0
var elapsed: float = 0.0
var speaking: bool = false
var zoom: float = 1.0
var focus := Vector2(576,310)
var privacy: float = 0.0
var motion_tween: Tween
var gesture_played: bool = false
var ending: bool = false

func _ready() -> void:
	metadata = JSON.parse_string(FileAccess.get_file_as_string(REGIONS))
	camera = Node2D.new()
	camera.name = "CameraRig"
	add_child(camera)
	background = Sprite2D.new()
	background.texture = DECK
	background.position = Vector2(576,324)
	background.scale = Vector2(1280,720)/DECK.get_size()
	camera.add_child(background)
	floor_effects = FloorEffects.new()
	floor_effects.director = self
	camera.add_child(floor_effects)
	for i in 6:
		var actor := _actor("eurylochus_luck_poses")
		actor.height = 190.0 + (i%2)*16
		actor.pose(5)
		actor.position = Vector2(160+i*170,438)
		actor.modulate = Color(0.27,0.32,0.39,0.0)
		crew.append(actor)
	rope = Line2D.new()
	rope.points = PackedVector2Array([Vector2(380,570),Vector2(890,-160)])
	rope.width = 5
	rope.default_color = Color(0.75,0.61,0.36)
	camera.add_child(rope)
	odysseus = _actor("odysseus_luck_poses")
	odysseus.position = Vector2(420,546)
	eurylochus = _actor("eurylochus_luck_poses")
	eurylochus.position = Vector2(760,546)
	eurylochus.scale.x = -1.0
	brothers = _actor("brothers_luck")
	brothers.height = 440.0
	brothers.position = Vector2(575,546)
	brothers.modulate.a = 0.0
	air_effects = AirEffects.new()
	air_effects.director = self
	add_child(air_effects)

func _actor(source: String) -> Performer:
	var actor := Performer.new(metadata,source)
	camera.add_child(actor)
	return actor

func _flip(actor: Performer, flip: bool) -> void:
	for sprite in actor.sprites:
		sprite.flip_h = flip

func present(index: int, beat: Dictionary) -> void:
	var previous_shot := current_shot
	current_index = index
	current_shot = str(beat.shot)
	current_beat = beat
	shot_elapsed = 0.0
	gesture_played = false
	if motion_tween and motion_tween.is_running():
		motion_tween.kill()
	odysseus.pose(int(beat.ody))
	eurylochus.pose(int(beat.eur))
	_flip(odysseus,current_shot == "walk")
	_flip(eurylochus,true)
	var private: bool = index >= 26
	var contact: bool = current_shot in ["comfort","private"]
	var sky: bool = current_shot in ["island","danger"]
	var left := Vector2(245,552) if private else Vector2(420,546)
	var right := Vector2(475,552) if private else Vector2(760,546)
	var target_zoom: float = 1.15
	var target_focus := Vector2(590,310)
	var duration: float = 1.25
	var target_privacy: float = 0.46 if private else 0.0
	match current_shot:
		"island", "danger":
			target_zoom = 1.02 if current_shot == "island" else 1.08
			target_focus = Vector2(576,305)
		"two", "question":
			target_zoom = 1.45
			target_focus = Vector2(590,276)
		"rope":
			target_zoom = 1.13
			target_focus = Vector2(600,308)
		"low_angle":
			target_zoom = 1.30
			target_focus = Vector2(660,266)
		"eury_close", "intimate":
			target_zoom = 2.30 if current_shot == "eury_close" else 1.78
			target_focus = Vector2(745,235) if current_shot == "eury_close" else Vector2(630,245)
		"odysseus_close", "odysseus_reaction":
			target_zoom = 2.25
			target_focus = Vector2(430,230)
		"comfort":
			brothers.pose(0)
			brothers.position = Vector2(575,546)
			target_zoom = 1.55
			target_focus = Vector2(575,272)
		"wide_crew", "crew", "memory":
			target_zoom = 1.06
			target_focus = Vector2(576,310)
		"walk":
			left = Vector2(300,552) if index == 24 else Vector2(245,552)
			right = Vector2(555,552) if index == 24 else Vector2(475,552)
			target_zoom = 1.20
			target_focus = Vector2(435,295) if index == 24 else Vector2(370,280)
			target_privacy = 0.22 if index == 24 else 0.38
			duration = 3.0
		"private":
			brothers.pose(1)
			brothers.position = Vector2(365,552)
			target_zoom = 1.63
			target_focus = Vector2(365,276)
		"private_shoulder":
			target_zoom = 1.95
			target_focus = Vector2(320,240)
			right = Vector2(570,552)
			eurylochus.pose(4)
		"private_close":
			target_zoom = 2.45
			target_focus = Vector2(255,225)
		"eury_nod":
			target_zoom = 2.40
			target_focus = Vector2(465,234)
		"thanks":
			target_zoom = 1.40
			target_focus = Vector2(365,285)
	rope.visible = current_shot in ["rope","low_angle"]
	odysseus.walking = current_shot == "walk"
	eurylochus.walking = current_shot == "walk"
	odysseus.lean = -0.015 if int(beat.ody) == 4 else 0.0
	eurylochus.lean = 0.02 if int(beat.eur) in [0,2] else 0.0
	# Film-like cutaways to the complete sky image; no island-over-sail overlay.
	var texture: Texture2D = SKY if sky else DECK
	if background.texture != texture:
		background.texture = texture
		background.scale = (Vector2(1152,648) if sky else Vector2(1280,720))/texture.get_size()
		if sky or previous_shot in ["island","danger"]:
			zoom = target_zoom
			focus = target_focus
	var crowd: bool = current_shot in ["wide_crew","crew","memory"]
	motion_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion_tween.tween_property(self,"zoom",target_zoom,duration)
	motion_tween.tween_property(self,"focus",target_focus,duration)
	motion_tween.tween_property(self,"privacy",target_privacy,1.8)
	motion_tween.tween_property(odysseus,"position",left,duration)
	motion_tween.tween_property(eurylochus,"position",right,duration)
	# Cutaway silhouettes are hidden immediately; contact poses blend as a unit.
	var actor_alpha: float = 0.0 if sky or contact else 1.0
	var left_alpha: float = 0.0 if current_shot in ["eury_close","eury_nod"] else actor_alpha
	var right_alpha: float = 0.0 if current_shot in ["odysseus_close","odysseus_reaction","private_close"] else actor_alpha
	var alpha_time: float = 0.0 if sky or previous_shot in ["island","danger"] else 0.35
	motion_tween.tween_property(odysseus,"modulate:a",left_alpha,alpha_time)
	motion_tween.tween_property(eurylochus,"modulate:a",right_alpha,alpha_time)
	motion_tween.tween_property(brothers,"modulate:a",1.0 if contact else 0.0,alpha_time)
	for actor in crew:
		motion_tween.tween_property(actor,"modulate:a",0.40 if crowd else 0.0,0.7)

func prepare_ascent() -> void:
	ending = true
	if motion_tween and motion_tween.is_running():
		motion_tween.kill()
	odysseus.pose(5)
	_flip(odysseus,false)
	eurylochus.pose(5)
	odysseus.walking = true
	rope.visible = true
	motion_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	motion_tween.tween_property(odysseus,"modulate:a",1.0,0.3)
	motion_tween.tween_property(eurylochus,"modulate:a",1.0,0.3)
	motion_tween.tween_property(brothers,"modulate:a",0.0,0.3)
	motion_tween.tween_property(odysseus,"position",Vector2(390,548),1.8)
	motion_tween.tween_property(self,"zoom",1.15,1.8)
	motion_tween.tween_property(self,"focus",Vector2(450,285),1.8)

func _process(delta: float) -> void:
	elapsed += delta
	shot_elapsed += delta
	camera.scale = Vector2.ONE*zoom
	camera.position = Vector2(576,310)-focus*zoom
	camera.rotation = sin(elapsed*0.65)*0.0022
	background.position = Vector2(576+sin(elapsed*0.31)*2.5,324+sin(elapsed*0.7)*1.0)
	# Follow the visible camera bounds near the rail so a tracking shot never
	# reveals the edge of the finite background plate.
	var half_size: Vector2 = background.texture.get_size()*background.scale*0.5
	var top_left: Vector2 = -camera.position/zoom
	var bottom_right: Vector2 = (Vector2(1152,648)-camera.position)/zoom
	background.position.x = clampf(background.position.x,bottom_right.x-half_size.x+4,top_left.x+half_size.x-4)
	background.position.y = clampf(background.position.y,bottom_right.y-half_size.y+4,top_left.y+half_size.y-4)
	background.modulate = Color(0.92,0.95,1.0).lerp(Color(0.48,0.58,0.74),privacy)
	odysseus.speaking = speaking and current_beat.get("speaker","") == "Odisseu"
	eurylochus.speaking = speaking and current_beat.get("speaker","") == "Euríloco"
	brothers.speaking = speaking
	if current_shot == "eury_nod":
		eurylochus.lean = sin(minf(shot_elapsed,2.0)*PI)*0.018
	if not gesture_played and current_beat.has("gesture") and shot_elapsed > 1.35 and not ending:
		gesture_played = true
		var actor: Performer = odysseus if current_beat.speaker == "Odisseu" else eurylochus
		actor.pose(int(current_beat.gesture))
	floor_effects.queue_redraw()
	air_effects.queue_redraw()

func draw_floor(canvas: Node2D) -> void:
	if current_shot in ["island","danger"]:
		return
	for actor in [odysseus,eurylochus,brothers]:
		if actor == null or actor.modulate.a < 0.01:
			continue
		canvas.draw_set_transform(actor.position+Vector2(0,4),0,Vector2(2.9,0.28))
		canvas.draw_circle(Vector2.ZERO,28 if actor != brothers else 52,Color(0.01,0.02,0.035,0.24*actor.modulate.a))
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func draw_air(canvas: Node2D) -> void:
	# The shaded corner deepens as they leave the crew; UI stays above this layer.
	for i in 14:
		var inset: float = i*8.0
		canvas.draw_rect(Rect2(inset,30,1152-inset*2,618),Color(0.012,0.024,0.055,privacy*0.016),false,8)
	if current_shot == "danger":
		var flash: float = maxf(0.0,sin(shot_elapsed*4.0))*exp(-shot_elapsed*1.4)*0.11
		canvas.draw_rect(Rect2(0,30,1152,618),Color(0.67,0.80,1.0,flash))
	if current_shot == "memory":
		var glow: float = sin(minf(shot_elapsed/3.0,1.0)*PI)*0.10
		canvas.draw_rect(Rect2(0,30,1152,430),Color(0.95,0.68,0.32,glow))
