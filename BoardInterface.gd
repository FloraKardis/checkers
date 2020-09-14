extends Node2D

class_name BoardInterface

const interface_users = [Controller.stone_color.black]

# Move:
var from
var to

var buttons : HistoryInterface
var controller : Controller
var ai : CheckersAI
var user_color
var stones : Array = []

func get_size() -> Vector2:
	return get_node("Sprite").texture.get_size()

func setup():
	from = controller.from
	to = controller.to
	set_squares()
	buttons = self.get_parent().buttons
	pause = 0.5
	paused_function = pausable_functions.set_stones

func set_squares():
	for square_number in controller.square_numbers:
		var new_square = load("res://SquareInterface.tscn").instance()
		new_square.initialize(square_number, self)
		new_square.set_name("Square" + String(square_number))
		add_child(new_square)

func set_stones(animate):
	game_over = false
	for stone in stones:
		stone.queue_free()
	stones.clear()
	for square_number in controller.square_numbers:
		if controller.current_state.board[square_number] != Controller.field.empty:
			put_stone(square_number, animate)

func check_all_put():
	var all_put = true
	for stone in stones:
		if stone.status != StoneInterface.animation_status.none:
			all_put = false
	if all_put:
		set_user_color()
	if reverted_change != null:
		reset()

func set_user_color():
	if controller.current_state.player in interface_users:
		user_color = controller.current_state.player
	else:
		user_color = null

func reset():
	set_stones(false)
	set_user_color()
	if not controller.current_state.player in interface_users:
		buttons.animate_lock()
		if reverted_change != null:
			revert(controller.history.undo())
		elif redone_change != null:
			redo(controller.history.redo())
		else:
			paused_function = pausable_functions.propose_move
			pause = 0.3
	else:
		reverted_change = null
		redone_change = null
		buttons.animate_unlock()

func put_stone(square_number : int, animate : bool):
	var new_stone = load("res://StoneInterface.tscn").instance()
	add_child(new_stone)
	stones.append(new_stone)
	new_stone.initialize(square_number, self)
	if animate:
		new_stone.animate_put(square_number)
	else:
		new_stone.scale = Vector2(1, 1)

func calculate_on_screen_position(square_number : int):
	var shift = controller.board_size / 2
	var square_size : int = load("res://SquareInterface.tscn").instance().get_size()
	var sprite_shift : int = square_size / 2
	var horizontal_position : int = (square_number % controller.board_size) - shift
	var vertical_position : int = (square_number / controller.board_size) - shift + 1
	return Vector2(horizontal_position, -vertical_position) * square_size + Vector2(sprite_shift, sprite_shift)

func calculate_order(number : int):
	var board_size = controller.board_size
	return (board_size * board_size) - (number - (number % board_size) + board_size - (number % board_size))

var captured_stone : StoneInterface
var promoted_stone : StoneInterface
var winner = null # : Controller.stone_color

func try_move(move, stone_interface):
	if controller.is_correct_move(controller.current_state, move):
		var change : Controller.Change = controller.make_move(move)
		ai.update_state(change.state_new)
		stone_interface.move_to(get_node("Square" + String(move[to])).position)
		stone_interface.set_square(move[to])
		if change.captured != null:
			captured_stone = find_stone(change.captured)
		if change.promoted:
			promoted_stone = find_stone(move[to])
		winner = change.winner
	else:
		stone_interface.move_to(get_node("Square" + String(move[from])).position)
	user_color = null

var reverted_change : Controller.Change = null
var redone_change : Controller.Change = null
var moved_stone : StoneInterface = null

func revert(change : Controller.Change):
	moved_stone = find_stone(change.move[to])
	controller.revert(change)
	reverted_change = change
	user_color = change.state_old.player
	moved_stone.move_to(get_node("Square" + String(change.move[from])).position)

func redo(change : Controller.Change):
	moved_stone = find_stone(change.move[from])
	controller.redo(change)
	redone_change = change
	user_color = change.state_new.player
	if change.captured != null:
		captured_stone = find_stone(change.captured)
	if change.promoted:
		promoted_stone = moved_stone
	moved_stone.move_to(get_node("Square" + String(change.move[to])).position)

func find_stone(square_number : int): # this is ugly, but I can't be bothered
	for stone in stones:
		if stone.square_number == square_number:
			return stone

var game_over : bool = false

# ANIMATION

func move_finished():
	if not game_over:
		if reverted_change == null:
			if captured_stone != null:
				captured_stone.animate_capture()
				captured_stone = null
			else:
				capture_finished()
		else:
			if reverted_change.captured != null:
				put_stone(reverted_change.captured, true)
			capture_finished()
	else:
		for stone in stones:
			stone.restart = true

func capture_finished():
	if not game_over:
		if reverted_change == null:
			if promoted_stone != null:
				promoted_stone.animate_promotion()
				promoted_stone = null
			else:
				if winner != null:
					clear_screen()
				else:
					reset()
		else:
			if reverted_change.promoted:
				moved_stone.animate_demotion()
			elif reverted_change.captured == null:
				promotion_finished()

func promotion_finished():
	if winner != null:
		clear_screen()
	else:
		reset()

var winner_squares : Array = []

var covers : Array = []

func clear_screen():
	game_over = true
	for stone in stones:
		if controller.color(controller.current_state, stone.square_number) == winner:
			stone.z_index = 3
	for square_number in range(controller.board_size * controller.board_size):
		var new_square = load("res://SquareInterface.tscn").instance()
		new_square.initialize(square_number, self)
		new_square.scale = Vector2(0, 0)
		add_child(new_square)
		winner_squares.append(new_square)
		new_square.animate_cover()
		covers.append(new_square)

func check_all_covered():
	var all_covered = true
	for square in covers:
		if not square.covered:
			all_covered = false
	if all_covered:
		paused_function = pausable_functions.show_the_winner
		pause = 1.0

func show_the_winner():
	buttons.animate_lock()
	buttons.hide()
	for stone in stones:
		if controller.color(controller.current_state, stone.square_number) == winner:
			stone.move_to(Vector2(0, 0))

enum pausable_functions { show_the_winner, set_stones, propose_move, try_move, none }
var pause : float
var paused_function = pausable_functions.none

var proposed_move = null

func _process(delta):
	if paused_function != pausable_functions.none:
		if pause > 0:
			pause -= delta
		if pause <= 0:
			if paused_function == pausable_functions.show_the_winner:
				show_the_winner()
			elif paused_function == pausable_functions.set_stones:
				set_stones(true)
			elif paused_function == pausable_functions.propose_move:
				paused_function = pausable_functions.none # to avoid calling more than once
				proposed_move = ai.propose_move()
				paused_function = pausable_functions.try_move # to avoid stuttered move
				pause = 0.2
				return
			elif paused_function == pausable_functions.try_move and proposed_move != null:
				paused_function = pausable_functions.none
				try_move(proposed_move, find_stone(proposed_move[from]))
				proposed_move = null
			paused_function = pausable_functions.none

func new_game():
	controller.reset()
	winner = null
	for stone in stones:
		stone.animate_capture()
	for square in covers:
		square.animate_uncover()
	buttons.animate_unlock()
	buttons.show()

func check_all_uncovered():
	var all_uncovered = true
	for square in covers:
		if square.covered:
			all_uncovered = false
	if all_uncovered:
		for cover in covers:
			cover.queue_free()
		covers.clear()
		paused_function = pausable_functions.set_stones
		pause = 0.25
