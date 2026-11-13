extends Control

signal worker_dropped(worker: int, cell: Vector2i)
signal picked(cell: Vector2i, alternate: bool)
signal inspected(cell: Vector2i)
signal redraw_requested
const Sets = preload("res://art_sets.gd")
const Campaign = preload("res://campaign.gd")
const GROUND = preload("res://art/terrain.png")
const TREES = preload("res://art/individual-trees.png")
const HILLS = preload("res://art/hills.png")
const MOUNTAINS = preload("res://art/mountains.png")
const SHIP = preload("res://art/caravel.png")
const ColonyArt = preload("res://colony_art.gd")
const Hex = preload("res://hex.gd")
const ART := [0,1,2,3,4,5,6,7,8,2,2,9,10]
var model: Campaign
var center := Vector2(31,16)
var zoom := 32.0
var fog := true
var grid := false
var seams := true
var hover := Campaign.NONE
var selected := Campaign.NONE
var area_center := Campaign.NONE
var focus_radius := false
var art: Array[Texture2D] = []
var edges := {}
var waves: Control
var show_yields := false
var locations := {}
var slides := {}
var work_town := -1
var deep_water: Texture2D

const OBJECTS := {
	"Town":preload("res://art/town.png"), "Village":preload("res://art/village.png"),
	"Person":preload("res://art/person.png"), "Fort":preload("res://art/fort.png"),
	"Wagon":preload("res://art/wagon.png"),
	"Caravel":preload("res://art/caravel.png"),"Merchantman":preload("res://art/merchantman.png"),
	"Galleon":preload("res://art/galleon.png"),"Privateer":preload("res://art/privateer.png"),"Frigate":preload("res://art/frigate.png"),
	"Food":preload("res://art/Food.png"),"Furs":preload("res://art/Furs.png"),"Lumber":preload("res://art/Lumber.png"),
	"Ore":preload("res://art/Ore.png"),"Silver":preload("res://art/Silver.png"),"Fish":preload("res://art/Fish.png"),
	"Cotton":preload("res://art/Cotton.png"),"Tobacco":preload("res://art/Tobacco.png"),"Sugar":preload("res://art/Sugar.png"),
	"Minerals":preload("res://art/Minerals.png"),"Oasis":preload("res://art/Oasis.png"),
}
const UVS := [Vector2(0.5,0),Vector2(1,0.25),Vector2(1,0.75),Vector2(0.5,1),Vector2(0,0.75),Vector2(0,0.25)]
const EDGE_NORMALS := [Vector2(1,0),Vector2(0.5,0.866),Vector2(-0.5,0.866),Vector2(-1,0),Vector2(-0.5,-0.866),Vector2(0.5,-0.866)]



func setup(state: Campaign) -> void:
	model = state
	clip_contents = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	model.changed.connect(update_positions)
	model.disembarked.connect(start_disembark)
	rebuild_ground()
	waves = preload("res://waves.gd").new()
	add_child(waves)
	waves.map = self



func rebuild_ground() -> void:
	art.clear()
	edges.clear()
	var ground := GROUND.get_image()
	var variant := Sets.mode("Terrain")
	var tones := ["#777858","#ac814d","#a28f5a","#938b50","#628049","#939150","#6c8261","#4c6650","#deded2","#8b795f","#756e64","#375d73","#375d73"]
	for kind in range(13):
		var image := ground.get_region(Rect2i(ART[kind]*32,0,32,32))
		image.convert(Image.FORMAT_RGBA8)
		if variant > 0:
			for y in range(32):
				for x in range(32):
					var wave := sin(x*TAU/32.0+sin(y*TAU/16.0))*0.10+cos(y*TAU/8.0+x*TAU/16.0)*0.05
					var grain := float(posmod(x*17+y*31+x*y,11)-5)*0.01
					var tone := Color(tones[kind])
					if variant==2:
						tone = tone.lerp(Color("#bd9e68"),0.24).darkened(0.10)
						wave = sin((y+0.7*sin(x*TAU/16.0))*TAU/8.0)*0.07
						grain = 0.055 if (x+2*y)%7==0 else -0.02
					var shade := snappedf(wave+grain,0.047)
					image.set_pixel(x,y,tone.lightened(maxf(0,shade)) if shade>=0 else tone.darkened(-shade))
		art.append(ImageTexture.create_from_image(image))
		for side in range(6):
			var overlay := Image.create_empty(32,32,false,Image.FORMAT_RGBA8)
			for y in range(32):
				for x in range(32):
					var point := Vector2((x+0.5)/32.0-0.5,((y+0.5)/32.0-0.5)*2.0/sqrt(3.0))
					var depth := 0.5 - point.dot(EDGE_NORMALS[side])
					var threshold := clampf((0.16-depth)/0.16,0,1)
					if float(posmod(x*23+y*47+x*y*3,37))/37.0 < threshold:
						overlay.set_pixel(x,y,image.get_pixel(x,y))
			edges[Vector2i(kind,side)] = ImageTexture.create_from_image(overlay)
	deep_water = water_art()
	queue_redraw()


