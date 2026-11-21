extends Node2D

## Terrain and decorations share the model's coordinates; no decorative platform
## can claim to be solid. The foreground never obscures the next landing.
const DASH_RECHARGE_BAR := preload("res://Code/DashRechargeBar.gd")
const BACKGROUND := preload("res://Assets/act5_circe/enchanted_forest.png")
const MODEL := preload("res://Ato5_Circe/Gameplay/CirceForestModel.gd")
const ATLAS := preload("res://Assets/act5_circe/forest_atlas.png")
const WALK := preload("res://Assets/act4_poseidon_escape/odysseus_escape_v2.png")
const AIR := preload("res://Assets/act4_poseidon_escape/odysseus_jump_v2.png")
const CROUCH := preload("res://Assets/act4_poseidon_escape/odysseus_crouch.png")
const MIRAGE := preload("res://Assets/act5_circe/illusion.gdshader")
const WALK_RECTS := [Rect2(0,0,410,350),Rect2(411,0,384,350),Rect2(795,0,384,350),Rect2(1179,0,357,350)]
const WALK_FEET := [Vector2(270,344),Vector2(209,344),Vector2(235,344),Vector2(229,344)]
const AIR_RECTS := [Rect2(0,0,768,512),Rect2(768,0,768,480),Rect2(0,512,768,512)]
const AIR_FEET := [Vector2(380,470),Vector2(402,430),Vector2(440,458)]
const GOLD := Color(0.98,0.82,0.45)
const VIOLET := Color(0.69,0.44,0.95)
var model: MODEL
var camera := Vector2(576,324)
var stride := 0.0
var return_glow := 0.0
var actor: Sprite2D
var dash_bar := DASH_RECHARGE_BAR.new()
var mirage_cards: Array[ColorRect] = []
var mirage_data: Array = []
var mirage_indices: Array[int] = []
var displayed_revelation := 0.0
var flower_lure: ColorRect

func _ready() -> void:
	actor = Sprite2D.new()
	actor.centered = false
	actor.region_enabled = true
	actor.region_filter_clip_enabled = true
	actor.z_index = 2
	add_child(actor)
	dash_bar.z_index = actor.z_index
	add_child(dash_bar)
	for index in model.level.platforms.size():
		var item: Array=model.level.platforms[index]
		if item[3]=="memory":
			mirage_data.append([item[0],item[1],item[2],true])
			mirage_indices.append(index)
	for item: Array in model.level.illusions:
		mirage_data.append([item[0],item[1],item[2],false])
		mirage_indices.append(-1)
	for i in mirage_data.size():
		var card:=ColorRect.new()
		card.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card.z_index=1
		var material:=ShaderMaterial.new()
		material.shader=MIRAGE
		material.set_shader_parameter("atlas",ATLAS)
		material.set_shader_parameter("true_path",mirage_data[i][3])
		material.set_shader_parameter("seed",float(i)*7.31)
		card.material=material
		add_child(card)
		mirage_cards.append(card)
	flower_lure=ColorRect.new()
	flower_lure.mouse_filter=Control.MOUSE_FILTER_IGNORE
	flower_lure.size=Vector2(128,145)
	flower_lure.z_index=1
	var flower_material:=ShaderMaterial.new()
	flower_material.shader=MIRAGE
	flower_material.set_shader_parameter("atlas",ATLAS)
	flower_material.set_shader_parameter("plant_form",true)
	flower_material.set_shader_parameter("seed",39.0)
	flower_lure.material=flower_material
	add_child(flower_lure)
	reset_camera()

func reset_camera() -> void:
	camera = Vector2(clampf(model.position.x + 140,576, float(model.level.width)-576),clampf(model.position.y - 216,140,324))
	update_visuals(0)

func world_to_screen(point: Vector2) -> Vector2:
	return point - camera + Vector2(576,324)

