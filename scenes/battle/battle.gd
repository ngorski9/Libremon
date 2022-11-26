extends TextureRect

signal done(outcome)
signal external(reason)

# whether or not various prints should be on for debugging
const USUAL_PRINTS = false

# used to store the encounter data
var encounter

var encounter_template = preload("res://standalone scripts/data containers/Encounter.gd")

# Feral or Person
var purpose

# Single or Double, may add to this later
var format

var ally
var ally2
var ally_party_index
var ally2_party_index

var enemy
var enemy2 # typically unused
var enemy_party_index
var enemy2_party_index

# States that apply to each the room, allies, and enemies
var room_states = []
var ally_states = []
var enemy_states = []

# Keeps track of all of the listeners attached to each hook
# This is a dictionary where the keys are hook names. The value of each hook name is
# an array of listeners which listen to that hook.
var attached_listeners = {}
var attached_states = {"Ally" : [], "Ally2" : [], "Enemy" : [], "Enemy2" : [], "AllySide" : [], "EnemySide" : [], "Battlefield" : []}

# set to true if the user is able to control things
var mode = "Animation"
# modes:

# Animation       - Animations are playing, no player control
# Main            - Main choices, fight, item etc.
# Fight           - Choose which move to use
# Target          - Choose which target to hit (double battles only)
# Transition:mode - Playing an animation to transition to mode "mode"

# will fill up with animations, which is a string of the form user:action
# Moves are stored as a string and then the corresponding object is fetched
# from the monster

var turn_actions = []
# actions:

# how many animations are currently playing
# (starts out as 1)
var animations_playing = 1
var animation_queue = ["start"]
# animation codes:

# join multiple of these codes with & signs to fire them simultaneously.
# note: codes that do not end in a colon cannot be joined with other codes

# Txt: - followed by whatever text you want to display
# Block - wait until enter is pressed to move on
# MonAnimate - Follow by something of the form Mon+Animation
#			   Replace Mon with Ally, Ally2, Enemy or Enemy2
#			   Replace Animation with the name of the animation that you want it to play
#			   Keep the + sign as a plus sign
#		       Causes a specified monster to play a specified animation
# MonAnimateBackwards - Same as MonAnimate, but runs the animation backwards
# PersonAppear: - Follow by Ally or Enemy. Causes person to appear
# MonDisappear: - Follow by Ally, Ally2, Enemy, or Enemy2. Causes monster to disappear
# PersonDisappear: - Follow by Ally or Enemy. Causes person to disappear
# SummaryAppear: - Follow by Ally or Enemy. Causes box to appear
# SummaryDisappear: - Follow by Ally or enemy. Causes box to disappear
# Box: - Follow by Expand or Contract
# Wait: - waits for a certain amount of time
# Healthbar: - Follow by something of the form Mon+Value
#				Replace Mon with Ally, Ally2, Enemy or Enemy2
#				Replace Value with an integer value from 0-100
#				Makes the specified monster's health bar have the
#				Specified percent
# SwapSummary - Followed by something of the form Which+Index+Hp+Level
#				or something of the form Which+Index+Hp
#				Replace Which with AllySingle, AllyDoubleTop, AllyDoubleBottom
#					EnemySingle, EnemyDoubleTop, or EnemyDoubleBottom
#				Replace Index with the index in the party of the new monster
#				  to be sent out
#				Replace HP with the HP that you want the monster to have
#				(optional) Replace Level with the level that you want the monster to have
#				otherwise, fills in the correct level of the monster
#				Replaces the information of the given summary box with the information
#				Of the specified monster, except that the health percent is the given
#				health percent, and then makes that box the one that is visible.
# SwapMonsterSprite - Followed by something of the form Key+Species
#				Replace Key with Ally, Ally2, Enemy, or Enemy2
#				Replace Species with the species to swap the sprite to
# End: - Follow by win or lose. Ends the battle
# DoubleToSingle: - Followed by something of the form Key+Time
#					Replace Key with Ally, Ally2, Enemy, or Enemy2
#					Replace Time with Slow or Fast
#					Shifts the specified monster from its double battle position to
#					the single battle position. Actually, only the sprite for Ally or Enemy
#					will actually move, although if Ally2 or Enemy2 is specified, it will move
#					from the position of Ally2 or Enemy2 to the correct location
# ExpBar: - Follow by something of the form Key+From+To
#			Replace key with Ally or Ally2
#			Replace From with a number from 0-100, which is the percent you want the bar to display
#			  initially
#			Replace To with a number from 0-100, which is the percent that you want the bar to
#			  display at the end
#			Animates the experience bar to shift the amount of experience from "From" to "To"
# FlashSummary: - Follow by something of the form Which+Direction
#			Replace Which with Ally or Enemy
#			Replace Direction with In or Out
#			Adds a silohette effect to the level-up box. There is the option to specify in/out
#			because the level updates while the silhouette is up, so the full animation sadly must be split
#			between two different animations
# EndAnimations - Followed by something of the form Mode+Who
#				  Replace Mode with the menu mode that it should swtich to
#				  Replace Who with who should receive focus

# used for fetching the action opcodes
var action_template = preload("../../standalone scripts/state code nodes/StateCodeActionNode.gd")

func _ready():
	var e = encounter_template.new()
	e.party = [StaticData.generate_monster("Hissiorite", 32), StaticData.generate_monster("Nuenflu", 2)]
	e.style = "Default"
	e.name = "Tammy"
	e.items = []
	e.ai = "Random"
	e.money = 100
	e.lose_message = "How did I lose!?"
	start("Person", "Double", e)

# ------------------------------------------------------------------------------
#        SETUP AND ANIMATIONS
# ------------------------------------------------------------------------------
func start(purpose, format, encounter, theme="Default"):
	self.format = format
	self.purpose = purpose
	self.encounter = encounter

	# all visibilities are set so that no initial values for the visibility
	# of anything needs to be assumed
	$allyArea/allyPerson.visible = true
	$enemyArea/enemyPerson.visible = false

	# Change the names of the encounter party's monsters:
	for m in encounter.party:
		if m.name == m.species:
			m.name = "Enemy " + m.species

	# Find what party members will be sent out. Set texture for ally
	for i in range(len(PlayerData.party)):
		if PlayerData.party[i].hp != 0:
			ally = PlayerData.party[i]
			ally_party_index = i
			break
	setMonsterTexture($allyArea/allySprite, ally)
	if format == "Double":
		# set second ally
		for i in range(len(PlayerData.party)):
			if PlayerData.party[i].hp != 0 and i != ally_party_index:
				ally2 = PlayerData.party[i]
				ally2_party_index = i
				break
	
	# update the hook counts based on the abilities of the monsters
	var monsters = [ally, ally2, enemy, enemy2]
	for m in monsters:
		if not m:
			continue
		var states = m.get_all_states()
		for s in states:
			attachState(s)
	var state_lists = [room_states, ally_states, enemy_states]
	for li in state_lists:
		for s in li:
			attachState(s)
					
	# Set positions based on if there are two allies or one
	if ally2:
		$allyArea/allySprite.rect_position = Vector2(62,106)
		$allyArea/allySummary.visible = false
		$allyArea/allySummaryDouble.visible = true
		setMonsterTexture($allyArea/allySprite2, ally2)
		setDoubleSummary(ally, "Ally")
		setDoubleSummary(ally2, "Ally2")
	else:
		$allyArea/allySummary.visible = true
		$allyArea/allySummaryDouble.visible = false
		$allyArea/allySprite.rect_position = Vector2(18,114)
		setSingleSummary(ally, "Ally")

	# Find which enemies will be sent out. Set texture for enemy
	enemy = encounter.party[0]
	enemy_party_index = 0
	setMonsterTexture($enemyArea/enemySprite, enemy)
	if format == "Double":
		if len(encounter.party) > 1:
			enemy2 = encounter.party[1]	
			enemy2_party_index = 1

	# Set textures and positions based on if there are two enemies or one
	if enemy2:
		$enemyArea/enemySprite.rect_position = Vector2(286,106)
		$enemyArea/enemySummary.visible = false
		$enemyArea/enemySummaryDouble.visible = true
		setMonsterTexture($enemyArea/enemySprite2, enemy2)
		setDoubleSummary(enemy, "Enemy")
		setDoubleSummary(enemy2, "Enemy2")
	else:
		$enemyArea/enemySummary.visible = true
		$enemyArea/enemySummaryDouble.visible = false
		$enemyArea/enemySprite.rect_position = Vector2(330,114)
		setSingleSummary(enemy, "Enemy")

	# @hook onSwitchIn

	# set up the animations and sprites for the intro
	if purpose == "Feral":
		$enemyArea/enemySprite.appear_immediately()
		if enemy2:
			$enemyArea/enemySprite2.appear_immediately()
			animation_queue.append("Txt:A feral " + enemy.name + " and " + enemy2.name + " approach!&SummaryAppear:Enemy")
		else:
			animation_queue.append("Txt:A feral " + enemy.name + " approaches!&SummaryAppear:Enemy")
		animation_queue.append("Block")
	elif purpose == "Person":
		$enemyArea/enemyPerson.visible = true
		animation_queue.append("Txt:You are challenged by " + encounter.name)
		animation_queue.append("Block")
		if enemy2:
			animation_queue.append("Txt:" + encounter.name + " sends out " + get_enemy_nickname(enemy) + " and " + get_enemy_nickname(enemy2) + "!")
			animation_queue.append("PersonDisappear:Enemy&Wait:0.5")
			animation_queue.append("MonAnimate:Enemy+Appear&MonAnimate:Enemy2+Appear&SummaryAppear:Enemy")
		else:
			animation_queue.append("Txt:" + encounter.name + " sends out " + get_enemy_nickname(enemy) + "!")
			animation_queue.append("PersonDisappear:Enemy&Wait:0.5")
			animation_queue.append("MonAnimate:Enemy+Appear&SummaryAppear:Enemy")

	# Keep setting up animations for the intro
	if ally2:
		animation_queue.append("Txt:You send out " + ally.name + " and " + ally2.name + "!")
		animation_queue.append("PersonDisappear:Ally&Wait:0.5")
		animation_queue.append("MonAnimate:Ally+Appear&MonAnimate:Ally2+Appear&SummaryAppear:Ally")
	else:
		animation_queue.append("Txt:You send out " + ally.name + "!")
		animation_queue.append("PersonDisappear:Ally&Wait:0.5")
		animation_queue.append("MonAnimate:Ally+Appear&SummaryAppear:Ally")

	animation_queue.append("EndAnimations:Main+Ally")
	$AnimationPlayer.play("Opener")

