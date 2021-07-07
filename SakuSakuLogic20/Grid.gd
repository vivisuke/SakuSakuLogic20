extends ColorRect


onready var g = get_node("/root/Global")

var pos1 = Vector2(-1, -1)		# ライン起点、-1 for ライン無し
var pos2 = Vector2(0, 0)		# ライン終点
var curX = -1
var curY = -1
var font

func _ready():
	var label = Label.new() 
	font = label.get_font("")
	pass # Replace with function body.
func set_font(f):
	font = f
func set_cursor(cx, cy):
	curX = cx
	curY = cy
	update()
func clearLine():
	pos1 = Vector2(-1, -1)
	update()
func setLine(p1, p2):
	pos1 = p1
	pos2 = p2
	update()
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

