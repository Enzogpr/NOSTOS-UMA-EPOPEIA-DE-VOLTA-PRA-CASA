extends Node2D
## The bag is already open when reality returns; its opener is never staged.
const RIG := preload("res://Ato4_Tempestade/Cutscenes/LuckStage.gd")
const DECK := preload("res://Assets/act4_released_winds/storm_deck.png")
const OPEN_SEA := preload("res://Assets/act4_released_winds/storm_open_sea.png")
const SHIP := preload("res://Assets/act4_storm/ship_harpoon_side.png")
const PRESENCE := preload("res://Assets/act4_released_winds/unknown_presence.gdshader")
var metadata: Dictionary
var camera: Node2D
var background: Sprite2D
var odysseus: RIG.Performer
var eurylochus: RIG.Performer
var aeolus: RIG.Performer
var rescue: RIG.Performer
var floor_effects: RIG.FloorEffects
var air_effects: RIG.AirEffects
var current_shot: String = "cry"
var current_speaker: String = "Odisseu"
var speaking: bool = false
var elapsed: float = 0.0
var shot_elapsed: float = 0.0
var reveal: float = 0.0
var focus := Vector2(576,325)
var target_focus := Vector2(430,295)
var zoom: float = 1.05
var target_zoom: float = 1.65
var wind_strength: float = 1.0
var atmosphere: float = 0.0
var bag_secured: bool = false
var ending: bool = false
var exterior: Node2D
var distant_ship: Sprite2D
var presence: ColorRect
var journey_progress: float = 0.0

