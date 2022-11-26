extends CanvasLayer

var paused = false

var menuMode = "None"

# handles opening and closing the pause menu
func _input(event):
	if event.is_action_pressed("ui_start"):
		if not get_tree().paused and not $"../Player".moving:
			enter_mode("Pause", null, null)
		elif menuMode == "Pause":
			unpause()
	if event.is_action_pressed("ui_b"):
		if menuMode == "Pause":
			unpause()

func _on_PauseBox_button_pressed(option):
	if option == "Libremon":
		enter_mode("Party", "Normal", null)
	if option == "Exit":
		get_tree().paused = false
		$PauseMenu.visible = false

# responsible for switching to various menu modes
# "purpose" tells the new menu node what it will be doing
# of_interest is an extra general purpose parameter which often
# carries an index in the party

func enter_mode(mode, purpose, of_interest):
	menuMode = mode
	if mode == "Pause":
		get_tree().paused = true
		$PauseMenu.visible = true
		$PauseMenu/PauseBox.focus()
	if mode == "Party":
		menuMode = "Party"
		$PauseMenu.visible = false
		var ps = $PartyScreen
		ps.refresh()
		ps.visible = true
		ps.focus()
		ps.purpose = purpose
		
		# depending on the purpose, sets the initial state to the
		# correct value
		if purpose == "Normal":
			ps.state = "Pick"
		elif purpose == "Return from summary":
			ps.purpose = "Normal"
			ps.state = "Pick"
			# simulate a button being pressed to pull up the menu
			ps.on_libremon_selected(of_interest)
	if mode == "Summary":
		menuMode = "Summary"
		var ss = $SummaryScreen
		ss.visible = true
		ss.of_interest = of_interest
		ss.updateToMonster(PlayerData.party[of_interest])
		ss.resetToPage1()
		
# Various exit functions.

# leaves pause mode
func unpause():
	menuMode = "None"
	get_tree().paused = false
	$PauseMenu.visible = false

# collects the exit signals for each of the menu screens
func on_menu_screen_exit(reason, other_param, screen):
	if screen == "Party":
		$PartyScreen.visible = false
		if reason == "Normal":
			enter_mode("Pause", null, null)
		elif reason == "Summary":
			enter_mode("Summary", "Normal", other_param)
	if screen == "Summary":
		$SummaryScreen.visible = false
		if reason == "Normal":
			enter_mode("Party", "Return from summary", other_param)
