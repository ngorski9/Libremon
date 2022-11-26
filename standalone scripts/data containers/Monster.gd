extends Reference

var name
var number
var species
var gender
var level
var type1
var type2
var oo
var item 
var personality_first
var personality_second
var personality
var met_location
var met_level
var genes
var hp
var stats
var stat_total
var stat_training
var ability
var growth_rate
var experience
var experience_next
var moves
var mana
var mana_max
var might
var might_max

var abilities = []
var statuses = []
var temporary_states = []

func clear_temporary_states():
	temporary_states = []

func get_all_states():
	return abilities + statuses + temporary_states

func getHpPercent():
	return int( ceil( 100.0 * float(hp) / float(stats["HP"]) ) )

func getExpPercent():
	if level < StaticData.max_monster_level:
		return int( floor( 100.0 * float(experience) / float(experience_next) ) )
	else:
		return 0

func update_to_level():	
	if stats:
		print("start: " + str(hp) + "/" + str(stats["HP"]))
	StaticData.set_data_line_where( StaticData.monster_type, "Name", species)
	
	stats = {}
	
	for i in StaticData.stats:
		var personality_multiplier = 1
		if personality_first == i:
			personality_multiplier += 0.075
		if personality_second == i:
			personality_multiplier += 0.075
		# 10 is added to the level to soften the difference at lower levels
		if i != "HP":
			stats[i] = float( floor( float( StaticData.data(i) ) * float(level + StaticData.level_pad) * float(personality_multiplier) * (1.0 + float(stat_training[i]) / 100.0 ) * ( 1.0 + float(genes[i]) / 100.0 ) ) )
		else:
			stats[i] = float( floor( float( StaticData.data(i) ) * float(personality_multiplier) * (1.0 + float(stat_training[i]) / 100.0) * (1.0 + float(genes[i]) / 100.0) ) )

	stats["HP"] *= 2
	mana_max = float( floor( float(StaticData.data("Mana")) * 0.2 + 0.8 * float(level) / float(StaticData.max_monster_level) ) )
	might_max = float( floor( float(StaticData.data("Might")) * 0.2 + 0.8 * float(level) / float(StaticData.max_monster_level) ) )
	experience = 0
	if level < StaticData.max_monster_level:
		experience_next = 0.6 * stat_total * pow(level, 1.5)
	else:
		experience_next = 0
	
	var new_move_names = StaticData.data(str(level))
	if new_move_names == "":
		return []
	else:
		# make new array rather than just using split so that we do not have a pool string array,
		# but rather a regular array (helpful down the line)
		var new_moves_array = []
		for s in new_move_names.split(";"):
			new_moves_array.append(s)
		return StaticData.get_move_data(new_moves_array)

func update_state_owner_keys(key):
	var all_states = get_all_states()
	for state in all_states:
		state.owner_key = key
