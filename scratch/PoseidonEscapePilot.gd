extends RefCounted
## QA input pilot. Uses the same physics as keyboard input, never moves the actor itself.
const M := preload("res://Ato4_Tempestade/Gameplay/PoseidonEscapeModel.gd")
var target := Vector2.ZERO
var holding_jump := false
var final_step := 0
var brake_in_air := false
var landing_x := INF

func controls(m: M) -> Dictionary:
	var horizontal := 1.0
	var duck := false
	var jump := false
	var interact := false
	if not m.active(): return {"move":0.0,"duck":false,"jump":false,"held":false,"interact":false}
	if m.phase == M.Phase.FINAL_SHIP:
		if m.bindings[0] < 1: target = m.binding_points[0]
		elif m.bindings[1] < 1:
			if m.position.y > 400: target = Vector2(m.final_origin+280,390)
			else: target = m.binding_points[1]
		elif m.bindings[2] < 1: target = m.binding_points[2]
		elif not m.has_bag:
			if m.position.y > 420: target = Vector2(m.final_origin+880,400)
			else: target = m.bag_point
		else: target = m.exit_point
		horizontal = clampf((target.x-m.position.x)/35.0,-1,1)
		if m.position.distance_to(target) < 33:
			horizontal = 0
			interact = true
		if m.grounded and target.y < m.position.y-35:
			var dx: float = target.x-m.position.x
			if absf(dx) < 190: jump = true
	else: target = Vector2(m.final_origin+100,470)
	if m.grounded:
		brake_in_air = false
		landing_x = INF
		holding_jump = false
		var floor_end := INF
		if m.support >= 0: floor_end = m.platform_rect(m.support).end.x
		else:
			for o in m.obstacles:
				if absf(m.position.y-o.rect.position.y) < 2: floor_end = o.rect.end.x
		if m.phase == M.Phase.TRAVERSAL and floor_end-m.position.x < 62:
			jump = true
			var nearest := INF
			for i in m.platforms.size():
				if m.platforms[i].gone: continue
				var r: Rect2 = m.platform_rect(i)
				if r.position.x >= floor_end-1 and r.position.x < nearest:
					nearest = r.position.x
					landing_x = r.get_center().x
		for o in m.obstacles:
			if m.sunk_at[o.boat] >= 0: continue
			var r: Rect2 = o.rect
			if m.position.x > r.end.x+20 or r.position.x-m.position.x > 92: continue
			if absf(m.position.y-(r.end.y+59 if o.kind == "beam" else r.end.y)) > 8: continue
			if o.kind == "beam": duck = true
			elif m.position.x < r.position.x: jump = true
	for h in m.hazards:
		if h.kind == "slam":
			if h.age > 0.25 and absf(m.position.x-h.target) < 80 and h.age < h.warning+0.35:
				horizontal = -1.0 if m.position.x < h.target else 1.0
				interact = false
		elif h.age >= h.warning and h.x > m.position.x-50 and h.x-m.position.x < 155:
			if h.kind == "high" and m.grounded and m.position.y > h.y-25:
				duck = true
				jump = false
			elif h.kind == "low" and m.grounded and m.position.y > h.y-25:
				jump = true
				if m.support >= 0 and m.platforms[m.support].kind == "deck":
					var edge_distance: float = m.platform_rect(m.support).end.x-m.position.x
					if edge_distance > 90 and edge_distance < 300: brake_in_air = true
	if duck: jump = false
	if jump: holding_jump = true
	if landing_x < INF: horizontal = clampf((landing_x-m.position.x)/60.0,-1,1)
	if brake_in_air: horizontal = 0
	return {"move":horizontal,"duck":duck,"jump":jump,"held":holding_jump,"interact":interact}
