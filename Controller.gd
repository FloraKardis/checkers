extends Control

class_name Controller

enum stone_color { black, white }
enum stone_type { man, king }
enum move_direction { NW, NE, SE, SW }

enum field { empty, black_man, black_king, white_man, white_king }

#class Move:
#	var from
#	var to
#	func _init(f, t):
#		from = f
#		to = t

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
const all_colors : Array = [stone_color.black, stone_color.white]
const first_player = stone_color.black
const board_size : int = 8
const stone_rows : int = 3
# Move:
const from = 0
const to = 1

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
	square_numbers.clear()
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
#	current_state.stone_squares[stone_color.black].append(0)
#	current_state.board[9] = field.black_man
#	current_state.stone_squares[stone_color.black].append(9)
#	current_state.board[25] = field.white_man
#	current_state.stone_squares[stone_color.white].append(25)
#	current_state.board[27] = field.white_man
#	current_state.stone_squares[stone_color.white].append(27)

	for square_number in square_numbers:
		var row_number : int = row(square_number)
		if row_number < stone_rows:
			current_state.board[square_number] = field.black_man
			current_state.stone_squares[stone_color.black].append(square_number)
		if row_number >= board_size - stone_rows:
			current_state.board[square_number] = field.white_man
			current_state.stone_squares[stone_color.white].append(square_number)

	current_state.board[32] = field.black_man
	current_state.stone_squares[stone_color.black].append(32)
	current_state.board[25] = field.white_man
	current_state.stone_squares[stone_color.white].append(25)
	current_state.board[18] = field.empty
	current_state.stone_squares[stone_color.black].erase(18)

	current_state.player = first_player


func clear_board_state():
	current_state = State.new([], [[],[]], first_player, null, null)
	for _square_number in range(board_size * board_size):
		current_state.board.append(field.empty)

func make_move(move) -> Change:
	if not is_correct_move(current_state, move):
		return null
	else:
		var old_state = deep_copy(current_state)
		var new_state = state_after(current_state, move)
		
		var captured = stone_between(current_state, move)
		var promoted : bool = type(old_state, move[from]) != type(new_state, move[to])

		current_state = new_state
		var change : Change = Change.new(
			old_state, 
			deep_copy(new_state), 
			move, # TODO is copy neccessary?
			captured, promoted, new_state.winner)
		if save_history:
			history.add(change)
#		print("\n\nnew state:")
#		print_board(current_state.board)
#		print("current player: ", current_state.player)
#		print("black stones:   ", current_state.stone_squares[stone_color.black])
#		print("white stones:   ", current_state.stone_squares[stone_color.white])
#		print("forced stone:   ", current_state.forced_stone)
#		print("winner:         ", current_state.winner)
		var moves = possible_moves(current_state)
#		for _i in range(1000):
#			var random_move = random_move(current_state)
#			for possible_move in moves:
#				if possible_move[from] == random_move[from] and possible_move[to] == random_move[to]:
#					moves.erase(possible_move)
#		print("not proposed by random_move(): ", moves)
		return change

func deep_copy(state : State) -> State:
	return State.new(state.board.duplicate(), state.stone_squares.duplicate(true), state.player, state.forced_stone, state.winner)

func state_after(state : State, move) -> State:
	return calculate_state_after(state, move, true, true)

func calculate_state_after(old_state : State, move, make_copy : bool, check_win : bool) -> State:
	# Assumes the move is correct
	var new_state : State
	if make_copy:
		new_state = deep_copy(old_state)
	else:
		new_state = old_state
	
	new_state.board[move[to]] = new_state.board[move[from]]
	new_state.board[move[from]] = field.empty
	new_state.stone_squares[new_state.player].erase(move[from])
	new_state.stone_squares[new_state.player].append(move[to])
	new_state.forced_stone = null
	
	var more_captures : bool = false
		
	var between = stone_between(new_state, move)
	if between != null:
		new_state.board[between] = field.empty
		new_state.stone_squares[switch_color(new_state.player)].erase(between)
		var possible_moves : Array = possible_stone_moves(new_state, move[to], new_state.player)
		if moves_are_captures:
			more_captures = true
			new_state.forced_stone = move[to]

	if not more_captures and type(new_state, move[to]) == stone_type.man and crownhead(new_state.player, row(move[to])):
		promote(new_state, move[to])
	
	if more_captures:
		new_state.player = old_state.player
	else:
		new_state.player = switch_color(old_state.player)
	
	if check_win:
		if possible_moves(new_state).empty(): # TODO this check could possibly be done earlier to save time
			new_state.winner = switch_color(new_state.player)
	
	return new_state

func stone_between(state : State, move):
	var stone = null
	var direction = get_direction(move)
	var fields_in_direction = diagonals[move[from]][direction]
	var index : int = 0 # TODO jeśli dictionary to 1
	var between : int = fields_in_direction[index]
	while between != move[to]:
		if state.board[between] != field.empty:
			return between
		index += 1
		between = fields_in_direction[index]
	return stone

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

