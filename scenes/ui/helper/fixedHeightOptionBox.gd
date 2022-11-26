tool
extends NinePatchRect

export var update_in_editor = false setget refresh

export(int) var width = 122 setget setWidth
export(int) var line_count = 3 setget setHeight

export(Array, String) var choices = []

export(Texture) var blank_texture = load("res://assets/ui/text boxes/transparent-8x22.png")
export(Texture) var arrow_texture = load("res://assets/ui/text boxes/arrow-190.png")

export(Color) var font_color = Color(0,0,0)
export(Color) var shadow_color = Color("bebebe")

export(int) var line_height = 26
export(int) var bottom_offset = 30

export(Resource) var font

signal button_pressed(option)

# Called when the node enters the scene tree for the first time.
func _ready():
	# prepare the font
	var new_font = DynamicFont.new()
	new_font.font_data = load("res://assets/fonts/alterebro.ttf")
	new_font.size = 32
	font = new_font
	connect_signals()

func setWidth(w):
	width = w
	margin_right = width

func setHeight(h):
	line_count = h
	margin_bottom = line_height * h + bottom_offset

func refresh(_p):
	var newNode = Control.new()
	add_child(newNode)
	for c in $Options.get_children():
		c.name = "dirty"
		c.queue_free()
	var i = 0
	for c in choices:
		# Make the button for this choice
		var newButton = TextureButton.new()
		newButton.name = c
		newButton.texture_normal = blank_texture
		newButton.texture_focused = arrow_texture
		$Options.add_child(newButton)
		newButton.set_owner(self)
		newButton.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		
		# Make the label for this choice
		var newLabel = Label.new()
		newLabel.text = c
		
		newLabel.anchor_right = 1
		newLabel.anchor_bottom = 1
		newLabel.margin_left = 12

		newLabel.set("custom_fonts/font", font)
		newLabel.set("custom_colors/font_color", font_color)
		newLabel.set("custom_colors/font_color_shadow", shadow_color)
		newLabel.set("custom_constants/shadow_offset_x", 2)
		newLabel.set("custom_constants/shadow_offset_y", 0)

		newButton.add_child(newLabel)
		newLabel.set_owner(self)
		
		if i >= line_count:
			newButton.visible = false
		
		i += 1
		margin_bottom = line_height * line_count + bottom_offset

func connect_signals():
	var l = $Options.get_children()
	for b in l:
		b.connect("pressed", self, "_on_child_button_pressed", [b.name])
		b.connect("focus_entered", self, "_on_child_focus_enter", [b.name])

func _on_child_button_pressed(text):
	emit_signal("button_pressed", text)
	print("emitted " + text)

func _on_child_focus_enter(text):
	if line_count > 0:

		# Make everything visible
		var l = $Options.get_children()
		for b in l:
			b.visible = true
		$upArrow.visible = true
		$downArrow.visible = true
		
		# get the index of the currently selected menu option
		var index = 0
		for i in range(len(l)):
			if l[i].name == text:
				index = i
				break
		
		# adjust node visibility to refocus on the desired node
		
		# Center the menu selection around the node of interest
		# lowest visible is the lowest index of a visible option
		var lowest_visible = index - int(floor(float(line_count) / 2.0) )
		# highest visible is the highest index of a visible option
		var highest_visible = index + int(ceil(float(line_count) / 2)) - 1

		# if the lowest visible is negative, that means that the
		# calculated range is outside of the menu, so clamp it back
		# into the menu
		if lowest_visible < 0:
			lowest_visible = 0
			highest_visible = line_count - 1
			$upArrow.visible = false

		# if the highest visible is greater than the number of
		# choices, then the calculated range is outside of the menu, so clamp
		# it back into the menu
		if highest_visible > len(choices) - 1:
			highest_visible = len(choices) - 1
			lowest_visible = highest_visible - line_count + 1
			$downArrow.visible = false

		for i in range(len(l)):
			if i < lowest_visible or i > highest_visible:
				l[i].visible = false

func focus():
	$Options.get_child(0).grab_focus()
