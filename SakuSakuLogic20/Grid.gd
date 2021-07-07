extends ColorRect


onready var g = get_node("/root/Global")

func _ready():
	pass # Replace with function body.
func _draw():
	# 縦線描画
	var y2 = g.BOARD_HEIGHT + 1
	for x in range(g.N_TOTAL_CELL_HORZ+1):
		var y1 = 0 if x >= g.N_CLUES_CELL_HORZ || !x else g.CLUES_WIDTH
		#var col = Color.black if x == 0 || x >= N_CLUES_CELL_HORZ && (x - N_CLUES_CELL_HORZ) % 5 == 0 else Color.gray
		var col = Color.black if x == 0 || (x - g.N_CLUES_CELL_HORZ) % 5 == 0 else Color.gray
		draw_line(Vector2(x * g.CELL_WIDTH, y1), Vector2(x * g.CELL_WIDTH, y2), col)
	# 横線描画
	var x2 = g.BOARD_WIDTH + 1
	for y in range(g.N_TOTAL_CELL_VERT+1):
		var x1 = 0 if y >= g.N_CLUES_CELL_HORZ || !y else g.CLUES_WIDTH
		#var col = Color.black if y == 0 || y >= N_CLUES_CELL_VERT && (y - N_CLUES_CELL_VERT) % 5 == 0 else Color.gray
		var col = Color.black if y == 0 || (y - g.N_CLUES_CELL_VERT) % 5 == 0 else Color.gray
		draw_line(Vector2(x1, y * g.CELL_WIDTH), Vector2(x2, y * g.CELL_WIDTH), col)
	# 太枠線描画
	draw_line(Vector2(0, -1), Vector2(x2, -1), Color.black)
	draw_line(Vector2(0, y2), Vector2(x2, y2), Color.black)
	draw_line(Vector2(-1, 0), Vector2(-1, y2+1), Color.black)
	draw_line(Vector2(x2, 0), Vector2(x2, y2+1), Color.black)

