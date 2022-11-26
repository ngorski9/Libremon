extends KinematicBody2D

var moving = false
var left_foot = false

const walk_time = 0.3 # time to walk between a tile, in seconds
const run_time = 0.15

var velocity = Vector2(0,0)
var target_position = Vector2(0,0)

var direction = "Down"

signal done_walking

func _ready():
	var directions = ["Up", "Down", "Left", "Right"]
	for d in directions:
		$Sprite.frames.set_animation_speed(d + "_Walk", 2 / walk_time)
		$Sprite.frames.set_animation_speed(d + "_Run", 2 / run_time)
		$Sprite.frame = 0
		$Sprite.animation = "Down_Walk"

func _process(_delta):
	if not moving:
		test_motion()

# returns True if a motion is inputted,
# returns False otherwise

func test_motion():
	var running = "Walk"
	if Input.is_action_pressed("ui_b"):
		running = "Run"
	if Input.is_action_pressed("ui_up"):
		direction = "Up"
		trigger_motion( Vector2(0, -1), running )
	elif Input.is_action_pressed("ui_down"):
		direction = "Down"
		trigger_motion( Vector2(0, 1), running )
	elif Input.is_action_pressed("ui_left"):
		direction = "Left"
		trigger_motion( Vector2(-1, 0), running )
	elif Input.is_action_pressed("ui_right"):
		direction = "Right"
		trigger_motion( Vector2(1, 0), running )
	else:
		return false
	return true

func trigger_motion(delta, running):
	# Cast a ray to see if the player can move
	var space_state = get_world_2d().direct_space_state
	var position = get_global_position()		
	var collision = space_state.intersect_ray(position, position + 23 * delta, [self], collision_mask)

	var blocked = false

	if collision:
		# (This will be used later)
		
		#print(collision.collider.get_class())
		# fetch the name of the tile
		#var tm = collision.collider
		#var tile_vec = ( (position + 9 * delta - tm.position) )
		#tile_vec = Vector2( floor(tile_vec.x / tm.cell_size.x ), floor(tile_vec.y / tm.cell_size.y) )
		#var tile_name = tm.tile_set.tile_get_name( tm.get_cellv( tile_vec ) )
		blocked = true
	
	if blocked:
		if moving:
			moving = false
			$Sprite.stop()
			$Sprite.frame = 0
		$Sprite.animation = direction + "_Walk"
	else:
		if not moving:
			moving = true
			# advance the animation by one frame on startup so as to allow walking to lead
			# with a foot-forward frame, rather than an idle frame.
			$Sprite.frame = ($Sprite.frame + 1) % $Sprite.frames.get_frame_count(direction + "_" + running)
		
		# Set the animation, preserving the frame number
		# And flicker the animation
		var frame_number = $Sprite.frame
		$Sprite.stop()
		$Sprite.play(direction + "_" + running)
		$Sprite.frame = frame_number
		
		if running == "Walk":
			$Tween.interpolate_property(self, "position", get_position(), get_position() + 32*delta, walk_time)
		else:
			$Tween.interpolate_property(self, "position", get_position(), get_position() + 32*delta, run_time)		
		$Tween.start()

func _on_Tween_tween_completed(_object, _key):
	var keep_moving = test_motion()

	if not keep_moving:
		moving = false

		$Sprite.stop()
		
		# grab the frame:
		var frame = $Sprite.frame
		
		# reset to walking animation
		$Sprite.animation = direction + "_Walk"
		$Sprite.frame = frame
		
		# Make sure that the stepping evens out
		if $Sprite.frame == 1:
			$Sprite.frame = 0
		elif $Sprite.frame == 3:
			$Sprite.frame = 2
	emit_signal("done_walking")
