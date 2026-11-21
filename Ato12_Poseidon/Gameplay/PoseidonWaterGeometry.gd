extends RefCounted
## Renderer and damage use the same sprite transforms and opaque water pixels.
const ATLAS := preload("res://Assets/act12_poseidon/arena_water_vfx.png")
const CELLS := [Rect2(0,253,512,249),Rect2(512,0,512,502),Rect2(1024,0,512,502),Rect2(0,627,512,289),Rect2(512,628,512,273),Rect2(1024,621,512,296)]
const BODY_HEIGHT := 36.0
const BODY_SAMPLES := [Vector2.ZERO,Vector2(-6,0),Vector2(6,0),Vector2(0,-12),Vector2(0,12)]
const SOLID_ALPHA := 0.45
static var pixels: Image

static func piece(frame: int, rect: Rect2, opacity: float, origin := Vector2.ZERO, angle: float = 0.0) -> Dictionary:
	return {"frame":frame,"rect":rect,"opacity":clampf(opacity,0,1),"origin":origin,"angle":angle}

static func breaker(at: Vector2, size: Vector2, power: float, opacity: float, clock: float, origin := Vector2.ZERO, angle: float = 0.0) -> Dictionary:
	var height := maxf(30,size.y*(0.82+power*0.45))
	var breathe := 1+sin(clock*6+at.x*0.01)*0.026
	var rect := Rect2(at-Vector2(size.x*0.57,height*0.78),Vector2(size.x*1.14,height)*breathe)
	return piece(3,rect,opacity,origin,angle)

static func hazard_parts(hazard: Dictionary, clock: float) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	var age: float = hazard.age
	var lead: float = hazard.lead
	if age < lead:
		return parts
	var rect: Rect2 = hazard.rect
	var at := rect.get_center()-Vector2(0,28)
	var fade := 1-smoothstep(lead+hazard.hold,lead+hazard.hold+0.42,age)
	match hazard.kind:
		"tide":
			for section in [Vector2(rect.position.y,hazard.gap-hazard.gap_size*0.5),Vector2(hazard.gap+hazard.gap_size*0.5,rect.end.y)]:
				parts.append(breaker(Vector2(at.x,(section.x+section.y)*0.5-25),Vector2(74,section.y-section.x+18),0.95,fade,clock))
		"bolt":
			parts.append(piece(4,Rect2(-54,-23,108,46),fade,at,hazard.velocity.angle()))
		"spear":
			var progress := clampf((age-lead)/hazard.hold,0,1)
			var rise := sin(progress*PI)
			parts.append(piece(1,Rect2(at-Vector2(34,74*rise),Vector2(68,82*rise+11)),fade*(1-smoothstep(0.45,0.9,progress))))
			parts.append(piece(2,Rect2(at-Vector2(42,82*rise),Vector2(84,91*rise+11)),fade*smoothstep(0.3,0.65,progress)))
		"rain":
			var count := maxi(2,int(rect.size.x/65))
			for n in count:
				var x := rect.position.x+rect.size.x*(n+0.5)/count
				var width := rect.size.x/count+27
				var height := 201+sin(clock*11+n)*14
				parts.append(piece(2,Rect2(x-width*0.5,rect.end.y-height-25,width,height),fade*0.91))
			parts.append(breaker(at,Vector2(rect.size.x,54),0.9,fade*0.66,clock))
		"pool":
			var pulse := 1+sin(clock*5+rect.position.x)*0.035
			parts.append(piece(5,Rect2(at-rect.size*Vector2(0.58,0.34)*pulse,rect.size*Vector2(1.16,0.78)*pulse),fade*0.87))
		"breaker":
			parts.append(breaker(at,rect.size,1.0,fade,clock))
	return parts

static func duel_parts(origin: Vector2, tip: Vector2, clock: float) -> Array[Dictionary]:
	var start := origin-Vector2(0,BODY_HEIGHT)
	var length := origin.distance_to(tip)
	return [breaker(Vector2(length*0.5,0),Vector2(length,59),0.95,0.93,clock,start,origin.angle_to_point(tip))]

