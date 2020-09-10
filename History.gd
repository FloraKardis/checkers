extends Control

class_name History

var changes : Array = []
var pointer : int = 0

func reset():
	changes = []
	pointer = 0

func add(change): #) : Controller.Change):
	if pointer == len(changes):
		changes.append(change)
		pointer += 1
	else:
		changes[pointer] = change
		pointer += 1
		while len(changes) > pointer:
			changes.pop_back()

func undo():
	if pointer > 0:
		pointer -= 1
		return changes[pointer]

func redo():
	if len(changes) > pointer:
		pointer += 1
		return changes[pointer - 1]
