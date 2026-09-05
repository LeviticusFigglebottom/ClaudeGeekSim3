class_name AreaRegistry
## The registry of every area (realm) in the game.
##
## Each entry maps an area id to its scene, display name, environment preset
## ("realm") and ambience track. The headless verifier (tools/verify.gd) reads
## this table to load every area and check the world graph, so keep it the
## single source of truth. Add a new area here and the verifier will start
## checking it.

const AREAS := {
	"apartment": {
		"scene": "res://src/areas/apartment/apartment.tscn",
		"name": "Flat 5½", "subtitle": "the Halden Arms, third floor",
		"realm": "waking", "ambience": "apartment",
	},
	"corridor": {
		"scene": "res://src/areas/corridor/corridor.tscn",
		"name": "The Halden Arms", "subtitle": "a corridor that keeps its own hours",
		"realm": "corridor", "ambience": "corridor",
	},
	"hallway": {
		"scene": "res://src/areas/hallway/hallway.tscn",
		"name": "The Hallway", "subtitle": "it was not there yesterday",
		"realm": "hallway", "ambience": "hallway",
	},
	"nexus": {
		"scene": "res://src/areas/nexus/nexus.tscn",
		"name": "The Anteroom", "subtitle": "you are early. wait here.",
		"realm": "nexus", "ambience": "nexus",
	},
	"forest": {
		"scene": "res://src/areas/forest/forest.tscn",
		"name": "The Hollow Wood", "subtitle": "where the drowned god dreams of trees",
		"realm": "forest", "ambience": "forest",
	},
	"city": {
		"scene": "res://src/areas/city/city.tscn",
		"name": "The Drowned City", "subtitle": "it forgot its name before you arrived",
		"realm": "city", "ambience": "city",
	},
	"tavern": {
		"scene": "res://src/areas/tavern/tavern.tscn",
		"name": "The Last Lamp", "subtitle": "at the end of every road",
		"realm": "tavern", "ambience": "tavern",
	},
	"house": {
		"scene": "res://src/areas/house/house.tscn",
		"name": "The Nowhere House", "subtitle": "a home in a field with no road",
		"realm": "house", "ambience": "house",
	},
	"castle": {
		"scene": "res://src/areas/castle/castle.tscn",
		"name": "The Keep of Hours", "subtitle": "the king is asleep. do not wake him.",
		"realm": "castle", "ambience": "castle",
	},
	"sea": {
		"scene": "res://src/areas/sea/sea.tscn",
		"name": "The Slow Sea", "subtitle": "a tide that takes a hundred years",
		"realm": "sea", "ambience": "sea",
	},
	"catacombs": {
		"scene": "res://src/areas/catacombs/catacombs.tscn",
		"name": "The Ossuary", "subtitle": "everyone is here. nobody is home.",
		"realm": "catacombs", "ambience": "catacombs",
	},
	"furnace": {
		"scene": "res://src/areas/furnace/furnace.tscn",
		"name": "The Furnace", "subtitle": "below the below",
		"realm": "furnace", "ambience": "furnace",
	},
	"cistern": {
		"scene": "res://src/areas/cistern/cistern.tscn",
		"name": "The Cistern", "subtitle": "the bathhouse of a god who never came back",
		"realm": "cistern", "ambience": "cistern",
	},
	"offices": {
		"scene": "res://src/areas/offices/offices.tscn",
		"name": "The Waiting Halls", "subtitle": "please take a number",
		"realm": "offices", "ambience": "offices",
	},
	"clocktower": {
		"scene": "res://src/areas/clocktower/clocktower.tscn",
		"name": "The Clocktower", "subtitle": "every hour is the same hour",
		"realm": "clocktower", "ambience": "clocktower",
	},
	"static": {
		"scene": "res://src/areas/static/static.tscn",
		"name": "The Static", "subtitle": "between channels",
		"realm": "static", "ambience": "static",
	},
	"workshop": {
		"scene": "res://src/areas/workshop/workshop.tscn",
		"name": "The Workshop", "subtitle": "where the props are kept",
		"realm": "city", "ambience": "offices", "hidden": true,
	},
	"mirror_nexus": {
		"scene": "res://src/areas/mirror_nexus/mirror_nexus.tscn",
		"name": "The Other Anteroom", "subtitle": ".ereh tiaw .etal era uoy",
		"realm": "mirror", "ambience": "mirror",
	},
	"kings_dream": {
		"scene": "res://src/areas/kings_dream/kings_dream.tscn",
		"name": "The King's Dream", "subtitle": "he is dreaming about you",
		"realm": "kings_dream", "ambience": "sea",
	},
	"promotion": {
		"scene": "res://src/areas/promotion/promotion.tscn",
		"name": "The Last Rank", "subtitle": "a pawn that gets there is whatever it is told",
		"realm": "promotion", "ambience": "hallway",
	},
	"static_end": {
		"scene": "res://src/areas/static_end/static_end.tscn",
		"name": "Off Air", "subtitle": "the set turned off",
		"realm": "static", "ambience": "static",
	},
	"pipes": {
		"scene": "res://src/areas/pipes/pipes.tscn",
		"name": "The Waterworks", "subtitle": "where the water went",
		"realm": "pipes", "ambience": "cistern",
	},
	"hospital": {
		"scene": "res://src/areas/hospital/hospital.tscn",
		"name": "St. Nowhere", "subtitle": "visiting hours are over",
		"realm": "hospital", "ambience": "offices",
	},
	"kings_mind": {
		"scene": "res://src/areas/kings_mind/kings_mind.tscn",
		"name": "The King's Mind", "subtitle": "everything he has been told",
		"realm": "kings_mind", "ambience": "cistern",
	},
}

## Areas the player can reach without any keepsake, straight from the first sleep.
const STARTING_AREA := "apartment"
const STARTING_SPAWN := "bed"

static func ids() -> Array:
	return AREAS.keys()

static func has(id: String) -> bool:
	return AREAS.has(id)

static func info(id: String) -> Dictionary:
	return AREAS.get(id, {})
