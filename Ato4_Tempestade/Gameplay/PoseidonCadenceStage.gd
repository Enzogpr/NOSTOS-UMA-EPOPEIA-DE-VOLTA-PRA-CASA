extends "res://Ato4_Tempestade/Gameplay/PoseidonEscapeStage.gd"
## Camera and acting for the musical route. Every traversable timber is drawn
## from the same pair of endpoints used by the collision model.
const DIVINE_MATERIAL := preload("res://Assets/act4_poseidon/acting.gdshader")
const SOLDIER_ATLAS := preload("res://Assets/act4_poseidon_soldiers/water_soldier_combat.png")
const COMBAT_ATLAS := preload("res://Assets/act4_poseidon_soldiers/odysseus_combat.png")
const SOLDIER_RECTS := [Rect2(0,0,627,440),Rect2(627,0,627,440),Rect2(0,440,627,430),Rect2(627,440,627,430),Rect2(0,870,657,384),Rect2(657,870,597,384)]
const SOLDIER_FEET := [Vector2(312,432),Vector2(275,432),Vector2(321,423),Vector2(262,423),Vector2(320,367),Vector2(227,367)]
const COMBAT_FEET := [Vector2(278,470),Vector2(285,470),Vector2(263,470),Vector2(280,452),Vector2(310,452),Vector2(300,452)]
const SIDE_WAVE := preload("res://Assets/act4_poseidon_escape/wave_side_v2.png")
var encounter: Variant
var god: RIG.Performer
var atmosphere: CadenceAtmosphere
var displayed_presence := 0.0
var displayed_storm := 0.0
var actor_lean := 0.0
var last_section := ""
var section_age := 99.0
var death_starts: Dictionary = {}

class CadenceAtmosphere extends Node2D:
	var director: Node2D
	func _draw() -> void: director.draw_atmosphere(self)

func _ready() -> void:
	encounter = model
	super._ready()
	distant_ship.hide()
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_poseidon/regions.json"))
	god = RIG.Performer.new(metadata,"poseidon")
	god.height = 615
	add_child(god)
	move_child(god,sea.get_index()+1)
	for sprite in god.sprites:
		var material := ShaderMaterial.new()
		material.shader = DIVINE_MATERIAL
		sprite.material = material
	god.pose(0)
	for sprite in horse.sprites:
		var material := ShaderMaterial.new()
		material.shader = DIVINE_MATERIAL
		sprite.material = material
	horse.height = 410
	horse.hide()
	atmosphere = CadenceAtmosphere.new()
	atmosphere.director = self
	add_child(atmosphere)
	move_child(atmosphere,world.get_index())
	reset_camera()
	update_visuals(0)

func reset_camera() -> void:
	encounter = model
	focus = clampf(model.position.x+175,576,model.final_origin+560)
	camera_zoom = 1.0
	camera_y = 0.0
	section_age = 99.0
	last_section = str(_value("score_section","surge"))
	displayed_presence = float(_value("god_presence",0.0))
	displayed_storm = float(_value("tension",0.3))
	actor_lean = 0.0
	death_starts.clear()
	if is_instance_valid(world): update_visuals(0)

func _value(key: String, fallback: Variant) -> Variant:
	if encounter == null: return fallback
	var value: Variant = encounter.get(key)
	return fallback if value == null else value

func update_visuals(dt: float) -> void:
	if model == null or not is_instance_valid(world): return
	encounter = model
	# One simulation clock keeps foam, actor motion and ship movement stationary
	# on a pause; render frame rate never advances the musical choreography.
	var previous_elapsed: float = elapsed
	elapsed = model.clock
	var visual_dt: float = minf(maxf(elapsed-previous_elapsed,0.0),0.1) if dt > 0 else 0.0
	var section: String = str(_value("score_section","surge"))
	if section != last_section:
		last_section = section
		section_age = 0.0
	section_age += visual_dt
	var state: String = str(_value("encounter_state","traversal"))
	var final: bool = state in ["bag","return","escaping"] or model.phase in [MODEL.Phase.FINAL_SHIP,MODEL.Phase.ESCAPING,MODEL.Phase.COMPLETE]
	var look_ahead: float = 180.0 if model.facing >= 0 else -95.0
	var target_focus: float = clampf(model.position.x+look_ahead,576,model.final_origin+560)
	var target_zoom := 1.0
	if section == "wrecks": target_zoom = 0.97
	if section == "onslaught": target_zoom = 0.94
	if state == "refuge": target_zoom = 1.02
	if final:
		target_zoom = 0.87
		target_focus = clampf(model.position.x+120*model.facing,model.final_origin+560,model.final_origin+1040)
	# A brief opening lets the player see a ship receive Poseidon's attack.
	# It never takes the next landing out of view or interrupts the controls.
	if not final:
		for i in mini(model.boats.size(),10):
			var age: float = model.clock-model.sunk_at[i] if model.sunk_at[i]>=0 else 99.0
			var distance: float = model.position.x-model.boats[i].rect.end.x
			if age>=0 and age<1.5 and distance>-150 and distance<1000:
				var open: float = sin(PI*clampf(age/1.5,0,1))
				target_focus -= 145*open
				target_zoom = minf(target_zoom,1.0-open*0.13)
				break
	if _wind_has_released():
		var escape_scale: float = _escape_scale()
		target_focus = model.final_origin+800*escape_scale+_escape_offset().x
		target_zoom = lerpf(0.78,0.72,_escape_progress())
	if dt <= 0:
		focus = target_focus
		camera_zoom = target_zoom
	else:
		focus = lerpf(focus,target_focus,1-exp(-visual_dt*4.1))
		camera_zoom = lerpf(camera_zoom,target_zoom,1-exp(-visual_dt*1.8))
	var y_target: float = clampf(280.0-model.position.y,0.0,60.0)
	camera_y = lerpf(camera_y,y_target,1-exp(-visual_dt*2.5))
	world.scale = Vector2.ONE*camera_zoom
	# The impact is bounded and belongs to a real collision/destruction event;
	# the beat itself never shakes the camera.
	var shake: float = minf(model.impact_flash*3.0,2.0)
	world.position = Vector2(576-focus*camera_zoom,475-475*camera_zoom+camera_y)+Vector2(sin(elapsed*47),cos(elapsed*43))*shake
	(sea.material as ShaderMaterial).set_shader_parameter("storm_clock",elapsed)
	var storm: float = float(_value("tension",0.45))
	displayed_storm = lerpf(displayed_storm,storm,1-exp(-visual_dt*1.6)) if dt > 0 else storm
	sea.modulate = Color(0.68,0.79,0.83).lerp(Color(0.41,0.61,0.69),displayed_storm*0.72)
	if _wind_has_released(): sea.modulate = sea.modulate.lerp(Color(0.72,0.82,0.85),_escape_progress()*0.44)
	_update_actor(visual_dt)
	_update_death_clocks()
	_update_divine(visual_dt,state,section)
	geometry.queue_redraw()
	foreground.queue_redraw()
	if is_instance_valid(atmosphere): atmosphere.queue_redraw()

