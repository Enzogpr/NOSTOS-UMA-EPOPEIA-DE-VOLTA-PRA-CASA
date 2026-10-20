extends Node2D
## Shared side-on camera, physical ship geometry and character animation.
const MODEL := preload("res://Ato4_Tempestade/Gameplay/PoseidonEscapeModel.gd")
const RIG := preload("res://Ato4_Tempestade/Cutscenes/LuckStage.gd")
const BOAT := preload("res://Assets/act4_poseidon_escape/traversal_ship.png")
const WALK := preload("res://Assets/act4_poseidon_escape/odysseus_escape_v2.png")
const AIR := preload("res://Assets/act4_poseidon_escape/odysseus_jump_v2.png")
const CROUCH := preload("res://Assets/act4_poseidon_escape/odysseus_crouch.png")
const SEA := preload("res://Assets/act4_released_winds/storm_open_sea.png")
const SMALL_SHIP := preload("res://Assets/act4_storm/ship_harpoon_side.png")
const BAG := preload("res://Assets/act4_friends/wind_bag.png")
const WAVE := preload("res://Assets/act4_storm/wave_front.png")
const WATER_ACTING := preload("res://Ato4_Tempestade/Gameplay/PoseidonWaterAttack.gd")
var debris_texture: Texture2D
var model: MODEL
var world: Node2D
var geometry: Geometry
var foreground: Foreground
var sea: Sprite2D
var horse: RIG.Performer
var distant_ship: Sprite2D
var odysseus: Sprite2D
var elapsed := 0.0
var stride := 0.0
var focus := 350.0
var camera_zoom := 1.0
var camera_y := 0.0
var font: Font
const WALK_RECTS := [Rect2(0,0,410,350),Rect2(411,0,384,350),Rect2(795,0,384,350),Rect2(1179,0,357,350)]
const WALK_FEET := [Vector2(270,344),Vector2(209,344),Vector2(235,344),Vector2(229,344)]
const AIR_RECTS := [Rect2(0,0,768,512),Rect2(768,0,768,480),Rect2(0,512,768,512)]
const AIR_FEET := [Vector2(380,470),Vector2(402,430),Vector2(440,458)]

class Geometry extends Node2D:
	var director: Node2D
	func _draw() -> void: director.draw_world(self)

class Foreground extends Node2D:
	var director: Node2D
	func _draw() -> void: director.draw_foreground(self)

func _ready() -> void:
	font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://Assets/act4_poseidon_escape/platform_wrecks.png"):
		debris_texture = load("res://Assets/act4_poseidon_escape/platform_wrecks.png")
	sea = Sprite2D.new()
	sea.texture = SEA
	sea.position = Vector2(576,324)
	sea.scale = Vector2(1280,720)/SEA.get_size()
	var water := ShaderMaterial.new()
	water.shader = preload("res://Assets/act4_storm/storm_water.gdshader")
	sea.material = water
	add_child(sea)
	distant_ship = Sprite2D.new()
	distant_ship.texture = SMALL_SHIP
	distant_ship.scale = Vector2(130,72)/SMALL_SHIP.get_size()
	add_child(distant_ship)
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_poseidon/regions.json"))
	horse = RIG.Performer.new(metadata,"horse")
	horse.height = 530
	horse.position = Vector2(960,355)
	add_child(horse)
	horse.pose(5)
	world = Node2D.new()
	add_child(world)
	geometry = Geometry.new()
	geometry.director = self
	world.add_child(geometry)
	odysseus = Sprite2D.new()
	odysseus.region_enabled = true
	odysseus.region_filter_clip_enabled = true
	odysseus.centered = false
	world.add_child(odysseus)
	foreground = Foreground.new()
	foreground.director = self
	world.add_child(foreground)
	update_visuals(0)

func reset_camera() -> void:
	focus = clampf(model.position.x+175,576,model.final_origin+560)
	camera_zoom = 0.88 if model.phase == MODEL.Phase.FINAL_SHIP else 1.0

func _process(dt: float) -> void:
	update_visuals(dt)

