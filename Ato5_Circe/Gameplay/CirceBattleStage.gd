extends Node2D

const DASH_RECHARGE_BAR := preload("res://Code/DashRechargeBar.gd")
const MODEL := preload("res://Ato5_Circe/Gameplay/CirceBattleModel.gd")
const BACKDROP := preload("res://Assets/act5_circe/battle/palace_topdown.png")
const PROPS := preload("res://Assets/act5_circe/battle/palace_props.png")
const HERO := preload("res://Assets/act5_circe/battle/odysseus_directions.png")
const CIRCE := preload("res://Assets/act5_circe/battle/circe_chimera.png")
const ACTING := preload("res://Assets/act4_poseidon/acting.gdshader")
const TABLE := Rect2(0,0,768,550)
const COLUMN := Rect2(768,0,768,552)
const ROOTS := Rect2(0,550,768,474)
const GATE := Rect2(768,560,768,464)
var model: MODEL
var world: Node2D
var player: Sprite2D
var dash_bar := DASH_RECHARGE_BAR.new()
var casters: Array[Node2D]=[]
var idle: Array[Sprite2D]=[]
var gestures: Array[Sprite2D]=[]
var columns: Array[Sprite2D]=[]
var gate: Sprite2D
var blend := 0.0

class Effects extends Node2D:
	var director: Node2D
	func _draw() -> void: director.draw_effects(self)

func _sprite(texture: Texture2D,region: Rect2,parent: Node) -> Sprite2D:
	var node := Sprite2D.new(); node.texture=texture; node.region_enabled=true
	node.region_filter_clip_enabled=true; node.region_rect=region; node.centered=false
	parent.add_child(node); return node

func _ready() -> void:
	world=Node2D.new(); world.y_sort_enabled=true; add_child(world)
	for i in 3:
		var actor := Node2D.new(); world.add_child(actor); casters.append(actor)
		var body := _sprite(CIRCE,Rect2(0,0,768,512),actor)
		body.offset=-Vector2(410,503); body.scale=Vector2.ONE*0.215
		var material := ShaderMaterial.new(); material.shader=ACTING
		material.set_shader_parameter("region",Vector4(0,0,0.5,0.5)); body.material=material; idle.append(body)
		var casting := _sprite(CIRCE,Rect2(768,0,768,512),actor)
		casting.offset=-Vector2(440,503); casting.scale=Vector2.ONE*0.215; gestures.append(casting)
	for i in [0,3]:
		var definition: Dictionary=model.tuning.palace_events[i]
		var pillar := _sprite(PROPS,COLUMN,world)
		pillar.position=Vector2(definition.pivot[0],definition.pivot[1])
		pillar.offset=-Vector2(386,533); pillar.scale=Vector2.ONE*0.33; columns.append(pillar)
	gate=_sprite(PROPS,GATE,world); gate.offset=-Vector2(384,400); gate.scale=Vector2.ONE*0.24
	player=_sprite(HERO,Rect2(),world)
	dash_bar.z_index = 1
	add_child(dash_bar)
	var fx := Effects.new(); fx.director=self; add_child(fx)
	update_visuals(0)

