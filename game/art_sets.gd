extends RefCounted

const MODES := ["Current", "Remake", "Re-remake"]
const CATEGORIES := ["Terrain","People","Buildings","Ships","Scenery","Goods","Surfaces"]
static var modes := {}
static var textures := {}

static func mode(category: String) -> int:
	return modes.get(category,0)

static func pick(category: String, key: String, fallback: Texture2D) -> Texture2D:
	var variant := mode(category)
	if variant == 0:
		return fallback
	var path := "res://art/remake/%s-%s.png" % [category.to_lower(),key]
	if not ResourceLoader.exists(path):
		return fallback
	var id := [path,variant]
	if not textures.has(id):
		var base := load(path) as Texture2D
		if variant == 1:
			textures[id] = base
		else:
			var pixels := base.get_image()
			pixels.convert(Image.FORMAT_RGBA8)
			for y in range(pixels.get_height()):
				for x in range(pixels.get_width()):
					var c := pixels.get_pixel(x,y)
					if c.a <= 0.0:
						continue
					var ramp := Color("#172937").lerp(Color("#f2d29e"),c.get_luminance())
					var ink := c.lerp(ramp,0.62)
					pixels.set_pixel(x,y,Color(snappedf(ink.r,0.045),snappedf(ink.g,0.045),snappedf(ink.b,0.045),c.a))
			textures[id] = ImageTexture.create_from_image(pixels)
	return textures[id]
