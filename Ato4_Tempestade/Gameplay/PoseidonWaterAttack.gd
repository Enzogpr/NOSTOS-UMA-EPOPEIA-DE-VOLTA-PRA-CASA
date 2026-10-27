extends RefCounted
## Water acting shared by both traversal renderers. Geometry follows the model's
## attack rectangle; only harmless trailing spray extends outside that body.
## No warning marks or input instructions are drawn here.

const WATER := preload("res://Assets/act4_storm/wave_front.png")
const DEEP := Color(0.045,0.18,0.23)
const WATER_LIGHT := Color(0.26,0.59,0.64)
const FOAM := Color(0.78,0.9,0.88)
const SIDE_FRONT_U := 0.975
const SIDE_WATER_V := 0.95
const SIDE_HEIGHT := 560.0
const SIDE_PROFILE_PATH := "res://Ato4_Tempestade/Gameplay/PoseidonWaveProfile.json"
static var side_profile: Dictionary = {}
static var side_texture: Texture2D

static func pursuit_profile() -> Dictionary:
	if side_profile.is_empty() and FileAccess.file_exists(SIDE_PROFILE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SIDE_PROFILE_PATH))
		if parsed is Dictionary: side_profile = parsed
	return side_profile

static func draw_pursuit_signed(canvas: Node2D, texture: Texture2D, front_x: float, elapsed: float, water_y: float, left_bound: float) -> void:
	if texture == null: return
	# Preserve the authored side-view volume and its alpha edge. This is one
	# complete painted wave, with only a small internal flow deformation.
	var profile: Dictionary = pursuit_profile()
	var height: float = float(profile.get("height",SIDE_HEIGHT))
	var front_u: float = float(profile.get("front_u",SIDE_FRONT_U))
	var water_v: float = float(profile.get("water_v",SIDE_WATER_V))
	var size := Vector2(height*texture.get_width()/texture.get_height(),height)
	var origin := Vector2(front_x-size.x*front_u,water_y-size.y*water_v)
	if origin.x+size.x < left_bound: return
	var mesh: ArrayMesh = canvas.get_meta("poseidon_side_water_mesh") as ArrayMesh if canvas.has_meta("poseidon_side_water_mesh") else null
	if mesh == null:
		mesh = ArrayMesh.new()
		canvas.set_meta("poseidon_side_water_mesh",mesh)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var columns := 8
	var rows := 12
	for row in rows+1:
		var v: float = row/float(rows)
		for column in columns+1:
			var u: float = column/float(columns)
			# The contact column and the base stay fixed in world space. The
			# artist's silhouette therefore cannot wobble ahead of physical danger.
			var inside: float = sin(u*PI)*sin(v*PI)
			var contact: float = smoothstep(0.0,0.18,absf(u-front_u))
			var upper: float = 1.0-smoothstep(0.73,water_v,v)
			var dx: float = (sin(v*8.0-elapsed*2.1)*0.014+sin(v*13.0+elapsed*1.7)*0.005)*inside*contact
			var dy: float = sin(u*9.0+v*3.0-elapsed*1.8)*0.011*inside*contact*upper
			vertices.append(Vector3(u+dx,v+dy,0))
			uvs.append(Vector2(u,v))
	for row in rows:
		for column in columns:
			var a: int = row*(columns+1)+column
			var b: int = a+1
			var c: int = a+columns+1
			var d: int = c+1
			indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	canvas.draw_mesh(mesh,texture,Transform2D(Vector2(size.x,0),Vector2(0,size.y),origin),Color.WHITE)

static func draw_pursuit(canvas: Node2D, front_x: float, elapsed: float, water_y: float, left_bound: float) -> void:
	# Compatibility entry point; both routes now draw the complete side-view
	# painting. No reconstruction from the old top-down wave remains here.
	if side_texture == null:
		var path: String = str(pursuit_profile().get("texture",""))
		if not path.is_empty() and ResourceLoader.exists(path): side_texture = load(path) as Texture2D
	if side_texture != null: draw_pursuit_signed(canvas,side_texture,front_x,elapsed,water_y,left_bound)

static func draw_splash(canvas: Node2D, at: Vector2, age: float, strength: float = 1.0) -> void:
	_impact_foam(canvas,at,age,strength)

