class_name Gear
extends RefCounted
## Weapon customisation and progression. Pure data and maths, shared by client and server:
## the client uses it to show choices, the server to enforce them.

const MAX_LEVEL := 30
const SLOTS := ["optic", "muzzle", "grip", "cell"]
const SLOT_NAMES := {"optic": "Celownik", "muzzle": "Wylot lufy", "grip": "Chwyt", "cell": "Ogniwo"}
const PERK_SLOTS := ["body", "kit"]
const PERK_SLOT_NAMES := {"body": "Perk: ciało", "kit": "Perk: sprzęt"}

## Primary weapons per Resistance class. The first of each row is free.
const PRIMARIES := [
	[C.W.CARBINE, C.W.ASSAULT, C.W.RIFLE, C.W.HEAVY, C.W.SWORD, C.W.LIGHTSABER, C.W.GREATSWORD],
	[C.W.SMG, C.W.SMG2, C.W.SCATTER],
	[C.W.SNIPER, C.W.SILENT, C.W.RAIL],
	[C.W.SCATTER, C.W.SMG2, C.W.RIFLE],
	[C.W.CARBINE, C.W.ASSAULT, C.W.SMG2],
	[C.W.MINIGUN, C.W.HEAVY],
]
## The same, for the Iron Empire's classes.
const PRIMARIES_EMPIRE := [
	[C.W.ASSAULT, C.W.CARBINE, C.W.RIFLE, C.W.LIGHTSABER, C.W.SWORD, C.W.GREATSWORD],
	[C.W.SNIPER, C.W.SILENT, C.W.RAIL],
	[C.W.HEAVY, C.W.SCATTER, C.W.RIFLE],
	[C.W.SCATTER, C.W.SMG, C.W.SMG2],
	[C.W.ASSAULT, C.W.CARBINE, C.W.SMG2],
	[C.W.SCATTER, C.W.SMG2, C.W.RIFLE],
]
const SIDEARMS := [C.W.PISTOL, C.W.REVOLVER, C.W.MPISTOL]

const WEAPON_LEVEL := {
	C.W.REVOLVER: 2, C.W.LIGHTSABER: 3, C.W.SMG2: 4, C.W.ASSAULT: 5, C.W.SILENT: 6, C.W.MPISTOL: 8,
	C.W.SCATTER: 1, C.W.RIFLE: 10, C.W.GREATSWORD: 12, C.W.RAIL: 13, C.W.HEAVY: 16,
}

const RIFLE_SLOTS := ["optic", "muzzle", "grip", "cell"]
const SIDEARM_SLOTS := ["muzzle", "cell"]
const SCOPED_SLOTS := ["muzzle", "grip", "cell"]
const WEAPON_SLOTS := {
	C.W.CARBINE: RIFLE_SLOTS, C.W.ASSAULT: RIFLE_SLOTS, C.W.RIFLE: RIFLE_SLOTS, C.W.HEAVY: RIFLE_SLOTS,
	C.W.MINIGUN: ["optic", "grip", "cell"],
	C.W.SMG: RIFLE_SLOTS, C.W.SMG2: RIFLE_SLOTS, C.W.SCATTER: ["optic", "grip", "cell"],
	C.W.SNIPER: SCOPED_SLOTS, C.W.SILENT: RIFLE_SLOTS, C.W.RAIL: ["grip", "cell"],
	C.W.PISTOL: SIDEARM_SLOTS, C.W.REVOLVER: SIDEARM_SLOTS, C.W.MPISTOL: SIDEARM_SLOTS,
}

