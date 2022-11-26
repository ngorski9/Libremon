extends Reference

const node_type = 2

const Num = 0
const Str = 1
const Bool = 2

var opcode
var data

func _init(opcode, data):
	self.opcode = opcode
	self.data = data

func out(level):
	var tab = ""
	for i in range(level):
		tab += "  "
	print(tab + str(data))

# Arguments is taken as a parameter for eval so that this node can be substituted
# for other node where arguments are also a parameter for eval and the 
func eval(arguments):
	match opcode:
		Num:
			return float(data)
		Str:
			return str(data)
		Bool:
			return bool(data)
		_:
			assert(false, "Unrecognized literal opcode " + str(opcode))

func clone():
	return self
