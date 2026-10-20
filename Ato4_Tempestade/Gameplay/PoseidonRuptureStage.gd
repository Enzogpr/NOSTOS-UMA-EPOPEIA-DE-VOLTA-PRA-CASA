extends "res://Ato4_Tempestade/Gameplay/PoseidonEscapeStage.gd"
## Direction for the rupture slice. Surface endpoints are the physics model's API;
## ship art, the moving mast and warnings never invent an extra landing surface.
const DIVINE_ACTING := preload("res://Assets/act4_poseidon/acting.gdshader")
var encounter: Variant
var god: RIG.Performer
var atmosphere: Atmosphere
var shot_clock := 0.0
var displayed_presence := 0.0
var last_state := ""

class Atmosphere extends Node2D:
	var director: Node2D
	func _draw() -> void: director.draw_atmosphere(self)

func _ready() -> void:
	encounter = model
	super._ready()
	distant_ship.hide()
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_poseidon/regions.json"))
	god = RIG.Performer.new(metadata,"poseidon")
	god.height = 610
	add_child(god)
	move_child(god,sea.get_index()+1)
	for sprite in god.sprites:
		var material := ShaderMaterial.new()
		material.shader = DIVINE_ACTING
		sprite.material = material
	god.pose(0)
	for sprite in horse.sprites:
		var material := ShaderMaterial.new()
		material.shader = DIVINE_ACTING
		sprite.material = material
	horse.height = 455
	horse.pose_index = -1
	horse.pose(5)
	atmosphere = Atmosphere.new()
	atmosphere.director = self
	add_child(atmosphere)
	move_child(atmosphere,world.get_index())
	focus = 576
	camera_zoom = 1.0
	update_visuals(0)

func reset_camera() -> void:
	encounter = model
	focus = clampf(model.position.x+180,576,5100)
	camera_zoom = 1.0
	camera_y = 0.0
	displayed_presence = 0.0

func update_visuals(dt: float) -> void:
	if model == null or not is_instance_valid(world): return
	encounter = model
	elapsed += dt
	shot_clock += dt
	var state: String = encounter.encounter_state
	if last_state != state:
		last_state = state
		shot_clock = 0.0
	# The rupture is a shared wide composition: the destroyed bow and the retreat
	# shelter remain readable together. Camera motion cannot erase the retreat.
	var target_focus: float = clampf(model.position.x+200,576,5050)
	var target_zoom := 1.0
	if state in ["fracture","retreat","mast_fall"]:
		target_focus = 625.0
		target_zoom = 0.88
	elif state == "crossing" and model.position.x < 1420:
		target_focus = maxf(680.0,model.position.x+190)
		target_zoom = 0.94
	elif state == "pursuit":
		target_focus = model.position.x+155
		target_zoom = 0.95
	elif state in ["safe","finished"]:
		target_focus = 4960
		target_zoom = 1.0
	if dt <= 0:
		focus = target_focus
		camera_zoom = target_zoom
	else:
		focus = lerpf(focus,target_focus,1-exp(-dt*3.2))
		camera_zoom = lerpf(camera_zoom,target_zoom,1-exp(-dt*2.6))
	# Vertical framing keeps elevated fragments and the next landing in view.
	var y_target: float = clampf(315.0-model.position.y,0,85)
	camera_y = lerpf(camera_y,y_target,1-exp(-dt*2.5))
	world.scale = Vector2.ONE*camera_zoom
	var shake: float = minf(model.impact_flash*3.0,2.5)
	world.position = Vector2(576-focus*camera_zoom,475-475*camera_zoom+camera_y)+Vector2(sin(elapsed*49),cos(elapsed*41))*shake
	(sea.material as ShaderMaterial).set_shader_parameter("storm_clock",elapsed)
	sea.modulate = Color(0.54,0.69,0.75).lerp(Color(0.37,0.53,0.61),encounter.tension*0.45)
	_update_actor(dt)
	# This slice ends on an inhabited refuge, rather than the legacy escape boat.
	if state in ["safe","finished"]: odysseus.visible = true
	# Presence follows authored events, never the player's jump or landing.
	var desired_presence: float = clampf(encounter.god_presence,0,1)
	var divine_pose: int = 2 if state in ["fracture","retreat"] else 5 if state == "mast_fall" else 0
	if state == "pursuit":
		desired_presence = 0.0
		for hazard in model.hazards:
			if hazard.kind == "slam" and hazard.age < hazard.warning+0.65:
				desired_presence = 1.0
				divine_pose = 2 if hazard.age < hazard.warning else 4
	elif state in ["safe","finished"]: desired_presence = 0.0
	displayed_presence = lerpf(displayed_presence,desired_presence,1-exp(-dt*3.2)) if dt > 0 else desired_presence
	if is_instance_valid(god):
		god.visible = displayed_presence > 0.01
		god.position = Vector2(895+sin(elapsed*0.2)*8,650)
		god.modulate = Color(0.61,0.83,0.91,displayed_presence*0.78)
		god.pose(divine_pose)
		for sprite in god.sprites:
			(sprite.material as ShaderMaterial).set_shader_parameter("emergence",1.0)
			(sprite.material as ShaderMaterial).set_shader_parameter("tension",encounter.tension)
	if is_instance_valid(horse):
		var show_horse: bool = state in ["fracture","retreat"] or (state == "pursuit" and encounter.event_age < 2.5)
		horse.visible = show_horse
		horse.pose(4 if state == "fracture" else 3)
		horse.position = Vector2(735+sin(elapsed*0.5)*9,460+sin(elapsed*1.3)*5)
		horse.modulate = Color(0.51,0.79,0.88,0.72)
	geometry.queue_redraw()
	foreground.queue_redraw()
	if is_instance_valid(atmosphere): atmosphere.queue_redraw()

