extends Node

var text_speed = 0.01

var current_room = null
var player_position = null
var player_name = "anon"
var party = []

func _ready():
	party.append(StaticData.generate_monster("Anu", 28))
	party.append(StaticData.generate_monster("Baobaraffe", 12))
