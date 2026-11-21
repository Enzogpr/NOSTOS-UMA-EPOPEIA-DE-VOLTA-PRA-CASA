extends RefCounted
## The established water soldiers, adapted to feet moving across a 2D arena.
const WATER_GEOMETRY := preload("res://Ato12_Poseidon/Gameplay/PoseidonWaterGeometry.gd")
const WAVE_ROLES := [["lancer","flanker","lancer","flanker","lancer"],["captain"],["archer","lancer","lancer"]]
var enemies: Array[Dictionary] = []
var arrows: Array[Dictionary] = []
var kills := 0
var serial := 0
var formation_age := 0.0
var shots_fired := 0

func clear() -> void:
	enemies.clear()
	arrows.clear()
	kills = 0
	serial = 0
	formation_age = 0.0
	shots_fired = 0

func spawn_formation(index: int, arena: Rect2, hp: int, captain_hp: int) -> void:
	formation_age = 0.0
	var roles: Array = WAVE_ROLES[clampi(index,0,WAVE_ROLES.size()-1)]
	var starts := [Vector2(155,401),Vector2(997,531),Vector2(140,548),Vector2(1011,403),Vector2(970,468)]
	if index == 1:
		starts = [Vector2(855,469)]
	elif index == 2:
		starts = [Vector2(963,405),Vector2(135,421),Vector2(1013,545)]
	for n in roles.size():
		serial += 1
		var side := -1 if n % 2 == 0 else 1
		var at: Vector2 = starts[n].clamp(arena.position+Vector2(18,12),arena.end-Vector2(18,12))
		var role: String = roles[n]
		var elite := role == "captain"
		var life := captain_hp if elite else 28 if role=="archer" else 20 if index==2 else hp+4 if role=="flanker" else hp
		enemies.append({"id":serial, "position":at, "hp":life, "max_hp":life, "elite":elite,
			"state":"arrive", "age":0.0, "flash":0.0, "facing":Vector2(-side, 0),
			"direction":Vector2(-side, 0), "origin":at, "spent":false, "attacks":0, "stagger_cd":0.0,
			"role":role,"kind":"thrust","reach":178.0 if elite else 132.0 if role=="flanker" else 140.0,
			"combo_left":0,"chained":false,"armor_flash":0.0,
			"push_velocity":Vector2.ZERO,"push_left":0.0,"stagger_duration":0.16,"shot_cooldown":0.7})

func remaining() -> int:
	var alive := 0
	for enemy in enemies:
		if enemy.hp > 0:
			alive += 1
	return alive

func hit(origin: Vector2, direction: Vector2, reach: float, damage: int) -> int:
	var hits := 0
	for enemy in enemies:
		if enemy.hp <= 0 or enemy.state == "arrive":
			continue
		var offset: Vector2 = enemy.position - origin
		if offset.length() > reach + 13 or (offset.length() > 25 and offset.normalized().dot(direction) < 0.24):
			continue
		_damage(enemy,damage,origin)
		hits += 1
	return hits

func hit_by_wind(from: Vector2, to: Vector2, damage: int) -> bool:
	for enemy in enemies:
		if enemy.hp <= 0 or enemy.state == "arrive":
			continue
		if Geometry2D.get_closest_point_to_segment(enemy.position,from,to).distance_to(enemy.position) < 25:
			_damage(enemy,damage,from)
			if enemy.hp > 0:
				var resistance := 0.45 if enemy.elite else 1.0
				enemy.push_velocity = from.direction_to(to)*430*resistance
				enemy.push_left = 0.32
				if not enemy.elite or enemy.state in ["approach","recover","stagger"]:
					_state(enemy,"stagger")
					enemy.stagger_duration = 0.28
					enemy.combo_left = 0
			return true
	return false

func _damage(enemy: Dictionary, amount: int, origin: Vector2) -> void:
	var frontal: bool = (origin-enemy.position).normalized().dot(enemy.facing) > 0.55
	if enemy.elite and enemy.state in ["approach","windup"] and frontal:
		amount = maxi(1,ceili(amount*0.5))
		enemy.armor_flash = 0.24
	enemy.hp = maxi(0,int(enemy.hp)-amount)
	enemy.flash = 0.16
	if enemy.hp == 0:
		_state(enemy,"dead")
		kills += 1
	elif enemy.stagger_cd <= 0 and enemy.state in ["approach","recover"]:
		_state(enemy,"stagger")
		enemy.stagger_duration = 0.16
		enemy.stagger_cd = 1.1

func _attack_slots() -> int:
	var count := 0
	for enemy in enemies:
		if enemy.hp > 0 and enemy.role != "archer" and enemy.state in ["windup","strike","chain"]:
			count += 1
	return count

func _begin_attack(enemy: Dictionary, player: Vector2) -> void:
	enemy.direction = enemy.position.direction_to(player)
	enemy.origin = enemy.position
	enemy.attacks += 1
	enemy.chained = false
	enemy.combo_left = 2 if enemy.elite and enemy.attacks%3==0 else 1 if enemy.role in ["captain","flanker"] else 0
	enemy.kind = "sweep" if enemy.elite and enemy.attacks%2 == 0 else "thrust"
	_state(enemy,"windup")

func windup_time(enemy: Dictionary) -> float:
	return 0.46 if enemy.chained else 0.72 if enemy.elite else 0.57 if enemy.role=="flanker" else 0.63