static func draw(canvas: Node2D, hazard: Dictionary, hit_rect: Rect2, elapsed: float, water_y: float) -> void:
	var age: float = float(hazard.get("age",0.0))
	var onset: float = float(hazard.get("warning",0.0))
	var local_age: float = age-onset
	if str(hazard.get("kind","low")) == "slam":
		var full_rect := Rect2(float(hazard.get("target",hit_rect.get_center().x))-47.0,float(hazard.get("y",hit_rect.end.y-25))-330.0,94,355)
		_column(canvas,full_rect,hit_rect.size.y,local_age,elapsed)
	else:
		_sweep(canvas,hit_rect,hazard,local_age,elapsed,water_y)

static func _sweep(canvas: Node2D, rect: Rect2, hazard: Dictionary, active_age: float, elapsed: float, water_y: float) -> void:
	if active_age < -0.34 or active_age > 3.4: return
	# A short piece of the incoming body forms at the spawn edge, rather than
	# marking the route or advertising which button the player should press.
	var formation: float = smoothstep(-0.34,0.0,active_age)
	var release: float = 1.0-smoothstep(3.04,3.4,active_age)
	var alpha: float = formation*release
	if alpha < 0.005: return
	var offset := Vector2((1.0-formation)*48,0)
	var flow: float = elapsed*8.0
	var width: float = rect.size.x
	var height: float = rect.size.y
	var origin: Vector2 = rect.position+offset
	var high: bool = str(hazard.get("kind")) == "high"
	_sweep_root(canvas,rect,origin,water_y,high,alpha,active_age,elapsed)
	# Curl, face and trailing tongue are one silhouette. Their shallow internal
	# motion never changes the travel speed or creates a second damaging crest.
	var curl: float = sin(elapsed*6.1)*0.055
	var contour := PackedVector2Array()
	_append_curve(contour,Vector2(0.03,1.0),Vector2(-0.025,0.59),Vector2(0.02,0.16),Vector2(0.24,0.04),9)
	_append_curve(contour,Vector2(0.24,0.04),Vector2(0.46,-0.04+curl),Vector2(0.5,0.25),Vector2(0.32,0.22),8)
	_append_curve(contour,Vector2(0.32,0.22),Vector2(0.19,0.19),Vector2(0.19,0.48),Vector2(0.46,0.62),8)
	_append_curve(contour,Vector2(0.46,0.62),Vector2(0.66,0.74),Vector2(0.85,0.64),Vector2(1.0,0.83),8)
	_append_curve(contour,Vector2(1.0,0.83),Vector2(0.84,1.03),Vector2(0.25,1.06),Vector2(0.03,1.0),8)
	_painted_body(canvas,contour,origin,Vector2(width,height),alpha,active_age,0.22)
	var ridge := PackedVector2Array()
	_append_curve(ridge,Vector2(0.035,0.99),Vector2(-0.015,0.53),Vector2(0.04,0.17),Vector2(0.24,0.045),15)
	_append_curve(ridge,Vector2(0.24,0.045),Vector2(0.41,-0.015+curl),Vector2(0.48,0.2),Vector2(0.34,0.2),12)
	_foam_path(canvas,_placed(ridge,origin,Vector2(width,height)),alpha,3.6,flow)
	var tongue := PackedVector2Array()
	_append_curve(tongue,Vector2(0.32,0.44),Vector2(0.5,0.9),Vector2(0.78,0.61),Vector2(0.98,0.83),18)
	_foam_path(canvas,_placed(tongue,origin,Vector2(width,height)),alpha*0.38,1.8,flow+1.0)
	# Foam is carried backwards by the same flow. Sparse flecks dissolve instead
	# of drawing a rectangle of particles around the whole hazard.
	for i in 9:
		var cycle: float = fposmod(active_age*2.3+i*0.173,1.0)
		var at: Vector2 = origin+Vector2(width*(0.2+cycle*0.8),height*(0.06+cycle*0.5))+Vector2(0,sin(i*2.1+cycle*PI)*3)
		var fade: float = sin(cycle*PI)*alpha*0.65
		canvas.draw_line(at,at+Vector2(3.0+cycle*4,1.4),Color(FOAM,fade),1.6,true)
	# The high jet's broken strands stay above the ducking clearance.
	if high:
		var strand := PackedVector2Array()
		for i in 15:
			var t: float = i/14.0
			strand.append(origin+Vector2(t*width,height*(0.9+sin(t*5+flow)*0.045)))
		canvas.draw_polyline(strand,Color(0.35,0.67,0.7,alpha*0.38),2.5,true)

