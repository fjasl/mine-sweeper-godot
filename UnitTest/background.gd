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
	
	#计分板
	#计分板横向亮光
	draw_rect(Rect2(Vector2(scoreStartPoint.x, scoreStartPoint.y+ scoreboardHeight- scoreboardBevelThickness), Vector2(scoreboardWidth, scoreboardBevelThickness)), COLOR_HIGHLIGHT)
	#计分板纵向亮光
	draw_rect(Rect2(Vector2(scoreStartPoint.x+ scoreboardWidth- scoreboardBevelThickness, scoreStartPoint.y), Vector2(scoreboardBevelThickness, scoreboardHeight)), COLOR_HIGHLIGHT)
	
	#计分板横向阴影
	draw_rect(Rect2(scoreStartPoint, Vector2(scoreboardWidth, scoreboardBevelThickness)), COLOR_SHADOW)
	#计分板纵向阴影
	draw_rect(Rect2(scoreStartPoint, Vector2(scoreboardBevelThickness, scoreboardHeight)), COLOR_SHADOW)
	
	#棋盘变量
	var boardStartPoint: Vector2 = Vector2(outerHighlightThickness+ leftBorderThickness, outerHighlightThickness+ middleTopBorderThickness+ scoreboardHeight+ middleCenterBorderThickness)
	var boardWidth = cellSize* boardColumns+ boardBevelThickness*2
	var boardHeight = cellSize* boardRows+ boardBevelThickness*2
	
	#棋盘横向高亮
	draw_rect(Rect2(Vector2(boardStartPoint.x, boardStartPoint.y+ boardHeight- boardBevelThickness),Vector2(boardWidth, boardBevelThickness)), COLOR_HIGHLIGHT)
	#棋盘纵向高亮
	draw_rect(Rect2(Vector2(boardStartPoint.x+ boardWidth- boardBevelThickness, boardStartPoint.y),Vector2(boardBevelThickness, boardHeight)), COLOR_HIGHLIGHT)
	#棋盘横向阴影
	draw_rect(Rect2(boardStartPoint, Vector2(boardWidth, boardBevelThickness)), COLOR_SHADOW)
	#棋盘纵向阴影
	draw_rect(Rect2(boardStartPoint, Vector2(boardBevelThickness, boardHeight)), COLOR_SHADOW)
	
