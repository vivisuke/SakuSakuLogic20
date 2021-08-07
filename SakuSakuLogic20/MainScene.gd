extends Node2D

onready var g = get_node("/root/Global")

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
const BITS_MASK = (1<<N_IMG_CELL_HORZ) - 1

const TILE_NONE = -1
const TILE_CROSS = 0		# ☓
const TILE_BLACK = 1
const TILE_BG_YELLOW = 0
const TILE_BG_GRAY = 1

const TILE_NUM_0 = 1
const ColorClues = Color("#dff9fb")

var FallingBlack = load("res://FallingBlack.tscn")
var FallingCross = load("res://FallingCross.tscn")

enum { MODE_SOLVE, MODE_EDIT_PICT, MODE_EDIT_CLUES, }
enum { SET_CELL, SET_CELL_BE, CLEAR_ALL, ROT_LEFT, ROT_RIGHT, ROT_UP, ROT_DOWN}

var qix					# 問題番号 [0, N]
var qID					# 問題ID
var qSolved = false		# 現問題をクリア済みか？
var qSolvedStat = false		# 現問題をクリア状態か？
var elapsedTime = 0.0	# 経過時間（単位：秒）
var hintTime = 0.0		# != 0 の間はヒント使用不可（単位：秒）
var mode = MODE_EDIT_PICT;
var dialog_opened = false;
var mouse_pushed = false
var last_xy = Vector2()
var pushed_xy = Vector2()
var cell_val = 0
#var g_map = {}		# 水平・垂直方向手がかり数字配列 → 候補数値マップ
#var slicedTable = []	# {0x0000 ～ 0x7fff → 連続ビットごとにスライスした配列} の配列
var h_clues = []		# 水平方向手がかり数字リスト（数字配列の配列）
var v_clues = []		# 垂直方向手がかり数字リスト
var h_candidates = []	# 水平方向候補リスト
var v_candidates = []	# 垂直方向候補リスト
var h_answer1_bits_1 = []		# 解答画像データ
var h_fixed_bits_1 = []
var h_fixed_bits_0 = []
var v_fixed_bits_1 = []
var v_fixed_bits_0 = []
var h_autoFilledCross = []		# 自動計算で☓を入れたセル（ビットボード, x == 0 が最下位ビット）
var v_autoFilledCross = []		# 自動計算で☓を入れたセル（ビットボード, x == 0 が最下位ビット）
var h_usedup = []			# 水平方向手がかり数字を使い切った＆エラー無し
var v_usedup = []			# 垂直方向手がかり数字を使い切った＆エラー無し
var shock_wave_timer = -1
var undo_ix = 0
var undo_stack = []

var help_text = ""

func _ready():
	#test_c2c()		# test clues_to_candidates()
	if g.solveMode:
		mode = MODE_SOLVE
		$EditButton.disabled = true
	else:
		mode = MODE_EDIT_PICT
		$titleBar/questLabel.text = "test"
	$MessLabel.text = ""
	##//$HintButton/timeLabel.text = ""
	update_modeButtons()
	update_commandButtons()
	#$boardBG/TileMap.set_cell(0, 0, 0)
	#build_map()
	#build_slicedTable()
	#print(g_map.size())
	h_clues.resize(N_IMG_CELL_VERT)
	h_autoFilledCross.resize(N_IMG_CELL_VERT)
	v_autoFilledCross.resize(N_IMG_CELL_HORZ)
	h_usedup.resize(N_IMG_CELL_VERT)
	v_usedup.resize(N_IMG_CELL_HORZ)
	for y in N_IMG_CELL_VERT:
		h_clues[y] = [0]
		h_autoFilledCross[y] = 0
		h_usedup[y] = false
	v_clues.resize(N_IMG_CELL_HORZ)
	for x in N_IMG_CELL_HORZ:
		v_clues[x] = [0]
		v_autoFilledCross[x] = 0
		v_usedup[x] = false
	h_answer1_bits_1.resize(N_IMG_CELL_VERT)
	if g.solveMode:
		#qix = g.qNum2QIX[g.qNumber - 1]
		qix = g.qNumber - 1
		qID = g.qix2ID[qix]
		print("QID = ", qID)
		if true:
			$titleBar/questLabel.text = (("#%d" % g.qNumber) + (", 難易度%d" % g.quest_list[qix][g.KEY_DIFFICULTY]) +
							", '" + g.quest_list[qix][g.KEY_TITLE][0] + "???' by " +
							g.quest_list[qix][g.KEY_AUTHOR])
		#$titleBar/questLabel.text = (("#%d" % g.qNumber) + (", diffi: %d" % g.quest_list[qix][g.KEY_DIFFICULTY]) +
		#					", '" + g.quest_list[qix][g.KEY_TITLE][0] + "???' by " +
		#					g.quest_list[qix][g.KEY_AUTHOR])
		set_quest(g.quest_list[qix][g.KEY_V_CLUES], g.quest_list[qix][g.KEY_H_CLUES])
		for y in range(N_IMG_CELL_VERT):
			h_answer1_bits_1[y] = 0
		init_usedup()
		if g.solvedPat.has(qID):	# 保存データあり
			if( g.solvedPat[qID].size() > N_IMG_CELL_VERT &&	# 経過時間が保存されている
					g.solvedPat[qID][N_IMG_CELL_VERT] < 0 ):		# 経過時間がマイナス → 途中経過
				elapsedTime = -g.solvedPat[qID][N_IMG_CELL_VERT]
				for y in range(N_IMG_CELL_VERT):
					var d = g.solvedPat[qID][y]
					var mask = 1 << N_IMG_CELL_HORZ
					for x in range(N_IMG_CELL_HORZ):
						mask >>= 1
						if (d&mask) != 0:
							$boardBG/TileMap.set_cell(x, y, TILE_BLACK)
							#$boardBG/MiniTileMap.set_cell(x, y, TILE_BLACK)
							#set_cell_basic(x, y, TILE_BLACK)
				if g.solvedPat[qID].size() > N_IMG_CELL_VERT + 1:	# ☓情報も保存されている場合
					for y in range(N_IMG_CELL_VERT):
						var d = g.solvedPat[qID][y + N_IMG_CELL_VERT + 1]
						var mask = 1 << N_IMG_CELL_HORZ
						for x in range(N_IMG_CELL_HORZ):
							mask >>= 1
							if (d&mask) != 0:
								$boardBG/TileMap.set_cell(x, y, TILE_CROSS)
				upate_imageTileMap()
				for y in range(N_IMG_CELL_VERT):
					check_h_clues(y)		# 使い切った手がかり数字グレイアウト
					check_h_conflicted(y)
				for x in range(N_IMG_CELL_HORZ):
					check_v_clues(x)		# 使い切った手がかり数字グレイアウト
					check_v_conflicted(x)
			else:
				qSolved = true		# すでにクリア済み
		set_crosses_null_line_column()	# 手がかり数字0の行・列に全部 ☓ を埋める
		print("qSolved = ", qSolved)
	update_undo_redo()
	update_modeUnderLine()
	##//$CanvasLayer/ColorRect.material.set_shader_param("size", 0)
	##//$SoundButton.pressed = !g.settings.has("Sound") || g.settings["Sound"]
	pass # Replace with function body.
func update_modeUnderLine():
	if mode == MODE_SOLVE:
		$modeUnderLine.rect_global_position.x = $SolveButton.rect_global_position.x
	else:
		$modeUnderLine.rect_global_position.x = $EditButton.rect_global_position.x
