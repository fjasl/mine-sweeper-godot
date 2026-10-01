extends Node2D


# 标上类型：否则从它们派生的局部变量用 := 推导不出类型
# (cam 故意不标：camera_2d.gd 没有 class_name，标成内置 Camera2D 会让
#  cam.set_world_bounds() 变成"方法不存在"的静态错误；想标就先给它加 class_name)
@onready var cam = $Camera2D
@onready var background: Background = $Background
@onready var board: Board = $Background/Board
@onready var timer: ScoreTimer = $Background/ScoreTimer
@onready var counter: MineCounter = $Background/MineCounter
@onready var face: Smiley = $Background/StateFace
@onready var settings_btn: TextureButton = $UILayer/SettingsButton
@onready var settings_panel: SettingsPanel = $UILayer/SettingsPanel
@onready var game_over_panel: GameOverPanel = $UILayer/GameOverPanel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 摆放与相机：几何全部由 _relayout() 统一负责
	_relayout()

	# board 的信号 → UI
	board.started.connect(func(): timer.start())
	board.flags_changed.connect(func(r): counter.set_number(r))
	# 计时器每跳一秒 → 滴答声
	timer.ticked.connect(func(): CoreSystem.audio_manager.play_sound("res://Asset/tick.wav"))
	board.won.connect(func():
		timer.stop()
		face.set_state("win")
		game_over_panel.show_result(true)
		CoreSystem.audio_manager.play_sound("res://Asset/win.wav")
	)
	board.lost.connect(func():
		timer.stop()
		face.set_state("lose")
		game_over_panel.show_result(false)
		CoreSystem.audio_manager.play_sound("res://Asset/explode.wav")
	)

	# 再来一次(_restart 内部已收起弹窗)
	game_over_panel.play_again.connect(_restart)

	# 背景音乐(项目里没有 bgm.ogg;如果加进了 Asset 就启用下面这行)
	# CoreSystem.audio_manager.play_music("res://Asset/bgm.ogg", 0.0)

	# 开局 HUD：计时器归零 + 剩余雷数 + 笑脸 normal
	_refresh_hud()

	# 输掉后点表情 → 重开
	face.restart_requested.connect(_restart)
	
	
	settings_panel.set_restart_func(_restart)
	
	settings_btn.pressed.connect(settings_panel.toggle)
	settings_panel.apply_settings.connect(_apply_settings)
	# 设置面板打开时,屏蔽棋盘输入(手柄导航给面板用)
	# 这里刻意跟 visible(动画结果)而不是面板的"意图" —— 门控的意义正是"面板是否占着屏幕"
	settings_panel.visibility_changed.connect(func():
		board.set_process_unhandled_input(not settings_panel.visible))


# 唯一的新局路径：重置棋盘 + 刷新 HUD + 收起弹窗
func _restart() -> void:
	board.new_game()
	_refresh_hud()
	game_over_panel.hide_result()

# HUD 复位(开局与重开共用)
func _refresh_hud() -> void:
	timer.reset()                                       # 计时器归零且不计时
	counter.set_number(board.remaining_mines())
	face.set_state("normal")


# 设置面板"应用"：颜色是表现层的事，规格变更交给 Board
func _apply_settings(cols: int, rows: int, mine_count: int, cursor_color: Color) -> void:
	# 光标颜色：纯表现，总是生效，不需要重开
	board.set_cursor_color(cursor_color)

	# 规格校验/写入都在 Board 里(规则的唯一出处)；规格没变就直接结束
	if not board.apply_spec(cols, rows, mine_count):
		return

	_restart()      # 新局 + HUD 复位 + 收起弹窗(修掉改尺寸后笑脸/弹窗不复位)
	_relayout()     # 尺寸变了，表现层几何与相机要重算

# 尺寸变化后的表现层重排(几何与相机的唯一出处)
func _relayout() -> void:
	var s := board.spec()                        # Vector3i(cols, rows, mine_count)
	background.boardColumns = s.x                # 从唯一真值同步，不再由外部传参
	background.boardRows = s.y
	board.position = background.board_grid_origin()
	timer.position  = background.place_display(timer,   "right", 8)
	counter.position = background.place_display(counter, "left", 8)
	face.position = background.place_display(face, "center", 0)
	background.center_in_viewport()   # 背景先居中，相机位置依赖它
	background.queue_redraw()
	# 相机中心的活动范围＝原版那一屏世界区域(棋盘中心 ± 半个视口)，
	# 范围沿用原版，夹取方式换成"中心夹取"，所以 zoom == 1 时不再被钉死
	var view: Vector2 = get_viewport_rect().size
	var board_center: Vector2 = background.position + background.board_size() / 2.0
	cam.set_world_bounds(Rect2(board_center - view / 2.0, view))
	cam.position = board_center       # 相机复位到新棋盘中心
	cam.zoom = Vector2(1, 1)          # 相机复位到新棋盘视野

# new_game 输入 → 重开(_restart 内部已收起弹窗)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("new_game"):
		_restart()
	elif event.is_action_pressed("setting_pane"):
		settings_panel.toggle()