# runs the animation(s) queued up in the 0 position of the queue
func play_queued_animation():
	if USUAL_PRINTS:
		print(animation_queue[0])
	var animations = animation_queue[0].split("&")
	var activate_tween = false
	for i in animations:
		# Say that this animation is playing
		animations_playing += 1
		
		# Decode the animation
		var animation_split = i.split(":")
		var key = animation_split[0]
		var value = ""
		if len(animation_split) > 1:
			value = animation_split[1]
		
		# act accordingly
		if key == "Txt":
			var t = $MainTextBox/MainText
			t.text = value
			t.visible_characters = 0
			$Tween.interpolate_property(t, "visible_characters", 0, len(value), PlayerData.text_speed*len(value))
			activate_tween = true

		elif key == "MonAnimate":
			var value_split = value.split("+")
			var monster_key = value_split[0]
			var monster_animation = value_split[1]
			var monster = get_monster_sprite_from_key(monster_key)
			
			monster.play_animation(monster_animation)

		elif key == "PersonAppear":
			if value == "Ally":
				$Tween.interpolate_property($allyArea/allyPerson, "rect_position", Vector2(-80, 106), Vector2(46,106), 0.5)
				activate_tween = true
			elif value == "Enemy":
				$Tween.interpolate_property($enemyArea/enemyPerson, "rect_position", Vector2(500, 106), Vector2(348, 106), 0.5)
				activate_tween = true

		elif key == "SummaryAppear":
			if value == "Ally":
				# If the box isn't already in place, animate it
				if $allyArea/allySummary.rect_position != Vector2(0,254):
					$Tween.interpolate_property($allyArea/allySummary, "rect_position", Vector2(0, 320), Vector2(0, 254), 0.2)
					$Tween.interpolate_property($allyArea/allySummaryDouble, "rect_position", Vector2(0, 320), Vector2(0, 254), 0.2)
					animations_playing += 1 # This is because 2 things are animated by this animation
					activate_tween = true
				else:
					animations_playing -= 1
			elif value == "Enemy":
				# If the box isn't already in place, animate it
				if $enemyArea/enemySummary.rect_position != Vector2(240,254):
					$Tween.interpolate_property($enemyArea/enemySummary, "rect_position", Vector2(240, 320), Vector2(240, 254), 0.2)
					$Tween.interpolate_property($enemyArea/enemySummaryDouble, "rect_position", Vector2(240, 320), Vector2(240, 254), 0.2)
					animations_playing += 1 # This is because 2 things are animated by this animation
					activate_tween = true
				else:
					animations_playing -= 1

		elif key == "MonAnimateBackwards":
			var value_split = value.split("+")
			var monster_key = value_split[0]
			var monster_animation = value_split[1]
			var monster = get_monster_sprite_from_key(monster_key)
			
			monster.play_backwards(monster_animation)

		elif key == "PersonDisappear":
			if value == "Ally":
				$Tween.interpolate_property($allyArea/allyPerson, "rect_position", Vector2(46, 106), Vector2(-80,106), 0.3)
				activate_tween = true
			elif value == "Enemy":
				$Tween.interpolate_property($enemyArea/enemyPerson, "rect_position", Vector2(348, 106), Vector2(500, 106), 0.3)
				activate_tween = true

		elif key == "SummaryDisappear":
			if value == "Ally":
				# If the summary isn't already in the right place, animate it
				if $allyArea/allySummary.rect_position != Vector2(0,320):
					$Tween.interpolate_property($allyArea/allySummary, "rect_position", Vector2(0, 254), Vector2(0, 320), 0.2)
					$Tween.interpolate_property($allyArea/allySummaryDouble, "rect_position", Vector2(0, 254), Vector2(0, 320), 0.2)
					animations_playing += 1 # This is because 2 things are animated by this animation
					activate_tween = true
				else:
					# Otherwise, do nothing
					animations_playing -= 1
			elif value == "Enemy":
				# If the summary isn't already in the right place, animate it
				if $enemyArea/enemySummary.rect_position != Vector2(240, 320):
					$Tween.interpolate_property($enemyArea/enemySummary, "rect_position", Vector2(240, 254), Vector2(240, 320), 0.2)
					$Tween.interpolate_property($enemyArea/enemySummaryDouble, "rect_position", Vector2(240, 254), Vector2(240, 320), 0.2)
					animations_playing += 1 # This is because 2 things are animated by this animation
					activate_tween = true
				else:
					# Otherwise, do nothing
					animations_playing -= 1

		elif key == "Wait":
			$Timer.wait_time = float(value)
			$Timer.start()
			
		elif key == "Healthbar":
			
			# This animates 2 things
			animations_playing += 1
			
			var bar_single = null
			var bar_double = null

			var value_split = value.split("+")
			var bar_key = value_split[0]
			var initial_bar_value = int(value_split[1])
			var final_bar_value = int(value_split[2])

			if bar_key == "Ally":
				bar_single = $allyArea/allySummary/hpProgress
				bar_double = $allyArea/allySummaryDouble/hpProgressTop
			elif bar_key == "Ally2":
				bar_single = $allyArea/allySummary/hpProgress
				bar_double = $allyArea/allySummaryDouble/hpProgressBottom
			elif bar_key == "Enemy":
				bar_single = $enemyArea/enemySummary/hpProgress
				bar_double = $enemyArea/enemySummaryDouble/hpProgressTop
			elif bar_key == "Enemy2":
				bar_single = $enemyArea/enemySummary/hpProgress
				bar_double = $enemyArea/enemySummaryDouble/hpProgressBottom

			var time = 2.0 * float(abs(initial_bar_value - final_bar_value)) / 100.0
			
			$Tween.interpolate_property(bar_single, "value", initial_bar_value, final_bar_value, time, Tween.TRANS_QUAD)
			$Tween.interpolate_property(bar_double, "value", initial_bar_value, final_bar_value, time, Tween.TRANS_QUAD)
			activate_tween = true
		elif key == "SwapMonsterSprite":
			animations_playing -= 1
			var value_split = value.split("+")
			var monster_key = value_split[0]
			var species = value_split[1]
			get_monster_sprite_from_key(monster_key).set_sprite(species)
		elif key == "SwapSummary":
			animations_playing -= 1
			var value_split = value.split("+")
			var which_key = value_split[0]
			var monster_index = int(value_split[1])
			var bar_value = int(value_split[2])
			var level_value
			if len(value_split) == 4:
				level_value = int(value_split[3])
			else:
				# When passed in to the set summary methods, they will know
				# that this means to use the current level of the monster,
				# rather than other proxy value
				level_value = -1

			if which_key == "AllySingle":
				setSingleSummary(PlayerData.party[monster_index], "Ally", bar_value, level_value)
				$allyArea/allySummary.visible = true
				$allyArea/allySummaryDouble.visible = false
			elif which_key == "AllyDoubleTop":
				setDoubleSummary(PlayerData.party[monster_index], "Ally", bar_value, level_value)
				$allyArea/allySummary.visible = false
				$allyArea/allySummaryDouble.visible = true
			elif which_key == "AllyDoubleBottom":
				setDoubleSummary(PlayerData.party[monster_index], "Ally2", bar_value, level_value)
				$allyArea/allySummary.visible = false
				$allyArea/allySummaryDouble.visible = true
			elif which_key == "EnemySingle":
				setSingleSummary(encounter.party[monster_index], "Enemy", bar_value, level_value)
				$enemyArea/enemySummary.visible = true
				$enemyArea/enemySummaryDouble.visible = false
			elif which_key == "EnemyDoubleTop":
				setDoubleSummary(encounter.party[monster_index], "Enemy", bar_value, level_value)
				$enemyArea/enemySummary.visible = false
				$enemyArea/enemySummaryDouble.visible = true
			elif which_key == "EnemyDoubleBottom":
				setDoubleSummary(encounter.party[monster_index], "Enemy2", bar_value, level_value)
				$enemyArea/enemySummary.visible = false
				$enemyArea/enemySummaryDouble.visible = true
		elif key == "DoubleToSingle":
			var value_split = value.split("+")
			var monster_key = value_split[0]
			var time_key = value_split[1]
			if time_key == "Slow":
				if monster_key == "Ally2":
					var ally_sprite = $allyArea/allySprite
					var ally_sprite2 = $allyArea/allySprite2
					ally_sprite.visible = true
					ally_sprite.make_visible()
					ally_sprite.rect_position = ally_sprite2.rect_position
					ally_sprite2.visible = false
				elif monster_key == "Enemy2":
					var enemy_sprite = $enemyArea/enemySprite
					var enemy_sprite2 = $enemyArea/enemySprite2
					enemy_sprite.visible = true
					enemy_sprite.make_visible()
					enemy_sprite.rect_position = enemy_sprite2.rect_position
					enemy_sprite2.visible = false
					
				if monster_key == "Ally" or monster_key == "Ally2":
					$Tween.interpolate_property($allyArea/allySprite, "rect_position", get_monster_sprite_from_key(monster_key).rect_position, Vector2(18,114), 0.3)
				else:
					$Tween.interpolate_property($enemyArea/enemySprite, "rect_position", get_monster_sprite_from_key(monster_key).rect_position, Vector2(330,114), 0.3)
				activate_tween = true
			elif time_key == "Fast":
				if monster_key == "Ally" or monster_key == "Ally2":
					$allyArea/allySprite.rect_position = Vector2(18,114)
				else:
					$enemyArea/enemySprite.rect_position = Vector2(330,114)
				# in this case, there is no animation to wait on
				animations_playing -= 1
		elif key == "End":
			emit_signal("done", value)
			print("ALL DONE!")
			get_tree().quit()
		elif key == "ExpBar":
			animations_playing += 1

			var value_split = value.split("+")
			var monster_key = value_split[0]
			var from = int(value_split[1])
			var to = int(value_split[2])

			var time = float(abs(from - to)) / 100.0 * 1.0
			
			$allyArea/allySummary/expProgress.value = from
			$Tween.interpolate_property($allyArea/allySummary/expProgress, "value", from, to, time)
			
			if monster_key == "Ally":
				$allyArea/allySummaryDouble/expProgressTop.value = from
				$Tween.interpolate_property($allyArea/allySummaryDouble/expProgressTop, "value", from, to, time)
			if monster_key == "Ally2":
				$allyArea/allySummaryDouble/expProgressBottom.value = from
				$Tween.interpolate_property($allyArea/allySummaryDouble/expProgressBottom, "value", from, to, time)

			activate_tween = true
		elif key == "FlashSummary":
			animations_playing += 1
			var value_split = value.split("+")
			var which_key = value_split[0]
			var direction_key = value_split[1]
			var s1
			var s2
			if which_key == "Ally":
				s1 = $allyArea/allySummary/silhouette
				s2 = $allyArea/allySummaryDouble/silhouette
			else:
				s1 = $enemyArea/enemySummary/silhouette
				s2 = $enemyArea/enemySummaryDobule/silhouette
			if direction_key == "In":
				s1.visible = true
				s2.visible = true
				s1.self_modulate = Color(1.0,1.0,1.0,0.0)
				s2.self_modulate = Color(1.0,1.0,1.0,0.0)
				$Tween.interpolate_property(s1, "self_modulate", Color(1.0,1.0,1.0,0.0), Color(1.0,1.0,1.0,1.0), 0.2)
				$Tween.interpolate_property(s2, "self_modulate", Color(1.0,1.0,1.0,0.0), Color(1.0,1.0,1.0,1.0), 0.2)
			else:
				$Tween.interpolate_property(s1, "self_modulate", Color(1.0,1.0,1.0,1.0), Color(1.0,1.0,1.0,0.0), 0.2)
				$Tween.interpolate_property(s2, "self_modulate", Color(1.0,1.0,1.0,1.0), Color(1.0,1.0,1.0,0.0), 0.2)
			activate_tween = true
		elif key == "EndAnimations":
			animations_playing -= 1
			var value_split = value.split("+")
			var new_state = value_split[0]
			var focus = value_split[1]
			animation_queue = []
			setAllyFocus(focus)
			setMenuMode(new_state)
		elif key[0] == "[":
			# Skip over tags
			animations_playing -= 1

	if USUAL_PRINTS:
		print("waiting on " + str(animations_playing))
	if activate_tween:
		$Tween.start()