static func object_art(key: String) -> Texture2D:
	var group := "Ships" if key in Campaign.SHIPS else ("Scenery" if key in ["Town","Village","Fort","Wagon","Oasis","Minerals"] else "Goods")
	return Sets.pick(group,key,OBJECTS.get(key))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			center = (center-event.relative/zoom).clamp(Vector2.ZERO,Vector2(model.dimensions))
		hover = Hex.pick(center+(event.position-size/2)/zoom)
		inspected.emit(hover)
		queue_redraw()
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: zoom = minf(64,zoom*1.25)
			MOUSE_BUTTON_WHEEL_DOWN: zoom = maxf(8,zoom/1.25)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				var cell := Hex.pick(center+(event.position-size/2)/zoom)
				if model.contains(cell):
					picked.emit(cell,event.button_index == MOUSE_BUTTON_RIGHT)
		queue_redraw()


func box(cell: Vector2i) -> Rect2:
	var middle := size/2+(Hex.position(cell)-center)*zoom
	return Rect2(middle-Vector2.ONE*zoom/2,Vector2.ONE*zoom)


func shape(cell: Vector2i) -> PackedVector2Array:
	var middle := box(cell).get_center()
	var h := zoom/sqrt(3.0)
	return PackedVector2Array([
		middle+Vector2(0,-h),middle+Vector2(zoom/2,-h/2),
		middle+Vector2(zoom/2,h/2),middle+Vector2(0,h),
		middle+Vector2(-zoom/2,h/2),middle+Vector2(-zoom/2,-h/2),
	])


func outline(cell: Vector2i, color: Color, width := 1.0) -> void:
	var points := shape(cell)
	points.append(points[0])
	draw_polyline(points,color,width)


func water_art() -> Texture2D:
	var image := Image.create_empty(96,96,false,Image.FORMAT_RGBA8)
	var dark := Color("#3598b9")
	var light := Color("#86cad5")
	if Sets.mode("Terrain") > 0:
		dark = Color("#286c80") if Sets.mode("Terrain")==1 else Color("#315b66")
		light = Color("#7fbaa9") if Sets.mode("Terrain")==1 else Color("#9bb7a0")
	for y in range(96):
		for x in range(96):
			var u := x*TAU/96
			var v := y*TAU/96
			var ripples := sin(v*5+sin(u*3)*0.83)+0.62*cos(u*4+v*3)
			var pools := 0.56+0.22*sin(u*2+v+sin(v*2))+ripples*0.065
			var dither := 0.04 if (x+y*3)%4==0 else 0.0
			image.set_pixel(x,y,dark.lerp(light,snappedf(pools+dither,0.125)))
	return ImageTexture.create_from_image(image)


