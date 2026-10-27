extends Node2D
## Reference-directed aftermath: ruined fleet, the forty-three, bag and flight.
## Acting uses the project's existing illustrations; all shot motion is seekable.
signal sound_cue(kind: String)
const RIG := preload("res://Ato4_Tempestade/Cutscenes/LuckStage.gd")
const ACTING := preload("res://Assets/act4_poseidon/acting.gdshader")
const SEA := preload("res://Assets/act4_released_winds/storm_open_sea.png")
const DECK := preload("res://Assets/act4_released_winds/storm_deck.png")
const SHIP := preload("res://Assets/act4_storm/ship_harpoon_side.png")
const OPEN_BAG := preload("res://Assets/act4_released_winds/wind_bag_rescue.png")
const BAG := preload("res://Assets/act4_friends/wind_bag.png")
var current_shot := "scan"
var current_index := -1
var beat: Dictionary = {}
var duration := 4.2
var age := 0.0
var elapsed := 0.0
var shot_start := 0.0
var speaking := false
var privacy := 0.0
var camera: Node2D
var sea: Sprite2D
var deck: Sprite2D
var scenery: Scenery
var atmosphere: Atmosphere
var odysseus: RIG.Performer
var bag_actor: RIG.Performer
var god: RIG.Performer
var face: RIG.Performer
var kneeling: RIG.Performer
var bag_insert: Sprite2D
var bag_closed: Sprite2D
var captain_ship: Sprite2D
var wind_amount := 0.0
var escape_progress := 0.0
var bag_open_amount := 0.0
var ship_waterline := Vector2.ZERO
var focus := Vector2(576,324)
var zoom := 1.0
var events: Dictionary = {}
var metadata: Dictionary = {}

class Scenery extends Node2D:
	var director: Node2D
	func _draw() -> void: director.draw_scenery(self)

class Atmosphere extends Node2D:
	var director: Node2D
	func _draw() -> void: director.draw_atmosphere(self)

