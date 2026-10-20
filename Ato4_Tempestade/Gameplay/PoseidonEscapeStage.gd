extends Node2D
## Shared side-on camera, textured geometry, telegraphs and animation for both parts.
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
	horse.pose(4 if model.impact_flash > 0.28 else 3 if not model.grounded else 5)
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
			if i < 10 and model.boats[i].collapse >= 0:
				var left: float = model.boats[i].collapse-model.clock
				canvas.draw_rect(Rect2(r.position-Vector2(0,5),Vector2(r.size.x,7)),Color(1,0.32,0.16,0.45+sin(elapsed*16)*0.3))
				_text(canvas,r.position+Vector2(r.size.x*0.32,-115),"SAIA DO NAVIO! %.1fs" % maxf(0,left),Color(1,0.65,0.34),18)
		else:
			for half in 2:
				var direction: float = -1 if half == 0 else 1
				canvas.draw_set_transform(picture.get_center()+Vector2(direction*age*40,age*50),direction*age*0.16)
				canvas.draw_texture_rect_region(BOAT,Rect2(Vector2(-width/2+half*width/2,-picture.size.y/2),Vector2(width/2,picture.size.y)),Rect2(half*768,0,768,1024),Color(1,1,1,1-smoothstep(1,4,age)))
			canvas.draw_set_transform(Vector2.ZERO)
			var foam := Rect2(r.position-Vector2(20,90)+Vector2(0,age*18),Vector2(r.size.x+40,180))
			canvas.draw_texture_rect(WAVE,foam,false,Color(0.8,0.94,1,sin(PI*clampf(age/4,0,1))*0.8))
	for i in model.platforms.size():
		var p: Dictionary = model.platforms[i]
		if p.gone or p.kind == "deck": continue
		var r: Rect2 = model.platform_rect(i)
		if r.end.x < min_x or r.position.x > max_view: continue
		if p.kind == "wreck" and debris_texture != null:
			var frame: int = (i-11)%4
			var region := Rect2((frame%2)*768,(frame/2)*512,768,512)
			var edge: float = [215.0,215.0,190.0,200.0][frame]
			var width: float = r.size.x+16
			canvas.draw_texture_rect_region(debris_texture,Rect2(r.position-Vector2(8,edge*width/768),Vector2(width,width*512/768)),region)
			canvas.draw_line(r.position,Vector2(r.end.x,r.position.y),Color(0.83,0.72,0.48),2,true)
		else: _plank(canvas,Rect2(r.position,Vector2(r.size.x,18)))
		if p.kind == "rigging":
			for side in [0.12,0.88]:
				var x: float = r.position.x+r.size.x*side
				canvas.draw_line(Vector2(x,470),Vector2(x,r.position.y+8),Color(0.4,0.26,0.13),8,true)
				canvas.draw_line(Vector2(x+2,470),Vector2(x+2,r.position.y+8),Color(0.67,0.49,0.25),2,true)
		if p.kind == "wreck" and p.touched >= 0 and model.clock-p.touched > 2.8:
			canvas.draw_line(r.position-Vector2(0,2),Vector2(r.end.x,r.position.y-2),Color(1,0.37,0.16,0.5+sin(elapsed*18)*0.4),4,true)
	for obstacle in model.obstacles:
		if model.sunk_at[obstacle.boat] >= 0: continue
		var r: Rect2 = obstacle.rect
		if r.end.x < min_x or r.position.x > max_view: continue
		_plank(canvas,r,Color(0.8,0.73,0.62))
		if obstacle.kind == "crate":
			canvas.draw_rect(r,Color(0.34,0.22,0.12),false,3)
			canvas.draw_line(r.position,r.end,Color(0.76,0.57,0.3),5,true)
			canvas.draw_line(Vector2(r.end.x,r.position.y),Vector2(r.position.x,r.end.y),Color(0.76,0.57,0.3),5,true)
		else:
			_text(canvas,r.position-Vector2(0,10),"↓ ABAIXE",Color(0.64,0.91,1),14)
			canvas.draw_line(Vector2(r.position.x,r.position.y-100),r.position,Color(0.58,0.5,0.32),3,true)
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
	for h in model.hazards:
		var r: Rect2 = model.hazard_rect(h)
		if h.age < h.warning:
			var color := Color(1,0.43,0.2,0.2+sin(elapsed*15)*0.1)
			if h.kind == "slam":
				canvas.draw_rect(r,color)
				canvas.draw_line(Vector2(h.target,r.position.y),Vector2(h.target,r.end.y),Color(1,0.68,0.28),2,true)
				_text(canvas,Vector2(h.target-55,r.end.y-50),"SAIA DA MARCA",Color(1,0.76,0.4),15)
			else:
				var deck: Rect2 = model.boats[h.boat].rect
				var y: float = r.position.y+15
				for x in range(int(deck.position.x),int(deck.end.x),48): canvas.draw_line(Vector2(x,y),Vector2(x+20,y),Color(0.63,0.93,1,0.65),2,true)
				_text(canvas,Vector2(deck.position.x+50,y-20),"↑ PULE" if h.kind == "low" else "↓ ABAIXE",Color(0.67,0.96,1),20)
		else:
			var live: bool = h.age-h.warning < (0.33 if h.kind == "slam" else 3.3)
			if not live: continue
			if h.kind == "slam":
				canvas.draw_rect(r,Color(0.5,0.91,1,0.7))
				for j in 7: canvas.draw_line(Vector2(r.position.x+j*13,r.position.y),Vector2(r.position.x+j*13,r.end.y),Color(0.83,0.98,1,0.8),4,true)
			else:
				canvas.draw_texture_rect(WAVE,r.grow(4),false,Color(0.55,0.91,1,0.86))
				for j in 3:
					var foam := PackedVector2Array()
					for k in 12:
						foam.append(r.position+Vector2(k*7,sin(k*0.6+elapsed*11+j)*4+5+j*9))
					canvas.draw_polyline(foam,Color(0.78,0.98,1,0.8-j*0.15),2,true)
	for i in 50:
		var p := Vector2(focus-750+fposmod(i*109.0-elapsed*210,1500),fposmod(i*67.0+elapsed*680,700))
		canvas.draw_line(p,p+Vector2(-7,20),Color(0.62,0.85,0.95,0.17),1,true)
	# Waterline is drawn below every playable surface, never over the character.
	var foam_points := PackedVector2Array()
	for i in 60: foam_points.append(Vector2(focus-800+i*28,MODEL.SEA_LEVEL+sin(i*0.7+elapsed*3)*5))
	canvas.draw_polyline(foam_points,Color(0.55,0.83,0.9,0.4),4,true)

func _draw_escape(canvas: Node2D) -> void:
	var age: float = minf(4.8,model.phase_clock) if model.phase == MODEL.Phase.ESCAPING else 4.8
	var center := Vector2(model.final_origin+480-age*230,420-age*12)
	var dimensions := Vector2(460,255)*(1-smoothstep(1,4.8,age)*0.35)
	canvas.draw_texture_rect(SMALL_SHIP,Rect2(center-dimensions/2,dimensions),false)
	for j in 9:
		var points := PackedVector2Array()
		for i in 24: points.append(center+Vector2(i*35,sin(i*0.4-elapsed*8+j)*15+j*6))
		canvas.draw_polyline(points,Color(0.62,1,0.97,0.3),2,true)