func _update_actor(dt: float) -> void:
	super._update_actor(dt)
	var slope := 0.0
	if model.grounded and model.support >= 0:
		var ends: Array = encounter.surface_endpoints(model.support)
		if ends.size() > 1: slope = (ends[1]-ends[0]).angle()
	var desired: float = clampf(slope,-0.12,0.12)
	if model.grounded and not model.crouching:
		desired += clampf(model.velocity.x/305.0,-1.0,1.0)*0.035
	var dashing: bool=float(_value("dash_time",0.0))>0.0
	if dashing and model.grounded: desired+=model.facing*0.095
	actor_lean = lerpf(actor_lean,desired,1-exp(-dt*13.0))
	odysseus.rotation = actor_lean
	# Compression pivots at the authored feet of each atlas frame. It cannot
	# move the character away from a landing or accumulate a visual offset.
	if model.grounded and not model.crouching:
		var squash: float = clampf(model.landing_flash,0.0,0.1)*0.7
		odysseus.scale *= Vector2(1.0+squash*0.32,1.0-squash)
	var boarding: Variant = _value("boarding",null)
	if boarding != null and not dashing and not model.has_bag and model.grounded and not model.crouching and absf(model.velocity.x)<65 and model.phase==MODEL.Phase.FINAL_SHIP:
		var attack_age: float = float(boarding.player_attack_age)
		var pose := -1
		if attack_age>=0:
			pose = 1 if attack_age<0.075 else 2 if attack_age<0.195 else 3
		elif bool(boarding.player_guarding): pose=4
		elif model.hit_flash>0: pose=5
		elif absf(model.velocity.x)<18 and not model.crouching: pose=0
		if pose>=0:
			odysseus.texture=COMBAT_ATLAS
			odysseus.region_rect=Rect2((pose%3)*512,(pose/3)*512,512,512)
			odysseus.offset=-COMBAT_FEET[pose]
			var acting_face: float=float(boarding.player_attack_facing) if attack_age>=0 else model.facing
			odysseus.scale=Vector2(0.202*acting_face,0.202)
			if attack_age>=0:
				odysseus.rotation = model.facing*lerpf(-0.035,0.055,smoothstep(0.075,0.3,attack_age))
	if model.phase == MODEL.Phase.ESCAPING:
		# The score may wait for the end of a phrase before releasing the wind.
		# Keep the player at the actual bag-opening position during that wait.
		odysseus.visible = true
		if _wind_has_released():
			var anchor := Vector2(model.final_origin,model.boats[int(_value("final_index",10))].rect.position.y)
			odysseus.position = anchor+(model.position-anchor)*_escape_scale()+_escape_offset()
			odysseus.scale *= _escape_scale()
			odysseus.rotation = -0.035

func _update_divine(dt: float, state: String, section: String) -> void:
	if not is_instance_valid(god): return
	var presence: float = float(_value("god_presence",0.0))
	if state == "refuge": presence *= 0.4
	if _wind_has_released(): presence *= 1.0-smoothstep(0,4.0,_escape_local_age())
	displayed_presence = lerpf(displayed_presence,presence,1-exp(-dt*2.4)) if dt > 0 else presence
	var pose := 0
	var active_slam := false
	var slam_age := -99.0
	for hazard in model.hazards:
		if str(hazard.kind) != "slam": continue
		var age: float = float(hazard.age)-float(hazard.warning)
		if age > -0.4 and age < 0.5:
			active_slam = true
			slam_age = age
			pose = 2 if age < 0 else 4
			break
	if not active_slam and section == "onslaught": pose = 5
	if not active_slam and state == "return": pose = 2
	god.pose(pose)
	god.position = Vector2(914+sin(elapsed*0.19)*7,650+sin(elapsed*0.8)*2)
	god.modulate = Color(0.59,0.79,0.88,displayed_presence*0.75)
	god.visible = displayed_presence > 0.015
	for sprite in god.sprites:
		(sprite.material as ShaderMaterial).set_shader_parameter("emergence",1.0)
		(sprite.material as ShaderMaterial).set_shader_parameter("tension",displayed_storm)
	# The water horse is a short manifestation during a heavy attack, rather
	# than a static cutout that follows the runner for the entire level.
	var horse_alpha: float = (smoothstep(-0.4,-0.15,slam_age)*(1.0-smoothstep(0.12,0.5,slam_age))) if active_slam else 0.0
	horse.visible = horse_alpha > 0.015 and displayed_presence > 0.15
	if horse.visible:
		horse.pose(3 if slam_age < 0 else 4)
		horse.position = Vector2(745-slam_age*35,500+sin(elapsed*1.2)*3)
		horse.modulate = Color(0.52,0.77,0.85,horse_alpha*0.58)