func update_visuals(dt: float) -> void:
	if model == null or not is_instance_valid(world): return
	elapsed += dt
	var final: bool = model.phase == MODEL.Phase.FINAL_SHIP or (model.phase == MODEL.Phase.FAILED and model.checkpoint.get("phase") == MODEL.Phase.FINAL_SHIP)
	var target_focus: float = model.final_origin+540 if final else clampf(model.position.x+190*model.facing,576,model.final_origin+560)
	var recent_sink := false
	for i in 10:
		if model.sunk_at[i] >= 0 and model.clock-model.sunk_at[i] < 1.0:
			recent_sink = true
			if not final: target_focus -= 90
	# A bounded look-ahead keeps the next landing visible, including when backing up.
	if absf(target_focus-focus) > 40: focus = lerpf(focus,target_focus,1-exp(-dt*5))
	camera_zoom = lerpf(camera_zoom,0.88 if final else 0.9 if recent_sink else 1.0,1-exp(-dt*3))
	camera_y = lerpf(camera_y,clampf(245-model.position.y,0,65),1-exp(-dt*3))
	world.scale = Vector2.ONE*camera_zoom
	var shake: float = minf(model.impact_flash*4,2.5)
	world.position = Vector2(576-focus*camera_zoom,475-475*camera_zoom+camera_y)+Vector2(sin(elapsed*63),cos(elapsed*57))*shake
	(sea.material as ShaderMaterial).set_shader_parameter("storm_clock",elapsed)
	var sunk_age: float = model.clock-model.sunk_at[10] if model.sunk_at[10] >= 0 else -1
	distant_ship.position = Vector2(350+sin(elapsed*0.5)*4,237+sin(elapsed*1.4)*4+maxf(0,sunk_age)*24)
	distant_ship.rotation = maxf(0,sunk_age)*0.25
	distant_ship.modulate = Color(0.67,0.82,0.9,1-smoothstep(0,3.5,sunk_age) if sunk_age >= 0 else 0.8)
	var water_pose := 5
	for hazard in model.hazards:
		if hazard.age >= hazard.warning and hazard.age-hazard.warning < 0.65:
			water_pose = 4 if hazard.kind == "slam" else 3
	horse.pose(water_pose)
	horse.position = Vector2(975+sin(elapsed*0.17)*30,357+sin(elapsed*1.2)*7)
	_update_actor(dt)
	geometry.queue_redraw()
	foreground.queue_redraw()

func _update_actor(dt: float) -> void:
	var moving: bool = absf(model.velocity.x) > 18 and model.grounded
	if moving: stride += dt*absf(model.velocity.x)/24.0
	var frame: int = int(stride)%4 if moving else 1
	odysseus.texture = WALK
	odysseus.region_rect = WALK_RECTS[frame]
	odysseus.offset = -WALK_FEET[frame]
	odysseus.scale = Vector2(0.245*model.facing,0.245)
	if model.has_bag:
		odysseus.region_rect.position.y = 350
		odysseus.region_rect.size.y = 340
		odysseus.offset.y = -335
	if not model.grounded:
		var air_frame: int = 0 if model.velocity.y < -360 else 1 if model.velocity.y < 170 else 2
		odysseus.texture = AIR
		odysseus.region_rect = AIR_RECTS[air_frame]
		odysseus.offset = -AIR_FEET[air_frame]
		odysseus.scale = Vector2(0.205*model.facing,0.205)
	elif model.crouching:
		var low: int = 1+int(stride)%2 if moving else 0
		odysseus.texture = CROUCH
		odysseus.region_rect = Rect2((low%2)*768,(low/2)*512,768,512)
		odysseus.offset = -Vector2(430 if low == 2 else 445,440 if low == 2 else 475)
		odysseus.scale = Vector2(0.15*model.facing,0.15)
	elif model.landing_flash > 0:
		odysseus.texture = AIR
		odysseus.region_rect = AIR_RECTS[2]
		odysseus.offset = -AIR_FEET[2]
		odysseus.scale = Vector2(0.205*model.facing,0.205)
	odysseus.position = model.position
	odysseus.rotation = 0
	odysseus.modulate = Color(1,0.55,0.45,0.75) if model.hit_flash > 0 else Color(1,1,1,0.6 if model.invulnerable > 0 and sin(elapsed*35)>0 else 1)
	odysseus.visible = model.phase not in [MODEL.Phase.ESCAPING,MODEL.Phase.COMPLETE]

func _plank(canvas: Node2D, rect: Rect2, tint := Color.WHITE) -> void:
	canvas.draw_texture_rect_region(BOAT,rect,Rect2(330,653,700,66),tint)
	canvas.draw_line(rect.position,Vector2(rect.end.x,rect.position.y),Color(0.85,0.72,0.43),2,true)

