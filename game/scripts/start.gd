extends "res://scripts/view.gd"
var begin: Button
var artwork: Texture2D = preload("res://assets/ui/title_art.png")
func _ready() -> void:
	setup("GHOST INSIDE", "2077 / EMOTION DEBUGGER / 意识访问请求")
	label_at("白色走廊", Vector2(75, 165), Vector2(700, 80), 60)
	label_at("CASE 001   /   林澈 · 22 岁", Vector2(80, 258), Vector2(740, 40), 24, CYAN)
	label_at("“请帮我找出，为什么我无法回答。”", Vector2(80, 326), Vector2(720, 58), 30)
	label_at("林远问：你当时怎么知道自己想当医生？\n林澈沉默了 7.4 秒。系统找不到属于他的声音。", Vector2(80, 394), Vector2(740, 92), 22, MUTED)
	label_at("他授权你进入六个意识空间，检查一条人生为什么无法说明归属。", Vector2(80, 492), Vector2(760, 36), 19, GOLD)
	portrait_at("林澈", Vector2(840, 96), Vector2(360, 520), Color(0.86, 0.93, 1.0))
	portrait_at("Ghost", Vector2(1045, 120), Vector2(200, 410), Color(0.55, 0.92, 1.0, 0.55))
	begin = button_at("授权进入  →", Vector2(80, 555), Vector2(360, 64), begin_case)
	begin.disabled = not GameState.load_error.is_empty()
	begin.grab_focus()
	if begin.disabled:
		label_at(GameState.load_error, Vector2(80, 520), Vector2(800, 60), 22, RED)
	label_at("六个空间：白色走廊 → 成长档案 → 封存工作室 → 未来验证 → 林远房间 → 自我手术", Vector2(485, 568), Vector2(710, 58), 18, MUTED)
	label_at("WASD / 方向键移动    E / Enter 调查    1/2/3 切频段    Space 提示    F2 重开", Vector2(80, 653), Vector2(1120, 40), 18, MUTED)
	queue_redraw()
func begin_case() -> void:
	if GameState.load_error.is_empty():
		GameState.current_scene_id = "scene01_white_corridor"
		goto_scene("scene01_white_corridor")
func _draw() -> void:
	draw_texture_rect(artwork, Rect2(0, 0, 1280, 720), false)
	draw_rect(Rect2(0, 0, 880, 720), Color(0.025, 0.06, 0.095, 0.95))
	draw_rect(Rect2(880, 0, 400, 720), Color(0.025, 0.06, 0.095, 0.48))
	draw_rect(Rect2(40, 537, 1200, 98), Color(0.04, 0.10, 0.15, 0.94))
	draw_line(Vector2(80, 135), Vector2(795, 135), CYAN, 2)
	draw_line(Vector2(880, 110), Vector2(880, 508), Color("355161"), 2)
