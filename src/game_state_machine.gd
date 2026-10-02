extends BaseStateMachine
class_name GameStateMachine

## 扫雷的对局阶段机：ready(待首击) → playing(进行中) → won / lost
##
## 设计要点：
##  - 每个状态把自己该做的事写在 _enter() 里，不依赖"上一个状态做过什么" ——
##    迁移图会变(将来加"暂停"之类)，靠前驱的写法迟早会碎。
##  - 迁移由规则层的信号驱动(见 bind)，规则层本身不知道这台机器存在。
##  - 同一次点击可能连续迁移两次(首击即翻完所有非雷格时 started 与 won 同帧发出)，
##    所以任何状态都要能承受"一帧内进入又离开"。
##  - 部件引用由 main 注入，而不是走 BaseState.agent：用 agent 就得写
##    `agent as GameMain`，而 main 又引用了 GameStateMachine —— 两个 class_name
##    互相引用会构成循环依赖，Godot 可能拒绝编译。

## 状态要用到的部件(main 在注册之前注入)
var board: Board
var timer: ScoreTimer
var counter: MineCounter
var face: StateFace
var result_panel: GameOverPanel

## 由 main 注入棋盘事件：把"规则事件 → 阶段"的映射留在本文件里，
## 以后加规则信号也只改这一处
func bind(b: Board) -> void:
	b.started.connect(func(): transition_to(&"playing"))
	b.won.connect(func(): transition_to(&"won"))
	b.lost.connect(func(): transition_to(&"lost"))

## add_state 必须写在 _ready 里：BaseState.ready() 会调用它，
## 而 ready() 必须在 start() 之前被调用(由 main 经 state_machine_manager 触发)
func _ready() -> void:
	add_state(&"ready", ReadyState.new())
	add_state(&"playing", PlayingState.new())
	add_state(&"won", WonState.new())
	add_state(&"lost", LostState.new())

## 待首击：棋盘已铺好，计时未开始
class ReadyState extends BaseState:
	func _enter(_msg: Dictionary = {}) -> void:
		var m := state_machine as GameStateMachine
		m.timer.reset()                                  # 归零且不计时
		m.counter.set_number(m.board.remaining_mines())
		m.face.set_state("normal")
		m.result_panel.hide_result()

## 进行中：首击已翻开，计时中
class PlayingState extends BaseState:
	func _enter(_msg: Dictionary = {}) -> void:
		(state_machine as GameStateMachine).timer.start()

## 胜利：全非雷格已翻开
class WonState extends BaseState:
	func _enter(_msg: Dictionary = {}) -> void:
		var m := state_machine as GameStateMachine
		m.timer.stop()
		m.face.set_state("win")
		m.result_panel.show_result(true)
		CoreSystem.audio_manager.play_sound("res://Asset/win.wav")

## 失败：踩到雷
class LostState extends BaseState:
	func _enter(_msg: Dictionary = {}) -> void:
		var m := state_machine as GameStateMachine
		m.timer.stop()
		m.face.set_state("lose")
		m.result_panel.show_result(false)
		CoreSystem.audio_manager.play_sound("res://Asset/explode.wav")
