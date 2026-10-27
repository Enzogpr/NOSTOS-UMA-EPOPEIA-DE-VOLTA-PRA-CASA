extends SceneTree
const Model = preload("res://Ato4_Tempestade/Gameplay/PoseidonCadenceModel.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func arena(final_ship: bool = false) -> Variant:
	var m := Model.new()
	m.start()
	m.obstacles.clear()
	m.next_attack_score = 100000.0
	m.fleet_next_score = 100000.0
	if final_ship:
		m.position = Vector2(m.final_origin+120.0, m.boats[10].rect.position.y)
		m._enter_boat(10)
		m.next_attack_score = 100000.0
		for i in m.platforms.size():
			if m.platforms[i].boat == 10:
				m.support = i
				break
	return m

func run() -> void:
	var m: Variant = arena()
	var start: Vector2 = m.position
	m.set_dash_input(true)
	m.tick(1.0/120.0)
	check(m.dashes == 1 and m.dash_time > 0.0, "Dash starts from a discrete request")
	check(m.invulnerable <= 0.0, "Dash does not grant invulnerability absent from the canonical player")
	m.tick(0.2-1.0/120.0)
	check(absf(m.position.x-start.x-m.dash_speed*0.2) < 3.0, "Dash travels its authored speed for 0.2 seconds")
	check(m.dash_time <= 0.00001, "Dash releases the player at the end of its duration")
	m.set_dash_input(true)
	m.tick(0.05)
	check(m.dashes == 1 and m.dash_time <= 0.0, "A repeated edge cannot bypass cooldown")
	for i in 13:
		m.tick(0.25)
	m.set_dash_input(true)
	m.tick(1.0/120.0)
	check(m.dashes == 2, "Dash becomes available after its cooldown")
	check(absf(m.dash_cooldown_seconds-3.0) < 0.001, "Standalone phase uses the canonical default cooldown")

	var left: Variant = arena()
	left.position.x = 700.0
	left.set_dash_input(true)
	left.tick(0.1,-1.0)
	check(left.position.x < 650.0 and left.dash_direction < 0.0, "Directional input chooses a leftward dash")
	var facing: Variant = arena()
	facing.position.x = 700.0
	facing.facing = -1.0
	facing.set_dash_input(true)
	facing.tick(0.1)
	check(facing.position.x < 650.0, "Dash uses facing when no horizontal direction is held")

	var air: Variant = arena()
	air.position.y = 200.0
	air.grounded = false
	air.support = -1
	air.set_dash_input(true)
	air.tick(0.1,1.0)
	check(air.position.x > 230.0 and air.position.y > 200.0 and air.velocity.y > 0.0, "Air dash remains horizontal while gravity continues")
	check(not air.grounded and air.dash_time > 0.0, "Air dash does not invent a landing or a second jump")

	var wall: Variant = arena()
	wall.obstacles.append({"rect":Rect2(260,380,80,100),"kind":"crate","boat":0,"active":true})
	wall.set_dash_input(true)
	wall.tick(0.2,1.0)
	check(wall.position.x <= 246.01, "Dash respects the existing solid cargo collision")
	check(wall.dash_time <= 0.0, "Dash ends against a wall without sliding through it")

	var guard: Variant = arena(true)
	guard.set_combat_input(false,true)
	guard.set_dash_input(true)
	guard.tick(0.01)
	check(guard.dashes == 0 and guard.boarding.player_guarding, "Guarding rejects dash rather than performing both actions")
	var swing: Variant = arena(true)
	swing.boarding.player_attack_age = 0.1
	swing.set_dash_input(true)
	swing.tick(0.01)
	check(swing.dashes == 0, "An active sword swing cannot be canceled into dash")
	var duck: Variant = arena()
	duck.set_dash_input(true)
	duck.tick(0.01,0.0,true)
	check(duck.dashes == 0 and duck.crouching, "Crouching rejects dash under a low passage")
	var stun: Variant = arena()
	stun.hit_stun = 0.15
	stun.set_dash_input(true)
	stun.tick(0.01)
	check(stun.dashes == 0, "Hit stun cannot be bypassed with dash")

	var busy: Variant = arena(true)
	busy.set_dash_input(true)
	busy.tick(0.05)
	busy.set_combat_input(true,true)
	busy.tick(0.01)
	check(busy.boarding.player_attack_age < 0.0 and not busy.boarding.player_guarding, "Active dash suppresses attack and guard simultaneously")
	busy._hit("low",-1.0)
	check(busy.balance == 72.0 and busy.dash_time <= 0.0, "A divine wave damages and interrupts a dash")

	var checkpoint: Variant = arena()
	checkpoint.set_dash_input(true)
	checkpoint.tick(0.05)
	checkpoint._save_checkpoint()
	var saved_time: float = checkpoint.dash_time
	var saved_cooldown: float = checkpoint.dash_cooldown_remaining
	var saved_direction: float = checkpoint.dash_direction
	checkpoint.tick(0.2)
	checkpoint._fail("Dash checkpoint fixture")
	checkpoint.retry_checkpoint()
	check(absf(checkpoint.dash_time-saved_time) < 0.00001 and absf(checkpoint.dash_cooldown_remaining-saved_cooldown) < 0.00001 and checkpoint.dash_direction == saved_direction, "Retry restores active dash duration, cooldown and direction exactly")
	var saved_x: float = checkpoint.position.x
	checkpoint.tick(0.01)
	check(checkpoint.position.x > saved_x+8.0, "Restored dash continues from the saved collision position")
	checkpoint._fail("Frozen dash fixture")
	var frozen_time: float = checkpoint.dash_time
	var frozen_cooldown: float = checkpoint.dash_cooldown_remaining
	var frozen_position: Vector2 = checkpoint.position
	checkpoint.set_dash_input(true)
	checkpoint.tick(0.25,1.0)
	check(checkpoint.dash_time == frozen_time and checkpoint.dash_cooldown_remaining == frozen_cooldown and checkpoint.position == frozen_position, "Failure freezes dash motion and cooldown until explicit retry")
	print("CADENCE_DASH ", checks, " CHECKS ", failures, " FAILURES")
	quit(0 if failures == 0 else 1)
