extends Node2D
const FX := preload("res://Ato4_Tempestade/Gameplay/PoseidonWaterEffects.gd")
const FLEET_STAGE := preload("res://Ato4_Tempestade/Gameplay/PoseidonFleetStage.gd")
const BROKEN := preload("res://Assets/act4_poseidon_escape/deck_broken.png")
const MODEL := preload("res://Ato4_Tempestade/Gameplay/PoseidonEscapeModel.gd")
const RIG := preload("res://Ato4_Tempestade/Cutscenes/LuckStage.gd")
const SEA := preload("res://Assets/act4_released_winds/storm_open_sea.png")
const DECK := preload("res://Assets/act4_poseidon_escape/deck.png")
const ACTOR := preload("res://Assets/act4_poseidon_escape/odysseus_escape_v2.png")
const SHIP := preload("res://Assets/act4_storm/ship_harpoon_side.png")
const BAG := preload("res://Assets/act4_friends/wind_bag.png")
const WAVE := preload("res://Assets/act4_storm/wave_front.png")
var fleet_stage: Node2D
var wood_clock: float = 0.0
var previous_mast: bool = false
var model: MODEL
var rig: Node2D
var world: Node2D
var sea: Sprite2D
var deck: Sprite2D
var mast: Sprite2D
var odysseus: Sprite2D
var bag: Sprite2D
var horse: RIG.Performer
var eurylochus: RIG.Performer
var fleet: Array[Sprite2D] = []
var wreckage: Array = []
var escape_ship: Sprite2D
var wave: Sprite2D
var floor_effects: RIG.FloorEffects
var air_effects: RIG.AirEffects
var elapsed: float = 0.0
var walk_clock: float = 0.0
var player_frame: int = 0
var walking: bool = false
var escape_amount: float = 0.0
var metadata: Dictionary
const FRAME_RECTS := [Rect2(0,0,410,350),Rect2(411,0,384,350),Rect2(795,0,384,350),Rect2(1179,0,357,350),Rect2(0,350,410,340),Rect2(411,350,384,340),Rect2(795,350,384,340),Rect2(1179,350,357,340),Rect2(0,690,438,334),Rect2(448,698,352,326),Rect2(800,690,376,334),Rect2(1179,690,357,334)]
const FRAME_FEET := [Vector2(270,344),Vector2(209,344),Vector2(235,344),Vector2(229,344),Vector2(270,335),Vector2(209,335),Vector2(235,335),Vector2(221,335),Vector2(218,300),Vector2(183,291),Vector2(177,300),Vector2(175,307)]