func tick(dt: float, player: Vector2, arena: Rect2) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	formation_age += dt
	for enemy in enemies:
		enemy.age += dt
		enemy.flash = maxf(0, enemy.flash - dt)
		enemy.armor_flash = maxf(0,enemy.armor_flash-dt)
		enemy.stagger_cd = maxf(0, enemy.stagger_cd - dt)
		enemy.shot_cooldown = maxf(0,enemy.shot_cooldown-dt)
		if enemy.push_left > 0 and enemy.hp > 0:
			var previous: Vector2 = enemy.position
			enemy.position = (enemy.position+enemy.push_velocity*dt).clamp(arena.position+Vector2(18,12),arena.end-Vector2(18,12))
			enemy.origin += enemy.position-previous
			enemy.push_velocity *= exp(-dt*7.5)
			enemy.push_left = maxf(0,enemy.push_left-dt)
		var delta: Vector2 = player - enemy.position
		if enemy.role == "archer":
			_archer_tick(enemy,dt,player,arena)
			continue
		match enemy.state:
			"arrive":
				if enemy.age > 1.05:
					_state(enemy, "approach")
			"approach":
				enemy.facing = delta.normalized()
				if delta.length() > (153 if enemy.elite else 127) or _attack_slots() >= 2:
					var separation := Vector2.ZERO
					for other in enemies:
						if other.id != enemy.id and other.hp > 0:
							var away: Vector2 = enemy.position - other.position
							if away.length() < 68:
								separation += away.normalized() * (68 - away.length()) * 2.6
					var flank := delta.normalized().orthogonal()*(51 if enemy.id%2==0 else -51) if enemy.role=="flanker" else Vector2.ZERO
					var speed := 138.0 if enemy.elite else 132.0 if enemy.role=="flanker" else 112.0
					var motion := delta.normalized()*speed + separation + flank
					if _attack_slots() >= 2 and delta.length() < 160:
						motion = delta.normalized().orthogonal()*93+separation
					enemy.position = (enemy.position + motion * dt).clamp(arena.position + Vector2(18, 12), arena.end - Vector2(18, 12))
				else:
					_begin_attack(enemy,player)
			"windup":
				if enemy.age < windup_time(enemy)-0.25:
					enemy.direction = delta.normalized()
					enemy.facing = enemy.direction
				if enemy.age >= windup_time(enemy):
					_state(enemy, "strike")
			"strike":
				if enemy.kind == "thrust":
					enemy.position = (enemy.origin+enemy.direction*(43 if enemy.role=="flanker" else 27)*smoothstep(0.025,0.18,enemy.age)).clamp(arena.position+Vector2(18,12),arena.end-Vector2(18,12))
				if not enemy.spent and WATER_GEOMETRY.soldier_hits(enemy,player):
					enemy.spent = true
					contacts.append({"origin":enemy.position, "damage":3 if enemy.elite else 1})
				if enemy.age >= 0.26:
					_state(enemy,"chain" if enemy.combo_left > 0 else "recover")
			"chain":
				if enemy.age >= 0.18:
					enemy.combo_left -= 1
					enemy.chained = true
					enemy.kind = "sweep" if enemy.elite else "thrust"
					enemy.origin = enemy.position
					enemy.direction = delta.normalized()
					_state(enemy,"windup")
			"recover":
				if enemy.age >= (0.90 if enemy.elite else 0.78):
					_state(enemy, "approach")
			"stagger":
				if enemy.age > enemy.stagger_duration:
					_state(enemy, "approach")
	_update_arrows(dt,player,contacts)
	return contacts

func _archer_tick(enemy: Dictionary, dt: float, player: Vector2, arena: Rect2) -> void:
	var delta: Vector2 = player-enemy.position
	match enemy.state:
		"arrive":
			if enemy.age > 1.05:_state(enemy,"approach")
		"approach":
			enemy.facing = delta.normalized()
			var motion := Vector2.ZERO
			if delta.length() < 250:
				motion = -delta.normalized()*96+delta.normalized().orthogonal()*38
			elif delta.length() > 420:
				motion = delta.normalized()*72
			else:
				motion = delta.normalized().orthogonal()*25
			enemy.position = (enemy.position+motion*dt).clamp(arena.position+Vector2(25,15),arena.end-Vector2(25,15))
			if enemy.shot_cooldown <= 0:
				enemy.direction = (enemy.position-Vector2(0,25)).direction_to(player)
				_state(enemy,"aim")
		"aim":
			if enemy.age < 0.75:
				enemy.direction = (enemy.position-Vector2(0,25)).direction_to(player)
				enemy.facing = enemy.direction
			if enemy.age >= 1.02:
				var at: Vector2 = enemy.position-Vector2(0,25)+enemy.direction*50
				arrows.append({"position":at,"direction":enemy.direction,"age":0.0,"spent":false})
				shots_fired += 1
				enemy.attacks += 1
				_state(enemy,"shoot")
		"shoot":
			if enemy.age >= 0.24:
				enemy.shot_cooldown = 1.35
				_state(enemy,"recover")
		"recover":
			if enemy.age >= 0.7:_state(enemy,"approach")
		"stagger":
			if enemy.age > enemy.stagger_duration:_state(enemy,"approach")

func _update_arrows(dt: float, player: Vector2, contacts: Array[Dictionary]) -> void:
	for i in range(arrows.size()-1,-1,-1):
		var arrow: Dictionary = arrows[i]
		arrow.age += dt
		arrow.position += arrow.direction*390*dt
		if arrow.age > 3.0 or arrow.spent:
			arrows.remove_at(i)
		elif WATER_GEOMETRY.arrow_hits(arrow,player):
			arrow.spent = true
			contacts.append({"origin":arrow.position-arrow.direction*30,"damage":2})

func _state(enemy: Dictionary, state: String) -> void:
	enemy.state = state
	enemy.age = 0.0
	enemy.spent = false
