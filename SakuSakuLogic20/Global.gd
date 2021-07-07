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

const solvedPatFileName = "user://saved.dat"
const settingsFileName = "user://settings.dat"

var lang_ja = false		# 日本語モード？
var solvedPatLoaded = false
var lvl_vscroll = 0		# レベルシーン スクロール位置
var solveMode = true
var qNumber = 0			# [#1, ...#N]
var qNum2QIX = []		# qNum (#1 ... #N) → QIX テーブル
var qix2ID = []			# qix → QID 配列
var settings = {}		# 設定辞書
var solvedPat = {}		# QID -> [data0, data1, ...] 辞書
#var solved = []			# true/false
var ans_images = []		# 解答ビットパターン配列
var quest_list = []		# ソート済み問題配列

enum {
	KEY_ID = 0,
	KEY_DIFFICULTY,
	KEY_TITLE,
	KEY_AUTHOR,
	KEY_V_CLUES,
	KEY_H_CLUES,
	}
var quest_list0 = [		# 非ソート済み問題配列
]

func _ready():
	pass # Replace with function body.

