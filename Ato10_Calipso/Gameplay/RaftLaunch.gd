extends RefCounted

signal notice(text: String)
signal grounded
signal reached_sea

enum Phase { SHORE, AFLOAT, ARRIVED }

const COVE := 0
const OPEN := 1
const NAMES := ["ENSEADA PROTEGIDA", "PRAIA ABERTA"]
const TARGET := [-0.52, 0.45]
const FINISH := 1540.0
const ESCAPE_FINISH := 2130.0
const TIDE_PERIOD := 7.2
const ROCKS: Array[Vector3] = [Vector3(-168, 288, 57), Vector3(54, 556, 52), Vector3(-34, 874, 59), Vector3(138, 1155, 48)]
const WAVE_Z: Array[float] = [412.0, 767.0, 1090.0]
const ESCAPE_COVE_REEFS: Array[Vector3] = [
	Vector3(-45, 320, 50), Vector3(67, 627, 61), Vector3(-54, 897, 58),
	Vector3(65, 1196, 65), Vector3(-77, 1513, 63), Vector3(42, 1762, 52),
]
const ESCAPE_OPEN_REEFS: Array[Vector3] = [Vector3(82, 445, 42), Vector3(-68, 957, 49), Vector3(61, 1475, 47)]
const ESCAPE_COVE_WAVES: Array[float] = [480.0, 1050.0, 1645.0]
const ESCAPE_OPEN_WAVES: Array[float] = [317.0, 598.0, 851.0, 1138.0, 1372.0, 1660.0, 1845.0]
const NO_REEFS: Array[Vector3] = []
const NO_WAVES: Array[float] = []

var phase := Phase.SHORE
var beach := COVE
var angle := 0.0
var clock := 0.0
var shore_delay := 0.0
var lash := 0.0
var distance := 0.0
var lateral := 0.0
var speed := 0.0
var side_speed := 0.0
var speed_factor := 1.0
var steer_factor := 1.0
var escape_attempt := false

func apply_stats(stats: Dictionary) -> void:
	speed_factor = clampf(sqrt(float(stats.speed_mult)), 0.7, 1.3)
	steer_factor = clampf(1.0 + (float(stats.intellect) - 5.0) * 0.02, 1.0, 1.2)

func choose_beach(index: int) -> void:
	if phase == Phase.SHORE:
		beach = clampi(index, COVE, OPEN)

func tide() -> float:
	return 0.5 + cos(clock * TAU / TIDE_PERIOD) * 0.5

func retreating() -> bool:
	var step := fposmod(clock, TIDE_PERIOD)
	return step >= 1.3 and step <= 3.9

func launch() -> void:
	if phase != Phase.SHORE or shore_delay > 0.0:
		return
	if lash < 1.0:
		notice.emit("Segure E para tensionar as amarras da jangada.")
		return
	if absf(angle - float(TARGET[beach])) > 0.32:
		_back_to_shore("A corrente pegou a jangada de lado.")
		return
	if beach == OPEN and not retreating():
		_back_to_shore("A arrebentação trouxe a jangada de volta.")
		return
	_begin_crossing()

func begin_escape(route: int) -> void:
	retry()
	escape_attempt = true
	beach = clampi(route, COVE, OPEN)
	angle = float(TARGET[beach])
	clock = 2.0
	_begin_crossing()

func _begin_crossing() -> void:
	distance = 0.0
	lateral = sin(angle) * 30.0
	side_speed = sin(angle) * 57.0
	speed = 80.0
	phase = Phase.AFLOAT

func tick(delta: float, steering: float, thrust: float, hold_rope: bool) -> void:
	clock += delta
	shore_delay = maxf(0.0, shore_delay - delta)
	if phase == Phase.SHORE:
		angle = clampf(angle + steering * delta * 1.45, -1.35, 1.35)
		if hold_rope:
			lash = minf(1.0, lash + delta / 0.72)
		return
	if phase != Phase.AFLOAT:
		return
	var target_speed := 128.0 + thrust * (46.0 if thrust >= 0.0 else 58.0)
	speed = move_toward(speed, target_speed * speed_factor, delta * 174.0)
	distance += speed * delta
	var current := sin(distance * 0.012 + clock * 0.7) * (19.0 if beach == COVE else 46.0)
	var breaker_force := 67.0 if beach == COVE else 113.0
	for wave in waves():
		current += (1.0 - smoothstep(0.0, 110.0, absf(distance - wave))) * breaker_force * wave_side(wave)
	side_speed = move_toward(side_speed, steering * 213.0 * steer_factor * speed_factor + current, delta * 730.0)
	lateral += side_speed * delta
	angle = move_toward(angle, side_speed / 395.0, delta * 2.2)
	if absf(lateral - channel_center(distance)) > channel_width(distance) - 19.0:
		_back_to_shore("A corrente empurrou a jangada para fora do canal.")
		return
	for rock in reefs():
		if Vector2(lateral, distance).distance_to(Vector2(rock.x, rock.y)) < rock.z + 19.0:
			_back_to_shore("A madeira bateu num recife. A corrente levou a embarcação de volta.")
			return
	if distance >= finish_distance():
		phase = Phase.ARRIVED
		reached_sea.emit()

func channel_center(at: float) -> float:
	if escape_attempt:
		var bend := 57.0 if beach == COVE else 88.0
		return sin(at / 199.0) * bend + sin(at / 91.0) * 16.0
	return sin(at / 225.0) * (45.0 if beach == COVE else 100.0)

func channel_width(at: float) -> float:
	if escape_attempt:
		var opening := 177.0 if beach == COVE else 160.0
		return opening + smoothstep(1798.0, ESCAPE_FINISH, at) * 108.0
	return (242.0 if beach == COVE else 188.0) + smoothstep(1150.0, FINISH, at) * 170.0

func finish_distance() -> float:
	return ESCAPE_FINISH if escape_attempt else FINISH

func reefs() -> Array[Vector3]:
	if escape_attempt:
		return ESCAPE_COVE_REEFS if beach == COVE else ESCAPE_OPEN_REEFS
	return ROCKS if beach == COVE else NO_REEFS

func waves() -> Array[float]:
	if escape_attempt:
		return ESCAPE_COVE_WAVES if beach == COVE else ESCAPE_OPEN_WAVES
	return WAVE_Z if beach == OPEN else NO_WAVES

func wave_side(at: float) -> float:
	return -1.0 if waves().find(at) % 2 == 1 else 1.0

func retry() -> void:
	phase = Phase.SHORE
	distance = 0.0
	lateral = 0.0
	speed = 0.0
	side_speed = 0.0
	shore_delay = 0.0

func _back_to_shore(message: String) -> void:
	retry()
	shore_delay = 0.86
	notice.emit(message)
	grounded.emit()
