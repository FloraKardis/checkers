extends Area2D

class_name AIButton

onready var sprite = get_node("Sprite")
var interface # : AIInterface
var selected : bool
var level : int


func initialize(new_interface, new_level : int):
	interface = new_interface
	selected = false
	level = new_level
	sprite.texture = load("res://Sprites/level" + str(level) + ".png")
#	position.x += (-2.5 + level) * sprite.texture.get_size().y * 0.75

func _on_AIButton_mouse_entered():
	interface.entered(level)

func _on_AIButton_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		interface.selected(level)

func fill():
	sprite.texture = load("res://Sprites/level" + str(level) + "_filled.png")

func empty():
	sprite.texture = load("res://Sprites/level" + str(level) + "_empty.png")