# Chooses the enemy moves and adds them to array of moves
func chooseEnemyMoves():
	# Set up the callback arguments for opponent menu
	var hook_args = {}

	hook_args["CHOOSING_KEY"] = "Enemy"
	hook_args["CHOOSING"] = enemy
	hook_args["CHOOSING_PARTNER_KEY"] = "Enemy2"
	hook_args["CHOOSING_PARTNER"] = enemy2
	hook_args["CHOOSING_OPPONENT_KEY"] = "Ally"
	hook_args["CHOOSING_OPPONENT"] = ally
	hook_args["CHOOSING_OPPONENT2_KEY"] = "Ally2"
	hook_args["CHOOSING_OPPONENT2"] = ally2

	# Select opponents' moves

	# Pick a move using AI for each opponent
	var move
	# how many times will a move be chosen (e.g. a move will be chosen twice if there are 2 enemies)
	var times = 1
	if enemy2:
		times = 2
	
	var index = 0
	while index < times:
		# pick move from either enemy or enemy2 depending on use
		match index:
			0:
				move = enemy.moves[rng.randi_range(0, len(enemy.moves)-1)]
				move.state.owner_key = "Enemy"
			1:
				move = enemy2.moves[rng.randi_range(0, len(enemy2.moves)-1)]	
				move.state.owner_key = "Enemy2"
		
		# refresh the move state
		move.state.reset()
		
		# Pick a target depending on number of targets
		match move.targets:
			0:
				move.state.target_key = "None"
			1:
				if ally2 and rng.randi_range(0,1) == 0:
					move.state.target_key = "Ally2"
				else:
					move.state.target_key = "Ally"
			2:
				move.state.target_key = "Ally"
		turn_actions.append(move.state)
		index += 1

func handleFainting():
	# What to do at the end of the turn if things faint
	for battler in ["Ally", "Enemy"]:
	
		var monster
		var monster2
		var monster_previous
		var monster2_previous
		var monster_party_index
		var monster2_party_index
		var party
		
		# Set the relevant variables depending on who we are dealing with
		if battler == "Ally":
			monster = ally
			monster2 = ally2
			monster_previous = ally
			monster2_previous = ally2
			monster_party_index = ally_party_index
			monster2_party_index = ally2_party_index
			party = PlayerData.party
		else:
			monster = enemy
			monster2 = enemy2
			monster_previous = enemy
			monster2_previous = enemy2
			monster_party_index = enemy_party_index
			monster2_party_index = enemy2_party_index
			party = encounter.party
	
		if purpose == "Person" or battler == "Ally":
			# Check all of the monsters
			for party_member in [monster, monster2]:
				# If there is no monster2, move along
				if not party_member:
					continue

				# If the member has 0 hp, replace it
				if party_member.hp == 0:

					# remove the fainted monster's states from the counter
					var states = party_member.get_all_states()
					for s in states:
						detachState(s)
					
					for i in range(len(party)):
						if party[i].hp > 0 and party[i] != monster and party[i] != monster2:
							if party_member == monster:
								monster = party[i]
								monster_party_index = i
								monster.update_state_owner_keys(battler)
							else:
								monster2 = party[i]
								monster2_party_index = i
								monster2.update_state_owner_keys(battler + "2")
								
							# add the new monster's states to the counter
							states = party[i].get_all_states()
							for s in states:
								attachState(s)
							
							break
					
		
		# Swap monsters or end the battle according to needs
		
		# If all monsters are still fainted after swapping from party,
		# end the battle
		if monster.hp == 0 and (not monster2 or monster2.hp == 0):
			# Needs to be modified for trainer battles
			if battler == "Ally":
				animation_queue.append("End:Lose")
			else:
				if purpose == "Person":
					animation_queue.append("Txt:You have defeated " + encounter.name + "&Wait:1")
					animation_queue.append("PersonAppear:Enemy")
					animation_queue.append("Txt:" + encounter.lose_message + "&Wait:1")
					animation_queue.append("Txt:" + encounter.name + " paid you $" + str(encounter.money) + " for winning.&Wait:1")
				animation_queue.append("End:Win")

		# If monster is fainted and monster2 is not, then turn it
		# into a single battle on the appropriate side where monster is
		# the only fighting monster
		elif monster.hp == 0 and monster2 and monster2.hp > 0:
			monster = monster2
			monster_party_index = monster2_party_index
			monster2 = null
			animation_queue.append("SwapSummary:" + battler + "Single+" + str(monster_party_index) + "+" + str(monster.getHpPercent()) \
			+ "&SwapMonsterSprite:" + battler + "+" + monster.species + "&DoubleToSingle:" + battler + "2+Slow&SummaryAppear:" + battler)
			# update state owner keys and update the attached states array
			monster.update_state_owner_keys(battler)
			attached_states[battler] = attached_states[battler + "2"]
			attached_states[battler + "2"] = []

		# If monster is present but monster2 is fainted, then turn it into a single battle
		# on monster's side This could either be due to a switch in, or monster2
		# fainting when the enemy is on the battlefield
		elif monster.hp > 0 and monster2 and monster2.hp == 0:
			# No more enemy2
			monster2 = null
			# If monster did not faint, shift it to the center
			if monster == monster_previous:
				animation_queue.append("DoubleToSingle:" + battler + "+Slow&SummaryAppear:" + battler)
			# If monster did faint, send it out but in the midde
			else:
				if battler == "Enemy":
					animation_queue.append("Txt:" + encounter.name + " sent out " + get_enemy_nickname(monster))
				else:
					animation_queue.append("Txt:You send out " + monster.name)
				
				animation_queue.append("SwapSummary:" + battler + "Single+" + str(monster_party_index) + "+" + str(monster.getHpPercent()) \
				+ "&SummaryAppear:" + battler + "&MonAnimate:" + battler + "+Appear&SwapMonsterSprite:" + battler + "+" + monster.species + "&DoubleToSingle:" + battler + "+Fast")

		# Otherwise, if any party members were swapped, do the appropriate animation
		elif monster != monster_previous or monster2 != monster2_previous:
			# If there is still a previous monster out, make the summary box disappear
			if monster_previous.hp > 0 or (monster2 and monster2_previous.hp > 0):
				# The wait is here because the summary box may already be down
				# whereby no animation would play and it would freeze.
				# it's kind of a workaround but it works
				animation_queue.append("Wait:0.1&SummaryDisappear:" + battler)
			
			# Switch in for single battles:
			if not monster2:
				if battler == "Enemy":
					animation_queue.append("Txt:" + encounter.name + " sent out " + get_enemy_nickname(monster))
				else:
					animation_queue.append("Txt:You send out " + monster.name)
				animation_queue.append("SwapSummary:" + battler + "Single+" + str(monster_party_index) + "+" + str(monster.getHpPercent()) \
				+ "&SummaryAppear:" + battler + "&MonAnimate:" + battler + "+Appear&SwapMonsterSprite:" + battler + "+" + monster.species)
			
			# If monster switches but not monster2
			if monster != monster_previous and monster2 and monster2 == monster2_previous:
				if battler == "Enemy":
					animation_queue.append("Txt:" + encounter.name + " sent out " + get_enemy_nickname(monster))
				else:
					animation_queue.append("Txt:You send out " + monster.name)
				animation_queue.append("SwapSummary:" + battler + "DoubleTop+" + str(monster_party_index) + "+" + str(monster.getHpPercent()) \
				+ "&SummaryAppear:" + battler + "&MonAnimate:" + battler + "+Appear&SwapMonsterSprite:" + battler + "+" + monster.species)
			
			# If monster2 switches but not monster
			if monster == monster_previous and monster2 != monster2_previous:
				if battler == "Enemy":
					animation_queue.append("Txt:" + encounter.name + " sent out " + get_enemy_nickname(monster2))
				else:
					animation_queue.append("Txt:You send out " + monster2.name)
				animation_queue.append("SwapSummary:" + battler + "DoubleBottom+" + str(monster2_party_index) + "+" + str(monster2.getHpPercent()) \
				+ "&SummaryAppear:" + battler + "&MonAnimate:" + battler + "2+Appear&SwapMonsterSprite:" + battler + "2+" + monster2.species)

			# If both monsters switch
			if monster != monster_previous and monster2 != monster2_previous:
				if battler == "Enemy":
					animation_queue.append("Txt:" + encounter.name + " sent out " + get_enemy_nickname(monster) + " and " + get_enemy_nickname(monster2))
				else:
					animation_queue.append("Txt:You send out " + monster.name + " and " + monster2.name)
				animation_queue.append("SwapSummary:" + battler + "DoubleTop+" + str(monster_party_index) + "+" + str(monster.getHpPercent()) \
				+ "&SwapSummary:" + battler + "DoubleBottom+" + str(monster2_party_index) + "+" + str(monster2.getHpPercent()) \
				+ "&SummaryAppear:" + battler + "&MonAnimate:" + battler + "+Appear&MonAnimate:" + battler + "2+Appear" \
				+ "&SwapMonsterSprite:" + battler + "+" + monster.species + "&SwapMonsterSprite:" + battler + "2+" + monster2.species)
		# end elif enemy != enemy_previous or enemy2 != enemy2_previous
		
		if monster != monster_previous:
			# breakpoint onSwitchIn
			pass
		
		if monster != monster_previous:
			# breakpoint onSwitchIn
			pass
		
		# Set the variables which have been changed back
		if battler == "Ally":
			ally = monster
			ally2 = monster2
			ally_party_index = monster_party_index
			ally2_party_index = monster2_party_index
		else:
			enemy = monster
			enemy2 = monster2
			enemy_party_index = monster_party_index
			enemy2_party_index = monster2_party_index

# For an action, generate a number to determine which goes first or second
# the higher the number, the more likely it is to go first
func setMoveValues(action):
	if action.has_been_used:
		return

	if should_do_hook("OnMoveValuesDetermined"):
		var values = {}
		values["PRIORITY"] = action.move.priority
		values["SPEED"] = get_monster_value(action.owner_key, "Speed", "Move Speed Number", action.target_key, action.owner_key, action.id)
		values["LUCK"] = rng.randi_range(0,999999)
		values["TYPE"] = action.move.type
		values["MODE"] = action.move.mode
		values["POWER"] = action.move.power

		# Set up the hook args
		var args = get_target_user_state_arguments(action.target_key, action.owner_key)
		get_value_state_arguments(values, args)
		get_state_identity_arguments(action, args)
		
		values = hook("OnMoveValuesDetermined", args, "Value")[1]
		
		# set the action numbers based on the hook
		action.priority = values["PRIORITY"]
		action.speed = values["SPEED"]
		action.luck = values["LUCK"]
		action.type = values["TYPE"]
		action.mode = values["MODE"]
		action.power = values["POWER"]
	else:
		action.priority = action.move.priority
		action.speed = get_monster_value(action.owner_key, "Speed", "Move Speed Number", action.target_key, action.owner_key, action.id)
		action.luck = rng.randi_range(0,999999)
		action.type = action.move.type
		action.mode = action.move.mode
		action.power = action.move.power

