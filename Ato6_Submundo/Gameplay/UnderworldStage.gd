extends Node2D
const DASH_RECHARGE_BAR := preload("res://Code/DashRechargeBar.gd")
const HERO := preload("res://Assets/act5_circe/battle/odysseus_directions.png")
const SOULS := preload("res://Assets/act6_underworld/souls_atlas.png")
const LAKE := preload("res://Assets/act6_underworld/oracle_lake.png")
const RIVER := preload("res://Ato6_Submundo/Gameplay/UnderworldRiver.gd")
const RUINS := preload("res://Assets/act6_underworld/river_ruins.png")
const RUIN_REGIONS := [Rect2(112, 4, 527, 499), Rect2(842, 164, 621, 334),
	Rect2(20, 576, 717, 409), Rect2(779, 606, 751, 363)]
const SPECTRAL := preload("res://Assets/act6_underworld/spectral.gdshader")
const VISIONS := [
	preload("res://Assets/act4_vigil/penelope_vision.png"),
	preload("res://Assets/act4_vigil/wind_bag_betrayal.png"),
	preload("res://Assets/act9_mutiny/mutiny_deck.png"),
	preload("res://Assets/act4_released_winds/storm_open_sea.png"),
	preload("res://Assets/act13_ithaca/hall.png"),
	preload("res://Assets/act13_ithaca/homecoming.png"),
]
const VISION_TINTS := [Color("aebfb0"), Color("819d9d"), Color("b4a5b9"), Color("83a6be"), Color("bb7b79"), Color("a299ae")]
const SEAL_COLORS := [Color("f3d08c"), Color("79ded8"), Color("cdb3f8")]
const SEAL_LABELS := ["VOCÊ", "1º ECO", "2º ECO"]
var model: RefCounted
var chapter := 0
var camera_offset := Vector2.ZERO
var river: RIVER
var world: Node2D
var hero: Sprite2D
var dash_bar := DASH_RECHARGE_BAR.new()
var companion: Sprite2D
var echo_sprites: Array[Sprite2D]=[]
var souls: Array[Dictionary]=[]
var coda := 0.0
var vision := 0
var last_vision := 0
var vision_blend := 0.0

class Foreground extends Node2D:
	var director: Node2D
	func _draw() -> void: director.draw_foreground(self)

func _sprite(texture: Texture2D,region: Rect2,parent: Node) -> Sprite2D:
	var body := Sprite2D.new(); body.texture=texture; body.region_enabled=true
	body.region_filter_clip_enabled=true; body.region_rect=region; body.centered=false
	parent.add_child(body); return body

func _spectral(body: Sprite2D,region: Vector4,color: Color) -> void:
	var effect := ShaderMaterial.new(); effect.shader=SPECTRAL
	effect.set_shader_parameter("region",region); effect.set_shader_parameter("spectral_color",color)
	body.material=effect

func _ready() -> void:
	if chapter == 0:
		river = RIVER.new()
		river.model = model
		add_child(river)
		river.add_mist(self, 0.52)
	world=Node2D.new(); world.y_sort_enabled=true; add_child(world)
	if chapter==0:
		_add_river_props()
		for i in model.waves.size():
			for j in 4:
				var ghost := _sprite(SOULS,Rect2(0,0,768,512),world)
				ghost.offset = -Vector2(384, 490)
				ghost.scale = Vector2.ONE * (0.116 + j % 3 * 0.016)
				ghost.flip_h = (j + i) % 2 == 1
				_spectral(ghost, Vector4(0,0,0.5,0.5), Color(0.46, 0.83, 0.81, 0.78))
				souls.append({"body": ghost, "i": i, "j": j})
		companion=_sprite(SOULS,Rect2(768,0,768,512),world)
		companion.offset=-Vector2(405,500); companion.scale=Vector2.ONE*0.24
		_spectral(companion,Vector4(0.5,0,0.5,0.5),Color(0.98,0.88,0.65,0.85))
	else:
		companion=_sprite(SOULS,Rect2(0,512,768,512),world)
		companion.offset=-Vector2(376,500); companion.scale=Vector2.ONE*0.25
		for i in 2:
			var echo := _sprite(HERO,Rect2(),world); echo.hide()
			_spectral(echo, Vector4(0,0,1,1), Color(SEAL_COLORS[i + 1], 0.56)); echo_sprites.append(echo)
	hero=_sprite(HERO,Rect2(),world)
	if chapter == 0: river.add_mist(self, 0.26)
	add_child(dash_bar)
	var front := Foreground.new(); front.director=self; add_child(front)
	if chapter == 0: snap_camera()
	update_visuals(0)