func draw_atmosphere(canvas: Node2D) -> void:
	if encounter == null: return
	for i in 7:
		canvas.draw_rect(Rect2(0,i*27,1152,29),Color(0.015,0.035,0.055,(0.13+displayed_storm*0.1)*(1.0-i/8.0)))
	# Distant fleet has a deliberately different scale, below the horizon. It
	# never masquerades as an additional playable support.
	for i in 6:
		var x: float = fposmod(140+i*227-focus*0.11,1430)-130
		var sinking_at: float = float(_value("background_sunk_at",-1.0)) if i==5 else model.sunk_at[i]
		var age: float = maxf(0.0,model.clock-sinking_at) if sinking_at>=0 else 0.0
		var fade: float = 1.0-smoothstep(0.0,3.5,age)
		var p := Vector2(x,300+i%2*12+sin(elapsed*0.7+i)*2+age*17)
		canvas.draw_set_transform(p,age*0.12)
		canvas.draw_texture_rect(SMALL_SHIP,Rect2(-46,-28,92,51),false,Color(0.3,0.47,0.55,0.4*fade))
	canvas.draw_set_transform(Vector2.ZERO)
	# Mist integrates the giant with the same sea instead of exposing its feet
	# as a standing character at an unrelated depth.
	for i in 11:
		canvas.draw_rect(Rect2(0,353+i*26,1152,28),Color(0.045,0.12,0.16,smoothstep(0,10,i)*0.61))
	for band in 2:
		var mist := PackedVector2Array()
		for i in 47:
			mist.append(Vector2(i*26,315+band*38+sin(i*0.25-elapsed*0.35+band)*6))
		canvas.draw_polyline(mist,Color(0.4,0.64,0.72,0.045),16,true)

func _ship_segment(canvas: Node2D, boat: Rect2, platform_index: int, alpha: float = 1.0) -> void:
	var p: Dictionary = model.platforms[platform_index]
	var base: Rect2 = p.rect
	var ends: Array = encounter.surface_endpoints(platform_index)
	if ends.size() < 2: return
	var a: Vector2 = ends[0]
	var b: Vector2 = ends[1]
	var length: float = a.distance_to(b)
	var ship_scale: float = (boat.size.x+38.0)/1536.0
	var left_extra: float = 19.0 if absf(base.position.x-boat.position.x) < 1.0 else 0.0
	var right_extra: float = 19.0 if absf(base.end.x-boat.end.x) < 1.0 else 0.0
	var source_left: float = clampf((base.position.x-left_extra-(boat.position.x-19.0))/ship_scale,0,1536)
	var source_width: float = minf((base.size.x+left_extra+right_extra)/ship_scale,1536-source_left)
	var local_scale: float = length/maxf(base.size.x,1.0)
	# Upper rigging is authored as one connected object, separately below. A
	# broken hull must not leave scraps of its sail hanging over other halves.
	var source_top := 510.0
	canvas.draw_set_transform(a,(b-a).angle())
	canvas.draw_texture_rect_region(BOAT,Rect2(-left_extra*local_scale,(source_top-653)*ship_scale,(length+(left_extra+right_extra)*local_scale),(1024-source_top)*ship_scale),Rect2(source_left,source_top,source_width,1024-source_top),Color(0.84,0.88,0.9,alpha))
	# One thin walkable timber aligns the painted deck precisely to collision.
	canvas.draw_texture_rect_region(BOAT,Rect2(0,0,length,12),Rect2(330,653,700,66),Color(0.81,0.78,0.65,alpha))
	canvas.draw_set_transform(Vector2.ZERO)

