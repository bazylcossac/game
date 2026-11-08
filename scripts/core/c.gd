class_name C
extends RefCounted
## Game-wide constants and data tables. Pure data: safe to use on client and server.

const GAME_TITLE := "MIECZ DAWIDA"
const GAME_SUBTITLE := "LASEROWY FRONT"
const VERSION := "0.12.0"
const DEFAULT_PORT := 7777
const MAX_PLAYERS := 16
## Spare connections, so a full server can still answer the server lists asking about it.
const QUERY_SLOTS := 8
## What the server list shows. A server's own --name replaces "name" once it answers.
const SERVERS := [
	{"name": "Serwer główny", "address": "5.253.232.117", "port": DEFAULT_PORT},
]

enum Team { RESISTANCE = 0, EMPIRE = 1 }
const NEUTRAL := -1

const TEAM_NAMES := ["USA", "Żelazne Imperium"]
const TEAM_SHORT := ["USA", "IMPERIUM"]
const TEAM_COLORS := [Color(0.3, 0.68, 1.0), Color(1.0, 0.28, 0.2)]
const NEUTRAL_COLOR := Color(0.72, 0.72, 0.68)
## Beam colours are pushed above 1.0 so they bloom through the glow pass.
const TEAM_BEAM := [Color(0.16, 0.5, 3.0), Color(3.0, 0.1, 0.07)]

enum W { PISTOL, CARBINE, SNIPER, HEAVY, SWORD, SMG, ASSAULT, SCATTER, SILENT, MECH_GOLEM, MECH_GOLIAT, MECH_LAUNCHER, LIGHTSABER, TANK_CANNON, TANK_MG, REVOLVER, MPISTOL, SMG2, RIFLE, RAIL, GREATSWORD, AT_ROCKET, APC_NONE, MINIGUN }

