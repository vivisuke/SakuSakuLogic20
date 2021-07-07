extends ColorRect

const RADIUS = 5
const POSITION = Vector2(0, 0)

func _draw():   # 描画関数
	var style_box = StyleBoxFlat.new()      # 影、ボーダなどを描画するための矩形スタイルオブジェクト
	style_box.bg_color = Color("#2e4f4f")   # 矩形背景色
	style_box.border_color = Color.green
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(RADIUS)
	style_box.shadow_offset = Vector2(4, 4)     # 影オフセット
	style_box.shadow_size = 8                   # 影（ぼかし）サイズ
	draw_style_box(style_box, Rect2(POSITION, self.rect_size))      # style_box に設定した矩形を描画
