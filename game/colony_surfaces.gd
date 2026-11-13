extends RefCounted

static func wood(margin: int, tint: Color) -> StyleBoxTexture:
	var frame := StyleBoxTexture.new()
	frame.texture = preload("res://art_sets.gd").pick("Surfaces","Wood",preload("res://art/wood.png"))
	frame.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	frame.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	frame.modulate_color = tint
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		frame.set_content_margin(side,margin)
	return frame