const WEAPONS := {
	W.AT_ROCKET: {
		"name": "Wyrzutnia przeciwpancerna AT-43", "short": "RAKIETA AT", "melee": false, "auto": false,
		"damage": 150.0, "head_mult": 1.0, "rate": 1.0, "mag": 1, "reserve": 2, "reload": 2.6,
		"spread_hip": .6, "spread_ads": .15, "spread_move": 1.5, "recoil": 5.0, "range": 650.0,
		"falloff_start": 650.0, "falloff_min": 1.0, "ads_fov": .4, "sound": "tank_fire", "beam": .015,
		"move_mult": .8, "vs_armor": 1.0,
	},
	W.PISTOL: {
		"name": "Pistolet laserowy", "short": "PISTOLET", "melee": false, "auto": false,
		"damage": 28.0, "head_mult": 1.8, "rate": 0.17, "mag": 14, "reserve": 70, "reload": 1.5,
		"spread_hip": 1.4, "spread_ads": 0.3, "spread_move": 1.0, "recoil": 1.4, "range": 90.0,
		"falloff_start": 30.0, "falloff_min": 0.55, "ads_fov": 0.82, "sound": "laser_pistol", "beam": 0.034,
		"move_mult": 1.0,
	},
	W.CARBINE: {
		"name": "Karabinek laserowy", "short": "KARABINEK", "melee": false, "auto": true,
		"damage": 21.0, "head_mult": 1.8, "rate": 0.095, "mag": 32, "reserve": 160, "reload": 2.1,
		"spread_hip": 1.9, "spread_ads": 0.28, "spread_move": 1.3, "recoil": 0.85, "range": 140.0,
		"falloff_start": 45.0, "falloff_min": 0.6, "ads_fov": 0.72, "sound": "laser_rifle", "beam": 0.038,
		"move_mult": 0.97,
	},
	W.SNIPER: {
		"name": "Karabin promieniowy", "short": "PROMIENIOWY", "melee": false, "auto": false,
		"damage": 88.0, "head_mult": 2.5, "rate": 1.25, "mag": 5, "reserve": 30, "reload": 2.8,
		"spread_hip": 4.5, "spread_ads": 0.02, "spread_move": 2.4, "recoil": 4.2, "range": 320.0,
		"falloff_start": 300.0, "falloff_min": 1.0, "ads_fov": 0.3, "sound": "laser_sniper", "beam": 0.06,
		"move_mult": 0.94,
	},
	W.HEAVY: {
		"name": "Działko plazmowe", "short": "DZIAŁKO", "melee": false, "auto": true,
		"damage": 27.0, "head_mult": 1.5, "rate": 0.115, "mag": 60, "reserve": 180, "reload": 3.6,
		"spread_hip": 2.6, "spread_ads": 0.75, "spread_move": 1.7, "recoil": 2.1, "range": 120.0,
		"falloff_start": 40.0, "falloff_min": 0.6, "ads_fov": 0.8, "sound": "laser_plasma", "beam": 0.085,
		"move_mult": 0.88, "shake": 0.16,
	},
	W.MINIGUN: {
		"name": "Minigun laserowy", "short": "MINIGUN", "melee": false, "auto": true,
		"damage": 15.0, "head_mult": 1.4, "rate": 0.058, "mag": 150, "reserve": 300, "reload": 5.2,
		"spread_hip": 2.9, "spread_ads": 1.1, "spread_move": 1.9, "recoil": 0.75, "range": 105.0,
		"falloff_start": 35.0, "falloff_min": 0.55, "ads_fov": 1.0, "sound": "laser_minigun", "beam": 0.06,
		"move_mult": 0.82, "shake": 0.08, "spin": 0.55, "no_sights": true,
	},
	W.SWORD: {
		"name": "Miecz energetyczny", "short": "MIECZ", "melee": true, "auto": true,
		"damage": 62.0, "head_mult": 1.0, "rate": 0.55, "mag": 0, "reserve": 0, "reload": 0.0,
		"spread_hip": 0.0, "spread_ads": 0.0, "spread_move": 0.0, "recoil": 0.0, "range": 3.0,
		"falloff_start": 99.0, "falloff_min": 1.0, "ads_fov": 1.0, "sound": "sword_swing", "beam": 0.0,
		"move_mult": 1.08,
	},
	W.SMG: {
		"name": "Krótki karabinek", "short": "KRÓTKI", "melee": false, "auto": true,
		"damage": 15.0, "head_mult": 1.7, "rate": 0.08, "mag": 40, "reserve": 200, "reload": 1.9,
		"spread_hip": 2.2, "spread_ads": 0.5, "spread_move": 1.0, "recoil": 0.6, "range": 90.0,
		"falloff_start": 28.0, "falloff_min": 0.55, "ads_fov": 0.8, "sound": "laser_smg", "beam": 0.03,
		"move_mult": 1.02,
	},
	W.ASSAULT: {
		"name": "Karabin szturmowy", "short": "SZTURMOWY", "melee": false, "auto": true,
		"damage": 26.0, "head_mult": 1.8, "rate": 0.125, "mag": 28, "reserve": 140, "reload": 2.2,
		"spread_hip": 1.8, "spread_ads": 0.3, "spread_move": 1.3, "recoil": 1.0, "range": 150.0,
		"falloff_start": 50.0, "falloff_min": 0.6, "ads_fov": 0.7, "sound": "laser_assault", "beam": 0.04,
		"move_mult": 0.96,
	},
	W.SCATTER: {
		"name": "Rozpylacz wiązki", "short": "ROZPYLACZ", "melee": false, "auto": false, "pellets": 8,
		"damage": 11.0, "head_mult": 1.2, "rate": 0.85, "mag": 6, "reserve": 36, "reload": 2.6,
		"spread_hip": 5.5, "spread_ads": 4.0, "spread_move": 1.0, "recoil": 3.0, "range": 38.0,
		"falloff_start": 12.0, "falloff_min": 0.4, "ads_fov": 0.85, "sound": "laser_scatter", "beam": 0.028,
		"move_mult": 0.97,
	},
	W.SILENT: {
		"name": "Karabin tłumiony", "short": "TŁUMIONY", "melee": false, "auto": false,
		"damage": 38.0, "head_mult": 2.0, "rate": 0.42, "mag": 10, "reserve": 50, "reload": 2.0,
		"spread_hip": 1.2, "spread_ads": 0.1, "spread_move": 1.2, "recoil": 1.6, "range": 170.0,
		"falloff_start": 80.0, "falloff_min": 0.7, "ads_fov": 0.6, "sound": "laser_suppressed", "beam": 0.03,
		"move_mult": 1.0,
	},
	W.MECH_GOLEM: {
		"name": "Działo Atlasa", "short": "DZIAŁO", "melee": false, "auto": true,
		"damage": 24.0, "head_mult": 1.0, "rate": 0.15, "mag": 70, "reserve": 140, "reload": 3.2,
		"spread_hip": 1.6, "spread_ads": 0.8, "spread_move": 0.6, "recoil": 0.9, "range": 130.0,
		"falloff_start": 60.0, "falloff_min": 0.6, "ads_fov": 0.8, "sound": "mech_cannon", "beam": 0.075,
		"move_mult": 1.0, "vs_armor": 0.25,
	},
	W.MECH_GOLIAT: {
		"name": "Bliźniacze działa", "short": "DZIAŁA", "melee": false, "auto": true,
		"damage": 30.0, "head_mult": 1.0, "rate": 0.19, "mag": 50, "reserve": 100, "reload": 3.2,
		"spread_hip": 1.5, "spread_ads": 0.7, "spread_move": 0.6, "recoil": 1.0, "range": 130.0,
		"falloff_start": 60.0, "falloff_min": 0.6, "ads_fov": 0.8, "sound": "mech_cannon", "beam": 0.08,
		"move_mult": 1.0, "vs_armor": 0.25,
	},
	W.LIGHTSABER: {
		"name": "Miecz świetlny", "short": "MIECZ ŚWIETLNY", "melee": true, "auto": true,
		"damage": 80.0, "head_mult": 1.0, "rate": 0.5, "mag": 0, "reserve": 0, "reload": 0.0,
		"spread_hip": 0.0, "spread_ads": 0.0, "spread_move": 0.0, "recoil": 0.0, "range": 3.3,
		"falloff_start": 99.0, "falloff_min": 1.0, "ads_fov": 1.0, "sound": "sword_swing", "beam": 0.0,
		"move_mult": 1.1,
	},
	W.TANK_CANNON: {
		"name": "Działo laserowe", "short": "DZIAŁO", "melee": false, "auto": false,
		"damage": 90.0, "head_mult": 1.0, "rate": 1.7, "mag": 10, "reserve": 40, "reload": 3.5,
		"spread_hip": 0.25, "spread_ads": 0.08, "spread_move": 0.2, "recoil": 2.0, "range": 240.0,
		"falloff_start": 200.0, "falloff_min": 0.8, "ads_fov": 0.55, "sound": "tank_fire", "beam": 0.15,
		"move_mult": 1.0, "vs_armor": 1.0, "splash": 4.5, "splash_damage": 70.0,
	},
	W.TANK_MG: {
		"name": "Działko wieżowe", "short": "DZIAŁKO", "melee": false, "auto": true,
		"damage": 15.0, "head_mult": 1.2, "rate": 0.1, "mag": 120, "reserve": 480, "reload": 3.0,
		"spread_hip": 1.1, "spread_ads": 0.5, "spread_move": 0.5, "recoil": 0.3, "range": 130.0,
		"falloff_start": 50.0, "falloff_min": 0.6, "ads_fov": 0.7, "sound": "laser_heavy", "beam": 0.045,
		"move_mult": 1.0, "vs_armor": 0.04,
	},
	W.REVOLVER: {
		"name": "Rewolwer promieniowy", "short": "REWOLWER", "melee": false, "auto": false,
		"damage": 48.0, "head_mult": 2.0, "rate": 0.5, "mag": 6, "reserve": 36, "reload": 2.2,
		"spread_hip": 1.6, "spread_ads": 0.2, "spread_move": 1.1, "recoil": 3.0, "range": 110.0,
		"falloff_start": 40.0, "falloff_min": 0.6, "ads_fov": 0.8, "sound": "laser_revolver", "beam": 0.04,
		"move_mult": 1.0,
	},
	W.MPISTOL: {
		"name": "Pistolet maszynowy", "short": "MASZYNOWY", "melee": false, "auto": true,
		"damage": 14.0, "head_mult": 1.6, "rate": 0.07, "mag": 24, "reserve": 120, "reload": 1.7,
		"spread_hip": 2.4, "spread_ads": 0.9, "spread_move": 1.0, "recoil": 0.8, "range": 70.0,
		"falloff_start": 20.0, "falloff_min": 0.5, "ads_fov": 0.85, "sound": "laser_smg", "beam": 0.03,
		"move_mult": 1.0,
	},
	W.SMG2: {
		"name": "Karabinek bojowy", "short": "BOJOWY", "melee": false, "auto": true,
		"damage": 19.0, "head_mult": 1.7, "rate": 0.1, "mag": 34, "reserve": 170, "reload": 2.0,
		"spread_hip": 2.0, "spread_ads": 0.45, "spread_move": 1.1, "recoil": 0.75, "range": 100.0,
		"falloff_start": 34.0, "falloff_min": 0.55, "ads_fov": 0.78, "sound": "laser_assault", "beam": 0.032,
		"move_mult": 1.0,
	},
	W.RIFLE: {
		"name": "Karabin samopowtarzalny", "short": "SAMOPOWTARZALNY", "melee": false, "auto": false,
		"damage": 44.0, "head_mult": 2.0, "rate": 0.26, "mag": 16, "reserve": 80, "reload": 2.3,
		"spread_hip": 2.2, "spread_ads": 0.14, "spread_move": 1.4, "recoil": 1.9, "range": 190.0,
		"falloff_start": 70.0, "falloff_min": 0.7, "ads_fov": 0.66, "sound": "laser_marksman", "beam": 0.042,
		"move_mult": 0.96,
	},
	W.RAIL: {
		"name": "Działo szynowe", "short": "SZYNOWE", "melee": false, "auto": false,
		"damage": 130.0, "head_mult": 2.0, "rate": 2.2, "mag": 3, "reserve": 18, "reload": 3.4,
		"spread_hip": 5.0, "spread_ads": 0.01, "spread_move": 2.6, "recoil": 5.5, "range": 360.0,
		"falloff_start": 340.0, "falloff_min": 1.0, "ads_fov": 0.26, "sound": "laser_rail", "beam": 0.075,
		"move_mult": 0.9,
	},
	W.GREATSWORD: {
		"name": "Wielki miecz", "short": "WIELKI MIECZ", "melee": true, "auto": true,
		"damage": 105.0, "head_mult": 1.0, "rate": 0.85, "mag": 0, "reserve": 0, "reload": 0.0,
		"spread_hip": 0.0, "spread_ads": 0.0, "spread_move": 0.0, "recoil": 0.0, "range": 3.7,
		"falloff_start": 99.0, "falloff_min": 1.0, "ads_fov": 1.0, "sound": "sword_swing", "beam": 0.0,
		"move_mult": 0.98,
	},
	W.APC_NONE: {
		"name": "Brak uzbrojenia", "short": "BRAK", "melee": false, "auto": false,
		"damage": 0.0, "head_mult": 1.0, "rate": 1.0, "mag": 0, "reserve": 0, "reload": 1.0,
		"spread_hip": 0.0, "spread_ads": 0.0, "spread_move": 0.0, "recoil": 0.0, "range": 1.0,
		"falloff_start": 1.0, "falloff_min": 1.0, "ads_fov": 1.0, "sound": "empty_click", "beam": 0.0,
		"move_mult": 1.0,
	},
	W.MECH_LAUNCHER: {
		"name": "Granatnik mecha", "short": "GRANATNIK", "melee": false, "auto": false,
		"damage": 60.0, "head_mult": 1.0, "rate": 0.85, "mag": 3, "reserve": 6, "reload": 2.8,
		"spread_hip": 0.5, "spread_ads": 0.25, "spread_move": 0.5, "recoil": 3.2, "range": 400.0,
		"falloff_start": 400.0, "falloff_min": 1.0, "ads_fov": 0.8, "sound": "mech_launcher", "beam": 0.02,
		"move_mult": 1.0, "vs_armor": 1.0, "shake": 0.3,
	},
}