func _text(canvas: Node2D, at: Vector2, text: String, color := Color(0.93,0.87,0.67), font_size: int = 15) -> void:
	canvas.draw_string(font,at+Vector2(1,2),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(0.01,0.03,0.04,0.95))
	canvas.draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw_floating_wreck(canvas: Node2D, rect: Rect2, frame: int, submerge: float = 0.0) -> void:
	# The top of the painted timber agrees with the floor collider. Its underside
	# is submerged instead of exposing a whole dry cutout over the ocean image.
	var selected: int = posmod(frame,4)
	var width: float = rect.size.x+16
	var water_y: float = model.water_height_at(rect.get_center().x,model.clock)
	# A sinking collider continues down through the same water plane. Its art
	# is clipped progressively at that plane instead of taking the sea with it.
	water_y -= submerge*0.5
	var edge: float = [215.0,215.0,190.0,200.0][selected]
	var region := Rect2((selected%2)*768,(selected/2)*512,768,512)
	var shape := Rect2(rect.position-Vector2(8,edge*width/768),Vector2(width,width*512/768))
	if debris_texture != null:
		var above_height: float = maxf(0,water_y-shape.position.y)
		var source_height: float = above_height*768.0/width
		canvas.draw_texture_rect_region(debris_texture,Rect2(shape.position,Vector2(width,above_height)),Rect2(region.position,Vector2(768,source_height)),Color(0.76,0.82,0.78))
		# Texture clipping, rather than an opaque coloured rectangle, submerges
		# the underside while preserving the painted water beneath the timber.
		canvas.draw_texture_rect_region(debris_texture,Rect2(shape.position+Vector2(0,above_height),Vector2(width,11)),Rect2(region.position+Vector2(0,source_height),Vector2(768,11*768.0/width)),Color(0.15,0.39,0.43,0.28))
	else:
		_plank(canvas,Rect2(rect.position,Vector2(rect.size.x,24)),Color(0.7,0.76,0.74))
	# The visible upper edge stays at rect.y and never rolls independently of it.
	var contact := PackedVector2Array()
	for i in 17:
		var u: float = i/16.0
		var x: float = lerpf(rect.position.x-12,rect.end.x+12,u)
		var y: float = water_y+sin(u*TAU*1.5-elapsed*2.8)*1.5
		contact.append(Vector2(x,y))
	canvas.draw_polyline(contact,Color(0.54,0.77,0.78,0.64),2.5,true)
	for side in [-1.0,1.0]:
		var center := Vector2(rect.get_center().x+side*(rect.size.x*0.5+6),water_y+2)
		var foam := PackedVector2Array()
		for i in 10:
			var u: float = i/9.0
			foam.append(center+Vector2(side*u*37,sin(u*PI)*7+sin(elapsed*2+u*4)*1.3))
		canvas.draw_polyline(foam,Color(0.73,0.87,0.85,0.6),2.2,true)
	# Short wet glints remain attached to the timber, never a neon landing bar.
	for i in 3:
		var start := Vector2(rect.position.x+rect.size.x*(0.15+i*0.27),water_y+5+i%2*4)
		canvas.draw_line(start,start+Vector2(10+sin(elapsed*1.7+i)*3,0),Color(0.56,0.77,0.79,0.4),1.5,true)

func _draw_rigging_support(canvas: Node2D, rect: Rect2, deck: Rect2) -> void:
	# Raised ledges are working scaffold decks: vertical posts and a diagonal
	# brace terminate on the same ship's deck, never on a universal y=470 plane.
	var feet := [rect.position.x+12,rect.end.x-12]
	for x in feet:
		canvas.draw_line(Vector2(x,rect.position.y+8),Vector2(x,deck.position.y+11),Color(0.25,0.19,0.12),9,true)
		canvas.draw_line(Vector2(x+1.5,rect.position.y+8),Vector2(x+1.5,deck.position.y+10),Color(0.55,0.42,0.22),2,true)
	canvas.draw_line(Vector2(feet[0],deck.position.y+5),Vector2(feet[1],rect.position.y+12),Color(0.36,0.27,0.15),6,true)

