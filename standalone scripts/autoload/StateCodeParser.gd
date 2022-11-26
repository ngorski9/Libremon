extends Node

var action = preload("../state code nodes/StateCodeActionNode.gd")
# uses load because preload causes an error
# because the control node already preloads the literal node
var control = preload("../state code nodes/StateCodeControlNode.gd")
var literal = null
var operation = preload("../state code nodes/StateCodeOperationNode.gd")

const error_type = -1
const action_type = 0
const control_type = 1
const literal_type = 2
const operation_type = 3

# all of our tokens:

# sorted in order of operations
const binary_operators = ["**", "*", "/", "+", "-", "==", ">", "<", ">=", "<=", "!=", "in", "or", "and"]
const unary_operators = ["-", "not"]
const unary_operators_after = ["opposite", "not"]

# also sorted in order of operations
const all_math_operators = ["opposite", "**", "*", "/", "+", "-", "==", ">", "<", ">=", "<=", "!=", "in", "not", "or", "and"]
const assignment_operators = ["=", "+=", "-=", "*=", "/="]
const statement_enders = [")", "]", "}", ":", ";", ",", ""]
const statement_starters = ["(", '"', "{"]
const modifiers = ["[", "."]
const non_starters = binary_operators + assignment_operators + statement_enders + modifiers
const non_starter_exceptions = ["-", "["]

const control_nodes_without_parameters = ["do", "chain"]

var action_nodes_exempt_from_param_fixing = [action.Animation_, action.Return, action.Keep, action.Print, action.Set, action.SetAtIndex, action.Squash]

var action_parameter_names = {
	action.ApplyState : ["state_name", "constructor_params", "target_key", "user_key", "args", "owner_id"],
	action.Damage : ["amount", "target_key", "user_key", "form", "type", "args", "owner_id"],
	action.GetMonsterProperty : ["var", "who_key", "property", "reason", "target_key", "user_key", "args", "owner_id"],
	action.GetRandomFloat : ["var", "reason", "target_key", "user_key", "args", "owner_id"],
	action.GetRandomInt : ["var", "min", "max", "reason", "target_key", "user_key", "args", "owner_id"],
	action.Hit : ["power", "type", "mode", "target_key", "user_key", "args", "owner_id"],
	action.Move : ["name", "target_key", "user_key", "args", "owner_id"],
	action.MoveNow : ["name", "target_key", "user_key", "args", "owner_id"],
	action.PercentChance : ["chance", "reason", "target_key", "user_key", "args", "owner_id"],
	action.RemoveState : ["target_key", "which", "user_key", "args", "owner_id"],
	action.SetArgument : ["arg_name", "value", "update_other_values"]
}

# if something is not present here, the optional arguments are assumed to be 
# target_key, user_key, args, owner_id, in that order, with default values of TARGET_KEY, USER_KEY, {}, 
# and getOwnId()
func get_action_optional_parameters_defaults(opcode):
	match opcode:
		action.ApplyState:
			return ["{}", "TARGET_KEY", "USER_KEY", "{}", "getOwnId()"]
		action.Damage:
			return ["TARGET_KEY", "USER_KEY", '"Effect"', '"Untyped"', "{}", "getOwnId()"]
		action.GetMonsterProperty, action.GetRandomFloat, action.GetRandomInt:
			return ["STACK[0][0].name", "TARGET_KEY", "USER_KEY", "{}", "getOwnId()"]
		action.Hit: 
			return [ 'getOwnMoveValue("power")', 'getOwnMoveValue("type")', 'getOwnMoveValue("mode")', "TARGET_KEY", "USER_KEY", "{}", "getOwnId()" ]
		action.RemoveState: 
			return [ "USER_KEY", "{}", "getOwnId()" ]
		action.SetArgument: 
			return[ "true" ]
		_:
			return [ "TARGET_KEY", "USER_KEY", "{}", "getOwnId()" ]


# Called when the node enters the scene tree for the first time.
func _ready():
	# This should actually stay
	literal = control.new(control.Do, [], []).literal

	# all of this is for testing purposes
	var code = '0'
	#var code = 'If(USER_KEY == SELF_KEY,Squash();Move(SELF_KEY,"Thrash2",OriginalTargetKey);Animation("Txt:" + SELF.name +" is locked into Thrash!&Wait:1"););'
	var vars = {}
	var eval_args = {"VARIABLES" : vars, "LAST_RESULT" : "Keep"}
	test_code(code, eval_args)