func update_visuals(delta: float) -> void:
	if model == null: return
	var target := Vector2(clampf(model.position.x + 120 * model.facing,576,float(model.level.width)-576),clampf(model.position.y-216,140,324))
	camera = camera.lerp(target, 1.0-exp(-delta*4.0)) if delta > 0 else camera
	return_glow = move_toward(return_glow,1.0 if model.has_flower else 0.0,delta*0.65)
	var reveal_target:=1.0 if model.focus_remaining>0 or model.has_flower else 0.0
	displayed_revelation=lerpf(displayed_revelation,reveal_target,1.0-exp(-delta*4.5)) if delta>0 else reveal_target
	for i in mirage_cards.size():
		var item: Array=mirage_data[i]
		if mirage_indices[i]>=0:
			var point:=model.surface_position(mirage_indices[i])
			item[0]=point.x
			item[1]=point.y
		var card:=mirage_cards[i]
		card.position=world_to_screen(Vector2(item[0],item[1]))-Vector2(24,28)
		card.size=Vector2(float(item[2])+48,100)
		card.visible=card.position.x>-300 and card.position.x<1252
		(card.material as ShaderMaterial).set_shader_parameter("simulation_clock",model.clock)
		(card.material as ShaderMaterial).set_shader_parameter("revelation",displayed_revelation)
	flower_lure.position=world_to_screen(Vector2(model.level.false_flower[0],model.level.false_flower[1]))-Vector2(64,131)
	flower_lure.visible=model.trickery_enabled and not model.has_flower and model.trickery.lure_dissolve()<1.0
	(flower_lure.material as ShaderMaterial).set_shader_parameter("simulation_clock",model.clock)
	(flower_lure.material as ShaderMaterial).set_shader_parameter("revelation",maxf(displayed_revelation,model.trickery.lure_dissolve()))
	_update_actor(delta)
	queue_redraw()

func _update_actor(dt: float) -> void:
	stride += absf(model.velocity.x) * dt / 55.0
	var frame := int(stride) % 4
	var region: Rect2 = WALK_RECTS[frame]
	var foot: Vector2 = WALK_FEET[frame]
	actor.texture = WALK
	var scale_factor := 0.245
	if not model.grounded:
		var air_frame: int = 0 if model.velocity.y < -100 else 1 if model.velocity.y < 130 else 2
		actor.texture = AIR
		region = AIR_RECTS[air_frame]
		foot = AIR_FEET[air_frame]
		scale_factor = 0.205
	elif absf(model.velocity.x) < 8:
		region = Rect2(0,350,410,340)
		foot = Vector2(270,335)
	if model.crouching:
		actor.texture=CROUCH
		region=Rect2(0,0,768,512)
		foot=Vector2(445,475)
		scale_factor=0.15
	actor.region_rect = region
	actor.offset = -foot
	actor.scale = Vector2(scale_factor * model.facing, scale_factor)
	actor.position = world_to_screen(model.position)
	actor.rotation = model.facing * (-0.045 if model.dash_remaining > 0 else 0.0)
	actor.modulate = Color(1,0.55,0.55,0.85) if model.hit_flash > 0 else Color(1,1,1,0.65 if model.invulnerable > 0 and sin(model.clock*28)>0 else 1)
	actor.visible = model.phase != model.Phase.FAILED
	var active := model.phase in [model.Phase.SEARCH, model.Phase.RETURN]
	dash_bar.update_at(actor.position, model.dash_recharge, model.dash_cooldown, active)

func _draw() -> void:
	if model == null: return
	draw_rect(Rect2(0,0,1152,648),Color(0.025,0.055,0.05))
	# Slow scrolling across a continuous forest; neither seams nor foreground
	# terrain are baked into the collision-free background.
	var bg_width := 1152.0 * 1.28
	var drift := fmod(camera.x * 0.10, bg_width)
	for i in range(-1,2):
		draw_texture_rect(BACKGROUND,Rect2(i*bg_width-drift,-30,bg_width,820),false,Color(0.76,0.84,0.81))
	var moonlight: float = smoothstep(2000,5400,model.position.x)
	draw_rect(Rect2(0,0,1152,648),Color(0.12,0.05,0.22,moonlight*0.16))
	_draw_depth()
	for i in model.surface_items.size():
		var item: Array=model.surface_items[i].duplicate()
		var point:=model.surface_position(i)
		item[0]=point.x
		item[1]=point.y
		if item[3]=="memory":
			_draw_branch_support(point,float(item[2]),displayed_revelation*0.85)
		else: _draw_surface(item)
		_draw_cracks(i,point)
	_draw_low_branches()
	_draw_return_trees()
	_draw_memory_gate()
	_draw_tricks()
	_draw_palace()
	_draw_illusions()
	_draw_hazards()
	_draw_traces()
	_draw_flower()
	_draw_particles()
	if model.has_flower:
		var at := world_to_screen(model.position-Vector2(0,39))
		for i in 3:
			draw_arc(at,40.0+i*8,0,TAU,48,Color(1.0,0.9,0.61,(0.10-i*0.02)*return_glow),1.0,true)
		for i in 9:
			var angle: float = i*TAU/9.0+model.clock*0.5
			draw_circle(at+Vector2(cos(angle)*37,sin(angle)*49),1.5,Color(1,0.94,0.73,0.8))
	if model.focus > 0.01:
		draw_rect(Rect2(0,0,1152,648),Color(0.13,0.23,0.2,model.focus*0.13))
	_draw_foreground()

