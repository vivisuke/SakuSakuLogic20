extends ColorRect


onready var g = get_node("/root/Global")

func _ready():
	pass # Replace with function body.

func _draw():
	#print(g)
	draw_rect(Rect2(0, g.CLUES_WIDTH, g.CLUES_WIDTH, g.IMG_AREA_WIDTH), Color.lightblue)
	draw_rect(Rect2(g.CLUES_WIDTH, 0, g.IMG_AREA_WIDTH, g.CLUES_WIDTH), Color.lightblue)
