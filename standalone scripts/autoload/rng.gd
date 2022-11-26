extends Node

var generator = RandomNumberGenerator.new()

func random():
	generator.randomize()
	return generator.randf()

func randi_range(a,b):
	generator.randomize()
	return generator.randi_range(a,b)

