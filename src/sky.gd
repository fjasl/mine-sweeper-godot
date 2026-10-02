extends Node2D
## 注意：**不能叫 Sky** —— Godot 有内置类 Sky(Environment 的天空资源)，同名会把它遮蔽，
## 报 "Class Sky hides a native class" 并且连引用它的脚本一起解析失败。
class_name NightSky

## 新做的背景效果：**近黑的夜空 + 偶尔划过的流星**。
##
## 为什么不沿用模板那个星形底：那份是"平铺星形 + 时间驱动漂移/自转"，是模板的效果，
## 不是这个游戏的。它在"看久了晕"之外还有个问题 —— 跟玩家做什么完全无关。
## 这里换成一个只跟对局有关的夜空：
##   - 流星是**偶发**的(进度 0 时平均 4 秒多一颗)，不是一直在动
##   - 划过频率**跟着翻开进度涨**：清得越多，夜空越活(进度 1 时约 0.55 秒一颗)
##   - 阶段换色：进行中=冷白 / 通关=暖金并补一小阵 / 失败=转冷转暗
##
## 和原来一样，只被**喂值**(set_progress / set_phase)，自己不去问阶段机或棋盘。
## 性能：**没有流星在飞时 _process 是关的**(靠 Timer 排下一颗)，所以空闲帧零开销。

@export var sky_deep := Color(0.016, 0.020, 0.035)      # 进度 0 的夜空
@export var sky_lit := Color(0.043, 0.055, 0.098)       # 进度 1 的夜空(略亮略蓝)
@export var meteor_color := Color(0.82, 0.88, 1.0)
@export var interval_far := 4.2                          # 多久来一颗(秒，进度 0)
@export var interval_near := 0.55                        # 多久来一颗(秒，进度 1)
@export var speed_min := 620.0
@export var speed_max := 1080.0
@export var length_min := 110.0
@export var length_max := 260.0
@export var fade_speed := 1.5                            # 拖尾淡出速度(每秒)

## 阶段色调(与流星颜色、夜空颜色**相乘**)。进行中=白(不变)
const MOOD := {
	&"won": Color(1.00, 0.87, 0.60),     # 暖金
	&"lost": Color(0.62, 0.66, 0.80),    # 冷、暗
}
const MOOD_NEUTRAL := Color(1, 1, 1)
const WON_BURST := 3                      # 通关那一下补几颗(一阵，不是一颗)

var _progress := 0.0
var _mood := MOOD_NEUTRAL
var _meteors: Array = []                  # 每项 {pos, vel, len, life}
var _rng := RandomNumberGenerator.new()
var _timer: Timer


func _ready() -> void:
	_rng.randomize()
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_spawn)
	_timer.start(_interval())              # 排下第一颗
	set_process(false)                     # 没有流星在飞就不跑 _process
	queue_redraw()


## 翻开进度(0..1)：夜空变亮 + 流星变密。main 从 Board 的 progress_changed 转发过来。
func set_progress(p: float) -> void:
	_progress = clampf(p, 0.0, 1.0)
	queue_redraw()                         # 只有玩家真的翻了牌才重画，不是每帧


## 对局阶段：ready / playing / paused / won / lost。通关补一小阵流星当"庆祝"。
func set_phase(phase: StringName) -> void:
	_mood = MOOD.get(phase, MOOD_NEUTRAL)
	queue_redraw()
	if _mood == MOOD[&"won"]:
		for i in WON_BURST:
			_spawn()


func _process(delta: float) -> void:
	if _meteors.is_empty():
		set_process(false)
		return
	var before := _meteors.size()
	var vp := get_viewport_rect().size
	for m in _meteors:
		m["life"] -= delta * fade_speed
		m["pos"] += (m["vel"] as Vector2) * delta
	var kept: Array = []
	for m in _meteors:
		if (m["life"] as float) > 0.0 and _near_viewport(m["pos"] as Vector2, vp):
			kept.append(m)
	_meteors = kept
	if _meteors.size() != before or not _meteors.is_empty():
		queue_redraw()                     # 有东西消失时必须重画一次，把旧的擦掉
	# 开关一次收到底：最后一颗消失的**这一帧**就关掉，不留一帧空转
	set_process(not _meteors.is_empty())


func _interval() -> float:
	return lerpf(interval_far, interval_near, _progress)


func _spawn() -> void:
	var vp := get_viewport_rect().size
	# 一半朝左下、一半朝右下(屏幕坐标 y 向下)
	var rightward := _rng.randf() < 0.5
	var ang := deg_to_rad(_rng.randf_range(18.0, 34.0) if rightward
			else _rng.randf_range(146.0, 162.0))
	var spd := _rng.randf_range(speed_min, speed_max)
	# 从上方进来：朝右下的从左上方起，朝左下的从右上方起
	var x := _rng.randf_range(0.05, 0.75) if rightward else _rng.randf_range(0.25, 0.95)
	_meteors.append({
		"pos": Vector2(x * vp.x, _rng.randf_range(-0.10, 0.25) * vp.y),
		"vel": Vector2(cos(ang), sin(ang)) * spd,
		"len": _rng.randf_range(length_min, length_max),
		"life": 1.0,
	})
	_timer.start(_interval())
	set_process(true)
	queue_redraw()


func _near_viewport(p: Vector2, vp: Vector2) -> bool:
	return p.x > -400.0 and p.x < vp.x + 400.0 and p.y > -400.0 and p.y < vp.y + 400.0


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), sky_deep.lerp(sky_lit, _progress) * _mood)
	for m in _meteors:
		var head: Vector2 = m["pos"]
		var dir: Vector2 = (m["vel"] as Vector2).normalized()
		var tail: Vector2 = head - dir * (m["len"] as float)
		var a := clampf(m["life"] as float, 0.0, 1.0)
		var col := meteor_color * _mood
		# 一颗流星 = 两层锥形拖尾：外面一层宽而淡(柔光)，里面一层窄而亮(亮芯)
		_draw_streak(head, tail, dir, 5.0, col, 0.10 * a)
		_draw_streak(head, tail, dir, 1.7, col, 0.95 * a)


## 锥形拖尾：头部宽而亮，尾端收窄到几乎为零，靠**顶点色**做渐变(一次 draw_polygon)
func _draw_streak(head: Vector2, tail: Vector2, dir: Vector2, width: float,
		col: Color, alpha: float) -> void:
	var perp := Vector2(-dir.y, dir.x) * (width * 0.5)
	var hot := Color(col.r, col.g, col.b, alpha)
	var cold := Color(col.r, col.g, col.b, 0.0)
	draw_polygon(
		PackedVector2Array([
			head + perp, head - perp,
			tail - perp * 0.12, tail + perp * 0.12]),
		PackedColorArray([hot, hot, cold, cold]))