func draw_world(canvas: Node2D) -> void:
	if encounter == null: return
	var min_x: float = focus-900
	var max_x: float = focus+900
	if bool(_value("front_active",false)):
		var front: float = float(_value("front_x",-500.0))
		if front > min_x-800 and front < max_x+200:
			WATER_ACTING.draw_pursuit_signed(canvas,SIDE_WAVE,front,elapsed,MODEL.WATER_SURFACE_Y,min_x)
	for i in model.boats.size():
		var r: Rect2 = model.boats[i].rect
		if r.end.x < min_x or r.position.x > max_x: continue
		var is_final: bool = i == int(_value("final_index",10))
		if is_final and _wind_has_released(): continue
		if not is_final and model.sunk_at[i]>=0:
			_draw_sinking_ship(canvas,i)
			continue
		var width: float=r.size.x+38
		var scale_value: float=width/1536.0
		canvas.draw_texture_rect_region(BOAT,Rect2(r.position.x-19,r.position.y-653*scale_value,width,510*scale_value),Rect2(0,0,1536,510),Color(0.84,0.88,0.9))
	for i in model.platforms.size():
		var p: Dictionary = model.platforms[i]
		if _wind_has_released() and int(p.boat)==int(_value("final_index",10)): continue
		if p.kind=="deck" and int(p.boat)!=int(_value("final_index",10)) and model.sunk_at[int(p.boat)]>=0: continue
		var ends: Array = encounter.surface_endpoints(i)
		if ends.size() < 2: continue
		var a: Vector2 = ends[0]
		var b: Vector2 = ends[1]
		if b.x < min_x or a.x > max_x: continue
		var kind: String = str(p.kind)
		var alpha := 1.0
		if p.get("gone",false):
			var drop_at: float = float(p.get("drop_at",-1.0))
			if drop_at < 0.0: continue
			var drop_age: float = maxf(0.0,model.clock-drop_at)
			if drop_age > 1.5: continue
			alpha = 1.0-smoothstep(0.6,1.5,drop_age)
		if kind in ["deck","bow"]:
			_ship_segment(canvas,model.boats[int(p.boat)].rect,i,alpha)
		elif kind == "wreck":
			var drop: float = maxf(0.0,(model.clock-float(p.get("drop_at",-1.0)))/0.6) if float(p.get("drop_at",-1.0)) >= 0 else 0.0
			_draw_floating_wreck(canvas,Rect2(a,Vector2(a.distance_to(b),20)),i%4,minf(drop,1.0))
		else:
			_draw_supported_deck(canvas,Rect2(a,Vector2(b.x-a.x,18)),int(p.boat))
	_draw_ship_damage(canvas)
	for obstacle in model.obstacles:
		if not bool(obstacle.get("active",true)): continue
		var bi: int = int(obstacle.boat)
		if _wind_has_released() and bi == int(_value("final_index",10)): continue
		if bi >= 0 and bi < model.sunk_at.size() and bi != int(_value("final_index",10)) and model.sunk_at[bi] >= 0: continue
		var r: Rect2 = obstacle.rect
		if r.end.x < min_x or r.position.x > max_x: continue
		if str(obstacle.kind) in ["beam","yard","sail"]:
			if bi == int(_value("final_index",10)):
				_draw_supported_beam(canvas,r,model.boats[bi].rect.position.y)
			else:
				_draw_hanging_yard(canvas,r,model.boats[bi].rect)
		else:
			_draw_cargo(canvas,r)
	_draw_fleet_assaults(canvas)
	_draw_dash_motion(canvas)
	_draw_boarders(canvas)
	if focus > model.final_origin-900: _draw_final(canvas)
	if _wind_has_released(): _draw_escape(canvas)

func _draw_supported_deck(canvas: Node2D, r: Rect2, boat_index: int) -> void:
	var deck: Rect2 = model.boats[boat_index].rect
	# A landing over the deck is a crate stack, with a visible solid connection
	# all the way to the hull. It is never an arbitrary plank suspended in air.
	_draw_cargo(canvas,Rect2(r.position,Vector2(r.size.x,maxf(18,deck.position.y-r.position.y))))
	_plank(canvas,r,Color(0.76,0.71,0.57))

func _draw_supported_beam(canvas: Node2D, r: Rect2, deck_y: float) -> void:
	# The mast no longer exists in the changed return route. A low cargo frame
	# stands on its own posts instead of leaving cables tied to an empty sky.
	for x in [r.position.x-8,r.end.x+8]:
		canvas.draw_line(Vector2(x,r.position.y+4),Vector2(x,deck_y+4),Color(0.24,0.18,0.11),9,true)
		canvas.draw_line(Vector2(x+1,r.position.y+6),Vector2(x+1,deck_y+3),Color(0.53,0.4,0.21),2,true)
	if debris_texture != null:
		canvas.draw_texture_rect_region(debris_texture,r.grow(3),Rect2(35,690,720,106),Color(0.73,0.75,0.65))
	else:
		_plank(canvas,r,Color(0.7,0.67,0.54))

func _draw_cargo(canvas: Node2D, r: Rect2) -> void:
	canvas.draw_rect(r,Color(0.27,0.19,0.11))
	# Narrow grain and fasteners belong to the timber; they never turn into
	# decorative landing markers or advertise an incoming attack.
	for i in 13:
		var y: float = r.position.y+r.size.y*(i+0.4)/13.0
		var x: float = r.position.x+4+fposmod(i*29.0,maxf(5,r.size.x-35))
		canvas.draw_line(Vector2(x,y),Vector2(minf(r.end.x-4,x+18+i%3*8),y+sin(i*1.7)*0.8),Color(0.44,0.31,0.17,0.5),1,true)
	var rows: int = maxi(1,int(ceil(r.size.y/34.0)))
	for row in rows:
		var y: float = r.position.y+row*r.size.y/rows
		canvas.draw_line(Vector2(r.position.x,y),Vector2(r.end.x,y),Color(0.46,0.32,0.17),2.0,true)
	canvas.draw_rect(r,Color(0.67,0.51,0.27),false,3)
	canvas.draw_line(r.position+Vector2(5,5),r.end-Vector2(5,5),Color(0.58,0.43,0.22),4,true)
	canvas.draw_line(Vector2(r.end.x-5,r.position.y+5),Vector2(r.position.x+5,r.end.y-5),Color(0.58,0.43,0.22),4,true)
	for x in [r.position.x+6,r.end.x-6]:
		for y in [r.position.y+6,r.end.y-6]: canvas.draw_circle(Vector2(x,y),1.5,Color(0.15,0.13,0.1))