## How each weapon kicks, on top of its base "recoil".
##   h     sideways wobble that swings left and right through a burst.
##   bias  steady drift: positive pulls right, negative pulls left.
##   rise  extra climb per shot, so long bursts get harder to hold.
## These come with a telescopic sight on the model, so aiming means looking through it.
const SCOPED_GUNS := [C.W.SNIPER, C.W.RAIL, C.W.RIFLE, C.W.SILENT]
const RECOIL := {
	C.W.CARBINE: {"h": 0.5, "bias": 0.1, "rise": 0.04},
	C.W.ASSAULT: {"h": 0.7, "bias": -0.3, "rise": 0.06},
	C.W.RIFLE: {"h": 0.3, "bias": 0.15, "rise": 0.0},
	C.W.HEAVY: {"h": 0.8, "bias": 0.4, "rise": 0.1},
	C.W.MINIGUN: {"h": 0.9, "bias": 0.2, "rise": 0.015},
	C.W.SMG: {"h": 1.0, "bias": 0.0, "rise": 0.02},
	C.W.SMG2: {"h": 1.4, "bias": 0.25, "rise": 0.03},
	C.W.SCATTER: {"h": 0.6, "bias": 0.0, "rise": 0.0},
	C.W.SNIPER: {"h": 0.3, "bias": 0.0, "rise": 0.0},
	C.W.SILENT: {"h": 0.4, "bias": -0.1, "rise": 0.0},
	C.W.RAIL: {"h": 0.5, "bias": 0.0, "rise": 0.0},
	C.W.PISTOL: {"h": 0.5, "bias": 0.1, "rise": 0.02},
	C.W.REVOLVER: {"h": 0.6, "bias": 0.3, "rise": 0.0},
	C.W.MPISTOL: {"h": 1.6, "bias": -0.2, "rise": 0.05},
}

## "mods" multiply a stat; "set" replaces it.
const ATTACHMENTS := {
	"reddot": {"slot": "optic", "name": "Kolimator", "level": 2,
		"desc": "Czysty punkt zamiast pierścienia. Celniej i szybciej przy celowaniu.",
		"mods": {"spread_ads": 0.8, "ads_speed": 1.1}, "set": {}},
	"holo": {"slot": "optic", "name": "Celownik holograficzny", "level": 7,
		"desc": "Szerokie okno i lekkie przybliżenie. Dobry na średni dystans.",
		"mods": {"spread_ads": 0.7, "ads_fov": 0.88}, "set": {}},
	"scope": {"slot": "optic", "name": "Luneta 3x", "level": 11,
		"desc": "Mocne przybliżenie z pełną lunetą. Wolniejsze celowanie.",
		"mods": {"spread_ads": 0.6, "ads_speed": 0.75}, "set": {"ads_fov": 0.42, "scope": true}},
	"comp": {"slot": "muzzle", "name": "Kompensator", "level": 3,
		"desc": "Mniejszy odrzut, zwłaszcza na boki. Większy błysk i rozrzut z biodra.",
		"mods": {"recoil": 0.8, "recoil_h": 0.65, "spread_hip": 1.15}, "set": {}},
	"suppressor": {"slot": "muzzle", "name": "Tłumik", "level": 6,
		"desc": "Cichy strzał, bez błysku, nie zdradza Cię na mapie wroga. Mniej obrażeń i zasięgu.",
		"mods": {"damage": 0.92, "range": 0.85, "falloff_start": 0.8}, "set": {"suppressed": true}},
	"stabilizer": {"slot": "muzzle", "name": "Stabilizator wiązki", "level": 14,
		"desc": "Wiązka trzyma moc dużo dalej. Lekko wolniejsze celowanie.",
		"mods": {"range": 1.35, "falloff_start": 1.5, "ads_speed": 0.92}, "set": {}},
	"vgrip": {"slot": "grip", "name": "Chwyt pionowy", "level": 4,
		"desc": "Stabilna broń: wyraźnie mniejszy odrzut w serii.",
		"mods": {"recoil": 0.82, "recoil_rise": 0.6}, "set": {}},
	"agrip": {"slot": "grip", "name": "Chwyt kątowy", "level": 8,
		"desc": "Szybkie złożenie do strzału. Lekko mniejszy odrzut.",
		"mods": {"ads_speed": 1.35, "recoil": 0.95}, "set": {}},
	"laser": {"slot": "grip", "name": "Wskaźnik laserowy", "level": 12,
		"desc": "Dużo celniejszy strzał z biodra.",
		"mods": {"spread_hip": 0.6, "spread_move": 0.8}, "set": {}},
	"bigcell": {"slot": "cell", "name": "Duże ogniwo", "level": 5,
		"desc": "Większy magazynek. Dłuższe przeładowanie i wolniejszy chód.",
		"mods": {"mag": 1.4, "reserve": 1.25, "reload": 1.18, "move_mult": 0.97}, "set": {}},
	"fastcell": {"slot": "cell", "name": "Szybkie ogniwo", "level": 9,
		"desc": "Dużo szybsze przeładowanie kosztem pojemności.",
		"mods": {"reload": 0.72, "mag": 0.85}, "set": {}},
	"overcell": {"slot": "cell", "name": "Ogniwo przeładowane", "level": 15,
		"desc": "Mocniejszy strzał. Mniej energii i wolniejsza szybkostrzelność.",
		"mods": {"damage": 1.12, "rate": 1.1, "mag": 0.8}, "set": {}},
}

