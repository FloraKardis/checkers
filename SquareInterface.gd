extends Node2D

class_name SquareInterface

var number : int
var order : int
var board_interface # : BoardInterface

func initialize(square_number : int, interface):
	board_interface = interface
	number = square_number
	var board_size = board_interface.controller.board_size
	order = board_interface.calculate_order(square_number)
	set_position(board_interface.calculate_on_screen_position(square_number))

func get_size() -> int:
	return get_node("Sprite").texture.get_size().x

# DRAG'N'DROP

var mouse_in : bool = false
var stone_over : StoneInterface

func _on_SquareInterface_area_entered(stone_interface):
	if stone_interface is StoneInterface:
		if stone_interface.picked_up:
			stone_over = stone_interface
			try_set_square()

func _on_SquareInterface_area_exited(area):
	stone_over = null

func _on_SquareInterface_mouse_entered():
	mouse_in = true
	try_set_square()

func _on_SquareInterface_mouse_exited():
	mouse_in = false
	if stone_over != null:
		stone_over.square_to = stone_over.square_number

func try_set_square():
	if mouse_in and stone_over != null:
		stone_over.square_to = number

# ANIMATION

enum animation_status { waiting_to_cover, waiting_to_uncover, covering, uncovering, none }

var wait_time : float = -1
var wait_factor : float = 50.0
var covering : bool = false
var animation_speed = 4
var covered = false
#var pause_time : float = 1.0
var status = animation_status.none

func animate_cover():
	z_index = 2
	scale = Vector2(0, 1)
	animate(animation_status.waiting_to_cover)

func animate_uncover():
	animate(animation_status.waiting_to_uncover)

func animate(new_status):
	status = new_status
	wait_time = order / wait_factor

func _process(delta):
	if status != animation_status.none:
		wait_time -= delta
		if wait_time < 0:
#			wait_time = 0
			if status == animation_status.waiting_to_cover:
				status = animation_status.covering
			if status == animation_status.waiting_to_uncover:
				status = animation_status.uncovering
	if status == animation_status.covering:
		scale += Vector2(animation_speed, 0) * delta
		if scale.x > 0.99:
			scale = Vector2(1, 1)
			status = animation_status.none
			covered = true
			board_interface.check_all_covered()
	if status == animation_status.uncovering:
		scale -= Vector2(animation_speed, 0) * delta
		if scale.x < 0.01:
			scale = Vector2(0, 0)
			status = animation_status.none
			covered = false
			board_interface.check_all_uncovered()
#	if covered:
#		if pause_time > 0:
#			pause_time -= delta
#		if pause_time <= 0:
#			covered = false
#			board_interface.show_the_winner()