func _add_river_props() -> void:
	for entry in model.level.props:
		var kind := int(entry[2])
		var region: Rect2 = RUIN_REGIONS[kind]
		var prop := _sprite(RUINS, region, world)
		prop.offset = -region.size * Vector2(0.5, 0.97)
		prop.position = Vector2(entry[0], entry[1])
		prop.scale = Vector2.ONE * float([175, 86, 96, 88][kind]) / region.size.y * float(entry[3])
		prop.modulate = Color(0.78, 0.87, 0.84)
		if kind == 3:
			prop.position.y -= 55.0 * float(entry[3])
			prop.offset.y += 55.0 * float(entry[3]) / prop.scale.y

func _camera_target() -> Vector2:
	var ahead := Vector2(clampf(model.facing.x, -1.0, 1.0) * 110.0, 0.0)
	var maximum: Vector2 = model.world_size - Vector2(1152, 648)
	var target: Vector2 = model.position - Vector2(530, 331) + ahead
	var fork: Vector2 = model.checkpoints[1]
	var reveal := 1.0 - smoothstep(45.0, 280.0, model.position.distance_to(fork))
	target.y = lerpf(target.y, fork.y - 400.0, reveal * 0.88)
	return target.clamp(Vector2.ZERO, maximum)

func snap_camera() -> void:
	if chapter == 0: camera_offset = _camera_target()

func _pose(body: Sprite2D,at: Vector2,direction: Vector2,moving: bool,time: float,brace: bool=false) -> void:
	var row := 1 if direction.y< -0.55 else 0 if direction.y>0.55 else 2
	var frame: int=[0,1,0,2][posmod(int(time*9),4)] if moving else 0
	if brace: frame=row; row=3
	var cell := HERO.get_size()/4.0
	body.region_rect=Rect2(Vector2(frame,row)*cell,cell); body.offset=-cell*Vector2(0.5,0.97)
	body.scale=Vector2.ONE*(105/cell.y); body.flip_h=direction.x<0 and (row==2 or (row==3 and frame==2))
	body.position=at
	if body.material is ShaderMaterial:
		body.material.set_shader_parameter("region",Vector4(frame/4.0,row/4.0,0.25,0.25))
		body.material.set_shader_parameter("simulation_clock",time)

func update_visuals(delta: float) -> void:
	var active: bool=model.phase==model.Phase.ACTIVE
	if vision > 0: last_vision = vision
	vision_blend=move_toward(vision_blend,1 if vision>0 else 0,delta*2)
	if chapter==0:
		if active: camera_offset = camera_offset.lerp(_camera_target(), 1.0 - exp(-delta * 5.0))
		world.position = -camera_offset
		river.update_view(camera_offset)
		companion.position=model.mother_position+Vector2(0,-8+sin(model.clock*1.2)*2)
		var screen := Rect2(camera_offset, Vector2(1152, 648)).grow(120.0)
		for entry in souls:
			var wave: Dictionary = model.waves[entry.i]
			var drift := Vector2(sin(model.clock * 1.8 + entry.j * 3.0) * 12.0, sin(model.clock * 2.0 + entry.j) * 6.0)
			var offset := Vector2((entry.j - 1.5) * wave.width * 0.48, -wave.direction * (entry.j % 2 * 30.0 + 12.0))
			var at: Vector2 = wave.position + offset + drift
			var strength: float = wave.strength
			if wave.gathering > 0.0:
				at = wave.origin + offset + drift
				strength = wave.gathering * 0.36
			entry.body.visible = strength > 0.025 and screen.has_point(at)
			if entry.body.visible:
				entry.body.position = at
				entry.body.modulate.a = strength
				entry.body.material.set_shader_parameter("simulation_clock", model.clock + entry.j)
		companion.material.set_shader_parameter("simulation_clock",model.clock)
	else:
		companion.position=model.prophet
		companion.visible = model.room == model.level.puzzles.back()
		companion.modulate.a = 1.0 if model.puzzle >= model.proof_count() else 0.65
		for i in echo_sprites.size():
			echo_sprites[i].visible=i<model.echoes.size()
			if i<model.echoes.size():
				var echo: Dictionary=model.echoes[i]
				_pose(echo_sprites[i],echo.p,echo.f,bool(echo.get("moving",false)),model.clock-model.echo_interval*(i+1))
		if model.phase==model.Phase.COMPLETE:
			coda=minf(coda+delta,3.0)
	var direction: Vector2=model.dash_direction if model.dash_time>0 else model.facing
	_pose(hero,model.position,direction,model.velocity.length()>15,model.clock,model.braced)
	dash_bar.update_at(world.transform * hero.position, model.dash_recharge, model.dash_cooldown, active)
	queue_redraw(); get_child(get_child_count()-1).queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0,0,1152,648),Color("061318"))
	if chapter == 0: return
	draw_texture_rect(LAKE,Rect2(0,-65,1152,768),false,Color(0.75,0.83,0.85))
	var floor: Array[Rect2] = model.floor_rects()
	for i in model.bridges.size():
		if not model.bridge_open(i):
			var bridge: Rect2 = model.bridges[i]
			var color := Color(SEAL_COLORS[model.pad_actors[int(model.room.bridges[i][4])]], 0.30)
			draw_rect(bridge, Color(color, 0.055))
			for y in [bridge.position.y, bridge.end.y]:
				draw_dashed_line(Vector2(bridge.position.x, y), Vector2(bridge.end.x, y), color, 1.4, 9.0)
	for floor_rect in floor:
		draw_rect(Rect2(floor_rect.position+Vector2(0,7),floor_rect.size),Color("11252b"))
	for floor_rect in floor: _stone_floor(floor_rect)
	for floor_rect in floor: _floor_edges(floor_rect, floor)
	_draw_oracle_seals()
	_shadow(self,model.position,20,0.45)
	if companion.visible: _shadow(self,model.prophet,23,0.28)
	# Slow motes and reflected light remain in simulation time through dialogue/pause.
	for i in 45:
		var at := Vector2(fposmod(i*163.3-model.clock*6,1152),120+fposmod(i*73.7-model.clock*3,420))
		draw_circle(at,1.1,Color(0.6,0.85,0.82,0.12+sin(model.clock+i)*0.08))

