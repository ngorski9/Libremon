extends Reference

const node_type = 1

const ApplyToSide = 0
const Chain = 1
const Do = 2
const If = 3
const IfElse = 4
const Repeat = 5
const While = 6

var literal = preload("StateCodeLiteralNode.gd")

var opcode
var parameters = []
var statements = []

var position = 0
var local_variables = {}

func _init(opcode, parameters, statements):
	self.opcode = opcode
	self.parameters = parameters
	self.statements = statements

func identify():
	match opcode:
		ApplyToSide:
			return "applyToSide"
		Chain:
			return "chain"
		Do:
			return "do"
		If:
			return "if"
		IfElse:
			return "ifElse"
		Repeat:
			return "repeat"
		While:
			return "while"

func out(level):
	var tab = ""
	for i in range(level):
		tab += "  "
	print(tab + identify())
	if opcode == IfElse:
		print(tab + "If")
		parameters[0].out(level+1)
		print(tab + "Then")
		for s in statements:
			s.out(level+1)
		print(tab + "Else")
		parameters[1].out(level+1)
	else:
		for p in parameters:
			p.out(level+1)
		print(tab + "This")
		for s in statements:
			s.out(level+1)
	
func eval(arguments):
	match opcode:
		ApplyToSide:
			# parameters[1] will store which monster we are applying the work on currently
			
			if len(parameters) == 1:
				# append a node to track which monster we are applying it to
				parameters.append(literal.new(literal.Num, 1))
			
			var result
			if parameters[1].eval(arguments) == -1:
				# In this case, we are done with the first monster and there is no second one
				return null
			if parameters[1].eval(arguments) == 1:
				# In this case, we are on the first monster
				
				# make the appropriate argument substitutions as necessary
				var old_target_key = arguments["TARGET_KEY"]
				var old_target = arguments["TARGET"]
				var old_target_partner_key = arguments["TARGET_PARTNER_KEY"]
				var old_target_partner = arguments["TARGET_PARTNER"]
				
				if parameters[0].eval(arguments) == arguments["USER_SIDE_KEY"]:

					arguments["TARGET_KEY"] = arguments["USER_KEY"]
					arguments["TARGET"] = arguments["USER"]
					arguments["TARGET_PARTNER_KEY"] = arguments["USER_PARTNER_KEY"]
					arguments["TARGET_PARTNER"] = arguments["USER_PARTNER"]
				
				# get the actual result (lol)
				result = normal(arguments)
				
				# swap back the arguments
				arguments["TARGET_KEY"] = old_target_key
				arguments["TARGET"] = old_target
				arguments["TARGET_PARTNER_KEY"] = old_target_partner_key
				arguments["TARGET_PARTNER"] = old_target_partner
				
				# Depending on the result, switch to monster 2
				if result:
					return result

				# At this point, it is time to move on to the second monster
				var target_monster = null
				if parameters[0].eval(arguments) == "TARGET_SIDE_KEY":
					target_monster = arguments["TARGET"]
				else:
					target_monster = arguments["USER"]
					
				if target_monster and target_monster.hp > 0:
					soft_reset()
					parameters[1].data = 2
					# Also reset last result in case there is a Chain node inside
					arguments["LAST_RESULT"] = "Keep"
				else:
					parameters[1].data = -1

			if parameters[1].eval(arguments) == 2 and len(parameters) >= 3 and parameters[2]:
				# In this case, we are on the second monster

				# keep track of the old arguments
				# and swap in the new ones
				var old_target_key = arguments["TARGET_KEY"]
				var old_target = arguments["TARGET"]
				var old_target_partner_key = arguments["TARGET_PARTNER_KEY"]
				var old_target_partner = arguments["TARGET_PARTNER"]
				
				if parameters[0].eval(arguments) == arguments["TARGET_SIDE_KEY"]:
					arguments["TARGET_KEY"] = old_target_partner_key
					arguments["TARGET"] = old_target_partner
					arguments["TARGET_PARTNER_KEY"] = old_target_key
					arguments["TARGET_PARTNER"] = old_target
				
				else:
					arguments["TARGET_KEY"] = arguments["USER_PARTNER_KEY"]
					arguments["TARGET"] = arguments["USER_PARTNER"]
					arguments["TARGET_PARTNER_KEY"] = arguments["USER_KEY"]
					arguments["TARGET_PARTNER"] = arguments["USER"]
				
				# get the actual result (lol)
				result = normal(arguments)
				
				# swap back the arguments
				arguments["TARGET_KEY"] = old_target_key
				arguments["TARGET"] = old_target
				arguments["TARGET_PARTNER_KEY"] = old_target_partner_key
				arguments["TARGET_PARTNER"] = old_target_partner

				return result

		Chain:
			var output
			if arguments["LAST_RESULT"] == "Squash":
				output = null
			else:
				output = normal(arguments)
				
			# Do this so that multiple chain nodes can work one after the other
			if not output:
				arguments["LAST_RESULT"] = "Keep"
			return output

		Do:
			return normal(arguments)

		If:
			if len(parameters) == 1:
				var result_token = literal.new( literal.Bool, parameters[0].eval(arguments) )
				parameters.append(result_token)
			if parameters[1].eval(arguments):
				return normal(arguments)

		IfElse:
			# parameters[0] is the condition.
			# parameters[1] is a control token for what to do for else
			if len(parameters) == 2:
				parameters.append(literal.new(literal.Bool, parameters[0].eval(arguments)))
			if parameters[2].eval(arguments):
				return normal(arguments)
			else:
				return parameters[1].eval(arguments)
		
		Repeat:
			# parameters[0] is the loop counters
			# parameters[1] stores the number of times the loop will
			if len(parameters) == 1:
				parameters.append( literal.new( literal.Num, 0 ) )
				parameters.append( literal.new( literal.Num, parameters[0].eval(arguments) ))
			
			var loop_counter = parameters[1].eval(arguments)
			var loop_max = parameters[2].eval(arguments)
			
			while loop_counter < loop_max:
				var result = normal(arguments)
				if result:
					parameters[1].data = loop_counter
					return result
				else:
					soft_reset()
					loop_counter += 1
			
			return null
		While:
			# parameters[1] will store whether the loop condition is true or false
			if len(parameters) == 1:
				parameters.append( literal.new( literal.Bool, parameters[0].eval(arguments) ) )
			
			var loop_condition = parameters[1].eval(arguments)
			while loop_condition:
				var result = normal(arguments)
				if result:
					return result
				else:
					soft_reset()
					loop_condition = parameters[0].eval(arguments)
					parameters[1].data = loop_condition
		_:
			assert(false, "Unrecognized control opcode " + str(opcode))

