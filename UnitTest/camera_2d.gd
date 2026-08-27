extends Camera2D

@export var min_zoom := 0.5
@export var max_zoom := 5.0
@export var move_speed := 400.0

func _process(delta: float) -> void:
	# 平移：ui_* 内置 action
	position += Input.get_vector("ui_left","ui_right","ui_up","ui_down") * move_speed * delta

	# 缩放：自定义 action，滚轮每滚一格是"刚按下"，用 is_action_just_pressed
	if Input.is_action_just_pressed("zoom_in"):
		_zoom(1.1)
	if Input.is_action_just_pressed("zoom_out"):
		_zoom(1.0 / 1.1)

	_clamp_to_canvas()

func _clamp_to_canvas() -> void:
	var canvas := get_viewport_rect()
	var half := canvas.size / 2.0 / zoom
	if canvas.size.x >= half.x * 2 and canvas.size.y >= half.y * 2:
		position.x = clampf(position.x, canvas.position.x + half.x, canvas.end.x - half.x)
		position.y = clampf(position.y, canvas.position.y + half.y, canvas.end.y - half.y)

func _zoom(f: float) -> void:
	zoom = (zoom * f).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
