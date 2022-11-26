tool
extends Button

const margin = 14

export(String) var real_text = "" setget setText

func setText(t):
	if $MainText:
		real_text = t
		text = "| " + t
		$MainText.text = t

func _on_ArrowButton_focus_entered():
	$Arrow.visible = true

func _on_ArrowButton_focus_exited():
	$Arrow.visible = false