static func wave_parts(x: float, gap: float, arena: Rect2, clock: float) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	for section in [Vector2(arena.position.y,gap-34),Vector2(gap+34,arena.end.y)]:
		parts.append(breaker(Vector2(x,(section.x+section.y)*0.5-25),Vector2(94,section.y-section.x+8),0.98,0.9,clock))
	return parts

static func contains_pixel(part: Dictionary, screen_point: Vector2) -> bool:
	if part.opacity < SOLID_ALPHA:
		return false
	var local: Vector2 = (screen_point-part.origin).rotated(-float(part.angle))
	var rect: Rect2 = part.rect
	if not rect.has_point(local) or rect.size.x <= 0 or rect.size.y <= 0:
		return false
	if pixels == null:
		pixels = ATLAS.get_image()
		if pixels.is_compressed():
			pixels.decompress()
	var cell: Rect2 = CELLS[int(part.frame)]
	var uv: Vector2 = (local-rect.position)/rect.size
	var pixel := Vector2i(cell.position+uv*cell.size)
	return pixels.get_pixelv(pixel).a*float(part.opacity) >= SOLID_ALPHA

static func hits_player(parts: Array[Dictionary], feet: Vector2) -> bool:
	# A small central hurtbox excludes cape, weapon, shadow and transparent padding.
	var center := feet-Vector2(0,BODY_HEIGHT)
	for part in parts:
		for offset: Vector2 in BODY_SAMPLES:
			if contains_pixel(part,center+offset):
				return true
	return false

static func hazard_hits(hazard: Dictionary, feet: Vector2, clock: float) -> bool:
	if hazard.age < hazard.lead or hazard.age > hazard.lead+hazard.hold:
		return false
	# Spray above a ground lane remains decorative, rather than enlarging damage.
	var footprint: Rect2 = hazard.rect
	if not footprint.has_point(feet):
		return false
	if hazard.kind == "tide" and absf(feet.y-hazard.gap) <= hazard.gap_size*0.5:
		return false
	return hits_player(hazard_parts(hazard,clock),feet)

static func soldier_segment(enemy: Dictionary) -> PackedVector2Array:
	var length := float(enemy.get("reach",143.0 if enemy.elite else 128.0))
	var reach := length*smoothstep(0,0.15,enemy.age) if enemy.state == "strike" else 54.0
	var start: Vector2 = enemy.position-Vector2(0,35)
	var direction: Vector2 = enemy.direction
	if enemy.get("kind", "thrust") == "sweep" and enemy.state == "strike":
		direction = direction.rotated(lerpf(-0.82,0.82,clampf(enemy.age/0.26,0,1)))
	return PackedVector2Array([start,start+direction*reach])

static func soldier_hits(enemy: Dictionary, feet: Vector2) -> bool:
	if enemy.state != "strike" or enemy.age < 0.055 or enemy.age > 0.20:
		return false
	var segment := soldier_segment(enemy)
	var center := feet-Vector2(0,BODY_HEIGHT)
	for offset: Vector2 in BODY_SAMPLES:
		var point := center+offset
		if Geometry2D.get_closest_point_to_segment(point,segment[0],segment[1]).distance_to(point) <= 3.0:
			return true
	return false

static func arrow_segment(arrow: Dictionary) -> PackedVector2Array:
	var center: Vector2 = arrow.position-Vector2(0,35)
	return PackedVector2Array([center-arrow.direction*24,center+arrow.direction*22])

static func arrow_hits(arrow: Dictionary, feet: Vector2) -> bool:
	var segment := arrow_segment(arrow)
	var center := feet-Vector2(0,BODY_HEIGHT)
	for offset: Vector2 in BODY_SAMPLES:
		var point := center+offset
		if Geometry2D.get_closest_point_to_segment(point,segment[0],segment[1]).distance_to(point) <= 3:
			return true
	return false