func _process(delta):
	if !qSolvedStat:
		elapsedTime += delta
		var sec = int(elapsedTime)
		var h = sec / (60*60)
		sec -= h * (60*60)
		var m = sec / 60
		sec -= m * 60
		##//$timeLabel.text = "%02d:%02d:%02d" % [h, m, sec]
		#
		if hintTime > 0:
			hintTime -= delta
			if hintTime <= 0:
				update_commandButtons()
				##//$HintButton/timeLabel.text = ""
			##//else:
				##//$HintButton/timeLabel.text = "%02d" % int(hintTime)
	if shock_wave_timer >= 0:
		shock_wave_timer += delta
		$CanvasLayer/ColorRect.material.set_shader_param("size", shock_wave_timer)
		if shock_wave_timer > 2:
			shock_wave_timer = -1.0
	pass
func update_undo_redo():
	$UndoButton.disabled = undo_ix == 0
	$RedoButton.disabled = undo_ix == undo_stack.size()
	pass
func push_to_undo_stack(item):
	if undo_stack.size() > undo_ix:
		undo_stack.resize(undo_ix)
	undo_stack.push_back(item)
	undo_ix += 1
func set_quest(vq, hq):
	for x in range(N_IMG_CELL_HORZ):
		var lst = []
		if x < vq.size():
			var txt : String = vq[x]
			if txt.empty():
				txt = " 0"
			if (txt.length() % 2) == 1:
				txt = " " + txt
			while !txt.empty():
				lst.push_front(int(txt.left(2)))
				txt = txt.substr(2)
		else:
			lst = [0]
		v_clues[x] = lst
		update_v_cluesText(x, lst)
	for y in range(N_IMG_CELL_VERT):
		var lst = []
		if y < hq.size():
			var txt : String = hq[y]
			if txt.empty():
				txt = " 0"
			if (txt.length() % 2) == 1:
				txt = " " + txt
			while !txt.empty():
				lst.push_front(int(txt.left(2)))
				txt = txt.substr(2)
		else:
			lst = [0]
		h_clues[y] = lst
		update_h_cluesText(y, lst)
func init_arrays():
	h_candidates.resize(N_IMG_CELL_VERT)
	v_candidates.resize(N_IMG_CELL_HORZ)
	h_fixed_bits_1.resize(N_IMG_CELL_VERT)
	h_fixed_bits_0.resize(N_IMG_CELL_VERT)
	v_fixed_bits_1.resize(N_IMG_CELL_HORZ)
	v_fixed_bits_0.resize(N_IMG_CELL_HORZ)
	#print(h_candidates)
# 101101110 → [3, 2, 1]	下位ビットの方が配列先頭とする
func data_to_clues(data : int) -> Array:
	if !data:
		return [0]
	var lst = []
	while data != 0:
		var b = data & -data
		data ^= b
		var n = 1
		b <<= 1
		while (data & b) != 0:
			data ^= b
			b <<= 1
			n += 1
		lst.push_back(n)
	return lst
# key は連配列、下位ビットの方が配列先頭
#func build_map():
#	g_map.clear()
#	for data in range(1<<N_IMG_CELL_HORZ):
#		var key = data_to_clues(data)
#		if g_map.has(key):
#			g_map[key].push_back(data)
#		else:
#			g_map[key] = [data]
#	#print(g_map([1]))
#	#print(g_map([0]))
func test_c2c():
	var cands
	#if false:
	# 余裕がなく、全部入れれる場合
	cands = clues_to_candidates([20])
	assert( cands.size() == 1 )
	assert( cands[0] == 0b11111111111111111111 )
	cands = clues_to_candidates([9, 10])
	assert( cands.size() == 1 )
	assert( cands[0] == 0b11111111110111111111 )
	cands = clues_to_candidates([1, 18])
	assert( cands.size() == 1 )
	assert( cands[0] == 0b11111111111111111101 )
	# 手がかり数字がひとつだけの場合
	cands = clues_to_candidates([19]);
	assert( cands.size() == 2 );
	assert( cands[0] == 0b11111111111111111110 );
	assert( cands[1] == 0b01111111111111111111 );
	cands = clues_to_candidates([17]);
	assert(cands.size() == 4);
	assert(cands[0] == 0b11111111111111111000);
	assert(cands[1] == 0b01111111111111111100);
	assert(cands[2] == 0b00111111111111111110);
	assert(cands[3] == 0b00011111111111111111);
	# 手がかり数字が複数だが、余裕がひとつだけの場合
	cands = clues_to_candidates([8, 10]);
	assert(cands.size() == 3);
	assert(cands[0] == 0b11111111110111111110);		# 手がかり数字の順序とは逆なので注意
	assert(cands[1] == 0b11111111110011111111);
	assert(cands[2] == 0b01111111111011111111);
	cands = clues_to_candidates([5, 2, 10]);
	assert(cands.size() == 4);
	assert(cands[0] == 0b11111111110110111110);
	assert(cands[1] == 0b11111111110110011111);
	assert(cands[2] == 0b11111111110011011111);
	assert(cands[3] == 0b01111111111011011111);
	# 上記以外の場合
	cands = clues_to_candidates([7, 10]);
	assert(cands.size() == 6);
	assert(cands[0] == 0b11111111110111111100);
	assert(cands[1] == 0b11111111110011111110);
	assert(cands[2] == 0b11111111110001111111);
	assert(cands[3] == 0b01111111111011111110);
	assert(cands[4] == 0b01111111111001111111);
	assert(cands[5] == 0b00111111111101111111);
	cands = clues_to_candidates([4, 1, 10]);
	assert(cands.size() == 20);
	assert(cands[0]  == 0b11111111110101111000);
	assert(cands[1]  == 0b11111111110100111100);
	assert(cands[2]  == 0b11111111110100011110);
	assert(cands[3]  == 0b11111111110100001111);
	assert(cands[4]  == 0b11111111110010111100);
	assert(cands[5]  == 0b11111111110010011110);
	assert(cands[6]  == 0b11111111110010001111);
	assert(cands[7]  == 0b11111111110001011110);
	assert(cands[8]  == 0b11111111110001001111);
	assert(cands[9]  == 0b11111111110000101111);
	assert(cands[10] == 0b01111111111010111100);
	assert(cands[11] == 0b01111111111010011110);
	assert(cands[12] == 0b01111111111010001111);
	assert(cands[13] == 0b01111111111001011110);
	assert(cands[14] == 0b01111111111001001111);
	assert(cands[15] == 0b01111111111000101111);
	assert(cands[16] == 0b00111111111101011110);
	assert(cands[17] == 0b00111111111101001111);
	assert(cands[18] == 0b00111111111100101111);
	assert(cands[19] == 0b00011111111110101111);

func clues_to_candidates(clues : Array) -> Array:
	#irint(clues)
	if clues == null || clues.empty() || clues == [0]:
		return [0]
	var s = clues.size() - 1;		#	手がかり数字間の数
	for i in range(clues.size()):
		s += clues[i]
	if( s > N_IMG_CELL_HORZ):
		return [0]
	var cands = []
	if( s == N_IMG_CELL_HORZ ):				#	余裕がなく、全て入れれる場合
		var d = 0;
		#for i in range(clues.size()):
		for i in range(clues.size() - 1, -1, -1):
			d <<= (clues[i] + 1);
			d |= (1 << clues[i]) - 1;
		cands.push_back(d);
		return cands;
	if( clues.size() == 1 ):		#	手がかり数字がひとつだけの場合
		var bits = (1 << clues[0]) - 1;
		for i in range(N_IMG_CELL_HORZ - s, -1, -1):
			cands.push_back(bits<<i);
		return cands;
	#	左への基礎シフト数を予め計算
	var shift = []
	shift.resize(clues.size())
	var sum = 0;
	#for i in range(shift.size()):
	for i in range(shift.size()-1, -1, -1):
		shift[i] = sum;
		sum += clues[shift.size() - i - 1] + 1;		#	1 for 隙間
	#	上記以外の場合
	var v = []		# for N進数もどき
	v.resize(clues.size())
	for i in range(v.size()):
		v[i] = N_IMG_CELL_HORZ - s
	while true:
		var bits = 0;
		#	各手がかり数字のビット列を v[i] だけ左にシフト
		#print(v)
		for i in range(clues.size()):
			bits |= ((1<<clues[clues.size() - i - 1]) - 1) << (shift[i] + v[i]);
		cands.push_back(bits);
		#
		var i = clues.size() - 1;
		while (i >= 0):
			if( v[i] != 0 ):
				v[i] -= 1;
				for k in range(i+1, clues.size()):
					v[k] = v[i];
				break;
			i -= 1
			if( i < 0 ):		#	ループ終了
				break;
		if( i < 0 ):
			break;
	return cands
	
