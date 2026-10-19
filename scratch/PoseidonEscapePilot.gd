extends RefCounted
## Test pilot reads telegraphs, but moves through the same rules as the player.
const MODEL := preload("res://Ato4_Tempestade/Gameplay/PoseidonEscapeModel.gd")
var avoid_until: float = -1
var avoid_point := Vector2.ZERO

func controls(model: MODEL) -> Dictionary:
	var idle := {"direction":Vector2.ZERO,"interact":false,"dash":false}
	if not model.active() or model.airborne: return idle
	if model.phase == MODEL.Phase.FINAL_ATTACK:
		return {"direction":_toward(model.position,MODEL.HELM,25),"interact":model.wind_window() and model.position.distance_to(MODEL.HELM) < 70,"dash":false}
	var area: Rect2 = model.route_rect() if model.is_route() else MODEL.WALK_AREA
	var target := model.launch_point() if model.is_route() else MODEL.BAG-Vector2(24,-13) if not model.has_bag else MODEL.HELM+Vector2(28,4) if model.act_index == 1 and not model.bag_secured else Vector2(540,515)
	var interact: bool = false
	var dash: bool = false
	var defend: bool = false
	if model.is_route() and model.gate_open:
		if model.position.distance_to(target) < 42:
			return {"direction":Vector2.ZERO,"interact":model.route_index == 1,"dash":model.route_index != 1}
	for hazard in model.hazards:
		var t: float = hazard.age-hazard.warning
		if hazard.kind == "hoof" and t < 0.4:
			var best: Vector2 = MODEL.ANCHORS[0]
			for anchor in MODEL.ANCHORS:
				if model.position.distance_to(anchor) < model.position.distance_to(best): best = anchor
			target = best
			interact = model.position.distance_to(best) < 40
			defend = true
		elif hazard.kind in ["wave","fan"]:
			var travel: float = (hazard.area.size.x+130)/440.0 if hazard.kind == "fan" else (hazard.area.size.x+130)/650.0
			if t < travel:
				target = Vector2(clampf(target.x,area.position.x+15,area.end.x-15),hazard.lane)
				defend = true
		elif hazard.kind == "aimed" and t < 1.8:
			target.y = area.position.y+7 if hazard.target.y > area.get_center().y else area.end.y-7
			defend = true
		elif hazard.kind == "crush" and t < 0.5 and absf(model.position.x-hazard.target.x) < 90:
			target.x = hazard.target.x-130 if hazard.target.x > area.get_center().x else hazard.target.x+130
			defend = true
		elif hazard.kind == "jets" and t < 0.65:
			for point in hazard.points:
				if model.position.distance_to(point) < (70 if model.is_route() else 85):
					avoid_point = Vector2(point.x-135 if point.x > area.get_center().x else point.x+135,clampf(point.y+(-95 if point.y > area.get_center().y else 95),area.position.y+5,area.end.y-5))
					avoid_until = model.clock+maxf(0,hazard.warning-hazard.age)+0.7
	if model.clock < avoid_until:
		target = avoid_point
		defend = true
	if not defend and not model.is_route():
		if not model.has_bag and model.position.distance_to(MODEL.BAG) < 62: interact = true
		if model.act_index == 1 and not model.bag_secured and model.position.distance_to(MODEL.HELM) < 62: interact = true
	var direction := _toward(model.position,target,9)
	if interact: direction = Vector2.ZERO
	# Reactive sidestep only when a water projectile will cross the actual body.
	for shot in model.projectiles:
		var relative: Vector2 = model.position-shot.position
		var close_time: float = clampf(relative.dot(shot.velocity)/shot.velocity.length_squared(),0,0.45)
		if (shot.position+shot.velocity*close_time).distance_to(model.position) < 27:
			if model.dash_cooldown <= 0:
				dash = true
				interact = false
				if direction == Vector2.ZERO: direction = Vector2.UP if model.position.y > area.get_center().y else Vector2.DOWN
	return {"direction":direction,"interact":interact,"dash":dash}

func _toward(from: Vector2, to: Vector2, stop: float) -> Vector2:
	return (to-from).normalized() if from.distance_to(to) > stop else Vector2.ZERO