func _draw_oracle_seals() -> void:
	if model.puzzle >= model.proof_count(): return
	if model.room.has("mirror"):
		var x := float(model.room.mirror)
		draw_rect(Rect2(x - 15, 310, 30, 210), Color(0.26, 0.57, 0.57, 0.10))
		draw_dashed_line(Vector2(x, 310), Vector2(x, 520), Color("6ca8a7"), 2.0, 10.0)
	if model.room.has("goal"):
		var goal := Vector2(model.room.goal[0], model.room.goal[1])
		draw_circle(goal, 28.0, Color(0.97, 0.76, 0.46, 0.11))
		draw_arc(goal, 26.0, 0.0, TAU, 32, Color("c5a875"), 1.5, true)
		for side in [-1.0, 1.0]: draw_line(goal + Vector2(7.0, side * 8.0), goal + Vector2(15.0, 0), Color("f3d08c"), 2.0, true)
	for i in model.pads.size():
		var at: Vector2 = model.pads[i]
		var role: int = model.pad_actors[i]
		var color: Color = SEAL_COLORS[role]
		var ordered: bool = model.room.rule == "sequence"
		var lit: bool = i < model.sequence_step if ordered else model.activated[i]
		draw_circle(at, 25, Color(0.04, 0.16, 0.19, 0.85))
		draw_arc(at, 24, 0, TAU, 48, Color(color, 0.95 if lit else 0.60), 2.3 if lit else 1.4, true)
		for j in 4:
			var axis := Vector2.from_angle(j * PI / 2 + PI / 4)
			draw_line(at + axis * 13, at + axis * 20, color, 2, true)
		if lit: draw_circle(at, 20, Color(color, 0.25))
		var label: String = SEAL_LABELS[role]
		if ordered: label = "%d · %s" % [i + 1, label]
		draw_string(ThemeDB.fallback_font, at + Vector2(-48, 41), label, HORIZONTAL_ALIGNMENT_CENTER, 96, 13, color)

func _stone_floor(rect: Rect2) -> void:
	# One world-aligned texture across every island and bridge, without stretched seams.
	var tile_size := Vector2(130,52.5)
	for x in range(floori(rect.position.x/tile_size.x),ceili(rect.end.x/tile_size.x)):
		for y in range(floori(rect.position.y/tile_size.y),ceili(rect.end.y/tile_size.y)):
			var tile := Rect2(Vector2(x,y)*tile_size,tile_size)
			var visible_part := rect.intersection(tile)
			var source := Rect2(Vector2(1030,695)+(visible_part.position-tile.position)*2,visible_part.size*2)
			draw_texture_rect_region(SOULS,visible_part,source,Color(0.63,0.76,0.76))

