extends Node2D
const MODEL := preload("res://Ato4_Tempestade/Gameplay/PoseidonEscapeModel.gd")
const RIG := preload("res://Ato4_Tempestade/Cutscenes/LuckStage.gd")
const FX := preload("res://Ato4_Tempestade/Gameplay/PoseidonWaterEffects.gd")
const BOAT := preload("res://Assets/act4_poseidon_escape/traversal_ship.png")
const JUMP := preload("res://Assets/act4_poseidon_escape/odysseus_jump_v2.png")
const WALK := preload("res://Assets/act4_poseidon_escape/odysseus_escape_v2.png")
const SHIP := preload("res://Assets/act4_storm/ship_harpoon_side.png")
const SEA := preload("res://Assets/act4_released_winds/storm_open_sea.png")
const WAVE := preload("res://Assets/act4_storm/wave_front.png")
var model: MODEL
var view: Node2D
var actor: Sprite2D
var horse: RIG.Performer
var boats: Array[Sprite2D] = []
var pieces: Array = []
var background_ships: Array[Sprite2D] = []
var sea: Sprite2D
var floor_effects: RIG.FloorEffects
var air_effects: RIG.AirEffects
var time: float = 0.0
var walk_clock: float = 0.0
var focus: float = 195
var camera_zoom: float = 1.0
var camera_center: float = 330
var catastrophe: Sprite2D
const WALK_RECTS := [Rect2(0,0,410,350),Rect2(411,0,384,350),Rect2(795,0,384,350),Rect2(1179,0,357,350)]
const WALK_FEET := [Vector2(270,344),Vector2(209,344),Vector2(235,344),Vector2(229,344)]
const AIR_RECTS := [Rect2(0,0,768,512),Rect2(768,0,768,480),Rect2(0,512,768,512),Rect2(768,490,768,534)]
const AIR_FEET := [Vector2(380,470),Vector2(402,430),Vector2(440,458),Vector2(418,496)]

func _ready() -> void:
	sea = _sprite(SEA,Vector2(576,324),Vector2(1280,720),self,0)
	var material := ShaderMaterial.new()
	material.shader = preload("res://Assets/act4_storm/storm_water.gdshader")
	sea.material = material
	for i in 8:
		background_ships.append(_sprite(SHIP,Vector2.ZERO,Vector2(150,84),self,1))
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_poseidon/regions.json"))
	horse = RIG.Performer.new(metadata,"horse")
	horse.height = 600
	horse.z_index = 2
	add_child(horse)
	horse.pose(5)
	view = Node2D.new()
	add_child(view)
	for i in 4:
		var boat := _sprite(BOAT,Vector2(MODEL.SHIP_X[i]+378,392),Vector2(900,600),view,3)
		boats.append(boat)
		var pair: Array[Sprite2D] = []
		for half in 2:
			var piece := _sprite(BOAT,boat.position,Vector2(900,600),view,3)
			piece.region_enabled = true
			piece.region_rect = Rect2(half*768,0,768,1024)
			pair.append(piece)
		pieces.append(pair)
	var destination := Label.new()
	destination.text = "NAVIO DE ODISSEU · A BOLSA ESTÁ AQUI"
	destination.position = Vector2(MODEL.SHIP_X[3]+130,315)
	destination.z_index = 9
	destination.add_theme_font_size_override("font_size",18)
	destination.add_theme_color_override("font_color",Color(1,0.84,0.42))
	destination.add_theme_color_override("font_shadow_color",Color.BLACK)
	destination.add_theme_constant_override("shadow_offset_x",2)
	destination.add_theme_constant_override("shadow_offset_y",2)
	view.add_child(destination)
	_sprite(preload("res://Assets/act4_friends/wind_bag.png"),Vector2(MODEL.SHIP_X[3]+590,450),Vector2(43,43),view,5)
	floor_effects = RIG.FloorEffects.new()
	floor_effects.director = self
	floor_effects.z_index = 4
	view.add_child(floor_effects)
	catastrophe = _sprite(WAVE,Vector2.ZERO,Vector2(850,440),view,5)
	catastrophe.hide()
	actor = Sprite2D.new()
	actor.region_enabled = true
	actor.region_filter_clip_enabled = true
	actor.centered = false
	actor.z_index = 6
	view.add_child(actor)
	air_effects = RIG.AirEffects.new()
	air_effects.director = self
	air_effects.z_index = 7
	view.add_child(air_effects)
	_sprite(WAVE,Vector2(576,680),Vector2(1350,170),self,8).modulate.a = 0.85
	update_visuals(0)

