@tool
extends HBoxContainer
class_name SegmentationLine
@export var title_show:bool :
	set(value):
		title_show = value
		notify_property_list_changed()
		_update_visibility()
@export var title:StringName:
	set(value):
		title = value
		if is_instance_valid(label):
			label.text = title
			
@onready var label: Label = $Label
@onready var color_rect_2: ColorRect = $ColorRect2

func _update_visibility() -> void:
	if not is_node_ready():   # ✅ 防止 editor 里过早调用
		return
	label.visible = title_show
	color_rect_2.visible = title_show

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if title_show:
		label.show()
		color_rect_2.show()
	label.text=title
	notify_property_list_changed()
		
	pass # Replace with function body.
