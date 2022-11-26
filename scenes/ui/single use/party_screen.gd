extends TextureRect

signal exit(reason, other_param)

var purpose = "Normal"
var state = "Pick"

var of_interest = 0

var party_buttons = []

var left_side_margin_left = 0
var right_side_margin_left = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	refresh()
	
func refresh():
	# fill out the boxes
	for i in range(6):
		var box = get_node("Party" + str(i+1))
		party_buttons.append(box)
		if i >= len(PlayerData.party):
			box.disabled = true
			box.hide_graphics()
			box.focus_mode = Control.FOCUS_NONE
		else:
			box.updateDataToMonster(PlayerData.party[i])
			
	left_side_margin_left = $Party1.margin_left
	right_side_margin_left = $Party2.margin_left

	# fix any strange focus neighbors
	if len(PlayerData.party) == 5:
		$ExitButton.focus_neighbour_top = "../Party4"
	if len(PlayerData.party) == 3:
		$ExitButton.focus_neighbour_top = "../Party2"

func _input(event):
	if visible:
		if event.is_action_pressed("ui_b"):
			if purpose == "Normal":
				if state == "Pick":
					emit_signal("exit", "Normal", 0)
				elif state == "Normal Options":
					change_state("Pick")
				elif state == "Switch":
					change_state("Normal Options")

func focus():
	$Party1.grab_focus()

func on_libremon_selected(index):
	if purpose == "Normal":
		if state == "Pick":
			of_interest = index
			change_state("Normal Options")
		if state == "Switch":
			if index == of_interest:
				change_state("Normal Options")
			else:
				of_interest = [of_interest, index]
				change_state("Switching Out")

func change_state(to):
	var from = state
	state = to
	
	if from == "Switching In":
		of_interest = of_interest[1]
	
	if to == "Normal Options":

		get_tree().call_group("librebox", "set_texture_mode", "Normal Options", of_interest)
		$Prompter/MessageLabel.text = "Do What?"
		$NormalOptions.visible = true
		$NormalOptions.focus()
		setButtonsLocked(true)

	if to == "Pick":
		if from == "Normal Options":
			$Prompter/MessageLabel.text = "Select a libremon"
			$NormalOptions.visible = false
			setButtonsLocked(false)
			# this needs to be here because the call group function doesn't activate immediately
			var will_be_selected = button_of_interest()
			will_be_selected.set_focus_mode(TextureButton.FOCUS_ALL)
			will_be_selected.grab_focus()
			get_tree().call_group("librebox", "set_texture_mode", "Normal", of_interest)

	if to == "Switch":
		if from == "Normal Options":
			var will_be_selected = button_of_interest()
			get_tree().call_group("librebox", "set_texture_mode", "Switch", of_interest)
			$Prompter/MessageLabel.text = "Switch with who?"
			$NormalOptions.visible = false
			setButtonsLocked(false)
			will_be_selected.set_focus_mode(TextureButton.FOCUS_ALL)
			will_be_selected.grab_focus()
	
	if to == "Switching Out":
		if of_interest[0] % 2 == 0:
			$BoxMover.interpolate_property(get_node("Party" + str(of_interest[0] + 1)), "margin_left", left_side_margin_left, left_side_margin_left -400, 0.5 )
		else:
			$BoxMover.interpolate_property(get_node("Party" + str(of_interest[0] + 1)), "margin_left", right_side_margin_left, right_side_margin_left + 400, 0.5 )
		if of_interest[1] % 2 == 0:
			$BoxMover.interpolate_property(get_node("Party" + str(of_interest[1] + 1)), "margin_left", left_side_margin_left, left_side_margin_left -400, 0.5 )
		else:
			$BoxMover.interpolate_property(get_node("Party" + str(of_interest[1] + 1)), "margin_left", right_side_margin_left, right_side_margin_left + 400, 0.5 )
		$BoxMover.start()
		setButtonsLocked(true)

	if to == "Switching In":
		var temp_mon = PlayerData.party[of_interest[0]]
		PlayerData.party[of_interest[0]] = PlayerData.party[of_interest[1]]
		PlayerData.party[of_interest[1]] = temp_mon
		get_node("Party" + str(of_interest[0] + 1)).updateDataToMonster(PlayerData.party[of_interest[0]])
		get_node("Party" + str(of_interest[1] + 1)).updateDataToMonster(PlayerData.party[of_interest[1]])
		if of_interest[0] % 2 == 0:
			$BoxMover.interpolate_property(get_node("Party" + str(of_interest[0] + 1)), "margin_left", left_side_margin_left -400, left_side_margin_left, 0.5 )
		else:
			$BoxMover.interpolate_property(get_node("Party" + str(of_interest[0] + 1)), "margin_left", right_side_margin_left + 400, right_side_margin_left , 0.5 )
		if of_interest[1] % 2 == 0:
			$BoxMover.interpolate_property(get_node("Party" + str(of_interest[1] + 1)), "margin_left", left_side_margin_left -400, left_side_margin_left, 0.5 )
		else:
			$BoxMover.interpolate_property(get_node("Party" + str(of_interest[1] + 1)), "margin_left", right_side_margin_left + 400, right_side_margin_left, 0.5 )
		$BoxMover.start()

func onNormalOptionPressed(option):
	if option == "Summary":
		change_state("Pick")
		emit_signal("exit", "Summary", of_interest)
	if option == "Switch":
		change_state("Switch")
	if option == "Cancel":
		change_state("Pick")

func setButtonsLocked(locked):
	if locked:
		get_tree().call_group("librebox","set_focus_mode", TextureButton.FOCUS_NONE)
	else:
		get_tree().call_group("librebox","set_focus_mode", TextureButton.FOCUS_ALL)
			
func shift_unfainted():
	get_tree().call_group("librebox", "shift", false)

func shift_fainted():
	get_tree().call_group("librebox", "shift", true)

func _on_ExitButton_pressed():
	emit_signal("exit", "Normal", 0)

func button_of_interest():
	return get_node("Party" + str(of_interest + 1))


func _on_BoxMover_tween_all_completed():
	if state == "Switching Out":
		change_state("Switching In")
	elif state == "Switching In":
		change_state("Normal Options")
