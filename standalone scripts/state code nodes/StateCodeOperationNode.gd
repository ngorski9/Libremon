extends Reference

const node_type = 3

const Property = 0
const Index = 1
const IsArgSet = 2
const IsVarSet = 3
const Variable = 4

const Abs = 5
const Add = 6
const Ceil = 7
const Div = 8
const Floor = 9
const Mul = 10
const Opposite = 11
const Pow = 12
const Sub = 13
const TypeMultiplier = 14

const And = 15
const Not = 16
const Or = 17

const Equal = 18
const Greater = 19
const GreaterEqual = 20
const Lesser = 21
const LesserEqual = 22
const NotEqual = 23

const List = 24
const Dict = 25

const Num = 26
const Str = 27

const GetCallingHook = 31
const GetCallingState = 32
const GetCallingStateId = 33
const GetCallingStateName = 34
const GetRootState = 35
const GetRootStateId = 36
const GetRootStateName = 37
const GetRootHook = 38

const GetMovesByOwner = 39
const GetMoveValue = 40
const GetOwnId = 41
const GetOwnMoveValue = 42

const Keys = 43
const Values = 44
const In = 45

var opcode
var parameters = []

func _init(opcode, parameters):
	self.opcode = opcode
	self.parameters = parameters

func out(level):
	var tab = ""
	for i in range(level):
		tab += "  "
	print(tab + identify())
	for p in parameters:
		p.out(level+1)

func identify():
	match opcode:

		Index:
			return "index"
		IsArgSet:
			return "isArgSet"
		IsVarSet:
			return "isVarSet"
		Property:
			return "property"
		Variable:
			return "variable"
		
		Abs:
			return "abs"
		Add:
			return "add"
		Ceil:
			return "ceil"
		Div:
			return "div"
		Floor:
			return "floor"
		Mul:
			return "mul"
		Opposite:
			return "opposite"
		Pow:
			return "pow"
		Sub:
			return "sub"
		TypeMultiplier:
			return "typeMultiplier"

		And:
			return "and"
		Not:
			return "not"
		Or:
			return "or"
			
		Equal:
			return "equal"
		Greater:
			return "greater"
		GreaterEqual:
			return "greaterEqual"
		Lesser:
			return "lesser"
		LesserEqual:
			return "lesserEqual"
		NotEqual:
			return "notEqual"

		List:
			return "list"
		Dict:
			return "dict"

		Num:
			return "num"
		Str:
			return "str"
		
		GetCallingHook:
			return "getCallingHook"
		GetCallingState:
			return "getCallingState"
		GetCallingStateId:
			return "getCallingStateId"
		GetCallingStateName:
			return "getCallingStateName"
		GetRootHook:
			return "getRootHook"
		GetRootState:
			return "getRootState"
		GetRootStateId:
			return "getRootStateId"
		GetRootStateName:
			return "getRootStateName"
			
		GetMovesByOwner:
			return "getMovesByOwner"
		GetMoveValue:
			return "getMoveValue"
		GetOwnId:
			return "getOwnId"
		GetOwnMoveValue:
			return "getOwnMoveValue"

		Keys:
			return "keys"
		Values:
			return "values"
		In:
			return "in"

# This is gonna be long lol
func eval(arguments):
	var p = []
	for param in parameters:
		p.append(param.eval(arguments))

	match opcode:
		# Variable operations
		Index:
			return (p[0])[p[1]]
		IsArgSet:
			return p[0] in arguments.keys()
		IsVarSet:
			return p[0] in arguments["Variables"].keys()
		Property:
			return p[0].get(p[1])
		Variable:
			if p[0] in arguments["VARIABLES"].keys():
				return (arguments["VARIABLES"])[p[0]]
			elif p[0] in arguments.keys():
				return arguments[p[0]]
			else:
				return p[0]

		# Number operations
		Abs:
			return abs(p[0])
		Add:
			return p[0] + p[1]
		Ceil:
			return ceil(p[0])
		Div:
			return p[0] / p[1]
		Floor:
			return floor(p[0])
		Mul:
			return p[0] * p[1]
		Opposite:
			return -1*p[0]
		Pow:
			return pow(p[0], p[1])
		Sub:
			return p[0] - p[1]
		TypeMultiplier:
			return StaticData.type_multipliers[p[0]][p[1]]

		# Bool Operations
		And:
			return p[0] and p[1]
		Not:
			return not p[0]
		Or:
			return p[0] or p[1]

		# Comparison Operators
		Equal:
			return p[0] == p[1]
		Greater:
			return p[0] > p[1]
		GreaterEqual:
			return p[0] >= p[1]
		Lesser:
			return p[0] < p[1]
		LesserEqual:
			return p[0] <= p[1]
		NotEqual:
			return p[0] != p[1]

		# List and dict
		List:
			return p
		Dict:
			var out_dict = {}
			var i = 0
			while i < len(p) - 1:
				out_dict[p[i]] = p[i+1]
				i += 2
			return out_dict

		# Typecast operations
		Num:
			return float(p[0])
		Str:
			return str(p[0])
		
		# Hook stack getters
		GetCallingHook:
			return getStackFrameFromPosition(arguments, p[0])[1]
		GetCallingState:
			return getStackFrameFromPosition(arguments, p[0])[0]
		GetCallingStateId:
			return getStackFrameFromPosition(arguments, p[0])[0].id
		GetCallingStateName:
			return getStackFrameFromPosition(arguments, p[0])[0].name
		GetRootHook:
			return arguments["STACK"][0][1]
		GetRootState:
			return arguments["STACK"][0][0]
		GetRootStateId:
			return arguments["STACK"][0][0].id
		GetRootStateName:
			return arguments["STACK"][0][0].name
		
		GetMovesByOwner:
			var output = []
			for m in arguments["MOVES"]:
				if m.owner_key == p[0]:
					output.append(m)
			return output
		GetMoveValue:
			for m in arguments["MOVES"]:
				if m.id == p[0]:
					return m.get(p[1])
			return null
		GetOwnId:
			return arguments["STACK"][0][0].id
		GetOwnMoveValue:
			return arguments["STACK"][0][0].get(p[0])
		
		Keys:
			return p[0].keys()
		Values:
			return p[0].values()
		In:
			return p[0] in p[1]
		
		_:
			assert(false, "Unrecognized operation opcode " + str(opcode))

func getStackFrameFromPosition(arguments, position):
	var stack = arguments["STACK"]
	var minusone = len(stack) - 1
	if position > minusone:
		position = minusone
	return stack[ minusone - position ]

func clone():
	var node = get_script().new(opcode, [])
	for k in parameters:
		node.parameters.append(k.clone())
	return node
