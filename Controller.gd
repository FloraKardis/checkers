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
	var player
	var forced_stone
	var winner
	func _init(b, p, fs, w):
		board = b
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
#var numbers_array : Array # of Array of int
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
#	numbers_array = []
#	for _row in board_size:
#		var row : Array = []
#		for _column in board_size:
#			row.append(-1)
#		numbers_array.append(row)
#	for square_number in square_numbers:
#		numbers_array[square_number / 8][square_number % 8] = square_number
#	print(numbers_array)

func set_new_board_state():
	clear_board_state()
#	current_state.board[0] = Stone.new(stone_color.black, stone_type.man, 0)
#	current_state.board[9] = Stone.new(stone_color.black, stone_type.man, 9)
#	current_state.board[25] = Stone.new(stone_color.white, stone_type.man, 25)
#	current_state.board[27] = Stone.new(stone_color.white, stone_type.man, 27)
	for square_number in square_numbers:
		var row_number : int = row(square_number)
		if row_number < stone_rows:
			current_state.board[square_number] = field.black_man
		if row_number >= board_size - stone_rows:
			current_state.board[square_number] = field.white_man
	current_state.player = first_player

func clear_board_state():
	current_state = State.new([], first_player, null, null)
	for _square_number in range(board_size * board_size):
		current_state.board.append(field.empty)

func make_move(move : Move) -> Change:
	if not is_correct_move(current_state, move):
		return null
	else:
		var old_state = deep_copy(current_state)
		var new_state = state_after(current_state, move)
		
		var captured = null
		var between : Array = stones_between(current_state, move)
		if len(between) == 1:
			captured = between[0]
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
	return State.new(state.board.duplicate(), state.player, state.forced_stone, state.winner)

func state_after(old_state : State, move : Move):
	# Assumes the move is correct	
	var new_state : State = deep_copy(old_state)
	new_state.board[move.to] = new_state.board[move.from]
	new_state.board[move.from] = field.empty
	new_state.forced_stone = null
	
	var more_captures : bool = false
	var between : Array = stones_between(new_state, move)
	if len(between) == 1:
		new_state.board[between[0]] = field.empty
		var possible_moves : Array = possible_stone_moves(new_state, move.to)
		if len(possible_moves) > 0 and is_capture(new_state, possible_moves[0]):
			more_captures = true
			new_state.forced_stone = move.to
	if not more_captures and type(new_state, move.to) == stone_type.man and crownhead(new_state.player, row(move.to)):
		promote(new_state, move.to)
	if more_captures:
		new_state.player = old_state.player
	else:
		new_state.player = switch_color(old_state.player)
	if possible_moves(new_state).empty(): # TODO this check could possibly be done earlier to save time
		new_state.winner = switch_color(new_state.player)
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
	if state.board[square_number] == field.black_man or state.board[square_number] == field.white_man:
		return stone_type.man
	else:
		return stone_type.king

func color(state : State, square_number : int):
	if state.board[square_number] == field.black_man or state.board[square_number] == field.black_king:
		return stone_color.black
	else:
		return stone_color.white

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
	return square_number + direction_to_number(direction) * distance

func get_direction(from, to): # -> move_direction:
	if (from == 0) and (to == board_size * board_size -1):
		return move_direction.NE
	if row(from) < row(to):
		if (to - from) % (board_size + 1) == 0:
			return move_direction.NE
		else:
			return move_direction.NW
	else: # row(from) > row(to):
		if (to - from) % (board_size + 1) == 0:
			return move_direction.SW
		else:
			return move_direction.SE

func get_distance(from, to):
	if int(abs(from - to)) % (board_size + 1) == 0:
		return int(abs(from - to)) / (board_size + 1)
	elif int(abs(from - to)) % (board_size - 1) == 0:
		return int(abs(from - to)) / (board_size - 1)

func diagonals(square_number) -> Array:
	var diagonals_array : Array = []
	for direction in all_directions:
		var temp : int = square_number
		while get_square(temp, direction, 1) in square_numbers:
			temp = get_square(temp, direction, 1)
			diagonals_array.append(temp)
	return diagonals_array

func compatible_with_current_state(state, move : Move):
	if not move.from in square_numbers or not move.to in square_numbers:
		return false
	if state.board[move.from] == field.empty or state.board[move.to] != field.empty:
		return false
	if not color(state, move.from) == state.player:
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
	return moves[randi() % len(moves)]

func possible_moves(state : State) -> Array:
	var moves : Array = []
	var captures : Array = []
	for square_number in square_numbers:
		if state.board[square_number] != field.empty:
			if color(state, square_number) == state.player:
				for move in possible_stone_moves(state, square_number):
					if is_capture(state, move):
						captures.append(move)
					if captures.empty():
						moves.append(move)
	if captures.empty():
		return moves
	else:
		return captures

func possible_stone_moves(state : State, from : int) -> Array:
	var non_captures : Array = []
	var captures : Array = []
	if type(state, from) == stone_type.man:
		for direction in all_directions:
			var to : int = get_square(from, direction, 2)
			var between : int = get_square(from, direction, 1)
			if to in square_numbers and state.board[to] == field.empty and state.board[between] != field.empty and color(state, between) == switch_color(color(state, from)):
				captures.append(Move.new(from, to))
		if captures.empty():
			for direction in man_directions(color(state, from)):
				var to : int = get_square(from, direction, 1)
				if to in square_numbers and state.board[to] == field.empty:
					non_captures.append(Move.new(from, to))
	else: # if stone.type == stone_type.king:
		for to in diagonals(from):
			if state.board[to] == field.empty:
				var new_move : Move = Move.new(from, to)
				if is_capture(state, new_move):
					captures.append(new_move)
				else:
					non_captures.append(new_move)
	if captures.empty():
		return non_captures
	else:
		return captures

func is_capture(state, move):
	if get_distance(move.from, move.to) < 2:
		return false
	else:
		var stones_array: Array = stones_between(state, move)
		return state.board[move.to] == field.empty and len(stones_array) == 1 and color(state, stones_array[0]) == switch_color(color(state, move.from))

func stones_between(state : State, move : Move) -> Array:
	var stones_array : Array = []
	var direction = get_direction(move.from, move.to)
	var temp : int = get_square(move.from, direction, 1)
	while temp != move.to:
		if state.board[temp] != field.empty:
			stones_array.append(temp)
		temp = get_square(temp, direction, 1)
	return stones_array

func man_directions(color) -> Array:
	if color == stone_color.black:
		return [move_direction.NW, move_direction.NE]
	else: # color == stone_color.white:
		return [move_direction.SE, move_direction.SW]

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
