extends Area2D

class_name StoneInterface

onready var sprite : Sprite = get_node("Sprite")
onready var focus : Sprite = get_node("Focus")
var board_interface # : BoardInterface
var square_number : int
var restart : bool


func initialize(new_number, interface):
	board_interface = interface
	square_number = new_number
	focus.visible = false
	focus.z_index = 4
	set_sprite()
	position = board_interface.calculate_on_screen_position(square_number)
	restart = false

func set_sprite():
	var field = board_interface.controller.current_state.board[square_number]
	if field == Controller.field.black_man:
		sprite.texture = load("res://Sprites/stone_black.png")
	if field == Controller.field.white_man:
		sprite.texture = load("res://Sprites/stone_white.png")
	if field == Controller.field.black_king:
		sprite.texture = load("res://Sprites/king_black.png")
	if field == Controller.field.white_king:
		sprite.texture = load("res://Sprites/king_white.png")
	scale = Vector2(0, 0)

func set_square(number : int):
	square_number = number

# DRAG'N'DROP

var square_to : int
var picked_up : bool = false

func _input_event(viewport, event, shape_idx):
	if restart and event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed:
			board_interface.new_game()
	else:
		if is_pickable() and event is InputEventMouseButton:
			if event.button_index == BUTTON_LEFT:
				if event.pressed:
					picked_up = true
					z_index = 1
					square_to = square_number

func is_pickable():
	var controller = board_interface.controller
	return controller.color(controller.current_state, square_number) == board_interface.user_color

func send_try_move():
	picked_up = false
	z_index = 0
	board_interface.try_move([square_number, square_to], self)

# ANIMATION

enum animation_status { waiting_to_put, being_put, moving, being_captured, disappearing, appearing, focusing, none }
enum type_change { promotion, demotion, none}

var moving : bool = false
var move_speed = 4000
var capture_speed = 4
var focus_speed = 2
var target : Vector2
var wait_time : float = -1
var wait_factor : float = 50.0
var status
var change = type_change.none

func move_to(position : Vector2):
	status = animation_status.moving
	target = position
	var start = self.position

var being_captured : bool = false

func animate_capture():
	status = animation_status.being_captured

func animate_put(number : int):
	scale = Vector2(0, 0)
	set_sprite()
	focus.visible = false
	var order = board_interface.calculate_order(number)
	status = animation_status.waiting_to_put
	wait_time = order / wait_factor

func animate_promotion():
	status = animation_status.disappearing
	change = type_change.promotion

func animate_demotion():
	status = animation_status.disappearing
	change = type_change.demotion

func animate_focus():
	status = animation_status.focusing
	focus.visible = true

func _process(delta):
	if picked_up:
		global_position = get_global_mouse_position()
		if not Input.is_action_pressed("left_click"):
			send_try_move()
	if status == animation_status.moving:
		z_index += 1
		position = position.move_toward(target, delta * move_speed)
		if position.distance_to(target) < 10:
			position = target
			z_index -= 1
			status = animation_status.none
			board_interface.move_finished()
	if status == animation_status.being_captured or status == animation_status.disappearing:
		scale -= Vector2(capture_speed, capture_speed) * delta
		if scale.x < 0.1:
			scale = Vector2(0, 0)
			if status == animation_status.being_captured:
				status = animation_status.none
				board_interface.capture_finished()
			else:
				set_sprite()
				status = animation_status.appearing
	if status == animation_status.waiting_to_put:
		wait_time -= delta
		if wait_time < 0:
			status = animation_status.being_put
	if status == animation_status.being_put or status == animation_status.appearing:
		scale += Vector2(capture_speed, capture_speed) * delta
		if scale.x > 0.95:
			scale = Vector2(1, 1)
			if status == animation_status.being_put:
				status = animation_status.none
				board_interface.check_all_put()
			else:
				status = animation_status.none
				change = type_change.none
				board_interface.promotion_finished()
	if status == animation_status.focusing:
		focus.scale += Vector2(focus_speed, focus_speed) * delta
		focus.set_modulate(Color(1, 1, 1, 2 - focus.scale.x))
		if focus.scale.x > 2:
			focus.scale = Vector2(2, 2)
			status = animation_status.none
			board_interface.focus_finished()

