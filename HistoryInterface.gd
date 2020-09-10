extends Node2D

class_name HistoryInterface

const distance_apart : float = 1.8 # In button sizes

onready var undo_button : InterfaceButton = get_node("Undo")
onready var redo_button : InterfaceButton = get_node("Redo")

var board_interface # : BoardInterface

# Called when the node enters the scene tree for the first time.
func _ready():
	undo_button.initialize(self)
	redo_button.initialize(self)
	var button_width : float = get_size().x
	var half_distance : float = distance_apart / 2
	undo_button.position.x = -button_width - button_width * half_distance
	redo_button.flip()
	redo_button.position.x = button_width * half_distance
	undo_button_default_position = undo_button.position
	redo_button_default_position = redo_button.position

func get_size() -> Vector2:
	return get_node("Undo").get_node("Sprite").texture.get_size()

func clicked():
	if undo_button.clicked:
		undo_button.clicked = false
		var change : Controller.Change = board_interface.controller.history.undo()
		if change != null:
			board_interface.revert(change)
	else:
		redo_button.clicked = false
		var change : Controller.Change = board_interface.controller.history.redo()
		if change != null:
			board_interface.redo(change)

# ANIMATION

enum animation_status { locking, unlocking, none }

var status = animation_status.none # animation_status
var locking_speed: int = 4000
var undo_button_default_position : Vector2
var redo_button_default_position : Vector2

func animate_lock():
	undo_button.fill()
	redo_button.fill()
	deactivate_all()
	status = animation_status.locking

func animate_unlock():
	undo_button.empty()
	redo_button.empty()
	activate_all()
	status = animation_status.unlocking

func activate_all():
	undo_button.active = true
	redo_button.active = true

func deactivate_all():
	undo_button.active = false
	redo_button.active = false

func _process(delta):
	if status == animation_status.locking:
		undo_button.position.x += locking_speed * delta
		redo_button.position.x -= locking_speed * delta
		var shift: float = undo_button.get_node("CollisionShape2D").position.x
		if undo_button.position.x >= 0:
			undo_button.position.x = shift/4
			redo_button.position.x = -undo_button.position.x - get_size().x
			status = animation_status.none
	if status == animation_status.unlocking:
		undo_button.position.x -= locking_speed * delta
		redo_button.position.x += locking_speed * delta
		var shift: float = undo_button.get_node("CollisionShape2D").position.x
		if undo_button.position.x <= undo_button_default_position.x:
			undo_button.position.x = undo_button_default_position.x
			redo_button.position.x = redo_button_default_position.x
			status = animation_status.none