const PERKS := {
	"tough": {"slot": "body", "name": "Twardziel", "level": 3, "desc": "+15 zdrowia."},
	"runner": {"slot": "body", "name": "Maratończyk", "level": 5, "desc": "O 50% dłuższy sprint."},
	"quiet": {"slot": "body", "name": "Cichy krok", "level": 8, "desc": "Prawie niesłyszalne kroki, wrogie boty słyszą Cię z bliska."},
	"reflex": {"slot": "body", "name": "Refleks", "level": 11, "desc": "Szybsze celowanie i zmiana broni."},
	"scavenger": {"slot": "kit", "name": "Zbieracz", "level": 2, "desc": "+50% zapasowej energii."},
	"grenadier": {"slot": "kit", "name": "Granatnik", "level": 6, "desc": "+1 granat odłamkowy."},
	"fieldmed": {"slot": "kit", "name": "Polowy opatrunek", "level": 10, "desc": "Zdrowie wraca po 4 s zamiast po 7 s."},
	"flak": {"slot": "kit", "name": "Kamizelka odłamkowa", "level": 13, "desc": "O 40% mniej obrażeń od wybuchów."},
	"scout": {"slot": "kit", "name": "Zwiadowca", "level": 17, "desc": "Strzelający wrogowie zostają na mapie 6 s zamiast 2,5 s."},
}


# ---------------------------------------------------------------- levels

## Experience needed to go from `level` to the next one.
static func xp_step(level: int) -> int:
	return 500 + 150 * (level - 1)


static func xp_total(level: int) -> int:
	var total := 0
	for l in range(1, level):
		total += xp_step(l)
	return total


static func level_of(xp: int) -> int:
	var level := 1
	var left := xp
	while level < MAX_LEVEL and left >= xp_step(level):
		left -= xp_step(level)
		level += 1
	return level


## Names of everything that becomes available at exactly this level.
static func unlocks_at(level: int) -> Array[String]:
	var out: Array[String] = []
	for w: int in WEAPON_LEVEL:
		if WEAPON_LEVEL[w] == level:
			out.append(String(C.WEAPONS[w]["name"]))
	for id: String in ATTACHMENTS:
		if ATTACHMENTS[id]["level"] == level:
			out.append(String(ATTACHMENTS[id]["name"]))
	for id: String in PERKS:
		if PERKS[id]["level"] == level:
			out.append(T.pack("Perk: %s", [PERKS[id]["name"]]))
	return out


static func weapon_level(w: int) -> int:
	return WEAPON_LEVEL.get(w, 1)


static func slots_for(w: int) -> Array:
	return WEAPON_SLOTS.get(w, [])


