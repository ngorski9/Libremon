tool
extends Node2D

var screen_width = 640
var screen_height = 480
var character_width = 32
var character_height = 32

export(int) var map_width = 15 setget setWidth
export(int) var map_height = 10 setget setHeight

export(Color) var roomOutlineColor = Color(1,0,0) setget setRoomOutlineColor
export(Color) var cameraOutlineColor = Color(0,0,1) setget setCameraOutlineColor

export(bool) var reciprocateBorders = true
export(bool) var previewBorders = true setget setPreview

export(String) var upBorder = ""
export(int) var upOffset = 0 setget setUpOffset

export(String) var rightBorder = ""
export(int) var rightOffset = 0 setget setRightOffset

export(String) var downBorder = ""
export(int) var downOffset = 0 setget setDownOffset

export(String) var leftBorder = ""
export(int) var leftOffset = 0 setget setLeftOffset

var roomIsEditing = true

var fname

func _ready():
	fname = getFileNameMinusPath()

# gets an instance of the room with name "name"
# also, sets roomIsEditing to false
func getRoomInstance(name):
	var room_file = File.new()
	if room_file.file_exists("res://scenes/levels/" + name + ".tscn"):
		var instance = load("res://scenes/levels/" + name + ".tscn").instance()
		instance.roomIsEditing = false
		return instance
	return null

func getFileNameMinusPath():
	var startIndex = "res://scenes/levels/".length()
	var length = filename.length() - startIndex - ".tscn".length()
	return filename.substr(startIndex, length)

# Adds a copy of the room "room" to the scene tree with direction "direction"
# This gives it the name (direction)Border, (i.e. upBorder)
# It then returns the added node so that its data can be edited manually,
# (such as to change the position of the node)
func addBorderRoom(room, name):
	var instance = getRoomInstance(room)
	if instance:
		instance.name = name
		add_child(instance)
	return instance

# Draws adjacent scenes in the editor
func addBorderingScenes():
	removeBorderingScenes()
	if Engine.editor_hint and roomIsEditing and previewBorders:
		if upBorder != "":
			var upBorderInstance = addBorderRoom(upBorder, "upBorder")
			if upBorderInstance:
				upBorderInstance.position = Vector2(upOffset * 32, -upBorderInstance.map_height * 32)
		if downBorder != "":
			var downBorderInstance = addBorderRoom(downBorder, "downBorder")
			if downBorderInstance:
				downBorderInstance.position = Vector2(downOffset * 32, map_height * 32)
		if leftBorder != "":
			var leftBorderInstance = addBorderRoom(leftBorder, "leftBorder")
			if leftBorderInstance:
				leftBorderInstance.position = Vector2(-leftBorderInstance.map_width * 32, leftOffset * 32)
		if rightBorder != "":
			var rightBorderInstance = addBorderRoom(rightBorder, "rightBorder")
			if rightBorderInstance:
				rightBorderInstance.position = Vector2(map_width * 32, rightOffset * 32)

# removes the scene in direction "direction"
func removeBorderScene(direction):
	print(direction)
	var instance = get_node_or_null(direction + "Border")
	if instance:
		if reciprocateBorders:
			if direction == "up" and instance.downBorder == fname:
				instance.downBorder = ""
				instance.downOffset = 0
			if direction == "down" and instance.upBorder == fname:
				instance.upBorder = ""
				instance.upOffset = 0
			if direction == "left" and instance.rightBorder == fname:
				instance.rightBorder = ""
				instance.rightOffset = 0
			if direction == "right" and instance.leftBorder == fname:
				instance.leftBorder = ""
				instance.leftOffset = 0

			instance.position = Vector2(0,0)
			instance.name = instance.getFileNameMinusPath()
			var packed_instance = PackedScene.new()
			packed_instance.pack(instance)
			print(instance.filename)
			ResourceSaver.save(instance.filename, packed_instance)		
		
		instance.name = direction + "_delete"
		instance.queue_free()

func removeBorderingScenes():
	removeBorderScene("up")
	removeBorderScene("down")
	removeBorderScene("left")
	removeBorderScene("right")
		

