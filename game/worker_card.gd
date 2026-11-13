extends Button
var worker_id := -1

func _get_drag_data(_at: Vector2) -> Variant:
	var preview := TextureRect.new()
	preview.texture = icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = Vector2(48,60)
	set_drag_preview(preview)
	return {"worker":worker_id}
