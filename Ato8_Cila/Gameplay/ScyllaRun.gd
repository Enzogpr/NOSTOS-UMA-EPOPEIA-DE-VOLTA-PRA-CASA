extends RefCounted

signal impact(kind: String, at: Vector2)
signal torch_lost(index: int, at: Vector2)

enum Phase { READY, RUNNING, ESCAPED }

const EXIT_DISTANCE := 4460.0
const OPENING := 0.27
const RECOIL := 0.88
const ATTACK_DURATION := 1.55

# Distance along the cave, lateral center and half width at each bend.
const CHANNEL := [
	Vector3(0, 0, 265), Vector3(485, -12, 193), Vector3(980, -132, 150),
	Vector3(1460, 78, 133), Vector3(1930, 124, 151), Vector3(2430, -108, 146),
	Vector3(2900, -124, 123), Vector3(3390, 110, 143), Vector3(3880, 66, 131),
	Vector3(4230, -12, 199), Vector3(4460, 3, 290), Vector3(5050, 0, 385),
]
# Distance, wall side, and the torch carried on that side.
const ATTACKS := [
	Vector3(610, -1, 0), Vector3(1160, 1, 1), Vector3(1760, -1, 2),
	Vector3(2320, 1, 3), Vector3(2950, -1, 4), Vector3(3680, 1, 5),
]
const TORCHES := [
	Vector2(-19, 46), Vector2(19, 9), Vector2(-19, -38),
	Vector2(19, 46), Vector2(-19, 9), Vector2(19, -38),
]

class Lunge:
	var age := -1.0
	var taken := false
	var strike_distance := 0.0

var phase := Phase.READY
var distance := 0.0
var lateral := 0.0
var speed := 0.0
var heading := 0.0
var torches := TORCHES.size()
var clock := 0.0
var agility := 1.0
var lunges: Array[Lunge] = []

func _init() -> void:
	for index in ATTACKS.size():
		lunges.append(Lunge.new())

func apply_attributes(stats: Dictionary) -> void:
	agility = clampf(sqrt(float(stats.speed_mult)), 0.7, 1.3)

func restart() -> void:
	phase = Phase.RUNNING
	distance = 0.0
	lateral = 0.0
	speed = 0.0
	heading = 0.0
	torches = TORCHES.size()
	clock = 0.0
	for lunge in lunges:
		lunge.age = -1.0
		lunge.taken = false
		lunge.strike_distance = 0.0

static func channel_at(at: float) -> Vector2:
	for index in range(1, CHANNEL.size()):
		var end: Vector3 = CHANNEL[index]
		if at <= end.x:
			var start: Vector3 = CHANNEL[index - 1]
			var blend := smoothstep(start.x, end.x, at)
			return Vector2(lerpf(start.y, end.y, blend), lerpf(start.z, end.z, blend))
	return Vector2(CHANNEL[-1].y, CHANNEL[-1].z)

func tick(delta: float, forward: bool) -> void:
	if phase != Phase.RUNNING or delta <= 0.0:
		return
	clock += delta
	speed = move_toward(speed, 144.0 * agility if forward else 0.0, delta * (150.0 if forward else 267.0))
	distance = minf(distance + speed * delta, EXIT_DISTANCE)
	lateral = channel_at(distance).x
	var ahead := channel_at(distance + 32.0).x - channel_at(distance - 32.0).x
	heading = move_toward(heading, clampf(ahead / 110.0, -0.35, 0.35), delta * 1.15)
	for i in lunges.size():
		_update_lunge(i, delta)
	if distance >= EXIT_DISTANCE and torches == 0:
		phase = Phase.ESCAPED

func torch_at(index: int, at: float) -> Vector2:
	var slot: Vector2 = TORCHES[index]
	var along := at + slot.y
	return Vector2(channel_at(at).x + slot.x, along)

func torch_strength(index: int) -> float:
	var lunge := lunges[index]
	if lunge.taken:
		return 0.0
	if lunge.age < 0.0:
		return 1.0
	var wind := smoothstep(OPENING, RECOIL, lunge.age)
	return (1.0 - wind) * (1.0 - wind * (0.30 + 0.30 * sin(lunge.age * 52.0)))

func reach(index: int) -> float:
	var age := lunges[index].age
	if age < 0.0:
		return 0.0
	return smoothstep(0.08, RECOIL - 0.10, age) * (1.0 - smoothstep(RECOIL, ATTACK_DURATION, age))

func _update_lunge(index: int, delta: float) -> void:
	var attack: Vector3 = ATTACKS[index]
	var lunge := lunges[index]
	if lunge.age < 0.0:
		if distance < attack.x:
			return
		lunge.age = 0.0
		var channel := channel_at(distance + 80.0)
		impact.emit("surface", Vector2(channel.x + channel.y * attack.y, distance + 80.0))
	var previous := lunge.age
	lunge.age = minf(lunge.age + delta, ATTACK_DURATION)
	if previous < OPENING and lunge.age >= OPENING:
		impact.emit("lunge", torch_at(int(attack.z), distance))
	if not lunge.taken and lunge.age >= RECOIL:
		lunge.taken = true
		lunge.strike_distance = distance
		torches -= 1
		torch_lost.emit(int(attack.z), torch_at(int(attack.z), distance))
