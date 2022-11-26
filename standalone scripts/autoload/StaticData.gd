extends Node

# --- CONSTANTS --- #

# The highest level a monster can reach
const max_monster_level = 100

# A pad applied to levels when scaling to balance fights between monsters
# at a lower level. A lower pad means a greater difference between the strengths of
# monsters at different levels
const level_pad = 10

# --- VARIABLES WHICH ARE FILLED IN --- #

# It goes personalities[minus_state][plus stat]
# i.e. personalities["Attack"]["Special Defense"]
var personalities = {}

# This stores the names of all of the types
# The order here is used in the multiplier table
var types

# This stores the html string values of the colors of each of the
# types, used for type labels
var type_colors = {}

# type_multipliers [i][j] is the multiplier of type i hitting type j
# here i and j are indices of the types that they represent in the above
# variable
var type_multipliers

# A list of the stats. This is useful in several functions
const stats = ["HP", "Attack", "Defense", "Wisdom", "Speed"]

var monster_template = preload("../data containers/Monster.gd")
var move_template = preload("../data containers/Move.gd")
var move_state_template = preload("../data containers/MoveState.gd")
var state_template = preload("../data containers/State.gd")
var battle_event_listener_template = preload("../data containers/BattleEventListener.gd")

# Keeps track of the indices of the spreadsheet column names, since they are prone to change.
var monster_table_header = {}
var move_table_header = {}
var state_table_header = {}

var header_dicts = [monster_table_header, move_table_header, state_table_header]
var header_filenames = ["monsters", "moves", "states"]

# These variables are used for the "data" function which makes it easier to read csv data
var current_data_line = null
var current_table_header = null
const monster_type = 0
const move_type = 1
const state_type = 2

var state_identifier_number = 0

func _ready():
	construct_personality_table()
	construct_type_table()
	construct_table_headers(header_dicts, header_filenames)

# ---------------------------------------------------------------------------- #
# These functions pull data from files during runtime
# ---------------------------------------------------------------------------- #

# Gets move data. Takes in a list of moves and returns them in a list
# in the same order
func get_move_data(names):
	var move_lines = null
	var out = null
	
	# Configure outputs for if we are returning an array or a single move
	# also get relevant rows
	if typeof(names) != TYPE_STRING:
		move_lines = get_lines_where( move_type, "Name", names )
		out = []
		for _i in range(len(names)):
			out.append(null)
	else:
		# put the single line into an array if a single move is given
		move_lines = [get_lines_where( move_type, "Name", names )]

	# iterate through the relevant rows
	for line in move_lines:
		set_data_line( line, move_type )

		var move = move_template.new()
		move.name = data("Name")
		move.tags = data("Tags").split(";",false)
		move.description = data("Description")
		move.type = data("Type")
		move.mode = data("Mode")
		
		move.cost = data_or_default("Cost", 0)
		move.power = data_or_default("Power", null)
		move.accuracy = data_or_default("Accuracy", null)
		move.targets = data_or_default("Targets", 1)
		move.priority = data_or_default("Priority", 0)

		# Load up the move state
		var state = move_state_template.new()
		state.move = move
		
		# state identifier number
		state.id = state_identifier_number
		state_identifier_number += 1

		# state unique identifier
		state.id = state_identifier_number
		state_identifier_number += 1

		move.state = state
		state.name = move.name
		state.display_name = StateCodeParser.tokenize_and_parse('return("' + move.name + '");', move.name + " state display name")
		state.visible = false
		state.tags = move.tags

		# Get the code from when the move is used. Autogenerate if appropriate
		var code_data = data("Code")
		var code = ""
		var full_manual = data("Full Manual").to_upper()
		if not full_manual == "T" and not full_manual == "TRUE":
			# If not full manual, generate

			# The hit
			if move.power:
				code += 'hit();'
			
			# Side effects:
			code = code + code_data

			# Multiple targets
			if move.targets == 2:
				code = "applyToSide(TARGET_KEY){" + code + "}"

			# Animation text
			var animation_text = data("Animation Text")
			if animation_text == "":
				code = 'animation("Txt:" + USER.name + " used ' + move.name + '&Wait:1");' + code
			else:
				code = 'animation("Txt:" + ' + animation_text + ' + "&Wait:1");' + code

		else:
			code = code_data
		state.main_code = StateCodeParser.tokenize_and_parse(code, move.name + " main move code")

		# parse all of the miscellaneous hooks
		var hook_start_index = move_table_header["hook1"]
		parse_state_event_listeners(state, line, hook_start_index)

		# Update the return depending on if we are looking for one move or multiple
		if out:
			out[ names.find(move.name) ] = move
		else:
			return move

	return out

