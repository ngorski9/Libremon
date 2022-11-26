extends Control

var purpose = "Normal"

var mode = 1
# scrolls through 1, 2, 3 and 4

var of_interest = 0
# index of the party member which is being viewed

var page3_screen1 = load("assets/ui/summary/summary-bg-3.png")
var page3_screen2 = load("assets/ui/summary/summary-bg-4.png")
var move_selector = load("assets/ui/summary/move-selector.png")

signal exit(reason, other_param)

func resetToPage1():
	$Page1.visible = true
	$Page2.visible = false
	$Page3.visible = false
	mode = 1

func _input(event):
	if visible:
		if event.is_action_pressed("ui_right"):
			if mode == 1:
				$Page1.visible = false
				$Page2.visible = true
				mode = 2
			elif mode == 2:
				$Page2.visible = false
				$Page3.visible = true
				mode = 3

		elif event.is_action_pressed("ui_left"):
			if mode == 2:
				$Page2.visible = false
				$Page1.visible = true
				mode = 1
			elif mode == 3:
				$Page3.visible = false
				$Page2.visible = true
				mode = 2

		elif event.is_action_pressed("ui_accept"):
			if mode == 3:
				$Page3/MovesColumn/Move1.grab_focus()

		elif event.is_action_pressed("ui_b"):
			if mode == 4:
				quitMoveSummary()
			else:
				emit_signal("exit", "Normal", of_interest)
		
		elif event.is_action_pressed("ui_up") and purpose == "Normal":
			if mode != 4:
				of_interest -= 1
				# Apparently mods work weird for negative numbers
				# in gdscript so I just did this
				if of_interest == -1:
					of_interest = 5
				updateToMonster(PlayerData.party[of_interest])
		
		elif event.is_action_pressed("ui_down") and purpose == "Normal":
			if mode != 4:
				of_interest += 1
				of_interest %= len(PlayerData.party)
				updateToMonster(PlayerData.party[of_interest])

func quitMoveSummary():
	mode = 3
	$Page3.texture = page3_screen1
	get_tree().call_group("move", "release_focus")
	$UsuallyPresent/LevelLabel.visible = true
	$UsuallyPresent/SpeciesPicture.visible = true
	$Page3/DataColumn.visible = false

func onMoveFocusEnter(index):
	if mode != 4:
		mode = 4
		$Page3.texture = page3_screen2
		$UsuallyPresent/LevelLabel.visible = false
		$UsuallyPresent/SpeciesPicture.visible = false
		$Page3/DataColumn.visible = true
	var d = $Page3/DataColumn/Data
	var move = PlayerData.party[of_interest].moves[index]
	d.get_node("ModeLabel").text = move.mode
	if move.power == null:
		d.get_node("PowerLabel").text = "-"
	else:
		d.get_node("PowerLabel").text = str(move.power)
	if move.accuracy == null:
		d.get_node("AccuracyLabel").text = "-"
	else:
		d.get_node("AccuracyLabel").text = str(move.accuracy)
	d.get_node("DescriptionLabel").text = move.description
	get_node("Page3/MovesColumn/Move" + str(index+1)).texture = move_selector

func onMoveFocusExit(index):
	get_node("Page3/MovesColumn/Move" + str(index+1)).texture = null

func updateToMonster(mon):
	# Set the usually present data
	get_node("UsuallyPresent/LevelLabel").text = str(mon.level)
	get_node("UsuallyPresent/SpeciesLabel").text = str(mon.species)
	get_node("UsuallyPresent/SpeciesPicture").texture.atlas = load("res://assets/monsters/" + mon.species + ".png")
	get_node("UsuallyPresent/genderLabel").setGender(mon.gender)
	
	# Set the page 1 data
	var p1d = $Page1/Data
	p1d.get_node("NumberLabel").text = str(mon.number)
	p1d.get_node("NameLabel").text = mon.name
	p1d.get_node("OriginalLabel").text = mon.oo
	#p1d.get_node("IDLabel").text = str(mon.public_ID)
	if mon.item == null:
		p1d.get_node("ItemLabel").text = "None"
	else:
		p1d.get_node("ItemLabel").text = mon.item
	p1d.get_node("PersonalityLabel").text = mon.personality + " personality"
	p1d.get_node("MetPlaceLabel").text = "met at " + mon.met_location
	p1d.get_node("MetLevelLabel").text = "at Lv " + str(mon.met_level)
	p1d.get_node("Type1Label").updateToType(mon.type1)
	p1d.get_node("Type2Label").updateToType(mon.type2)

	# Set the page 2 data
	var p2d = $Page2/Data
	p2d.get_node("HPLabel").text = str(mon.hp) + " / " + str(mon.stats["HP"])
	p2d.get_node("AttackLabel").text = str(mon.stats["Attack"])
	p2d.get_node("DefenseLabel").text = str(mon.stats["Defense"])
	p2d.get_node("SpecialAttackLabel").text = str(mon.stats["Special Attack"])
	p2d.get_node("SpecialDefenseLabel").text = str(mon.stats["Special Defense"])
	p2d.get_node("SpeedLabel").text = str(mon.stats["Speed"])
	p2d.get_node("AbilityNameLabel").text = mon.ability
	p2d.get_node("ExperienceLabel").text = str(mon.experience)
	p2d.get_node("NextLevelLabel").text = str(mon.experience_next)
	var hpBar = p2d.get_node("HPBar")
	hpBar.max_value = mon.stats["HP"]
	hpBar.value = mon.hp
	var hpPercent = float(mon.hp) / float(mon.stats["HP"])
	if hpPercent >= 0.5:
		hpBar.texture_progress.region = Rect2(0,0,96,6)
	elif hpPercent >= 0.25:
		hpBar.texture_progress.region = Rect2(0,6,96,6)
	else:
		hpBar.texture_progress.region = Rect2(0,12,96,6)
	var expBar = p2d.get_node("ExperienceBar")
	if mon.level == StaticData.max_monster_level:
		expBar.value = 0
	else:
		expBar.min_value = mon.experience_previous
		expBar.max_value = mon.experience_next
		expBar.value = mon.experience
		
	# set up page 3 data
	var mc = $Page3/MovesColumn
	for i in range(4):
		# if the monster doesn't have that many moves, hide this column
		if i >= len(mon.moves):
			mc.get_node("Move" + str(i+1)).visible = false
		else:
			var move = mc.get_node("Move" + str(i+1))
			move.visible = true
			move.get_node("typeLabel").updateToType(mon.moves[i].type)
			move.get_node("NameLabel").text = mon.moves[i].name
			move.get_node("MMLabel").text = str(mon.moves[i].mana_remaining) + " / " + str(mon.moves[i].mana_max)
	var dcd = $Page3/DataColumn/Data
	dcd.get_node("MonsterIcon").texture.atlas = load("res://assets/monsters/" + mon.name + ".png")
	dcd.get_node("type1Label").updateToType(mon.type1)
	dcd.get_node("type2Label").updateToType(mon.type2)

func _on_CancelButton_focus_entered():
	if mode != 4:
		$Page3/MovesColumn/Move1.grab_focus()
