tool
extends Label

const small_font = preload("res://tres/fonts/libremon_custom_small.tres")
const large_font = preload("res://tres/fonts/libremon_custom.tres")

# I don't like that I have to put it here rather than in autoload!
# tbh this would be way easier if I could figure out rich text
enum ColorScheme { DARK = 0, WHITE = 1, RED = 2}
enum TextSize{ SMALL, LARGE }

export(ColorScheme) var color_scheme = ColorScheme.DARK setget setColors
export(TextSize) var font_size = TextSize.LARGE setget setFontSize

var mainColor = Color("000000")
var shadowColor = Color("bebebe")

func _ready():
	setFontSize(font_size)

func _set(property, value):
	if property == "text":
		$OtherShadow.text = value
	elif property == "align":
		$OtherShadow.align = value
	elif property == "autowrap":
		$OtherShadow.autowrap = value
	elif property == "visible_characters":
		$OtherShadow.visible_characters = value
	elif property == "percent_visible":
		$OtherShadow.percent_visible = value
	elif property == "lines_skipped":
		$OtherShadow.lines_skipped = value
	elif property == "max_lines_visible":
		$OtherShadow.max_lines_visible = value

func setColors(e):
	color_scheme = e
	if e == ColorScheme.DARK:
		mainColor = Color("000000")
		shadowColor = Color("bebebe")
	elif e == ColorScheme.WHITE:
		mainColor = Color("ffffff")
		shadowColor = Color("282828")
	elif e == ColorScheme.RED:
		mainColor = Color("ff0000")
		shadowColor = Color("000000")
	set("custom_colors/font_color", mainColor)
	set("custom_colors/font_color_shadow", shadowColor)
	$OtherShadow.set("custom_colors/font_color", shadowColor)
	$OtherShadow.set("custom_colors/font_color_shadow", shadowColor)

func setFontSize(e):
	font_size = e
	if e == TextSize.SMALL:
		set("custom_fonts/font", small_font)
		$OtherShadow.set("custom_fonts/font", small_font)
	if e == TextSize.LARGE:
		set("custom_fonts/font", large_font)
		$OtherShadow.set("custom_fonts/font", large_font)