func test_code(code, eval_args):
	var node = tokenize_and_parse(code, "test")
	if node:
		node.out(0)
		print("---")
		if node.node_type == 0 or node.node_type == 1:
			var action = node.eval(eval_args)
			while action:
				action.out_evaluated()
				action = node.eval(eval_args)
		else:
			# If it is operation or literal type
			print(node.eval(eval_args))

	else:
		print("no return")

func tokenize_and_parse(code, reason):
	if code.find(";") != -1 and code.substr(0,2) != "do":
		code = "do{" + code + "}"
	var s = TokenStream.new(code, reason)
	var node = parse(s)
	return node

# s is a token stream
func parse(s):
	# used for giving errors
	var parse_start_position = s.start_position

	# This Lists an infix expression. It will be an alternation between nodes and operator tokens
	var infix_expression = []

	while s.peak_next_token() != "":
		var t = s.next_token()
		parse_error(s, not t in non_starters or t in non_starter_exceptions, \
		'. Unexpected token "' + t)
		
		# Append prefix operators to the infix expression
		while t in unary_operators:
			if t == "-":
				# this sets up "Opposite" as the unary minus operator, which is different from - which is a binary operator
				infix_expression.append("opposite")
			else:
				infix_expression.append(t)
			t = s.next_token()

		# Get the next legitimate token
		if t[0] == '"':
			# if this token is a string literal
			var unescaped = t.c_unescape()
			infix_expression.append( literal.new(literal.Str, unescaped.substr(1,len(unescaped)-2)) )
		elif t == "true":
			# if this token is a bool literal for true
			infix_expression.append( literal.new( literal.Bool, true ) )
		elif t == "false":
			# if this token is a bool literal for false
			infix_expression.append( literal.new( literal.Bool, false ) )
		elif t.is_valid_integer():
			# if this token is a number literal
			if(s.peak_next_token() == '.'):
				# if this number is a decimal
				s.next_token()
				var after_decimal = s.next_token()
				parse_error(s, after_decimal.is_valid_integer(), "malformed decimal")
				infix_expression.append( literal.new(literal.Num, float(t + "." + after_decimal) ) )
			else:
				# if this number is an integer
				infix_expression.append( literal.new(literal.Num, float(t)) )
		elif t == "(":
			# If this token signifies the start of a parenthetical expression
			var parse_position = s.start_position - 1
			var node = parse(s) # get the next whole token
			var next_token = s.next_token()
			parse_error(s, next_token == ")", "Unclosed parentheses", parse_position)
			infix_expression.append(node)
		elif t == "[":
			# If this token signifies the start of a list literal
			var parse_position = s.start_position - 1
			var out_list = []
			var next_token = s.peak_next_token()
			while next_token != "]":
				out_list.append(parse(s))
				next_token = s.next_token()
				parse_error(s, next_token == "]" or next_token == ",", "Unexpected seperator in list", parse_position)
			infix_expression.append( operation.new(operation.List, out_list) )
		elif t == "{":
			# If this token signifies the start of a dictionary literal
			var next_token = s.peak_next_token()
			var expecting_colon = true
			var parse_position = s.start_position - 1
			var out_list = []
			while next_token != "}":
				out_list.append(parse(s))
				next_token = s.next_token()
				parse_error(s, (expecting_colon and next_token == ":") or (not expecting_colon and (next_token == "," or next_token == "}")), "Unexpected seperator in dictionary", parse_position)
				if expecting_colon:
					expecting_colon = false
				else:
					expecting_colon = true
			infix_expression.append( operation.new(operation.Dict, out_list) )
		else:
			# Words, meaning either a variable or function
			var next_token = s.peak_next_token()
			if next_token != "(" and not t in control_nodes_without_parameters:
			# If it's a variable, we are either assigning it or getting its value
			# In either case, initially parse a variable node as though we are assigning to it
				var out_node = operation.new( operation.Variable, [literal.new( literal.Str, t )] )
				while next_token in modifiers:
					if next_token == ".":
						s.next_token() # consume the "."
						var property = literal.new( literal.Str, s.next_token() )
						out_node = operation.new( operation.Property, [out_node, property] )
						next_token = s.peak_next_token()
					if next_token == "[":
						var parse_position = s.start_position - 1
						s.next_token() # consume the "["
						var index = parse(s)
						next_token = s.next_token() # consume the "]"
						parse_error( s, next_token == "]", "Unclosed brackets" )
						out_node = operation.new( operation.Index, [out_node, index] )
						next_token = s.peak_next_token()
				
				# Now, if we are doing an assign, modify the token previously created into an assignment token.
				if next_token in assignment_operators:
					# If we are assigning to a variable

					# consume the assignment operator (still stored in next_token)
					s.next_token()
					var assignment = parse(s) # what we are assigning to the variable
					
					# modify what will be assigned to the variable based on operator (if applicable)
					if next_token != "=":
						var opcode = -1
						
						match next_token:
							"+=":
								opcode = operation.Add
							"-=":
								opcode = operation.Sub
							"*=":
								opcode = operation.Mul
							"/=":
								opcode = operation.Div
						
						# If we are doing an arithmetic assign, we must also fetch the value of the variable in order to do the assign
						# we do this by cloning our first node which we already created to fetch the value
						# (we have to clone because if we used the same node it would get evaluated multiple times, which
						# may mess it up.
						assignment = operation.new( opcode, [out_node.clone(), assignment] )
					
					# modify the previously created node for assignment based on what sort of node it is.
					match out_node.opcode:
						operation.Variable:
							out_node = action.new( action.Set, [out_node.parameters[0], assignment] )
						operation.Index:
							out_node = action.new( action.SetAtIndex, [out_node.parameters[0], out_node.parameters[1], assignment] )
						operation.Property:
							parse_error(s, false, "assigning to properties is not allowed")
					
				# append the next node to the expression (works in either case)
				infix_expression.append( out_node )

			else:
				# if it's a function
				
				var parse_position = s.start_position - len(t)

				if not t in control_nodes_without_parameters:
					s.next_token() # consume the "(" if applicable
				
				# Generate the base node
				var opcode_and_type = get_opcode_from_token(t)
				var opcode = opcode_and_type[0]
				var type = opcode_and_type[1]
				
				var root_node = null
				match type:
					action_type:
						root_node = action.new(opcode, [])
					control_type:
						root_node = control.new(opcode, [], [])
					operation_type:
						root_node = operation.new(opcode, [])
					_:
						parse_error(s, false, "unrecognized function name " + t, parse_position)

				# Parse the parameters
				if not t in control_nodes_without_parameters:
					# Parse function not of control type
					next_token = s.peak_next_token()
					if next_token == ")":
						parse_error(s, type != control_type, "Control node should have parameters", parse_position)
						next_token = s.next_token()
					while next_token != ")":
						root_node.parameters.append(parse(s))
						next_token = s.next_token() # here is where we consume the comma or )
						parse_error(s, next_token == "," or next_token == ")", "Unexpected token " + next_token, parse_position)
				
				# Fix the parameters for action types
				if type == action_type:
					set_action_node_parameters(root_node, s)
				
				# Parse the control portion (control nodes only)
				if type == control_type:
					next_token = s.next_token()
					parse_error(s, next_token == "{", "Unexpected token " + next_token, parse_position)
					while next_token != "}":
						root_node.statements.append(parse(s))
						next_token = s.peak_next_token()
						# We must have that either the statement just parsed is a control node, or we now have a semicolon or a }
						parse_error(s, root_node.statements[len(root_node.statements)-1].node_type == control_type or next_token == ";" or next_token == "}", "Unexpected token " + next_token, parse_position)
						
						# handle the case where the next token is a ; or }
						if next_token == ";" or next_token == "}":
							next_token = s.next_token()
						# This is if the contntens of the control node end with ;}
						if next_token == ";" and s.peak_next_token() == "}":
							next_token = s.next_token()

					next_token = s.peak_next_token()
					if next_token == "Else":
						# Handle else
						parse_error(s, t == "If", "Else not following If", parse_position)
						root_node.opcode = control.IfElse
						s.next_token() # consume the else

						# Set up the else statements
						var else_do_node = control.new(control.Do, [], [])

						next_token = s.next_token()
						parse_error(s, next_token == "{", "Unexpected token " + next_token, parse_position)
						while next_token != "}":
							parse_error(s, next_token == "{", "Unexpected token " + next_token, parse_position)
							else_do_node.statements.append(parse(s))
							next_token = s.peak_next_token()
							
							# this area is handled similarly to above
							parse_error(s, else_do_node.statements[len(else_do_node.statements)-1].node_type == operation_type or next_token == ";" or next_token == "}", "Unexpected token " + next_token, parse_position)
							if next_token == ";" or next_token == "}":
								next_token = s.next_token()
							if next_token == ";" and s.peak_next_token() == "}":
								next_token = s.next_token()
						root_node.parameters.append(else_do_node)
				
				infix_expression.append(root_node)


		# Once we are done parsing the first token, analyze the seperator which follows

		var next_token = s.peak_next_token()
		parse_error(s, (typeof(infix_expression[0]) == TYPE_OBJECT and infix_expression[0].node_type == control_type) or next_token in binary_operators or next_token in statement_enders, "Unexpected token " + next_token)
		
		if next_token in [')', "]", "}" , ",", ":", ";", ""] or infix_expression[len(infix_expression)-1].node_type == control_type:
			# if we hit a terminal character or just parsed an control node then end the expression
			if len(infix_expression) == 1:
				return infix_expression[0]
			else:
				return parse_infix_expression(infix_expression, s, parse_start_position)
		else:
			# Otherwise, it must be an operation, so add it to the infix expression
			parse_error(s, next_token in all_math_operators, "Unexpected token " + next_token, parse_start_position)
			parse_error(s, not infix_expression[len(infix_expression)-1].node_type in [action_type, control_type], "Operation used on action or control node")
			infix_expression.append(s.next_token())

	return null