func _draw_falling_mast(canvas: Node2D) -> void:
	var age: float = float(_value("split_age",0.0))
	if age > 1.35 or focus < model.final_origin-800: return
	var deck: Rect2 = model.boats[int(_value("final_index",10))].rect
	var ship_scale: float = (deck.size.x+38)/1536.0
	var pivot := Vector2(deck.position.x-19+835*ship_scale,deck.position.y+age*age*90)
	var fall: float = smoothstep(0.0,0.9,age)
	canvas.draw_set_transform(pivot,fall*1.35)
	# Broken rigging has no floor collider. Only the hull's walkable top follows
	# the physical endpoints; this upper mast visibly detaches and falls away.
	canvas.draw_texture_rect_region(BOAT,Rect2(-235*ship_scale,-653*ship_scale,600*ship_scale,510*ship_scale),Rect2(600,0,600,510),Color(0.7,0.77,0.79,1.0-smoothstep(0.8,1.35,age)))
	canvas.draw_set_transform(Vector2.ZERO)

func _draw_ship_damage(canvas: Node2D) -> void:
	for boat_index in model.boats.size():
		var boat: Dictionary = model.boats[boat_index]
		var rect: Rect2 = boat.rect
		if rect.end.x < focus-950 or rect.position.x > focus+950: continue
		var damage: float = float(boat.get("damage_progress",0.0))
		var sink_age: float = model.clock-model.sunk_at[boat_index] if model.sunk_at[boat_index] >= 0 else -1.0
		if damage > 0.01 and damage < 1.0:
			var split_x: float = float(boat.get("split_x",rect.get_center().x))
			var at := Vector2(split_x,rect.position.y+8)
			var age: float = damage*0.62
			WATER_ACTING.draw_splash(canvas,at,age,1.3)
			for i in 11:
				var direction := Vector2.from_angle(-2.9+i*0.27)
				var travel: float = age*(110+i%4*35)
				var chip: Vector2 = at+direction*travel+Vector2(0,age*age*280)
				canvas.draw_line(chip,chip+direction*7,Color(0.63,0.47,0.24,1.0-damage),3,true)
		if sink_age >= 0 and sink_age < 0.9 and boat_index != int(_value("final_index",10)):
			for j in 3:
				var at := Vector2(lerpf(rect.position.x,rect.end.x,(j+1)/4.0),model.water_height_at(rect.get_center().x,model.clock))
				WATER_ACTING.draw_splash(canvas,at,sink_age-j*0.11,1.25)

func _draw_final(canvas: Node2D) -> void:
	if model.has_bag: return
	var at: Vector2 = model.bag_point
	canvas.draw_texture_rect(BAG,Rect2(at-Vector2(24,51),Vector2(48,49)),false,Color(0.97,0.9,0.69))
	# Small leather ties explain how the bag rests against its cargo support.
	canvas.draw_line(at+Vector2(-12,-3),at+Vector2(12,-3),Color(0.39,0.25,0.11),2,true)

func _draw_sinking_ship(canvas: Node2D, index: int) -> void:
	var deck: Rect2=model.boats[index].rect
	var age: float=maxf(0,model.clock-model.sunk_at[index])
	if age>4.0: return
	var width: float=deck.size.x+38
	var ship_scale: float=width/1536.0
	var fade: float=1.0-smoothstep(2.7,4.0,age)
	var fall: float=10.0*age*age
	# Painted deck and its collider descend together, with exactly10*age².
	# The cracks and spray show structural failure below the walking plane;
	# no horizontal separation or roll moves the deck away from the feet.
	for half in 2:
		var pivot:=Vector2(deck.position.x-19+(half+0.5)*width*0.5,deck.position.y+fall)
		canvas.draw_set_transform(pivot)
		canvas.draw_texture_rect_region(BOAT,Rect2(-width*0.25,-653*ship_scale,width*0.5,1024*ship_scale),Rect2(half*768,0,768,1024),Color(0.73,0.82,0.86,fade))
	canvas.draw_set_transform(Vector2.ZERO)

func _draw_fleet_assaults(canvas: Node2D) -> void:
	var assaults: Array=_value("fleet_assaults",[])
	for assault in assaults:
		var index: int=int(assault.boat)
		if index<0 or index>=mini(10,model.boats.size()): continue
		var deck: Rect2=model.boats[index].rect
		if deck.end.x<focus-1200 or deck.position.x>focus+1200: continue
		var age: float=float(assault.age)
		var duration: float=float(assault.duration)
		var t: float=clampf(age/duration,0,1)
		var alpha: float=smoothstep(0,0.35,age)*(1.0-smoothstep(duration,duration+0.8,age))
		if alpha<0.005: continue
		var water_y: float=model.water_height_at(deck.get_center().x,model.clock)
		var height: float=lerpf(245,475,smoothstep(0,1,t))
		var width: float=height*SIDE_WAVE.get_width()/SIDE_WAVE.get_height()
		var front: float=deck.get_center().x-420+smoothstep(0,1,t)*600
		canvas.draw_texture_rect(SIDE_WAVE,Rect2(front-width*0.975,water_y-height*0.95,width,height),false,Color(0.65,0.87,0.91,alpha*0.87))
		if age>duration-0.08:
			for j in 3:
				WATER_ACTING.draw_splash(canvas,Vector2(lerpf(deck.position.x,deck.end.x,(j+1)/4.0),water_y),age-duration+0.08-j*0.04,1.6)