# reset each of the statements as well as the position, but
# keeps the parameters
func soft_reset():
	for s in statements:
		s.hard_reset()
	position = 0

# completely resets everything to as though it has never been fired
func hard_reset():
	soft_reset()
	
	# reset added parameters
	if (opcode == ApplyToSide or opcode == If) and len(parameters) > 1:
		parameters = [parameters[0]]
	elif opcode == IfElse and len(parameters) > 2:
		parameters = [parameters[0], parameters[1]]
	
	for p in parameters:
		if p.node_type == 0 or p.node_type == 1: # action type or control type
			p.reset()

# gets the next statement in statements. If it turns up null, then cycle through
# the statements until one does not turn up as null. If they all end up turning
# up null, then return null
func normal(arguments):

	var statement = null
	# position should be incremented every time that statement turns up as
	# null except for the first time. Thus, we decrement it to cancel out
	# the first increment. An exception is made if position is less than 0 which
	# implies that the node has 0 statements and this function was already run.
	if position >= 0:
		position -= 1

	while statement == null and position < len(statements) - 1:
		position += 1
		statement = statements[position].eval(arguments)

	return statement

func clone():
	var node = get_script().new(opcode, [], [])
	for p in parameters:
		node.parameters.append(p.clone())
	for s in statements:
		node.statements.append(s.clone())
	return node
