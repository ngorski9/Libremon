tool
extends Control

export var ally = false setget setAlly

signal animation_finished(animation)

var has_focus

func set_focus(value):
	if value and (not has_focus):
		has_focus = true
		$AnimationPlayer.play("Bob")
	elif (not value) and has_focus:
		has_focus = false
		$AnimationPlayer.stop()
		$AnimationPlayer.play("RESET")

func _ready():
	if Engine.editor_hint:
		$mainSprite.self_modulate = Color(1.0,1.0,1.0,1.0)
	else:
		$mainSprite.self_modulate = Color(1.0,1.0,1.0,0)

func appear_immediately():
	$mainSprite.self_modulate = Color(1.0,1.0,1.0,1.0)

func setAlly(a):
	ally = a
	if $mainSprite:
		$mainSprite.flip_h = a
	if $silhouette:
		$silhouette.flip_h = a

func set_sprite(monster):
	$mainSprite.texture.atlas = load("res://assets/monsters/" + monster + ".png")

func _set(property, value):
	if property == "texture":
		$silhouette.texture = value

func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name != "RESET":
		emit_signal("animation_finished", "Sprite " + anim_name)
	
func play_animation(anim_name):
	$AnimationPlayer.play(anim_name)

func play_backwards(anim_name):
	$AnimationPlayer.play_backwards(anim_name)

func make_visible():
	$mainSprite.self_modulate = Color(1.0,1.0,1.0,1.0)