func _update_death_clocks() -> void:
	var boarding: Variant=_value("boarding",null)
	if boarding==null: return
	for enemy in boarding.enemies:
		var key: int=int(enemy.id)
		if str(enemy.state)=="dead":
			if not death_starts.has(key): death_starts[key]=model.clock-float(enemy.age)
		else: death_starts.erase(key)

func _draw_boarders(canvas: Node2D) -> void:
	var boarding: Variant=_value("boarding",null)
	if boarding==null or model.phase in [MODEL.Phase.ESCAPING,MODEL.Phase.COMPLETE]: return
	for enemy in boarding.enemies:
		var at: Vector2=enemy.position
		if at.x<focus-1000 or at.x>focus+1000: continue
		var state: String=str(enemy.state)
		var age: float=float(enemy.age)
		var pose:=0
		var secondary: int=-1
		var blend:=0.0
		var rotation:=0.0
		var alpha:=1.0
		var face: float=float(enemy.facing)
		var flow: float=sin(elapsed*3.6+int(enemy.id))*0.009
		var vertical:=0.0
		var formation:=1.0
		var collapse:=1.0
		var captain: bool=int(enemy.variant)>1
		if state=="arrive":
			pose=0
			formation=smoothstep(0.0,0.62 if not captain else 0.82,age)
			_draw_water_materialization(canvas,at,age,captain,false)
		elif state=="approach":
			pose=1 if fmod(boarding.elapsed*2.6+int(enemy.id)*0.4,1)>0.46 else 0
			vertical=-absf(sin(boarding.elapsed*8.1+int(enemy.id)))*1.0
			rotation=face*0.015
		elif state=="windup":
			pose=2
			secondary=0
			blend=1.0-smoothstep(0,0.09,age)
			rotation=-face*smoothstep(0,0.35,age)*0.035
		elif state=="strike":
			pose=3 if str(enemy.kind) in ["overhead","sweep"] else 4
			secondary=2
			blend=1.0-smoothstep(0,0.045,age)
			rotation=face*sin(clampf(age/0.2,0,1)*PI)*0.04
		elif state=="recover":
			pose=0
			secondary=3 if str(enemy.kind) in ["overhead","sweep"] else 4
			blend=1.0-smoothstep(0.04,0.23,age)
		elif state in ["stagger","dead"]:
			pose=5
			if state=="dead":
				# The last soldier's AI timer stops on victory. The world clock
				# continues its dissolution, so no corpse remains beside the bag.
				age=model.clock-float(death_starts.get(int(enemy.id),model.clock-age))
				alpha=1.0-smoothstep(0.12,1.02,age)
				collapse=lerpf(1.0,0.24,smoothstep(0.08,0.94,age))
				_draw_water_materialization(canvas,at,age,captain,true)
		if alpha<0.005: continue
		var size_factor: float=0.285 if captain else 0.252
		var tint: Color=Color(0.7,0.91,0.98,alpha) if not captain else Color(0.86,1.0,1.0,alpha)
		if float(enemy.flash)>0: tint=tint.lerp(Color(0.95,1.0,1.0,alpha),0.85)
		# A watery reflection and a few strands connect the figure to the deck.
		canvas.draw_set_transform(at+Vector2(0,2),0,Vector2(1,0.13))
		canvas.draw_circle(Vector2.ZERO,24 if not captain else 28,Color(0.13,0.61,0.73,alpha*0.13))
		if secondary>=0 and blend>0.005:
			canvas.draw_set_transform(at+Vector2(0,vertical),rotation,Vector2(face*size_factor,size_factor*(1.0+flow)*collapse))
			var secondary_tint:=tint
			secondary_tint.a*=blend
			_draw_soldier_pose(canvas,secondary,secondary_tint,formation)
		tint.a*=1.0-blend
		canvas.draw_set_transform(at+Vector2(0,vertical),rotation,Vector2(face*size_factor,size_factor*(1.0+flow)*collapse))
		_draw_soldier_pose(canvas,pose,tint,formation)
		canvas.draw_set_transform(Vector2.ZERO)
		if state=="strike": _draw_water_weapon(canvas,enemy,age)

func _draw_soldier_pose(canvas: Node2D, pose: int, tint: Color, formation: float) -> void:
	var region: Rect2=SOLDIER_RECTS[pose]
	var hidden: float=region.size.y*(1.0-formation)
	region.position.y+=hidden
	region.size.y-=hidden
	if region.size.y<1: return
	var origin: Vector2=-SOLDIER_FEET[pose]+Vector2(0,hidden)
	canvas.draw_texture_rect_region(SOLDIER_ATLAS,Rect2(origin,region.size),region,tint)