static func _sweep_root(canvas: Node2D, rect: Rect2, origin: Vector2, water_y: float, high: bool, alpha: float, age: float, elapsed: float) -> void:
	# The crest is carried by an uprooted tongue of sea. Its trailing connection
	# sits behind the moving face and descends into the real ocean surface;
	# neither the low wave nor the high crown is a detached flying platform.
	var at: Vector2 = origin+Vector2(rect.size.x*0.52,rect.size.y*0.73)
	var depth: float = maxf(40.0,water_y-at.y+12.0)
	var width: float = 205.0 if high else 162.0
	var sway: float = sin(elapsed*5.2)*0.025
	var shape := PackedVector2Array()
	if high:
		_append_curve(shape,Vector2(0,0),Vector2(0.27,-0.05),Vector2(0.54,0.18+sway),Vector2(0.67,0.48),18)
		_append_curve(shape,Vector2(0.67,0.48),Vector2(0.78,0.7),Vector2(0.83,0.83),Vector2(1,1),14)
		_append_curve(shape,Vector2(1,1),Vector2(0.83,1.08),Vector2(0.78,0.87),Vector2(0.7,0.7),14)
		_append_curve(shape,Vector2(0.7,0.7),Vector2(0.5,0.25),Vector2(0.28,0.17),Vector2(0,0.15),18)
	else:
		_append_curve(shape,Vector2(0,0),Vector2(0.27,-0.01),Vector2(0.39,0.23+sway),Vector2(0.61,0.58),18)
		_append_curve(shape,Vector2(0.61,0.58),Vector2(0.72,0.79),Vector2(0.84,0.86),Vector2(1,1),14)
		_append_curve(shape,Vector2(1,1),Vector2(0.8,1.08),Vector2(0.58,0.87),Vector2(0.43,0.58),14)
		_append_curve(shape,Vector2(0.43,0.58),Vector2(0.29,0.31),Vector2(0.12,0.2),Vector2(0,0.2),18)
	shape.append(Vector2.ZERO)
	_painted_body(canvas,shape,at,Vector2(width,depth),alpha*(0.78 if high else 0.84),age,0.15,true)
	var edge := PackedVector2Array()
	_append_curve(edge,Vector2(0.05,0.045),Vector2(0.38,0.01),Vector2(0.5,0.38),Vector2(0.68,0.64),24)
	_append_curve(edge,Vector2(0.68,0.64),Vector2(0.8,0.87),Vector2(0.84,0.86),Vector2(0.94,0.97),12)
	_foam_path(canvas,_placed(edge,at,Vector2(width,depth)),alpha*0.42,2.5,elapsed*7.0)

static func _column(canvas: Node2D, rect: Rect2, physical_height: float, active_age: float, elapsed: float) -> void:
	if active_age < -0.3 or active_age > 0.7: return
	# Before impact only the descending water overhead is visible. There is no
	# light on the deck, aiming line, target circle or projected danger volume.
	var incoming: float = smoothstep(-0.3,0.0,active_age)
	var drain: float = (1.0-smoothstep(0.28,0.59,active_age))*smoothstep(-0.3,-0.12,active_age)
	# The model grows its hit rectangle over the first 120 ms. Consume that
	# height directly, so visual descent and physical descent are the same event.
	var struck_height: float = minf(rect.size.y,physical_height) if active_age >= 0 else (incoming-1.0)*200.0
	if struck_height+220 < 1.0 or drain < 0.005:
		if active_age >= 0.1: _impact_foam(canvas,Vector2(rect.get_center().x,rect.end.y-25),active_age-0.1,1.0)
		return
	# The tail remains above the frame while the head falls. Both phases share
	# this single stream, avoiding a clipped water card appearing at activation.
	var top: Vector2 = rect.position-Vector2(0,220)
	var size := Vector2(rect.size.x,maxf(1.0,struck_height+220))
	var contour := PackedVector2Array()
	var sway: float = sin(elapsed*5.0)*0.055
	_append_curve(contour,Vector2(0.3,0),Vector2(0.24+sway,0.25),Vector2(0.05,0.63),Vector2(0.07,1),18)
	_append_curve(contour,Vector2(0.07,1),Vector2(0.27,1.035),Vector2(0.74,1.035),Vector2(0.96,1),12)
	_append_curve(contour,Vector2(0.96,1),Vector2(0.85,0.62),Vector2(0.66+sway,0.26),Vector2(0.7,0),18)
	contour.append(Vector2(0.3,0))
	_painted_body(canvas,contour,top,size,drain,active_age,0.07)
	for band in 2:
		var ribbon := PackedVector2Array()
		var offset: float = 0.29+band*0.39
		_append_curve(ribbon,Vector2(offset,0),Vector2(offset+sway,0.31),Vector2(offset+(band*2-1)*0.14,0.65),Vector2(offset+(band*2-1)*0.18,1),24)
		_foam_path(canvas,_placed(ribbon,top,size),drain*(0.55 if band == 0 else 0.8),3.8,elapsed*12+band)
	# The hit lands, spreads and collapses continuously into the existing sea.
	if active_age >= 0.1: _impact_foam(canvas,Vector2(rect.get_center().x,rect.end.y-25),active_age-0.1,1.0)

