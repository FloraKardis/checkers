extends Control

class_name CheckersAI

class MCTS_Node:
	var state : Controller.State
	var possible_moves : Array
#	var possible_moves_number : int # TODO: This could slightly help
	var parent : MCTS_Node
	var children : Array
	var visits : int = 0
	var wins : int = 0
	func _init(s, p, controller):
		state = s
		possible_moves = controller.possible_moves(state)
		parent = p
		children = []


var controller : Controller
var difficulty : int
var max_number_of_iterations = 10000
var difficulty_factors : Array = [0.1, 0.3, 0.6, 1.0]
var ai_player = Controller.stone_color.white


func init(new_controller  : Controller):
	randomize()
	controller = new_controller
	root = MCTS_Node.new(controller.current_state, null, controller)

var root
var thread # TODO

func update_state(new_state):
	for node in root.children:
		if controller.same_state(node.state, new_state):
			root = node
			root.parent = null
			return
	root = MCTS_Node.new(new_state, null, controller)

func set_difficulty(new_difficulty : int):
	difficulty = new_difficulty

func propose_move():
#	return propose_move_first()
#	return propose_move_random()
	return propose_move_mcts()

func propose_move_first():
	return controller.possible_moves(controller.current_state)[0]

func propose_move_random():
	return controller.random_move(controller.current_state)

func propose_move_mcts():
	# https://en.wikipedia.org/wiki/Monte_Carlo_tree_search
	if len(root.possible_moves) == 1:
		return select_best(root)
	
	var number_of_iterations = number_of_iterations()
	
	while root.visits < number_of_iterations:
		var selected_node : MCTS_Node = selection(root)
		var expanded_node : MCTS_Node = expansion(selected_node)
		var winner = simulation(expanded_node)
		backpropagation(expanded_node, winner)
	
	return select_best(root)

func number_of_iterations():
	var number_of_iterations : int
	var number_of_stones : int = controller.count_stones(root.state)
	if number_of_stones == 24 and root.visits == 0: # Just the first move
		number_of_iterations = int(max_number_of_iterations * 0.1) 
	else:
		if number_of_stones > 20:
			number_of_iterations = int(max_number_of_iterations * 0.3)
		elif number_of_stones > 16:
			number_of_iterations = int(max_number_of_iterations * 0.4)
		elif number_of_stones > 12:
			number_of_iterations = int(max_number_of_iterations * 0.5)
		elif number_of_stones > 10:
			number_of_iterations = int(max_number_of_iterations * 0.6)
		elif number_of_stones > 8:
			number_of_iterations = int(max_number_of_iterations * 0.7)
		else:
			number_of_iterations = max_number_of_iterations
	return number_of_iterations * difficulty_factors[difficulty - 1]

func selection(root) -> MCTS_Node:
	var current_node : MCTS_Node = root
	while len(current_node.children) != 0 and len(current_node.children) == len(current_node.possible_moves):
		current_node = select_child(current_node.visits, current_node.children)
	return current_node

const c : float = sqrt(2)

func select_child(N, children) -> MCTS_Node:
	# https://en.wikipedia.org/wiki/Monte_Carlo_tree_search#Exploration_and_exploitation
	var highest_uct : float = -1.0
	var best_child : MCTS_Node = null
	var ln_N : float = log(float(N))
	for child in children:
		var w : float = float(child.wins)
		var n : float = float(child.visits)
		var uct : float = w / n + c * sqrt(ln_N / n)
		if uct > highest_uct:
			highest_uct = uct
			best_child = child
	return best_child

func expansion(node) -> MCTS_Node:
	if len(node.possible_moves) > 0:
		var untested_move = node.possible_moves[len(node.children)]
		var new_state = controller.state_after(node.state, untested_move)
		node.children.append(MCTS_Node.new(new_state, node, controller))
		return node.children.back()
	else:
		return node

const simulation_limit : int = 100
const tie_limit : int = 30

var moves_until_tie
var stones_lost_previous

func simulation(node) -> bool:
	var current_state : Controller.State = controller.deep_copy(node.state)
	var counter : int = 0
	
	stones_lost_previous = [0, 0]
	moves_until_tie = tie_limit
	
	var big_advantage = null
	var random_move = null
	if len(node.possible_moves) > 0:
		random_move = node.possible_moves[randi() % len(node.possible_moves)]
	while random_move != null and not tie(node.state, current_state) and counter < simulation_limit and big_advantage == null:
		counter += 1
		current_state = controller.calculate_state_after(current_state, random_move, false, false)
		random_move = controller.random_move(current_state)
		big_advantage = big_advantage(node.state, current_state)
	if counter == simulation_limit or tie(node.state, current_state):
		return [Controller.stone_color.black, Controller.stone_color.white][randi() % 2] # tie = coinflip
	elif big_advantage != null:
		return big_advantage
	else:
		return controller.switch_color(current_state.player)

func tie(old_state : Controller.State, new_state : Controller.State):
	return false
	if stones_lost_previous != stones_lost(old_state, new_state):
		moves_until_tie = tie_limit
	else:
		moves_until_tie -= 1
	if moves_until_tie == 0:
		return true
	else:
		return false

var small_stones_difference = 2
var big_stones_difference = 3

func small_advantage(old_state : Controller.State, new_state : Controller.State):
	var stones_lost = stones_lost(old_state, new_state)
	var black_stones_lost : int = stones_lost[Controller.stone_color.black]
	var white_stones_lost : int = stones_lost[Controller.stone_color.white]
	if black_stones_lost + small_stones_difference <= white_stones_lost:
		return Controller.stone_color.black
	if white_stones_lost + small_stones_difference <= white_stones_lost:
		return Controller.stone_color.white
	return null

func big_advantage(old_state : Controller.State, new_state : Controller.State):
	var stones_lost = stones_lost(old_state, new_state)
	var black_stones_lost : int = stones_lost[Controller.stone_color.black]
	var white_stones_lost : int = stones_lost[Controller.stone_color.white]
	if black_stones_lost + big_stones_difference <= white_stones_lost:
		return Controller.stone_color.black
	if white_stones_lost + big_stones_difference <= white_stones_lost:
		return Controller.stone_color.white
	return null

func stones_lost(old_state : Controller.State, new_state : Controller.State) -> Array:
	var black_stones_old : int = len(old_state.stone_squares[Controller.stone_color.black])
	var white_stones_old : int = len(old_state.stone_squares[Controller.stone_color.white])
	var black_stones_new : int = len(new_state.stone_squares[Controller.stone_color.black])
	var white_stones_new : int = len(new_state.stone_squares[Controller.stone_color.white])
	var black_stones_lost : int = black_stones_old - black_stones_new
	var white_stones_lost : int = white_stones_old - white_stones_new
	return [black_stones_lost, white_stones_lost]

func backpropagation(node : MCTS_Node, winner):
	while node.parent != null:
		node.visits += 1
		if winner == node.parent.state.player:
			node.wins += 1
		node = node.parent
	node.visits += 1

func select_best(root): 
	# TODO add tie/draw suggestion?
	var best_index : int = 0
	for child_index in len(root.children):
		if root.children[child_index].wins > root.children[best_index].wins:
			best_index = child_index
	return controller.possible_moves(controller.current_state)[best_index]

func print_node(node : MCTS_Node):
	print("\n\nNODE:")
	controller.print_board(node.state.board)
	print(node.wins, " / ", node.visits)