func _draw_hanging_yard(canvas: Node2D, rect: Rect2, deck: Rect2) -> void:
	# Mast anchor is derived from the existing ship texture's mast coordinate.
	# Both ropes visibly end at its collar instead of stopping in empty space.
	var ship_scale: float = (deck.size.x+38)/1536.0
	var collar := Vector2(deck.position.x-19+835*ship_scale,deck.position.y-315*ship_scale)
	for u in [0.12,0.88]:
		var endpoint := Vector2(lerpf(rect.position.x,rect.end.x,u),rect.position.y+4)
		canvas.draw_line(collar,endpoint,Color(0.13,0.12,0.085),5,true)
		canvas.draw_line(collar+Vector2(1,0),endpoint+Vector2(1,0),Color(0.63,0.51,0.3),2.2,true)
	canvas.draw_circle(collar,4,Color(0.71,0.56,0.27))
	if debris_texture != null:
		canvas.draw_texture_rect_region(debris_texture,rect.grow(3),Rect2(35,690,720,106),Color(0.73,0.75,0.65))
	else:
		_plank(canvas,rect,Color(0.7,0.67,0.54))
	for u in [0.12,0.88]:
		var x: float = lerpf(rect.position.x,rect.end.x,u)
		for coil in 4:
			canvas.draw_line(Vector2(x+coil*2-3,rect.position.y-1),Vector2(x+coil*2-3,rect.end.y+1),Color(0.7,0.59,0.38),1.5,true)

func _draw_near_water(canvas: Node2D) -> void:
	# The model supplies one coherent ocean surface. Floating floors follow it;
	# neither individual water pillars nor visual-only bobbing support the wrecks.
	var boundary := PackedVector2Array()
	for i in 101:
		var x: float = focus-900+i*18
		boundary.append(Vector2(x,model.water_height_at(x,model.clock)))
	var water := boundary.duplicate()
	water.append(Vector2(focus+900,740))
	water.append(Vector2(focus-900,740))
	canvas.draw_colored_polygon(water,Color(0.025,0.12,0.16,0.46))
	canvas.draw_polyline(boundary,Color(0.43,0.65,0.69,0.32),2,true)
	for band in 3:
		var flow := PackedVector2Array()
		for i in boundary.size():
			var p: Vector2 = boundary[i]+Vector2(0,13+band*17+sin(i*0.31-elapsed*1.9+band)*3)
			flow.append(p)
		canvas.draw_polyline(flow,Color(0.18,0.4,0.46,0.18-band*0.035),5,true)

func draw_world(canvas: Node2D) -> void:
	if model.phase in [MODEL.Phase.ESCAPING,MODEL.Phase.COMPLETE]:
		_draw_escape(canvas)
		return
	var min_x: float = focus-800
	var max_view: float = focus+800
	for i in model.boats.size():
		var r: Rect2 = model.boats[i].rect
		if r.end.x < min_x or r.position.x > max_view: continue
		var age: float = model.clock-model.sunk_at[i] if i < 10 and model.sunk_at[i] >= 0 else -1
		if age >= 4: continue
		var width: float = r.size.x+38
		var scale_value: float = width/1536.0
		var picture := Rect2(r.position.x-19,r.position.y-636*scale_value,width,1024*scale_value)
		if age < 0:
			if i == 10 and model.mast_broken:
				canvas.draw_texture_rect_region(BOAT,Rect2(picture.position+Vector2(0,510*scale_value),Vector2(width,514*scale_value)),Rect2(0,510,1536,514))
			else: canvas.draw_texture_rect(BOAT,picture,false,Color(0.87,0.92,0.96) if i < 10 else Color.WHITE)
			_plank(canvas,Rect2(r.position,Vector2(r.size.x,14)))
			var label: String = "ODISSEU · BOLSA DOS VENTOS" if i == 10 else "%02d" % (i+1)
			_text(canvas,Vector2(r.position.x+20,r.position.y+44),label,Color(1,0.83,0.4),17 if i == 10 else 14)
		else:
			for half in 2:
				var direction: float = -1 if half == 0 else 1
				canvas.draw_set_transform(picture.get_center()+Vector2(direction*age*40,age*50),direction*age*0.16)
				canvas.draw_texture_rect_region(BOAT,Rect2(Vector2(-width/2+half*width/2,-picture.size.y/2),Vector2(width/2,picture.size.y)),Rect2(half*768,0,768,1024),Color(1,1,1,1-smoothstep(1,4,age)))
			canvas.draw_set_transform(Vector2.ZERO)
			for splash in 3:
				var at := Vector2(lerpf(r.position.x,r.end.x,(splash+1)/4.0),model.water_height_at(r.get_center().x,model.clock))
				WATER_ACTING.draw_splash(canvas,at,age-splash*0.12,1.4)
	for i in model.platforms.size():
		var p: Dictionary = model.platforms[i]
		if p.gone or p.kind == "deck": continue
		var r: Rect2 = model.platform_rect(i)
		if r.end.x < min_x or r.position.x > max_view: continue
		if p.kind == "wreck":
			var submerge: float = clampf((model.clock-float(p.drop_at))/0.6,0,1) if p.drop_at >= 0 else 0.0
			_draw_floating_wreck(canvas,r,i-11,submerge)
		else:
			if p.kind == "rigging": _draw_rigging_support(canvas,r,model.boats[int(p.boat)].rect)
			_plank(canvas,Rect2(r.position,Vector2(r.size.x,18)),Color(0.78,0.75,0.61))
	for obstacle in model.obstacles:
		if model.sunk_at[obstacle.boat] >= 0: continue
		var r: Rect2 = obstacle.rect
		if r.end.x < min_x or r.position.x > max_view: continue
		if obstacle.kind == "crate":
			_plank(canvas,r,Color(0.8,0.73,0.62))
			canvas.draw_rect(r,Color(0.34,0.22,0.12),false,3)
			canvas.draw_line(r.position,r.end,Color(0.76,0.57,0.3),5,true)
			canvas.draw_line(Vector2(r.end.x,r.position.y),Vector2(r.position.x,r.end.y),Color(0.76,0.57,0.3),5,true)
		else:
			_draw_hanging_yard(canvas,r,model.boats[int(obstacle.boat)].rect)
	if focus > model.final_origin-700: _draw_final(canvas)
	if model.phase in [MODEL.Phase.ESCAPING,MODEL.Phase.COMPLETE]: _draw_escape(canvas)