func _draw_depth() -> void:
	for i in 4:
		var x := i*365.0-fmod(camera.x*0.18,365)
		var points := PackedVector2Array([Vector2(x,-20),Vector2(x+29,-20),Vector2(x+210,580),Vector2(x+125,580)])
		draw_colored_polygon(points,Color(0.93,0.85,0.55,0.018))

func _draw_surface(item: Array) -> void:
	var left := world_to_screen(Vector2(item[0],item[1]))
	var width: float = item[2]
	if left.x+width < -100 or left.x > 1252: return
	if left.y>800: return
	if item[3] in ["root","branch"]:
		# Sprite bridge roots extend down at both ends. Its top follows the
		# collision strip instead of floating above it.
		if item[3]=="branch": _draw_branch_support(Vector2(item[0],item[1]),width,0.9)
		draw_texture_rect_region(ATLAS,Rect2(left-Vector2(9,12),Vector2(width+18,79)),Rect2(780,238,748,170),Color(0.82,0.84,0.67))
		draw_line(left,left+Vector2(width,0),Color(0.37,0.38,0.18),3)
		return
	var bottom := world_to_screen(Vector2(0,920)).y
	draw_rect(Rect2(left,Vector2(width,bottom-left.y)),Color(0.065,0.075,0.045))
	# Crop one continuous tile per face, rather than stretching its grass cap
	# down the whole cliff. Visible collision tops carry a bright moss edge.
	var remaining := width
	var offset := 0.0
	while remaining > 0:
		var part := minf(remaining,310)
		var y := 16.0
		while y < bottom-left.y:
			var height := minf(165,bottom-left.y-y)
			draw_texture_rect_region(ATLAS,Rect2(left+Vector2(offset,y),Vector2(part,height)),Rect2(45,205,part/310.0*680,height/165.0*205),Color(0.67,0.70,0.57))
			y += height
		draw_texture_rect_region(ATLAS,Rect2(left+Vector2(offset,-10),Vector2(part,30)),Rect2(35,147,part/310.0*690,43),Color(0.73,0.81,0.62))
		remaining -= part
		offset += part
	draw_line(left,left+Vector2(width,0),Color(0.56,0.65,0.30),2.0)
	for i in int(width/25.0):
		var x := left.x + i*25.0 + 10
		var root := PackedVector2Array([Vector2(x,left.y+15),Vector2(x-7,left.y+47),Vector2(x+8,left.y+71),Vector2(x+2,left.y+102)])
		draw_polyline(root,Color(0.20,0.23,0.10,0.6),2,true)

func _draw_palace() -> void:
	var at := world_to_screen(model.palace_position())
	if at.x < -250 or at.x > 1400: return
	draw_texture_rect_region(ATLAS,Rect2(at-Vector2(185,294),Vector2(370,294)),Rect2(85,515,620,500),Color(0.84,0.87,0.83))
	if model.has_flower:
		draw_rect(Rect2(at-Vector2(89,183),Vector2(177,168)),Color(0.025,0.045,0.037,return_glow*0.98))
		for i in 12:
			var t: float = i/11.0
			draw_rect(Rect2(at+Vector2(-84,-179+i*13),Vector2(167,14)),Color(0.11+t*0.065,0.12+t*0.055,0.075+t*0.025,return_glow*0.85))
		for i in 4:
			draw_line(at+Vector2(-85,-12-i*6),at+Vector2(84,-12-i*6),Color(0.48,0.43,0.28,return_glow*0.30),1)
		for side in [-1.0,1.0]:
			draw_line(at+Vector2(side*91,-184),at+Vector2(side*91,-15),Color(1,0.91,0.65,return_glow*0.7),2,true)
	else:
		for i in 7:
			var points := PackedVector2Array()
			for j in 18:
				points.append(at+Vector2(-60+i*20+sin(j*0.6+model.clock*1.8+i)*6,-180+j*10))
			draw_polyline(points,Color(0.76,0.48,1,0.45),2,true)

