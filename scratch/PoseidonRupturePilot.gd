extends RefCounted
## Input-only QA route. Knows geometry; not a human difficulty assessment.
const R := preload("res://Ato4_Tempestade/Gameplay/PoseidonRuptureModel.gd")
var jump_held := false
var landing_x := INF
var brake_jump := false

func controls(m: R) -> Dictionary:
	var move := 1.0
	var duck := false
	var jump := false
	if not m.active(): return {"move":0.0,"duck":false,"jump":false,"held":false,"interact":false}
	if m.encounter_state in ["fracture","retreat"]:
		move = -1.0 if m.position.x > 350 else 0.0
		duck = m.position.x < 670 and m.position.x > 420
		jump_held = false
		return {"move":move,"duck":duck,"jump":false,"held":false,"interact":false}
	if m.encounter_state == "mast_fall": return {"move":-1.0 if m.position.x > 352 else 0.0,"duck":false,"jump":false,"held":false,"interact":false}
	if m.grounded:
		jump_held = false
		landing_x = INF
		brake_jump = false
		var floor_end := INF
		if m.support >= 0: floor_end = m.platform_rect(m.support).end.x
		else:
			for o in m.obstacles:
				if o.active and absf(m.position.y-o.rect.position.y) < 3 and m.position.x > o.rect.position.x-15 and m.position.x < o.rect.end.x+15: floor_end = o.rect.end.x
		if floor_end-m.position.x < 49:
			jump = true
			var nearest := INF
			for i in m.platforms.size():
				if m.platforms[i].gone: continue
				var r: Rect2 = m.platform_rect(i)
				if r.position.x >= floor_end-1 and r.position.x < nearest:
					nearest = r.position.x
					landing_x = r.get_center().x
		for o in m.obstacles:
			if not o.active or o.kind != "crate" or m.sunk_at[o.boat] >= 0: continue
			var rect: Rect2 = o.rect
			if m.position.x < rect.position.x and rect.position.x-m.position.x < 75 and absf(m.position.y-rect.end.y)<6: jump = true
	for h in m.hazards:
		if h.kind == "slam" and h.age > 0.25 and h.age < h.warning+0.35 and absf(m.position.x-h.target)<80:
			move = -1.0 if m.position.x < h.target else 1.0
		elif h.kind == "low" and h.age >= h.warning and h.x-m.position.x < 145 and h.x > m.position.x-40 and m.grounded and m.position.y > h.y-25:
			jump = true
			if m.support >= 0 and m.platforms[m.support].kind == "deck":
				var distance: float = m.platform_rect(m.support).end.x-m.position.x
				if distance > 100 and distance < 300: brake_jump = true
	if jump: jump_held = true
	if landing_x < INF: move = clampf((landing_x-m.position.x)/58.0,-1,1)
	if brake_jump: move = 0
	return {"move":move,"duck":duck,"jump":jump,"held":jump_held,"interact":false}
