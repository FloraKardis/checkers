extends Node2D

class_name AIInterface


onready var levels : Array = [get_node("Level1"), get_node("Level2"), get_node("Level3"), get_node("Level4")]
var selected : int = 2
var ai : CheckersAI

func _ready():
	for i in len(levels):
		levels[i].initialize(self, i + 1)
	fill(selected)

func get_size() -> float:
	return levels[0].get_node("Sprite").texture.get_size().y

func entered(level : int):
	fill(level)

func selected(level : int):
	selected = level
	ai.set_difficulty(selected)

func fill(level):
	for i in level:
		levels[i].fill()
	for i in range(level, len(levels)):
		levels[i].empty()


func _on_AIInterface_mouse_exited():
	fill(selected)
