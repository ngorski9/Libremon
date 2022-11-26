extends Reference

const node_type = 0 # action_type

const Animation_ = 0
const ApplyState = 1
const Damage = 2
const GetMonsterProperty = 3
const GetRandomFloat = 4
const GetRandomInt = 5
const Hit = 6
const Keep = 7
const Move = 8
const MoveNow = 9
const RemoveState = 10
const Return = 11
const PercentChance = 12
const Print = 13
const Set = 14
const SetArgument = 15
const SetAtIndex = 16
const Squash = 17
const Text = 18

var opcode
var parameters = []

var finished = false

func _init(opcode, parameters):
	self.opcode = opcode
	self.parameters = parameters

func identify():
	match opcode:
		Animation_:
			return "animation"
		ApplyState:
			return "applyState"
		Damage:
			return "damage"
		GetMonsterProperty:
			return "getMonsterProperty"
		GetRandomFloat:
			return "getRandomFloat"
		GetRandomInt:
			return "getRandomInt"
		Hit:
			return "hit"
		Move:
			return "move"
		RemoveState:
			return "removeState"
		Return:
			return "return"
		Keep:
			return "keep"
		PercentChance:
			return "percentChance"
		Print:
			return "print"
		Squash:
			return "squash"
		Set:
			return "set"
		SetArgument:
			return "setArgument"
		SetAtIndex:
			return "setAtIndex"
		Text:
			return "text"

func out(level):
	var tab = ""
	for i in range(level):
		tab += "  "
	print(tab + identify())
	for p in parameters:
		p.out(level+1)

func out_evaluated():
	var tab = "  "
	print(identify())
	for p in parameters:
		print(tab + str(p))

func eval(arguments):
	if finished:
		return null
	else:
		if opcode == Set:
			arguments["VARIABLES"][parameters[0].eval(arguments)] = parameters[1].eval(arguments)
			return null
		elif opcode == SetAtIndex:
			# This works because the only things that you set with an index are passed by reference
			# so there is no need to refer to arguments["VARIABLES"].
			parameters[0].eval(arguments)[parameters[1].eval(arguments)] = parameters[2].eval(arguments)
		elif opcode == Print:
			print(parameters[0].eval(arguments))
			return null
		else:
			finished = true
			var new_node = get_script().new( opcode, [] )
			for p in parameters:
				new_node.parameters.append(p.eval(arguments))
			return new_node

func hard_reset():
	finished = false

func clone():
	var node = get_script().new(opcode, [])
	for k in parameters:
		node.parameters.append(k.clone())
	return node
