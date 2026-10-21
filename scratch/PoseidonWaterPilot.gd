extends RefCounted
## Input-only QA helper. Never loaded by the campaign controller.
func controls(combat: RefCounted, position: Vector2, facing: float, grounded: bool) -> Dictionary:
	var c: Dictionary={"move":0.0,"duck":false,"jump":false,"held":false,"attack":false,"guard":false}
	if not combat.active: return c
	var nearest: Dictionary={}
	var distance:=INF
	for enemy in combat.enemies:
		if int(enemy.hp)<=0: continue
		var dx: float=absf(float(enemy.position.x)-position.x)
		if dx<distance:
			distance=dx
			nearest=enemy
	if nearest.is_empty(): return c
	var dx: float=float(nearest.position.x)-position.x
	var desired: float=signf(dx)
	c.move=desired if distance>87 else 0.0
	# A heavy swing locks its landing point during preparation. Retreat beyond
	# that point rather than paying repeated chip damage through a guard.
	var heavy: Dictionary={}
	var heavy_distance:=INF
	for enemy in combat.enemies:
		if int(enemy.hp)<=0 or str(enemy.state) not in ["windup","strike"] or str(enemy.kind)!="overhead": continue
		var landing_distance: float=absf(float(enemy.target_x)-position.x)
		if landing_distance<110 and landing_distance<heavy_distance:
			heavy=enemy
			heavy_distance=landing_distance
	if not heavy.is_empty():
		var away: float=signf(position.x-float(heavy.target_x))
		if absf(away)<0.1: away=-signf(float(heavy.position.x)-position.x)
		if position.x+away*95<combat.deck.position.x+100 or position.x+away*95>combat.deck.end.x-100: away=-away
		c.move=away if heavy_distance<86 else 0.0
		return c
	# Defend regular committed trident swings; counter through recovery openings.
	var danger: Dictionary={}
	var imminent:=INF
	for enemy in combat.enemies:
		if int(enemy.hp)<=0 or str(enemy.state) not in ["windup","strike"]: continue
		var reach: float=absf(float(enemy.position.x)-position.x)
		if reach<185 and reach<imminent:
			imminent=reach
			danger=enemy
	if not danger.is_empty():
		var toward: float=signf(float(danger.position.x)-position.x)
		c.guard=true
		c.move=toward if facing*toward<0 else 0.0
	else:
		c.attack=distance<113 and combat.player_attack_age<0 and str(nearest.state)!="arrive"
	# Stay on the authored surviving deck during the combat test.
	if position.x<combat.deck.position.x+100 and c.move<0: c.move=0.0
	if position.x>combat.deck.end.x-100 and c.move>0: c.move=0.0
	return c