# Executes the moves. Does math and animatinos. This function is a big deal
func doActionStep():

	# Before doing anything, pause for a second or else it looks weird
	$MainTextBox/MainText.text = ""
	animation_queue.append("Wait:0.1")

	chooseEnemyMoves()

	# Consider all of the queued moves as valid states for this turn
	for a in turn_actions:
		attachState(a)

	# Perform actions!

	while true:
		# Stores all of the actions that could possibly go next
		# (this is a list in case there are multiple moves which tie in both priority and speed)
		var possible_next_actions = []
		
		# Fill out the list
		for a in turn_actions:
			
			if a.has_been_used:
				continue
			
			setMoveValues(a)
			
			if len(possible_next_actions) == 0:
				possible_next_actions.append(a)
			else:
				var rep = possible_next_actions[0]
				if a.priority < rep.priority:
					continue
				elif a.priority > rep.priority:
					possible_next_actions = [a]
				else:
					if a.speed < rep.speed:
						continue
					elif a.speed > rep.speed:
						possible_next_actions = [a]
					else:
						possible_next_actions.append(a)

		# This means we are done using actions
		if possible_next_actions == []:
			break
			
		var next_action = possible_next_actions[rng.randi_range(0, len(possible_next_actions)-1)]
		
		# evaluate the next action
		var action_args = get_universal_state_arguments(next_action, "OnMoveMainCode")
		get_target_user_state_arguments(next_action.target_key, next_action.owner_key, action_args)

		evaluate_state_code(next_action.main_code, action_args)
		next_action.has_been_used = true

	if USUAL_PRINTS:
		print("-----------")
		print("ally states")
		for s in ally.get_all_states():
			print(s.name)
		print("ally2 states")
		for s in ally2.get_all_states():
			print(s.name)
		print("------------")
	
	hook("OnTurnEnd")
	
	handleFainting()
	
	# remove actions from hook counter
	for a in turn_actions:
		detachState(a)
	
	# clear out the turn actions
	turn_actions = []
	
	# remove animation at the end if it should be removed
	if animation_queue[len(animation_queue) - 1].find("[RemoveIfAtEnd]") != -1:
		animation_queue.pop_back()

	# end for battler in ["Ally", "Enemy"]
	
	animation_queue.append("Wait:1")
	animation_queue.append("EndAnimations:Main+Ally")
	call_deferred("play_queued_animation")

# ------------------------------------------------------------------------------
#                     ACTION FUNCTIONS
# ------------------------------------------------------------------------------

func perform_action(action, hook_stack):
	if USUAL_PRINTS:
		print(action.identify() + ";" + str(action.parameters))
	
	var params = action.parameters # just makes it easier to write.
	
	match action.opcode:

		action_template.Animation_:
			var animations = params[0].split(";")
			for a in animations:
				animation_queue.append(a)

		action_template.ApplyState:
			# these args apply to both onOtherStateApplied and onAfterStateApplied
			var hook_args

			var state_name = params[0]
			var target_key = params[2]
			var user_key = params[3]

			var user = get_monster_from_key(user_key)
			var state = StaticData.get_state_data(state_name)

			if should_do_hook("OnOtherStateApplied") or state.has_constructor or should_do_hook("OnAfterStateApplied"):
				hook_args = get_argument_dictionary_from_action(action)
				get_target_user_state_arguments(target_key, user_key, hook_args)
				get_state_identity_arguments(state, hook_args)
			
			if should_do_hook("OnOtherStateApplied"):
				var on_other_applied_output = hook("OnOtherStateApplied", hook_args, "Normal", hook_stack)
				if on_other_applied_output[0] == "Squash":
					return get_action_return_value_from_hook_result(on_other_applied_output)
			
			var target
			if target_key in ["Ally", "Ally2", "Enemy", "Enemy2"]:
				target = get_monster_from_key(target_key)
			
			# Tell the state who owns it
			state.owner_key = target_key
			
			# Run the constructor for the state, if it has one
			# hook OnApplication
			if state.has_constructor:
				
				# set up the constructor args
				var constructor_args = get_universal_state_arguments(state, "OnApplication")
				zip_dicts(constructor_args, hook_args) # include the hook args in the constructor args
				zip_dicts(constructor_args, params[1]) # include the constructor args from a parameter in the constructor args

				# Find and execute the listeners
				var listeners = state.get_relevant_event_listeners("OnApplication")
				var constructor_output
				for l in listeners:
					constructor_output = evaluate_state_code(l.code, constructor_args)
					# the constructor can squash to prevent the state from being applied
					if constructor_output[0] == "Squash":
						break
				if constructor_output[0] == "Squash":
					return get_action_return_value_from_hook_result(constructor_output)
			
			# Apply the actual state

			# Add state to its relevant owner
			if target:
				target.temporary_states.append(state)
			elif target_key == "Battlefield":
				room_states.append(state)
			elif target_key == "AllySide":
				ally_states.append(state)
			elif target_key == "EnemySide":
				enemy_states.append(state)

			# Attach the state's listeners
			attachState(state)

			# the state which was just attached can actually attach to this hook. If we checked if this
			# state should run before the state is applied when setting the arguments, it may return a false
			# negative because it would not account for the state which is applied by this action, thus
			# we check for it here.
			if should_do_hook("OnAfterStateApplied"):
				hook("OnAfterStateApplied", hook_args, "Normal", hook_stack)

		action_template.Damage:

			var damage_amount = params[0]
			var target_key = params[1]
			var user_key = params[2]
			var type = params[3]
			var form = params[4]

			var hook_args
			if should_do_hook("OnEffectDamage") or should_do_hook("OnEffectDamageValuesDetermined") or should_do_hook("OnAfterEffectDamage"):
				hook_args = get_argument_dictionary_from_action(action)
				get_target_user_state_arguments(target_key, user_key, hook_args)

			if should_do_hook("OnEffectDamageValuesDetermined"):
				var vals = {"DAMAGE_AMOUNT" : damage_amount, "TYPE_VALUE" : type, "FORM_VALUE" : form}
				get_value_state_arguments(vals, hook_args)
				var hook_output = hook("OnEffectDamageAmountDetermined", hook_args, "Value", hook_stack)
				damage_amount = hook_output["DAMAGE_AMOUNT"]
				type = hook_output["PERCEIVED_TYPE"]
				form = hook_output["FORM_VALUE"]
				clear_value_arguments(hook_args)
				
			if hook_args:
				hook_args["DAMAGE_AMOUNT"] = damage_amount
				hook_args["PERCEIVED_TYPE"] = type
				hook_args["FORM_VALUE"] = form

			if should_do_hook("OnEffectDamage"):
				var hook_output = hook("OnEffectDamage", hook_args, "Normal", hook_stack)
				if hook_output[0] == "Squash":
					return get_action_return_value_from_hook_result(hook_output)

			var damage_output = deal_damage(damage_amount, target_key, user_key, 1, type, form, hook_stack)
			if damage_output[0] == "Squash":
				return get_action_return_value_from_hook_result(damage_output)
			
			if hook_args:
				hook_args["DEALT_DAMAGE_AMOUNT"] = damage_output[1]

			hook("OnAfterEffectDamage", hook_args, "Normal", hook_stack)
		
		action_template.Hit:

			var power = params[0]
			var type = params[1]
			var perceived_type = type # Does not affect damage amounts. Used only for the deal_damage function.
			var mode = params[2]
			var target_key = params[3]
			var user_key = params[4]
			var owner_id = params[6]

			var target = get_monster_from_key(target_key)
			var user = get_monster_from_key(user_key)

			var hook_args
			if should_do_hook("OnHitComponentsDetermined") or should_do_hook("OnHitDamageDetermined") or should_do_hook("OnHit") or should_do_hook("OnAfterHit"):
				hook_args = get_argument_dictionary_from_action(action)
				get_target_user_state_arguments(target_key, user_key, hook_args)

			# Does it hit with attack or wisdom?
			var strength = -1
			var form
			if mode == "Mana":
				strength = get_monster_value(user_key, "Attack", "Mana Hit Attack", target_key, user_key, owner_id, {}, hook_stack)
				form = "Contact"
			else:
				strength = get_monster_value(user_key, "Wisdom", "Mana Hit Attack", target_key, user_key, owner_id, {}, hook_stack)
				form = "Special"

			var defense = get_monster_value(target_key, "Defense", "Hit Defense", target_key, user_key, owner_id, {}, hook_stack)
			
			# Same type attack bonus
			var stab = 1.0
			if type == user.type1 or type == user.type2:
				stab = 1.5
			
			# Is it super / not very effective?
			var type_multiple = 1.0
			type_multiple *= StaticData.get_type_multiplier(type, target.type1)
			if target.type2 != "":
				type_multiple *= StaticData.get_type_multiplier(type, target.type2)

			# in case one wants to multiply damage for miscellaneous reasons
			var misc_multiple = 1

			if should_do_hook("OnHitComponentsDetermined"):
				var components_dict = {}
				components_dict["POWER_VALUE"] = power
				components_dict["STAB"] = stab
				components_dict["STRENGTH_STAT"] = strength
				components_dict["DEFENSE_STAT"] = defense
				components_dict["TYPE_MULTIPLIER"] = type_multiple
				components_dict["MISC_MULTIPLIER"] = misc_multiple
				components_dict["PERCEIVED_TYPE"] = perceived_type
				components_dict["FORM_VALUE"] = form
				
				get_value_state_arguments(components_dict, hook_args)
				
				components_dict = hook("OnHitComponentsDetermined", hook_args, "Value", hook_stack)[1]
				
				power = components_dict["POWER_VALUE"]
				stab = components_dict["STAB"]
				strength = components_dict["STRENGTH_STAT"]
				defense = components_dict["DEFENSE_STAT"]
				type_multiple = components_dict["TYPE_MULTIPLIER"]
				misc_multiple = components_dict["MISC_MULTIPLIER"]
				perceived_type = components_dict["PERCEIVED_TYPE"]
				form = components_dict["FORM_VALUE"]
				
				clear_value_arguments(hook_args)
			
			var damage = int( ceil( float(power) * strength / defense * stab * type_multiple ))

			if should_do_hook("OnHitDamageDetermined") or should_do_hook("OnHit") or should_do_hook("OnAfterHit"):
				hook_args["POWER_VALUE"] = power
				hook_args["STAB"] = stab
				hook_args["STRENGTH_STAT"] = strength
				hook_args["DEFENSE_STAT"] = defense
				hook_args["TYPE_MULTIPLIER"] = type_multiple
				hook_args["MISC_MULTIPLIER"] = misc_multiple
				hook_args["PERCEIVED_TYPE"] = perceived_type
				hook_args["FORM_VALUE"] = form

			if should_do_hook("OnHitDamageDetermined"):
				get_value_state_arguments(damage, hook_args)
				damage = hook("OnHitDamageDetermined", hook_args, "Value", hook_stack)[1]
				
				clear_value_arguments(hook_args)
			
			if should_do_hook("OnHit") or should_do_hook("OnAfterHit"):
				hook_args["DAMAGE_AMOUNT"] = damage
			
			if should_do_hook("OnHit"):
				var onhit_return = hook("OnHit", hook_args, "Normal", hook_stack)
				if onhit_return[0] == "Squash":
					return get_action_return_value_from_hook_result(onhit_return)
			
			deal_damage(damage, target_key, user_key, type_multiple, perceived_type, form, hook_stack)
		
			hook("OnAfterHit", hook_args, "Normal", hook_stack)
		
		action_template.Move:
			# this needs to be completely rewritten
			pass
		action_template.RemoveState:
			# Parse parameters
			var user_key = params[0]
			var user = get_monster_from_key(user_key)
			
			var state_name = params[1]
			var target_key = params[2]
			
			# Get the target user args
			var state_args = null#get_target_user_state_arguments(target_key, user_key)
			
			# Get the list of all of the states posessed by the target
			var target_state_list
			var target

			if target_key in ["Ally", "Ally2", "Enemy", "Enemy2"]:
				target = get_monster_from_key(target_key)
				target_state_list = target.temporary_states
			elif target_key == "AllySide":
				target_state_list = ally_states
			elif target_key == "EnemySide":
				target_state_list = enemy_states
			elif target_key == "Battlefield":
				target_state_list = room_states

			# Scroll through states owned by the target and pull the ones which match
			var index = 0
			while index < len(target_state_list):
				if target_state_list[index].name == state_name:
					var state = target_state_list[index]
					state_args["STATE"] = state
					state_args["STATE_NAME"] = state.name
					state_args["STATE_ID"] = state.id
					
					# hook OnOtherStateRemoved
					
					# hook OnRemoved
					if state.has_destructor:
						var listeners = null#get_relevant_listeners_from_states_sorted([state], "OnRemoved")
						var squashed = false
						for l in listeners:
							var destructor_output = evaluate_state_code(l.code, state_args)
							if destructor_output[0] == "Squash":
								squashed = true
								break
						
						# If the removal is squashed, keep going, otherwise, remove the state
						if squashed:
							index += 1
						else:
							# Remove the state and free it from memory
							target_state_list.pop_at(index)
					else:
						target_state_list.pop_at(index)
				else:
					index += 1
	return "Keep"