func _draw_illusions() -> void:
	for index in mirage_data.size():
		var item: Array=mirage_data[index]
		var at:=world_to_screen(Vector2(item[0],item[1]))
		if at.x< -250 or at.x>1250: continue
		var real: bool=item[3]
		var tint:=GOLD if real and displayed_revelation>0.1 else VIOLET
		var strength: float=0.45+displayed_revelation*0.5 if real else 0.65-displayed_revelation*0.50
		for strand in 3:
			var points:=PackedVector2Array()
			for j in 25:
				var t: float=j/24.0
				var angle: float=t*TAU*1.3+model.clock*(0.8+strand*0.2)+index
				points.append(at+Vector2(t*float(item[2]),sin(angle)*(7+strand*3)-8-strand*5))
			draw_polyline(points,Color(tint,strength*0.27),1.0,true)
		for mote in 15:
			var t: float=fposmod(mote/15.0+model.clock*0.08,1.0)
			var p:=at+Vector2(t*float(item[2]),-5-sin(t*PI)*22+sin(model.clock*2+mote)*6)
			if not real: p.y-=displayed_revelation*(mote%4)*8
			draw_circle(p,1.2 if mote%3 else 2.0,Color(tint,strength*pow(sin(t*PI),0.5)))
		if real and displayed_revelation>0.05:
			draw_line(at-Vector2(0,2),at+Vector2(item[2],-2),Color(1,0.91,0.6,displayed_revelation*0.8),2,true)

func _draw_branch_support(point: Vector2, width: float, alpha: float) -> void:
	if alpha<0.01: return
	var top:=world_to_screen(point+Vector2(width*0.82,16))
	var base:=world_to_screen(Vector2(point.x+width*0.78,930))
	var points:=PackedVector2Array([base,top+Vector2(34,140),top+Vector2(-6,70),top])
	draw_polyline(points,Color(0.11,0.12,0.065,alpha),21,true)
	for i in range(points.size()-1):
		var length:=points[i].distance_to(points[i+1])
		draw_set_transform(points[i],(points[i+1]-points[i]).angle(),Vector2.ONE)
		draw_texture_rect_region(ATLAS,Rect2(0,-10,length,20),Rect2(900,260,450,60),Color(0.63,0.62,0.39,alpha))
		draw_set_transform(Vector2.ZERO)
	draw_polyline(points,Color(0.40,0.35,0.16,alpha*0.6),2,true)

func _draw_cracks(index: int, point: Vector2) -> void:
	var item: Array=model.surface_items[index]
	var age: float=float(model.crumble_ages.get(str(item[0]),-1.0))
	if age<0: return
	var delay: float=model.crumble_delay(float(item[0]))
	var amount:=clampf(age/delay,0,1)
	var at:=world_to_screen(point)
	for i in 5:
		var x: float=float(item[2])*(i+1)/6.0
		var crack:=PackedVector2Array([at+Vector2(x-5,-3),at+Vector2(x+2,8),at+Vector2(x-4,17),at+Vector2(x+6,25)])
		draw_polyline(crack,Color(0.95,0.75,0.35,amount*0.85),1.5,true)
		var t:=maxf(0,age-delay)
		draw_circle(at+Vector2(x+sin(i*5)*t*40,20+t*90+i*3),2.5,Color(0.5,0.34,0.13,1.0-clampf(t,0,1)))