func _ready() -> void:
	metadata = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_friends/regions.json"))
	metadata.merge(JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_luck/regions.json")))
	metadata.merge(JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_released_winds/regions.json")))
	camera = Node2D.new()
	add_child(camera)
	background = Sprite2D.new()
	background.texture = DECK
	background.scale = Vector2(1450,816)/DECK.get_size()
	background.position = Vector2(576,324)
	camera.add_child(background)
	floor_effects = RIG.FloorEffects.new()
	floor_effects.director = self
	camera.add_child(floor_effects)
	odysseus = _actor("odysseus_luck_poses",405,Vector2(385,555))
	eurylochus = _actor("eurylochus_luck_poses",380,Vector2(775,557))
	aeolus = _actor("aeolus_poses",285,Vector2(800,332))
	rescue = _actor("wind_bag_rescue",365,Vector2(576,560))
	rescue.hide()
	_build_exterior()
	presence = ColorRect.new()
	presence.size = Vector2(1152,648)
	presence.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var veil := ShaderMaterial.new()
	veil.shader = PRESENCE
	presence.material = veil
	presence.hide()
	add_child(presence)
	air_effects = RIG.AirEffects.new()
	air_effects.director = self
	add_child(air_effects)
	present({"shot":"cry","speaker":"Odisseu"})

func _build_exterior() -> void:
	exterior = Node2D.new()
	add_child(exterior)
	var sea := Sprite2D.new()
	sea.texture = OPEN_SEA
	sea.scale = Vector2(1152,648)/OPEN_SEA.get_size()
	sea.position = Vector2(576,324)
	exterior.add_child(sea)
	distant_ship = Sprite2D.new()
	distant_ship.texture = SHIP
	exterior.add_child(distant_ship)
	exterior.hide()

func _process_exterior() -> void:
	var travel_time: float = maxf(0.0,shot_elapsed-0.75)
	journey_progress = clampf(travel_time/3.5,0.0,1.0)
	var travel: float = 1.0-pow(1.0-journey_progress,1.4)
	exterior.visible = current_shot == "giants"
	exterior.modulate.a = smoothstep(0.0,0.45,travel_time)
	distant_ship.scale = Vector2.ONE*lerpf(420.0,118.0,travel)/SHIP.get_width()
	distant_ship.position = Vector2(lerpf(258,876,travel),lerpf(321,251,travel)+sin(elapsed*4.2)*lerpf(11,3,travel))
	distant_ship.rotation = -0.06+sin(elapsed*3.3)*0.09*(1.0-travel*0.6)
	distant_ship.modulate = Color.WHITE.lerp(Color(0.60,0.72,0.78),travel*0.55)

func _actor(source: String, height: float, at: Vector2) -> RIG.Performer:
	var actor := RIG.Performer.new(metadata,source)
	actor.height = height
	camera.add_child(actor)
	actor.position = at
	actor.pose(0)
	return actor

func _pose(actor: RIG.Performer, index: int, flip: bool = false) -> void:
	actor.pose(index)
	actor.sprites[actor.front].flip_h = flip

func present(beat: Dictionary) -> void:
	current_shot = str(beat.shot)
	current_speaker = str(beat.speaker)
	shot_elapsed = 0.0
	target_focus = Vector2(576,310)
	target_zoom = 1.10
	match current_shot:
		"cry":
			target_focus = Vector2(390,285)
			target_zoom = 1.85
		"course":
			target_focus = Vector2(575,295)
			target_zoom = 1.13
		"aeolus":
			target_focus = Vector2(785,196)
			target_zoom = 1.92
		"giants":
			target_focus = Vector2(765,249)
			target_zoom = 1.38
		"help":
			target_focus = Vector2(533,350)
			target_zoom = 1.50
		"late":
			target_focus = Vector2(775,284)
			target_zoom = 1.92
		"rescue":
			target_focus = Vector2(576,365)
			target_zoom = 1.45
		"close":
			bag_secured = true
			target_focus = Vector2(576,382)
			target_zoom = 1.64
		"voice", "presence":
			target_focus = Vector2(767,257)
			target_zoom = 1.45 if current_shot == "voice" else 1.8

func _process(delta: float) -> void:
	elapsed += delta
	shot_elapsed += delta
	reveal = minf(1.0,reveal+delta/0.60)
	var mysterious: bool = current_shot in ["voice","presence"]
	var together: bool = current_shot in ["help","rescue","close"]
	var deity: bool = current_shot in ["aeolus","giants"]
	_process_exterior()
	wind_strength = move_toward(wind_strength,0.12 if bag_secured else 1.0,delta*0.38)
	atmosphere = move_toward(atmosphere,1.0 if mysterious else 0.0,delta*0.55)
	focus = focus.lerp(target_focus,minf(delta*2.5,1.0))
	zoom = lerpf(zoom,target_zoom,minf(delta*2.3,1.0))
	camera.scale = Vector2.ONE*zoom
	var sway := Vector2(sin(elapsed*3.1)*3.5,cos(elapsed*2.2)*2.4)*wind_strength
	camera.position = Vector2(576,324)-focus*zoom+sway
	camera.rotation = sin(elapsed*1.7)*0.010*wind_strength
	background.modulate = Color.WHITE.lerp(Color(0.43,0.59,0.70),atmosphere*0.65)
	presence.visible = mysterious
	(presence.material as ShaderMaterial).set_shader_parameter("clock",elapsed)
	(presence.material as ShaderMaterial).set_shader_parameter("emergence",atmosphere)
	# Overscan covers the viewport throughout the moving shots, including corners.
	var half_size: Vector2 = background.texture.get_size()*background.scale*0.5
	var top_left: Vector2 = -camera.position/zoom
	var bottom_right: Vector2 = (Vector2(1152,648)-camera.position)/zoom
	background.position = Vector2(clampf(576,bottom_right.x-half_size.x+18,top_left.x+half_size.x-18),clampf(324,bottom_right.y-half_size.y+18,top_left.y+half_size.y-18))
	odysseus.visible = current_shot in ["cry","course"]
	eurylochus.visible = current_shot in ["course","late"]
	rescue.visible = together
	_pose(odysseus,1 if current_shot == "cry" else 2 if current_shot == "help" else 0)
	_pose(eurylochus,3 if current_shot == "late" else 0,true)
	_pose(aeolus,3 if current_shot == "aeolus" else 2 if deity else 5,current_shot == "aeolus")
	_pose(rescue,1 if bag_secured else 0)
	aeolus.visible = deity
	aeolus.modulate.a = move_toward(aeolus.modulate.a,1.0 if deity else 0.0,delta*1.7)
	aeolus.position = Vector2(800+sin(elapsed*0.85)*15,332+sin(elapsed*1.4)*8)
	odysseus.lean = -0.035*wind_strength
	eurylochus.lean = -0.045*wind_strength
	rescue.lean = -0.015*wind_strength
	for actor in [odysseus,eurylochus,aeolus,rescue]:
		actor.speaking = speaking and ((actor == odysseus and current_speaker == "Odisseu") or (actor == eurylochus and current_speaker == "Euríloco") or (actor == aeolus and current_speaker == "Éolo") or (actor == rescue and current_speaker == "Odisseu"))
	floor_effects.queue_redraw()
	air_effects.queue_redraw()
	modulate.a = smoothstep(0.0,1.0,reveal)

func draw_floor(canvas: Node2D) -> void:
	for actor in [odysseus,eurylochus,rescue]:
		if actor.visible:
			canvas.draw_set_transform(actor.position+Vector2(0,3),0,Vector2(3.1 if actor != rescue else 6.0,0.22))
			canvas.draw_circle(Vector2.ZERO,34,Color(0.01,0.025,0.04,0.30))
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func draw_air(canvas: Node2D) -> void:
	if exterior.visible and exterior.modulate.a > 0.02:
		_draw_exile(canvas)
	# Rain and wind remain procedural layers, so they move across every painting.
	for i in 100:
		var drift: float = 480.0 if current_shot == "giants" else -480.0
		var start := Vector2(fposmod(i*83.7+elapsed*drift,1390.0)-110,fposmod(i*41.3+elapsed*340.0,830.0)-90)
		var direction := Vector2(45,24) if current_shot == "giants" else Vector2(-22,32)
		canvas.draw_line(start,start+direction,Color(0.69,0.85,0.96,0.12*(1.0-atmosphere*0.6)),1.0,true)
	if atmosphere < 0.8 and current_shot != "giants":
		var origin: Vector2 = camera.transform*((Vector2(595,336) if bag_secured else Vector2(520,345)) if rescue.visible else Vector2(170,590))
		for ribbon in 15:
			var points := PackedVector2Array()
			for step in 25:
				var t: float = float(step)/24.0
				var width: float = 35.0+t*230.0
				points.append(origin+Vector2(sin(t*9.0+elapsed*4.1+ribbon*0.41)*width+t*190.0,-t*900.0))
			canvas.draw_polyline(points,Color(0.68,0.92,1.0,wind_strength*0.12),2.0+ribbon%3,true)
		for i in 13:
			var x: float = fposmod(i*139.0-elapsed*610.0,1400.0)-120.0
			var y: float = 125.0+i*32.0+sin(elapsed*2.0+i)*18.0
			canvas.draw_line(Vector2(x,y),Vector2(x+75,y-9),Color(0.91,0.96,1.0,0.12*wind_strength),1.4,true)
	# The final voice is represented by the sea and an indistinct moving shadow.
	# No face, divine symbol, name, or portrait discloses its identity.
	if atmosphere > 0.0:
		for band in 7:
			var points := PackedVector2Array()
			for index in 39:
				var x: float = index*34.0-60.0
				points.append(Vector2(x,240+band*23+sin(index*0.27+elapsed*0.7+band*0.5)*20))
			canvas.draw_polyline(points,Color(0.005,0.026,0.038,0.09*atmosphere),14.0,true)
	var flash: float = maxf(0.0,1.0-absf(shot_elapsed-0.18)*5.0) if current_shot == "cry" else 0.0
	if flash > 0.0: canvas.draw_rect(Rect2(0,0,1152,648),Color(0.72,0.89,1.0,flash*0.16))

func _draw_exile(canvas: Node2D) -> void:
	var alpha: float = exterior.modulate.a
	var keel: Vector2 = distant_ship.position+Vector2(0,SHIP.get_height()*distant_ship.scale.y*0.37)
	var length: float = lerpf(225,75,journey_progress)
	for band in 5:
		var points := PackedVector2Array()
		for i in 23:
			var t: float = float(i)/22.0
			points.append(keel+Vector2(-t*length,10*t+sin(t*12.0-elapsed*6.0+band)*3.0+band*2.5))
		canvas.draw_polyline(points,Color(0.78,0.94,0.98,0.28*alpha),1.6,true)
	for i in 22:
		var start := Vector2(fposmod(i*92.0+elapsed*390.0,1400.0)-140,135+i*13.0+sin(elapsed+i)*6)
		canvas.draw_line(start,start+Vector2(105,-14),Color(0.81,0.94,1.0,0.19*alpha),1.5,true)