func _floor_edges(rect: Rect2, floor: Array[Rect2]) -> void:
	for edge in [[rect.position,Vector2(rect.end.x,rect.position.y),Vector2.UP],[Vector2(rect.end.x,rect.position.y),rect.end,Vector2.RIGHT],[rect.end,Vector2(rect.position.x,rect.end.y),Vector2.DOWN],[Vector2(rect.position.x,rect.end.y),rect.position,Vector2.LEFT]]:
		var from: Vector2=edge[0]; var to: Vector2=edge[1]; var outward: Vector2=edge[2]
		var steps := ceili(from.distance_to(to)/8)
		for i in steps:
			var a := from.lerp(to,float(i)/steps); var b := from.lerp(to,float(i+1)/steps)
			var outside := true
			for other in floor:
				if other.has_point((a+b)*0.5+outward*2): outside=false; break
			if outside:
				draw_line(a,b,Color("8ca7a4"),2,true)
				draw_line(a+outward*4,b+outward*4,Color(0.07,0.16,0.18,0.65),3,true)

func _shadow(canvas: Node2D,at: Vector2,radius: float,alpha: float) -> void:
	canvas.draw_set_transform(at,0,Vector2(1,0.3)); canvas.draw_circle(Vector2.ZERO,radius,Color(0,0.04,0.05,alpha))
	canvas.draw_set_transform(Vector2.ZERO)

func draw_foreground(canvas: Node2D) -> void:
	if chapter==0:
		if model.influence>0.05:
			var player_at: Vector2=model.position - camera_offset - Vector2(0, 33)
			for k in 3:
				var points := PackedVector2Array()
				var end := player_at+Vector2(-75+k*65,model.pull.y*0.6)
				for j in 13:
					var t := j/12.0
					points.append(player_at.lerp(end,t)+Vector2(sin(t*PI*3+model.clock*3+k)*8*sin(t*PI),0))
				canvas.draw_polyline(points,Color(0.4,0.85,0.82,model.influence*0.42),1.7,true)
		if model.braced:
			canvas.draw_arc(model.position - camera_offset,28,0,TAU,40,Color("f0d7a0"),2,true)
		for i in 12:
			var alpha: float=model.attachment/100*0.021
			canvas.draw_rect(Rect2(i*4,i*4,1152-i*8,648-i*8),Color(0.01,0.05,0.06,alpha),false,8)
	elif coda>0:
		# A reflection leaves the still hero behind; no new playable chapter is unlocked.
		var at: Vector2=model.position+Vector2(coda*23,82)
		canvas.draw_set_transform(at,0,Vector2(0.33,-0.20))
		var cell := HERO.get_size()/4
		var frame: int=[0,1,0,2][int(coda*9)%4]
		canvas.draw_texture_rect_region(HERO,Rect2(-cell.x/2,-cell.y,cell.x,cell.y),Rect2(cell.x*frame,cell.y*2,cell.x,cell.y),Color(0.48,0.75,0.77,0.55*(1-coda/5)))
		canvas.draw_set_transform(Vector2.ZERO)
	if chapter == 1 and vision_blend > 0.001 and last_vision > 0:
		var alpha := smoothstep(0.0, 1.0, vision_blend)
		var window := Rect2(245, 119, 662, 258)
		var art: Texture2D = VISIONS[last_vision - 1]
		var size := art.get_size()
		var ratio := window.size.aspect()
		var source_size := Vector2(minf(size.x, size.y * ratio), minf(size.y, size.x / ratio))
		var source := Rect2((size - source_size) * 0.5, source_size)
		canvas.draw_rect(window, Color(0.02, 0.065, 0.08, alpha * 0.94))
		canvas.draw_texture_rect_region(art, window, source, Color(VISION_TINTS[last_vision - 1], alpha * 0.78))
		canvas.draw_rect(window, Color(0.48, 0.75, 0.74, alpha * 0.5), false, 1)
	if model.dash_time>0:
		for i in 4:
			var at: Vector2 = model.position - camera_offset - Vector2(0, 30) - model.dash_direction * (18 + i * 13)
			canvas.draw_line(at,at-model.dash_direction*15,Color(0.9,0.8,0.5,0.4-i*0.08),2,true)
