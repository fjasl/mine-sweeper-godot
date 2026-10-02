extends Node2D
class_name ScoreTimer

signal ticked   # 每过 1 秒触发一次

# LED 图里单个数字瓦片的尺寸(改成你实际的)
@export var tile_w := 13.0
@export var tile_h := 23.0
@export var gap_px := 0.0                  # 数字间像素间距(0 就是紧贴)

@onready var d: Array = [$D0, $D1, $D2]    # 3 个 Sprite2D,同一张 led 纹理,开 region

var elapsed := 0.0
var running := false
var _last_sec := -1

func _ready() -> void:
	if d[0].texture == null:
		push_error("D0/D1/D2 需要设置 texture(led 图)且 region_enabled=true")
	for i in 3:
		d[i].centered = false                       # ← 以左上角为锚点(默认是中心)
		d[i].position = Vector2(i * (tile_w + gap_px), 0)   # 像素定位
	set_number(0)

func _process(delta: float) -> void:
	if running:
		elapsed += delta
		var sec := int(elapsed)
		if sec != _last_sec:
			_last_sec = sec
			set_number(sec)
			ticked.emit()

func set_number(n: int) -> void:
	n = clampi(n, 0, 999)
	@warning_ignore("integer_division")
	var digits := [n / 100, (n / 10) % 10, n % 10]
	for i in 3:
		# 数字 d 在 led 图里是第 (11 - d) 行(第0列)
		var r := Rect2(0, (11 - digits[i]) * tile_h, tile_w, tile_h)
		d[i].region_rect = r

func start() -> void: elapsed = 0.0; running = true; _last_sec = -1; set_number(0)
func stop() -> void: running = false
func reset() -> void: elapsed = 0.0; running = false; _last_sec = -1; set_number(0)   # 重开:回到 0 且不计时

func display_size() -> Vector2:
	return Vector2(2 * (tile_w + gap_px) + tile_w, tile_h)
