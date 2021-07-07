extends Node2D


const SCREEN_WIDTH = 620.0
const SCREEN_HEIGHT = 940.0
const BOARD_WIDTH = 600.0
const BOARD_HEIGHT = BOARD_WIDTH
const LR_SPC = (SCREEN_WIDTH - BOARD_WIDTH) / 2

const N_CLUES_CELL_HORZ = 10		# 手がかり数字 セル数
const N_IMG_CELL_HORZ = 20		# 画像 セル数
const N_TOTAL_CELL_HORZ = N_CLUES_CELL_HORZ + N_IMG_CELL_HORZ
const N_CLUES_CELL_VERT = 10		# 手がかり数字 セル数
const N_IMG_CELL_VERT = 20		# 画像 セル数
const N_TOTAL_CELL_VERT = N_CLUES_CELL_VERT + N_IMG_CELL_VERT
const CELL_WIDTH = BOARD_WIDTH / N_TOTAL_CELL_HORZ
const CLUES_WIDTH = CELL_WIDTH * N_CLUES_CELL_HORZ
const IMG_AREA_WIDTH = CELL_WIDTH * N_IMG_CELL_HORZ


func _ready():
	pass # Replace with function body.

