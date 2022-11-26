extends "State.gd"

var target_key
var has_been_used
var main_code
var move

# these values get set periodically.
var priority
var speed
var luck
var type # because this is subject to change for various moves due to states or other effects
var number # number of the move in the monster's array - used for actions which involve learning moves or replacing moves (rare)
var power
var mode


func reset():
	state_variables = {}
	target_key = ""
	has_been_used = false
	for l in battle_event_listeners:
		l.menu_checked = false