func get_state_data(state_name):
	# Configure the data function
	set_data_line_where(state_type, "Name", state_name)

	assert(current_data_line, "State not found: " + state_name)

	var state = state_template.new()
	state.name = state_name

	# Set up the display name and visibility
	var display_name = data("Display Name")
	if display_name != "":
		if not "return(" in display_name:
			display_name = "return(" + display_name + ");"
		state.display_name = StateCodeParser.tokenize_and_parse(display_name, state_name + " display name")
		state.visible = true
	else:
		if data("Visible") == "FALSE":
			state.visible = false
		else:
			state.visible = true
			state.display_name = StateCodeParser.tokenize_and_parse('return("' + state.name + '");', state_name + " display name")

	# Set up the tags
	var tags_string = data("Tags")
	if tags_string != "":
		state.tags = tags_string.split(";", false)
	else:
		state.tags = []
	
	# Set up the hooks
	parse_state_event_listeners(state, current_data_line, state_table_header["Code1"])
	
	return state

# Parses hooks from a file. This is used multiple times so as to not
# duplicate the same code when generating move states vs pure states
func parse_state_event_listeners(state, line, start_index):
	# Set up the listeners
	var index = start_index
	while index < len(line):
		if line[index] != "":
			parse_state_event_listener(state, line[index])
		index += 1

func parse_state_event_listener(state, code):
	var colon_index = code.find(":")
	# hook is the part before the code
	var hook = code.substr(0,colon_index)
	# parse the actual code
	var parse_tree = StateCodeParser.tokenize_and_parse(code.substr(colon_index + 1), state.name + " " + hook)
	
	var bel = battle_event_listener_template.new()
	bel.owning_state = state

	var hook_at_index = hook.find("@")

	# Is this a proper listening hook
	if hook_at_index != -1:
		bel.precedence = int(hook.substr(hook_at_index + 1))
		hook = hook.substr(0, hook_at_index)
	else:
		bel.precedence = 0
	bel.hook = hook
	bel.code = parse_tree
	if hook == "OnApplication":
		state.has_constructor = true
	elif hook == "OnTurnEnd":
		state.has_turn_end_listener = true
	elif hook == "OnRemoved":
		state.has_destructor = true
	state.battle_event_listeners.append(bel)

# ---------------------------------------------------------------------------- #
# Generate and modify monster data
# ---------------------------------------------------------------------------- #

func generate_monster(species, level):
	set_data_line_where( monster_type, "Name", species )

	var mon = monster_template.new()
	mon.species = species
	if data("% male (dec)") == "NA":
		mon.gender = "None"
	else:
		var male_probability = float(data("% male (dec)"))
		if rng.random() <= male_probability:
			mon.gender = "Male"
		else:
			mon.gender = "Female"
	
	mon.name = species
	mon.level = level
	mon.type1 = data("Type 1")
	mon.type2 = data("Type 2")
	mon.oo = PlayerData.player_name
	
	# pick the item
	var item1percent = 0
	var item2percent = 0
	var item1 = data("Item 1")
	var item2 = data("Item 2")
	if item1 != "":
		item1 = item1.split("@")
		item1percent = float(item1[1])
		item2percent = item1percent
		item1 = item1[0]
	if item2 != "":
		item2 = item2.split("@")
		item2percent += float(item2[1])
		item2 = item2[0]
	var itemNum = rng.random()
	
	if itemNum <= item1percent:
		mon.item = item1
	elif itemNum <= item2percent:
		mon.item = item2

	# Get the personality
	mon.personality_first = stats[rng.randi_range(0, len(stats) - 1)]
	mon.personality_second = stats[rng.randi_range(0, len(stats) - 1)]
	mon.personality = personalities[ mon.personality_first ][ mon.personality_second ]
	
	# Where were they met
	mon.met_location = "Olivine City" # this will need to change !
	mon.met_level = level
	
	# Set the genes of the pokemon
	mon.genes = {}
	for i in stats:
		mon.genes[i] = rng.randi_range(0,100)
	
	# Set the stat training of each stat
	mon.stat_training = {}
	for i in stats:
		mon.stat_training[i] = 0
	
	# Set the ability
	if data("Ability 2") == "" or rng.randi_range(0,1) == 0:
		mon.ability = data("Ability 1")
	else:
		mon.ability = data("Ability 2")

	# Calculate the monster's stat total
	var stat_total = 0
	for i in stats:
		stat_total += int(data(i))
	mon.stat_total = stat_total

	mon.update_to_level()
	# we have to set the data line back because update_to_level changes it
	set_data_line_where( monster_type, "Name", species )
	
	mon.mana = mon.mana_max
	mon.might = mon.might_max
	mon.hp = mon.stats["HP"]

	# This is all moves
	var counter = mon.level
	var move_names = []
	while counter > 0 and len(move_names) < 4:
		var possible_move = data(str(counter))
		if possible_move != "":
			var moves_at_this_level = possible_move.split(";")
			var j = 0
			while j < len(moves_at_this_level) and len(move_names) < 4:
				move_names.append(moves_at_this_level[j])
				j += 1
		counter -= 1
	
	mon.moves = get_move_data(move_names)
	return mon