func draw_atmosphere(canvas: Node2D) -> void:
	if encounter == null: return
	# Screen-space horizon. Dark mass above, pale atmospheric separation beneath.
	for i in 8:
		canvas.draw_rect(Rect2(0,i*28,1152,30),Color(0.015,0.04,0.06,0.18*(1.0-i/10.0)))
	for band in 3:
		var horizon := PackedVector2Array()
		for k in 45:
			horizon.append(Vector2(k*28,295+band*34+sin(k*0.32+elapsed*0.45+band)*6))
		canvas.draw_polyline(horizon,Color(0.37,0.65,0.74,0.06+band*0.025),13,true)
	# Water vapour merges the divine body with the ocean rather than leaving
	# a full standing cutout floating over the distant horizon.
	for i in 12:
		canvas.draw_rect(Rect2(0,350+i*26,1152,28),Color(0.055,0.13,0.17,smoothstep(0,11,i)*0.68))
	# Far fleet stays below the horizon and never resembles a playable landing.
	for i in 5:
		var x: float = fposmod(125+i*263-focus*0.09,1390)-110
		var sinking: float = clampf((encounter.front_x-(680+i*540))/420.0,0,1) if encounter.front_active else 0.0
		var y: float = 316+i%2*15+sin(elapsed*0.8+i)*3+sinking*38
		canvas.draw_set_transform(Vector2(x,y),sinking*0.32)
		canvas.draw_texture_rect(SMALL_SHIP,Rect2(-45,-25,90,50),false,Color(0.31,0.49,0.57,0.4*(1-sinking)))
	canvas.draw_set_transform(Vector2.ZERO)

func _surface(canvas: Node2D, a: Vector2, b: Vector2, thickness: float, tint: Color) -> void:
	var length: float = a.distance_to(b)
	canvas.draw_set_transform(a,(b-a).angle())
	canvas.draw_texture_rect_region(BOAT,Rect2(0,0,length,thickness),Rect2(330,653,700,66),tint)
	canvas.draw_line(Vector2.ZERO,Vector2(length,0),Color(0.95,0.81,0.51),2,true)
	canvas.draw_set_transform(Vector2.ZERO)

func _boat_section(canvas: Node2D, rect: Rect2, left: float, right: float, displacement: Vector2, angle: float, alpha: float) -> void:
	var scale_value: float = (rect.size.x+38)/1536.0
	var top: float = rect.position.y-(653-510)*scale_value
	var source_left: float = clampf((left-(rect.position.x-19))/scale_value,0,1536)
	var source_width: float = (right-left)/scale_value
	var pivot := Vector2(left,rect.position.y)
	canvas.draw_set_transform(pivot+displacement,angle)
	canvas.draw_texture_rect_region(BOAT,Rect2(Vector2(0,top-rect.position.y),Vector2(right-left,514*scale_value)),Rect2(source_left,510,source_width,514),Color(0.61,0.68,0.68,alpha))
	canvas.draw_set_transform(Vector2.ZERO)