## Indexed by team, then class. Ids below NORMAL_CLASSES are picked when deploying.
## SUPER_MECH and SUPER_SPECIAL are unlocked in the field with a coin. A loadout is
## primary, sidearm, melee; mechs have only two slots.
const NORMAL_CLASSES := 6
## Only a squad leader deploys as this class, and a squad leader can deploy as nothing else.
const COMMAND_CLASS := 4
const SUPER_MECH := 6
const SUPER_SPECIAL := 7
const VEHICLE_CLASS := 8
const APC_CLASS := 9
## Passengers a troop carrier takes, besides the driver.
const APC_SEATS := 6
## Passengers a tank carries, on top of the driver and the gunner.
const TANK_RIDERS := 2
## In place of a flag number when deploying: come in at the squad's beacon.
const SPAWN_BEACON := -2
## Extra loudness of the shots that should hit hardest, in decibels.
const SHOT_BOOST := {"laser_plasma": 3.0, "laser_sniper": 2.5, "laser_minigun": 2.0, "laser_rail": 2.0}

const CLASSES := [
	[
		{
			"id": "fighter", "name": "Szturmowiec", "hp": 100.0, "speed": 1.0, "grenades": 3, "smoke": 1,
			"weapons": [W.CARBINE, W.PISTOL, W.LIGHTSABER], "sword_mult": 1.0,
			"desc": "Trzon armii USA. Karabinek laserowy, trzy granaty i niebieski miecz świetlny.",
			"stats": [0.75, 0.6, 0.6],
		},
		{
			"id": "medic", "name": "Sanitariusz", "hp": 95.0, "speed": 1.05, "grenades": 1, "smoke": 2, "healer": true,
			"weapons": [W.SMG, W.PISTOL, W.SWORD], "sword_mult": 1.0,
			"desc": "Leczy wszystkich sojuszników w pobliżu, także siebie. Trzymaj się oddziału.",
			"stats": [0.5, 0.75, 0.7],
		},
		{
			"id": "sniper", "name": "Strzelec wyborowy", "hp": 90.0, "speed": 1.02, "grenades": 1, "smoke": 1,
			"weapons": [W.SNIPER, W.PISTOL, W.SWORD], "sword_mult": 1.0,
			"desc": "Karabin promieniowy z lunetą. Jeden celny strzał w głowę kończy walkę.",
			"stats": [1.0, 0.5, 0.65],
		},
		{
			"id": "engineer", "name": "Inżynier", "hp": 110.0, "speed": 1.0, "grenades": 1, "fire": 2, "builder": true,
			"weapons": [W.SCATTER, W.PISTOL, W.SWORD], "sword_mult": 1.0,
			"desc": "Strzelba i fortyfikacje na własnych flagach. V wybiera budowlę, T rozpoczyna budowę.",
			"stats": [0.8, 0.65, 0.65],
		},
		{
			"id": "commander", "name": "Dowódca oddziału", "hp": 110.0, "speed": 1.0, "grenades": 1, "smoke": 2, "command": true,
			"weapons": [W.CARBINE, W.PISTOL, W.SWORD], "sword_mult": 1.0,
			"desc": "Klasa lidera oddziału. Karabinek, lornetka, radiostacja, jeden granat i dwa dymne na osłonę oddziału. Z wzywa artylerię, T stawia punkt odrodzenia.",
			"stats": [0.7, 0.7, 0.65],
		},
		{
			"id": "gunner", "name": "Strzelec ciężki", "hp": 135.0, "speed": 0.84, "grenades": 1, "smoke": 1,
			"weapons": [W.MINIGUN, W.PISTOL, W.SWORD], "sword_mult": 1.0,
			"desc": "Minigun zalewa ulicę ogniem, ale lufy muszą się najpierw rozkręcić. Wolny i wytrzymały.",
			"stats": [0.7, 1.0, 0.35],
		},
		{
			"id": "golem", "name": "Atlas", "hp": 480.0, "speed": 0.68, "grenades": 0, "duration": 75.0,
			"mech": true, "height": 3.4, "eye": 3.05, "radius": 0.62, "no_headshot": true, "no_sprint": true,
			"no_jump": true, "no_crouch": true, "melee_vuln": 1.5,
			"weapons": [W.MECH_GOLEM, W.MECH_LAUNCHER], "sword_mult": 1.0,
			"desc": "Mech z brązu i gliny. Ogromna wytrzymałość, ale jest powolny, nie wejdzie do budynków, a miecze ranią go mocniej.",
			"stats": [0.8, 1.0, 0.2],
		},
		{
			"id": "maccabee", "name": "Ranger", "hp": 130.0, "speed": 1.15, "grenades": 1, "duration": 90.0,
			"jetpack": true, "melee_first": true,
			"weapons": [W.SWORD, W.PISTOL, W.SWORD], "sword_mult": 1.4,
			"desc": "Plecak odrzutowy i miecz. Przytrzymaj spację, aby lecieć. Spada z nieba na wroga, ale paliwo szybko się kończy.",
			"stats": [0.75, 0.7, 1.0],
		},
		{
			"id": "lion", "name": "Patriot", "hp": 800.0, "speed": 1.0, "grenades": 0, "vehicle": true,
			"height": 3.0, "eye": 2.9, "radius": 1.5, "no_headshot": true, "no_sprint": true, "no_jump": true,
			"no_crouch": true, "melee_vuln": 0.8, "hit_box": Vector3(1.9, 1.15, 3.55),
			"weapons": [W.TANK_CANNON, W.TANK_MG], "sword_mult": 1.0,
			"desc": "Czołg antygrawitacyjny armii USA.",
			"stats": [1.0, 1.0, 0.6],
		},
		{
			"id": "carrier", "name": "Transporter", "hp": 650.0, "speed": 1.3, "grenades": 0, "vehicle": true, "apc": true,
			"height": 3.0, "eye": 2.9, "radius": 1.4, "no_headshot": true, "no_sprint": true, "no_jump": true,
			"no_crouch": true, "melee_vuln": 0.8, "hit_box": Vector3(1.75, 1.2, 3.15),
			"weapons": [W.APC_NONE], "sword_mult": 1.0,
			"desc": "Opancerzony transporter: kierowca i czterech żołnierzy. Nie ma działa.",
			"stats": [0.0, 0.8, 0.8],
		},
	],
	[
		{
			"id": "grenadier", "name": "Droid liniowy", "frame": "Reg", "hp": 100.0, "speed": 1.0, "grenades": 2, "smoke": 1, "fire": 1,
			"weapons": [W.ASSAULT, W.PISTOL, W.LIGHTSABER], "sword_mult": 1.0,
			"desc": "Podstawa armii maszyn: smukły szkielet z siłownikami, karabin szturmowy i czerwony miecz świetlny.",
			"stats": [0.8, 0.6, 0.6],
		},
		{
			"id": "hunter", "name": "Droid strzelec", "frame": "Reg", "hp": 90.0, "speed": 1.02, "grenades": 1, "smoke": 1,
			"weapons": [W.SNIPER, W.PISTOL, W.SWORD], "sword_mult": 1.0,
			"desc": "Droid z masztem sensorów i karabinem promieniowym. Niszczy z dużej odległości.",
			"stats": [1.0, 0.5, 0.65],
		},
		{
			"id": "heavy", "name": "Droid ciężki", "frame": "Big", "hp": 130.0, "speed": 0.9, "grenades": 2, "fire": 1,
			"weapons": [W.HEAVY, W.PISTOL, W.SWORD], "sword_mult": 1.0,
			"desc": "Wielka pancerna maszyna. Wolniejsza, ale działko plazmowe zalewa ulice ogniem zaporowym.",
			"stats": [0.65, 1.0, 0.4],
		},
		{
			"id": "sapper", "name": "Droid komando", "frame": "Cmd", "hp": 110.0, "speed": 1.0, "grenades": 3, "fire": 2,
			"weapons": [W.SCATTER, W.PISTOL, W.SWORD], "sword_mult": 1.0,
			"desc": "Gładka, ciemna maszyna do walki w budynkach. Rozpylacz wiązki, granaty i ogień czyszczą pomieszczenia.",
			"stats": [0.85, 0.7, 0.5],
		},
		{
			"id": "marshal", "name": "Droid dowódca", "frame": "Reg", "hp": 110.0, "speed": 1.0, "grenades": 1, "smoke": 2, "command": true,
			"weapons": [W.ASSAULT, W.PISTOL, W.LIGHTSABER], "sword_mult": 1.0,
			"desc": "Klasa lidera oddziału, z anteną i grzebieniem na głowie. Z wzywa artylerię, T stawia punkt odrodzenia.",
			"stats": [0.7, 0.7, 0.65],
		},
		{
			"id": "droid_engineer", "name": "Droid inżynier", "frame": "Reg", "hp": 110.0, "speed": 1.0, "grenades": 1, "fire": 2, "builder": true,
			"weapons": [W.SCATTER, W.PISTOL, W.SWORD], "sword_mult": 1.0,
			"desc": "Maszyna budowlana Imperium. Stawia fortyfikacje i walczy rozpylaczem wiązki z bliska.",
			"stats": [0.8, 0.65, 0.5],
		},
		{
			"id": "goliat", "name": "Goliat", "hp": 430.0, "speed": 0.72, "grenades": 0, "duration": 75.0,
			"mech": true, "height": 3.4, "eye": 3.05, "radius": 0.62, "no_headshot": true, "no_sprint": true,
			"no_jump": true, "no_crouch": true, "melee_vuln": 1.5,
			"weapons": [W.MECH_GOLIAT, W.MECH_LAUNCHER], "sword_mult": 1.0,
			"desc": "Czarny stalowy kolos z bliźniaczymi działami. Mniej pancerza niż Atlas, więcej ognia.",
			"stats": [0.9, 0.9, 0.25],
		},
		{
			"id": "phantom", "name": "Widmo", "frame": "Cmd", "hp": 100.0, "speed": 1.1, "grenades": 1, "smoke": 1, "duration": 90.0,
			"cloak": true,
			"weapons": [W.SILENT, W.PISTOL, W.SWORD], "sword_mult": 1.2,
			"desc": "Maskowanie optyczne: niemal niewidoczne, dopóki nie strzeli lub nie oberwie.",
			"stats": [0.8, 0.6, 0.8],
		},
		{
			"id": "wolf", "name": "Wilk", "hp": 800.0, "speed": 1.0, "grenades": 0, "vehicle": true,
			"height": 3.0, "eye": 2.9, "radius": 1.5, "no_headshot": true, "no_sprint": true, "no_jump": true,
			"no_crouch": true, "melee_vuln": 0.8, "hit_box": Vector3(1.9, 1.15, 3.55),
			"weapons": [W.TANK_CANNON, W.TANK_MG], "sword_mult": 1.0,
			"desc": "Czołg antygrawitacyjny Imperium.",
			"stats": [1.0, 1.0, 0.6],
		},
		{
			"id": "carrier", "name": "Transporter", "hp": 650.0, "speed": 1.3, "grenades": 0, "vehicle": true, "apc": true,
			"height": 3.0, "eye": 2.9, "radius": 1.4, "no_headshot": true, "no_sprint": true, "no_jump": true,
			"no_crouch": true, "melee_vuln": 0.8, "hit_box": Vector3(1.75, 1.2, 3.15),
			"weapons": [W.APC_NONE], "sword_mult": 1.0,
			"desc": "Opancerzony transporter: kierowca i czterech żołnierzy. Nie ma działa.",
			"stats": [0.0, 0.8, 0.8],
		},
	],
]
const CLASS_STAT_LABELS := ["Siła ognia", "Wytrzymałość", "Mobilność"]