# updates bordering rooms so that their borders match the current
# room's. This way, borders don't need to be updated twice.
func reciprocateBorderScenes():	
	if upBorder != "":
		var upRoom = getRoomInstance(upBorder)
		if upRoom:
			if upRoom.downBorder != fname or upRoom.downOffset != -upOffset:
				upRoom.downBorder = fname
				upRoom.downOffset = -upOffset
				var packed_upRoom = PackedScene.new()
				packed_upRoom.pack(upRoom)
				ResourceSaver.save("res://scenes/levels/" + upBorder + ".tscn", packed_upRoom)

	if leftBorder != "":
		var leftRoom = getRoomInstance(leftBorder)
		if leftRoom:
			if leftRoom.rightBorder != fname or leftRoom.rightOffset != -leftOffset:
				leftRoom.rightBorder = fname
				leftRoom.rightOffset = -leftOffset
				var packed_leftRoom = PackedScene.new()
				packed_leftRoom.pack(leftRoom)
				ResourceSaver.save("res://scenes/levels/" + leftBorder + ".tscn", packed_leftRoom)
			
	if downBorder != "":
		var downRoom = getRoomInstance(downBorder)
		if downRoom:
			if downRoom.upBorder != fname or downRoom.upOffset != -downOffset:
				downRoom.upBorder = fname
				downRoom.upOffset = -downOffset
				var packed_downRoom = PackedScene.new()
				packed_downRoom.pack(downRoom)
				ResourceSaver.save("res://scenes/levels/" + downBorder + ".tscn", packed_downRoom)

	if rightBorder != "":
		var rightRoom = getRoomInstance(rightBorder)
		if rightRoom:
			if rightRoom.leftBorder != fname or rightRoom.leftOffset != -rightOffset:
				rightRoom.leftBorder = fname
				rightRoom.leftOffset = -rightOffset
				var packed_rightRoom = PackedScene.new()
				packed_rightRoom.pack(rightRoom)
				ResourceSaver.save("res://scenes/levels/" + rightBorder + ".tscn", packed_rightRoom)