static func _impact_foam(canvas: Node2D, at: Vector2, age: float, strength: float) -> void:
	if age < 0 or age > 0.61: return
	var spread: float = 1.0-pow(1.0-clampf(age/0.6,0,1),2.0)
	var fade: float = (1.0-smoothstep(0.18,0.61,age))*strength
	var crest := PackedVector2Array()
	for i in 35:
		var t: float = i/34.0
		var x: float = (t*2.0-1.0)*(18+spread*86)
		var y: float = -sin(t*PI)*(10+spread*14)+sin(t*27+age*14)*2
		crest.append(at+Vector2(x,y+age*12))
	_foam_path(canvas,crest,fade*0.85,5.0-spread*2.0,age*7)
	for i in 15:
		var side: float = -1.0 if i%2 == 0 else 1.0
		var speed: float = 55+i*6.7
		var at_drop: Vector2 = at+Vector2(side*speed*age,-(65+i%4*21)*age+240*age*age)
		canvas.draw_line(at_drop,at_drop+Vector2(side*3,2+age*4),Color(FOAM,fade*(0.55+(i%3)*0.1)),1.6,true)

static func _painted_body(canvas: Node2D, contour: PackedVector2Array, origin: Vector2, size: Vector2, alpha: float, age: float, texture_offset: float, dissolve_base: bool = false) -> void:
	var placed: PackedVector2Array = _placed(contour,origin,size)
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	for p in contour:
		var tint: Color = DEEP.lerp(WATER_LIGHT,clampf(0.23+p.x*0.45,0,1))
		tint.a = alpha*0.92*(1.0-smoothstep(0.68,1.08,p.y) if dissolve_base else 1.0)
		colors.append(tint)
		# Keep the hand-painted foam/teal grain in a flowing curved silhouette.
		# UVs remain in the source interior; no opaque rectangular sprite edge.
		uv.append(Vector2(0.27+p.x*0.31,clampf(texture_offset+p.y*0.42+maxf(0,age)*0.025,0.02,0.96)))
	canvas.draw_polygon(placed,colors)
	var paint := PackedColorArray()
	for p in contour: paint.append(Color(0.7,0.86,0.88,alpha*0.86*(1.0-smoothstep(0.68,1.08,p.y) if dissolve_base else 1.0)))
	canvas.draw_polygon(placed,paint,uv,WATER)

static func _foam_path(canvas: Node2D, path: PackedVector2Array, alpha: float, width: float, flow: float) -> void:
	if path.size() < 2 or alpha < 0.005: return
	canvas.draw_polyline(path,Color(0.3,0.62,0.65,alpha*0.5),width+2.0,true)
	for i in path.size()-1:
		var t: float = i/float(path.size()-1)
		var broken: float = 0.55+0.45*pow(sin(i*0.63-flow*0.7),2)
		var edge_fade: float = smoothstep(0.0,0.1,t)*(1.0-smoothstep(0.88,1.0,t))
		canvas.draw_line(path[i],path[i+1],Color(FOAM,alpha*0.84*broken*edge_fade),width*(0.58+broken*0.42),true)
	for i in range(1,path.size()-1,3):
		var p: Vector2 = path[i]
		var shimmer: float = 0.45+sin(i*1.7+flow)*0.12
		canvas.draw_line(p-Vector2(1.3,0.6),p+Vector2(1.7,0.7),Color(0.91,0.96,0.91,alpha*shimmer),1.5,true)

static func _append_curve(points: PackedVector2Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2, count: int) -> void:
	for i in count:
		if not points.is_empty() and i == 0: continue
		points.append(a.bezier_interpolate(b,c,d,i/float(count-1)))

static func _placed(points: PackedVector2Array, at: Vector2, size: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points: result.append(at+p*size)
	return result
