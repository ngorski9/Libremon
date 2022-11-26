extends TextureButton

var evenTick = true

export(int) var selectedShiftDistance = 4	

const maleColor = Color("00ffcf")
const femaleColor = Color("ff0000")

var regular_texture_backup
var has_appearance_of_focus = false

# whether or not the box represents something that has fainted
var fainted = false

func _ready():
	texture_normal = AtlasTexture.new()
	texture_normal.atlas = load("res://assets/ui/party screen/libreboxes.png")
	texture_focused = AtlasTexture.new()
	texture_focused.atlas = load("res://assets/ui/party screen/libreboxes.png")
	$HealthBar.texture_progress = AtlasTexture.new()
	$HealthBar.texture_progress.atlas = load("res://assets/ui/party screen/healthbars.png")

func fake_appearance_of_focus(val):
	if val:
		if fainted:
			texture_normal.region = Rect2(0,152,220,76)
		else:
			texture_normal.region = Rect2(0,0,220,76)
	else:
		if fainted:
			texture_normal.region = Rect2(0,228,220,76)
		else:
			texture_normal.region = Rect2(0,76,220,76)

func shift(fainted_status_for):
	if not disabled:
		if (fainted_status_for == fainted) and (not fainted or has_focus() or has_appearance_of_focus):
			if evenTick:
				evenTick = false
			else:
				evenTick = true
			
			if evenTick:
				$MonsterIcon.texture.region = Rect2(0,0,64,64)
				if has_focus() or has_appearance_of_focus:
					$MonsterIcon.margin_top = -selectedShiftDistance
					$MonsterIcon.margin_bottom = -selectedShiftDistance
			else:
				if not fainted:
					$MonsterIcon.texture.region = Rect2(64,0,64,64)
				if has_focus() or has_appearance_of_focus:
					$MonsterIcon.margin_top = selectedShiftDistance
					$MonsterIcon.margin_bottom = selectedShiftDistance

func updateDataToMonster(mon):
	$NameLabel.text = mon.name
	print(mon.name)
	$genderLabel.setGender(mon.gender)

	$LevelLabel.text = "Lv " + str(mon.level)
	
	$HPLabel.text = str(mon.hp) + "/" + str(mon.stats["HP"])
	
	$HealthBar.value = mon.hp	
	print(mon.hp)
	print($HealthBar.value)
	var hp_stat = mon.stats["HP"]
	$HealthBar.max_value = hp_stat
	print(hp_stat)
	print($HealthBar.max_value)
	var percent = mon.hp / mon.stats["HP"]
	if percent >= 0.5:
		$HealthBar.texture_progress.region = Rect2(0,0,96,8)
	elif percent >= 0.25:
		$HealthBar.texture_progress.region = Rect2(0,8,96,8)
	else:
		$HealthBar.texture_progress.region = Rect2(0,8,96,8)
	if mon.hp == 0:
		fainted = true
		texture_normal.region = Rect2(0,228,220,76)
		texture_focused.region = Rect2(0, 152, 220, 76)
	else:
		fainted = false
		texture_normal.region = Rect2(0,76,220,76)
		texture_focused.region = Rect2(0,0,220,76)

	$MonsterIcon.texture = AtlasTexture.new()
	$MonsterIcon.texture.atlas = load("res://assets/monsters/" + mon.species + ".png")
	$MonsterIcon.texture.region = Rect2(0,0,64,64)

func set_texture_mode(mode, interest=null):
	if mode == "Normal" or mode == "Normal Options":
		if fainted:
			texture_focused.region = Rect2(0, 152, 220, 76)
			texture_normal.region = Rect2(0,228,220,76)
		else:
			texture_focused.region = Rect2(0,0,220,76)
			texture_normal.region = Rect2(0,76,220,76)
		if mode == "Normal Options" and name[-1] == str(interest + 1):
			fake_appearance_of_focus(true)
		elif has_appearance_of_focus:
			fake_appearance_of_focus(false)
	if mode == "Switch":
		texture_focused.region = Rect2(0,304,220,76)
		if name[-1] == str(interest + 1):
			texture_normal.region = Rect2(0,380,220,76)
		if has_appearance_of_focus:
			fake_appearance_of_focus(false)

func hide_graphics():
	for i in get_children():
		i.visible = false
		
func show_graphics():
	for i in get_children():
		i.visible = true

func _on_Control_focus_entered():
	if evenTick:
		$MonsterIcon.margin_top = -selectedShiftDistance
		$MonsterIcon.margin_bottom = -selectedShiftDistance
	else:
		$MonsterIcon.margin_top = selectedShiftDistance
		$MonsterIcon.margin_bottom = selectedShiftDistance

func _on_Control_focus_exited():
	$MonsterIcon.margin_top = 0
	$MonsterIcon.margin_bottom = 0
