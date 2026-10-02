extends Resource
class_name BoardSpec

## 一局棋盘的规格：宽、高、雷数。
##
## 定位是「跨模块传递的值对象」，取代原先 Vector3i(cols, rows, mines) 那种只靠注释
## 约定的写法。用 Resource 是为了将来把「每档难度」做成 .tres 预设，以及给最佳成绩
## 做序列化。
##
## 约定：真相永远是 Mines 上的三个 int 字段，本类只是过路的信使 ——
## 不要把它存起来当状态，否则就出现了第二个真相来源。

@export var cols: int = 30
@export var rows: int = 16
@export var mine_count: int = 60

# 规格约束(原先住在 mines.gd)：跟着数据走，UI 与逻辑都从这里取
const MIN_COLS := 9
const MAX_COLS := 40
const MIN_ROWS := 9
const MAX_ROWS := 24

## 构造一个新实例(每次都新建，避免共享同一个 Resource 被互相改串)
static func make(c: int, r: int, m: int) -> BoardSpec:
	var s := BoardSpec.new()
	s.cols = c
	s.rows = r
	s.mine_count = m
	return s

## 夹到合法范围。跨字段约束也在这里：雷数不能占满整盘(否则首击无处挪雷)
func clamped() -> BoardSpec:
	var c := clampi(cols, MIN_COLS, MAX_COLS)
	var r := clampi(rows, MIN_ROWS, MAX_ROWS)
	return BoardSpec.make(c, r, clampi(mine_count, 1, c * r - 1))

## 总格数
func total_cells() -> int:
	return cols * rows

## 雷数上限(至少留一格给首击)
func max_mines() -> int:
	return cols * rows - 1

## 规格是否相同
func equals(other: BoardSpec) -> bool:
	if other == null:
		return false
	return cols == other.cols and rows == other.rows and mine_count == other.mine_count