func to_sliced(data):
	if data == 0:
		return [0]
	var ar = []
	while data != 0:
		var b = data & -data
		var t = b
		data ^= b
		b <<= 1
		while (data & b) != 0:
			data ^= b
			t |= b
			b <<= 1
		ar.push_back(t)
	return ar
# 値：-1 for init, -2 for 不一致
func usedup_clues(lst : Array,		# 可能な候補リスト
					data : int,		# ユーザ入力状態（ビットパターン）
					nc : int):	# nc: 手がかり数字数
	var uu = []
	uu.resize(nc)
	for i in range(nc):
		uu[i] = 0
	var ds = to_sliced(data)		# ユーザ入力状態をビット塊に分ける
	for k in range(ds.size()):		# ユーザ入力の各ビット塊について
		var pos = -1
		for i in range(lst.size()):			# 各候補について
			var cs = to_sliced(lst[i])
			var ix = cs.find(ds[k])
			if ix < 0:		# not found
				pos = -1
				break
			if pos < 0:
				pos = ix
			elif ix != pos:
				pos = -1
				break
		if pos >= 0:
			uu[pos] = 1
	return uu
#func build_slicedTable():
#	slicedTable.resize(1<<N_IMG_CELL_HORZ)
#	for d in range(1<<N_IMG_CELL_HORZ):
#		var ar = to_sliced(d)
#		#print(array_to_binText(ar))
#		slicedTable[d] = ar
	pass
func to_binText(d : int) -> String:
	var txt = ""
	var mask = 1 << (N_IMG_CELL_HORZ - 1)
	while mask != 0:
		txt += '1' if (d&mask) != 0 else '0'
		mask >>= 1
	return txt
func array_to_binText(lst : Array) -> String:
	var txt = "["
	for i in range(lst.size()):
		txt += to_binText(lst[i])
		txt += ", "
	txt += "]"
	return txt
func init_candidates():
	#return
	#print("\n*** init_candidates():")
	for y in range(N_IMG_CELL_VERT):
		#print("h_clues[", y, "] = ", h_clues[y])
		if h_clues[y] == null:
			h_candidates[y] = [0]
		else:
			h_candidates[y] = clues_to_candidates(h_clues[y])
			#h_candidates[y] = g_map[h_clues[y]].duplicate()
		if y < 5:
			print( "h_candidates[", y, "].size() = ",  h_candidates[y].size())
			if y == 0 && h_candidates[y].size() == 1:
				print(to_binText(h_candidates[y][0]))
		#print( "h_cand[", y, "] = ", to_binText(h_candidates[y]) )
	for x in range(N_IMG_CELL_HORZ):
		#print("v_clues[", x, "] = ", v_clues[x])
		if v_clues[x] == null:
			v_candidates[x] = [0]
		else:
			v_candidates[x] = clues_to_candidates(v_clues[x])
			#v_candidates[x] = g_map[v_clues[x]].duplicate()
		if x < 5:
			print( "v_candidates[", x, "].size() = ",  v_candidates[x].size())
		##print( "v_cand[", x, "] = ", to_binText(v_candidates[x]) )
func num_candidates():
	var sum = 0
	for y in range(N_IMG_CELL_VERT):
		sum += h_candidates[y].size()
	for x in range(N_IMG_CELL_HORZ):
		sum += v_candidates[x].size()
	return sum
# h_candidates[] を元に h_fixed_bits_1, 0 を計算
func update_h_fixedbits():
	#print("\n*** update_h_fixedbits():")
	for y in range(N_IMG_CELL_VERT):
		var lst = h_candidates[y]
		if lst.size() == 1:
			h_fixed_bits_1[y] = lst[0]
			h_fixed_bits_0[y] = ~lst[0] & BITS_MASK
		else:
			var bits1 = BITS_MASK
			var bits0 = BITS_MASK
			for i in range(lst.size()):
				bits1 &= lst[i]
				bits0 &= ~lst[i]
			h_fixed_bits_1[y] = bits1
			h_fixed_bits_0[y] = bits0
		if y < 2:
			print("h_fixed[", y , "] = ", to_binText(h_fixed_bits_1[y]), ", ", to_binText(h_fixed_bits_0[y]))
	pass
# v_candidates[] を元に v_fixed_bits_1, 0 を計算
func update_v_fixedbits():
	#print("\n*** update_v_fixedbits():")
	for x in range(N_IMG_CELL_HORZ):
		var lst = v_candidates[x]
		if lst.size() == 1:
			v_fixed_bits_1[x] = lst[0]
			v_fixed_bits_0[x] = ~lst[0] & BITS_MASK
		else:
			var bits1 = BITS_MASK
			var bits0 = BITS_MASK
			for i in range(lst.size()):
				bits1 &= lst[i]
				bits0 &= ~lst[i]
			v_fixed_bits_1[x] = bits1
			v_fixed_bits_0[x] = bits0
		if x < 2:
			print("v_fixed[", x , "] = ", to_binText(v_fixed_bits_1[x]), ", ", to_binText(v_fixed_bits_0[x]))
		#print("v_fixed[", x , "] = ", to_binText(v_fixed_bits_1[x]), ", ", to_binText(v_fixed_bits_0[x]))
	pass
func hFixed_to_vFixed():
	#print("\n*** hFixed_to_vFixed():")
	for x in range(N_IMG_CELL_HORZ):
		v_fixed_bits_1[x] = 0
		v_fixed_bits_0[x] = 0
	var hmask = 1 << N_IMG_CELL_HORZ;
	for x in range(N_IMG_CELL_HORZ):
		hmask >>= 1
		var vmask = 1 << N_IMG_CELL_VERT;
		for y in range(N_IMG_CELL_VERT):
			vmask >>= 1
			if( (h_fixed_bits_1[y] & hmask) != 0 ):
				v_fixed_bits_1[x] |= vmask;
			if( (h_fixed_bits_0[y] & hmask) != 0 ):
				v_fixed_bits_0[x] |= vmask;
		#print("v_fixed[", x , "] = ", to_binText(v_fixed_bits_1[x]), ", ", to_binText(v_fixed_bits_0[x]))
	pass
func vFixed_to_hFixed():
	#print("\n*** vFixed_to_hFixed():")
	for y in range(N_IMG_CELL_VERT):
		h_fixed_bits_1[y] = 0
		h_fixed_bits_0[y] = 0
	var vmask = 1 << N_IMG_CELL_VERT;
	for y in range(N_IMG_CELL_VERT):
		vmask >>= 1
		var hmask = 1 << N_IMG_CELL_HORZ;
		for x in range(N_IMG_CELL_HORZ):
			hmask >>= 1
			if( (v_fixed_bits_1[x] & vmask) != 0 ):
				h_fixed_bits_1[y] |= hmask;
			if( (v_fixed_bits_0[x] & vmask) != 0 ):
				h_fixed_bits_0[y] |= hmask;
		#print("h_fixed[", y , "] = ", to_binText(h_fixed_bits_1[y]), ", ", to_binText(h_fixed_bits_0[y]))
	pass
