extends Control

class_name CheckersAI

class MCTS_Node:
	var state : Controller.State
	var parent : MCTS_Node
	var children : Array
	var visits : int = 0
	var wins : int = 0
	func _init(s, p):
		state = s
		parent = p
		children = []


var controller 
var number_of_iterations = 25 # 1000 is good enough
var ai_player = Controller.stone_color.white


func _ready():
#	randomize()
	pass

func propose_move() -> Controller.Move:
#	return propose_move_simple()
	return propose_move_mcts()

func propose_move_simple() -> Controller.Move:
	for possible_move in controller.possible_moves(controller.state_current()):
		if controller.is_correct_move(controller.state_current(), possible_move):
			return possible_move
	return null # Error, should not happen

func propose_move_mcts() -> Controller.Move:
	# https://en.wikipedia.org/wiki/Monte_Carlo_tree_search
	var root : MCTS_Node = MCTS_Node.new(controller.state_current(), null)
	if len(controller.possible_moves(root.state)) == 1:
		return select_best(root)
	for iteration in number_of_iterations:
		var selected_node : MCTS_Node = selection(root)
		var expanded_node : MCTS_Node = expansion(selected_node)
		var winner = simulation(expanded_node)
		backpropagation(expanded_node, winner)
	return select_best(root)

func selection(root) -> MCTS_Node:
	var current_node : MCTS_Node = root
	while len(current_node.children) != 0 and len(current_node.children) == len(controller.possible_moves(current_node.state)):
		current_node = select_child(current_node.children)
	return current_node

var c : float = sqrt(2)

func select_child(children) -> MCTS_Node:
	# https://en.wikipedia.org/wiki/Monte_Carlo_tree_search#Exploration_and_exploitation
	var highest_uct : float = -1.0
	var best_child : MCTS_Node = null
	var N : int = 0
	for child in children:
		N += child.visits
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
	var possible_moves : Array = controller.possible_moves(node.state)
	if len(possible_moves) > 0:
		var untested_move : Controller.Move = possible_moves[len(node.children)]
		var new_state = controller.state_after(node.state, untested_move)
		node.children.append(MCTS_Node.new(new_state, node))
		return node.children.back()
	else:
		return node

var tie_limit : int = 50

func simulation(node) -> bool:
	var current_state : Controller.State = node.state
	var timer
	var counter : int = 0
	while current_state.winner == null and counter < tie_limit:
		counter += 1
		var random_move : Controller.Move = controller.random_move(current_state)
		current_state = controller.state_after(current_state, random_move)
	if counter == tie_limit:
		return [Controller.stone_color.black, Controller.stone_color.white][randi() % 2] # tie = coinflip
	else:
		return current_state.winner

func big_advantage(state : Controller.State):
	var black_men : int = controller.count_stones(state, Controller.stone_type.man, Controller.stone_color.black)
	var white_men : int = controller.count_stones(state, Controller.stone_type.man, Controller.stone_color.white)
	var black_kings : int = controller.count_stones(state, Controller.stone_type.king, Controller.stone_color.black)
	var white_kings : int = controller.count_stones(state, Controller.stone_type.king, Controller.stone_color.white)
	if black_men >= white_men + 2 and black_kings > white_kings:
		return controller.stone_color.black
	if white_men >= black_men + 2 and white_kings > black_kings:
		return controller.stone_color.white
	return null

func backpropagation(node : MCTS_Node, winner):
	while node.parent != null:
		node.visits += 1
		if winner == node.parent.state.player:
			node.wins += 1
		node = node.parent

func select_best(root) -> Controller.Move:
	var best_index : int = 0
	for child_index in len(root.children):
		if root.children[child_index].visits > root.children[best_index].visits:
			best_index = child_index
	return controller.possible_moves(controller.state_current())[best_index]
