extends HBoxContainer
@onready var label_num_value: Label = $LabelNumValue
@onready var h_slider: HSlider = $HSlider
@export var start_text:StringName
@export var end_text:StringName
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
	
	if not start_text.is_empty():
		label_num_value.text=start_text+str(int(value))
	elif  not end_text.is_empty():
		label_num_value.text=str(int(value))+end_text


func _on_timer_timeout() -> void:
	audio_stream_player.play(0.04)
	pass # Replace with function body.
