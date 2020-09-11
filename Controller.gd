extends Control

class_name Controller

enum stone_color { black, white }
enum stone_type { man, king }
enum move_direction { NW, NE, SE, SW }

enum field { empty, black_man, black_king, white_man, white_king }

class Move:
	var from
	var to
	func _init(f, t):
		from = f
		to = t

class State:
	var board
	var stone_squares
	var player
	var forced_stone
	var winner
	func _init(b, ss, p, fs, w):
		board = b
		stone_squares = ss
		player = p
		forced_stone = fs
		winner = w

class Change:
	var state_old
	var state_new
	var move
	var captured
	var promoted
	var winner
	func _init(so, sn, m, c, p, w):
		state_old = so
		state_new = sn
		move = m
		captured = c
		promoted = p
		winner = w


const all_directions : Array = [move_direction.NW, move_direction.NE, move_direction.SE, move_direction.SW]
const first_player = stone_color.black
const board_size : int = 8
const stone_rows : int = 3

var square_numbers : Array # of int
var diagonals : Array
# 3-dimensional array, storing squares reachable from a given square, by direction and distance, e.g.:
# diagonals[square_number][direction][distance]
var colors : Array
var types : Array
var man_directions : Array
var current_state : State

onready var history : History = get_node("History")
var save_history : bool = true

func _ready():
	reset()

func reset():
	set_square_numbers()
	set_new_board_state()
	history.reset()

func set_square_numbers():
	# https://oeis.org/A225240
	for number in range(1, board_size * board_size + 1):
		if number % 2 + (1 - 2 * (number % 2)) * (number - 1) / board_size % 2:
			square_numbers.append(number - 1)
	diagonals = []
	for index in board_size * board_size:
		diagonals.append(null)
	for square_number in square_numbers:
		diagonals[square_number] = []
		for direction in all_directions:
			diagonals[square_number].append([])
			for distance in range(1, board_size):
				var number = square_number + direction_to_number(direction) * distance
				if number in square_numbers:
					diagonals[square_number][direction].append(number)
	colors = []
	types = []
	for i in range(5):
		colors.append(stone_color.white)
		types.append(stone_type.man)
	colors[field.black_man] = stone_color.black
	colors[field.black_king] = stone_color.black
	types[field.black_king] = stone_type.king
	types[field.white_king] = stone_type.king
	man_directions = [null, null]
	man_directions[stone_color.black] = [move_direction.NW, move_direction.NE]
	man_directions[stone_color.white] = [move_direction.SE, move_direction.SW]

func set_new_board_state():
	clear_board_state()
#	current_state.board[0] = field.black_man
#	current_state.board[9] = field.black_man
#	current_state.board[25] = field.white_man
#	current_state.board[27] = field.white_man
	for square_number in square_numbers:
		var row_number : int = row(square_number)
		if row_number < stone_rows:
			current_state.board[square_number] = field.black_man
			current_state.stone_squares[stone_color.black].append(square_number)
		if row_number >= board_size - stone_rows:
			current_state.board[square_number] = field.white_man
			current_state.stone_squares[stone_color.white].append(square_number)
	current_state.player = first_player

func clear_board_state():
	current_state = State.new([], [[],[]], first_player, null, null)
	for _square_number in range(board_size * board_size):
		current_state.board.append(field.empty)

func make_move(move : Move) -> Change:
	if not is_correct_move(current_state, move):
		return null
	else:
		var old_state = deep_copy(current_state)
		var new_state = state_after(current_state, move)
		
		var captured = stones_between(current_state, move)
		var promoted : bool = type(old_state, move.from) != type(new_state, move.to)

		current_state = new_state
		var change : Change = Change.new(
			old_state, 
			deep_copy(new_state), 
			Move.new(move.from, move.to), # TODO maybe copy not necessary?
			captured, promoted, new_state.winner)
		if save_history:
			history.add(change)
		return change

func deep_copy(state : State) -> State:
	return State.new(state.board.duplicate(), state.stone_squares.duplicate(true), state.player, state.forced_stone, state.winner)

func state_after(state : State, move : Move) -> State:
	return calculate_state_after(state, move, true, true)