# recursively generate a parse tree from an array of operations nodes and operation strings
func parse_infix_expression(list, stream, position, operator_number = -1):
	# first, the base case:
	if len(list) == 1:
		parse_error( stream, typeof(list[0]) == TYPE_OBJECT, "Unexpected token " + str(list[0]), position )
		return list[0]

	# Set the operator number if it was not specified
	if operator_number == -1:
		# note that we traverse the list in reverse order of operations (so we traverse the list backwards)
		operator_number = len(all_math_operators) - 1

	# recursion step

	# Figure out what operator we are using and where it is
	var split_index = list.find(all_math_operators[operator_number])
	while operator_number >= 0 and split_index == -1:
		operator_number -= 1
		split_index = list.find(all_math_operators[operator_number])
	
	parse_error( stream, split_index >= 0, "Unexpected operation when parsing infix expression", position )
	
	var operator = all_math_operators[operator_number]

	if operator in unary_operators_after:
		# Handle unary operators
		parse_error( stream, split_index == 0, "Incorrect unary operator positioning", position )
		var inner_eval = parse_infix_expression( list.slice(1, len(list)-1), stream, position, operator_number )
		return operation.new( get_opcode_from_token(operator)[0], [inner_eval])
	else:
		# Handle binary operators
		
		# for left eval we can do operator number - 1 because split_index is the leftmost occurence of the current operator number
		var left_eval = parse_infix_expression( list.slice(0, split_index - 1), stream, position, operator_number-1 )
		var right_eval = parse_infix_expression( list.slice(split_index+1, len(list)-1), stream, position, operator_number )
		
		var output_node = operation.new( get_opcode_from_token(operator)[0], [left_eval, right_eval] )
		
		# account for ** taking priority over a negative sign (I couldn't think of a cleaner way to do this)
		if operator == "**" and left_eval.opcode == operation.Opposite:
			# take the negative out of the left parameter
			output_node.parameters[0] = left_eval.parameters[0]
			# place the negative on the outside
			output_node = operation.new( operation.Opposite, [output_node] )
		
		return output_node

