extends RefCounted
## The same warnings and collision silhouettes are drawn in both arenas.
static func floor_marks(canvas: Node2D, model: RefCounted, time: float) -> void:
	for hazard in model.hazards:
		var t: float = hazard.age-hazard.warning
		var area: Rect2 = hazard.area
		if hazard.kind == "jets":
			for point in hazard.points:
				var radius: float = 37 if model.is_route() else 49
				canvas.draw_circle(point,radius,Color(1,0.43,0.16,0.17+sin(time*12)*0.06))
				canvas.draw_arc(point,radius,0,TAU,40,Color(1,0.7,0.29,0.9),2,true)
				canvas.draw_arc(point,radius*clampf(hazard.age/hazard.warning,0.1,1),0,TAU,32,Color(1,0.9,0.6),2,true)
		elif hazard.kind in ["wave","fan"] and t < 0:
			var half: float = 13 if model.is_route() else 26
			canvas.draw_rect(area,Color(0.8,0.28,0.1,0.1))
			var lane := Rect2(area.position.x,hazard.lane-half,area.size.x,half*2)
			canvas.draw_rect(lane,Color(0.17,0.78,0.65,0.24))
			canvas.draw_rect(lane,Color(0.61,1,0.85,0.85),false,2)
		elif hazard.kind == "crush":
			var danger := Rect2(hazard.target.x-66,area.position.y,132,area.size.y)
			canvas.draw_rect(danger,Color(0.94,0.25,0.11,0.17+sin(time*15)*0.06))
			canvas.draw_rect(danger,Color(1,0.48,0.25),false,3)
		elif hazard.kind == "hoof" and t < 0:
			for point in model.ANCHORS:
				canvas.draw_arc(point,34+sin(time*9)*3,0,TAU,40,Color(0.6,1,0.9,0.8),3,true)

static func water(canvas: Node2D, model: RefCounted, time: float) -> void:
	for hazard in model.hazards:
		var t: float = hazard.age-hazard.warning
		if t < 0: continue
		if hazard.kind == "jets":
			var height: float = sin(clampf(t/0.8,0,1)*PI)*155
			for point in hazard.points:
				for j in 6:
					var base: Vector2 = point+Vector2((j-2.5)*6,0)
					canvas.draw_line(base,base+Vector2(sin(time*15+j)*10,-height),Color(0.44+j*0.07,0.84,0.98,0.8),6,true)
		elif hazard.kind == "wave" and t < 1.8:
			var x: float = hazard.area.end.x+60-t*650
			var half: float = 13 if model.is_route() else 26
			for y in range(int(hazard.area.position.y),int(hazard.area.end.y),8):
				if absf(y-hazard.lane) < half: continue
				var point := Vector2(x+sin(y*0.11+time*18)*7,y)
				canvas.draw_line(point-Vector2(26,3),point+Vector2(17,-5),Color(0.5,0.94,1,0.9),8,true)
		elif hazard.kind == "crush" and t < 0.65:
			var height: float = sin(clampf(t/0.7,0,1)*PI)*390
			var at: Vector2 = hazard.target
			for j in 12:
				var point := at+Vector2((j-5.5)*10,0)
				canvas.draw_line(point,point-Vector2(sin(j)*9,height),Color(0.49,0.85,0.97,0.8),12,true)
	for shot in model.projectiles:
		canvas.draw_line(shot.position-shot.velocity.normalized()*27,shot.position,Color(0.25,0.8,0.98,0.65),7,true)
		canvas.draw_circle(shot.position,shot.radius,Color(0.64,0.96,1))
		canvas.draw_circle(shot.position,shot.radius*0.45,Color(0.94,1,1))
