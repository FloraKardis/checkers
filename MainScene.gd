extends Control

onready var controller : Controller = get_node("Controller")
onready var interface : Interface = get_node("Interface")
onready var ai : CheckersAI = get_node("CheckersAI")

func _ready():
	interface.connect_to_ai(ai)
	interface.connect_to_controller(controller)
	ai.init(controller)