func _draw_tricks() -> void:
	if not model.trickery_enabled: return
	for hazard: Dictionary in model.trickery.hazards():
		var rect: Rect2=hazard.rect
		rect.position=world_to_screen(rect.position)
		if rect.end.x< -100 or rect.position.x>1252: continue
		var opacity: float=hazard.alpha
		if hazard.kind=="spikes":
			for i in maxi(3,int(rect.size.x/14)):
				var width:=rect.size.x/float(maxi(3,int(rect.size.x/14)))
				var x:=rect.position.x+i*width
				var spike:=PackedVector2Array([Vector2(x,rect.end.y),Vector2(x+width*0.55,rect.position.y),Vector2(x+width,rect.end.y)])
				draw_colored_polygon(spike,Color(0.16,0.22,0.10,opacity))
				draw_polyline(spike,Color(0.88,0.56,0.95,opacity),1.5,true)
		elif hazard.kind=="fall":
			draw_texture_rect_region(ATLAS,rect,Rect2(70,215,160,190),Color(0.68,0.64,0.57,opacity))
			var tip:=PackedVector2Array([Vector2(rect.position.x,rect.end.y-20),Vector2(rect.position.x+rect.size.x*0.5,rect.end.y),Vector2(rect.end.x,rect.end.y-20)])
			draw_colored_polygon(tip,Color(0.69,0.39,0.83,opacity*0.8))
		else:
			draw_texture_rect_region(ATLAS,rect,Rect2(1020,245,320,90),Color(0.73,0.75,0.56,opacity))
			for thorn in 4:
				var x: float=rect.position.x+rect.size.x*(thorn+0.5)/4.0
				var spike:=PackedVector2Array([Vector2(x-7,rect.position.y+rect.size.y*0.45),Vector2(x+2,rect.position.y),Vector2(x+7,rect.position.y+rect.size.y*0.65)])
				draw_colored_polygon(spike,Color(0.28,0.24,0.12,opacity))
		for mote in 7:
			var t: float=mote/7.0
			draw_circle(rect.position+Vector2(t*rect.size.x,rect.size.y*0.5+sin(model.clock*7+mote)*rect.size.y*0.4),1.5,Color(0.91,0.72,1,opacity*0.8))
	# Hairline fractures are part of the actual floor, before its patch drops.
	for i in model.trickery.definitions.size():
		if model.trickery.ages[i]<0 or model.trickery.definitions[i].phase!=model.trickery.phase_name: continue
		for effect: Dictionary in model.trickery.definitions[i].effects:
			if effect.kind!="cut": continue
			for surface_index in model.level.platforms.size():
				var item: Array=model.level.platforms[surface_index]
				if float(item[0])!=float(effect.surface_x): continue
				var at:=world_to_screen(model.surface_position(surface_index))
				if at.y>800: continue
				for crack in 8:
					var x:=at.x+float(item[2])*(crack+0.5)/8.0
					draw_polyline(PackedVector2Array([Vector2(x-4,at.y-1),Vector2(x+2,at.y+9),Vector2(x-5,at.y+17)]),Color(0.39,0.23,0.27,0.8),1.3,true)

func _draw_low_branches() -> void:
	for rect: Array in model.level.low_branches:
		var at:=world_to_screen(Vector2(rect[0],rect[1]))
		if at.x< -300 or at.x>1300: continue
		var root:=PackedVector2Array([at+Vector2(-30,100),at+Vector2(-43,57),at+Vector2(-26,18),at+Vector2(5,15)])
		draw_polyline(root,Color(0.13,0.15,0.08),20,true)
		draw_polyline(root,Color(0.30,0.27,0.13),9,true)
		draw_texture_rect_region(ATLAS,Rect2(at,Vector2(rect[2],rect[3])),Rect2(825,245,640,90),Color(0.75,0.80,0.62))

func _draw_memory_gate() -> void:
	var gate: Array=model.level.memory_gate
	var at:=world_to_screen(Vector2(float(gate[0])+float(gate[2])*0.5,float(gate[1])+float(gate[3])))
	var opacity: float=1.0-model.gate_opening
	var height: float=gate[3]
	if opacity<=0.01 or model.has_flower or at.x< -100 or at.x>1250: return
	for side in [-1.0,1.0]:
		var points:=PackedVector2Array()
		for j in 30:
			var t: float=j/29.0
			points.append(at+Vector2(side*(22+sin(t*PI)*12),-t*height))
		draw_polyline(points,Color(0.15,0.21,0.10,opacity),7,true)
	for strand in 13:
		var points:=PackedVector2Array()
		for j in 35:
			var t: float=j/34.0
			points.append(at+Vector2(sin(t*8+model.clock*1.7+strand)*14+strand*2-12,-t*height))
		draw_polyline(points,Color(0.75,0.46,1.0,opacity*(0.23+0.08*sin(model.clock+strand))),2,true)

func _draw_return_trees() -> void:
	for index in model.level.return_trees.size():
		var line:=model.tree_segment(index)
		var start:=world_to_screen(line[0])
		var end:=world_to_screen(line[1])
		if maxf(start.x,end.x)< -100 or minf(start.x,end.x)>1252: continue
		draw_line(start,end,Color(0.10,0.12,0.065),35,true)
		draw_set_transform(start,(end-start).angle(),Vector2.ONE)
		draw_texture_rect_region(ATLAS,Rect2(0,-16,start.distance_to(end),32),Rect2(890,250,560,80),Color(0.75,0.75,0.59))
		draw_set_transform(Vector2.ZERO)
		var age: float=model.tree_ages[index]
		if age>=0 and age<1.8:
			for i in 8:
				var t: float=fposmod(age+i*0.13,1.0)
				draw_circle(start.lerp(end,i/9.0)+Vector2(sin(i*5)*t*28,t*40),2,Color(0.64,0.51,0.20,1-t))