func _draw_boarder_health(canvas: Node2D) -> void:
	var boarding: Variant=_value("boarding",null)
	if boarding==null or model.phase in [MODEL.Phase.ESCAPING,MODEL.Phase.COMPLETE]: return
	# These belong to the foreground so weapons, foam and Odisseu cannot cover
	# the health readout. Their world-space anchors still follow each soldier.
	for enemy in boarding.enemies:
		if str(enemy.state)=="dead" or int(enemy.hp)<=0: continue
		var at: Vector2=enemy.position
		if at.x<focus-850 or at.x>focus+850: continue
		var captain: bool=int(enemy.variant)>1
		var height:=122.0 if captain else 108.0
		var alpha:=smoothstep(0.08,0.5,float(enemy.age)) if str(enemy.state)=="arrive" else 1.0
		var maximum: int=maxi(1,int(enemy.max_hp))
		var health: int=clampi(int(enemy.hp),0,maximum)
		var panel:=Rect2(at+Vector2(-45,-height-41),Vector2(90,29))
		canvas.draw_rect(panel,Color(0.015,0.045,0.06,alpha*0.92))
		var bar:=Rect2(panel.position+Vector2(6,20),Vector2(78,5))
		canvas.draw_rect(bar,Color(0.15,0.26,0.29,alpha))
		canvas.draw_rect(Rect2(bar.position,Vector2(bar.size.x*float(health)/maximum,bar.size.y)),Color(0.4,0.9,0.96,alpha))
		var segments: int=mini(maximum,10)
		for pip in range(1,segments):
			var x: float=bar.position.x+bar.size.x*float(pip)/segments
			canvas.draw_line(Vector2(x,bar.position.y),Vector2(x,bar.end.y),Color(0.025,0.07,0.09,alpha),1.0)
		var label: String="%d / %d" % [health,maximum]
		var width: float=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		canvas.draw_string(font,Vector2(at.x-width*0.5,panel.position.y+15),label,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(0.88,0.98,1.0,alpha))

func _draw_dash_motion(canvas: Node2D) -> void:
	var remaining: float=float(_value("dash_time",0.0))
	if remaining<=0.0 or not model.grounded: return
	var face: float=float(_value("dash_direction",model.facing))
	var strength: float=smoothstep(0.0,0.045,remaining)
	# Short deck spray stays behind the actual feet. The character keeps the
	# established side-view atlas, without transparency or an invulnerability cue.
	for i in 4:
		var y: float=-7.0-i*15.0
		var a: Vector2=model.position+Vector2(-face*(15+i*3),y)
		var b: Vector2=a-Vector2(face*(68-i*12),-2.0)
		canvas.draw_line(a,b,Color(0.71,0.83,0.8,strength*(0.25-i*0.04)),1.7-i*0.2,true)
	for i in 5:
		var travel: float=fposmod(elapsed*9+i*0.21,1.0)
		var at: Vector2=model.position+Vector2(-face*(14+travel*90),-sin(travel*PI)*(4+i%3*2))
		canvas.draw_line(at,at-Vector2(face*(4+travel*7),-1),Color(0.73,0.88,0.89,strength*(1.0-travel)*0.35),1.3,true)

func _draw_water_materialization(canvas: Node2D, at: Vector2, age: float, captain: bool, dissolving: bool) -> void:
	var duration: float=1.2 if dissolving else 0.82 if captain else 0.65
	if age<0 or age>duration+0.3: return
	var u: float=clampf(age/duration,0,1)
	var strength: float=sin(clampf(u,0.01,0.99)*PI)
	var size_factor: float=1.13 if captain else 1.0
	# Foam streams rather than a targeting ring: these belong to the body,
	# not to a future area of damage or a HUD warning.
	for j in 5:
		var stream:=PackedVector2Array()
		for i in 15:
			var t: float=i/14.0
			var height: float=(108*size_factor*(1.0-u) if dissolving else 108*size_factor*u)
			var x: float=sin(t*7.0-elapsed*4.0+j*1.3)*(7.0+j*1.8)*(1.0-t)
			stream.append(at+Vector2(x+(j-2)*4,-t*height))
		canvas.draw_polyline(stream,Color(0.4,0.9,0.98,strength*(0.27-j*0.025)),1.4,true)
	for i in 13:
		var direction: float=-1.0 if i%2==0 else 1.0
		var speed: float=18.0+i%5*7
		var t: float=fposmod(u+i*0.081,1.0)
		var p: Vector2=at+Vector2(direction*t*speed*size_factor,-sin(t*PI)*(8+i%4*4))
		canvas.draw_line(p,p+Vector2(direction*3,1.3),Color(0.76,0.97,1.0,(1.0-t)*strength*0.8),1.3,true)

func _draw_water_weapon(canvas: Node2D, enemy: Dictionary, age: float) -> void:
	if age>0.20: return
	var face: float=float(enemy.facing)
	var at: Vector2=enemy.position
	var alpha: float=sin(clampf(age/0.20,0.0,1.0)*PI)*0.78
	var kind: String=str(enemy.kind)
	var path:=PackedVector2Array()
	if kind=="overhead":
		var target: float=float(enemy.target_x)
		var descent: float=smoothstep(0,0.12,age)
		for i in 15:
			var u: float=i/14.0
			path.append(Vector2(lerpf(at.x+face*35,target,u),at.y-118+u*118*descent))
	else:
		var y: float=-18.0 if kind=="sweep" else -70.0
		for i in 15:
			var u: float=i/14.0
			path.append(at+Vector2(face*lerpf(68.0,138.0,u),y+sin(u*7-age*30)*2.2*u))
	canvas.draw_polyline(path,Color(0.12,0.62,0.79,alpha*0.8),7.0,true)
	canvas.draw_polyline(path,Color(0.73,0.96,1.0,alpha),2.0,true)

func _draw_sword_motion(canvas: Node2D) -> void:
	var boarding: Variant=_value("boarding",null)
	if boarding==null or model.phase!=MODEL.Phase.FINAL_SHIP: return
	var age: float=float(boarding.player_attack_age)
	if age<0.075 or age>0.195: return
	var progress: float=clampf((age-0.075)/0.12,0,1)
	var origin: Vector2=model.position+Vector2(0,-43 if not model.crouching else -23)
	var face: float=float(boarding.player_attack_facing)
	var path:=PackedVector2Array()
	for i in 12:
		var t: float=i/11.0
		var angle: float=lerpf(-0.75,0.65,clampf(progress-t*0.48,0,1))
		path.append(origin+Vector2(cos(angle)*face,sin(angle))*92)
	canvas.draw_polyline(path,Color(0.9,0.85,0.65,sin(progress*PI)*0.48),1.8,true)

