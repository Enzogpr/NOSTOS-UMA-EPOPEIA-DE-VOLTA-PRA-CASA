extends RefCounted
## Geometry-aware input-only QA. Not a measurement of human difficulty.
const Model = preload("res://Ato4_Tempestade/Gameplay/PoseidonCadenceModel.gd")
var combat_pilot := preload("res://scratch/PoseidonWaterPilot.gd").new()
var held := false
var landing_x := INF
var landing_y := INF
var previous_grounded := true
var brake_jump := false

func controls(m: Model) -> Dictionary:
	if m.phase==m.Phase.FINAL_SHIP and m.boarding.active:
		var fighting: Dictionary=combat_pilot.controls(m.boarding,m.position,m.facing,m.grounded)
		fighting["interact"]=false
		for h in m.hazards:
			if h.kind=="high" and h.age>=h.warning-0.05 and h.x-m.position.x<180 and h.x>m.position.x-70 and m.grounded and absf(m.position.y-h.y)<8:
				fighting.duck=true
				fighting.attack=false
				fighting.guard=false
			elif h.kind=="low" and h.age>=h.warning and h.x-m.position.x<165 and h.x>m.position.x-40 and m.grounded and absf(m.position.y-h.y)<8:
				fighting.jump=true
				fighting.held=true
				fighting.attack=false
				fighting.guard=false
			elif h.kind=="slam" and h.age>0.05 and h.age<h.warning+0.4 and absf(m.position.x-h.target)<90:
				fighting.move=-1 if m.position.x<h.target else 1
				fighting.attack=false
				fighting.guard=false
		return fighting
	var move:=1.0
	var duck:=false
	var jump:=false
	var interact:=false
	if not m.active(): return {"move":0.0,"duck":false,"jump":false,"held":false,"interact":false,"attack":false,"guard":false}
	var direction: float=-1 if m.has_bag else 1
	move=direction
	var target: Vector2=m.exit_point if m.has_bag else m.bag_point
	if m.phase==m.Phase.FINAL_SHIP and m.position.distance_to(target)<46:
		move=clampf((target.x-m.position.x)/25.0,-1,1)
		interact=true
	if m.grounded:
		held=false
		landing_x=INF
		landing_y=INF
		brake_jump=false
		var floor_end: float=INF if direction>0 else -INF
		if m.support>=0:
			var floor_rect:=m.platform_rect(m.support)
			floor_end=floor_rect.end.x if direction>0 else floor_rect.position.x
		else:
			for o in m.obstacles:
				if not m._obstacle_enabled(o): continue
				if absf(m.position.y-o.rect.position.y)<3 and m.position.x>o.rect.position.x-15 and m.position.x<o.rect.end.x+15:
					floor_end=o.rect.end.x if direction>0 else o.rect.position.x
		if (floor_end-m.position.x)*direction<53:
			jump=true
			var nearest:=INF
			for i in m.platforms.size():
				if m.platforms[i].gone: continue
				var r:=m.platform_rect(i)
				var entry: float=r.position.x if direction>0 else r.end.x
				var ahead: float=(entry-floor_end)*direction
				if ahead>=-1 and ahead<nearest:
					nearest=ahead
					landing_x=r.get_center().x
					landing_y=r.position.y
		for o in m.obstacles:
			if not m._obstacle_enabled(o): continue
			var r: Rect2=o.rect
			var entry: float=r.position.x if direction>0 else r.end.x
			var distance: float=(entry-m.position.x)*direction
			if o.kind=="beam" and distance<95 and distance>-r.size.x-22 and absf(m.position.y-r.end.y-60)<7:
				duck=true
				jump=false
			elif o.kind=="crate" and distance>0 and distance<88 and absf(m.position.y-r.end.y)<7:
				jump=true
	for h in m.hazards:
		if h.kind=="high" and h.age>=h.warning-0.05 and h.x-m.position.x<180 and h.x>m.position.x-70 and m.grounded and absf(m.position.y-h.y)<8:
			duck=true
			jump=false
		elif h.kind=="low" and h.age>=h.warning and h.x-m.position.x<165 and h.x>m.position.x-40 and m.grounded and absf(m.position.y-h.y)<8 and not duck:
			jump=true
			if m.support>=0:
				var floor_rect:=m.platform_rect(m.support)
				if floor_rect.end.x-m.position.x>130 and floor_rect.end.x-m.position.x<360: brake_jump=true
		elif h.kind=="slam" and h.age>0.05 and h.age<h.warning+0.4 and absf(m.position.x-h.target)<90:
			move=-1 if m.position.x<h.target else 1
	if jump: held=true
	if landing_x<INF:
		move=clampf((landing_x-m.position.x)/65.0,-1,1)
		# Continue to the landing rather than running off a narrow fragment.
		if absf(landing_x-m.position.x)<20: held=false
	if brake_jump: move=0
	if m.phase==m.Phase.FINAL_SHIP and absf(m.position.x-target.x)<180:
		move=clampf((target.x-m.position.x)/55.0,-1,1)
		if absf(m.position.x-target.x)<12 and absf(m.position.y-target.y)<4:
			interact=true
			jump=false
			held=false
	previous_grounded=m.grounded
	return {"move":move,"duck":duck,"jump":jump,"held":held,"interact":interact,"attack":false,"guard":false}