static func attachments_for(slot: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in ATTACHMENTS:
		if ATTACHMENTS[id]["slot"] == slot:
			out.append(id)
	return out


static func perks_for(slot: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in PERKS:
		if PERKS[id]["slot"] == slot:
			out.append(id)
	return out


# ---------------------------------------------------------------- kits

static func primaries(team: int, class_id: int) -> Array:
	return PRIMARIES_EMPIRE[class_id] if team == C.Team.EMPIRE else PRIMARIES[class_id]


static func default_kit(class_id: int, team := 0) -> Dictionary:
	return {"primary": primaries(team, class_id)[0], "sidearm": SIDEARMS[0], "parts_p": [], "parts_s": [], "perks": [], "ordnance": "grenades"}


## Rebuilds a kit, keeping only what this class and level really allow. The server runs
## this on whatever a client sends, so a tampered kit just falls back to legal gear.
static func sanitize(class_id: int, kit: Dictionary, level: int, team := 0) -> Dictionary:
	var out := default_kit(class_id, team)
	if class_id == 0 and str(kit.get("ordnance", "grenades")) == "rockets":
		out["ordnance"] = "rockets"
	var primary: int = int(kit.get("primary", -1))
	if primaries(team, class_id).has(primary) and weapon_level(primary) <= level:
		out["primary"] = primary
	var sidearm: int = int(kit.get("sidearm", -1))
	if SIDEARMS.has(sidearm) and weapon_level(sidearm) <= level:
		out["sidearm"] = sidearm
	out["parts_p"] = _legal_parts(out["primary"], kit.get("parts_p", []), level)
	out["parts_s"] = _legal_parts(out["sidearm"], kit.get("parts_s", []), level)
	var perks: Array[String] = []
	var used := {}
	var wanted: Variant = kit.get("perks", [])
	if wanted is Array:
		for p: Variant in wanted:
			var id := str(p)
			if PERKS.has(id) and PERKS[id]["level"] <= level and not used.has(PERKS[id]["slot"]):
				used[PERKS[id]["slot"]] = true
				perks.append(id)
	out["perks"] = perks
	return out


static func _legal_parts(weapon: int, wanted: Variant, level: int) -> Array[String]:
	var out: Array[String] = []
	if not wanted is Array:
		return out
	var allowed := slots_for(weapon)
	var used := {}
	for p: Variant in wanted:
		var id := str(p)
		if not ATTACHMENTS.has(id):
			continue
		var a: Dictionary = ATTACHMENTS[id]
		if a["level"] <= level and allowed.has(a["slot"]) and not used.has(a["slot"]):
			used[a["slot"]] = true
			out.append(id)
	return out


## The real stats of a weapon with these attachments and perks.
static func stats(weapon: int, parts: Array = [], perks: Array = []) -> Dictionary:
	var w: Dictionary = C.WEAPONS[weapon].duplicate()
	var kick: Dictionary = RECOIL.get(weapon, {"h": 0.5, "bias": 0.0, "rise": 0.02})
	w["recoil_h"] = kick["h"]
	w["recoil_bias"] = kick["bias"]
	w["recoil_rise"] = kick["rise"]
	w["ads_speed"] = 7.5
	w["scope"] = weapon in SCOPED_GUNS
	w["suppressed"] = weapon == C.W.SILENT
	for id: Variant in parts:
		if not ATTACHMENTS.has(str(id)):
			continue
		var a: Dictionary = ATTACHMENTS[str(id)]
		var mods: Dictionary = a["mods"]
		for key: String in mods:
			w[key] = float(w[key]) * float(mods[key])
		if a["slot"] == "optic":
			w["scope"] = false
		var fixed: Dictionary = a["set"]
		for key: String in fixed:
			w[key] = fixed[key]
	w["mag"] = int(round(float(w["mag"])))
	w["reserve"] = int(round(float(w["reserve"])))
	if perks.has("reflex"):
		w["ads_speed"] = float(w["ads_speed"]) * 1.3
	if perks.has("scavenger"):
		w["reserve"] = int(round(float(w["reserve"]) * 1.5))
	return w