func _ready() -> void:
	metadata = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_poseidon/regions.json"))
	metadata.merge(JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_luck/regions.json")))
	rig = Node2D.new()
	rig.position = Vector2(576,430)
	add_child(rig)
	world = Node2D.new()
	world.position = Vector2(-576,-430)
	rig.add_child(world)
	sea = _picture(SEA,Vector2(576,324),Vector2(1280,720),0)
	var water := ShaderMaterial.new()
	water.shader = preload("res://Assets/act4_storm/storm_water.gdshader")
	sea.material = water
	for i in 11:
		var ship := _picture(SHIP,Vector2.ZERO,Vector2(133,74),2)
		fleet.append(ship)
		var pieces: Array[Sprite2D] = []
		for half in 2:
			var piece := _picture(SHIP,Vector2.ZERO,Vector2(133,74),2)
			piece.region_enabled = true
			piece.region_rect = Rect2(half*SHIP.get_width()/2.0,0,SHIP.get_width()/2.0,SHIP.get_height())
			piece.hide()
			pieces.append(piece)
		wreckage.append(pieces)
	horse = _performer("horse",390,1)
	horse.pose(0)
	deck = _picture(DECK,Vector2(576,324),Vector2(1152,648),3)
	floor_effects = RIG.FloorEffects.new()
	floor_effects.director = self
	floor_effects.z_index = 4
	world.add_child(floor_effects)
	eurylochus = _performer("eurylochus_luck_poses",173,6)
	eurylochus.pose(3)
	eurylochus.position = Vector2(164,453)
	odysseus = Sprite2D.new()
	odysseus.texture = ACTOR
	odysseus.region_enabled = true
	odysseus.region_filter_clip_enabled = true
	odysseus.centered = false
	odysseus.z_index = 7
	world.add_child(odysseus)
	mast = _picture(DECK,Vector2(576,324),Vector2(1152,648),6)
	# The source image remains untouched; a region draws the mast in front when
	# the captain passes behind its base, preserving the depth of the deck.
	mast.region_enabled = true
	mast.region_rect = Rect2(633,0,285,676)
	mast.centered = false
	mast.position = Vector2(633,0)*Vector2(0.75,648.0/1024.0)
	bag = _picture(BAG,MODEL.BAG-Vector2(0,34),Vector2(75,75),7)
	wave = _picture(WAVE,Vector2(1250,463),Vector2(590,280),9)
	air_effects = RIG.AirEffects.new()
	air_effects.director = self
	air_effects.z_index = 10
	world.add_child(air_effects)
	escape_ship = _picture(SHIP,Vector2(680,405),Vector2(420,234),8)
	escape_ship.flip_h = true
	escape_ship.hide()
	fleet_stage = FLEET_STAGE.new()
	fleet_stage.model = model
	add_child(fleet_stage)
	update_visuals(0.0)

func _picture(texture: Texture2D, at: Vector2, dimensions: Vector2, layer: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.scale = dimensions/texture.get_size()
	sprite.z_index = layer
	world.add_child(sprite)
	return sprite

func _performer(source: String, height: float, layer: int) -> RIG.Performer:
	var actor := RIG.Performer.new(metadata,source)
	actor.height = height
	actor.z_index = layer
	world.add_child(actor)
	return actor

func _process(delta: float) -> void:
	update_visuals(delta)

func update_visuals(delta: float) -> void:
	if model == null: return
	fleet_stage.visible = model.is_route()
	rig.visible = not model.is_route()
	if model.is_route():
		fleet_stage.update_visuals(delta)
		return
	deck.texture = BROKEN if model.mast_broken else DECK
	mast.visible = not model.mast_broken
	if model.mast_broken and not previous_mast: wood_clock = 1.2
	previous_mast = model.mast_broken
	wood_clock = maxf(0,wood_clock-delta)
	elapsed += delta
	(sea.material as ShaderMaterial).set_shader_parameter("storm_clock",elapsed)
	walking = model.velocity.length() > 25 and model.stagger <= 0.0 and not model.untying
	if walking: walk_clock += delta*(1.1 if model.has_bag else 1.7)
	var frame: int = int(walk_clock*8.0)%4 if walking else 1
	if model.has_bag and not model.bag_secured: frame += 4
	if model.bracing: frame = 8
	if model.untying: frame = 9
	if model.stagger > 0.0 or model.phase == MODEL.Phase.FAILED: frame = 10
	if model.phase == MODEL.Phase.ESCAPING: frame = 11
	player_frame = frame
	odysseus.region_rect = FRAME_RECTS[frame]
	odysseus.offset = -FRAME_FEET[frame]
	odysseus.scale = Vector2(0.51*model.facing,0.51)
	odysseus.position = model.position+Vector2(0,sin(walk_clock*TAU*2)*1.7 if walking else sin(elapsed*2.0)*0.45)
	odysseus.rotation = -model.facing*0.13 if model.dash_left > 0.0 else 0.0
	odysseus.z_index = 5 if model.position.y < 445 else 7
	odysseus.modulate = Color(1.0,0.65,0.56) if model.hit_flash > 0.0 else Color(0.92,0.97,1.0)
	var belt_bag: bool = model.has_bag and not model.bag_secured and frame in [8,10]
	bag.visible = model.bag_secured or belt_bag or (not model.has_bag and not model.untying)
	bag.rotation = sin(elapsed*1.6)*0.08
	bag.position = MODEL.HELM+Vector2(55,-42) if model.bag_secured else model.position+Vector2(-model.facing*23,-52) if belt_bag else MODEL.BAG-Vector2(0,34)+Vector2(sin(elapsed*1.4)*3,0)
	var tilt: float = sin(elapsed*0.8)*0.007
	var shake: float = model.hit_flash*11+model.impact_flash*8
	rig.rotation = tilt
	rig.position = Vector2(576,430)+Vector2(sin(elapsed*51),cos(elapsed*43))*shake
	_update_fleet()
	_update_horse()
	_update_escape()
	floor_effects.queue_redraw()
	air_effects.queue_redraw()

func _update_fleet() -> void:
	for i in fleet.size():
		var row: int = i/6
		var ship := fleet[i]
		var x: float = 100+(i%6)*175+row*50
		var y: float = 190+row*65
		var age: float = model.clock-model.sunk_at[i] if model.sunk_at[i] >= 0.0 else -1.0
		ship.visible = age < 0.0
		ship.position = Vector2(x+sin(elapsed*0.7+i)*5,y+sin(elapsed*1.5+i)*6)
		ship.rotation = sin(elapsed*1.3+i)*0.055
		ship.modulate = Color(0.72,0.85,0.91,1.0)
		if age >= 0.0:
			ship.rotation += sin(float(i+1))*smoothstep(0,2.4,age)*1.1
			ship.position.y += smoothstep(0,4,age)*80
			ship.modulate.a = 1.0-smoothstep(1.2,4,age)
		for half in 2:
			var piece: Sprite2D = wreckage[i][half]
			piece.visible = age >= 0.0 and age < 4.0
			if not piece.visible: continue
			var side: float = -1.0 if half == 0 else 1.0
			piece.position = ship.position+Vector2(side*(33+age*11),age*8*half)
			piece.rotation = ship.rotation+side*smoothstep(0,2.8,age)*0.65
			piece.modulate = ship.modulate

func _update_horse() -> void:
	var horse_age: float = -1.0
	for hazard in model.hazards:
		if hazard.kind == "hoof": horse_age = hazard.age
	var final: bool = model.phase == MODEL.Phase.FINAL_ATTACK
	var target: int = 5 if final or horse_age >= 0.0 else 0
	horse.height = 390.0+(smoothstep(0,8,model.phase_clock)*130 if final else 0.0)
	horse.pose(target)
	for sprite in horse.sprites:
		if sprite.region_rect.size.y > 0: sprite.scale = Vector2.ONE*horse.height/sprite.region_rect.size.y
	horse.position = Vector2(980,338+sin(elapsed*1.2)*8)
	horse.modulate = Color(0.94,0.99,1.0,0.95 if final or horse_age >= 0 else 0.60)
	if horse_age >= 0.0:
		horse.position.x -= smoothstep(2.6,3.5,horse_age)*150
		horse.position.y += smoothstep(2.8,3.5,horse_age)*65
	wave.visible = false
	for hazard in model.hazards:
		if hazard.kind == "sweep" and hazard.age >= hazard.warning:
			wave.visible = true
			wave.position = Vector2(1230-(hazard.age-hazard.warning)*1500,467)
			wave.modulate.a = 0.86
	if final:
		wave.visible = true
		wave.position = Vector2(1570-smoothstep(7.0,11.5,model.phase_clock)*470,375)
		wave.modulate.a = 0.8

func _update_escape() -> void:
	var escaping: bool = model.phase in [MODEL.Phase.ESCAPING,MODEL.Phase.COMPLETE]
	var age: float = 6.6 if model.phase == MODEL.Phase.COMPLETE else model.phase_clock
	escape_amount = smoothstep(0.2,1.4,age) if escaping else 0.0
	for item in [deck,mast,bag,odysseus,eurylochus]:
		item.modulate.a = 1.0-escape_amount
	escape_ship.visible = escaping
	if not escaping: return
	wave.visible = true
	wave.position = Vector2(1100+age*130,420)
	wave.modulate.a = 1.0-smoothstep(3.2,6,age)
	escape_ship.modulate.a = smoothstep(0.6,1.4,age)
	escape_ship.position = Vector2(690-smoothstep(1.3,6.6,age)*800,407-smoothstep(1.3,6.6,age)*75)
	escape_ship.rotation = -0.09+sin(elapsed*3)*0.025
	escape_ship.scale = Vector2(420,234)/SHIP.get_size()*(1.0-smoothstep(2,6.6,age)*0.42)
	horse.position = Vector2(1060,389)
	horse.pose(5)
	horse.modulate.a = 0.92

func draw_floor(canvas: Node2D) -> void:
	if model.phase in [MODEL.Phase.ESCAPING,MODEL.Phase.COMPLETE]: return
	for i in MODEL.ANCHORS.size():
		var at: Vector2 = MODEL.ANCHORS[i]
		var color := Color(0.5,1,0.9,0.9) if model.bracing and model.anchor_index() == i else Color(0.8,0.7,0.45,0.6)
		canvas.draw_arc(at,26,0,TAU,40,color,2,true)
		canvas.draw_line(at-Vector2(8,0),at+Vector2(8,0),color,3,true)
		canvas.draw_line(at-Vector2(0,8),at+Vector2(0,8),color,3,true)
	canvas.draw_set_transform(model.position,0,Vector2(1,0.26))
	canvas.draw_circle(Vector2.ZERO,32,Color(0,0,0,0.4))
	canvas.draw_set_transform(Vector2.ZERO)
	if not model.has_bag:
		canvas.draw_arc(MODEL.BAG,38,0,TAU,40,Color(1,0.8,0.35,0.8),3,true)
	elif not model.bag_secured:
		canvas.draw_arc(MODEL.HELM,54,0,TAU,48,Color(0.5,1,0.87,0.8),3,true)
	for hazard in model.hazards:
		if hazard.kind == "wave" and hazard.age < hazard.warning:
			if not model.mast_broken: canvas.draw_rect(MODEL.COVER,Color(0.2,0.8,0.6,0.25))
			elif model.act_index == 1: canvas.draw_rect(MODEL.CRATE_COVER,Color(0.2,0.8,0.6,0.25))
	FX.floor_marks(canvas,model,elapsed)

func draw_air(canvas: Node2D) -> void:
	for i in 90:
		var p := Vector2(fposmod(i*109.3-elapsed*230,1220)-30,fposmod(i*67.1+elapsed*650,760)-40)
		canvas.draw_line(p,p+Vector2(-11,29),Color(0.65,0.83,0.91,0.19),1,true)
	for i in 11:
		if model.sunk_at[i] < 0.0: continue
		var age: float = model.clock-model.sunk_at[i]
		if age > 3.5: continue
		var center := fleet[i].position
		canvas.draw_set_transform(center,0,Vector2(1,0.36))
		canvas.draw_arc(Vector2.ZERO,32+age*30,0,TAU,40,Color(0.76,0.95,1,1.0-age/3.5),4,true)
		canvas.draw_set_transform(Vector2.ZERO)
		for j in 7:
			var particle := center+Vector2((j-3)*age*19,-sin(minf(age/2.0,1)*PI)*45+j%2*8)
			canvas.draw_line(particle,particle+Vector2(7,-12),Color(0.72,0.89,0.95,1-age/3.5),3,true)
	FX.water(canvas,model,elapsed)
	if wood_clock > 0:
		var age: float = 1.2-wood_clock
		for i in 22:
			var at := MODEL.MAST+Vector2(sin(i*9.1)*age*170,-110-cos(i)*age*160+age*age*150)
			canvas.draw_line(at,at+Vector2(10,16).rotated(i),Color(0.55,0.34,0.16,wood_clock/1.2),4,true)
	if model.phase in [MODEL.Phase.ESCAPING,MODEL.Phase.COMPLETE]:
		var start: Vector2 = model.position-Vector2(0,100) if escape_amount < 1 else escape_ship.position
		for j in 14:
			var points := PackedVector2Array()
			for i in 26:
				var x: float = i*34.0
				points.append(start+Vector2(x,sin(x*0.014-elapsed*7+j*0.4)*(12+j*3)+(j-7)*5))
			canvas.draw_polyline(points,Color(0.54,0.97,0.95,0.25+sin(j)*0.13),2,true)