func _draw_hazards() -> void:
	for hazard: Dictionary in model.level.hazards:
		var at := world_to_screen(Vector2(hazard.x,hazard.y))
		if at.x < -170 or at.x > 1320: continue
		var state: float = model.hazard_state(hazard)
		var rise: float = smoothstep(0.0,0.22,state)*(1.0-smoothstep(0.52,0.75,state))
		var tint := GOLD if model.has_flower else VIOLET
		var width: float = hazard.width
		for i in 7:
			var points := PackedVector2Array()
			for j in 15:
				var t: float = j/14.0
				points.append(at+Vector2(width*i/7.0+sin(t*6+model.clock*3+i)*7*t,-float(hazard.height)*t*rise))
			draw_polyline(points,Color(0.13,0.22,0.11),5,true)
			draw_polyline(points,Color(tint,0.35+rise*0.45),1.7,true)
			if rise > 0.05:
				draw_circle(points[-1],3,Color(tint,0.65))
		var mist_alpha := rise*0.12 if not model.has_flower else 0.025
		for i in 4:
			draw_circle(at+Vector2(width*(i+0.5)/4.0,-20-rise*28),22,Color(tint,mist_alpha))

func _draw_traces() -> void:
	# White petals belong to rooted, real terrain. Purple illusions have no
	# roots or shadow; this visual language is taught by Hermes.
	for surface: Rect2 in model.platforms:
		if surface.position.x < 1000: continue
		if surface.position.x>2700 and surface.position.x<3750 and displayed_revelation<0.1: continue
		var at := world_to_screen(surface.position+Vector2(surface.size.x*0.45,-3))
		if at.x < -20 or at.x > 1180: continue
		for i in 3:
			draw_set_transform(at+Vector2(i*8,-2-sin(i)*2),i*0.7,Vector2.ONE)
			_draw_petal(Vector2.ZERO,Vector2(3,1.2),Color(1,0.91,0.68,0.9))
			draw_set_transform(Vector2.ZERO)
	var scrap := world_to_screen(Vector2(1220,540))
	if scrap.x > -50 and scrap.x < 1200:
		draw_colored_polygon(PackedVector2Array([scrap+Vector2(-18,-4),scrap+Vector2(5,-13),scrap+Vector2(20,-5),scrap+Vector2(4,-1)]),Color(0.55,0.15,0.13))

func _draw_petal(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 12:
		var angle: float = i*TAU/12.0
		points.append(center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y))
	draw_colored_polygon(points,color)

func _draw_flower() -> void:
	if model.has_flower: return
	var at := world_to_screen(Vector2(model.level.flower[0],model.level.flower[1]))
	if at.x < -150 or at.x > 1300: return
	for i in range(4,0,-1):
		draw_circle(at-Vector2(0,35),25.0*i,Color(1,0.89,0.51,0.025))
	draw_texture_rect_region(ATLAS,Rect2(at-Vector2(53,115),Vector2(106,116)),Rect2(936,531,415,469))
	for i in 12:
		var angle: float = i*TAU/12.0+model.clock*0.4
		draw_circle(at+Vector2(cos(angle)*55,-55+sin(angle)*36),1.5,Color(1,0.96,0.68,0.85))

func _draw_particles() -> void:
	for i in 56:
		var x := fposmod(i*137.7-camera.x*0.55+sin(model.clock*0.3+i)*18,1190)-20
		var y := fposmod(i*73.5-model.clock*(3+i%4),600)+20
		var glow: float = 0.22+sin(model.clock*1.2+i)*0.16
		draw_circle(Vector2(x,y),1.0 if i%3 else 1.7,Color(1,0.88,0.53,glow))

func _draw_foreground() -> void:
	# Restrict foreground foliage to the bottom edge, below playable feet.
	for i in 31:
		var x := i*44.0-fmod(camera.x*1.1,44)
		var height := 12.0+sin(i*3.2)*7
		var points := PackedVector2Array([Vector2(x-13,648),Vector2(x-7,648-height),Vector2(x,643),Vector2(x+7,628-height),Vector2(x+15,648)])
		draw_colored_polygon(points,Color(0.018,0.058,0.051,0.8))