# ---------------------------------------------------------------------------- #
# Functions related to pulling data from CSV files. None of these functions are
# strictly speaking necessary, but they make life convenient
# ---------------------------------------------------------------------------- #

# Records the index of each column title in each data table for which this is
# appropriate
func construct_table_headers(header_dicts, filenames):
	# Go through each of the file names and fill out the header dicts
	for i in range(len(header_dicts)):
		
		var file = File.new()
		# open the file
		file.open("res://data/" + filenames[i] + ".csv", file.READ)

		# it always reads the top row
		var line = file.get_csv_line()
		var header = header_dicts[i]
		
		for j in range(len(line)):
			header[line[j]] = j
		
		file.close()

# This function exists because it is a pain to type it out, even if writing it
# as a function is marginally less efficient.
func data(key):
	return current_data_line[ current_table_header[ key ] ]

func data_or_default(key, default, int_type = true):
	var result = data(key)
	if result == "":
		return default
	else:
		if int_type:
			return int(result)
		else:
			return result

# This function sets up the previous function. Also because it is easier if this
# is how it exists
func set_data_line(line, table):
	current_data_line = line
	match table:
		monster_type:
			current_table_header = monster_table_header
		state_type:
			current_table_header = state_table_header
		move_type:
			current_table_header = move_table_header
		_:
			assert(false, "Invalid table type " + str(table))

# This function gets a line from a table where a certain property is equal to a certain value
func get_lines_where(type, property, values):
	# Get the appropriate table header
	var table_header = header_dicts[type]

	# load the species list from the csv file 
	var file = File.new()
	file.open("res://data/" + header_filenames[type] + ".csv", file.READ)

	if typeof(values) == TYPE_ARRAY or typeof(values) == TYPE_STRING_ARRAY:
		# If multiple possible values are passed in
		var found_lines = []
		
		# Search lines which match
		while !file.eof_reached():
			var line = file.get_csv_line()
			if line[table_header[property]] in values:
				found_lines.append(line)
		
		return found_lines
	else:
		# If only one value is passed in
		# Search lines which match
		while !file.eof_reached():
			var line = file.get_csv_line()
			if line[table_header[property]] == values:
				return line
		
		# If nothing is found, return null
		return null

func set_data_line_where(type, property, value):
	var line = get_lines_where(type, property, value)
	set_data_line(line, type)

# ---------------------------------------------------------------------------- #
# Generate tables that will be loaded throughout the game
# ---------------------------------------------------------------------------- #

func construct_personality_table():
	var personality_names = ["Hardy", "Bold", "Modest", "Calm", "Timid", "Lonely", "Docile", "Mild", "Gentle", "Hasty", "Adamant", "Impish", "Bashful", "Careful", "Jolly", "Naughty", "Lax", "Rash", "Quirky", "Naive", "Brave", "Relaxed", "Quiet", "Sassy", "Serious"]
	for i in range(len(stats)):
		personalities[stats[i]] = {}
		for j in range(len(stats)):
			personalities[stats[i]][stats[j]] = personality_names[len(stats) * i + j]

func construct_type_table():
	var file = File.new()
	file.open("res://data/types.csv", file.READ)

	types = []

	# Grab the top row which contains all of the types
	var top_line = file.get_csv_line()
	for i in range(2, len(top_line)):
		types.append(top_line[i])

	type_multipliers = []
	# Iterate through lines to construct the type table
	while !file.eof_reached():
		var line = file.get_csv_line()
		if len(line) < 2:
			continue
		var table_row = []
		for i in range(2, len(line)):
			if line[i] == "":
				table_row.append(1.0)
			else:
				table_row.append(float(line[i]))
		type_multipliers.append(table_row)
		type_colors[line[0]] = line[1]
		

func get_type_multiplier(hitting, receiving):
	var hitting_index = 0
	for i in range(len(types)):
		if types[i] == hitting:
			hitting_index = i
			break
	
	var receiving_index = 0
	for i in range(len(types)):
		if types[i] == receiving:
			receiving_index = i
			break
	
	return type_multipliers[hitting_index][receiving_index]