func draw_world(canvas: Node2D) -> void:
	if encounter == null: return
	var min_x: float = focus-850
	var max_x: float = focus+850
	# Water is drawn behind all collision surfaces. Its crest is the actual front_x.
	_draw_pursuit(canvas,false)
	for boat_index in model.boats.size():
		var rect: Rect2 = model.boats[boat_index].rect
		if rect.end.x < min_x or rect.position.x > max_x: continue
		var sink_age: float = model.clock-model.sunk_at[boat_index] if model.sunk_at[boat_index] >= 0 else -1
		if sink_age > 4.2: continue
		if boat_index == 0:
			_boat_section(canvas,rect,rect.position.x-19,805,Vector2.ZERO,0,1)
			var f: float = encounter.fracture
			_boat_section(canvas,rect,805,rect.end.x+19,Vector2(f*45,f*f*230),f*0.27,1-smoothstep(0.65,1.0,f))
			if f > 0: _rupture_spray(canvas,Vector2(808,475),f)
			if f > 0.3:
				for row in 7:
					var y: float = 490+row*17
					var edge := PackedVector2Array([Vector2(797,y),Vector2(813+row%3*4,y+5),Vector2(796,y+12)])
					canvas.draw_colored_polygon(edge,Color(0.39,0.26,0.1,f))
		else:
			var drop: float = maxf(0,sink_age)
			_boat_section(canvas,rect,rect.position.x-19,rect.end.x+19,Vector2(drop*13,drop*drop*27),drop*0.08,1-smoothstep(1,4.2,drop))
	# Platforms, including moving fragments and the diagonal mast, use exactly
	# the two model endpoints used by floor collision, never visual-only offsets.
	for i in model.platforms.size():
		var platform: Dictionary = model.platforms[i]
		if platform.get("gone",false): continue
		var ends: Array = encounter.surface_endpoints(i)
		if ends.size() < 2: continue
		var a: Vector2 = ends[0]
		var b: Vector2 = ends[1]
		if b.x < min_x or a.x > max_x: continue
		var kind: String = str(platform.kind)
		if kind == "ramp":
			if encounter.ramp_ready: _surface(canvas,a,b,18,Color(0.83,0.76,0.57))
		elif kind == "wreck" and debris_texture != null:
			var frame: int = i%4
			var texture_region := Rect2((frame%2)*768,(frame/2)*512,768,512)
			var width: float = a.distance_to(b)+18
			var edge: float = [215.0,215.0,190.0,200.0][frame]
			canvas.draw_set_transform(a,(b-a).angle())
			canvas.draw_texture_rect_region(debris_texture,Rect2(-9,-edge*width/768, width,width*512/768),texture_region,Color(0.73,0.81,0.81))
			canvas.draw_line(Vector2.ZERO,Vector2(a.distance_to(b),0),Color(0.93,0.82,0.54),2,true)
			canvas.draw_set_transform(Vector2.ZERO)
		else:
			if kind == "ledge":
				var deck: Rect2 = model.boats[int(platform.boat)].rect
				for side in [0.1,0.9]:
					var x: float = lerpf(a.x,b.x,side)
					canvas.draw_line(Vector2(x,a.y+10),Vector2(x,deck.position.y+12),Color(0.31,0.23,0.13),10,true)
					canvas.draw_line(Vector2(x+2,a.y+10),Vector2(x+2,deck.position.y+12),Color(0.62,0.47,0.25),2,true)
			_surface(canvas,a,b,16 if kind == "deck" else 22,Color(0.75,0.78,0.7))
	for obstacle in model.obstacles:
		if not obstacle.get("active",true) or obstacle.kind != "crate": continue
		var rect: Rect2 = obstacle.rect
		canvas.draw_rect(rect,Color(0.27,0.19,0.1))
		for row in 4:
			var y: float = rect.position.y+row*rect.size.y/4
			canvas.draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),Color(0.46,0.32,0.16),2,true)
		canvas.draw_rect(rect,Color(0.72,0.56,0.29),false,3)
		canvas.draw_line(rect.position,rect.end,Color(0.62,0.46,0.22),4,true)
		canvas.draw_line(Vector2(rect.end.x,rect.position.y),Vector2(rect.position.x,rect.end.y),Color(0.62,0.46,0.22),4,true)
	_draw_mast(canvas)
	_draw_sail(canvas)
	if encounter.encounter_state in ["safe","finished"]:
		_text(canvas,Vector2(4920,345),"UM INSTANTE PARA RESPIRAR",Color(0.67,0.86,0.84),16)