func paint_tile(cell: Vector2i) -> void:
	var points := shape(cell)
	var kind := ground_kind(cell)
	var neighbors := Hex.neighbors(cell)
	var wet := model.water(cell)
	if wet:
		var uv := PackedVector2Array()
		var shade := PackedColorArray()
		var land_distance := 3
		if model.water_beside_land(cell):
			land_distance = 1
		elif neighbors.any(func(tile): return model.contains(tile) and model.water_beside_land(tile)):
			land_distance = 2
		var deep := Color("#4d87ac")
		for i in range(points.size()):
			uv.append((points[i]-size/2)/zoom/3+center/3)
			var brightness: float = [0.0,0.46,0.12,0.0][land_distance]
			for side in [posmod(i-1,6),posmod(i-2,6)]:
				var next := neighbors[side]
				if not model.contains(next):
					continue
				if not model.water(next):
					brightness = 1.0
				elif model.water_beside_land(next):
					brightness = maxf(brightness,0.54)
			shade.append(deep.lerp(Color.WHITE,brightness))
		draw_polygon(points,shade,uv,deep_water)
	else:
		draw_polygon(points,PackedColorArray([Color.WHITE]),PackedVector2Array(UVS),art[kind])
		for side in range(6):
			var neighbor := neighbors[side]
			if seams and model.contains(neighbor) and not model.water(neighbor) and (not fog or model.explored.has(neighbor)):
				var other := ground_kind(neighbor)
				if other != kind:
					draw_polygon(points,PackedColorArray([Color.WHITE]),PackedVector2Array(UVS),edges[Vector2i(other,side)])


func paint_shore(cell: Vector2i) -> void:
	var points := shape(cell)
	for side in range(6):
		var neighbor: Vector2i = Hex.neighbors(cell)[side]
		if not model.contains(neighbor) or model.water(neighbor) or (fog and not model.explored.has(neighbor)):
			continue
		var a := points[(side+1)%6]
		var b := points[(side+2)%6]
		var inward := (box(cell).get_center()-(a+b)*0.5).normalized()
		var bank := PackedVector2Array()
		for i in range(9):
			var t := i/8.0
			bank.append(a.lerp(b,t)+inward*zoom*sin(t*PI)*(0.032+0.057*sin(t*PI*3+cell.x+cell.y+side)))
		draw_polyline(bank,Color("#507c69"),maxf(2,zoom*0.16),true)
		draw_polyline(bank,Color("#c0aa70"),maxf(2,zoom*0.105),true)
		draw_polyline(bank,Color("#e1cb91"),maxf(1,zoom*0.045))
		for i in [1,3,6,7]:
			var pixel := maxf(1,roundf(zoom/38))
			var speck := (bank[i]+inward*pixel*1.2).round()
			draw_rect(Rect2(speck,Vector2(pixel*2,pixel)),Color("#8bb3aa"))
		var along := (b-a).normalized()
		waves.cells.append([bank[4]+inward*zoom*0.11,cell.x*11+cell.y*17+side*3,1,along])
		if model.water_beside_land(cell) and posmod(cell.x*5+cell.y*3+side,4)==0:
			var pixel := maxf(1,roundf(zoom/29))
			for mark in range(4):
				var pool: Vector2 = bank[3+mark]+inward*(3+mark%2)*pixel
				draw_rect(Rect2(pool.round(),Vector2(pixel*2,pixel)),Color("#a6d3bc"))


func river(cell: Vector2i) -> void:
	if model.water(cell) or (model.raw(cell)&64)==0:
		return
	var origin := box(cell).get_center()
	var points := shape(cell)
	var arms: Array[PackedVector2Array] = []
	for side in range(6):
		var next := Hex.neighbors(cell)[side]
		if not model.contains(next) or (not model.water(next) and (model.raw(next)&64)==0):
			continue
		var tip := (points[(side+1)%6]+points[(side+2)%6])/2
		var along := (tip-origin).normalized()
		if model.water(next):
			tip += along*zoom*0.11
		var bend := along.orthogonal()*zoom*0.105*float(posmod(cell.x*11+cell.y*5+side,3)-1)
		arms.append(PackedVector2Array([origin,origin.lerp(tip,0.32)+bend*0.5,origin.lerp(tip,0.67)+bend,tip]))
	var width := zoom*(0.20 if model.raw(cell)&128 else 0.134)
	var channel := "#164864" if Sets.mode("Terrain")==0 else "#245663"
	var glint := "#387790" if Sets.mode("Terrain")==0 else "#508d87"
	for layer in [[1.6,"#344b34"],[1.24,"#a29a6d"],[1.0,channel],[0.66,glint]]:
		for arm in arms:
			draw_polyline(arm,Color(layer[1]),maxf(1,width*layer[0]),true)
		if not arms.is_empty():
			draw_circle(origin,width*layer[0]/2,Color(layer[1]),true,-1,true)
	for arm in arms:
		var flow := (arm[3]-arm[1]).normalized()
		draw_rect(Rect2((arm[1]-flow.orthogonal()*width*0.31).round(),Vector2(maxf(1,zoom/22),1)),Color("#86abb2"))
		waves.cells.append([arm[2],cell.x*13+cell.y*9+arms.find(arm)*5,2,flow])