func parse_error( s, condition, error_type, position = -1 ):
	if position == -1:
		position = s.last_start_position
	assert( condition, "ERROR when parsing " + s.reason + '. ' + error_type + ' at position ' \
	+ str(position) + ' > ' + s.code.substr(position))

func set_action_node_parameters(node, stream):
	if node.opcode in action_nodes_exempt_from_param_fixing:
		return
		
	var param_name_list = action_parameter_names[node.opcode]
	var optional_param_list = get_action_optional_parameters_defaults(node.opcode)
	
	# this will be the new parameter list. It will start out as an array of nulls of the correct length
	var new_params = []
	for i in param_name_list:
		new_params.append(null)
	
	# go through each parameter that we will need
	for i in range(len(node.parameters)):
		var parameter = node.parameters[i]
		# if so, see if it is assigned positionally
		if parameter.opcode != action.Set:
			# if so, then assign
			new_params[i] = parameter
		else:
			# if not, then assign to the proper position   -- parameter.parameters[0].data is the variable name
			new_params[ param_name_list.find( parameter.parameters[0].data ) ] = parameter.parameters[1]
	
	var optional_param_offset = len(param_name_list) - len(optional_param_list)
	
	# go through mandatory parameters and see if they are set
	var no_nulls = true
	for i in range(optional_param_offset):
		if not new_params[i]:
			no_nulls = false
			break
	
	parse_error(stream, no_nulls, "default values missing for action " + node.identify(), 0)
	
	# go through the optional parameters and set them if they are not currently set
	for i in range(len(optional_param_list)):
		if not new_params[i + optional_param_offset]:
			new_params[i + optional_param_offset] = tokenize_and_parse(optional_param_list[i], node.identify() + " default param value")
	
	node.parameters = new_params

