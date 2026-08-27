extends TileMapLayer
class_name Mines

@export var cols := 30
@export var rows := 16
@export var mine_count := 60

# 你定好的 坐标→状态 映射(用同一张表)
const TILE := {
	"covered": Vector2i(0,0), 
	"empty": Vector2i(0,15),
	"1": Vector2i(0,14),
	"2": Vector2i(0,13), 
	"3": Vector2i(0,12),
	"4": Vector2i(0,11), 
	"5": Vector2i(0,10),
	"6": Vector2i(0,9),
	"7": Vector2i(0,8),
	"8": Vector2i(0,7),
	"mine": Vector2i(0,5),
	"mine_hit": Vector2i(0,3),
	"flag": Vector2i(0,1),
	"question": Vector2i(0,2),
	"wrong_flag": Vector2i(0,1),
	"covered_pressed": Vector2i(0,15),
}

var cells := {}            # Vector2i -> {mine:bool, visit:bool, mark:int(0无/1旗/2问号)}
var game_over := false
var reveal_target := 0
var revealed_count := 0

func _ready() -> void:
	start_game()

func start_game() -> void:
	cells.clear()
	revealed_count = 0
	game_over = false
	reveal_target = cols * rows - mine_count
	for x in cols:
		for y in rows:
			cells[Vector2i(x,y)] = {"mine": false, "visit": false, "mark": 0}
	_place_mines()
	fill_covered()


func fill_covered() -> void:
	for x in cols:
		for y in rows:
			set_cell(Vector2i(x,y), 0, TILE["covered"])

func _place_mines() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var placed := 0
	while placed < mine_count:
		var c := Vector2i(rng.randi_range(0, cols-1), rng.randi_range(0, rows-1))
		if not cells[c]["mine"]:
			cells[c]["mine"] = true
			placed += 1

# 左键：翻开（对应 StepSquare/StepBox）
func reveal(cell: Vector2i) -> void:
	if game_over: return
	var st: Dictionary = cells[cell]
	if st["visit"] or st["mark"] != 0: return
	if st["mine"]:
		if revealed_count == 0:
			_relocate_mine(cell)          # 第一步踩雷：把雷挪走
		else:
			set_cell(cell, 0, TILE["mine_hit"])
			_game_over(false, cell)  
			return
	_step_box(cell)
	if revealed_count == reveal_target:
		_game_over(true)

# 右键：旗→问号→取消（对应 MakeGuess，去掉偏好只留循环）
func toggle_flag(cell: Vector2i) -> void:
	if game_over: return
	var st: Dictionary = cells[cell]
	if st["visit"]: return
	match st["mark"]:
		0:
			st["mark"] = 1
			set_cell(cell, 0, TILE["flag"])
		1:
			st["mark"] = 2
			set_cell(cell, 0, TILE["question"])
		_:
			st["mark"] = 0
			set_cell(cell, 0, TILE["covered"])

# 双击已翻开的数字：周围旗数==数字时翻开周围（对应 StepBlock）
func chord(cell: Vector2i) -> void:
	if game_over or not cells[cell]["visit"]: return
	var num := _num(cell)
	if num == 0 or _flags_around(cell) != num: return
	for nb in _neighbors(cell):
		var st: Dictionary = cells[nb]
		if st["mark"] != 0: continue
		if st["mine"]:
			set_cell(nb, 0, TILE["mine_hit"])
			_game_over(false, nb)  
			return
		_step_box(nb)
	if revealed_count == reveal_target:
		_game_over(true)

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows

# ---- 内部 ----
func _step_box(start: Vector2i) -> void:
	var queue: Array = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		var st: Dictionary = cells[c]
		if st["visit"] or st["mine"] or st["mark"] != 0: continue
		st["visit"] = true
		revealed_count += 1
		var n := _num(c)
		if n == 0:
			set_cell(c, 0, TILE["empty"])
			for nb in _neighbors(c):
				if not cells[nb]["visit"]:
					queue.append(nb)
		else:
			set_cell(c, 0, TILE[str(n)])

func _num(c: Vector2i) -> int:
	var n := 0
	for nb in _neighbors(c):
		if cells[nb]["mine"]: n += 1
	return n

func _flags_around(c: Vector2i) -> int:
	var n := 0
	for nb in _neighbors(c):
		if cells[nb]["mark"] == 1: n += 1
	return n

func _neighbors(c: Vector2i) -> Array:
	var out: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0: continue
			var nb := c + Vector2i(dx, dy)
			if in_bounds(nb): out.append(nb)
	return out

func _relocate_mine(cell: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var t: Vector2i = cell
	while t == cell or cells[t]["mine"]:
		t = Vector2i(rng.randi_range(0, cols-1), rng.randi_range(0, rows-1))
	cells[cell]["mine"] = false
	cells[t]["mine"] = true

func _game_over(won: bool, hit: Vector2i = Vector2i(-1, -1)) -> void:
	if game_over: return
	game_over = true
	if won:
		for c in cells:
			if cells[c]["mine"]:
				set_cell(c, 0, TILE["flag"])
	else:
		for c in cells:
			var st: Dictionary = cells[c]
			if st["visit"]: continue
			if c == hit: continue                 # 踩中的那颗保持 mine_hit
			if st["mine"] and st["mark"] != 1:
				set_cell(c, 0, TILE["mine"])
			elif st["mark"] == 1 and not st["mine"]:
				set_cell(c, 0, TILE["wrong_flag"])
	print("WIN" if won else "LOSE")