func calculate_state_after(old_state : State, move : Move, make_copy : bool, check_win : bool) -> State:
	# Assumes the move is correct
	var timer = OS.get_system_time_msecs()
	var new_state : State
	if make_copy:
		new_state = deep_copy(old_state)
	else:
		new_state = old_state
	
	new_state.board[move.to] = new_state.board[move.from]
	new_state.board[move.from] = field.empty
	new_state.stone_squares[new_state.player].erase(move.from)
	new_state.stone_squares[new_state.player].append(move.to)
	new_state.forced_stone = null
	
	var more_captures : bool = false
	
	setup += OS.get_system_time_msecs() - timer
	timer = OS.get_system_time_msecs()
	
	var between = stones_between(new_state, move)
	
	stones_between_timer += OS.get_system_time_msecs() - timer
	timer = OS.get_system_time_msecs()
	
	if between != null:
		new_state.board[between] = field.empty
		new_state.stone_squares[switch_color(new_state.player)].erase(between)
		var possible_moves : Array = possible_stone_moves(new_state, move.to, new_state.player)
		if len(possible_moves) > 0 and is_capture(new_state, possible_moves[0]):
			more_captures = true
			new_state.forced_stone = move.to
	
	forced_stone_timer += OS.get_system_time_msecs() - timer
	timer = OS.get_system_time_msecs()
	
	if not more_captures and type(new_state, move.to) == stone_type.man and crownhead(new_state.player, row(move.to)):
		promote(new_state, move.to)
	
	promotion_timer += OS.get_system_time_msecs() - timer
	timer = OS.get_system_time_msecs()
	
	if more_captures:
		new_state.player = old_state.player
	else:
		new_state.player = switch_color(old_state.player)
		
	new_player_timer += OS.get_system_time_msecs() - timer
	timer = OS.get_system_time_msecs()
	
	if check_win:
		if possible_moves(new_state).empty(): # TODO this check could possibly be done earlier to save time
			new_state.winner = switch_color(new_state.player)
	
	check_win_timer += OS.get_system_time_msecs() - timer
	
	return new_state

func revert(change : Change):
	current_state = deep_copy(change.state_old)

func redo(change : Change):
	current_state = deep_copy(change.state_new)

func promote(state : State, square_number : int):
	if state.board[square_number] == field.black_man:
		state.board[square_number] = field.black_king
	else:
		state.board[square_number] = field.white_king

func type(state : State, square_number : int):
	return types[state.board[square_number]]

func field_type(stone_field):
	return types[stone_field]

func color(state : State, square_number : int):
	return colors[state.board[square_number]]

func field_color(stone_field):
	return colors[stone_field]

func crownhead(color, row):
	return (color == stone_color.black and row == board_size - 1) or (color == stone_color.white and row == 0)

func direction_to_number(direction) -> int:
	var signum : int = 1
	var offset : int = 1
	if direction in [move_direction.SW, move_direction.SE]:
		signum = -1
	if direction in [move_direction.NW, move_direction.SE]:
		offset = -1
	return signum * (board_size + offset)

func get_square(square_number : int, direction, distance) -> int:
	return diagonals[square_number][direction][distance]

func get_direction(move): # -> move_direction:
	if (move.from == 0) and (move.to == board_size * board_size -1):
		return move_direction.NE
	if row(move.from) < row(move.to):
		if (move.to - move.from) % (board_size + 1) == 0:
			return move_direction.NE
		else:
			return move_direction.NW
	else: # row(from) > row(to):
		if (move.to - move.from) % (board_size + 1) == 0:
			return move_direction.SW
		else:
			return move_direction.SE

func get_distance(move):
	if int(abs(move.from - move.to)) % (board_size + 1) == 0:
		return int(abs(move.from - move.to)) / (board_size + 1)
	elif int(abs(move.from - move.to)) % (board_size - 1) == 0:
		return int(abs(move.from - move.to)) / (board_size - 1)

func compatible_with_current_state(state, move : Move):
	if not move.from in square_numbers or not move.to in square_numbers:
		return false
	var stone_field_from = state.board[move.from]
	if stone_field_from == field.empty or state.board[move.to] != field.empty:
		return false
	if not field_color(stone_field_from) == state.player:
		return false
	return true

func is_correct_move(state, move : Move):
	if state.forced_stone != null and move.from != state.forced_stone:
		return false
	if not compatible_with_current_state(state, move):
		return false
	if not contains_move(move, possible_moves(state)):
		return false
	return true

func contains_move(move : Move, moves : Array):
	for possible_match in moves:
		if possible_match.from == move.from and possible_match.to == move.to:
			return true
	return false

func random_move(state : State) -> Move:
	var moves = possible_moves(state)
	if len(moves) == 0:
		return null
	return moves[randi() % len(moves)]


var setup = 0
var stones_between_timer = 0
var forced_stone_timer = 0
var promotion_timer = 0
var new_player_timer = 0
var check_win_timer = 0
var declaring = 0
var man_captures = 0
var man_moves = 0
var king_moves = 0
var appending = 0
var possible_timer = 0