# v_fixed_bits_1, 0 を元に v_candidates[] から不可能なパターンを削除
func update_v_candidates():
	#print("\n*** update_v_candidates():")
	for x in range(N_IMG_CELL_HORZ):
		for i in range(v_candidates[x].size()-1, -1, -1):
			if( (v_candidates[x][i] & v_fixed_bits_1[x]) != v_fixed_bits_1[x] ||
					(~v_candidates[x][i] & v_fixed_bits_0[x]) != v_fixed_bits_0[x] ):
				v_candidates[x].remove(i)
		#print( "v_cand[", x, "] = ", to_binText(v_candidates[x]) )
	pass
# h_fixed_bits_1, 0 を元に h_candidates[] から不可能なパターンを削除
func update_h_candidates():
	#print("\n*** update_h_candidates():")
	for y in range(N_IMG_CELL_VERT):
		for i in range(h_candidates[y].size()-1, -1, -1):
			if( (h_candidates[y][i] & h_fixed_bits_1[y]) != h_fixed_bits_1[y] ||
					(~h_candidates[y][i] & h_fixed_bits_0[y]) != h_fixed_bits_0[y] ):
				h_candidates[y].remove(i)
		#print( "h_cand[", y, "] = ", to_binText(h_candidates[y]) )
	pass
func remove_h_candidates_conflicted():		# 現在のセルの状態にマッチしない候補をリストから削除
	for y in range(N_IMG_CELL_VERT):
		var d1 = get_h_data(y)
		var d0 = get_h_data0(y)
		remove_conflicted(d1, d0, h_candidates[y])
	pass
func remove_v_candidates_conflicted():		# 現在のセルの状態にマッチしない候補をリストから削除
	for x in range(N_IMG_CELL_HORZ):
		var d1 = get_v_data(x)
		var d0 = get_v_data0(x)
		remove_conflicted(d1, d0, v_candidates[x])
	pass
func is_data_OK(d, d0, lst):	# d が lst のすべてと矛盾する場合は false を返す
	for i in range(lst.size()):
		if (lst[i] & d) == d && (~lst[i] & d0) == d0:
			return true
	return false
func remove_conflicted(d1, d0, lst):		# d1, d0 と矛盾する要素を削除
	for i in range(lst.size()-1, -1, -1):
		if (lst[i] & d1) != d1 || (~lst[i] & d0) != d0:
			lst.remove(i)
func set_crosses_null_line_column():	# 手がかり数字0の行・列に全部 ☓ を埋める
	for y in range(N_IMG_CELL_VERT):
		if h_clues[y] == [0]:
			for x in range(N_IMG_CELL_HORZ):
				$boardBG/TileMap.set_cell(x, y, TILE_CROSS)
	for x in range(N_IMG_CELL_HORZ):
		if v_clues[x] == [0]:
			for y in range(N_IMG_CELL_VERT):
				$boardBG/TileMap.set_cell(x, y, TILE_CROSS)
func clear_all_crosses():
	for y in range(N_IMG_CELL_VERT):
		for x in range(N_IMG_CELL_HORZ):
			if $boardBG/TileMap.get_cell(x, y) == TILE_CROSS:
				$boardBG/TileMap.set_cell(x, y, TILE_NONE)
func remove_h_auto_cross(y0):
	if h_autoFilledCross[y0] != 0:		# ☓オートフィルでフィルされた☓を削除
		var vmask = 1 << y0
		var mask = 1
		for x in range(N_IMG_CELL_HORZ):
			if( (h_autoFilledCross[y0] & mask) != 0 && (v_autoFilledCross[x] & vmask) == 0 &&
					$boardBG/TileMap.get_cell(x, y0) == TILE_CROSS ):
				$boardBG/TileMap.set_cell(x, y0, TILE_NONE)
			mask <<= 1
		h_autoFilledCross[y0] = 0
func set_h_auto_cross(y0):
	var mask = 1
	for x in range(N_IMG_CELL_HORZ):
		if $boardBG/TileMap.get_cell(x, y0) == TILE_NONE:
			$boardBG/TileMap.set_cell(x, y0, TILE_CROSS)
			h_autoFilledCross[y0] |= mask
		mask <<= 1
func check_h_conflicted(y0):
	var d1 = get_h_data(y0)
	var d0 = get_h_data0(y0)
	#print("d0 = ", d0)
	var lst = clues_to_candidates(h_clues[y0])
	#var lst = g_map[h_clues[y0]].duplicate()
	var bg = TILE_NONE
	remove_conflicted(d1, d0, lst)
	if lst.empty():
		for x in range(h_clues[y0].size()):
			$boardBG/TileMapBG.set_cell(-x-1, y0, TILE_BG_YELLOW)
	else:
		for x in range(h_clues[y0].size()):
			if $boardBG/TileMapBG.get_cell(-x-1, y0) != TILE_BG_GRAY:
				$boardBG/TileMapBG.set_cell(-x-1, y0, TILE_NONE)	# グレイでなければ透明に
	#bg = TILE_BG_YELLOW if lst.empty() else TILE_NONE
	#for x in range(h_clues[y0].size()):
		#if $boardBG/TileMapBG.get_cell(-x-1, y0) != TILE_BG_GRAY:
		#$boardBG/TileMapBG.set_cell(-x-1, y0, bg)	# 黄色の方が優先
func check_h_clues(y0 : int):		# 水平方向チェック
	var d1 = get_h_data(y0)
	var d0 = get_h_data0(y0)
	#print("d0 = ", d0)
	var lst = clues_to_candidates(h_clues[y0])
	#var lst = g_map[h_clues[y0]].duplicate()
	var bg = TILE_NONE
	remove_conflicted(d1, d0, lst)
	remove_h_auto_cross(y0)
	h_usedup[y0] = false
	if !lst.empty():		# 候補数字が残っている場合
		if lst.has(d1):		# d1 が正解に含まれる場合
			h_usedup[y0] = true
			bg = TILE_BG_GRAY if d1 != 0 else TILE_NONE			# グレイ or 無し
			set_h_auto_cross(y0)
			for x in range(h_clues[y0].size()):
				$boardBG/TileMapBG.set_cell(-x-1, y0, bg)
		else:
			# 部分確定判定
			#	lst: 可能なビットパターンリスト（配列）
			#	ユーザ入力パターン（d1）を連続1ごとにスライスし、それと lst[] の各要素とを比較し、
			#	全要素と一致していれば、その部分がマッチしている（はず）
			var uu = usedup_clues(lst, d1, h_clues[y0].size())
			for x in range(h_clues[y0].size()):
				$boardBG/TileMapBG.set_cell(-x-1, y0, (TILE_NONE if uu[x] == 0 else TILE_BG_GRAY))
	pass
func remove_v_auto_cross(x0):
	if v_autoFilledCross[x0] != 0:
		var hmask = 1 << x0
		var mask = 1
		for y in range(N_IMG_CELL_VERT):
			if( (v_autoFilledCross[x0] & mask) != 0 && (h_autoFilledCross[y] & hmask) == 0 &&
					$boardBG/TileMap.get_cell(x0, y) == TILE_CROSS ):
				$boardBG/TileMap.set_cell(x0, y, TILE_NONE)
			mask <<= 1
		v_autoFilledCross[x0] = 0
func set_v_auto_cross(x0):
	var mask = 1
	for y in range(N_IMG_CELL_VERT):
		if $boardBG/TileMap.get_cell(x0, y) == TILE_NONE:
			$boardBG/TileMap.set_cell(x0, y, TILE_CROSS)
			v_autoFilledCross[x0] |= mask
		mask <<= 1