# Movement
const WALK_SPEED := 5.4
const SPRINT_SPEED := 8.0
const CROUCH_SPEED := 2.8
const PRONE_SPEED := 1.4
const ADS_SPEED_MULT := 0.62
const GRAVITY := 21.0
const JUMP_VELOCITY := 7.2
const GROUND_ACCEL := 52.0
const AIR_ACCEL := 9.0
const STAMINA_MAX := 7.0
## Run dry and the legs need this share of the stamina back before they sprint again.
const STAMINA_RECOVER := 0.3
## Seconds of holding still beside a vehicle to get in, or inside it to get out.
const USE_TIME := 2.0
## A side's home: nobody standing in it can be hurt, soldiers or vehicles. Flag modes only.
## The radius grows to take in the side's own tank park, up to the larger number.
const SAFE_ZONE_MIN := 32.0
const SAFE_ZONE_MAX := 62.0
const STAND_EYE := 1.62
const CROUCH_EYE := 1.0
const PRONE_EYE := 0.42
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.2
const PRONE_HEIGHT := 0.8
const BODY_RADIUS := 0.36
const HEAD_RADIUS := 0.17

# Combat
const REGEN_DELAY := 7.0
const REGEN_DELAY_PERK := 4.0
const WIN_XP := 500
const LOSS_XP := 150
const REGEN_RATE := 14.0
const RESPAWN_DELAY := 5.0
const SPAWN_PROTECTION := 2.5
const GRENADE_FUSE := 2.6
## The three kinds, in the order H cycles through them.
const NADE_FRAG := 0
const NADE_SMOKE := 1
const NADE_FIRE := 2
const NADE_NAMES := ["ODŁAMKOWY", "DYMNY", "ZAPALAJĄCY"]
const SMOKE_FUSE := 1.5
const SMOKE_SECONDS := 15.0
const SMOKE_RADIUS := 6.5
## Goes off on first contact. The fuse only matters if it never touches anything.
const FIRE_FUSE := 2.2
const FIRE_SECONDS := 8.0
const FIRE_RADIUS := 4.5
const FIRE_DPS := 30.0
const FIRE_TICK := 0.5
const FIRE_VS_ARMOR := 0.15
## The server allows this much reload left, since a client's clock can run a little ahead.
const RELOAD_THROW_SLACK := 0.25
const GRENADE_RADIUS := 8.5
const GRENADE_DAMAGE := 125.0
const BLOCK_DAMAGE_MULT := 0.08
const BLOCK_DRAIN_PER_HIT := 0.6

