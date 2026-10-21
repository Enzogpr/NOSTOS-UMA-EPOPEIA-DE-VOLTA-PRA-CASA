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
	# Defend committed trident swings; only attack through the recovery opening.
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
