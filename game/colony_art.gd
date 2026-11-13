extends RefCounted

const Sets = preload("res://art_sets.gd")
const BUILDINGS = preload("res://art/buildings.png")
const ICONS = preload("res://art/colony-icons.png")
const GOODS := {"Food":22,"Sugar":23,"Tobacco":24,"Cotton":25,"Furs":26,"Lumber":27,"Ore":28,"Silver":29,"Horses":30,"Tools":36,"Muskets":32,"Rum":31,"Cloth":33,"Cigars":37,"Coats":34,"Fish":22,"Hammers":54}
const PROFESSIONS := {"Expert Farmer":81,"Expert Fisherman":89,"Expert Fur Trapper":85,"Expert Silver Miner":88,"Expert Lumberjack":86,"Expert Ore Miner":87,"Master Sugar Planter":90,"Master Cotton Planter":92,"Master Tobacco Planter":91,"Master Carpenter":94,"Master Distiller":98,"Master Weaver":99,"Master Tobacconist":100,"Master Fur Trader":101,"Master Blacksmith":96,"Master Gunsmith":93,"Firebrand Preacher":82,"Seasoned Scout":75,"Hardy Pioneer":97,"Veteran Soldier":102}
const CLASSES := {"Free Colonist":58,"Indentured Servant":106,"Petty Criminal":107}
# Indices follow @BUILDING in the DOS NAMES.TXT.
const STRUCTURES := {"Stockade":0,"Fort":1,"Fortress":2,"Armory":3,"Magazine":4,"Arsenal":5,"Dock":6,"Drydock":7,"Shipyard":8,"Schoolhouse":12,"College":13,"University":14,"Warehouse":15,"Warehouse Expansion":15,"Stables":16,"Weaver House":21,"Weaver Shop":22,"Textile Mill":23,"Tobacconist House":24,"Tobacconist Shop":25,"Cigar Factory":26,"Distiller House":27,"Rum Distillery":28,"Rum Factory":29,"Fur Trader House":32,"Fur Trading Post":33,"Fur Factory":34,"Carpenter Shop":35,"Lumber Mill":36,"Church":37,"Cathedral":38,"Blacksmith House":39,"Blacksmith Shop":40,"Iron Works":41}
const BUILDING_SIZES := [Vector2i(73,18),Vector2i(73,18),Vector2i(73,18),Vector2i(44,22),Vector2i(44,22),Vector2i(44,22),Vector2i(75,48),Vector2i(75,48),Vector2i(75,48),Vector2i(53,37),Vector2i.ONE,Vector2i.ONE,Vector2i(44,22),Vector2i(44,22),Vector2i(44,22),Vector2i(44,22),Vector2i(73,18),Vector2i.ONE]
static var cached := {}

static func region(atlas: Texture2D, index: int, stride: Vector2i, extent: Vector2i) -> Texture2D:
	var key := Vector2i(atlas.get_instance_id(),index)
	if not cached.has(key):
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(Vector2i(index%12,index/12)*stride,extent)
		texture.filter_clip = true
		cached[key] = texture
	return cached[key]

static func building(name: String) -> Texture2D:
	var index: int = STRUCTURES.get(name,35)
	var extent := Vector2i(23,27)
	if index < BUILDING_SIZES.size():
		extent = BUILDING_SIZES[index]
	elif index in [35,36,43,46,47]:
		extent = Vector2i(44,22)
	elif index in [37,38]:
		extent = Vector2i(53,37)
	return Sets.pick("Buildings",name,region(BUILDINGS,index,Vector2i(78,51),extent))

static func goods(name: String) -> Texture2D:
	return Sets.pick("Goods",name,region(ICONS,GOODS.get(name,22),Vector2i(24,19),Vector2i(13,12)))

static func resident(skill: String, social_class := "Free Colonist") -> Texture2D:
	return Sets.pick("People",skill if PROFESSIONS.has(skill) else social_class,region(ICONS,PROFESSIONS.get(skill,CLASSES.get(social_class,58)),Vector2i(24,19),Vector2i(14,16)))

