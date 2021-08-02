extends Node2D


onready var g = get_node("/root/Global")

var dialog_opened = false
var mouse_pushed = false
var mouse_pos
var scroll_pos

var QuestPanel = load("res://QuestPanel.tscn")

class MyCustomSorter:
	var g 
	static func sort_ascending(a, b):
		return true if a[1] < b[1] else false
	#static func sort_descending(a, b):
	#	return true if a > b else false
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_ClearButton_pressed():
	pass # Replace with function body.


func _on_EditButton_pressed():
	g.lvl_vscroll = $ScrollContainer.scroll_vertical
	print("vscroll = ", g.lvl_vscroll)
	g.solveMode = false;
	get_tree().change_scene("res://MainScene.tscn")
	pass # Replace with function body.
