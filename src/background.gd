extends Node2D
class_name Background

@export var centerInViewport: bool = true

@export var cellSize: int = 16
@export var boardColumns: int = 30
@export var boardRows: int = 16

@export var outerHighlightThickness: int = 5
@export var scoreboardBevelThickness: int = 2
@export var scoreboardHeight: int = 36
@export var boardBevelThickness: int = 4
@export var leftBorderThickness: int = 6
@export var rightBorderThickness: int = 5
@export var middleTopBorderThickness: int = 6
@export var middleCenterBorderThickness: int = 6
@export var middleBottomBorderThickness: int = 5

const COLOR_BG: Color = Color("#C0C0C0")
const COLOR_HIGHLIGHT: Color = Color("#FFFFFF")
const COLOR_SHADOW: Color = Color("#808080")

func _ready():
	# 想让整块棋盘画在屏幕中心：移动节点 position 即可整体平移绘制内容。
	# 勾掉 centerInViewport 就可以手动拖拽/填充 position 自由摆放。
	if centerInViewport:
		center_in_viewport()

# 整块棋盘的包围尺寸（本地 (0,0) 就是绘制原点）
func board_size() -> Vector2:
	var totalWidth: int = outerHighlightThickness + leftBorderThickness + boardBevelThickness + cellSize * boardColumns + boardBevelThickness + rightBorderThickness
	var totalHeight: int = outerHighlightThickness + middleTopBorderThickness + scoreboardBevelThickness + scoreboardHeight + scoreboardBevelThickness + middleCenterBorderThickness + boardBevelThickness + cellSize * boardRows + boardBevelThickness + middleBottomBorderThickness
	return Vector2(totalWidth, totalHeight)

func board_grid_origin() -> Vector2:
	# 棋盘面板左上角
	var board_start := Vector2(
		outerHighlightThickness + leftBorderThickness,
		outerHighlightThickness + middleTopBorderThickness + scoreboardHeight + middleCenterBorderThickness
	)
	# 面板往内缩一个 bevel 厚度，才是第一格(0,0)的位置
	return board_start + Vector2(boardBevelThickness, boardBevelThickness)

func place_display(display, side: String, inset: float) -> Vector2:
	var rect = scoreboard_rect()
	var tsize = display.display_size()
	var y = rect.position.y + (rect.size.y - tsize.y) / 2.0
	var x
	match side:
		"right":  x = rect.position.x + rect.size.x - inset - tsize.x
		"left":   x = rect.position.x + inset
		"center": x = rect.position.x + (rect.size.x - tsize.x) / 2.0
	return Vector2(x, y)


func scoreboard_rect() -> Rect2:
	var totalWidth := board_size().x
	var sp := Vector2(outerHighlightThickness + leftBorderThickness,
		outerHighlightThickness + middleTopBorderThickness)
	return Rect2(sp, Vector2(totalWidth - outerHighlightThickness - leftBorderThickness - rightBorderThickness, scoreboardHeight))

func center_in_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	position = (viewport_size - board_size()) / 2.0

func _draw():
	# 总宽度/总高度：本地坐标为原点，绘制内容整体由节点 position 决定位置
	var bsize: Vector2 = board_size()
	var totalWidth: int = int(bsize.x)
	var totalHeight: int = int(bsize.y)

	# 背景色
	draw_rect(Rect2(Vector2.ZERO, Vector2(totalWidth, totalHeight)), COLOR_BG)
	
	#外圈
	#横向高亮
	draw_rect(Rect2(Vector2.ZERO, Vector2(totalWidth, outerHighlightThickness)), COLOR_HIGHLIGHT)
	#纵向
	draw_rect(Rect2(Vector2.ZERO, Vector2(outerHighlightThickness, totalHeight)), COLOR_HIGHLIGHT)
	
	#计分板变量
	var scoreStartPoint: Vector2 = Vector2(outerHighlightThickness+ leftBorderThickness, outerHighlightThickness+ middleTopBorderThickness)
	var scoreboardWidth: int = totalWidth- outerHighlightThickness- leftBorderThickness- rightBorderThickness
	
	#计分板（左下角、右上角 45° 斜切衔接，而非矩形直角覆盖）
	_draw_panel_bevel(scoreStartPoint, Vector2(scoreboardWidth, scoreboardHeight), scoreboardBevelThickness)
	
	#棋盘变量
	var boardStartPoint: Vector2 = Vector2(outerHighlightThickness+ leftBorderThickness, outerHighlightThickness+ middleTopBorderThickness+ scoreboardHeight+ middleCenterBorderThickness)
	var boardWidth = cellSize* boardColumns+ boardBevelThickness*2
	var boardHeight = cellSize* boardRows+ boardBevelThickness*2
	
	#棋盘（同样左下角、右上角 45° 斜切衔接）
	_draw_panel_bevel(boardStartPoint, Vector2(boardWidth, boardHeight), boardBevelThickness)


# 绘制一块凸起面板的边框：
# 上/左 亮色(阴影)，下/右 亮色(高光)。在「左下角」和「右上角」这两处
# 阴影条与高光条相接的角落，用 45° 斜边衔接，而不是两个矩形直接直角覆盖。
func _draw_panel_bevel(p: Vector2, size: Vector2, bevel: int) -> void:
	var x0: float = p.x
	var y0: float = p.y
	var x1: float = p.x + size.x
	var y1: float = p.y + size.y
	var b: float = float(bevel)

	# 顶部阴影条（右上角 45° 斜切）
	draw_colored_polygon(PackedVector2Array([
		Vector2(x0, y0),
		Vector2(x1, y0),
		Vector2(x1 - b, y0 + b),
		Vector2(x0, y0 + b),
	]), COLOR_SHADOW)

	# 左侧阴影条（左下角 45° 斜切）
	draw_colored_polygon(PackedVector2Array([
		Vector2(x0, y0),
		Vector2(x0 + b, y0),
		Vector2(x0 + b, y1 - b),
		Vector2(x0, y1),
	]), COLOR_SHADOW)

	# 底部高光条（左下角 45° 斜切）
	draw_colored_polygon(PackedVector2Array([
		Vector2(x0 + b, y1 - b),
		Vector2(x1, y1 - b),
		Vector2(x1, y1),
		Vector2(x0, y1),
	]), COLOR_HIGHLIGHT)

	# 右侧高光条（右上角 45° 斜切）
	draw_colored_polygon(PackedVector2Array([
		Vector2(x1, y1),
		Vector2(x1 - b, y1),
		Vector2(x1 - b, y0 + b),
		Vector2(x1, y0),
	]), COLOR_HIGHLIGHT)