func deal_damage(damage, target_key, user_key, type_multiple, type, form, hook_stack):

	var hook_args
	if should_do_hook("OnDamageValuesDetermined") or should_do_hook("OnDamage") or should_do_hook("OnAfterDamage"):
		hook_args = get_target_user_state_arguments(target_key, user_key)

	if should_do_hook("OnDamageValuesDetermined"):
		var vals = {}
		vals["DAMAGE"] = damage
		vals["TYPE"] = type
		vals["FORM"] = form

		get_value_state_arguments(vals, hook_args)
		vals = hook("OnDamageValuesDetermined", hook_args, "Value", hook_stack)

		damage = vals["DAMAGE"]
		type = vals["TYPE"]
		form = vals["FORM"]

		clear_value_arguments(hook_args)

	if should_do_hook("OnDamage"):
		hook_args["DAMAGE"] = damage
		hook_args["TYPE"] = type
		hook_args["FORM"] = form
		var hook_return = hook("OnDamage", hook_args, "Normal", hook_stack)
		return hook_return
	
	var target = get_monster_from_key(target_key)
	var target_name = target.name
	if target_key == "Enemy" or target_key == "Enemy2":
		target_name = "Enemy " + target.name
	
	var initial_percent = str(target.getHpPercent())
	
	# breakpoint onDamageDealt
	target.hp -= damage
	if target.hp <= 0:
		target.hp = 0
	var final_percent = str(target.getHpPercent())
	
	# Set the resulting animations
	animation_queue.append("MonAnimate:" + target_key + "+Blink&Wait:1")
	animation_queue.append("Healthbar:" + target_key + "+" + initial_percent + "+" + final_percent)
	
	if type_multiple != 1:
		if type_multiple > 1:
			animation_queue.append("Txt:" + target_name + " was weak to this move&Wait:1")
		elif type_multiple < 1:
			animation_queue.append("Txt:" + target_name + " resisted this move&Wait:1")

	# Handle fainting
	if target.hp == 0:
		# breakpoint onMonsterFaint
		
		# Animate the fainting monster
		var summary_target = ""
		if target_key == "Ally" or target_key == "Ally2":
			summary_target = "Ally"
		elif target_key == "Enemy" or target_key == "Enemy2":
			summary_target = "Enemy"
		animation_queue.append("MonAnimate:" + target_key + "+Disappear&SummaryDisappear:" + summary_target + "&Wait:1")
		animation_queue.append("Txt:" + target_name + " fainted.&Wait:1")
		get_monster_from_key(target_key).clear_temporary_states()

		# Handle experience yield
		if target == enemy or target == enemy2:

			# Calculate the experience yield
			var experience_yield = target.stat_total * target.level
			if format == "Person":
				experience_yield = int( floor( float(experience_yield) * 1.5 ) )
			if ally.hp > 0 and ally2 and ally2.hp > 0:
				experience_yield /= 2
				
			# Give experience to allies
			give_experience("Ally", experience_yield)
			give_experience("Ally2", experience_yield)

		# If its a double battle and one monser faints, make the relevant box adjustement
		# The text is marked with a [RemoveIfAtEnd] to show that if, at the end of adjustements, this
		# is the final thing in the animation queue, it should be removed
		if ((target_key == "Ally2" and ally.hp > 0) or (target_key == "Ally" and ally2 and ally2.hp > 0) \
		or (target_key == "Enemy2" and enemy.hp > 0) or (target_key == "Enemy" and enemy2 and enemy2.hp > 0)):

			# Put up the summary box but with the correct value
			var summary_swap_code = ""
			var summary_appear_code = ""
			if target_key == "Ally":
				summary_swap_code = "SwapSummary:AllySingle+" + str(ally2_party_index) + "+" + str(ally2.getHpPercent()) + "+" + str(ally2.level)
				summary_appear_code = "SummaryAppear:Ally"
			elif target_key == "Ally2":
				summary_swap_code = "SwapSummary:AllySingle+" + str(ally_party_index) + "+" + str(ally.getHpPercent()) + "+" + str(ally.level)
				summary_appear_code = "SummaryAppear:Ally"
			if target_key == "Enemy":
				summary_swap_code = "SwapSummary:EnemySingle+" + str(enemy2_party_index) + "+" + str(enemy2.getHpPercent()) + "+" + str(enemy2.level)
				summary_appear_code = "SummaryAppear:Enemy"
			if target_key == "Enemy2":
				summary_swap_code = "SwapSummary:EnemySingle+" + str(enemy_party_index) + "+" + str(enemy.getHpPercent())  + "+" + str(enemy.level)
				summary_appear_code = "SummaryAppear:Enemy"
			animation_queue.append("[RemoveIfAtEnd]&" + summary_swap_code + "&" + summary_appear_code)
	
	if should_do_hook("OnAfterDamage"):
		hook("OnAfterDamage", hook_args, "Normal", hook_stack)
	
	return ["Keep", damage]

func give_experience(recipient_key, experience_yield):
	var recipient = get_monster_from_key(recipient_key)
	
	# Do not give experience to fainted / not present allies
	if not recipient or recipient.hp == 0 or recipient.level == StaticData.max_monster_level:
		return
	
	var experience_yield_remaining = experience_yield
	
	animation_queue.append("Txt:" + recipient.name + " gained " + str(experience_yield) + " experience!")
	
	# Keep leveling up while experience is present
	while experience_yield_remaining > 0:
		
		# See if the current yield is enough to level up or not
		var discrepency = recipient.experience_next - recipient.experience
		# The initial percent that the exp bar is at
		var initial_exp_percent = recipient.getExpPercent()
		var level_up = false
		# If it's not enough to level up, add the experience to the monster
		if discrepency > experience_yield_remaining:
			recipient.experience += experience_yield_remaining
			experience_yield_remaining = 0
			animation_queue.append("ExpBar:" + recipient_key + "+" + str(initial_exp_percent) + "+" + str(recipient.getExpPercent()) + "&Wait:0.5")
		# If it is enough to level up, then do so
		else:
			recipient.level += 1
			experience_yield_remaining -= discrepency
			animation_queue.append("ExpBar:" + recipient_key + "+" + str(initial_exp_percent) + "+100" + "&Wait:0.5")
			animation_queue.append("FlashSummary:Ally+In")
			var box_key
			var party_index
			if recipient == ally:
				party_index = ally_party_index
				if ally2 and (ally2.hp > 0):
					box_key = "AllyDoubleTop"
				else:
					box_key = "AllySingle"
			else:
				party_index = ally2_party_index
				if ally.hp > 0:
					box_key = "AllyDoubleBottom"
				else:
					box_key = "AllySingle"
			animation_queue.append("SwapSummary:" + box_key + "+" + str(party_index) + "+" + str(recipient.getHpPercent()) + "+" + str(recipient.level) + "&FlashSummary:Ally+Out&ExpBar:" + recipient_key + "+0+0")
			animation_queue.append("Txt:" + recipient.name + " grew to level " + str(recipient.level) + "&Wait:1")
			
			# This updates the stats and returns new moves that are learned
			var new_moves = recipient.update_to_level()
			for m in new_moves:
				# If no new moves are learned, m will still take one value of null.
				# We need to do nothing in that case
				if not m:
					continue
				
				# If the monster already knows the move, skip over this
				var already_has = false
				for e in recipient.moves:
					if e.name == m.name:
						already_has = true
						break
				if already_has:
					continue
					
				# Learn the move or ask depending on how many moves the monster knows
				if len(recipient.moves) < 4:
					recipient.moves.append(m)
					animation_queue.append("Txt:" + recipient.name + " learned " + m.name + "&Wait:1")
				else:
					# TODO: more than 4 moves. Requires an up to date party / summary screen
					pass

# ------------------------------------------------------------------------------
#                     BATTLE SPECIFIC STATE CODE
# ------------------------------------------------------------------------------

func evaluate_state_code(code, parameters):
	var output = ["Keep", null]
	
	# we clone the code because otherwise you would be evaluating original node
	# which physically modifies it. Normally this wouldn't be a big deal because
	# you could just reset it at the end, but potentially you would want to have
	# the same state activate multiple times in the same chain, which would not
	# be possible under those circumstances. Thus, we clone the code before
	# running it.
	var code_clone = code.clone()
	
	# This is for chain blocks
	parameters["LAST_RESULT"] = "Keep"
	
	var next_action = code_clone.eval(parameters)
	while next_action:
		
		match next_action.opcode:
			action_template.GetMonsterProperty:
			
				# note that the order of parameters 7 and 6 are swapped here because they need to be
				# in the corresponding function. This is because owner id is optional for the action
				# but not for the get_monster_value function written in this script
				parameters["VARIABLES"][ next_action.parameters[0] ] = \
				get_monster_value(next_action.parameters[1], next_action.parameters[2], \
				next_action.parameters[3], next_action.parameters[4], next_action.parameters[5], \
				next_action.parameters[7], next_action.parameters[6], parameters["STACK"])
			
			action_template.Return:
				output[1] = next_action.parameters[0]
				return output
			action_template.Keep:
				output[0] = "Keep"
				if len(next_action.parameters) > 0:
					output[1] = next_action.parameters[0]
					return output
			action_template.Squash:
				output[0] = "Squash"
				if len(next_action.parameters) > 0:
					output[1] = next_action.parameters[1]
					return output
			action_template.Text:
				animation_queue.append("Txt:" + next_action.parameters[0])
			action_template.Set, action_template.Print:
				pass # these should be handled in the eval function
			_:
				parameters["LAST_RESULT"] = perform_action(next_action, parameters["STACK"])

		next_action = code_clone.eval(parameters)

	return output