func update_visuals(delta: float) -> void:
	var dt := delta if model.active() else 0.0
	var target := 1.0 if model.boss_state in ["windup","approach"] else 0.0
	blend=move_toward(blend,target,dt*8)
	var movement := smoothstep(6.0,MODEL.SIDESTEP_SPEED,model.boss_velocity.length())
	for i in 3:
		var real := i==model.real_slot
		casters[i].visible=real or model.phase in [MODEL.Phase.MIRRORS,MODEL.Phase.PALACE]
		casters[i].position=model.boss_position if real else model.clone_positions[i]
		var side := 1.0 if model.position.x<casters[i].position.x else -1.0
		var tint := Color.WHITE
		if not real:
			# A tiny displaced hem/reflection is a learnable clue even without E.
			casters[i].position.x+=sin(model.clock*3+i)*1.8
			tint=Color(0.66,0.44,0.9,0.16) if model.reveal_time>0 or float(model.clone_flashes[i])>0 else Color(0.96,0.94,1,0.95)
		elif model.boss_flash>0: tint=Color(1.4,1.2,0.8)
		var stride := movement if real or model.boss_state=="reposition" else 0.0
		var sway := sin(model.clock*16.0)*stride
		casters[i].rotation = sway*0.025
		idle[i].scale=Vector2(side*0.215,0.215*(1+sin(model.clock*1.9)*0.003+sway*0.015))
		gestures[i].scale=Vector2(side*0.215,0.215)
		idle[i].modulate=tint*Color(1,1,1,1-blend)
		gestures[i].modulate=tint*Color(1,1,1,blend)
		var material := idle[i].material as ShaderMaterial
		material.set_shader_parameter("clock",model.clock)
		material.set_shader_parameter("walking",stride)
	var direction := model.attack_direction if model.attack_age>=0 else model.facing
	if model.attack_age<0 and not model.guarding and model.velocity.length()>15: direction=model.velocity.normalized()
	if model.dash_time>0: direction=model.dash_direction
	var row := 1 if direction.y< -0.55 else 0 if direction.y>0.55 else 2
	var frame := 0
	if model.velocity.length()>15:
		frame=[0,1,0,2][int(model.clock*10)%4]
	if model.attack_age>=0: frame=3
	if model.guarding: frame=row; row=3
	if model.hit_flash>0: row=3; frame=3
	if model.dash_time>0:
		var dash_frame := clampi(int((float(model.tuning.dash_duration)-model.dash_time)*20.0),0,3)
		frame = [0,1,2,0][dash_frame]
	var cell := Vector2(HERO.get_width()/4.0,HERO.get_height()/4.0)
	player.region_rect=Rect2(Vector2(frame,row)*cell,cell)
	player.offset=-cell*Vector2(0.50,0.97)
	player.scale=Vector2.ONE*(105.0/cell.y)
	player.flip_h=direction.x<0 and (row==2 or (row==3 and frame==2))
	player.position=model.position
	dash_bar.update_at(player.position, model.dash_recharge, model.dash_cooldown, model.active())
	player.rotation = model.dash_direction.x*0.12 if model.dash_time>0 else 0.0
	player.modulate=Color(1.4,0.65,0.65) if model.hit_flash>0 else Color.WHITE
	for index in columns.size():
		var definition: Dictionary=model.tuning.palace_events[0 if index==0 else 3]
		var progress := 0.0
		for event in model.palace.events:
			if event.id==definition.id: progress=float(event.progress)
		columns[index].rotation=ease(progress,2.0)*PI*0.5
	gate.hide()
	for event in model.palace.events:
		if event.kind=="gate":
			gate.show(); gate.position=Vector2(585,315-(1-event.progress)*110)
			gate.modulate.a=smoothstep(0,0.4,event.progress)
	queue_redraw(); get_child(get_child_count()-1).queue_redraw()

func _draw() -> void:
	draw_texture_rect(BACKDROP,Rect2(0,-55,1152,768),false)
	draw_rect(Rect2(0,0,1152,648),Color(0.02,0.01,0.04,0.13))
	_shadow(self,model.position,22,0.43)
	for i in 3:
		if i==model.real_slot: _shadow(self,model.boss_position,23,0.43)
		elif model.phase in [MODEL.Phase.MIRRORS,MODEL.Phase.PALACE]: _shadow(self,model.clone_positions[i]+Vector2(3,0),23,0.27)
	for event in model.palace.events:
		if event.kind=="pit":
			var center: Vector2=event.center
			if event.progress>0:
				draw_circle(center,float(event.radius)*event.progress,Color("171020"))
				draw_arc(center,float(event.radius)+2,0,TAU,30,Color("9b7a86"),3,true)
			for i in 7:
				var axis := Vector2.from_angle(float(i)*TAU/7)
				draw_line(center+axis*10,center+axis*(18+event.age*13),Color(0.15,0.07,0.2,0.9),2,true)
		elif event.progress<1:
			var r := MODEL.PALACE.rectangle(event)
			if event.kind=="column":
				draw_rect(r,Color(0.07,0.025,0.10,0.12+event.age*0.12))
	for root in model.roots:
		if root.age>=float(model.tuning.root_warning):
			var fraction := smoothstep(float(model.tuning.root_warning),float(model.tuning.root_warning)+0.25,root.age)
			draw_texture_rect_region(PROPS,Rect2(root.p-Vector2(50,50)*fraction,Vector2(100,85)*fraction),ROOTS)
		else:
			for i in 6:
				var axis := Vector2.from_angle(i*TAU/6+0.2)
				draw_line(root.p+axis*8,root.p+axis*(18+root.age*20),Color("5c354f"),2,true)

