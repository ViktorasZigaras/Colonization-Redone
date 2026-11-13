extends Control

signal centered(cell: Vector2i)
var model
var camera: Control


func _ready() -> void:
	custom_minimum_size.y = 116
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	if model == null or model.dimensions == Vector2i.ZERO:
		return
	var scale_factor := minf(size.x / model.dimensions.x, size.y / model.dimensions.y)
	var offset := (size - Vector2(model.dimensions) * scale_factor) / 2
	for y in range(model.dimensions.y):
		for x in range(model.dimensions.x):
			var cell := Vector2i(x,y)
			var color := Color("#17303b")
			if not camera.fog or model.explored.has(cell):
				color = Color("#376e88") if model.water(cell) else Color("#8e9d5b")
			draw_rect(Rect2(offset+Vector2(cell)*scale_factor,Vector2.ONE*ceilf(scale_factor)),color)
	for t in model.towns:
		draw_circle(offset+(Vector2(t.cell)+Vector2(0.5,0.5))*scale_factor,2.5,Color("#ffbb78"))
	for site in model.indigenous.settlements:
		if not camera.fog or model.explored.has(site.cell):
			draw_circle(offset+(Vector2(site.cell)+Vector2(0.5,0.5))*scale_factor,1.5,Color("#91ceb1"))
	var row: float = model.Hex.ROW
	var viewport: Vector2 = Vector2(camera.size.x,camera.size.y/row) / camera.zoom * scale_factor
	draw_rect(Rect2(offset+Vector2(camera.center.x,camera.center.y/row)*scale_factor-viewport/2,viewport),Color("#f5db9b"),false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var scale_factor := minf(size.x / model.dimensions.x, size.y / model.dimensions.y)
		var offset := (size - Vector2(model.dimensions) * scale_factor) / 2
		var cell := Vector2i(((event.position-offset)/scale_factor).floor())
		if model.contains(cell):
			centered.emit(cell)
			accept_event()

