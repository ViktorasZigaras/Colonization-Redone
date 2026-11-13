extends PanelContainer

const FRAME = preload("res://colony_surfaces.gd")

func _ready() -> void:
	add_theme_stylebox_override("panel",FRAME.wood(8,Color("#74624a")))
	resized.connect(queue_redraw)

func _draw() -> void:
	var bounds := Rect2(Vector2(8,8),size-Vector2(16,16))
	if bounds.size.x < 1 or bounds.size.y < 1:
		return
	draw_rect(bounds,Color("#293d31"))
	for i in range(600):
		var at := bounds.position+Vector2(posmod(i*119,601)/601.0,posmod(i*223,607)/607.0)*bounds.size
		var ring := ((at-bounds.get_center())/bounds.size).length()
		var pigment := Color("#a8995451") if ring>0.42 else Color("#788d5a3c")
		draw_rect(Rect2(at.floor(),Vector2(2+i%3,1)),pigment)
	draw_rect(bounds.grow(1),Color("#ad8653"),false,1)