# This will draw lines which show the boundaries of where the player can walk
# so that the camera is still centered on the player
# not obeying these boundaries can lead to strange behavior with connected rooms.
func drawCameraMargins():
	
	var margin_x = (screen_width - character_width) / 2
	var margin_y = (screen_height - character_height) / 2
	if margin_y % 32 != 0:
		margin_y = margin_y + (32 - margin_y % 32)
	
	var top_right = Vector2(map_width * 32 - margin_x,margin_y)
	var bottom_right = Vector2(map_width * 32 - margin_x, map_height * 32 - margin_y)
	var bottom_left = Vector2(margin_x, map_height * 32 - margin_y)
	var top_left = Vector2(margin_x,margin_y)

	var upWidth = 0
	var downWidth = 0
	var leftHeight = 0
	var rightHeight = 0
	
	if upBorder != "":
		var upRoom = getRoomInstance(upBorder)
		if upRoom:
			upWidth = upRoom.map_width
	if downBorder != "":
		var downRoom = getRoomInstance(downBorder)
		if downRoom:
			downWidth = downRoom.map_width
	if leftBorder != "":
		var leftRoom = getRoomInstance(leftBorder)
		if leftRoom:
			leftHeight = leftRoom.map_height
	if rightBorder != "":
		var rightRoom = getRoomInstance(rightBorder)
		if rightRoom:
			rightHeight = rightRoom.map_height
	
	# Calculate where the corners of the shape will be
	# (excluding where one has an aisle into the bordering room
	
	if upBorder != "":
		if upOffset <= 0:
			top_left.y = 0
		if upWidth * 32 + upOffset * 32 >= map_width * 32:
			top_right.y = 0
	
	if rightBorder != "":
		if rightOffset <= 0:
			top_right.x = map_width * 32
		if rightOffset * 32 + rightHeight * 32 >= map_height * 32:
			bottom_right.x = map_width * 32
	
	if downBorder != "":
		if downOffset * 32 + downWidth * 32 >= map_width * 32:
			bottom_right.y = map_height * 32
		if downOffset <= 0:
			bottom_left.y = map_height * 32
		
	if leftBorder != "":
		if leftOffset * 32 + leftHeight * 32 >= map_height * 32:
			bottom_left.x = 0
		if leftOffset <= 0:
			top_left.x = 0
	
	# Draw the actual lines
	
	if upBorder != "":
		if upOffset > 0:
			var corner = Vector2( upOffset * 32 + margin_x , top_left.y )
			draw_line(top_left, corner, cameraOutlineColor, 2)
			draw_line( corner, Vector2(corner.x, 0), cameraOutlineColor, 2 )
		if upOffset * 32 + upWidth * 32 < map_width * 32:
			var corner = Vector2( upOffset*32 + upWidth*32 - margin_x, top_right.y )
			draw_line( corner, top_right, cameraOutlineColor, 2 )
			draw_line( corner, Vector2(corner.x, 0), cameraOutlineColor, 2 )
	else:
		draw_line( top_left, top_right, cameraOutlineColor, 2 )
		
	if rightBorder != "":
		if rightOffset > 0:
			var corner = Vector2( top_right.x, rightOffset * 32 + margin_y )
			draw_line( top_right, corner, cameraOutlineColor, 2 )
			draw_line( corner, Vector2( map_width * 32, corner.y ), cameraOutlineColor, 2 )
		if rightOffset * 32 + rightHeight * 32 < map_height * 32:
			var corner = Vector2( bottom_right.x, rightOffset * 32 + rightHeight * 32 - margin_y )
			draw_line( bottom_right, corner, cameraOutlineColor, 2 )
			draw_line( corner, Vector2( map_width * 32, corner.y ), cameraOutlineColor, 2 )
	else:
		draw_line( top_right, bottom_right, cameraOutlineColor, 2 )	

	if downBorder != "":
		if downOffset > 0:
			var corner = Vector2( downOffset * 32 + margin_x , bottom_left.y )
			draw_line(bottom_left, corner, cameraOutlineColor, 2)
			draw_line( corner, Vector2(corner.x, map_height * 32), cameraOutlineColor, 2 )
		if downOffset * 32 + downWidth * 32 < map_width * 32:
			var corner = Vector2( downOffset*32 + downWidth*32 - margin_x, bottom_right.y )
			draw_line( corner, bottom_right, cameraOutlineColor, 2 )
			draw_line( corner, Vector2(corner.x, map_height * 32), cameraOutlineColor, 2 )
	else:
		draw_line( bottom_left, bottom_right, cameraOutlineColor, 2 )

	if leftBorder != "":
		if leftOffset > 0:
			var corner = Vector2( top_left.x, leftOffset * 32 + margin_y )
			draw_line( top_left, corner, cameraOutlineColor, 2 )
			draw_line( corner, Vector2( 0, corner.y ), cameraOutlineColor, 2 )
		if leftOffset * 32 + leftHeight * 32 < map_height * 32:
			var corner = Vector2( bottom_left.x, leftOffset * 32 + leftHeight * 32 - margin_y )
			draw_line( bottom_left, corner, cameraOutlineColor, 2 )
			draw_line( corner, Vector2( 0, corner.y ), cameraOutlineColor, 2 )
	else:
		draw_line( top_left, bottom_left, cameraOutlineColor, 2 )	

func _draw():		
	# draws room stuff in the editor
	if Engine.editor_hint:
		
		for i in self.get_children():
			i.z_as_relative = false

		if roomIsEditing:
			z_index = 3
		else:
			z_index = 2
		
		if roomIsEditing:
			drawCameraMargins()
			addBorderingScenes()
		
			# Draw the room outline
			draw_rect(Rect2( 0, 0, map_width*32, map_height * 32 ), roomOutlineColor, false, 3 )
			
			if reciprocateBorders:
				reciprocateBorderScenes()
		else:
			# Fill in the adjacent scenes with white
			draw_rect(Rect2( 0, 0, map_width*32, map_height * 32 ), Color(1, 1, 1, 0.5), true )

# --------------- (set gets below -----------------#

func setWidth(w):
	map_width = w
	update()

func setHeight(h):
	map_height = h
	update()
	
func setUpOffset(x):
	upOffset = x
	update()
	
func setDownOffset(x):
	downOffset = x
	update()
	
func setLeftOffset(x):
	leftOffset = x
	update()
	
func setRightOffset(x):
	rightOffset = x
	update()

func setRoomOutlineColor(x):
	roomOutlineColor = x
	update()

func setCameraOutlineColor(x):
	cameraOutlineColor = x
	update()

func setPreview(x):
	previewBorders = x
	update()
