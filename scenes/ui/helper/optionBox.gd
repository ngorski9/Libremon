tool
extends NinePatchRect

export var update_in_editor = false setget refresh
export(Array, String) var choices = []
export(Resource) var font

var arrowButton = preload("res://scenes/ui/helper/arrowButton.tscn")

signal button_pressed(option)

# Called when the node enters the scene tree for the first time.
func _ready():
	refresh(true)
	connect_signals()

func refresh(_p):
	for c in $Options.get_children():
		c.name = "dirty"
		c.queue_free()
	var i = 0
	for c in choices:
		
		# Make the button for this choice
		var newButton = arrowButton.instance()
		newButton.name = c
		newButton.setText(c)
		$Options.add_child(newButton)
		newButton.set_owner(get_tree().edited_scene_root)
		
		i += 1

	# Connect the bottom and top option
	if len($Options.get_children()) > 0:
		$Options.get_child(0).focus_neighbour_top = "../" + choices[len(choices) - 1]
		$Options.get_child(len(choices) - 1).focus_neighbour_bottom = "../" + choices[0]

func focus():
	$Options.get_child(0).grab_focus()

func connect_signals():
	var l = $Options.get_children()
	for b in l:
		b.connect("pressed", self, "_on_child_button_pressed", [b.name])

func _on_child_button_pressed(text):
	emit_signal("button_pressed", text)