func _sprite(texture: Texture2D, at: Vector2, dimensions: Vector2, parent: Node, layer: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.scale = dimensions/texture.get_size()
	sprite.z_index = layer
	parent.add_child(sprite)
	return sprite

func update_visuals(delta: float) -> void:
	if model == null: return
	time += delta
	var recent: int = -1
	for i in 3:
		if model.sunk_at[i] >= 0 and model.clock-model.sunk_at[i] < 1.65: recent = i
	var camera_target: float = (MODEL.SHIP_X[recent]+378+model.position.x)*0.5 if recent >= 0 else model.position.x
	focus = lerpf(focus,camera_target,minf(1,delta*4.0))
	camera_zoom = lerpf(camera_zoom,0.8 if recent >= 0 else 1.0,minf(1,delta*6))
	camera_center = lerpf(camera_center,576.0 if recent >= 0 else 330.0,minf(1,delta*6))
	view.scale = Vector2.ONE*camera_zoom
	view.position = Vector2(camera_center-focus*camera_zoom,455-455*camera_zoom)
	(sea.material as ShaderMaterial).set_shader_parameter("storm_clock",time)
	for i in 8:
		var sprite := background_ships[i]
		sprite.position = Vector2(fposmod(130+i*170-focus*0.11,1400)-80,195+(i%2)*55+sin(time*1.4+i)*6)
		sprite.rotation = sin(time*1.6+i)*0.05
		var age: float = model.clock-model.sunk_at[i+3] if model.sunk_at[i+3] >= 0 else -1
		sprite.visible = age < MODEL.WRECK_SECONDS
		sprite.modulate = Color(0.67,0.82,0.9,1-smoothstep(0.4,4.2,age) if age >= 0 else 1)
		if age >= 0:
			sprite.position.y += age*20
			sprite.rotation += age*0.3
	horse.position = Vector2(975,340+sin(time)*12)
	horse.pose(4 if recent >= 0 else 3 if model.airborne else 5)
	catastrophe.hide()
	for i in 3:
		if model.sunk_at[i] < 0: continue
		var age: float = model.clock-model.sunk_at[i]
		if age < 3.3:
			catastrophe.show()
			catastrophe.position = Vector2(MODEL.SHIP_X[i]+378,450+age*40)
			catastrophe.modulate.a = sin(PI*clampf(age/3.3,0,1))*0.95
	for i in 4:
		var age: float = model.clock-model.sunk_at[i] if i < 3 and model.sunk_at[i] >= 0 else -1
		var boat := boats[i]
		boat.visible = age < 0
		var shift: float = 100*(1-smoothstep(16,20,model.phase_clock)) if i == model.route_index+1 and not model.airborne else 0
		boat.position.x = MODEL.SHIP_X[i]+378+shift
		boat.position.y = 392+sin(time*1.4+i)*4
		for half in 2:
			var part: Sprite2D = pieces[i][half]
			part.visible = age >= 0 and age < MODEL.WRECK_SECONDS
			var side: float = -1 if half == 0 else 1
			part.position = boat.position+Vector2(side*(225+maxf(age,0)*45),maxf(age,0)*45)
			part.rotation = side*smoothstep(0,3,age)*0.55
			part.modulate.a = 1-smoothstep(1.2,4.2,age)
	var frame: int = 1
	if model.velocity.length() > 20: walk_clock += delta*13
	if model.velocity.length() > 20: frame = int(walk_clock)%4
	actor.texture = WALK
	actor.region_rect = WALK_RECTS[frame]
	actor.offset = -WALK_FEET[frame]
	actor.scale = Vector2(0.37*model.facing,0.37)
	actor.position = model.position+Vector2(0,sin(time*1.4+model.route_index)*4)
	if model.airborne:
		var air: int = 3 if model.route_index == 1 else 0 if model.flight_age < 0.12 else 2 if model.flight_age > model.flight_duration-0.18 else 1
		actor.texture = JUMP
		actor.region_rect = AIR_RECTS[air]
		actor.offset = -AIR_FEET[air]
		actor.scale = Vector2.ONE*0.31
		actor.position.y -= sin(PI*clampf(model.flight_age/model.flight_duration,0,1))*(150 if model.route_index == 1 else 105)
	elif model.landing_pause > 0 or model.phase == MODEL.Phase.ARRIVAL:
		actor.texture = JUMP
		actor.region_rect = AIR_RECTS[2]
		actor.offset = -AIR_FEET[2]
		actor.scale = Vector2.ONE*0.31
	if model.phase == MODEL.Phase.FAILED or model.stagger > 0:
		actor.texture = WALK
		actor.region_rect = Rect2(800,690,376,334)
		actor.offset = -Vector2(177,300)
	actor.modulate = Color(1,0.55,0.48) if model.hit_flash > 0 else Color.WHITE
	floor_effects.queue_redraw()
	air_effects.queue_redraw()

func draw_floor(canvas: Node2D) -> void:
	canvas.draw_set_transform(model.position,0,Vector2(1,0.3))
	canvas.draw_circle(Vector2.ZERO,24,Color(0,0,0,0.4))
	canvas.draw_set_transform(Vector2.ZERO)
	var pad: Vector2 = model.launch_point()
	var color := Color(0.5,1,0.86,0.9) if model.gate_open else Color(0.9,0.73,0.42,0.6)
	canvas.draw_arc(pad,27,0,TAU,40,color,3,true)
	canvas.draw_polyline(PackedVector2Array([pad+Vector2(-8,-7),pad+Vector2(8,0),pad+Vector2(-8,7)]),color,3,true)
	FX.floor_marks(canvas,model,time)

func draw_air(canvas: Node2D) -> void:
	for i in 70:
		var p := Vector2(focus-380+fposmod(i*109-time*230,1300),fposmod(i*67+time*600,720))
		canvas.draw_line(p,p+Vector2(-9,25),Color(0.7,0.87,0.97,0.23),1,true)
	if model.airborne and model.route_index == 1:
		var anchor := Vector2(MODEL.SHIP_X[model.route_index+1]+418,110)
		var rope_tip: Vector2 = actor.position+(Vector2(491,10)-AIR_FEET[3])*0.31
		canvas.draw_line(anchor,rope_tip,Color(0.72,0.59,0.34),4,true)
	for i in 3:
		if model.sunk_at[i] < 0: continue
		var age: float = model.clock-model.sunk_at[i]
		if age > 4.2: continue
		var at := Vector2(MODEL.SHIP_X[i]+350,500+age*10)
		canvas.draw_set_transform(at,0,Vector2(1,0.4))
		canvas.draw_arc(Vector2.ZERO,80+age*70,0,TAU,60,Color(0.7,0.97,1,1-age/4.2),14,true)
		canvas.draw_set_transform(Vector2.ZERO)
	FX.water(canvas,model,time)
