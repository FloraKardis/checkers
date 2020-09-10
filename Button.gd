extends Area2D

class_name InterfaceButton

onready var sprite : Sprite = get_node("Sprite")
var history_interface # : HistoryInterface
var active : bool = true
var clicked = false

func initialize(hi):
	history_interface = hi

func flip():
	sprite.flip_h = true
	get_node("CollisionShape2D").position *= -1

func _on_Button_mouse_entered():
	if active:
		self.fill()

func _on_Button_mouse_exited():
	if active:
		self.empty()

func fill():
	sprite.texture = load("res://Sprites/arrow_filled.png")

func empty():
	sprite.texture = load("res://Sprites/arrow_empty.png")

func _on_Button_input_event(viewport, event, shape_idx):
	if active and event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		clicked = true
		history_interface.deactivate_all()
		history_interface.clicked()