func hook(hook_name, additional_args = {}, type = "Normal", hook_stack = []):
	# If nothing will hook on, then don't do the hook
	if not hook_name in attached_listeners.keys():
		return ["Keep", null]

	# Set variables about menu type
	var menu_hook = (type == "Menu")
	var value_hook = (type == "Value")

	# Whether or not any listeners were considered during this hook
	# (only used for menu hooks)
	var any_listeners_considered = false
	
	# Set up an output that gets returned in the event that no hooks do anything.
	var output = ["Keep", null]
		
	if value_hook:
		output[1] = additional_args["CURRENT_VALUE"]
	
	# for number hooks, the initial value passed in is given as the return value
	
	# Execute each state's code
	var finished_listeners = []
	var listener = get_next_relevant_listener(hook_name, finished_listeners, INF)
	var max_precedence_allowed = listener.precedence
	
	while listener:
		# For menu states, skip them if they have already been completed
		if menu_hook:
			if listener.menu_checked:
				finished_listeners.append(listener)
				max_precedence_allowed = listener.precedence
				listener = get_next_relevant_listener(hook_name, finished_listeners, max_precedence_allowed)
				continue
			else:
				listener.menu_checked = true
		
		any_listeners_considered = true
		
		# Get the universal parameters (i.e. SELF)
		# TODO hook stack
		var args = get_universal_state_arguments(listener.owning_state, hook_name, hook_stack)
		
		# Pass in any additional parameters
		zip_dicts(args, additional_args)
		
		if not "TARGET_KEY" in args.keys():
			args["TARGET_KEY"] = "State"
			args["USER_KEY"] = "State"
		
		# Run the state code
		var state_code_output = evaluate_state_code(listener.code, args)
		
		# pop the back of the hook stack (because it was modified by get_universal_state_arguments)
		hook_stack.pop_back()
		
		# update output code and return value
		output[0] = state_code_output[0]
		var code_return_value = state_code_output[1]
		if code_return_value:
			output[1] = code_return_value
			if value_hook:
				additional_args["CURRENT_VALUE"] = code_return_value

		# If we are squashing, then return
		if output[0] == "Squash":
			
			# If a menu hook is squashed, reset all of the menu hooks
			# because the menu mode that triggered the hook will not
			# be revisited (because it was squashed)
			if menu_hook:
				print("resetting all menu listeners due to squash")
				for l in attached_listeners[hook_name]:
					l.menu_checked = false
			
			return output
	
		finished_listeners.append(listener)
		max_precedence_allowed = listener.precedence
		listener = get_next_relevant_listener(hook_name, finished_listeners, max_precedence_allowed)
	
	# Once done, if in a menu state and nothing happened, set all
	# menu hooks back to unchecked
	if menu_hook and not any_listeners_considered:
		print("resetting all menu listeners due to keep")
		for l in attached_listeners[hook_name]:
			l.menu_checked = false

	return output

# ------------------------------------------------------------------------------
#                     ANIMATION SIGNALS
# ------------------------------------------------------------------------------

func on_any_animation_terminate(z):
	if mode == "Animation":
		if USUAL_PRINTS:
			print(z)
		animations_playing -= 1
		if animations_playing < 0:
			print("NEGATIVE!")
		if animations_playing == 0:
			animation_queue.pop_front()
			if len(animation_queue) > 0:
				play_queued_animation()

func _on_Tween_tween_completed(object, key):
	on_any_animation_terminate("tween")

func _on_Timer_timeout():
	# another wrapper ...
	on_any_animation_terminate("timer")

func _on_AnimationPlayer_animation_finished(anim_name):
	if (anim_name == "Expand Box" or anim_name == "Contract Box") and mode.substr(0,10) == "Transition":
		# Transition animations
		setMenuMode(mode.substr(mode.find(":")+1))
	else:
		# General Animations
		on_any_animation_terminate(anim_name)

func on_hpBar_value_change(value, bar_key):
	var bar
	if bar_key == "Ally Single":
		$allyArea/allySummary/percentLabel.text = str(int(value)) + "%"
		bar = $allyArea/allySummary/hpProgress
	elif bar_key == "Ally Double Top":
		$allyArea/allySummaryDouble/percentLabelTop.text = str(int(value)) + "%"
		bar = $allyArea/allySummaryDouble/hpProgressTop
	elif bar_key == "Ally Double Bottom":
		$allyArea/allySummaryDouble/percentLabelBottom.text = str(int(value)) + "%"
		bar = $allyArea/allySummaryDouble/hpProgressBottom
	elif bar_key == "Enemy Single":
		$enemyArea/enemySummary/percentLabel.text = str(int(value)) + "%"
		bar = $enemyArea/enemySummary/hpProgress
	elif bar_key == "Enemy Double Top":
		$enemyArea/enemySummaryDouble/percentLabelTop.text = str(int(value)) + "%"
		bar = $enemyArea/enemySummaryDouble/hpProgressTop
	elif bar_key == "Enemy Double Bottom":
		$enemyArea/enemySummaryDouble/percentLabelBottom.text = str(int(value)) + "%"
		bar = $enemyArea/enemySummaryDouble/hpProgressBottom

	if value > 50:
		bar.texture_progress.region = Rect2(0,0,96,6)
	elif value > 25:
		bar.texture_progress.region = Rect2(0,8,96,6)
	else:
		bar.texture_progress.region = Rect2(0,16,96,6)

# ------------------------------------------------------------------------------
#                INPUTS AND BUTTONS
# ------------------------------------------------------------------------------

func _input(event):
	if event.is_action_pressed("ui_accept"):
		if mode == "Animation" and len(animation_queue) > 0 and animation_queue[0] == "Block":
			# clear blocking if applicable
			on_any_animation_terminate("input")
		elif mode == "Target":
			onTargetSelected()
	elif event.is_action_pressed("ui_b"):
		if mode == "Target":
			turn_actions.pop_back()
			call_deferred("setMenuMode", "Main")
		elif mode == "Fight":
			setMenuMode("Main")
		elif mode == "Main":
			if $allyArea/allySprite2.has_focus:
				turn_actions = []
				setAllyFocus("Ally")
				# This is so that the hook runs again, even though the
				# menu mode is already main
				setMenuMode("Main")
				# If the menu mode main isn't immediately switched back,
				# then empty the queue because Ally has focus
	elif event.is_action_pressed("ui_up"):
		if mode == "Target" and $enemyArea/enemySprite2.has_focus:
			setEnemyFocus("Enemy")
	elif event.is_action_pressed("ui_down"):
		if mode == "Target" and $enemyArea/enemySprite.has_focus:
			setEnemyFocus("Enemy2")

# This is its own function because it takes up so much
# space and if it was inserted into the input function
# the input function would be unreadable.
func onTargetSelected():
	
	var target_key
	var user_key
	
	if $allyArea/allySprite.has_focus:
		user_key = "Ally"
	else:
		user_key = "Ally2"
	
	if $enemyArea/enemySprite.has_focus:
		target_key = "Enemy"
	else:
		target_key = "Enemy2"
	
	var hook_output = null
	
	# @hook OnTargetSelected
	if should_do_hook("OnTargetSelected"):
		var hook_args = get_target_user_state_arguments(target_key, user_key)
		hook_output = hook("OnTargetSelected", hook_args)

	# If behavior is to continue as normal
	if (not hook_output) or hook_output[0] != "Squash":
		var previous_action = turn_actions[len(turn_actions) - 1]
		if $enemyArea/enemySprite.has_focus:
			previous_action.target_key = "Enemy"
		else:
			previous_action.target_key = "Enemy2"

		if len(animation_queue) > 0:
			if ally2 and user_key == "Ally":
				animation_queue.append("EndAnimations:Main+Ally2")
			else:
				animation_queue.append("EndAnimations:Action+Neither")
			setMenuMode("Animation")
		else:
			if ally2 and user_key == "Ally":
				setAllyFocus("Ally2")
				# defer the call to not double press a button
				call_deferred("setMenuMode", "Main")
			else:
				setMenuMode("Action")
	else:
		# if there is a squash, and there are animations, then do the animating
		if len(animation_queue) > 0:
			animation_queue.append("EndAnimations:Target+" + user_key)
			setMenuMode("Animation")

func _on_FightButton_pressed():
	if mode == "Main":
		setMenuMode("Fight")
		
func on_MoveButton_focus_enter(number):
	var monster = ally2
	# There is probably a better way to keep track of this
	if $allyArea/allySprite.has_focus:
		monster = ally

	$MainTextBox/Moves/ManaCostNumberLabel.text = str(monster.moves[number].cost)
	if monster.moves[number].mode == "Mana":
		$MainTextBox/Moves/ManaLeftNumberLabel.text = str(monster.mana)
	else:
		$MainTextBox/Moves/ManaLeftNumberLabel.text = str(monster.might)

func on_MoveButton_press(number):

	# Figure out who used the move
	var user = ally
	var user_key = "Ally"
	if $allyArea/allySprite2.has_focus:
		user = ally2
		user_key = "Ally2"

	# get the movestate
	var movestate = user.moves[number].state
	movestate.reset()
	movestate.owner_key = user_key

	# @hook OnMoveSelected
	if should_do_hook("OnMoveSelected"):
		var hook_args = get_target_user_state_arguments("Enemy", user_key)
		hook_args["MOVE_NUMBER"] = number
		hook_args["MOVE_NAME"] = user.moves[number].name
		hook_args["MOVE"] = user.moves[number]
		var hook_output = hook("OnMoveSelected", hook_args)
		if hook_output[0] == "Squash":
			if len(animation_queue) > 0:
				animation_queue.append("EndAnimations:Fight+" + user_key)
				setMenuMode("Animation")
			return

	# Set the targets for the state

	var target_number = user.moves[number].targets
	var target_key

	# What to put for target varies depending on who exactly gets targeted.
	# [TBD] gets filled in when the target is selected
	if target_number == 0:
		target_key = "None"
	elif target_number == 1 and enemy2:
		target_key = "[TBD]"
	else:
		target_key = "Enemy"
		
	movestate.target_key = target_key

	turn_actions.append(movestate)

	# Figure out how to transition depending on the user and circumstances
	if len(animation_queue) > 0:
		if $allyArea/allySprite.has_focus:
			if target_number == 0 or target_number == 2 or (not enemy2):
				if ally2:
					animation_queue.append("EndAnimations:Main+Ally2")
				else:
					animation_queue.append("EndAnimations:Action+Neither")
			else:
				animation_queue.append("EndAnimations:Target+Ally")
		else:
			if target_number == 0 or target_number == 2 or (not enemy2):
				animation_queue.append("EndAnimations:Action+Neither")
			else:
				animation_queue.append("EndAnimations:Target+" + user_key)
		setMenuMode("Animation")
	else:
		if $allyArea/allySprite.has_focus:
			if target_number == 0 or target_number == 2 or (not enemy2):
				if ally2:
					setAllyFocus("Ally2")
					setMenuMode("Main")
				else:
					setMenuMode("Action")
			else:
				setMenuMode("Target")
		else:
			if target_number == 0 or target_number == 2 or (not enemy2):
				setMenuMode("Action")
			else:
				setMenuMode("Target")


# ------------------------------------------------------------------------------
#                SETTERS - Like for filling out information
# ------------------------------------------------------------------------------

# clears out the value arguments from a dictionary
func clear_value_arguments(args):
	args.erase("ORIGINAL_VALUE")
	args.erase("CURRENT_VALUE")