func check_v_conflicted(x0):
	var d1 = get_v_data(x0)
	var d0 = get_v_data0(x0)
	#print("d0 = ", d0)
	var lst = clues_to_candidates(v_clues[x0])
	#var lst = g_map[v_clues[x0]].duplicate()
	var bg = TILE_NONE
	remove_conflicted(d1, d0, lst)
	if lst.empty():
		for y in range(v_clues[x0].size()):
			$boardBG/TileMapBG.set_cell(x0, -y-1, TILE_BG_YELLOW)
	else:
		for y in range(v_clues[x0].size()):
			if $boardBG/TileMapBG.get_cell(x0, -y-1) != TILE_BG_GRAY:
				$boardBG/TileMapBG.set_cell(x0, -y-1, TILE_NONE)	# グレイでなければ透明に
	#bg = TILE_BG_YELLOW if lst.empty() else TILE_NONE
	#for y in range(v_clues[x0].size()):
		#if $boardBG/TileMapBG.get_cell(x0, -y-1) != TILE_BG_GRAY:
		#$boardBG/TileMapBG.set_cell(x0, -y-1, bg)
func check_v_clues(x0 : int):		# 垂直方向チェック
	var d1 = get_v_data(x0)
	var d0 = get_v_data0(x0)
	var lst = clues_to_candidates(v_clues[x0])
	#var lst = g_map[v_clues[x0]].duplicate()
	var bg = TILE_NONE
	remove_conflicted(d1, d0, lst)
	remove_v_auto_cross(x0)
	v_usedup[x0] = false
	if !lst.empty():
		if lst.has(d1):		# d1 が正解に含まれる場合
			v_usedup[x0] = true
			bg = TILE_BG_GRAY if d1 != 0 else TILE_NONE			# グレイ or 無し
			set_v_auto_cross(x0)
			for y in range(v_clues[x0].size()):
				$boardBG/TileMapBG.set_cell(x0, -y-1, bg)
		else:
			# 部分確定判定
			#	lst: 可能なビットパターンリスト（配列）
			#	ユーザ入力パターン（d1）を連続1ごとにスライスし、それと lst[] の各要素とを比較し、
			#	全要素と一致していれば、その部分がマッチしている（はず）
			var uu = usedup_clues(lst, d1, v_clues[x0].size())
			for y in range(v_clues[x0].size()):
				$boardBG/TileMapBG.set_cell(x0, -y-1, (TILE_NONE if uu[y] == 0 else TILE_BG_GRAY))
#func check_all_clues():
#	for y in range(N_IMG_CELL_VERT):
#		check_h_clues(y)
#	for x in range(N_IMG_CELL_HORZ):
#		check_v_clues(x)
func check_clues(x0, y0):
	check_h_clues(y0)
	check_v_clues(x0)
	for y in range(N_IMG_CELL_VERT):
		check_h_conflicted(y)
	for x in range(N_IMG_CELL_HORZ):
		check_v_conflicted(x)
func init_usedup():
	for y in range(N_IMG_CELL_VERT):
		if h_clues[y] == [0]:
			h_usedup[y] = true
	for x in range(N_IMG_CELL_HORZ):
		if v_clues[x] == [0]:
			v_usedup[x] = true
func is_solved():
	for y in range(N_IMG_CELL_VERT):
		if !h_usedup[y]:
			return false;
	for x in range(N_IMG_CELL_HORZ):
		if !v_usedup[x]:
			return false;
	return true;
func get_h_data(y0):
	var data = 0
	for x in range(N_IMG_CELL_HORZ):
		data = data * 2 + (1 if $boardBG/TileMap.get_cell(x, y0) == TILE_BLACK else 0)
	return data
func get_h_data0(y0):
	var data = 0
	for x in range(N_IMG_CELL_HORZ):
		data = data * 2 + (1 if $boardBG/TileMap.get_cell(x, y0) == TILE_CROSS else 0)
	return data
func get_v_data(x0):
	var data = 0
	for y in range(N_IMG_CELL_VERT):
		data = data * 2 + (1 if $boardBG/TileMap.get_cell(x0, y) == TILE_BLACK else 0)
	return data
func get_v_data0(x0):
	var data = 0
	for y in range(N_IMG_CELL_VERT):
		data = data * 2 + (1 if $boardBG/TileMap.get_cell(x0, y) == TILE_CROSS else 0)
	return data
func update_h_cluesText(y0, lst):
	var x = -1
	for i in range(lst.size()):
		$boardBG/TileMap.set_cell(x, y0, lst[i] + TILE_NUM_0 if lst[i] != 0 else TILE_NONE)
		x -= 1
	while x >= -N_CLUES_CELL_HORZ:
		$boardBG/TileMap.set_cell(x, y0, TILE_NONE)
		x -= 1
func update_h_clues(y0):
	# 水平方向手がかり数字更新
	var data = get_h_data(y0)
	var lst = data_to_clues(data)
	h_clues[y0] = lst;
	update_h_cluesText(y0, lst)
func update_v_cluesText(x0, lst):
	var y = -1
	for i in range(lst.size()):
		$boardBG/TileMap.set_cell(x0, y, lst[i] + TILE_NUM_0 if lst[i] != 0 else TILE_NONE)
		y -= 1
	while y >= -N_CLUES_CELL_VERT:
		$boardBG/TileMap.set_cell(x0, y, TILE_NONE)
		y -= 1
func update_v_clues(x0):
	# 垂直方向手がかり数字更新
	var data = get_v_data(x0)
	var lst = data_to_clues(data)
	v_clues[x0] = lst;
	update_v_cluesText(x0, lst)
func update_clues(x0, y0):
	update_h_clues(y0)
	update_v_clues(x0)
	pass
func update_all_clues():
	for y in range(N_IMG_CELL_VERT):
		update_h_clues(y)
	for x in range(N_IMG_CELL_HORZ):
		update_v_clues(x)
func clearMiniTileMap():
	for y in range(N_IMG_CELL_VERT):
		for x in range(N_IMG_CELL_HORZ):
			$boardBG/MiniTileMap.set_cell(x, y, TILE_NONE)
			pass
func clearTileMap():
	for y in range(N_IMG_CELL_VERT):
		for x in range(N_IMG_CELL_HORZ):
			$boardBG/TileMap.set_cell(x, y, TILE_NONE)
func clearTileMapBG():
	for y in range(N_IMG_CELL_VERT):
		for x in range(N_IMG_CELL_HORZ):
			$boardBG/TileMapBG.set_cell(x, y, TILE_NONE)
func setup_fallingBlack(pos):
	var obj = FallingBlack.instance()
	obj.setup(pos)
	add_child(obj)
	pass
func setup_fallingCross(pos):
	var obj = FallingCross.instance()
	obj.setup(pos)
	add_child(obj)
	pass
func posToXY(pos):
	var xy = Vector2(-1, -1)
	var X0 = $boardBG/TileMap.global_position.x
	var Y0 = $boardBG/TileMap.global_position.y
	if pos.x >= X0 && pos.x < X0 + CELL_WIDTH*N_IMG_CELL_HORZ:
		if pos.y >= Y0 && pos.y < Y0 + CELL_WIDTH*N_IMG_CELL_VERT:
			xy.x = floor((pos.x - X0) / CELL_WIDTH)
			xy.y = floor((pos.y - Y0) / CELL_WIDTH)
	return xy
func xyToPos(x, y):
	var px = $boardBG/TileMap.global_position.x + x * CELL_WIDTH
	var py = $boardBG/TileMap.global_position.y + y * CELL_WIDTH
	return Vector2(px, py)
