extends RefCounted
## Consistent action-triggered room changes; no random traps or invisible collisions.
var definitions: Array=[]
var events: Array=[]
var triggered := {}
var landed_hits := 0
var enabled := false
var previous_position := Vector2.ZERO

func _init(data: Array=[]) -> void: definitions=data.duplicate(true)

func arm(at: Vector2=Vector2.ZERO) -> void:
	enabled=true; previous_position=at; _trigger("enter",Vector2.ZERO)

func notify(action: String,at: Vector2) -> void:
	if not enabled: return
	if action=="hit":
		landed_hits+=1
		if landed_hits==2: _trigger("second_hit",at)
	else: _trigger(action,at)

func _trigger(condition: String,at: Vector2) -> void:
	for definition in definitions:
		if definition.trigger!=condition or triggered.has(definition.id): continue
		triggered[definition.id]=true
		var event: Dictionary=definition.duplicate(true)
		event["age"]=0.0; event["progress"]=0.0; event["impacted"]=false
		if event.kind=="pit": event["center"]=at
		events.append(event)

func tick(delta: float,player: Vector2,radius: float) -> Array:
	if not enabled: return []
	if player.x>590 and previous_position.x<=590: _trigger("cross_center",player)
	previous_position=player
	var impacts: Array=[]
	for event in events:
		var next_age: float=event.age+delta
		var progress := clampf((next_age-float(event.warning))/float(event.duration),0,1)
		# Closing passages wait for an occupying player instead of pinning them.
		if event.kind=="gate" and progress>=0.8 and rectangle(event).grow(radius+3).has_point(player):
			next_age=float(event.warning)+float(event.duration)*0.79; progress=0.79
		event.age=next_age; event.progress=progress
		if progress>=1 and not event.impacted:
			event.impacted=true; impacts.append(event)
	return impacts

func solids() -> Array[Rect2]:
	var result: Array[Rect2]=[]
	for event in events:
		if event.kind in ["column","gate"] and event.progress>=1: result.append(rectangle(event))
	return result

func pit_at(point: Vector2,margin := 0.0) -> bool:
	for event in events:
		if event.kind=="pit" and event.progress>=1 and point.distance_to(event.center)<float(event.radius)+margin: return true
	return false

static func rectangle(event: Dictionary) -> Rect2:
	var r: Array=event.rect
	return Rect2(r[0],r[1],r[2],r[3])