func attachState(state):
	attached_states[state.id] = state
	attached_states[state.owner_key].append(state)
	for l in state.battle_event_listeners:
		var hook_name = l.hook
		if hook_name in attached_listeners.keys():
			attached_listeners[hook_name].append(l)
		else:
			attached_listeners[hook_name] = [l]

func detachState(state, move = false):
	attached_states.erase(state.id)
	attached_states[state.owner_key].erase(state)
	for l in state.battle_event_listeners:
		attached_listeners[l.hook].erase(l)

func setMenuMode(mode):

	# set up the menu hooks
	if (should_do_hook("OnMenuModeMain") and mode == "Main") \
	or (should_do_hook("OnMenuModeFight") and mode == "Fight" and self.mode != "Transition:Fight") \
	or (should_do_hook("OnMenuModeTarget") and mode == "Target"):
		
		var user_key
		if $allyArea/allySprite.has_focus:
			user_key = "Ally"
		else:
			user_key = "Ally2"

		# set up the parameters for the proceeding hooks
		var hook_args = get_target_user_state_arguments("Enemy", user_key)

		if mode == "Main":
			# @hook onMenuModeMain
			var hook_output = hook("OnMenuModeMain", hook_args, "Menu")
			if len(animation_queue) > 0:
				# If running the hook added animations to the queue, then
				# add the appropriate end to the queue to set the mode back
				# to where it aught to go, then run the animations
				if hook_output[0] == "Squash":
					if ally2 and $allyArea/allySprite.has_focus:
						animation_queue.append("EndAnimations:Main+Ally2")
					else:
						animation_queue.append("EndAnimations:Action+Neither")
				else:
					if ally2 and $allyArea/allySprite.has_focus:
						animation_queue.append("EndAnimations:Main+Ally")						
					else:
						animation_queue.append("EndAnimations:Main+Ally2")
				setMenuMode("Animation")
				return
			else:
				# If running the hook squashed, but did not add any animations,
				# then move on to the correct menu mode.
				if hook_output[0] == "Squash":
					if ally2 and $allyArea/allySprite.has_focus:
						setAllyFocus("Ally2")
						setMenuMode("Main")
					else:
						setMenuMode("Action")
					return
		# We need to make sure the self mode isn't transition:fight for this
		# because if it is, then that means the hook already happened
		elif mode == "Fight" and self.mode != "Transition:Fight":
			
			# @hook OnMenuModeFight
			var hook_output = hook("OnMenuModeFight", hook_args, "Menu")
			if hook_output[0] == "Squash":
				# If the squash is supposed to send the user back to the main menu
				# (i.e. the user cannot fight)
				if hook_output[1] == "Cancel":
					# If animations were added, set the appropriate end to the animations
					if len(animation_queue) > 0:
						if $allyArea/allySprite.has_focus:
							animation_queue.append("EndAnimations:Main+Ally")
						else:
							animation_queue.append("EndAnimations:Main+Ally2")
						setMenuMode("Animation")
					# Otherwise, set the menu mode back to main
					else:
						setMenuMode("Main")
					return
				# Otherwise, a move is provided, so queue up that move
				else:

					var move = null

					# get the number of targets
					if hook_output[1] in ["0", "1", "2", "3"]:
						if user_key == "Ally":
							move = ally.moves[int(hook_output[1])]
						else:
							move = ally2.moves[int(hook_output[1])]
					else:
						move = StaticData.get_move_data([hook_output[1]])

					move.state.reset()
					move.state.owner_key = user_key
					
					var target_number = move.targets

					# Add to the action queue
					var target_key

					# What to put for target varies depending on who exactly gets targeted.
					# [TBD] gets filled in when the target is selected
					if target_number == 0:
						target_key = "None"
					elif target_number == 1 and enemy2:
						target_key = "[TBD]"
					else:
						target_key = "Enemy"

					move.state.target_key = target_key
					turn_actions.append(move.state)
					
					# set the menu mode to the appropriate next menu mode
					if len(animation_queue) > 0:
						if target_key == "[TBD]":
							animation_queue.append("EndAnimations:Target+" + user_key)
						elif ally2 and user_key == "Ally":
							animation_queue.append("EndAnimations:Main+Ally2")
						else:
							animation_queue.append("EndAnimations:Action+Neither")
						setMenuMode("Animation")
					else:
						if target_key == "[TBD]":
							setMenuMode("Target")
						elif ally2 and user_key == "Ally":
							setAllyFocus("Ally2")
							setMenuMode("Main")
						else:
							setAllyFocus("Neither")
							setMenuMode("Action")
					return
				# end else from if hook_output[1] == "Cancel":
			# end if hook_output[0] == "Squash"
			elif len(animation_queue) > 0:
				# if the output isn't squashed, but there are animations, go to the right place
				animation_queue.append("EndAnimations:Fight+" + user_key)
				setMenuMode("Animation")
				return
		elif mode == "Target":
			# @hook onMenuModeTarget
			var hook_output = hook("OnMenuModeTarget", hook_args, "Menu")
			if hook_output[0] == "Squash":
				
				# If there is a squash, set the target of the move equal to the
				# value specified by the squash
				var previous_action = turn_actions[len(turn_actions) - 1]
				if hook_output[1] == "1":
					previous_action.target_key = "Enemy"
				else:
					previous_action.target_key = "Enemy2"
	
				# set the menu mode to go to the right place
				if len(animation_queue) > 0:
					if ally2 and $allyArea/allySprite.has_focus:
						animation_queue.append("EndAnimations:Main+Ally2")
					else:
						animation_queue.append("EndAnimations:Action+Neither")
					setMenuMode("Animation")
					return
				else:
					if ally2 and $allyArea/allySprite.has_focus:
						setAllyFocus("Ally2")
						setMenuMode("Main")
					else:
						setAllyFocus("Neither")
						setMenuMode("Action")
					return
			else:
				# if not squashed but there are animations, accomodate them
				if len(animation_queue) > 0:
					if $allyArea/allySprite.has_focus:
						animation_queue.append("EndAnimations:Main+Ally")
					else:
						animation_queue.append("EndAnimations:Main+Ally2")
					return
	
	# If we need to transition then do so
	if self.mode == "Fight" and mode != "Fight":
		
		self.mode = "Transition:" + mode
		$MainTextBox/MainText.text = ""
		$MainTextBox/Choices.visible = false
		$MainTextBox/Moves.visible = false
		$AnimationPlayer.play("Contract Box")
	else:
		# Otherwise, handle the real animations
		
		# Update the mode to be correct if we're swapping into fighting
		if mode == "Fight" and self.mode != "Transition:Fight":
			self.mode = "Transition:Fight"
		elif mode == "Action":
			self.mode = "Animation"
		else:
			self.mode = mode

		# Then, do the real swapping
		if mode == "Main":
			$MainTextBox/MainText.text = ""
			$MainTextBox/Choices.visible = true
			$MainTextBox/Moves.visible = false
			$MainTextBox/Choices/FightButton.grab_focus()
			setEnemyFocus("Neither")
		elif mode == "Fight":
			# This one's a bit weird with the transitions
			
			$MainTextBox/MainText.text = ""
			$MainTextBox/Choices.visible = false
			setEnemyFocus("Neither")

			if self.mode == "Fight":
				# If the transition is resolved
				$MainTextBox/Moves.visible = true
				$MainTextBox/Moves/Move1Button.grab_focus()
				if $allyArea/allySprite.has_focus:
					setMoveButtons(ally)
				else:
					setMoveButtons(ally2)
			else:
				# If we still need to transition
				$AnimationPlayer.play("Expand Box")

		elif mode == "Target":
			$MainTextBox/MainText.text = "Use this move on which monster?"
			$MainTextBox/MainText.visible_characters = -1
			$MainTextBox/Choices.visible = false
			$MainTextBox/Moves.visible = false
			setEnemyFocus("Enemy")
		elif mode == "Animation" or mode == "Action":
			$MainTextBox/MainText.text = ""
			$MainTextBox/Choices.visible = false
			$MainTextBox/Moves.visible = false
			setEnemyFocus("Neither")
			setAllyFocus("Neither")
			if mode == "Action":
				doActionStep()
			else:
				play_queued_animation()

func setAllyFocus(monster):
	if monster == "Ally":
		$allyArea/allySprite.set_focus(true)
		$allyArea/allySprite2.set_focus(false)
		$allyArea/allySummary.visible = true
		$allyArea/allySummaryDouble.visible = false
		setSingleSummary(ally, "Ally")
	elif monster == "Ally2":
		$allyArea/allySprite.set_focus(false)
		$allyArea/allySprite2.set_focus(true)
		$allyArea/allySummary.visible = true
		$allyArea/allySummaryDouble.visible = false
		setSingleSummary(ally2, "Ally")
	elif monster == "Neither":
		$allyArea/allySprite.set_focus(false)
		if ally2:
			$allyArea/allySprite2.set_focus(false)
			$allyArea/allySummary.visible = false
			$allyArea/allySummaryDouble.visible = true

func setEnemyFocus(monster):
	if monster == "Enemy":
		$enemyArea/enemySprite.set_focus(true)
		$enemyArea/enemySprite2.set_focus(false)
		$enemyArea/enemySummary.visible = true
		$enemyArea/enemySummaryDouble.visible = false
		setSingleSummary(enemy, "Enemy")
	elif monster == "Enemy2":
		$enemyArea/enemySprite.set_focus(false)
		$enemyArea/enemySprite2.set_focus(true)
		$enemyArea/enemySummary.visible = true
		$enemyArea/enemySummaryDouble.visible = false
		setSingleSummary(enemy2, "Enemy")
	elif monster == "Neither":
		$enemyArea/enemySprite.set_focus(false)
		if enemy2:
			$enemyArea/enemySprite2.set_focus(false)
			$enemyArea/enemySummary.visible = false
			$enemyArea/enemySummaryDouble.visible = true

func setMonsterTexture(node, monster):
	node.set_sprite(monster.species)

# allows you to specify an hp or level if the one that you want
# to display is different from that of the object you pass in
# (notably, for animating events that happened "in the past")
func setSingleSummary(mon, whose, hp = -1, level=-1):
	var a = null
	if whose == "Ally":
		a = $allyArea/allySummary
	else:
		a = $enemyArea/enemySummary

	a.get_node("genderLabel").setGender(mon.gender)
	
	if whose == "Enemy":
		a.get_node("nameLabel").text = get_enemy_nickname(mon)
	else:
		a.get_node("nameLabel").text = mon.name

	var lvstr = ""
	if level == -1:
		lvstr = str(mon.level)
	else:
		lvstr = str(level)
	if len(lvstr) == 3:
		a.get_node("lvLabel").text = "Lv." + lvstr
	elif len(lvstr) == 2:
		a.get_node("lvLabel").text = "Lv. " + lvstr
	elif len(lvstr) == 1:
		a.get_node("lvLabel").text = "Lv.  " + lvstr

	var hpPercent
	if hp == -1:
		hpPercent = mon.getHpPercent()
	else:
		hpPercent = hp
	a.get_node("percentLabel").text = str(hpPercent) + "%"
	var hpProgress = a.get_node("hpProgress")
	hpProgress.value = hpPercent
	if hpPercent > 50:
		hpProgress.texture_progress.region = Rect2(0,0,96,6)
	elif hpPercent > 25:
		hpProgress.texture_progress.region = Rect2(0,8,96,6)
	else:
		hpProgress.texture_progress.region = Rect2(0,16,96,6)

	if whose == "Ally":
		var expProgress = a.get_node("expProgress")
		expProgress.value = mon.getExpPercent()

