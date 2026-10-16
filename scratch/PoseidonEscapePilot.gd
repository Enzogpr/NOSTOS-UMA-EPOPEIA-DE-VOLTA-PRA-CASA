extends RefCounted
## QA pilot uses the same movement/interact rules as keyboard play.
const MODEL := preload("res://Ato4_Tempestade/Gameplay/PoseidonEscapeModel.gd")
var dodge_side: float = 1.0

func controls(model: MODEL) -> Dictionary:
	var direction := Vector2.ZERO
	var interact: bool = false
	var dash: bool = false
	if model.phase == MODEL.Phase.FINAL_ATTACK:
		return {"direction":(MODEL.HELM-model.position).normalized() if model.position.distance_to(MODEL.HELM) > 28 else Vector2.ZERO,"interact":model.wind_window(),"dash":false}
	if not model.active(): return {"direction":direction,"interact":false,"dash":false}
	var target := MODEL.BAG-Vector2(25,-15) if not model.has_bag else MODEL.HELM+Vector2(20,10)
	if not model.has_bag and model.position.x < 690: target = Vector2(710,548)
	if model.has_bag and model.position.x > 630: target = Vector2(610,548)
	var defending: bool = false
	for hazard in model.hazards:
		var t: float = hazard.age-hazard.warning
		if hazard.kind == "sweep" and t < 0.86:
			target = Vector2(488,492)
			defending = true
		elif hazard.kind == "hoof" and t < 0.45:
			var best: Vector2 = MODEL.ANCHORS[0]
			for anchor in MODEL.ANCHORS:
				if model.position.distance_to(anchor) < model.position.distance_to(best): best = anchor
			target = best
			interact = model.position.distance_to(best) < 40
			defending = true
		elif hazard.kind == "jets" and t < 0.7 and hazard.age > 0.3:
			for point in hazard.points:
				if model.position.distance_to(point) < 85:
					target = model.position+Vector2(-100 if model.position.x > 900 else 100, -85 if model.position.y > 490 else 85)
					defending = true
					dash = hazard.age > hazard.warning-0.35 and model.dash_cooldown <= 0
	if not defending:
		if not model.has_bag and model.position.distance_to(MODEL.BAG) < 60:
			interact = true
		elif model.has_bag and model.position.distance_to(MODEL.HELM) < 55:
			interact = true
	if not interact and model.position.distance_to(target) > 15: direction = (target-model.position).normalized()
	return {"direction":direction,"interact":interact,"dash":dash}
