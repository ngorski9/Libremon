tool
extends Node2D

export(String) var start_room = ""
export(Vector2) var player_spawn_position = Vector2(0,0) setget setPlayerSpawn

export(bool) var preview = false setget setPreview

var game_start = true

var current_room = null
var loaded_rooms = []

var player = null

func _ready():

	if not Engine.editor_hint:
		player = $Player

		# load the current room from file
		if game_start:
			current_room = getRoomInstance(start_room)
			PlayerData.current_room = start_room
			PlayerData.player_position = player_spawn_position
		else:
			current_room = getRoomInstance(PlayerData.current_room)
		add_child(current_room)

		# load the bordering rooms
		var first_layer = get_bordering_rooms(current_room)
		for r in first_layer:
			loaded_rooms += get_bordering_rooms(r)
		loaded_rooms += first_layer
		loaded_rooms.append(current_room)

		# add the player
		if game_start:
			player.position = player_spawn_position * 32 + Vector2(16,16)
		else:
			player.position = PlayerData.player_position * 32 + Vector2(16,16)
		move_child(player, get_child_count() - 1)

func _process(_delta):
	if player:
		get_viewport().canvas_transform.origin = Vector2(-player.position.x + 240 ,-player.position.y + 160)

func _on_Player_done_walking():
	var new_room = null

	if player.position.y < current_room.position.y:
		new_room = get_node(current_room.upBorder)
	elif player.position.y > current_room.position.y + current_room.map_height * 32:
		new_room = get_node(current_room.downBorder)
	elif player.position.x < current_room.position.x:
		new_room = get_node(current_room.leftBorder)
	elif player.position.x > current_room.position.x + current_room.map_width * 32:
		new_room = get_node(current_room.rightBorder)

	if new_room:
		var new_rooms = []
		var bordersNewRoom = get_bordering_rooms(new_room)
		for r in bordersNewRoom:
			new_rooms += get_bordering_rooms(r)
		new_rooms += bordersNewRoom
		new_rooms.append(new_room)
		
		for r in loaded_rooms:
			if not r in new_rooms:
				r.queue_free()

		current_room = new_room
		loaded_rooms = new_rooms
		
# gets an instance of the room with name "name"
# also, sets roomIsEditing to false
func getRoomInstance(name):
	var room_file = File.new()
	if room_file.file_exists("res://scenes/levels/" + name + ".tscn"):
		var instance = load("res://scenes/levels/" + name + ".tscn").instance()
		instance.roomIsEditing = false
		return instance
	return null

# For the room passed in as a parameter, adds all bordering rooms to the
# scene tree that have not already been added, then returns a list of
# references to all rooms that border the inputed room
func get_bordering_rooms(room):
	var added_rooms = []
	if room.upBorder != "":
		var upRoom = get_node_or_null(room.upBorder)
		if upRoom:
			added_rooms.append(upRoom)
		else:
			upRoom = getRoomInstance(room.upBorder)
			upRoom.position = Vector2(room.position.x + room.upOffset * 32, room.position.y - upRoom.map_height * 32)
			upRoom.name = room.upBorder
			# adds the new room below the old one.
			# this prevents the room from being on top of the player
			add_child_below_node(room, upRoom)
			added_rooms.append(upRoom)
	if room.leftBorder != "":
		var leftRoom = get_node_or_null(room.leftBorder)
		if leftRoom:
			added_rooms.append(leftRoom)
		else:
			leftRoom = getRoomInstance(room.leftBorder)
			leftRoom.position = Vector2(room.position.x - leftRoom.map_width * 32, room.position.y + room.leftOffset * 32)
			leftRoom.name = room.leftBorder
			add_child_below_node(room, leftRoom)
			added_rooms.append(leftRoom)
	if room.downBorder != "":
		var downRoom = get_node_or_null(room.downBorder)
		if downRoom:
			added_rooms.append(downRoom)
		else:
			downRoom = getRoomInstance(room.downBorder)
			downRoom.position = Vector2(room.position.x + room.downOffset * 32, room.position.y + room.map_height * 32)
			downRoom.name = room.downBorder
			add_child_below_node(room, downRoom)
			added_rooms.append(downRoom)
	if room.rightBorder != "":
		var rightRoom = get_node_or_null(room.rightBorder)
		if rightRoom:
			added_rooms.append(rightRoom)
		else:
			rightRoom = getRoomInstance(room.rightBorder)
			rightRoom.position = Vector2(room.position.x + room.map_width * 32, room.position.y + room.rightOffset * 32)
			rightRoom.name = room.rightBorder
			add_child_below_node(room, rightRoom)
			added_rooms.append(rightRoom)

	return added_rooms

func preview_level():
	var old_instance = get_node_or_null("start_room")
	if old_instance:
		old_instance.name = "start_room_delete"
		old_instance.queue_free()

	var instance = getRoomInstance(start_room)
	if instance:
		instance.name = "start_room"
		add_child(instance)
	
	var old_test_player = get_node_or_null("test_player")
	if old_test_player:
		old_test_player.name = "test_player_delete"
		old_test_player.queue_free()
	
	var test_player = load("res://scenes/overworld/player.tscn").instance()
	if test_player:
		test_player.name = "test_player"
		test_player.position = 32 * player_spawn_position + Vector2(16,16)
		add_child(test_player)
	
func setPreview(_x):
	preview_level()

func setPlayerSpawn(x):
	player_spawn_position = x
	if Engine.editor_hint:
		preview_level()