# Coins: rare field pickups that unlock a super class.
const COIN_FIRST_DELAY := 50.0
const COIN_INTERVAL_MIN := 80.0
const COIN_INTERVAL_MAX := 130.0
const COIN_MAX_ON_MAP := 2
const COIN_LIFETIME := 120.0
const COIN_DROP_LIFETIME := 40.0
const COIN_PICKUP_RADIUS := 1.9

# Abilities
const HEAL_RADIUS := 9.0
const HEAL_RATE := 6.0
const SCORE_HEAL_PER_50 := 25
const JET_FUEL := 3.5
const JET_RISE_SPEED := 7.0
const CLOAK_BREAK_TIME := 2.0
const CLOAK_SIGHT_RANGE := 14.0
const SUPER_END_HP_FRACTION := 0.6

# Vehicles
# Artillery. A strike needs a full charge and the gaps below, and everyone gets the warning.
const STRIKE_CHARGE_SECONDS := 150.0
const STRIKE_MEMBER_BONUS := 0.25
const STRIKE_KILL_CHARGE := 8.0
const STRIKE_CAPTURE_CHARGE := 15.0
const STRIKE_FIRST_DELAY := 60.0
const STRIKE_COOLDOWN := 75.0
const STRIKE_RANGE := 280.0
const STRIKE_MIN_RANGE := 20.0
const STRIKE_BASE_SAFE := 55.0
const STRIKE_WARNING := 6.0
const STRIKE_SHELLS := 6
const STRIKE_INTERVAL := 0.6
const STRIKE_SCATTER := 12.0
const SHELL_RADIUS := 6.0
const SHELL_DAMAGE := 90.0