func reset_timers():
	setup = 0
	stones_between_timer = 0
	forced_stone_timer = 0
	promotion_timer = 0
	new_player_timer = 0
	check_win_timer = 0
	declaring = 0
	man_captures = 0
	man_moves = 0
	king_moves = 0
	appending = 0
	possible_timer = 0

func print_timers(calculate_state_after, random_move_timer):
	print("calculate_state_after: ", calculate_state_after)
	print("    setup:          ", setup)
	print("    stones_between: ", stones_between_timer)
	print("    forced_stone:   ", forced_stone_timer)
	print("    promotion:      ", promotion_timer)
	print("    new_player:     ", new_player_timer)
	print("    check_win:      ", check_win_timer)
	print("random_move:           ", random_move_timer)
	print("    declaring:      ", declaring)
	print("    man_captures:   ", man_captures)
	print("    man_moves:      ", man_moves)
	print("    king_moves:     ", king_moves)
	print("    possible_timer: ", possible_timer)
	print("    appending:      ", appending)

func possible_moves(state : State) -> Array:
	if state.forced_stone != null:
		return possible_stone_moves(state, state.forced_stone, state.player)
	var moves : Array = []
	var captures : Array = []
	for square_number in state.stone_squares[state.player]:
		var timer = OS.get_system_time_msecs()
		var stone_moves = possible_stone_moves(state, square_number, state.player)
		possible_timer += OS.get_system_time_msecs() - timer
		timer = OS.get_system_time_msecs()
		if moves_are_captures:
			for move in stone_moves:
				captures.append(move)
		else:
			for move in stone_moves:
				moves.append(move)
		appending += OS.get_system_time_msecs() - timer
	if captures.empty():
		return moves
	else:
		return captures

var moves_are_captures : bool

func possible_stone_moves(state : State, from : int, color : int) -> Array:
	var timer_big = OS.get_system_time_msecs()
	var moves : Array = []
	var timer
	var type = field_type(state.board[from])
	declaring += OS.get_system_time_msecs() - timer_big
	if type == stone_type.man:
		timer = OS.get_system_time_msecs()
		for fields_in_direction in diagonals[from]:
			if len(fields_in_direction) > 1:
				var to : int = fields_in_direction[1]
				var between : int = fields_in_direction[0]
				if state.board[to] == field.empty and state.board[between] != field.empty and color(state, between) == switch_color(color):
					moves.append(Move.new(from, to))
		man_captures += OS.get_system_time_msecs() - timer
		timer = OS.get_system_time_msecs()
		if moves.empty():
			moves_are_captures = false
			for direction in man_directions[color]:
				var fields_in_direction = diagonals[from][direction]
				if not fields_in_direction.empty():
					var to : int = fields_in_direction[0]
					if state.board[to] == field.empty:
						moves.append(Move.new(from, to))
		else:
			moves_are_captures = true
		man_moves += OS.get_system_time_msecs() - timer
	else: # if stone.type == stone_type.king:
		timer = OS.get_system_time_msecs()
		var non_captures : Array = []
		var captures : Array = []
		for direction in all_directions:
			for to in diagonals[from][direction]:
				if state.board[to] == field.empty:
					var new_move : Move = Move.new(from, to)
					if get_distance(new_move) < 2:
						non_captures.append(new_move)
					else:
						var between = stones_between(state, new_move)
						if between != null and color(state, between) == switch_color(color(state, from)):
							captures.append(new_move)
						else:
							non_captures.append(new_move)
		if captures.empty():
			moves_are_captures = false
			moves = non_captures
		else:
			moves_are_captures = true
			moves = captures
		king_moves += OS.get_system_time_msecs() - timer
	possible_timer += OS.get_system_time_msecs() - timer_big
	return moves

func is_capture(state, move):
	if get_distance(move) < 2:
		return false
	else:
		var between = stones_between(state, move)
		return state.board[move.to] == field.empty and between != null and color(state, between) == switch_color(color(state, move.from))

func stones_between(state : State, move : Move):
	var stone = null
	var direction = get_direction(move)
	var fields_in_direction = diagonals[move.from][direction]
	var index : int = 0 # TODO jeśli dictionary to 1
	var between : int = fields_in_direction[index]
	while between != move.to:
		if state.board[between] != field.empty:
			if stone == null:
				stone = between
			else:
				return null
		index += 1
		between = fields_in_direction[index]
	return stone

func switch_color(color):
	if color == stone_color.black:
		return stone_color.white
	else:
		return stone_color.black

func row(a):
	return a / board_size
	
func print_board(board : Array):
	for i in range(8):
		var string = ""
		for j in range(8):
			if board[(7-i)*8 + j] != field.empty:
				string += str(board[(7-i)*8 + j]) + " "
			else:
				string += "  "
		print(string)
