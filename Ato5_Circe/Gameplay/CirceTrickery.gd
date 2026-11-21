extends RefCounted
## Position/action-triggered choreography. No random traps and no wall-clock time.
## A retry reconstructs the same trial from its safe entry point.
var definitions: Array = []
var ages: Array[float] = []
var phase_name := "out"
var jump_seen := 0
var dash_seen := 0
var fired_ids: Array[String] = []

func _init(data: Array = []) -> void:
	definitions=data.duplicate(true)
	reset()

func reset(returning: bool = false) -> void:
	phase_name="back" if returning else "out"
	ages.clear()
	for event in definitions: ages.append(-1.0)
	jump_seen=0
	dash_seen=0
	fired_ids.clear()

func is_fired(id: String) -> bool:
	for i in definitions.size():
		if str(definitions[i].id)==id: return ages[i]>=0
	return false

func fire(id: String, model: RefCounted) -> bool:
	for i in definitions.size():
		if str(definitions[i].id)!=id or ages[i]>=0 or str(definitions[i].phase)!=phase_name: continue
		ages[i]=0
		fired_ids.append(id)
		model.cue.emit("crack" if definitions[i].get("sound","")=="wood" else "trick")
		return true
	return false

func tick(dt: float, model: RefCounted) -> void:
	var jumped: bool=model.jump_serial!=jump_seen
	var dashed: bool=model.dash_serial!=dash_seen
	for i in definitions.size():
		var event: Dictionary=definitions[i]
		if str(event.phase)!=phase_name: continue
		if ages[i]>=0:
			ages[i]+=dt
			continue
		var x: Array=event.get("x",[-1,-1])
		if model.position.x<float(x[0]) or model.position.x>float(x[1]): continue
		if event.has("after") and not is_fired(str(event.after)): continue
		var condition: String=event.get("when","enter")
		var trigger: bool=condition=="enter" or (condition=="jump" and jumped) or (condition=="dash" and dashed) or (condition=="land" and model.grounded) or (condition=="retreat" and model.velocity.x< -20) or (condition=="air" and not model.grounded)
		if trigger: fire(str(event.id),model)
	jump_seen=model.jump_serial
	dash_seen=model.dash_serial

func effect_age(event_index: int, effect: Dictionary) -> float:
	return ages[event_index]-float(effect.get("start",0.0))

func surface_shift(x: float) -> Vector2:
	var offset:=Vector2.ZERO
	for i in definitions.size():
		if ages[i]<0 or str(definitions[i].phase)!=phase_name: continue
		for effect: Dictionary in definitions[i].effects:
			if str(effect.kind) not in ["cut","slide"] or not is_equal_approx(float(effect.get("surface_x",-1000)),x): continue
			var t:=effect_age(i,effect)
			if t<0: continue
			if effect.kind=="cut": offset.y+=minf(1300,t*t*1100)
			else:
				var progress:=smoothstep(0,1,clampf(t/float(effect.get("travel",0.5)),0,1))
				var shift: Array=effect.get("shift",[0,0])
				offset+=Vector2(shift[0],shift[1])*progress
	return offset

func surface_gone(x: float) -> bool:
	for i in definitions.size():
		if ages[i]<0 or str(definitions[i].phase)!=phase_name: continue
		for effect: Dictionary in definitions[i].effects:
			if effect.kind=="cut" and is_equal_approx(float(effect.surface_x),x) and effect_age(i,effect)>=0: return true
	return false

func palace_offset() -> float:
	for i in definitions.size():
		if definitions[i].id=="last_door" and ages[i]>=0:
			return -170.0*smoothstep(0,1,clampf(ages[i]/0.45,0,1))
	return 0.0

func lure_dissolve() -> float:
	for i in definitions.size():
		if definitions[i].id=="false_flower" and ages[i]>=0: return clampf(ages[i]/0.65,0,1)
	return 0.0

func hazards() -> Array:
	var result: Array=[]
	for i in definitions.size():
		if ages[i]<0 or str(definitions[i].phase)!=phase_name: continue
		for effect: Dictionary in definitions[i].effects:
			if effect.kind not in ["sweep","spikes","fall"]: continue
			var age:=effect_age(i,effect)
			var travel: float=effect.get("travel",0.18)
			var hold: float=effect.get("hold",0.2)
			if age< -0.12 or age>travel+hold+0.18: continue
			var size_data: Array=effect.size
			var from_data: Array=effect.from
			var to_data: Array=effect.to
			var from:=Vector2(from_data[0],from_data[1])
			var to:=Vector2(to_data[0],to_data[1])
			var progress:=clampf(age/travel,0,1)
			if effect.kind=="fall": progress*=progress
			var at:=from.lerp(to,progress)
			var fade:=1.0-smoothstep(travel+hold,travel+hold+0.18,age)
			result.append({"rect":Rect2(at,Vector2(size_data[0],size_data[1])),"active":age>=0 and age<=travel+hold,"alpha":fade*clampf((age+0.12)/0.12,0,1),"kind":effect.kind,"id":definitions[i].id,"progress":progress})
	return result