func _draw_mast(canvas: Node2D) -> void:
	if focus > 1950: return
	var origin: Vector2 = encounter.ramp_start
	var length: float = encounter.ramp_start.distance_to(encounter.ramp_end)
	# The pivot and length agree with the ramp collider. Only the settled mast
	# draws its broad walkable top; during the fall it is an animated object.
	var endpoint: Vector2 = origin+Vector2.from_angle(encounter.mast_angle)*length
	canvas.draw_line(origin+Vector2(4,4),endpoint+Vector2(4,4),Color(0.015,0.03,0.035,0.55),23,true)
	canvas.draw_set_transform(origin,encounter.mast_angle+PI/2)
	canvas.draw_texture_rect_region(BOAT,Rect2(-14,-length,28,length),Rect2(810,24,50,612),Color(0.76,0.82,0.8))
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_circle(origin,20,Color(0.23,0.19,0.11))
	canvas.draw_arc(origin,18,0,TAU,20,Color(0.68,0.53,0.26),4,true)
	if encounter.encounter_state == "mast_fall":
		for i in 5:
			var direction: Vector2 = Vector2.from_angle(-0.2-i*0.31)
			var distance_value: float = fposmod(encounter.event_age*160+i*31,170)
			var p: Vector2 = origin+direction*distance_value+Vector2(0,distance_value*distance_value/600)
			canvas.draw_line(p,p+direction*12,Color(0.68,0.49,0.24,0.75*(1-distance_value/170)),3,true)

func _draw_sail(canvas: Node2D) -> void:
	if focus > 1600 or encounter.sail_drop <= 0: return
	var amount: float = encounter.sail_drop
	var lower: float = lerpf(238,415,amount)
	var cloth := Rect2(490,200,140,lower-200)
	canvas.draw_line(Vector2(490,160),cloth.position,Color(0.54,0.43,0.26),4,true)
	canvas.draw_line(Vector2(630,160),Vector2(630,200),Color(0.54,0.43,0.26),4,true)
	canvas.draw_texture_rect_region(BOAT,cloth,Rect2(648,166,138,67),Color(0.88,0.84,0.71))
	canvas.draw_line(Vector2(490,lower),Vector2(630,lower),Color(0.98,0.75,0.45),5,true)
	for i in 5:
		var x: float = 502+i*25
		canvas.draw_line(Vector2(x,208),Vector2(x+sin(elapsed*2+i)*3,lower-5),Color(0.35,0.3,0.2,0.22),2,true)
	if amount > 0.8 and encounter.encounter_state in ["retreat","mast_fall"]:
		_text(canvas,Vector2(508,446),"↓",Color(0.78,0.95,1),24)

func _rupture_spray(canvas: Node2D, at: Vector2, fracture_value: float) -> void:
	var amount: float = sin(clampf(fracture_value,0,1)*PI)
	if amount < 0.01: return
	canvas.draw_texture_rect(WAVE,Rect2(at-Vector2(140,amount*150),Vector2(460,220+amount*130)),false,Color(0.64,0.89,0.95,amount*0.75))
	for i in 14:
		var direction: Vector2 = Vector2.from_angle(-PI+i*PI/15)
		var travel: float = fposmod(encounter.event_age*125+i*23,200)
		var p: Vector2 = at+direction*travel+Vector2(0,travel*travel/440)
		canvas.draw_line(p,p+direction*6,Color(0.82,0.95,1,amount*(1-travel/200)),2,true)