func draw_foreground(canvas: Node2D) -> void:
	if encounter == null: return
	_draw_near_water(canvas)
	if model.phase not in [MODEL.Phase.ESCAPING,MODEL.Phase.COMPLETE]:
		for hazard in model.hazards:
			var r: Rect2 = model.hazard_rect(hazard)
			if r.end.x < focus-900 or r.position.x > focus+900: continue
			WATER_ACTING.draw(canvas,hazard,r,elapsed,model.water_height_at(r.get_center().x,model.clock))
	_draw_sword_motion(canvas)
	var count: int = 17+int(displayed_storm*19)
	for i in count:
		var p := Vector2(focus-850+fposmod(i*113.0-elapsed*125,1700),fposmod(i*79.0+elapsed*450,730))
		canvas.draw_line(p,p+Vector2(-5,15),Color(0.6,0.81,0.88,0.09+displayed_storm*0.035),1,true)
	_draw_boarder_health(canvas)
	if _wind_has_released():
		var duration: float = float(_value("escape_duration",16.35))
		var age: float = float(_value("escape_score_age",model.phase_clock))
		var fade: float = smoothstep(duration-1.65,duration,age)
		if fade > 0.001: canvas.draw_rect(Rect2(focus-1400,-350,2800,1500),Color(0.005,0.013,0.02,fade))

func _wind_has_released() -> bool:
	return model.phase in [MODEL.Phase.ESCAPING,MODEL.Phase.COMPLETE] and bool(_value("wind_released",false))

func _escape_local_age() -> float:
	return maxf(0.0,float(_value("escape_score_age",model.phase_clock))-float(_value("escape_release_at",3.273)))

func _escape_progress() -> float:
	var playable: float = maxf(1.0,float(_value("escape_duration",16.35))-float(_value("escape_release_at",3.273)))
	return clampf(_escape_local_age()/playable,0.0,1.0)

func _escape_scale() -> float:
	return lerpf(1.0,0.44,smoothstep(0.0,1.0,_escape_progress()))

func _escape_offset() -> Vector2:
	var t: float = _escape_local_age()
	# Initial acceleration comes out of the bag burst; then the ship continues
	# withdrawing throughout the coda instead of leaving an empty background.
	var acceleration: float = smoothstep(0.0,1.0,t)
	return Vector2(-(100*t+2.5*t*t)*acceleration,-_escape_progress()*116)

func _draw_escape(canvas: Node2D) -> void:
	var boat: Rect2 = model.boats[int(_value("final_index",10))].rect
	var source_scale: float = (boat.size.x+38)/1536.0
	var visual_scale: float = _escape_scale()
	var origin := boat.position+_escape_offset()
	var progress: float = _escape_progress()
	canvas.draw_set_transform(origin,0.0,Vector2.ONE*visual_scale)
	# The captain's complete hull and rigging survive both the battle and escape.
	# The exact same texture and cargo travel with Odisseu; no repaired replacement.
	var source_water_y: float=653+88/source_scale
	canvas.draw_texture_rect_region(BOAT,Rect2(-19,-653*source_scale,boat.size.x+38,source_water_y*source_scale),Rect2(0,0,1536,source_water_y),Color(0.84,0.88,0.9))
	canvas.draw_texture_rect_region(BOAT,Rect2(-19,88,boat.size.x+38,9),Rect2(0,source_water_y,1536,9/source_scale),Color(0.15,0.37,0.4,0.3))
	canvas.draw_texture_rect_region(BOAT,Rect2(0,0,boat.size.x,12),Rect2(330,653,700,66),Color(0.81,0.78,0.65))
	for obstacle in model.obstacles:
		if int(obstacle.boat)!=int(_value("final_index",10)): continue
		var local_rect: Rect2=obstacle.rect
		local_rect.position-=boat.position
		if str(obstacle.kind)=="beam": _draw_supported_beam(canvas,local_rect,0.0)
		else: _draw_cargo(canvas,local_rect)
	canvas.draw_set_transform(Vector2.ZERO)
	var contact := origin+Vector2(800,88)*visual_scale
	for j in 4:
		var wake := PackedVector2Array()
		for i in 25:
			var u: float = i/24.0
			wake.append(contact+Vector2((90+u*540)*visual_scale,(sin(u*9-elapsed*4+j)*4+j*5)*visual_scale))
		canvas.draw_polyline(wake,Color(0.63,0.85,0.87,(1.0-progress*0.35)*(0.38-j*0.05)),(2.6-j*0.35)*visual_scale,true)
	# The bag has a stable source on Odisseus' hands. Flow peels backwards from
	# that source as a continuous stream, with no target mark or input warning.
	var source: Vector2 = origin+(model.position-boat.position+Vector2(15,-45))*visual_scale
	var release: float = smoothstep(0.0,0.32,_escape_local_age())
	for j in 7:
		var stream := PackedVector2Array()
		for i in 27:
			var u: float = i/26.0
			stream.append(source+Vector2(u*(400+j*36)*visual_scale,(sin(u*7.0-elapsed*4.3+j)*8*u+(j-3)*u*15)*visual_scale))
		canvas.draw_polyline(stream,Color(0.67,0.92,0.89,release*(0.29-absf(j-3)*0.035)),1.8*visual_scale,true)