class TokenStream:
	
	var code
	var reason
	var start_position = 0

	# This is used for displaying error messages for statecode
	var last_start_position

	# This gets set if you peak. It exists so that you can peak multiple times without re-searching
	var last_end_position = -1
	
	func _init(code, reason):
		self.code = code
		self.reason = reason

	func break_at(end_position):
		last_end_position = end_position
		var out = code.substr(start_position, end_position-start_position+1)
		return out

	# Return next token and move past it
	func next_token():
		var out = peak_next_token()
		last_start_position = start_position
		start_position = last_end_position + 1
		last_end_position = -1
		return out

	# Return next token, but don't move past it
	func peak_next_token():
		# if the next token is buffered, then grab it
		if last_end_position >= 0:
			return code.substr(start_position, last_end_position-start_position+1)
		
		if start_position >= len(code):
			return ""
		var end_position = start_position

		# Should we override the other token characters due to being in a string literal which starts
		# with a ". Note that a string literal can also be not in quotes, but this ensures that the
		# other characters won't get picked up, and also allows for you to insert other nodes
		# in the middle.
		var in_string_literal = (code[start_position] == '"')
		
		while end_position < len(code):
			var c = code[end_position]

			if c == '"':
				# See if we are finishing a string literal, or about to start a new one
					if in_string_literal and end_position > start_position \
					and (code[end_position - 1] != "\\" or (end_position > 1 and code[end_position - 2] == "\\")):
						return break_at(end_position)
					elif not in_string_literal:
						# If we encounter a " and aren't in a string which started with ", we assume
						# that we aren't in a literal and break it off before that
						return break_at(end_position - 1)
			elif not in_string_literal: 
				if c == ' ':	
					# cut off tokens at spaces, and never include tokens in spaces
					if end_position > start_position:
						# cut off tokens at spaces
						return break_at(end_position - 1)
					else:
						# otherwise, shift the start position up
						start_position += 1
						end_position += 1
						# if the area where we're starting to look for a token at starts with a space,
						# reset whether we are inside of a string literal
						in_string_literal = (code[start_position] == '"')
						continue
				elif c == "*":
					# Get the *, ** and *= tokens tokens (all standalone)
					if end_position == start_position:
						if end_position < len(code) - 1 and code[end_position + 1] in ["*", "="]:
							# exponent operator token
							return break_at(end_position + 1)
						else:
							# multiplication operator token
							return break_at(end_position)
					else:
						return break_at(end_position - 1)
				elif c in ["+", "-", "/", ">", "<", "="]:
					# get single tokens that can also have = after them
					if end_position == start_position:
						if (end_position < len(code) - 1) and code[end_position + 1] == "=":
							# operator equals token
							return break_at(end_position + 1)
						else:
							# single operator token
							return break_at(end_position)
					else:
						return break_at(end_position - 1)
				elif c in ["[", "]", "(", ")", "{", "}", ".", ",", ":", ";"]:
					# various standalone tokens
					if end_position == start_position:
						return break_at(end_position)
					else:
						return break_at(end_position - 1)
				elif code.substr(start_position, 3) == "and":
					# get and
					return break_at(start_position + 2)
				elif code.substr(start_position, 2) == "or":
					# get or
					return break_at(start_position + 1)
				elif code.substr(start_position, 3) == "not":
					# get not
					return break_at(start_position + 2)
				elif code.substr(start_position, 4) == "true":
					# get true
					return break_at(start_position + 3)
				elif code.substr(start_position, 5) == "false":
					# get false
					return break_at(start_position + 4)
			
			end_position += 1
		# if no breaking character is reached by the end of the code, then 
		return break_at(len(code))