func _draw_final(canvas: Node2D) -> void:
	for i in 3:
		var at: Vector2 = model.binding_points[i]
		var done: bool = model.bindings[i] >= 1
		canvas.draw_circle(at-Vector2(0,18),15,Color(0.11,0.25,0.28,0.9))
		canvas.draw_arc(at-Vector2(0,18),15,-PI/2,-PI/2+TAU*maxf(0.02,model.bindings[i]),24,Color(0.44,1,0.77),3,true)
		_text(canvas,at+Vector2(-7,-12),"✓" if done else str(i+1),Color(0.4,1,0.8) if done else Color(1,0.84,0.4),18)
		if not done: canvas.draw_line(at-Vector2(0,20),model.bag_point-Vector2(0,30),Color(0.84,0.69,0.37,0.6),2,true)
	if not model.has_bag:
		canvas.draw_texture_rect(BAG,Rect2(model.bag_point-Vector2(25,52),Vector2(50,50)),false)
		_text(canvas,model.bag_point-Vector2(42,68),"BOLSA DOS VENTOS",Color(1,0.85,0.42),14)
	if model.has_bag:
		var at: Vector2 = model.exit_point
		canvas.draw_arc(at-Vector2(0,16),28,0,TAU,32,Color(0.43,1,0.88),3,true)
		_text(canvas,at-Vector2(30,60),"LIBERE AQUI",Color(0.62,1,0.9),15)
	if model.mast_broken:
		var rect := Rect2(model.final_origin+480,444,195,20)
		_plank(canvas,rect,Color(0.6,0.56,0.48))

func draw_foreground(canvas: Node2D) -> void:
	_draw_near_water(canvas)
	for h in model.hazards:
		var r: Rect2 = model.hazard_rect(h)
		if r.end.x < focus-850 or r.position.x > focus+850: continue
		WATER_ACTING.draw(canvas,h,r,elapsed,MODEL.WATER_SURFACE_Y)
	for i in 50:
		var p := Vector2(focus-750+fposmod(i*109.0-elapsed*210,1500),fposmod(i*67.0+elapsed*680,700))
		canvas.draw_line(p,p+Vector2(-7,20),Color(0.62,0.85,0.95,0.17),1,true)

func _draw_escape(canvas: Node2D) -> void:
	var age: float = minf(4.8,model.phase_clock) if model.phase == MODEL.Phase.ESCAPING else 4.8
	var center := Vector2(model.final_origin+480-age*230,420-age*12)
	var dimensions := Vector2(460,255)*(1-smoothstep(1,4.8,age)*0.35)
	canvas.draw_texture_rect(SMALL_SHIP,Rect2(center-dimensions/2,dimensions),false)
	for j in 9:
		var points := PackedVector2Array()
		for i in 24: points.append(center+Vector2(i*35,sin(i*0.4-elapsed*8+j)*15+j*6))
		canvas.draw_polyline(points,Color(0.62,1,0.97,0.3),2,true)
