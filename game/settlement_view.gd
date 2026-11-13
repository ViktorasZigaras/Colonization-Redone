extends Control


const PARCHMENT = preload("res://art/parchment.png")
const Sets = preload("res://art_sets.gd")
const FOREST = preload("res://art/individual-trees.png")
const PLACES := [
	Vector2(.17,.22),Vector2(.54,.16),Vector2(.81,.29),Vector2(.25,.45),
	Vector2(.60,.40),Vector2(.20,.68),Vector2(.49,.72),Vector2(.80,.58),
	Vector2(.74,.83),Vector2(.31,.88),Vector2(.86,.10),Vector2(.10,.54)
]
const GROVES := [Vector2(.09,.28),Vector2(.26,.14),Vector2(.62,.10),Vector2(.92,.31),
	Vector2(.07,.63),Vector2(.12,.86),Vector2(.53,.91),Vector2(.89,.76),Vector2(.94,.87)]
const ROAD := [Vector2(.09,.43),Vector2(.25,.36),Vector2(.39,.32),Vector2(.54,.34),
	Vector2(.67,.47),Vector2(.74,.64),Vector2(.81,.71),Vector2(.95,.70)]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(place_buildings)
	child_entered_tree.connect(func(_child): place_buildings.call_deferred())

func place_buildings() -> void:
	for i in range(get_child_count()):
		var card := get_child(i) as Control
		var slot: Vector2 = PLACES[i%PLACES.size()]
		if i >= PLACES.size():
			slot += Vector2(.035,-.04)
		card.size = Vector2(96,78)
		card.position = (slot*size-card.size/2).clamp(Vector2.ZERO,(size-card.size).max(Vector2.ZERO))
	queue_redraw()

func _draw() -> void:
	if size.x < 2 or size.y < 2:
		return
	draw_texture_rect(PARCHMENT,Rect2(Vector2.ZERO,size),true,Color("#ddd1a7"))
	var lawn := PackedVector2Array()
	for uv in [Vector2(.02,.13),Vector2(.32,.04),Vector2(.67,.04),Vector2(.99,.2),
			Vector2(.98,.71),Vector2(.88,.96),Vector2(.36,.99),Vector2(.03,.84)]:
		lawn.append(uv*size)
	draw_colored_polygon(lawn,Color("#788c4c42"))
	for i in range(390):
		var uv := Vector2(float(posmod(i*127,397))/397,float(posmod(i*173,389))/389)
		var at := (uv*size).floor()
		var shade := Color("#77674330") if i%3 else Color("#f6e7b770")
		draw_rect(Rect2(at,Vector2(2+i%4,1)),shade)
	var path := PackedVector2Array()
	for point in ROAD:
		path.append(point*size)
	draw_polyline(path,Color("#8c755662"),16)
	draw_polyline(path,Color("#d8bd8c"),11)
	for i in range(get_child_count()):
		var foot: Vector2 = (get_child(i).position+Vector2(48,44))
		var end := path[0]
		for k in range(path.size()-1):
			var point := Geometry2D.get_closest_point_to_segment(foot,path[k],path[k+1])
			if point.distance_squared_to(foot)<end.distance_squared_to(foot):
				end = point
		draw_line(foot,end,Color("#a2835f80"),8)
		draw_line(foot,end,Color("#d8bd8c"),5)
	for i in range(GROVES.size()):
		for j in range(2+i%2):
			var at: Vector2 = GROVES[i]*size+Vector2(j*15-12,j*5)
			var bounds := Rect2(at-Vector2(21,30),Vector2(46,46))
			if Sets.mode("Scenery")==0:
				draw_texture_rect_region(FOREST,bounds,Rect2(40*((i+j)%3),0,40,40))
			else:
				draw_texture_rect(Sets.pick("Scenery","Tree%d" % ((i+j)%3),FOREST),bounds,false)