func _input(event):
	if dialog_opened:
		return;
	if event is InputEventMouseButton:
		#print("InputEventMouseButton")
		if( event.is_action_pressed("click") ||		# left mouse button
			event.is_action_pressed("rt_click") ):		# right mouse button
			#print(event.position)
			var xy = posToXY(event.position)
			print(xy)
			$MessLabel.text = ""
			clearTileMapBG()
			$boardBG/Grid.set_cursor(-1, -1)
			if xy.x >= 0:
				##//if $SoundButton.pressed:
				##//	$clickAudio.play()
				mouse_pushed = true;
				last_xy = xy
				pushed_xy = xy
				var v0 = $boardBG/TileMap.get_cell(xy.x, xy.y)
				var v = v0
				if event.is_action_pressed("click"):		# left mouse button
					v = TILE_BLACK if v0 != TILE_BLACK else TILE_NONE;
				else:
					v = TILE_CROSS if v0 != TILE_CROSS else TILE_NONE
					#v += 1
					#if v > TILE_BLACK:
					#	v = TILE_NONE
				cell_val = v
				#$boardBG/TileMap.set_cell(xy.x, xy.y, v)
				push_to_undo_stack([SET_CELL_BE, xy.x, xy.y, v0, v])
				update_undo_redo()
				set_cell_basic(xy.x, xy.y, v)
				if v0 == TILE_BLACK && v != TILE_BLACK:
					setup_fallingBlack(event.position)
			else:
				#return		# 盤面外をクリックした場合
				pass
		elif event.is_action_released("click") || event.is_action_released("rt_click"):
			if mouse_pushed:
				mouse_pushed = false;
				$boardBG/Grid.clearLine()
				if pushed_xy != last_xy:
					set_cell_rect(pushed_xy, last_xy, cell_val)
				if !undo_stack.empty() && undo_stack.back()[0] <= SET_CELL_BE:
					undo_stack.back()[0] ^= 1		# 最下位ビット反転
	elif event is InputEventMouseMotion:
		var xy = posToXY(event.position)
		if mouse_pushed:	# マウスドラッグ中
			if xy.x >= 0 && xy != last_xy:
				$boardBG/Grid.set_cursor(-1, -1)
				#print(xy)
				last_xy = xy
				if true:
					$boardBG/Grid.setLine(pushed_xy, xy)
				else:
					var v0 = $boardBG/TileMap.get_cell(xy.x, xy.y)
					push_to_undo_stack([SET_CELL, xy.x, xy.y, v0, cell_val])
					update_undo_redo()
					set_cell_basic(xy.x, xy.y, cell_val)
					#$boardBG/TileMap.set_cell(xy.x, xy.y, cell_val)
					if v0 == TILE_BLACK && cell_val != TILE_BLACK:
						setup_fallingBlack(event.position)
		else:
			if xy.x >= 0:
				$boardBG/Grid.set_cursor(xy.x, xy.y)
			else:
				$boardBG/Grid.set_cursor(-1, -1)
	if mode == MODE_SOLVE:
		if is_solved():			# クリア状態
			qSolved = true		# クリア済みフラグON
			if g.solveMode:
				if !qSolvedStat:
					qSolvedStat = true
					shock_wave_timer = 0.0		# start shock wave
					if $SoundButton.pressed:
						$clearedAudio.play()
				# ☓消去
				for y in range(N_IMG_CELL_VERT):
					for x in range(N_IMG_CELL_HORZ):
						if $boardBG/TileMap.get_cell(x, y) == TILE_CROSS:
							$boardBG/TileMap.set_cell(x, y, TILE_NONE)
							setup_fallingCross(xyToPos(x, y))
				#g.solved[qix] = true
				#if !g.solvedPat.has(qID):		# クリア辞書に入っていない場合
				var lst = []
				for y in range(N_IMG_CELL_VERT):
					lst.push_back(get_h_data(y))
				lst.push_back(int(elapsedTime))
				#
				if( g.solvedPat.has(qID) &&
						g.solvedPat[qID].size() == N_IMG_CELL_VERT + 1):		# クリアタイムが記録されている場合
					lst[N_IMG_CELL_VERT] = g.solvedPat[qID][N_IMG_CELL_VERT]
				g.solvedPat[qID] = lst
				saveSolvedPat()
				if true:
					$titleBar/questLabel.text = (("#%d" % g.qNumber) + (", 難易度%d" % g.quest_list[qix][g.KEY_DIFFICULTY]) +
											", '" + g.quest_list[qix][g.KEY_TITLE] +
											"' by " + g.quest_list[qix][g.KEY_AUTHOR])
				#$titleBar/questLabel.text = (("#%d" % g.qNumber) + (", diffi: %d" % g.quest_list[qix][g.KEY_DIFFICULTY]) +
				#						", '" + g.quest_list[qix][g.KEY_TITLE] +
				#						"' by " + g.quest_list[qix][g.KEY_AUTHOR])
			$MessLabel.add_color_override("font_color", Color.blue)
			$MessLabel.text = "問題クリアです。グッジョブ！"
			#$MessLabel.text = "Solved, Good Job !"
		else:	# not is_solved()
			qSolvedStat = false
			if help_text.empty():
				$MessLabel.text = ""
	pass
func saveSolvedPat():
	var file = File.new()
	file.open(g.solvedPatFileName, File.WRITE)
	file.store_var(g.solvedPat)
	file.close()
func saveSettings():
	var file = File.new()
	file.open(g.settingsFileName, File.WRITE)
	file.store_var(g.settings)
	file.close()
func clear_all():
	var item = [CLEAR_ALL]
	for y in range(N_IMG_CELL_VERT):
		item.push_back(get_h_data(y))
	push_to_undo_stack(item)
	clear_all_basic()
func clear_all_basic():
	for y in range(N_TOTAL_CELL_VERT):
		for x in range(N_TOTAL_CELL_HORZ):
			if $boardBG/TileMap.get_cell(x, y) == TILE_BLACK:
				setup_fallingBlack(xyToPos(x, y))
			$boardBG/TileMap.set_cell(x, y, TILE_NONE)
			$boardBG/MiniTileMap.set_cell(x, y, TILE_NONE)
	if mode == MODE_EDIT_PICT:
		for y in range(N_TOTAL_CELL_VERT):
			for x in range(N_CLUES_CELL_HORZ):
				$boardBG/TileMap.set_cell(-x-1, y, TILE_NONE)
		for x in range(N_TOTAL_CELL_HORZ):
			for y in range(N_CLUES_CELL_VERT):
				$boardBG/TileMap.set_cell(x, -y-1, TILE_NONE)
		for y in range(N_IMG_CELL_VERT):
			h_clues[y] = [0]
			for x in range(N_CLUES_CELL_HORZ):
				$boardBG/TileMapBG.set_cell(-x-1, y, TILE_NONE)
		for x in range(N_IMG_CELL_HORZ):
			v_clues[x] = [0]
			for y in range(N_CLUES_CELL_VERT):
				$boardBG/TileMapBG.set_cell(x, -y-1, TILE_NONE)
	else:
		for y in range(N_IMG_CELL_VERT):
			for x in range(N_CLUES_CELL_HORZ):
				$boardBG/TileMapBG.set_cell(-x-1, y, TILE_NONE)
		for x in range(N_IMG_CELL_HORZ):
			for y in range(N_CLUES_CELL_VERT):
				$boardBG/TileMapBG.set_cell(x, -y-1, TILE_NONE)
func _on_ClearButton_pressed():
	clear_all()
	if mode == MODE_SOLVE:
		set_crosses_null_line_column()	# 手がかり数字0の行・列に全部 ☓ を埋める
	pass # Replace with function body.
func upate_imageTileMap():
	for y in range(N_IMG_CELL_VERT):
		for x in range(N_IMG_CELL_HORZ):
			var img = 0 if $boardBG/TileMap.get_cell(x, y) == 1 else TILE_NONE
			$boardBG/MiniTileMap.set_cell(x, y, img)

