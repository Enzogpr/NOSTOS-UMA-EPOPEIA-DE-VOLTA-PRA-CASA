extends RefCounted
## QA only: eight-direction movement and ordinary combat inputs, never attached to gameplay.
static func drive(m: RefCounted,delta: float) -> void:
	var toward: Vector2=m.boss_position-m.position
	var destination: Vector2=m.boss_position-toward.normalized()*67
	var observing: bool=m.phase in [m.Phase.MIRRORS,m.Phase.PALACE] and m.reveal_time<=0 and m.reveal_recharge<=0 and m.focus>=20 and m.attack_kind=="enchant" and m.boss_state in ["windup","recovery"]
	var axis := Vector2.ZERO
	var best := INF
	for i in 9:
		var direction := Vector2.ZERO if i==8 else Vector2.from_angle(i*TAU/8)
		var next: Vector2=m.position+direction*20
		if not m.walkable(next) or m.palace.pit_at(next,28): continue
		var score: float=next.distance_to(destination)
		for root in m.roots:
			var separation: float=next.distance_to(root.p)
			if separation<90: score+=(90-separation)*4
		for table in m.tables:
			var future: Vector2=table.p+table.v*0.15
			var separation: float=Geometry2D.get_closest_point_to_segment(next,table.p,future).distance_to(next)
			if separation<75: score+=(75-separation)*7
		if m.boss_state=="windup" and m.attack_kind=="staff":
			var relative: Vector2=next-m.boss_position
			if relative.length()<155 and relative.normalized().dot(m.boss_facing)>0: score+=200
		if m.boss_state=="windup" and m.attack_kind=="table":
			var line: Vector2=(m.locked_target-m.boss_position).normalized()
			var separation: float=Geometry2D.get_closest_point_to_segment(next,m.boss_position+line*38,m.boss_position+line*750).distance_to(next)
			if separation<85: score+=(85-separation)*7
		if score<best: best=score; axis=direction
	m.set_input(axis,toward,false,observing)
	if toward.length()>210 and axis!=Vector2.ZERO and not observing:
		var clear := true
		for distance in [30,60,90,125,150]:
			if not m.walkable(m.position+axis*distance): clear=false
		if clear: m.request_dash()
	if m.boss_state=="recovery" and toward.length()<90 and not observing: m.request_attack()
	m.tick(delta)
