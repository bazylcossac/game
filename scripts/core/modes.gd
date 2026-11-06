class_name Modes
extends RefCounted
## Game modes and maps as data, so the menus, the server arguments and the rules all read
## the same table. A match is described by its cfg: "mode" and "map" hold keys of these
## tables, and the server sends that cfg to every client that joins.


const DEFAULT_MODE := "podboj"
const DEFAULT_SEED := 1943

const MAPS := {
	"dolina_pancerna": {"name": "Dolina Pancerna", "desc": "Duże pole walki 1020 × 900 m. Bazy za grzbietami, boczne wyjazdy i trzy cele."},
	"neonowa_dzielnica": {"name": "Neonowa Dzielnica", "desc": "Deszczowa noc w śródmieściu 520 × 700 m: szerokie aleje, wieżowce i kolej nad bulwarem. Miejsca dość dla czołgów i mechów."},
	"stacja_rdzen": {"name": "Stacja Rdzeń", "desc": "Reaktor z galerią, kapsuły kriogeniczne po zachodniej stronie i labirynt kontenerów po wschodniej."},
	"stare_miasto": {"name": "Stare Miasto", "desc": "Zrujnowane miasto: ulice, ratusz, dworzec i rynek."},
	"ziemia_niczyja": {"name": "Ziemia Niczyja", "desc": "Front w błocie i deszczu, 720 × 600 m: dwie linie okopów na stronę, zasieki, leje po pociskach i burza nad głową."},
	"pole_bitwy": {"name": "Pole Bitwy", "desc": "Otwarte pola, wzgórza, okopy i leje po bombach."},
	"rynek": {"name": "Rynek", "desc": "Ciasny plac pod wieżą zegarową, barykady w zaułkach i bombowce nad głową."},
}

## "maps": the first one is the default. "team_max": soldiers per side, or all of them in a
## free-for-all. "bleed": flags held -> seconds between tickets taken from the enemy.
const LIST := {
	"podboj": {
		"name": "Podbój", "rules": "conquest", "maps": ["neonowa_dzielnica", "ziemia_niczyja", "stare_miasto", "stacja_rdzen"],
		"desc": "Pięć flag, ograniczone posiłki. Trzymaj większość flag, a wróg traci je szybciej.",
		"flags": true, "vehicles": true, "coins": true, "squads": true, "team_min": 4, "team_max": 24,
		"limit": C.START_TICKETS, "bleed": {3: C.BLEED_MAJORITY, 4: C.BLEED_DOMINANT},
	},
	"pvp": {
		"name": "Klasyczne PvP", "rules": "kills", "maps": ["neonowa_dzielnica", "ziemia_niczyja", "rynek", "pole_bitwy", "stacja_rdzen"],
		"desc": "Dwie drużyny, odrodzenia bez limitu. Pierwsza drużyna z 75 eliminacjami wygrywa.",
		"coins": true, "squads": true, "team_min": 2, "team_max": 10, "limit": 75,
	},
	"deathmatch": {
		"name": "Deathmatch", "rules": "kills", "ffa": true, "maps": ["rynek", "neonowa_dzielnica", "stacja_rdzen"],
		"desc": "Każdy na każdego, bez drużyn. Pierwszy z 30 eliminacjami wygrywa.",
		"coins": true, "team_min": 4, "team_max": 16, "limit": 30,
	},
	"czolgi": {
		"name": "Wojna czołgów", "rules": "conquest", "maps": ["dolina_pancerna", "ziemia_niczyja", "neonowa_dzielnica"],
		"desc": "Każdy walczy w czołgu i w czołgu wraca. Trzy flagi i zniszczenia zabierają tickety.",
		"flags": true, "vehicles": true, "tanks_only": true, "team_min": 2, "team_max": 6,
		"limit": 150, "bleed": {2: 6.0, 3: 2.5},
	},
}


static func has_mode(id: String) -> bool:
	return LIST.has(id)


static func has_map(id: String) -> bool:
	return MAPS.has(id)


static func fits(mode_id: String, map_id: String) -> bool:
	return LIST.has(mode_id) and LIST[mode_id]["maps"].has(map_id)


static func mode_of(cfg: Dictionary) -> Dictionary:
	return LIST[String(cfg.get("mode", DEFAULT_MODE))]


## Fills in what is missing and corrects what does not fit, so an old cfg means Podbój.
static func normalize(cfg: Dictionary) -> Dictionary:
	var out := cfg.duplicate()
	var mode_id := String(out.get("mode", ""))
	if not LIST.has(mode_id):
		mode_id = DEFAULT_MODE
	var mode: Dictionary = LIST[mode_id]
	var map_id := String(out.get("map", ""))
	if not mode["maps"].has(map_id):
		map_id = mode["maps"][0]
	out["mode"] = mode_id
	out["map"] = map_id
	out["seed"] = int(out.get("seed", DEFAULT_SEED))
	out["bots_per_team"] = mini(int(out.get("bots_per_team", 12)), mode["team_max"])
	return out


## The score that ends the match: tickets to start with, or kills or rounds to reach. A test
## or a server owner can shorten it with "limit" in the cfg.
static func score_limit(cfg: Dictionary) -> int:
	var custom := int(cfg.get("limit", 0))
	return custom if custom > 0 else int(mode_of(cfg)["limit"])


static func create_map(cfg: Dictionary) -> MapKit:
	match String(cfg.get("map", "")):
		"dolina_pancerna": return TankValleyMap.new()
		"neonowa_dzielnica": return NeonMap.new(String(cfg.get("mode", "")))
		"ziemia_niczyja": return TrenchMap.new(String(cfg.get("mode", "")))
		"stacja_rdzen": return StationMap.new()
		"pole_bitwy": return FieldMap.new()
		"rynek": return SquareMap.new()
	return CityMap.new()
