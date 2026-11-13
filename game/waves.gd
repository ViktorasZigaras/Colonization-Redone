extends Control

var map: Control
var cells: Array = []
var elapsed := 0.0
var phase := 0
var active := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.18:
		return
	elapsed -= 0.18
	phase = (phase+1)%24
	if active and is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	if map == null or map.zoom < 16:
		return
	for entry in cells:
		var kind: int = entry[2]
		var frame := (phase+int(entry[1]))%24
		if frame >= (10 if kind==2 else 15):
			continue
		var along: Vector2 = entry[3]
		var across := along.orthogonal()
		var pixel := maxf(1,roundf(map.zoom/31))
		var at: Vector2 = (entry[0]+along*(frame-6)*pixel*0.48).round()
		var tint := Color("#d7f2dd") if kind==1 else Color("#a6d8de")
		tint.a = sin(frame*PI/16)*0.78
		for mark in [Vector2(-4,0),Vector2(-3,-1),Vector2(-2,-1),Vector2(-1,-2),Vector2(0,-2),Vector2(1,-2),Vector2(2,-1),Vector2(3,-1)]:
			if kind==2 and mark.x < -1:
				continue
			var pos: Vector2 = (at+(along*mark.x+across*mark.y)*pixel).round()
			draw_rect(Rect2(pos,Vector2.ONE*pixel),tint)