# The squad's spawn beacon.
const BEACON_HP := 150.0
const BEACON_BASE_SAFE := 60.0
const BEACON_FLAG_SAFE := 22.0
const BEACON_CONTEST := 12.0
const BEACON_LOST_DELAY := 45.0
const BEACON_REPLACE_DELAY := 20.0
const BEACON_SPAWN_GAP := 10.0
const BEACON_BOT_RANGE := 26.0
const SCORE_BEACON := 40

const TANK_SPEED := 10.5
const TANK_REVERSE_MULT := 0.55
const TANK_ACCEL := 9.0
const TANK_TURN_RATE := 1.25
const TANK_RESPAWN := 60.0
const TANK_ENTER_RANGE := 6.5
## The roof gun's elevation limits, and the height of its pivot above the ground.
const TANK_GUNNER_PITCH_MIN := -0.4
const TANK_GUNNER_PITCH_MAX := 0.7
const TANK_GUNNER_EYE := 2.86
## The driver's second weapon is that same roof gun, while nobody else is sitting at it.
const TANK_ROOF_SLOT := 1
## How a tank's 800 points go: six rockets, or sixteen grenades on the hull, or two thousand rounds
## of rifle fire. Weapons can override the small arms figure with "vs_armor".
const ARMOR_DEFAULT := 0.02
const MELEE_VS_ARMOR := 0.05
const GRENADE_VS_ARMOR := 0.4
const BOT_TANK_WAIT := 25.0

