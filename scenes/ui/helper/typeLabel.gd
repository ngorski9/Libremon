extends ColorRect

func updateToType(type):
	if type == "":
		visible = false
	else:
		visible = true
		color = Color(StaticData.type_colors[type])
		$ShadowLabel.text = type.to_upper()
