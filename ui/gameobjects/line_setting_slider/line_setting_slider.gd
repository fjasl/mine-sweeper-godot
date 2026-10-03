extends HBoxContainer
@onready var label_num_value: Label = $LabelNumValue
@onready var h_slider: HSlider = $HSlider
@export var start_text:StringName
@export var end_text:StringName
## 数值标签的小数位。**默认 0 = 原来的整数显示**，模板 demo 的行为一字不变；
## 手感参数是小数(如 0.045 / 1.6)，所以那几个行会把它设成 1~2。
@export var decimals:int = 0
## 显示前先乘的系数(0.045 → 4.5 用 100)。默认 1 = 不缩放
@export var display_scale:float = 1.0
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var timer: Timer = $Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	change_label_text(h_slider.value)
	notify_property_list_changed()
	pass # Replace with function body.




func _on_h_slider_value_changed(value: float) -> void:
	#timer.start()
	change_label_text(value)
	pass # Replace with function body.
func change_label_text(value):
	# 原来这里是 str(int(value))：整数滑条够用，但手感阈值都是小数
	# (轻点容差 0.045、指针灵敏度 1.6)，取整会把它们全显示成 0 或 1。
	# 改成按 decimals 保留小数位、按 display_scale 先放大。
	#
	# 另一处修正：原来是 `if start_text ... elif end_text ...`，两个都空时**一个字都不写**，
	# 标签会一直停在 .tscn 里的占位文字("89%")。手感那几行里有不带单位的(灵敏度/加速)，
	# 正好踩中 —— 表现就是"数字不更新"。现在改成"总是写"，只是没单位时不缀单位。
	var txt := String.num(value * display_scale, decimals)
	if not start_text.is_empty():
		label_num_value.text=start_text+txt
	else:
		label_num_value.text=txt+end_text


func _on_timer_timeout() -> void:
	audio_stream_player.play(0.04)
	pass # Replace with function body.
