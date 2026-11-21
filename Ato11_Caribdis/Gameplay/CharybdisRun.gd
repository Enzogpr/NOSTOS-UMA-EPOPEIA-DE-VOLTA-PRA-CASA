extends RefCounted

signal struck

enum Phase { READY, ORBIT, RELEASE, LOST, DONE }

const LIMIT := 55.0
const RELEASE_TIME := 3.0
const MAX_HULL := 3
const RADII := [145.0, 215.0, 286.0]
const BUILDUP := 1.48
const WINDOW := 0.29
# Crossing time in tenths of a second, occupied lanes, lanes occupied by teeth.
# Bit 0 is the innermost lane. Each sweep leaves at least one clear passage.
const SWEEPS := [
	Vector3i(55, 2, 2), Vector3i(89, 4, 0), Vector3i(123, 1, 1),
	Vector3i(158, 3, 1), Vector3i(191, 6, 4), Vector3i(223, 5, 1),
	Vector3i(255, 3, 3), Vector3i(284, 6, 2), Vector3i(313, 5, 4),
	Vector3i(342, 3, 1), Vector3i(370, 6, 6), Vector3i(398, 5, 1),
	Vector3i(424, 3, 3), Vector3i(450, 5, 4), Vector3i(476, 6, 4),
	Vector3i(500, 3, 1), Vector3i(522, 6, 6), Vector3i(540, 5, 5),
]

var phase := Phase.READY
var time := 0.0
var release := 0.0
var lane := 1.0
var target_lane := 1
var hull := MAX_HULL
var hit_cooldown := 0.0
var helm_speed := 3.0

func set_agility(speed_mult: float) -> void:
	helm_speed = 3.0 * clampf(sqrt(speed_mult), 0.7, 1.3)

func start() -> void:
	time = 0.0
	release = 0.0
	lane = 1.0
	target_lane = 1
	hull = MAX_HULL
	hit_cooldown = 0.0
	phase = Phase.ORBIT

func steer(step: int) -> void:
	if phase == Phase.ORBIT:
		target_lane = clampi(target_lane + step, 0, RADII.size() - 1)

func tick(delta: float) -> void:
	if phase == Phase.RELEASE:
		release = minf(release + delta, RELEASE_TIME)
		if release >= RELEASE_TIME:
			phase = Phase.DONE
		return
	if phase != Phase.ORBIT:
		return
	time = minf(LIMIT, time + delta)
	hit_cooldown = maxf(hit_cooldown - delta, 0.0)
	lane = move_toward(lane, target_lane, helm_speed * delta)
	if hit_cooldown == 0.0:
		_check_collision()
	if time >= LIMIT and phase == Phase.ORBIT:
		phase = Phase.RELEASE

func angle_at(at: float) -> float:
	return -0.2 + 0.66 * at + 0.0055 * at * at

func sweep_time(sweep: Vector3i) -> float:
	return sweep.x / 10.0

func radius_at(at_lane: float) -> float:
	var lo := clampi(floori(at_lane), 0, RADII.size() - 1)
	return lerpf(RADII[lo], RADII[mini(lo + 1, RADII.size() - 1)], at_lane - lo)

func power() -> float:
	if phase == Phase.READY:
		return 0.32
	return (0.60 + time / LIMIT * 0.40) * (1.0 - smoothstep(0.0, RELEASE_TIME, release))

func _check_collision() -> void:
	var contact := minf(WINDOW, 0.23 * RADII[1] / radius_at(lane) / (1.0 + time * 0.007))
	for sweep: Vector3i in SWEEPS:
		var remaining := sweep_time(sweep) - time
		if remaining > WINDOW:
			return
		if absf(remaining) > contact:
			continue
		for index in RADII.size():
			if (sweep.y & (1 << index)) != 0 and absf(lane - index) <= 0.36:
				hull -= 1
				hit_cooldown = 0.88
				if hull == 0:
					phase = Phase.LOST
				struck.emit()
				return
