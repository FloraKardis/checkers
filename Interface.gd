extends Control

class_name Interface

const board_size : float = 0.9 # Board to window width ratio
const board_shift : float = 0.5 # Vertical shift from the top of the window in %
const buttons_size : float = 1.0
const buttons_shift : float = 3.27
const slider_size : float = 0.75
const slider_shift : float = -3.27

onready var board : BoardInterface = get_node("BoardInterface")
onready var buttons : HistoryInterface = board.get_node("HistoryInterface")
onready var slider : AIInterface = board.get_node("AIInterface")

func _ready():
	adjust_to_screen(board, board_size, board_shift)
	adjust_to_screen(buttons, buttons_size, buttons_shift)
	adjust_to_screen(slider,slider_size, slider_shift)
	slider.position.x = 0
	buttons.z_index = 100

func adjust_to_screen(interface_element, element_size, element_vertical_shift):
	var screen_size : Vector2 = get_viewport().get_visible_rect().size
	var screen_width : float = screen_size.x
	var ratio: float = screen_width / interface_element.get_size()
	interface_element.set_scale(Vector2(1, 1) * ratio * element_size)
	interface_element.set_position(Vector2(screen_size.x * 0.5, screen_size.y * element_vertical_shift))
#	interface_element.position.y =  screen_size.y * element_vertical_shift
#
#func adjust_to_screen2(interface_element, element_size, element_vertical_shift):
#	var screen_size : Vector2 = get_viewport().get_visible_rect().size
#	var screen_width : float = screen_size.x
#	var ratio: float = screen_width / interface_element.get_size()
#	interface_element.set_scale(Vector2(1, 1) * ratio * element_size)
#	interface_element.position.y =  screen_size.y * element_vertical_shift
##	interface_element.set_position(Vector2(screen_size.x * 0.5, screen_size.y * element_vertical_shift))
#	pass

func connect_to_ai(ai):
	board.ai = ai
	slider.ai = ai
	ai.set_difficulty(slider.selected)

func connect_to_controller(controller : Controller):
	board.controller = controller
	board.setup()
	buttons.board_interface = board