func _draw_pursuit(canvas: Node2D, front_only: bool) -> void:
	if not encounter.front_active: return
	var x: float = encounter.front_x
	var left: float = focus-900
	if x < left-150 or x > focus+900: return
	var edge := PackedVector2Array()
	for i in 23:
		var y: float = 122+i*25
		var curl: float = sin(i*0.38+elapsed*1.7)*20+sin(i*0.83-elapsed*3)*5
		edge.append(Vector2(x-34+curl,y))
	if front_only:
		for i in 16:
			var p: Vector2 = Vector2(x-45+sin(i*0.8+elapsed*4)*25,160+fposmod(i*41+elapsed*180,450))
			canvas.draw_line(p,p+Vector2(12,20),Color(0.8,0.95,1,0.45),2,true)
	else:
		var body := PackedVector2Array([Vector2(left,730),Vector2(left,95)])
		body.append_array(edge)
		body.append(Vector2(x,730))
		canvas.draw_colored_polygon(body,Color(0.015,0.11,0.15,0.93))
		# The original painted water front is mirrored so its foam approaches from
		# the left; the crest is aligned to front_x, with only spray extending ahead.
		canvas.draw_set_transform(Vector2(x+160,85),0,Vector2(-1,1))
		canvas.draw_texture_rect(WAVE,Rect2(0,0,720,650),false,Color(0.68,0.91,0.97,0.98))
		canvas.draw_set_transform(Vector2.ZERO)

func draw_foreground(canvas: Node2D) -> void:
	if encounter == null: return
	for h in model.hazards:
		var rect: Rect2 = model.hazard_rect(h)
		if rect.end.x < focus-850 or rect.position.x > focus+850: continue
		var warning: bool = h.age < h.warning
		if warning:
			var prepare: float = clampf(h.age/h.warning,0,1)
			if h.kind == "slam":
				canvas.draw_rect(rect,Color(0.55,0.83,0.91,0.06+prepare*0.1))
				canvas.draw_line(Vector2(rect.position.x,rect.end.y),rect.end,Color(0.98,0.72,0.38,0.8),4,true)
				for i in 8:
					var p := Vector2(rect.position.x+i*rect.size.x/8,rect.end.y-12-prepare*30)
					canvas.draw_line(p,p-Vector2(0,12),Color(0.58,0.88,0.96,prepare*0.6),2,true)
			else:
				canvas.draw_line(Vector2(rect.position.x,rect.position.y+rect.size.y/2),Vector2(rect.end.x,rect.position.y+rect.size.y/2),Color(0.53,0.86,0.93,0.3+prepare*0.5),3,true)
				var cue := "↑" if h.kind == "low" else "↓"
				_text(canvas,Vector2(clampf(model.position.x+130,rect.position.x+20,rect.end.x-25),rect.position.y-14),cue,Color(0.79,0.96,1),24)
		else:
			var live: bool = h.age-h.warning < (0.33 if h.kind == "slam" else 3.3)
			if not live: continue
			canvas.draw_texture_rect(WAVE,rect,false,Color(0.59,0.88,0.96,0.86))
			canvas.draw_line(rect.position,Vector2(rect.end.x,rect.position.y),Color(0.78,0.97,1,0.83),3,true)
	_draw_pursuit(canvas,true)
	var water := PackedVector2Array([Vector2(focus-900,760)])
	var foam := PackedVector2Array()
	for i in 65:
		var p := Vector2(focus-900+i*29,616+sin(i*0.5+elapsed*2.1)*6+sin(i*0.9-elapsed*2)*3)
		water.append(p)
		foam.append(p)
	water.append(Vector2(focus+960,760))
	canvas.draw_colored_polygon(water,Color(0.025,0.11,0.15,0.84))
	canvas.draw_polyline(foam,Color(0.44,0.7,0.75,0.48),3,true)
	# Rain density follows tension; no rain stripe obscures the playable contour.
	var count: int = 22+int(encounter.tension*22)
	for i in count:
		var p := Vector2(focus-800+fposmod(i*109.0-elapsed*115,1600),fposmod(i*67.0+elapsed*460,700))
		canvas.draw_line(p,p+Vector2(-5,15),Color(0.62,0.83,0.91,0.12),1,true)
