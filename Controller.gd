extends Control

class_name Controller

enum stone_color { black, white }
enum stone_type { man, king }
enum move_direction { NW, NE, SE, SW }

#enum field { empty, black_man, black_king, white_man, white_king }

class Stone:
	var color
	var type
	var square_number : int
	func _init(c, t, sn):
		color = c
		type = t
		square_number = sn

class Move:
	var stone
	var to
	func _init(s, t):
		stone = s
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
var numbers_array : Array # of Array of int
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
	numbers_array = []
	for _row in board_size:
		var row : Array = []
		for _column in board_size:
			row.append(-1)
		numbers_array.append(row)
	for square_number in square_numbers:
		numbers_array[square_number / 8][square_number % 8] = square_number
	print(numbers_array)

func set_new_board_state():
	clear_board_state()
	for square_number in square_numbers:
		var row_number : int = row(square_number)
		if row_number < stone_rows:
			current_state.board[square_number] = Stone.new(stone_color.black, stone_type.man, square_number)
		if row_number >= board_size - stone_rows:
			current_state.board[square_number] = Stone.new(stone_color.white, stone_type.man, square_number)
#	current_state.board[0] = Stone.new(stone_color.black, stone_type.man, 0)
#	current_state.board[9] = Stone.new(stone_color.black, stone_type.man, 9)
#	current_state.board[25] = Stone.new(stone_color.white, stone_type.man, 25)
#	current_state.board[27] = Stone.new(stone_color.white, stone_type.man, 27)
	current_state.player = first_player

func clear_board_state():
	current_state = State.new([], first_player, null, null)
	for _square_number in range(board_size * board_size):
		current_state.board.append(null)

func make_move(move : Move) -> Change:
	if not is_correct_move(current_state, move):
		return null
	else:
		var old_state = deep_copy(current_state)
		var new_state = state_after(current_state, move)
		
		var captured = null
		var between : Array = stones_between(current_state, move.stone.square_number, move.to)
		if len(between) == 1:
			captured = between[0]
		var promoted : bool = not new_state.forced_stone and move.stone.type == stone_type.man and crownhead(current_state.player, row(move.to))

		current_state = new_state
		var change : Change = Change.new(
			old_state, 
			deep_copy(new_state), 
			Move.new(Stone.new(move.stone.color, move.stone.type, move.stone.square_number), move.to),
			captured, promoted, new_state.winner)
		if save_history:
			history.add(change)
		return change

func deep_copy(state : State) -> State:
	var new_array : Array = []
	for square_number in range(board_size * board_size):
		if state.board[square_number] == null:
			new_array.append(null)
		else:
			var old_stone : Stone = state.board[square_number]
			new_array.append(Stone.new(old_stone.color, old_stone.type, old_stone.square_number))
	var forced_stone = null
	if state.forced_stone != null:
		forced_stone = Stone.new(state.forced_stone.color, state.forced_stone.type, state.forced_stone.square_number)
	return State.new(new_array, state.player, forced_stone, state.winner)

func state_current():
	return current_state

func state_after(old_state : State, move : Move):
	# Assumes the move is correct
	var new_state : State = deep_copy(old_state)
	new_state.board[move.to] = new_state.board[move.stone.square_number]
	new_state.board[move.to].square_number = move.to
	new_state.board[move.stone.square_number] = null
	
	var more_captures : bool = false
	var between : Array = stones_between(new_state, move.stone.square_number, move.to)
	if len(between) == 1:
		new_state.board[between[0].square_number] = null
		var possible_moves : Array = possible_stone_moves(new_state, new_state.board[move.to])
		if len(possible_moves) > 0 and is_capture(new_state, possible_moves[0]):
			more_captures = true
	if not more_captures and move.stone.type == stone_type.man and crownhead(new_state.player, row(move.to)):
		new_state.board[move.to].type = stone_type.king
	new_state.forced_stone = null
	if more_captures:
		new_state.player = old_state.player
		new_state.forced_stone = new_state.board[move.to]
	else:
		new_state.player = switch_color(old_state.player)
	if possible_moves(new_state).empty():
		new_state.winner = switch_color(new_state.player)
	return new_state

func revert(change : Change):
	current_state = deep_copy(change.state_old)
	for square_number in range(board_size * board_size):
		if current_state.board[square_number] != null:
			current_state.board[square_number].square_number = square_number

func redo(change : Change):
	current_state = deep_copy(change.state_new)
	for square_number in range(board_size * board_size):
		if current_state.board[square_number] != null:
			current_state.board[square_number].square_number = square_number

func promote(stone : Stone):
	stone.type = stone_type.king
	return stone

func crownhead(color, row):
	return (color == stone_color.black and row == board_size - 1) or (color == stone_color.white and row == 0)