func _ready() -> void:
	metadata=JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_poseidon/regions.json"))
	metadata.merge(JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_luck/regions.json")))
	metadata.merge(JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_friends/regions.json")))
	camera=Node2D.new()
	add_child(camera)
	sea=_plate(SEA)
	scenery=Scenery.new()
	scenery.director=self
	camera.add_child(scenery)
	deck=_plate(DECK)
	deck.z_index=1
	odysseus=_actor("odysseus_luck_poses",430)
	bag_actor=_actor("odysseus_bag_poses",430)
	god=_actor("poseidon",460)
	face=_actor("god_faces",465)
	kneeling=_actor("kneeling",290)
	for actor in [odysseus,bag_actor,god,face,kneeling]: actor.z_index=3
	bag_closed=Sprite2D.new()
	bag_closed.texture=BAG
	bag_closed.z_index=4
	camera.add_child(bag_closed)
	bag_insert=Sprite2D.new()
	bag_insert.texture=OPEN_BAG
	bag_insert.region_enabled=true
	# A tight insert shows Odisseu's two hands and the already drawn open mouth.
	# The neighbouring Euriloco illustration lies outside this source window.
	bag_insert.region_rect=Rect2(340,300,230,270)
	bag_insert.z_index=4
	camera.add_child(bag_insert)
	captain_ship=Sprite2D.new()
	captain_ship.texture=SHIP
	captain_ship.z_index=2
	camera.add_child(captain_ship)
	atmosphere=Atmosphere.new()
	atmosphere.director=self
	atmosphere.z_index=8
	add_child(atmosphere)
	seek(0.0,0.0)

func _plate(texture: Texture2D) -> Sprite2D:
	var sprite:=Sprite2D.new()
	sprite.texture=texture
	sprite.scale=Vector2(1480,834)/texture.get_size()
	sprite.position=Vector2(576,324)
	camera.add_child(sprite)
	return sprite

func _actor(asset: String, height: float) -> RIG.Performer:
	var actor:=RIG.Performer.new(metadata,asset)
	actor.height=height
	camera.add_child(actor)
	actor.set_process(false)
	for sprite in actor.sprites:
		var material:=ShaderMaterial.new()
		material.shader=ACTING
		sprite.material=material
	actor.pose(0)
	return actor

func present(index: int, next_beat: Dictionary) -> void:
	if current_index>=0 and index!=current_index: shot_start+=duration
	current_index=index
	beat=next_beat
	current_shot=str(beat.get("shot","scan"))
	duration=float(beat.get("duration",4.0))
	age=0.0
	events.clear()
	seek(0.0,0.0)

func _phase(start: float, finish: float) -> float:
	return smoothstep(start,finish,age)

func _once(key: String, time: float, sound: String) -> void:
	if age>=time and not events.has(key):
		events[key]=true
		sound_cue.emit(sound)

func _pose(actor: RIG.Performer, index: int, flip: bool=false, height: float=-1.0, blend_start: float=-99.0) -> void:
	if height>0.0 and not is_equal_approx(actor.height,height):
		actor.height=height
		actor.pose_index=-1
	if actor.pose_index!=index:
		actor.pose(index)
	var transition: float=smoothstep(0.0,0.16,age-blend_start)
	for i in actor.sprites.size():
		var sprite: Sprite2D=actor.sprites[i]
		sprite.modulate.a=transition if i==actor.front else 1.0-transition
		if i==actor.front: sprite.flip_h=flip
		var material:=sprite.material as ShaderMaterial
		material.set_shader_parameter("clock",elapsed)
		material.set_shader_parameter("speaking",1.0 if actor.speaking else 0.0)
		material.set_shader_parameter("tension",0.4+wind_amount)
	actor.clock=elapsed

func _camera(at: Vector2, magnification: float) -> void:
	focus=at
	zoom=magnification
	camera.scale=Vector2.ONE*zoom
	camera.position=Vector2(576,324)-focus*zoom
	for plate in [sea,deck]:
		var half_size: Vector2=plate.texture.get_size()*plate.scale*0.5
		var top_left: Vector2=-camera.position/zoom
		var bottom_right: Vector2=(Vector2(1152,648)-camera.position)/zoom
		plate.position=Vector2(clampf(576,bottom_right.x-half_size.x+15,top_left.x+half_size.x-15),clampf(324,bottom_right.y-half_size.y+15,top_left.y+half_size.y-15))

func seek(time: float, _delta: float) -> void:
	if not is_instance_valid(camera): return
	age=maxf(0,time)
	elapsed=shot_start+age
	var progress: float=clampf(age/maxf(0.1,duration),0.0,1.0)
	wind_amount=0.0
	bag_open_amount=0.0
	escape_progress=0.0
	sea.show()
	deck.visible=current_shot not in ["wrecks","escape","remember"]
	deck.modulate=Color(0.82,0.88,0.91)
	sea.modulate=Color(0.71,0.80,0.85)
	for actor in [odysseus,bag_actor,god,face,kneeling]:
		actor.hide()
		actor.speaking=false
		actor.modulate=Color.WHITE
		actor.rotation=0.0
	odysseus.position=Vector2(390,586)
	bag_actor.position=Vector2(465,586)
	god.position=Vector2(815,578)
	face.position=Vector2(815,615)
	kneeling.position=Vector2(400,581)
	bag_closed.hide()
	bag_insert.hide()
	captain_ship.hide()
	var at:=Vector2(576,324)
	var magnification:=1.10
	match current_shot:
		"scan":
			odysseus.show()
			_pose(odysseus,3 if age<1.1 else 5,age<1.1,430,1.1 if age>=1.1 else -99.0)
			odysseus.position.x=390+_phase(1.1,2.6)*12
			odysseus.rotation=0.025*sin(age*0.9)
			at=Vector2(420+progress*55,320)
			magnification=lerpf(1.24,1.34,progress)
		"wrecks":
			at=Vector2(lerpf(515,655,progress),332)
			magnification=1.0
			_once("timber",0.6,"wood_snap")
		"question":
			odysseus.show()
			odysseus.speaking=speaking
			_pose(odysseus,2,false,430)
			god.show()
			_pose(god,0,true,430)
			god.modulate=Color(0.75,0.86,0.91,0.76)
			at=Vector2(431,285)
			magnification=1.62
		"forty_three":
			face.show()
			face.speaking=speaking
			_pose(face,3 if age<2.8 else 1,true,465,2.8 if age>=2.8 else -99.0)
			at=Vector2(810,280)
			magnification=lerpf(1.22,1.34,progress)
		"reaction":
			kneeling.show()
			_pose(kneeling,0,false,340)
			at=Vector2(410,395)
			magnification=1.42
		"last_words":
			god.show()
			god.speaking=speaking
			_pose(god,3,true,465)
			kneeling.show()
			_pose(kneeling,0,false,235)
			at=Vector2(670,315)
			magnification=1.17
		"bag_reveal":
			bag_actor.show()
			_pose(bag_actor,3 if age<0.7 else 4,false,435,0.7 if age>=0.7 else -99.0)
			bag_actor.position.y-=sin(_phase(0.0,1.1)*PI)*5
			at=Vector2(520,340)
			magnification=1.40
			_once("cloth",0.30,"grip")
		"bag_open":
			# Cut from the visible sealed cord to the drawn hands stretching its mouth.
			# The fast insert preserves the actor's identity and excludes his companion.
			bag_actor.show()
			_pose(bag_actor,3,false,435)
			bag_actor.modulate.a=1.0-_phase(0.25,0.35)
			bag_insert.show()
			bag_insert.position=Vector2(576,540)
			bag_insert.scale=Vector2.ONE*4.2
			bag_insert.modulate.a=_phase(0.25,0.35)
			bag_open_amount=_phase(1.30,1.55)
			wind_amount=bag_open_amount
			at=Vector2(576,337)
			magnification=lerpf(1.28,1.38,progress)
			_once("cord",0.25,"grip")
		"surprise":
			face.show()
			face.speaking=speaking
			_pose(face,2,true,465)
			face.rotation=lerpf(0.0,0.025,_phase(0.05,0.45))
			at=Vector2(810,270)
			magnification=1.30
			wind_amount=1.0
		"escape":
			escape_progress=smoothstep(0.0,duration,age)
			wind_amount=1.0
			captain_ship.show()
			var width: float=lerpf(610,185,escape_progress)
			captain_ship.scale=Vector2.ONE*width/SHIP.get_width()
			captain_ship.position=Vector2(lerpf(360,1010,escape_progress),lerpf(370,312,escape_progress)+sin(age*3.1)*6*(1-escape_progress))
			captain_ship.rotation=-0.035+sin(age*3.6)*0.025*(1-escape_progress)
			ship_waterline=captain_ship.position+Vector2(0,SHIP.get_height()*captain_ship.scale.y*0.34)
			god.show()
			_pose(god,0,false,lerpf(220,155,escape_progress))
			god.position=Vector2(195,348)
			god.modulate=Color(0.60,0.75,0.80,0.82)
			at=Vector2(576,324)
			magnification=1.0
		"look_back":
			bag_actor.show()
			_pose(bag_actor,5,false,430)
			bag_actor.position=Vector2(475,585)
			bag_actor.rotation=-0.04
			at=Vector2(485,310)
			magnification=1.52
			wind_amount=0.75
		"remember":
			god.show()
			god.speaking=speaking
			_pose(god,0,false,lerpf(185,148,progress))
			god.position=Vector2(415,352)
			god.modulate=Color(0.67,0.79,0.84)
			at=Vector2(576,324)
			magnification=lerpf(1.0,0.98,progress)
			wind_amount=0.25
			sea.modulate=Color(0.64,0.75,0.81)
	_camera(at,magnification)
	scenery.queue_redraw()
	atmosphere.queue_redraw()

func draw_scenery(canvas: Node2D) -> void:
	if current_shot in ["wrecks","remember"]:
		# Broken bow/stern pieces instead of eleven undamaged boats on the surface.
		var amount: int=11 if current_shot=="wrecks" else 4
		for i in amount:
			var scale_value: float=0.11+float(i%3)*0.055
			var at:=Vector2(50+i*107,355+float(i%4)*34+sin(elapsed*0.9+i)*3)
			if current_shot=="remember":
				scale_value*=0.58
				at=Vector2(55+i*255,385+float(i%2)*31)
			canvas.draw_set_transform(at,[-0.17,0.23,-0.08,0.11][i%4],Vector2.ONE*scale_value)
			var region:=Rect2(0,615,615,285) if i%2==0 else Rect2(1060,640,612,260)
			canvas.draw_texture_rect_region(SHIP,Rect2(-region.size*Vector2(0.5,0.2),region.size),region,Color(0.51,0.56,0.58))
			canvas.draw_set_transform(Vector2.ZERO)
			var wet_width: float=region.size.x*scale_value+20
			_water_patch(canvas,Rect2(at+Vector2(-wet_width*0.5,7),Vector2(wet_width,region.size.y*scale_value+25)))
			for j in 3:
				var drift: float=sin(elapsed*0.8+i+j)*2
				canvas.draw_line(at+Vector2(j*19-30,14+drift),at+Vector2(j*19+2,9+drift),Color(0.38,0.28,0.17),4-j,true)
			if i%3==0:
				canvas.draw_line(at+Vector2(-25,4),at+Vector2(60,-20),Color(0.32,0.22,0.13),4,true)
				var sail:=PackedVector2Array([at+Vector2(-20,1),at+Vector2(34,-12),at+Vector2(21,22),at+Vector2(7,8)])
				canvas.draw_colored_polygon(sail,Color(0.53,0.51,0.42,0.8))
			var foam:=PackedVector2Array()
			for j in 16:
				var u: float=j/15.0
				foam.append(at+Vector2((u-0.5)*wet_width,7+sin(u*8+elapsed*2+i)*1.7))
			canvas.draw_polyline(foam,Color(0.68,0.84,0.84,0.66),1.8,true)
	if not deck.visible:
		for band in 5:
			var points:=PackedVector2Array()
			for i in 35:
				points.append(Vector2(i*38-50,380+band*43+sin(i*0.55-elapsed*1.6+band)*5))
			canvas.draw_polyline(points,Color(0.70,0.83,0.84,0.10),1.6,true)

func _water_patch(canvas: Node2D, rect: Rect2) -> void:
	# The original painted sea occludes submerged timber, with matching UVs.
	# This produces a real wet edge without an opaque coloured rectangle.
	var bounds:=Rect2(sea.position-sea.texture.get_size()*sea.scale*0.5,sea.texture.get_size()*sea.scale)
	var source:=Rect2((rect.position-bounds.position)/sea.scale,rect.size/sea.scale)
	canvas.draw_texture_rect_region(SEA,rect,source,sea.modulate)

func draw_atmosphere(canvas: Node2D) -> void:
	# Rain and cloth movement continue within held dialogue shots on the same clock.
	for i in 74:
		var at:=Vector2(fposmod(i*91.7-elapsed*(110+wind_amount*370),1320)-80,fposmod(i*67.3+elapsed*265,760)-50)
		canvas.draw_line(at,at+Vector2(-7-wind_amount*19,17),Color(0.69,0.85,0.9,0.08+wind_amount*0.035),1.0,true)
	if wind_amount>0.0:
		for ribbon in 8:
			var points:=PackedVector2Array()
			var origin:=Vector2(576,280) if current_shot=="bag_open" else Vector2(230,290)
			for i in 28:
				var u: float=i/27.0
				points.append(origin+Vector2(-u*900,(ribbon-3.5)*u*21+sin(u*10+elapsed*7+ribbon)*u*9))
			canvas.draw_polyline(points,Color(0.75,0.94,0.93,wind_amount*0.14),2.0,true)
		for i in 17:
			var at:=Vector2(fposmod(i*143-elapsed*620,1500)-160,110+i*25+sin(elapsed*3+i)*5)
			canvas.draw_line(at,at+Vector2(95,-7),Color(0.84,0.95,0.95,wind_amount*0.12),1.4,true)
	if current_shot=="escape":
		canvas.draw_set_transform(camera.position,0,camera.scale)
		var painted_width: float=captain_ship.texture.get_width()*captain_ship.scale.x
		_water_patch(canvas,Rect2(ship_waterline+Vector2(-painted_width*0.55,0),Vector2(painted_width*1.1,80)))
		canvas.draw_set_transform(Vector2.ZERO)
		var water: Vector2=camera.transform*ship_waterline
		var width: float=captain_ship.texture.get_width()*captain_ship.scale.x
		for band in 4:
			var wake:=PackedVector2Array()
			for i in 25:
				var u: float=i/24.0
				wake.append(water+Vector2(-width*0.3-u*(290-escape_progress*130),sin(u*10-elapsed*6+band)*3+band*3))
			canvas.draw_polyline(wake,Color(0.77,0.93,0.93,0.36-band*0.055),2.2-band*0.3,true)
	if current_shot in ["escape","remember"] and god.visible:
		var feet: Vector2=camera.transform*god.position
		for i in 3: canvas.draw_arc(feet+Vector2(0,i*2),god.height*(0.21+i*0.03),0.05,PI-0.05,25,Color(0.70,0.91,0.9,0.26-i*0.05),1.8,true)
	if current_shot=="bag_open" and bag_open_amount>0:
		canvas.draw_rect(Rect2(0,0,1152,648),Color(0.71,0.91,0.94,sin(bag_open_amount*PI)*0.12))
