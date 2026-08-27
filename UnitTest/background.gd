extends Node2D

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

func _draw():
	# 总宽度：外层高光 + 左边框 + 棋盘高光 + 棋盘宽度 + 棋盘阴影 + 右边框
	var totalWidth: int = outerHighlightThickness + leftBorderThickness + boardBevelThickness + cellSize * boardColumns + boardBevelThickness + rightBorderThickness
	
	# 总高度：外层高光 + 中上边框 + 计分板高光 + 计分板高度 + 计分板阴影 + 中中边框 + 棋盘高光 + 棋盘高度 + 棋盘阴影 + 中底边框
	var totalHeight: int = outerHighlightThickness + middleTopBorderThickness + scoreboardBevelThickness + scoreboardHeight + scoreboardBevelThickness + middleCenterBorderThickness + boardBevelThickness + cellSize * boardRows + boardBevelThickness + middleBottomBorderThickness
	
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
