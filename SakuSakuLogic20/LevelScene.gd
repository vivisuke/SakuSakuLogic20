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
	var file = File.new()
	if file.file_exists(g.settingsFileName):
		file.open(g.settingsFileName, File.READ)
		g.settings = file.get_var()
		file.close()
		print(g.settings)
	#var vsb = $ScrollContainer.get_v_scrollbar()
	#vsb.step = 10
	if !g.solvedPatLoaded:			# クリア履歴未読込の場合
		g.solvedPatLoaded = true
		#print(g.solvedPatFileName)
		if file.file_exists(g.solvedPatFileName):
			file.open(g.solvedPatFileName, File.READ)
			g.solvedPat = file.get_var()
			file.close()
			##print(g.solvedPat)
	print(g.quest_list0.size())
	if g.quest_list.empty():	# ソート済み問題配列が空
		g.quest_list.resize(g.quest_list0.size())
		for i in range(g.quest_list0.size()):
			g.quest_list[i] = g.quest_list0[i]
		g.quest_list.sort_custom(MyCustomSorter, "sort_ascending")
	#if g.qNum2QIX.empty():			# 問題番号 → 問題リストIX（qix）テーブルが未構築の場合
	#	g.qNum2QIX.resize(g.quest_list.size())
	#	for i in range(g.quest_list.size()):
	#		g.qNum2QIX[i] = i
	#	MyCustomSorter.g = g
	#	g.qNum2QIX.sort_custom(MyCustomSorter, "sort_ascending")
	g.ans_images.resize(g.quest_list.size())
	g.qix2ID.resize(g.quest_list.size())
	var score = 0
	var nSolved = 0
	for i in g.quest_list.size():	# 問題パネルセットアップ
		#if g.solved.size() <= i:
		#	g.solved.push_back(false)
		#var qix = g.qNum2QIX[i]
		var qix = i
		g.qix2ID[qix] = g.quest_list[qix][g.KEY_ID]
		var panel = QuestPanel.instance()
		panel.set_number(i+1)
		var diffi = g.quest_list[qix][g.KEY_DIFFICULTY]
		panel.set_difficulty(diffi)
		#if g.solved[i]:
		var ns = 0
		var solved = false;
		if g.solvedPat.has(g.qix2ID[qix]):		# クリア済み or 途中経過あり
			var lst = g.solvedPat[g.qix2ID[qix]]
			if lst.size() <= g.N_IMG_CELL_VERT || lst[g.N_IMG_CELL_VERT] > 0:
				solved = true
				panel.set_title(g.quest_list[qix][g.KEY_TITLE])
			else:
				panel.set_title(g.quest_list[qix][g.KEY_TITLE][0] + "???")
			panel.set_ans_image(lst)
			#panel.set_ans_image(g.ans_images[i])
			#panel.set_clearTime(lst[N_IMG_CELL_VERT] if lst.size() > N_IMG_CELL_VERT else 0)
			if lst.size() > g.N_IMG_CELL_VERT:	# クリアタイムあり
				panel.set_clearTime(lst[g.N_IMG_CELL_VERT])
				if solved:
					if lst[g.N_IMG_CELL_VERT] < diffi * 60 * 0.5:
						ns = 3
					elif lst[g.N_IMG_CELL_VERT] < diffi * 60:
						ns = 2
					elif lst[g.N_IMG_CELL_VERT] < diffi * 60 * 2:
						ns = 1
			else:
				panel.set_clearTime(0)
		else:
			panel.set_title(g.quest_list[qix][g.KEY_TITLE][0] + "???")
			panel.set_clearTime(0)
		if solved:
			nSolved += 1
			score += diffi * (10 + ns*2)
		panel.set_star(ns)
		panel.set_author(g.quest_list[qix][g.KEY_AUTHOR])
		$ScrollContainer/VBoxContainer.add_child(panel)
		#
		panel.connect("pressed", self, "_on_QuestPanel_pressed")
	$scoreLabel.text = "SCORE: %d" % score
	var pc : int = round(nSolved * 100.0 / g.quest_list.size())
	$solvedLabel.text = "Solved: %d/%d (%d%%)" % [nSolved, g.quest_list.size(), pc]
	print("vscroll = ", g.lvl_vscroll)
	$ScrollContainer.set_v_scroll(g.lvl_vscroll)
	pass # Replace with function body.
	pass # Replace with function body.

func _input(event):
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == BUTTON_WHEEL_UP:
				print("BUTTON_WHEEL_UP")
			if event.button_index == BUTTON_WHEEL_DOWN:
				print("BUTTON_WHEEL_DOWN")
		#print("InputEventMouseButton")
		if event.is_action_pressed("click"):		# left mouse button
			if $ScrollContainer.get_global_rect().has_point(event.position):		# in ScrollContainer
				mouse_pushed = true;
				mouse_pos = event.position
				scroll_pos = $ScrollContainer.get_v_scroll()
		elif event.is_action_released("click"):
			mouse_pushed = false;
			mouse_pos = null
	elif event is InputEventMouseMotion && mouse_pushed:	# mouse Moved
		$ScrollContainer.set_v_scroll(scroll_pos + mouse_pos.y - event.position.y)
	pass

func _on_QuestPanel_pressed(num):
	print("mouse_pos = ", mouse_pos)
	if mouse_pos == null || dialog_opened:
		return
	var v = $ScrollContainer.scroll_vertical
	print("v = ", v)
	print("QuestPanel_pressed(", num, ")")
	g.lvl_vscroll = $ScrollContainer.scroll_vertical
	print("vscroll = ", g.lvl_vscroll)
	g.solveMode = true;
	g.qNumber = num
	#g.qix = qNum2QIX[num-1]
	get_tree().change_scene("res://MainScene.tscn")
	pass # Replace with function body.


func _on_ClearButton_pressed():
	pass # Replace with function body.


func _on_EditButton_pressed():
	g.lvl_vscroll = $ScrollContainer.scroll_vertical
	print("vscroll = ", g.lvl_vscroll)
	g.solveMode = false;
	get_tree().change_scene("res://MainScene.tscn")
	pass # Replace with function body.
