extends Node2D
class_name ScoreTimer

signal ticked   # 每过 1 秒触发一次

# LED 图里单个数字瓦片的尺寸(改成你实际的)
@export var tile_w := 13.0
@export var tile_h := 23.0
@export var gap_px := 0.0                  # 数字间像素间距(0 就是紧贴)

@onready var d: Array = [$D0, $D1, $D2]    # 3 个 Sprite2D,同一张 led 纹理,开 region

var elapsed := 0.0
## 表当前是否在走。**完全由阶段机决定**(Playing 才 true，其余 false)。
## 唯一的真相就在这一个布尔上：别在别处再挂一个"暂停"标志，
## 否则"表在走"与"表被冻住"会分家。
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

## 暂停 / 继续：playing <-> paused 之间来回用(设置抽屉的开关)。
## 与 stop() 的区别只在语义上 —— 表停在半途、待会儿还要接着走；
## **resume() 不像 start() 那样把 elapsed 归零**，这正是"恢复计时"要的。
## _last_sec 也不动：恢复时当前这一秒还没走完，不会多响一声滴答。
func pause() -> void: running = false
func resume() -> void: running = true
func reset() -> void: elapsed = 0.0; running = false; _last_sec = -1; set_number(0)   # 重开:回到 0 且不计时

func display_size() -> Vector2:
	return Vector2(2 * (tile_w + gap_px) + tile_w, tile_h)