func _shadow(canvas: Node2D,at: Vector2,radius: float,alpha: float) -> void:
	canvas.draw_set_transform(at,0,Vector2(1,0.35))
	canvas.draw_circle(Vector2.ZERO,radius,Color(0.025,0.015,0.05,alpha))
	canvas.draw_set_transform(Vector2.ZERO)

func draw_effects(canvas: Node2D) -> void:
	if model.boss_state=="windup":
		if model.attack_kind=="table":
			var at := model.boss_position+model.boss_facing*35
			_shadow(canvas,at,42,0.35)
			canvas.draw_texture_rect_region(PROPS,Rect2(at-Vector2(55,80+sin(model.clock*5)*4),Vector2(110,79)),TABLE,Color(1,1,1,0.55+model.boss_age*0.5))
		elif model.attack_kind=="enchant":
			var t := clampf(model.boss_age/0.7,0,1)
			canvas.draw_arc(model.boss_position+Vector2(0,-40),20+t*30,model.clock*3,model.clock*3+TAU,32,Color(0.75,0.43,1,t*0.7),2,true)
		elif model.attack_kind=="roots":
			var t := clampf(model.boss_age/0.7,0,1)
			canvas.draw_arc(model.locked_target,24+t*13,0,TAU,28,Color(0.72,0.47,0.82,t*0.62),1.5,true)
		elif model.attack_kind=="staff":
			var angle := model.boss_facing.angle()
			canvas.draw_arc(model.boss_position,70+model.boss_age*25,angle-0.8,angle+0.8,24,Color(0.93,0.72,0.47,model.boss_age*0.7),2,true)
	for table in model.tables:
		_shadow(canvas,table.p,44,0.3)
		canvas.draw_set_transform(table.p+Vector2(0,-25),table.angle)
		canvas.draw_texture_rect_region(PROPS,Rect2(-56,-35,112,80),TABLE)
		canvas.draw_set_transform(Vector2.ZERO)
	if model.flower_flash>0 or model.observing:
		var color := Color(1,0.88,0.48,0.8)
		canvas.draw_arc(model.position+Vector2(0,-39),54,0,TAU,44,Color(color,model.flower_flash if model.flower_flash>0 else 0.55),2,true)
	if model.reveal_time>0 and model.phase in [MODEL.Phase.MIRRORS,MODEL.Phase.PALACE]:
		canvas.draw_circle(model.boss_position+Vector2(0,-123),4,Color("ffe6a6"))
	if model.guarding:
		var angle := model.facing.angle()
		canvas.draw_arc(model.position+Vector2(0,-35),46,angle-0.6,angle+0.6,20,Color("e6cb90"),2,true)
	if model.attack_age>=0 and model.attack_age<0.25:
		var angle := model.attack_direction.angle()-0.7+model.attack_age*5
		canvas.draw_arc(model.position+Vector2(0,-28),float(model.tuning.sword_range),angle-0.45,angle+0.3,16,Color(1,0.88,0.59,0.65),3,true)
	if model.dash_time>0:
		for i in 4:
			var at := model.position+Vector2(0,-35)-model.dash_direction*(18+i*12)
			canvas.draw_line(at,at-model.dash_direction*18,Color(0.38,0.83,1,0.5-i*0.09),2,true)
	for effect in model.effects:
		if effect.kind=="teleport":
			var age := float(effect.age)
			var fade := 1.0-smoothstep(0.10,0.43,age)
			var at: Vector2 = effect.p
			canvas.draw_arc(at,18.0+age*90.0,0,TAU,32,Color(0.76,0.49,1.0,fade*0.85),2.5,true)
			for i in 6:
				var angle := i*TAU/6.0+age*5.0
				var mote := at+Vector2.from_angle(angle)*(21+age*65.0)-Vector2(0,9+age*80.0)
				canvas.draw_circle(mote,2.0,Color(0.91,0.73,1.0,fade))
			continue
		var color := Color("ead195") if effect.kind=="gold" else Color("a97ecf") if effect.kind=="violet" else Color("b68a52")
		for i in 9:
			var direction := Vector2.from_angle(i*TAU/9+0.2)
			var at: Vector2=effect.p+Vector2(0,-25)+direction*effect.age*90
			canvas.draw_line(at,at-direction*7,Color(color,1-effect.age/0.8),2,true)
	if model.impact_flash>0: canvas.draw_rect(Rect2(0,0,1152,648),Color(0.9,0.8,1,model.impact_flash*0.09))