func rotate_left_basic():
	var ar = []
	for y in range(N_IMG_CELL_VERT):
		ar.push_back($boardBG/TileMap.get_cell(0, y))	# may be -1 or +1
	for x in range(N_IMG_CELL_HORZ-1):
		for y in range(N_IMG_CELL_VERT):
			$boardBG/TileMap.set_cell(x, y, $boardBG/TileMap.get_cell(x+1, y))
	for y in range(N_IMG_CELL_VERT):
		$boardBG/TileMap.set_cell(N_IMG_CELL_HORZ-1, y, ar[y])
	update_all_clues()
	upate_imageTileMap()
func _on_LeftButton_pressed():
	push_to_undo_stack([ROT_LEFT])
	rotate_left_basic()
	pass # Replace with function body.
func rotate_right_basic():
	var ar = []
	for y in range(N_IMG_CELL_VERT):
		ar.push_back($boardBG/TileMap.get_cell(N_IMG_CELL_HORZ-1, y))	# may be -1 or +1
	for x in range(N_IMG_CELL_HORZ-1, 0, TILE_NONE):
		for y in range(N_IMG_CELL_VERT):
			$boardBG/TileMap.set_cell(x, y, $boardBG/TileMap.get_cell(x-1, y))
	for y in range(N_IMG_CELL_VERT):
		$boardBG/TileMap.set_cell(0, y, ar[y])
	update_all_clues()
	upate_imageTileMap()
func _on_RightButton_pressed():
	push_to_undo_stack([ROT_RIGHT])
	rotate_right_basic()
	pass # Replace with function body.
func rotate_down_basic():
	var ar = []
	for x in range(N_IMG_CELL_HORZ):
		ar.push_back($boardBG/TileMap.get_cell(x, N_IMG_CELL_VERT-1))	# may be -1 or +1
	for y in range(N_IMG_CELL_VERT-1, 0, TILE_NONE):
		for x in range(N_IMG_CELL_HORZ):
			$boardBG/TileMap.set_cell(x, y, $boardBG/TileMap.get_cell(x, y-1))
	for x in range(N_IMG_CELL_HORZ):
		$boardBG/TileMap.set_cell(x, 0, ar[x])
	update_all_clues()
	upate_imageTileMap()
func _on_DownButton_pressed():
	push_to_undo_stack([ROT_DOWN])
	rotate_down_basic()
	pass # Replace with function body.
func rotate_up_basic():
	var ar = []
	for x in range(N_IMG_CELL_HORZ):
		ar.push_back($boardBG/TileMap.get_cell(x, 0))	# may be -1 or +1
	for y in range(N_IMG_CELL_VERT-1):
		for x in range(N_IMG_CELL_HORZ):
			$boardBG/TileMap.set_cell(x, y, $boardBG/TileMap.get_cell(x, y+1))
	for x in range(N_IMG_CELL_HORZ):
		$boardBG/TileMap.set_cell(x, N_IMG_CELL_VERT-1, ar[x])
	update_all_clues()
	upate_imageTileMap()
func _on_UpButton_pressed():
	push_to_undo_stack([ROT_UP])
	rotate_up_basic()
	pass # Replace with function body.

func print_clues(clues):
	var txt = "["
	for x in range(N_IMG_CELL_HORZ):
		txt += '"'
		for i in range(clues[x].size()-1, -1, -1):
			txt += "%2d" % clues[x][i]
		txt += '",'
	txt += "],"
	print(txt)
func _on_CheckButton_pressed():
	set_crosses_null_line_column()	# 手がかり数字0の行・列に全部 ☓ を埋める
	init_arrays()
	init_candidates()
	print_clues(v_clues)
	print_clues(h_clues)
	var nc0 = 0
	var solved = false
	var itr = 0
	while true:
		update_h_fixedbits()	# h_candidates[] を元に h_fixed_bits_1, 0 を計算
		#print("num candidates = ", num_candidates())
		var nc = num_candidates()
		print("num cands = ", nc)
		if nc == N_IMG_CELL_HORZ + N_IMG_CELL_VERT:	# solved
			solved = true
			break
		if nc == nc0:	# CAN't be solved
			break;
		nc0 = nc
		hFixed_to_vFixed()
		update_v_candidates()
		print("v_candidates[0].size() = ", v_candidates[0].size())
		print("v_candidates[1].size() = ", v_candidates[1].size())
		if v_candidates[1].size() == 2:
			print("v_candidates[1][0] = ", to_binText(v_candidates[1][0]),
					" [1] = ", to_binText(v_candidates[1][1]))
		update_v_fixedbits()
		vFixed_to_hFixed()
		update_h_candidates()
		print("h_candidates[0].size() = ", h_candidates[0].size())
		print("h_candidates[1].size() = ", h_candidates[1].size())
		if h_candidates[1].size() == 2:
			print("h_candidates[1][0] = ", to_binText(h_candidates[1][0]),
					" [1] = ", to_binText(h_candidates[1][1]))
		itr += 1
	print(solved)
	if solved:
		$MessLabel.add_color_override("font_color", Color.black)
		$MessLabel.text = "適切な問題です(難易度: %d)。" % itr
		#$MessLabel.text = "Propper Quest (difficulty: %d)" % itr
	else:
		$MessLabel.add_color_override("font_color", Color.red)
		$MessLabel.text = "不適切な問題です。"
		#$MessLabel.text = "Impropper Quest"
	var txt = ""
	for y in range(N_IMG_CELL_VERT):
		#print(to_binText(h_fixed_bits_1[y]), " ", to_binText(h_fixed_bits_0[y]))
		var mask = 1<<(N_IMG_CELL_HORZ-1)
		var x = -1
		while mask != 0:
			x += 1
			if (h_fixed_bits_1[y] & mask) != 0:
				txt += "#"
			elif (h_fixed_bits_0[y] & mask) != 0:
				txt += "."
			else:
				txt += "?"
				$boardBG/TileMapBG.set_cell(x, y, 0)	# yellow
			mask >>= 1
		txt += "\n"
	print(txt)
	clear_all_crosses();
	pass # Replace with function body.
func update_modeButtons():
	##//if mode == MODE_SOLVE:
		##//$CenterContainer/HBoxContainer/SolveButton.add_color_override("font_color", Color.white)
		##//$CenterContainer/HBoxContainer/SolveButton.icon = load("res://images/light_white.png")
		##//$CenterContainer/HBoxContainer/EditButton.add_color_override("font_color", Color.darkgray)
		##//$CenterContainer/HBoxContainer/EditButton.icon = load("res://images/edit_gray.png")
	##//elif mode == MODE_EDIT_PICT:
		##//$CenterContainer/HBoxContainer/SolveButton.add_color_override("font_color", Color.darkgray)
		##//$CenterContainer/HBoxContainer/SolveButton.icon = load("res://images/light_gray.png")
		##//$CenterContainer/HBoxContainer/EditButton.add_color_override("font_color", Color.white)
		##//$CenterContainer/HBoxContainer/EditButton.icon = load("res://images/edit_white.png")
	pass
func update_commandButtons():
	##//$HintButton.disabled = mode != MODE_SOLVE || hintTime > 0
	##//$LeftButton.disabled = mode == MODE_SOLVE
	##//$DownButton.disabled = mode == MODE_SOLVE
	##//$UpButton.disabled = mode == MODE_SOLVE
	##//$RightButton.disabled = mode == MODE_SOLVE
	##//$CheckButton.disabled = mode == MODE_SOLVE
	pass
func _on_SolveButton_pressed():		# 解答モード
	if mode == MODE_SOLVE:
		return
	mode = MODE_SOLVE
	update_modeUnderLine()
	update_modeButtons()
	update_commandButtons()
	# 解答保存
	for y in range(N_IMG_CELL_VERT):
		h_answer1_bits_1[y] = get_h_data(y)
	#
	clearTileMap()
	clearMiniTileMap()
	init_usedup()
	set_crosses_null_line_column();	# 手がかり数字0の行・列に全部 ☓ を埋める
	pass # Replace with function body.