func ground_kind(cell: Vector2i) -> int:
	var kind := model.kind(cell)
	if kind == 12:
		return 11
	return kind


func person_art(person: Dictionary) -> Texture2D:
	if Sets.mode("People") == 0:
		return OBJECTS.Person
	var role: String = person.get("role","")
	if role in ["Soldier","Dragoon","Artillery","Damaged Artillery"]:
		var key := "Artillery" if role.ends_with("Artillery") else role
		return Sets.pick("People",key,OBJECTS.Person)
	return ColonyArt.resident(person.skill,person.get("class","Free Colonist"))


func draw_object(texture: Texture2D, cell: Vector2i, scale_factor: float, offset := Vector2.ZERO, tint := Color.WHITE) -> void:
	var dimensions := Vector2(texture.get_size())
	var extent := dimensions / maxf(dimensions.x,dimensions.y) * zoom * scale_factor
	draw_texture_rect(texture,Rect2(box(cell).get_center()+offset*zoom-extent/2,extent),false,tint)


func scenery(cell: Vector2i) -> void:
	var kind := model.kind(cell)
	var overlay: Texture2D = null
	if kind in [9,10]:
		overlay = HILLS if kind == 9 else MOUNTAINS
	if overlay and Sets.mode("Scenery") > 0:
		draw_object(Sets.pick("Scenery","Hill" if kind==9 else "Mountain",overlay),cell,1.18,Vector2(0,-0.19))
	elif overlay:
		draw_texture_rect_region(overlay,Rect2(box(cell).get_center()+Vector2(-0.51,-0.76)*zoom,Vector2(1.02,1.02)*zoom),Rect2(0,0,32,32))
	for improvement in model.improvements.get(cell,[]):
		var middle := box(cell).get_center()
		if improvement == "Road":
			for next in Hex.neighbors(cell):
				if "Road" in model.improvements.get(next,[]):
					draw_line(middle,middle.lerp(box(next).get_center(),0.5),Color("#bd9a64"),maxf(2,zoom/9))
			draw_circle(middle,zoom*0.09,Color("#bd9a64"))
		else:
			for line in range(4):
				var offset := Vector2(0,(line-1.5)*0.12)*zoom
				draw_line(middle+offset-Vector2(zoom*0.39,0),middle+offset+Vector2(zoom*0.39,0),Color("#b99553"),maxf(1,zoom/14))


func gather_trees(cell: Vector2i, trees: Array) -> void:
	if not model.forest(cell):
		return
	var origin := box(cell).get_center()
	var river_tile := (model.raw(cell)&64)!=0
	var neighbors := Hex.neighbors(cell)
	for i in range(6):
		var next: Vector2i = neighbors[i]
		var joined := model.contains(next) and model.forest(next) and (not fog or model.explored.has(next))
		if river_tile and (model.water(next) or (model.raw(next)&64)!=0):
			continue
		var jitter := float(posmod(cell.x*19+cell.y*7+i*13,11)-5)*0.019
		var delta := (Hex.position(next)-Hex.position(cell))*(0.48 if joined else 0.26)
		var drift := Vector2(sin(cell.x*0.89+cell.y*0.51),cos(cell.x*0.55-cell.y*0.73))*0.13
		if not joined and not river_tile and i%2==0 and sin(cell.x*1.34+cell.y*1.13)>0.42:
			continue
		var at := origin+(delta+drift+Vector2(jitter,jitter*0.67))*zoom
		trees.append([at,posmod(cell.x*11+cell.y*7+i,3),(0.68 if joined else 0.57)+float(posmod(cell.x*3+cell.y*5+i,4))*0.045])


