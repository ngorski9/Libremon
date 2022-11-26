extends Reference

# A string indicating who owns it, either a party member, a side, or the battlefield
var owner_key

var name
var display_name
var visible
var tags
var battle_event_listeners = []
var state_variables = {}
var has_constructor
var has_turn_end_listener
var has_destructor
var id = 0

func state_sort(s1, s2):
	if s1.precedence >= s2.precedence:
		return true
	else:
		return false

# returns them sorted
func get_relevant_event_listeners(hook):
	var out = []
	for h in battle_event_listeners:
		if h.hook == hook:
			out.append(h)
	out.sort_custom(get_script(), "state_sort")
	return out
