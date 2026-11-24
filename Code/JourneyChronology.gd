extends RefCounted
## Campaign calendar, in days since the departure from Troy.
## Unknown sailing intervals are game adaptations, not Homeric dates.
const VERSION := 1
const START_AGE := 20
const DAYS_PER_YEAR := 365
const RETURN_DAYS := 10 * DAYS_PER_YEAR
const CALYPSO_YEARS := 7
const DAYS := {
	"troy_departure": 0,
	"lotus_departure": 12,
	"cyclops_departure": 47,
	"aeolia_arrival": 170,
	"aeolia_departure": 200,
	"wind_bag_opened": 209,
	"first_poseidon_escape": 220,
	"circe_search": 300,
	"circe_departure": 665,
	"underworld_crossing": 666,
	"underworld_prophecy": 667,
	"sirens_departure": 1000,
	"scylla_passage": 1001,
	"mutiny": 1068,
	"calypso_arrival": 1077,
	"calypso_departure": 3632,
	"charybdis_escape": 3649,
	"ithaca_arrival": RETURN_DAYS,
}

# Entry dates for isolated editor runs. They simulate the same age curve
# without completing earlier chapters or writing to the campaign save.
const STAGE_ENTRY := {
	"res://Ato5_Circe/Gameplay/CirceForest.tscn": "first_poseidon_escape",
	"res://Ato5_Circe/Gameplay/CirceBattle.tscn": "circe_search",
	"res://Ato6_Submundo/Gameplay/UnderworldCrossing.tscn": "circe_departure",
	"res://Ato6_Submundo/Gameplay/UnderworldOracle.tscn": "underworld_crossing",
	"res://Ato7_Sereias/Gameplay/SirenCove.tscn": "underworld_prophecy",
	"res://Ato8_Cila/Gameplay/ScyllaPassage.tscn": "sirens_departure",
	"res://Ato9_Motim/Gameplay/Mutiny.tscn": "scylla_passage",
	"res://Ato10_Calipso/Gameplay/CalypsoPaths.tscn": "calypso_arrival",
	"res://Ato10_Calipso/Gameplay/CalypsoDeparture.tscn": "calypso_departure",
	"res://Ato11_Caribdis/Gameplay/Charybdis.tscn": "calypso_departure",
	"res://Ato12_Poseidon/Gameplay/FinalPoseidon.tscn": "charybdis_escape",
	"res://Ato13_Itaca/Gameplay/Ithaca.tscn": "ithaca_arrival",
}

static func stage_entry_day(path: String) -> int:
	return day(String(STAGE_ENTRY.get(path, "")))

static func day(milestone: String) -> int:
	return int(DAYS.get(milestone, 0))

static func years(days: int) -> int:
	return floori(float(maxi(0, days)) / DAYS_PER_YEAR)

static func duration_text(days: int) -> String:
	var whole_years := years(days)
	var remainder := maxi(0, days) % DAYS_PER_YEAR
	var day_text := "%d dia%s" % [remainder, "" if remainder == 1 else "s"]
	if whole_years == 0: return day_text
	var year_text := "%d ano%s" % [whole_years, "" if whole_years == 1 else "s"]
	return year_text if remainder == 0 else year_text + " e " + day_text