# Only sets half of the double summary, so it must be
# called twice to fully fill it out
# mon is a monster object. Key is Ally, Ally2, Enemy, or Enemy2
#
# allows you to specify an hp or level if the one that you want
# to display is different from that of the object you pass in
# (notably, for animating events that happened "in the past")
func setDoubleSummary(mon, key, hp = -1, level = -1):
	var a = null
	if key == "Ally" or key == "Ally2":
		a = $allyArea/allySummaryDouble
	else:
		a = $enemyArea/enemySummaryDouble
	
	var lvStrRaw
	if level == -1:
		lvStrRaw = str(mon.level)
	else:
		lvStrRaw = str(level)
	var lvStrFinal = ""
	if len(lvStrRaw) == 3:
		lvStrFinal = "Lv." + lvStrRaw
	elif len(lvStrRaw) == 2:
		lvStrFinal = "Lv. " + lvStrRaw
	elif len(lvStrRaw) == 1:
		lvStrFinal = "Lv.  " + lvStrRaw

	var hpPercent
	if hp == -1:
		hpPercent = mon.getHpPercent()
	else:
		hpPercent = hp

	if key == "Ally" or key == "Enemy":
		a.get_node("percentLabelTop").text = str(hpPercent) + "%"
		a.get_node("hpProgressTop").value = hpPercent
		a.get_node("lvLabelTop").text = lvStrFinal

	elif key == "Ally2" or key == "Enemy2":
		a.get_node("percentLabelBottom").text = str(hpPercent) + "%"
		a.get_node("hpProgressBottom").value = hpPercent
		a.get_node("lvLabelBottom").text = lvStrFinal

	if key == "Ally":
		var expProgressTop = a.get_node("expProgressTop")
		expProgressTop.value = mon.getExpPercent()
	elif key == "Ally2":
		var expProgressBottom = a.get_node("expProgressBottom")
		expProgressBottom.value = mon.getExpPercent()

func setMoveButtons(monster):
	var button_of_interest = null
	for i in range(4):
		button_of_interest = get_node("MainTextBox/Moves/Move" + str(i+1) + "Button")
		if len(monster.moves) > i:
			button_of_interest.setText(monster.moves[i].name)
			button_of_interest.visible = true
			button_of_interest.enabled_focus_mode = Button.FOCUS_ALL
		else:
			button_of_interest.visible = false
			button_of_interest.enabled_focus_mode = Button.FOCUS_NONE

# ------------------------------------------------------------------------------
#                    GETTERS
# ------------------------------------------------------------------------------

# gets the return value for do_action_step from the result of the hook corresponding to an action
func get_action_return_value_from_hook_result(result):
	if result[1] == "Continue":
		return "Keep"
	if result[0] == "Squash":
		return "Squash"
	return "Keep"

# makes a dictionary with the keys being the parameter names in all caps and
# the values being the parameter values. Also includes any arguments specified in the args dictionary,
# if it is a parameter (the whole args dictionary is also included as ARGS)
func get_argument_dictionary_from_action( action ):
	var output = {}
	var args_parameter
	var param_names = StateCodeParser.action_parameter_names[action.opcode]
	for i in range(len(param_names)):
		output[param_names[i].to_upper()] = action.parameters[i]
		if param_names[i] == "args":
			args_parameter = action.parameters[i]
	
	# if args is an argument for the action, then zip in the extra args which don't override a preset
	# argument name:
	if args_parameter:
		var existing_keys = output.keys()
		var args_keys = args_parameter.keys()
		for k in args_keys:
			if not k in existing_keys:
				output[k] = args_parameter[k]
	
	return output

# Gets the next relevant listener for a hook
func get_next_relevant_listener(hook, finished_listeners, max_precedence_allowed):
	var max_precedence_found = -INF # max precedence which has been found that is <= the max precedence allowed
	var next_listener = null
	
	for l in attached_listeners[hook]:
		if (not l in finished_listeners) and l.precedence > max_precedence_found and l.precedence <= max_precedence_allowed:
			max_precedence_found = l.precedence
			next_listener = l

	return next_listener

# Gets property for a monster and runs appropriate hook
func get_monster_value(key, property, reason, target_key, user_key, owner_id, additional_args = {}, stack = []):
	var value = null
	if property in StaticData.stats:
		value = get_monster_from_key(key).stats[ property ]
	else:
		value = get_monster_from_key(key).get( property )

	if should_do_hook("OnMonsterValueDetermined"):
		var args = get_value_state_arguments(value)
		get_target_user_state_arguments(target_key, user_key, args)
		args["WHO_KEY"] = key
		args["MONSTER"] = get_monster_from_key(key)
		args["PROPERTY"] = property
		args["REASON"] = reason
		args["OWNER_ID"] = owner_id
		var additional_args_keys = additional_args.keys()
		for k in additional_args_keys:
			args[k] = additional_args.keys()
		value = hook("OnMonsterValueDetermined", args, "Value", stack)
	return value

# Takes in the name of a hook. Returns true if the number of attached
# hooks indicates that the hook should be performed, and false otherwise.
func should_do_hook(hook):
	return hook in attached_listeners.keys() and len(attached_listeners[hook]) > 0

func get_value_state_arguments(value, args = {}):
	args["CURRENT_VALUE"] = value
	if typeof(value) == TYPE_DICTIONARY or typeof(value) == TYPE_ARRAY:
		args["ORIGINAL_VALUE"] = value.duplicate(true)
	else:
		args["ORIGINAL_VALUE"] = value
	return args

func get_state_identity_arguments(state, args = {}):
	args["STATE"] = state
	args["STATE_ID"] = state.id
	args["STATE_NAME"] = state.name
	return args

# adds the arguments to the dictionary "args"
func get_target_user_state_arguments(target_key, user_key, args = {}):

	args["TARGET_KEY"] = target_key
	if not target_key in ["Battlefield", "AllySide", "EnemySide"]:
		args["TARGET_PARTNER_KEY"] = get_partner_key_from_key(target_key)
		args["TARGET_PARTNER"] = get_monster_from_key(get_partner_key_from_key(target_key))
		args["TARGET"] = get_monster_from_key(target_key)
	else:
		args["TARGET_PARTNER_KEY"] = "N"
		args["TARGET_PARTNER"] = null
		args["TARGET"] = null
		
	args["USER_KEY"] = user_key
	if not user_key in ["Battlefield", "AllySide", "EnemySide"]:
		args["USER"] = get_monster_from_key(user_key)
		args["USER_PARTNER_KEY"] = get_partner_key_from_key(user_key)
		args["USER_PARTNER"] = get_monster_from_key(get_partner_key_from_key(user_key))
	else:
		args["USER"] = null
		args["USER_PARTNER_KEY"] = "N"
		args["USER_PARTNER"] = null

	if target_key != "Battlefield":
		args["TARGET_SIDE_KEY"] = get_side_key_from_monster_key(target_key)
	else:
		args["TARGET_SIDE_KEY"] = "N"

	if user_key != "Battlefield":
		args["USER_SIDE_KEY"] = get_side_key_from_monster_key(user_key)
	else:
		args["USER_SIDE_KEY"] = "N"
	
	return args

func get_partner_key_from_key(key):
	if key == "Ally":
		return "Ally2"
	if key == "Ally2":
		return "Ally"
	if key == "Enemy":
		return "Enemy2"
	if key == "Enemy2":
		return "Enemy"

func get_universal_state_arguments(hooking_state, hook_name, hook_stack = []):
	var state_owner_key = hooking_state.owner_key
	var params = {}

	# Set universal parameters
	params["SELF_KEY"] = state_owner_key
	params["VARIABLES"] = hooking_state.state_variables
	hook_stack.append([hooking_state, hook_name])
	params["STACK"] = hook_stack

	# Set the battle mode parameters
	params["PURPOSE"] = purpose
	params["FORMAT"] = format

	# Set monster parameters
	if state_owner_key in ["Ally", "Ally2", "Enemy", "Enemy2"]:
		var state_owner = get_monster_from_key(state_owner_key)
		params["SELF"] = state_owner
		
		if state_owner_key == "Ally":
			params["PARTNER_KEY"] = "Ally2"
			params["PARTNER"] = ally2
			params["OPPONENT_KEY"] = "Enemy"
			params["OPPONENT"] = enemy
			params["OPPONENT2_KEY"] = "Enemy2"
			params["OPPONENT"] = enemy2
		elif state_owner_key == "Ally2":
			params["PARTNER_KEY"] = "Ally"
			params["PARTNER"] = ally
			params["OPPONENT_KEY"] = "Enemy"
			params["OPPONENT"] = enemy
			params["OPPONENT2_KEY"] = "Enemy2"
			params["OPPONENT"] = enemy2
		if state_owner_key == "Enemy":
			params["PARTNER_KEY"] = "Enemy2"
			params["PARTNER"] = enemy2
			params["OPPONENT_KEY"] = "Ally"
			params["OPPONENT"] = ally
			params["OPPONENT2_KEY"] = "Ally2"
			params["OPPONENT"] = ally2
		if state_owner_key == "Enemy2":
			params["PARTNER_KEY"] = "Enemy"
			params["PARTNER"] = enemy
			params["OPPONENT_KEY"] = "Ally"
			params["OPPONENT"] = ally
			params["OPPONENT2_KEY"] = "Ally2"
			params["OPPONENT"] = ally2
	
	# Set side parameters
	if state_owner_key in ["Ally", "Ally2", "AllySide"]:
		params["SELF_SIDE_KEY"] = "AllySide"
		params["OPPOSITE_SIDE_KEY"] = "EnemySide"
	elif state_owner_key in ["Enemy", "Enemy2", "EnemySide"]:
		params["SELF_SIDE_KEY"] = "EnemySide"
		params["OPPOSITE_SIDE_KEY"] = "AllySide"

	# Add the states
	params["STATES"] = attached_states
	params["MOVES"] = turn_actions

	return params

func get_side_key_from_monster_key(key):
	if key == "Ally" or key == "Ally2" or key == "AllySide":
		return "AllySide"
	else:
		return "EnemySide"

func get_largest_speed():
	# Find the largest speed
	var largest_speed = max(ally.stats["Speed"], enemy.stats["Speed"])
	if ally2:
		largest_speed = max(largest_speed, ally2.stats["Speed"])
	if enemy2:
		largest_speed = max(largest_speed, enemy2.stats["Speed"])
	return largest_speed

func get_monster_from_key(key):
	if key == "Ally":
		return ally
	elif key == "Ally2":
		return ally2
	elif key == "Enemy":
		return enemy
	elif key == "Enemy2":
		return enemy2
	return null

func get_monster_sprite_from_key(key):
	if key == "Ally":
		return $allyArea/allySprite
	elif key == "Ally2":
		return $allyArea/allySprite2
	elif key == "Enemy":
		return $enemyArea/enemySprite
	elif key == "Enemy2":
		return $enemyArea/enemySprite2

func get_enemy_nickname(mon):
	if mon.name == "Enemy " + mon.species:
		return mon.species
	else:
		return mon.name

# folds all of d2's key/value pairs into d1
func zip_dicts(d1, d2):
	for k in d2.keys():
		d1[k] = d2[k]