func change_cross_to_none():
	for y in range(N_IMG_CELL_VERT):
		for x in range(N_IMG_CELL_HORZ):
			if $boardBG/TileMap.get_cell(x, y) == TILE_CROSS:
				$boardBG/TileMap.set_cell(x, y, TILE_NONE)
func clear_clues_BG():
	for y in range(N_IMG_CELL_VERT):
		for x in range(N_CLUES_CELL_HORZ):
			$boardBG/TileMapBG.set_cell(-x-1, y, TILE_NONE)
	for x in range(N_IMG_CELL_HORZ):
		for y in range(N_CLUES_CELL_VERT):
			$boardBG/TileMapBG.set_cell(x, -y-1, TILE_NONE)
func _on_EditButton_pressed():		# 問題エディットモード
	if mode == MODE_EDIT_PICT:
		return
	mode = MODE_EDIT_PICT
	update_modeUnderLine()
	update_modeButtons()
	update_commandButtons()
	change_cross_to_none()		#
	clear_clues_BG()			# 手がかり数字強調クリア
	for y in range(N_IMG_CELL_VERT):		# 画像復活
		var d = h_answer1_bits_1[y]
		var mask = 1 << N_IMG_CELL_HORZ
		for x in range(N_IMG_CELL_HORZ):
			mask >>= 1
			$boardBG/TileMap.set_cell(x, y, TILE_BLACK if (d & mask) != 0 else TILE_NONE)
	upate_imageTileMap()
func _on_BackButton_pressed():
	if !qSolved && !qSolvedStat:
		var lst = []
		for y in range(N_IMG_CELL_VERT):
			lst.push_back(get_h_data(y))
		lst.push_back(-int(elapsedTime))
		for y in range(N_IMG_CELL_VERT):
			lst.push_back(get_h_data0(y))
		g.solvedPat[qID] = lst
		saveSolvedPat()
	get_tree().change_scene("res://LevelScene.tscn")
	pass # Replace with function body.
func set_cell_basic(x, y, v):
	$boardBG/TileMap.set_cell(x, y, v)
	if mode == MODE_EDIT_PICT:
		update_clues(x, y)
	elif mode == MODE_SOLVE:
		#check_all_clues()
		check_clues(x, y)
	var img = 0 if v == TILE_BLACK else TILE_NONE
	$boardBG/MiniTileMap.set_cell(x, y, img)
func set_cell_rect(pos1, pos2, v):
	var x0 = min(pos1.x, pos2.x)
	var y0 = min(pos1.y, pos2.y)
	var wd = max(pos1.x, pos2.x) - x0 + 1
	var ht = max(pos1.y, pos2.y) - y0 + 1
	for y in range(ht):
		for x in range(wd):
			var v0 = $boardBG/TileMap.get_cell(x0+x, y0+y)
			set_cell_basic(x0+x, y0+y, v)
			push_to_undo_stack([SET_CELL, x0+x, y0+y, v0, v])
func _on_UndoButton_pressed():
	undo_ix -= 1
	var item = undo_stack[undo_ix]
	if item[0] == SET_CELL:
		var x = item[1]
		var y = item[2]
		var v0 = item[3]
		set_cell_basic(x, y, v0)
	elif item[0] == SET_CELL_BE:
		set_cell_basic(item[1], item[2], item[3])
		while true:
			undo_ix -= 1
			item = undo_stack[undo_ix]
			set_cell_basic(item[1], item[2], item[3])
			if item[0] == SET_CELL_BE:
				break;
	elif item[0] == CLEAR_ALL:
		for y in range(N_IMG_CELL_VERT):
			var d = item[y+1]
			var mask = 1 << (N_IMG_CELL_HORZ - 1)
			for x in range(N_IMG_CELL_HORZ):
				set_cell_basic(x, y, (TILE_BLACK if (d&mask) != 0 else TILE_NONE))
				mask >>= 1
	elif item[0] == ROT_LEFT:
		rotate_right_basic()
	elif item[0] == ROT_RIGHT:
		rotate_left_basic()
	elif item[0] == ROT_UP:
		rotate_down_basic()
	elif item[0] == ROT_DOWN:
		rotate_up_basic()
	update_undo_redo()
	pass # Replace with function body.
func _on_RedoButton_pressed():
	var item = undo_stack[undo_ix]
	if item[0] == SET_CELL:
		var x = item[1]
		var y = item[2]
		var v = item[4]
		set_cell_basic(x, y, v)
	elif item[0] == SET_CELL_BE:
		set_cell_basic(item[1], item[2], item[4])
		while true:
			undo_ix += 1
			item = undo_stack[undo_ix]
			set_cell_basic(item[1], item[2], item[4])
			if item[0] == SET_CELL_BE:
				break;
	elif item[0] == CLEAR_ALL:
		clear_all_basic()
	elif item[0] == ROT_LEFT:
		rotate_left_basic()
	elif item[0] == ROT_RIGHT:
		rotate_right_basic()
	elif item[0] == ROT_UP:
		rotate_up_basic()
	elif item[0] == ROT_DOWN:
		rotate_down_basic()
	undo_ix += 1
	update_undo_redo()
	pass # Replace with function body.
func fixedLine():
	for y in range(N_IMG_CELL_VERT):
		var d = get_h_data(y)
		if y == 6:
			print("h_data[", y , "] = ", to_binText(d));
			print("h_fixed_bits_1[", y , "] = ", to_binText(h_fixed_bits_1[y]));
		if (d & h_fixed_bits_1[y]) != h_fixed_bits_1[y]:
			return y;
		var d0 = get_h_data0(y)
		if (d0 & h_fixed_bits_0[y]) != h_fixed_bits_0[y]:
			return y;
	return -1
func fixedColumn():
	for x in range(N_IMG_CELL_VERT):
		var d = get_v_data(x)
		if (d & v_fixed_bits_1[x]) != v_fixed_bits_1[x]:
			return x;
		var d0 = get_v_data0(x)
		if (d0 & v_fixed_bits_0[x]) != v_fixed_bits_0[x]:
			return x;
	return -1
func _on_HintButton_pressed():
	init_arrays()
	init_candidates()
	remove_h_candidates_conflicted()
	update_h_fixedbits()	# h_candidates[] を元に h_fixed_bits_1, 0 を計算
	var y = fixedLine()		# 確定セルがある行を探す
	print("hint: line = ", y)
	if y >= 0:
		if true:
			help_text = "%d行目に確定するセルがあります。" % (y+1)
		else:
			help_text = "Hint: fixed cell(s) in the line-%d" % (y+1)
		$MessLabel.add_color_override("font_color", Color.black)
		$MessLabel.text = help_text
		for x in range(N_IMG_CELL_HORZ):
			$boardBG/TileMapBG.set_cell(x, y, TILE_BG_YELLOW)
		hintTime = 60
		update_commandButtons()
		return
	remove_v_candidates_conflicted()
	update_v_fixedbits()	# v_candidates[] を元に v_fixed_bits_1, 0 を計算
	var x = fixedColumn()	# 確定セルがある列を探す
	print("hint: column = ", x)
	if x >= 0:
		if true:
			help_text = "%d列目に確定するセルがあります。" % (x+1)
		else:
			help_text = "Hint: fixed cell(s) in the column-%d" % (x+1)
		$MessLabel.add_color_override("font_color", Color.black)
		$MessLabel.text = help_text
		for y2 in range(N_IMG_CELL_VERT):
			$boardBG/TileMapBG.set_cell(x, y2, TILE_BG_YELLOW)
		hintTime = 60
		update_commandButtons()
		return
	pass # Replace with function body.


func _on_SoundButton_pressed():
	g.settings["Sound"] = $SoundButton.pressed
	saveSettings()
	pass # Replace with function body.