func get_direction(move): # -> move_direction:
	if (move[from] == 0):
		return move_direction.NE
	if row(move[from]) < row(move[to]):
		if (move[to] - move[from]) % (board_size + 1) == 0:
			return move_direction.NE
		else:
			return move_direction.NW
	else: # row(from) > row(to):
		if (move[to] - move[from]) % (board_size + 1) == 0:
			return move_direction.SW
		else:
			return move_direction.SE

func is_correct_move(state, move):
	if state.forced_stone != null and move[from] != state.forced_stone:
		return false
	if not compatible_with_current_state(state, move):
		return false
	if not contains_move(move, possible_moves(state)):
		return false
	return true

func compatible_with_current_state(state, move):
	if not move[from] in square_numbers or not move[to] in square_numbers:
		return false
	var stone_field_from = state.board[move[from]]
	if stone_field_from == field.empty or state.board[move[to]] != field.empty:
		return false
	if not field_color(stone_field_from) == state.player:
		return false
	return true

func contains_move(move, moves : Array):
	return move in moves

func random_move(state : State):
	return random_move_good(state)
#	return random_move_bad(state)

func random_move_good(state : State):
	if state.forced_stone != null:
		var moves = possible_stone_moves(state, state.forced_stone, state.player)
		return moves[randi() % len(moves)]
	else:
		var moves = possible_moves(state)
		if len(moves) == 0:
			return null
		else:
			return moves[randi() % len(moves)]

func random_move_bad(state : State):
	var moves : Array = []
	if state.forced_stone != null:
		moves = possible_stone_moves(state, state.forced_stone, state.player)
		return moves[randi() % len(moves)]
	else:
		
		var stones : Array = state.stone_squares[state.player].duplicate()
		var stones_number : int = len(stones)
		var stones_permutation : Array = []
		for _i in stones_number:
			var random_index : int = randi() % len(stones)
			stones_permutation.append(stones[random_index])
			stones.remove(random_index)
		for stone in stones_permutation:
			if len(moves) == 0:
				moves = possible_stone_moves(state, stone, state.player)
			if moves_are_captures:
				return moves[randi() % len(moves)]
		
		if len(moves) == 0:
			return null
		else:
			return moves[randi() % len(moves)]

func possible_moves(state : State) -> Array:
	if state.forced_stone != null:
		return possible_stone_moves(state, state.forced_stone, state.player)
	var moves : Array = []
	var captures : Array = []
	for square_number in state.stone_squares[state.player]:
		var stone_moves = possible_stone_moves(state, square_number, state.player)
		if moves_are_captures:
			for move in stone_moves:
				captures.append(move)
		else:
			for move in stone_moves:
				moves.append(move)
	if captures.empty():
		return moves
	else:
		return captures

var moves_are_captures : bool

func possible_stone_moves(state : State, from : int, color : int) -> Array:
	var non_captures : Array = []
	var captures : Array = []
	var type = field_type(state.board[from])
	if type == stone_type.man:
		for direction in all_directions:
			var fields_in_direction = diagonals[from][direction]
			var fields_number : int = len(fields_in_direction)
			if fields_number > 0:
				var one_away : int = fields_in_direction[0]
				var field_one_away = state.board[one_away]
				if field_one_away == field.empty:
					if direction in man_directions[color]:
						non_captures.append([from, one_away])
				elif fields_number > 1:
					var two_away : int = fields_in_direction[1]
					var field_two_away = state.board[two_away]
					if field_two_away == field.empty and field_color(field_one_away) != color:
						captures.append([from, two_away])
	else: # if stone.type == stone_type.king:
		for direction in all_directions:
			var enemy_stone_between : bool = false
			for to in diagonals[from][direction]:
				var stone_field = state.board[to]
				if stone_field == field.empty:
					if enemy_stone_between:
						captures.append([from, to])
					else:
						non_captures.append([from, to])
				elif field_color(stone_field) != color:
#					enemy_stone_between = true
					if enemy_stone_between == false:
						enemy_stone_between = true
					else:
						break
				else:
					break
	if captures.empty():
		moves_are_captures = false
		return non_captures
	else:
		moves_are_captures = true
		return captures

func switch_color(color):
	if color == stone_color.black:
		return stone_color.white
	else:
		return stone_color.black

func row(a):
	return a / board_size

func same_state(state1 : State, state2 : State) -> bool:
	# assumes the states are correct
	return state1.board == state2.board # and state1.player == state2.player and state1.forced_stone == state2.forced_stone

func count_stones(state : State) -> int:
	return len(state.stone_squares[0] + state.stone_squares[1])

func print_board(board : Array):
	for i in range(8):
		var string = ""
		for j in range(8):
			if board[(7-i)*8 + j] != field.empty:
				string += str(board[(7-i)*8 + j]) + " "
			else:
				string += "  "
		print(string)