func same_stone(stone1 : Stone, stone2 : Stone):
	if (stone1 == null) and (stone2 == null):
		return true
	if (stone1 == null and stone2 != null) or (stone1 != null and stone2 == null):
		return false
	return (stone1.color == stone2.color) and (stone1.type == stone2.type) and (stone1.square_number == stone2.square_number)

func compatible_with_current_state(state, move : Move):
	if not move.stone.color == state.player:
		return false
	if not move.stone.square_number in square_numbers:
		return false
	if not move.to in square_numbers:
		return false
	if state.board[move.to] != null:
		return false
	if not same_stone(move.stone, state.board[move.stone.square_number]):
		return false
	return true

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

func is_correct_move(state, move : Move):
	if state.forced_stone != null and move.stone != state.forced_stone:
		return false
	if not compatible_with_current_state(state, move):
		return false
	var all_moves : Array = possible_moves(state)
	if not contains_move(move, all_moves):
		return false
	if captures_possible(state, all_moves) and not is_capture(state, move):
		return false
	return true

func contains_move(move : Move, moves : Array):
	for possible_match in moves:
		if same_stone(move.stone, possible_match.stone) and move.to == possible_match.to:
			return true
	return false

func random_move(state : State) -> Move:
	var stones : Array = []
	for square_number in square_numbers:
		if state.board[square_number] != null:
			stones.append(state.board[square_number])
	
	var stone_index : int = randi() % len(stones)
	var possible_moves : Array = possible_stone_moves(state, stones[stone_index])
	while possible_moves.empty():
		stones.remove(stone_index)
		stone_index = randi() % len(stones)
		possible_moves = possible_stone_moves(state, stones[stone_index])
	
	var moves : Array = []
	var captures : Array = []
	for move in possible_moves:
		if captures.empty():
			moves.append(move)
		if is_capture(state, move):
			captures.append(move)
	if captures.empty():
		return moves[randi() % len(moves)]
	else:
		return captures[randi() % len(captures)]

func possible_moves(state : State) -> Array:
	var moves : Array = []
	var captures : Array = []
	for square_number in square_numbers:
		if state.board[square_number] != null:
			var stone : Stone = state.board[square_number]
			if stone.color == state.player:
				for move in possible_stone_moves(state, stone):
					if captures.empty():
						moves.append(move)
					if is_capture(state, move):
						captures.append(move)
	if captures.empty():
		return moves
	else:
		return captures

func possible_stone_moves(state : State, stone : Stone) -> Array:
	var non_captures : Array = []
	var captures : Array = []
	if stone.type == stone_type.man:
		for direction in all_directions:
			var to : int = get_square(stone.square_number, direction, 2)
			var between : int = get_square(stone.square_number, direction, 1)
			if to in square_numbers and state.board[to] == null and state.board[between] != null and state.board[between].color == switch_color(stone.color):
				captures.append(Move.new(stone, to))
		if captures.empty():
			for direction in man_directions(stone.color):
				var to : int = get_square(stone.square_number, direction, 1)
				if to in square_numbers and state.board[to] == null:
					non_captures.append(Move.new(stone, to))
	else: # if stone.type == stone_type.king:
		for to in diagonals(stone.square_number):
			if state.board[to] == null:
				var stones_between : Array = stones_between(state, stone.square_number, to)
				if correct_capture(state, stone, to, stones_between):
					captures.append(Move.new(stone, to))
				if stones_between.empty():
					non_captures.append(Move.new(stone, to))
	if captures.empty():
		return non_captures
	else:
		return captures

func captures_possible(state : State, moves_list : Array):
	for move in moves_list:
		if correct_capture(state, move.stone, move.to, stones_between(state, move.stone.square_number, move.to)):
			return true
	return false

func is_capture(state, move):
	return correct_capture(state, move.stone, move.to, stones_between(state, move.stone.square_number, move.to))

func correct_capture(state : State, stone : Stone, to : int, stones_between : Array) -> bool:
	var stones_array: Array = stones_between(state, stone.square_number, to)
	return state.board[to] == null and len(stones_between) == 1 and stones_between[0].color == switch_color(stone.color)

func stones_between(state : State, from, to) -> Array:
	var stones_array : Array = []
	var direction = get_direction(from, to)
	var temp : int = get_square(from, direction, 1)
	while temp != to:
		if state.board[temp] != null:
			stones_array.append(state.board[temp])
		temp = get_square(temp, direction, 1)
	return stones_array

func count_stones(state : State, type, color) -> int:
	var counter : int = 0
	for stone in state.board:
		if stone != null and stone.type == type and stone.color == color:
			counter += 1
	return counter

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
			if board[(7-i)*8 + j] != null:
				string += str(board[(7-i)*8 + j].square_number) + " "
			else:
				string += "  "
		print(string)
