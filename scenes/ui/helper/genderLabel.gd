extends Label

const maleColor = Color("00ffcf")
const femaleColor = Color("ff0000")

func setGender(gender):
	if gender == "Male":
		text = "{"
		$otherShadow.text = "{"
		set("custom_colors/font_color", maleColor)
	elif gender == "Female":
		text = "}"
		$otherShadow.text = "}"
		set("custom_colors/font_color", femaleColor)
	else:
		text = ""
		$otherShadow.text = ""