# Conquest
const START_TICKETS := 350
const FLAG_RADIUS := 15.0
const CAPTURE_TIME := 11.0
const BLEED_MAJORITY := 6.0
const BLEED_DOMINANT := 2.5

const WEAPON_FIRE := -3
## Not a weapon: the player gave up this life from the pause menu.
const WEAPON_RESPAWN := -4
## Not a weapon: the admin panel took the life.
const WEAPON_ADMIN := -5

# Score
const SCORE_KILL := 100
const SCORE_HEADSHOT := 25
const SCORE_CAPTURE := 200
const SCORE_ASSIST := 40

# Physics layers
const LAYER_WORLD := 1
const LAYER_SOLDIER := 2
const LAYER_VEHICLE := 4
const LAYER_FORT := 8

# Snapshot flag bits
const F_ALIVE := 1
const F_CROUCH := 2
const F_SPRINT := 4
const F_ADS := 8
const F_BLOCK := 16
const F_RELOAD := 32
const F_PROTECTED := 64
const F_CLOAK := 128
## Does not fit in the snapshot's flag byte, so it travels in the top bit of the slot byte.
const F_PRONE := 256
const SLOT_PRONE := 128

const BOT_NAMES_RESISTANCE := [
	"Miller", "Carter", "Walker", "Reed", "Hayes", "Brooks", "Cole", "Parker", "Ross", "Turner",
	"Bennett", "Hughes", "Sanders", "Murphy", "Foster", "Mason",
]
const BOT_NAMES_EMPIRE := [
	"ZI-117", "ZI-204", "ZI-318", "ZI-402", "ZI-566", "ZI-631", "ZI-709", "ZI-823", "ZI-914", "ZI-1022",
	"ZI-1147", "ZI-1260", "ZI-1385", "ZI-1433", "ZI-1579", "ZI-1604",
]

const DIFFICULTIES := [
	{"name": "Rekrut", "reaction": 0.75, "aim_error": 3.8, "burst_pause": 0.75, "turn": 3.5},
	{"name": "Weteran", "reaction": 0.45, "aim_error": 2.3, "burst_pause": 0.5, "turn": 5.0},
	{"name": "Elita", "reaction": 0.25, "aim_error": 1.2, "burst_pause": 0.3, "turn": 7.5},
]


static func cls(team: int, class_id: int) -> Dictionary:
	return CLASSES[team][class_id]


static func is_blade(weapon_id: int) -> bool:
	return weapon_id == W.SWORD or weapon_id == W.LIGHTSABER or weapon_id == W.GREATSWORD


static func class_name_for(team: int, class_id: int) -> String:
	return T.t(String(CLASSES[team][class_id]["name"]))


static func team_color(team: int) -> Color:
	return NEUTRAL_COLOR if team < 0 else TEAM_COLORS[team]