func resource_art(cell: Vector2i) -> Texture2D:
	var info := model.tile_resource(cell)
	if info.is_empty():
		return null
	var key: String = info.bonuses.keys()[0]
	match info.name:
		"Fishery": key = "Fish"
		"Oasis": key = "Oasis"
		"Mineral Deposit": key = "Minerals"
	return object_art(key)


func _draw() -> void:
	if model == null:
		return
	redraw_requested.emit()
	var first := Vector2i((Vector2(center.x,center.y/Hex.ROW)-Vector2(size.x,size.y/Hex.ROW)/(2*zoom)-Vector2.ONE).floor()).max(Vector2i.ZERO)
	var last := Vector2i((Vector2(center.x,center.y/Hex.ROW)+Vector2(size.x,size.y/Hex.ROW)/(2*zoom)+Vector2.ONE).ceil()).min(model.dimensions)
	var objects := {}
	var trees := []
	var names := {}
	for site in model.indigenous.settlements:
		names[site.cell] = [site.name,2]
		objects[site.cell] = [object_art("Village"),0.92,Color.WHITE]
	for rival in model.rivals.settlements:
		names[rival.cell] = [rival.name,1]
		objects[rival.cell] = [object_art("Town"),0.92,Color(model.RivalAI.COLORS[rival.nation]).lerp(Color.WHITE,0.55)]
	for town in model.towns:
		names[town.cell] = [town.name,0]
		objects[town.cell] = [object_art("Fort") if model.colony_defense(town)>0 else object_art("Town"),0.95,Color.WHITE]
	var units := {}
	for id in range(model.people.size()):
		var person := model.people[id]
		if person.location == "land":
			add_unit(units,person.cell,person_art(person),Color.WHITE,Vector2i(1,id))
	for faction in model.rivals.factions:
		add_unit(units,faction.ship,object_art("Caravel"),Color(model.RivalAI.COLORS[faction.nation]).lerp(Color.WHITE,0.42))
	for id in range(model.ships.size()):
		var ship := model.ships[id]
		if ship.port == "America":
			add_unit(units,ship.cell,object_art(ship.type),Color.WHITE,Vector2i(0,id))
	for faction in model.rivals.factions:
		var freight: Dictionary = faction.get("freight",{})
		if freight.get("phase","") == "America":
			add_unit(units,freight.cell,object_art("Merchantman"),Color(model.RivalAI.COLORS[faction.nation]).lerp(Color.WHITE,0.42))
	for wagon in model.wagons:
		var from: Vector2i = model.towns[wagon.first].cell
		var to: Vector2i = model.towns[wagon.second].cell
		if wagon.returning:
			var swap := from
			from = to
			to = swap
		var progress := 1.0-float(wagon.remaining)/maxi(1,wagon.duration)
		var cell: Vector2i = Hex.pick(Hex.position(from).lerp(Hex.position(to),progress))
		if model.water(cell):
			cell = from
		add_unit(units,cell,object_art("Wagon"),Color.WHITE)
	waves.cells.clear()
	waves.active = is_visible_in_tree()
	for y in range(first.y,last.y):
		for x in range(first.x,last.x):
			var cell := Vector2i(x,y)
			if focus_radius and not model.in_radius(cell,area_center):
				continue
			if fog and not model.explored.has(cell):
				draw_colored_polygon(shape(cell),Color("#122932"))
			else:
				paint_tile(cell)
				if model.water(cell) and not units.has(cell) and posmod(x*17+y*13,3)==0:
					waves.cells.append([box(cell).get_center(),x*11+y*17,0,Vector2.RIGHT])
			if grid:
				outline(cell,Color("#17232055"))
	for y in range(first.y,last.y):
		for x in range(first.x,last.x):
			var cell := Vector2i(x,y)
			if (focus_radius and not model.in_radius(cell,area_center)) or (fog and not model.explored.has(cell)):
				continue
			if model.water(cell):
				paint_shore(cell)
	for y in range(first.y,last.y):
		for x in range(first.x,last.x):
			var cell := Vector2i(x,y)
			if (focus_radius and not model.in_radius(cell,area_center)) or (fog and not model.explored.has(cell)):
				continue
			river(cell)
	for y in range(first.y,last.y):
		for x in range(first.x,last.x):
			var cell := Vector2i(x,y)
			if focus_radius and not model.in_radius(cell,area_center):
				continue
			if fog and not model.explored.has(cell):
				continue
			scenery(cell)
			gather_trees(cell,trees)
	trees.sort_custom(func(a,b): return a[0].y < b[0].y)
	for tree in trees:
		var extent := zoom*float(tree[2])*(1.0 if Sets.mode("Scenery")==0 else 0.86)
		var at: Vector2 = tree[0]
		var bounds := Rect2(at-Vector2(extent*0.48,extent*0.83),Vector2.ONE*extent)
		if Sets.mode("Scenery") == 0:
			draw_texture_rect_region(TREES,bounds,Rect2(tree[1]*40,0,40,40))
		else:
			draw_texture_rect(Sets.pick("Scenery","Tree%d" % tree[1],TREES),bounds,false)
	for y in range(first.y,last.y):
		for x in range(first.x,last.x):
			var cell := Vector2i(x,y)
			if (focus_radius and not model.in_radius(cell,area_center)) or (fog and not model.explored.has(cell)):
				continue
			var sprite := resource_art(cell)
			if sprite:
				draw_object(sprite,cell,0.67,Vector2(-0.12,0.1) if objects.has(cell) else Vector2.ZERO)
			if objects.has(cell):
				var item: Array = objects[cell]
				draw_object(item[0],cell,item[1],Vector2(0,-0.1),item[2])
			if units.has(cell):
				var list: Array = units[cell]
				for i in range(list.size()):
					var offset := Vector2((i-(list.size()-1)*0.5)*0.18,0.13)
					draw_object(list[i][0],cell,0.88 if list.size()==1 else 0.64,offset+slide_offset(list[i][2],cell),list[i][1])
	if zoom >= 23 and not focus_radius:
		var labels := names.keys()
		labels.sort_custom(func(a,b): return names[a][1] < names[b][1])
		var occupied: Array[Rect2] = []
		for cell in labels:
			if cell.x < first.x or cell.x >= last.x or cell.y < first.y or cell.y >= last.y or (fog and not model.explored.has(cell)):
				continue
			var font := ThemeDB.fallback_font
			var label: String = names[cell][0]
			var width := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
			for offset in [Vector2(0,0.52),Vector2(0,-0.76),Vector2(0,0.98),Vector2(0,-1.18)]:
				var at: Vector2 = box(cell).get_center()+offset*zoom-Vector2(width*0.5,0)
				var bounds := Rect2(at-Vector2(4,12),Vector2(width+8,16))
				if not Rect2(Vector2.ZERO,size).encloses(bounds) or occupied.any(func(other): return other.intersects(bounds)):
					continue
				occupied.append(bounds)
				draw_rect(bounds,Color("#24251deb"))
				draw_string(font,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#fff0c5"))
				break
	if (show_yields or focus_radius) and zoom >= 22:
		var working := {}
		if focus_radius and work_town >= 0:
			for id in model.residents(work_town):
				var resident := model.people[id]
				if resident.field != Campaign.NONE:
					working[resident.field] = resident
		for y in range(first.y,last.y):
			for x in range(first.x,last.x):
				var cell := Vector2i(x,y)
				if (focus_radius and not model.in_radius(cell,area_center)) or (fog and not model.explored.has(cell)):
					continue
				var at := box(cell).get_center()
				if working.has(cell):
					var worker: Dictionary = working[cell]
					draw_object(ColonyArt.resident(worker.skill,worker.get("class","Free Colonist")),cell,0.43,Vector2(0,-0.19))
					if not show_yields:
						paint_yield(at+Vector2(0,zoom*0.33),worker.job,model.yield_at(cell,worker.job)+Campaign.Catalog.bonus(worker.skill,worker.job))
				if show_yields:
					paint_tile_yields(at,cell)

	if model.contains(area_center):
		for tile in model.work_area(area_center):
			if not fog or model.explored.has(tile):
				outline(tile,Color("#f1cc8077"))
	for cell in [selected,hover]:
		if model.contains(cell):
			outline(cell,Color("#e8b668"),2)
	waves.queue_redraw()


func add_unit(units: Dictionary, cell: Vector2i, texture: Texture2D, tint: Color, key := Campaign.NONE) -> void:
	if not units.has(cell):
		units[cell] = []
	units[cell].append([texture,tint,key])

func paint_yield(at: Vector2, good: String, amount: int) -> void:
	if amount <= 0:
		return
	var sprite := ColonyArt.goods("Fish" if good=="Fishing" else good)
	var count := mini(6,amount)
	var step := clampf(zoom*0.115,4,10)
	for i in range(count):
		draw_texture_rect(sprite,Rect2(at+Vector2((i-(count-1)*0.5)*step-step*0.85,-step),Vector2.ONE*step*1.7),false)
	if amount > count:
		draw_string(ThemeDB.fallback_font,at+Vector2(count*step/2,4),"+%d" % (amount-count),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#fff3c6"))


func paint_tile_yields(at: Vector2, cell: Vector2i) -> void:
	var goods := ["Fishing"] if model.water(cell) else Campaign.GOODS.slice(0,8)
	var yields := []
	for good in goods:
		var amount := model.yield_at(cell,good)
		if amount > 0:
			yields.append([good,amount])
	var step := clampf(zoom*0.39,11,23)
	for i in range(yields.size()):
		var row := i/2
		var cols := mini(2,yields.size()-row*2)
		var point := at+Vector2((i%2-(cols-1)*0.5)*step,zoom*0.06+(row-(yields.size()-1)/4.0)*step*0.59)
		var icon := ColonyArt.goods("Fish" if yields[i][0]=="Fishing" else yields[i][0])
		var extent := Vector2(step,step*0.61)
		draw_rect(Rect2(point-extent/2,extent),Color("#20251bd9"))
		draw_texture_rect(icon,Rect2(point-Vector2(step*0.48,extent.y/2),Vector2(step*0.53,extent.y)),false)
		var font_size := clampi(roundi(step*0.62),8,13)
		draw_string(ThemeDB.fallback_font,point+Vector2(step*0.03,font_size*0.35),str(yields[i][1]),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("#fff1c3"))


func start_disembark(person: int, from: Vector2i, to: Vector2i) -> void:
	var key := Vector2i(1,person)
	locations[key] = to
	slides[key] = [Hex.position(from),0.0,0.42]
	queue_redraw()


func update_positions() -> void:
	for kind in range(2):
		var items := model.ships if kind == 0 else model.people
		for id in range(items.size()):
			var unit := items[id]
			var key := Vector2i(kind,id)
			var present: bool = unit.port == "America" if kind == 0 else unit.location == "land"
			if not present:
				locations.erase(key)
				slides.erase(key)
				continue
			if locations.has(key) and locations[key] != unit.cell and model.Hex.distance(locations[key],unit.cell)<=6:
				var from: Vector2i = locations[key]
				slides[key] = [model.Hex.position(from),0.0,0.22+0.13*model.Hex.distance(from,unit.cell)]
			locations[key] = unit.cell
	queue_redraw()


func _process(delta: float) -> void:
	if slides.is_empty():
		return
	for key in slides.keys():
		slides[key][1] += delta
		if slides[key][1]>=slides[key][2]:
			slides.erase(key)
	if is_visible_in_tree():
		queue_redraw()


func slide_offset(key: Vector2i, cell: Vector2i) -> Vector2:
	if not slides.has(key):
		return Vector2.ZERO
	var slide: Array = slides[key]
	return (slide[0]-Hex.position(cell))*(1.0-smoothstep(0.0,slide[2],slide[1]))


func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if not focus_radius or not data is Dictionary or not data.has("worker"):
		return false
	var cell := Hex.pick(center+(at-size/2)/zoom)
	return model.contains(cell) and cell != area_center and model.in_radius(cell,area_center)


func _drop_data(at: Vector2, data: Variant) -> void:
	worker_dropped.emit(data.worker,Hex.pick(center+(at-size/2)/zoom))