func get_opcode_from_token(token):
	match token:
		# Control nodes
		"applyToSide":
			return [control.ApplyToSide, control_type]
		"chain":
			return [control.Chain, control_type]
		"do":
			return [control.Do, control_type]
		"if":
			return [control.If, control_type]
		"ifElse":
			return [control.IfElse, control_type]
		"repeat":
			return [control.Repeat, control_type]
		"while":
			return [control.While, control_type]

		# Variable operations
		"index":
			return [operation.Index, operation_type]
		"isArgSet":
			return [operation.IsArgSet, operation_type]
		"isVarSet":
			return [operation.IsVarSet, operation_type]
		"property":
			return [operation.Property, operation_type]
		"variable":
			return [operation.Variable, operation_type]
		
		# Number operations
		"abs":
			return [operation.Abs, operation_type]
		"add", "+":
			return [operation.Add, operation_type]
		"ceil":
			return [operation.Ceil, operation_type]
		"div", "/":
			return [operation.Div, operation_type]
		"floor":
			return [operation.Floor, operation_type]
		"mul", "*":
			return [operation.Mul, operation_type]
		"opposite":
			return[operation.Opposite, operation_type]
		"pow", "**":
			return [operation.Pow, operation_type]
		"sub", "-":
			return [operation.Sub, operation_type]
		"typeMultiplier":
			return [operation.TypeMultiplier, operation_type]
		
		# Bool operations
		"and":
			return [operation.And, operation_type]
		"not", "not":
			return [operation.Not, operation_type]
		"or", "or":
			return [operation.Or, operation_type]
			
		# Comparison operators
		"equal", "==":
			return [operation.Equal, operation_type]
		"greater", ">":
			return [operation.Greater, operation_type]
		"greaterEqual", ">=":
			return [operation.GreaterEqual, operation_type]
		"lesser", "<":
			return [operation.Lesser]
		"lesserEqual", "<=":
			return [operation.LesserEqual, operation_type]
		"notEqual", "!=":
			return [operation.NotEqual, operation_type]

		# Type operations
		"num":
			return [operation.Num, operation_type]
		"str":
			return [operation.Str, operation_type]

		# List and dictionary operators
		"keys":
			return [operation.Keys, operation_type]
		"values":
			return [operation.Values, operation_type]
		"in":
			return [operation.In, operation_type]

		# Hook stack getters
		"getCallingHook":
			return [operation.GetCallingHook, operation_type]
		"getCallingState":
			return [operation.GetCallingState, operation_type]
		"getCallingStateId":
			return [operation.GetCallingStateId, operation_type]
		"getCallingStateName":
			return [operation.GetCallingStateName, operation_type]
		"getRootHook":
			return [operation.GetRootHook, operation_type]
		"getRootState":
			return [operation.GetRootState, operation_type]
		"getRootStateId":
			return [operation.GetRootStateId, operation_type]
		"getRootStateName":
			return [operation.GetRootStateName, operation_type]

		# state getters
		"getMovesByOwner":
			return [operation.GetMovesByOwner, operation_type]
		"getMoveValue":
			return [operation.GetMoveValue, operation_type]
		"getOwnId":
			return [operation.GetOwnId, operation_type]
		"getOwnMoveValue":
			return [operation.GetOwnMoveValue, operation_type]

		# Actions
		"animation":
			return [action.Animation_, action_type]
		"applyState":
			return [action.ApplyState, action_type]
		"damage":
			return [action.Damage, action_type]
		"getMonsterProperty":
			return [action.GetMonsterProperty, action_type]
		"getRandomFloat":
			return [action.GetRandomFloat, action_type]
		"getRandomInt":
			return [action.GetRandomInt, action_type]
		"hit":
			return [action.Hit, action_type]
		"move":
			return [action.Move, action_type]
		"removeState":
			return [action.RemoveState, action_type]
		"return":
			return [action.Return, action_type]
		"keep":
			return [action.Keep, action_type]
		"percentChance":
			return [action.PercentChance, action_type]
		"print":
			return [action.Print, action_type]
		"squash":
			return [action.Squash, action_type]
		"set":
			return [action.Set, action_type]
		"setArgument":
			return [action.SetArgument, action_type]
		"setAtIndex":
			return [action.SetAtIndex, action_type]
		"text":
			return [action.Text, action_type]
		
		_:
			return [0, error_type]
