extends PanelContainer
@onready var button_audio_stream_player: AudioStreamPlayer = $BottomContainer/ButtonAudioStreamPlayer
@onready var bottom_container: HBoxContainer = $BottomContainer
@export var tab_container: TabContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var index=0;
	for button in bottom_container.get_children():
		
		if button is Button:
			button.button_down.connect(_on_mouse_down.bind(button,index))
			index+=1
			
	pass # Replace with function body.


func _on_mouse_down(button:Button,index:int):
	print(index)
	if button.button_pressed==false:
		tab_container.current_tab=index
		button_audio_stream_player.play(0.04)
	pass
