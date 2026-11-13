extends RefCounted

signal changed
signal disembarked(person: int, from: Vector2i, to: Vector2i)

const Catalog = preload("res://catalog.gd")
const RivalAI = preload("res://rivals.gd")
var rivals := RivalAI.new()
var indigenous := preload("res://indigenous.gd").new()
var extraction := {}
var world_seed := 1492
const NONE := Vector2i(-1, -1)
const GOODS := ["Food","Sugar","Tobacco","Cotton","Furs","Lumber","Ore","Silver","Horses","Tools","Muskets","Rum","Cloth","Cigars","Coats"]
const NATIONS := ["France","England","Spain","Netherlands","Portugal"]
const TERRAIN := ["Tundra","Desert","Plains","Prairie","Grassland","Savannah","Marsh","Swamp","Arctic","Hills","Mountains","Ocean","Sea Lane"]
const OPEN := [[3,0,0,0,0,0,2,0],[2,0,1,1,0,0,2,0],[4,0,1,2,0,0,0,0],[4,0,2,3,0,0,0,0],[4,1,3,2,0,0,0,0],[4,3,2,3,0,0,0,0],[3,1,3,0,0,0,3,0],[3,3,1,0,0,0,0,0],[0,0,0,0,0,0,0,0],[2,0,0,0,0,0,4,0],[0,0,0,0,0,0,3,1],[3,0,0,0,0,0,0,0],[3,0,0,0,0,0,0,0]]
const WOODS := [[2,0,0,0,3,4,1,0],[2,0,0,1,2,2,1,0],[3,0,1,1,3,6,0,0],[3,0,1,1,2,4,0,0],[3,0,1,1,2,6,0,0],[3,1,1,1,2,4,0,0],[2,1,2,0,2,4,2,0],[2,2,0,0,0,4,0,0]]
const RECIPES := {"Hammers":"Lumber","Tools":"Ore","Muskets":"Tools","Rum":"Sugar","Cloth":"Cotton","Cigars":"Tobacco","Coats":"Furs"}
const SHIPS := {"Caravel":[4,2,300],"Merchantman":[5,4,600],"Galleon":[6,6,1000],"Privateer":[8,2,900],"Frigate":[6,4,1500]}
const BUILDINGS := {
	"Carpenter Shop":[39,0,1,""],"Tobacconist House":[52,0,3,""],"Distiller House":[52,0,3,""],"Fur Trader House":[52,0,3,""],
	"Warehouse":[80,0,1,""],"Warehouse Expansion":[80,20,1,"Warehouse"],
	"Dock":[52,0,1,""],"Drydock":[80,50,6,"Dock"],"Shipyard":[240,100,8,"Drydock"],
	"Lumber Mill":[52,0,3,"Carpenter Shop"],"Armory":[52,0,1,""],"Magazine":[120,50,8,"Armory"],
	"Blacksmith House":[52,0,3,""],"Weaver House":[52,0,3,""],"Blacksmith Shop":[64,20,4,"Blacksmith House"],"Weaver Shop":[64,20,4,"Weaver House"],"Tobacconist Shop":[64,20,4,"Tobacconist House"],
	"Rum Distillery":[64,20,4,"Distiller House"],"Fur Trading Post":[56,20,3,"Fur Trader House"],"Stables":[64,0,1,""],
	"Church":[52,0,3,""],"Cathedral":[176,100,8,"Church"],
	"Schoolhouse":[64,0,4,""],"College":[160,50,8,"Schoolhouse"],"University":[200,100,10,"College"],
	"Iron Works":[240,100,8,"Blacksmith Shop"],"Cigar Factory":[160,100,8,"Tobacconist Shop"],
	"Textile Mill":[160,100,8,"Weaver Shop"],"Rum Factory":[160,100,8,"Rum Distillery"],
	"Fur Factory":[160,100,6,"Fur Trading Post"],"Arsenal":[240,100,8,"Magazine"],
	"Stockade":[64,0,3,""],"Fort":[120,100,4,"Stockade"],"Fortress":[320,200,8,"Fort"]}
const WORKSHOP_UPGRADES := {"Hammers":"Lumber Mill","Tools":"Blacksmith Shop","Muskets":"Magazine","Rum":"Rum Distillery","Cloth":"Weaver Shop","Cigars":"Tobacconist Shop","Coats":"Fur Trading Post"}
const FACTORIES := {"Tools":"Iron Works","Cigars":"Cigar Factory","Cloth":"Textile Mill","Rum":"Rum Factory","Coats":"Fur Factory","Muskets":"Arsenal"}
const EQUIPMENT := {"Pioneer":"Tools","Scout":"Horses","Soldier":"Muskets","Dragoon":"Muskets"}
const PRICES := [2,3,3,3,5,3,3,8,4,5,6,8,8,8,8]
const Hex = preload("res://hex.gd")
var geography := {}
var local_yield_cache := {}

var dimensions := Vector2i.ZERO
var terrain := PackedByteArray()
var ships: Array[Dictionary] = []
var people: Array[Dictionary] = []
var towns: Array[Dictionary] = []
var explored := {}
var improvements := {}
var turn := 1
var year := 1492
var gold := 350
var tax := 10
var crosses := 0
var recruits := 2
var report := ""
var nation := "France"
var leader := "Test"
var target_year := 1800
var finished := false
var market := {}
var ledger: Array[Dictionary] = []
var market_notice := ""
var discoveries := 0
var discovered_sites := {}
var wagons: Array[Dictionary] = []


func start(bytes: PackedByteArray, options: Dictionary) -> bool:
	if bytes.size() < 6 or bytes.decode_u16(4) != 4:
		return false
	dimensions = Vector2i(bytes.decode_u16(0), bytes.decode_u16(2))
	if dimensions != Vector2i(58,72) or bytes.size() != 6 + dimensions.x * dimensions.y * 3:
		return false
	terrain = bytes.slice(6, 6 + dimensions.x * dimensions.y)
	ships.clear()
	people.clear()
	towns.clear()
	explored.clear()
	improvements.clear()
	market.clear()
	ledger.clear()
	market_notice = ""
	discoveries = 0
	discovered_sites.clear()
	wagons.clear()
	extraction.clear()
	world_seed = options.get("seed",1492)
	turn = 1
	year = options.get("year", 1492)
	gold = options.get("gold", 350)
	nation = options.get("nation", "France")
	leader = options.get("leader", "Test")
	tax = maxi(0, int(options.get("tax", 10)) - (2 if nation == "Spain" else 0))
	target_year = options.get("target", 1800)
	crosses = 0
	recruits = 3 if nation == "England" else 2
	finished = false
	if options.get("random", false):
		generate_map(options.get("seed", 1), options)
	var start_cell := Vector2i(33,16)
	if nation == "Portugal":
		var coast := brazil_coast()
		if coast != NONE:
			start_cell = water_beside(coast)
	while contains(start_cell) and not water(start_cell):
		start_cell.x += 1
	if not contains(start_cell):
		start_cell = Vector2i(dimensions.x-2,16)
	if not contains(start_cell) or not water(start_cell):
		return false
	add_ship("Merchantman" if nation == "Netherlands" else "Caravel", start_cell, "America")
	for name in ["Colonist 1", "Colonist 2"]:
		add_person(name, "ship", 0)
	reveal(start_cell)
	classify_geography()
	rivals.settlements.clear()
	indigenous.start(self, options.get("random",false))
	rivals.start(self)
	return note("Sail west and select adjacent land to disembark a colonist.")


func generate_map(seed_value: int, options: Dictionary) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = [0.115, 0.085, 0.06][clampi(options.get("form", 1), 0, 2)]
	var mass := clampi(options.get("mass", 1), 0, 2)
	var climate := clampi(options.get("climate", 1), 0, 2)
	var temperature := clampi(options.get("temperature", 1), 0, 2)
	for y in range(dimensions.y):
		for x in range(dimensions.x):
			var cell := Vector2i(x,y)
			var n := noise.get_noise_2d(x,y)
			var edge := float(x) / dimensions.x
			var tile := 25
			if x >= dimensions.x - 5 or x < 2:
				tile = 26
			elif n + 0.24 - absf(edge - 0.40) * 1.55 > 0.13 - mass * 0.08:
				var latitude := absi(y - dimensions.y / 2) + (1-temperature)*5
				tile = 0 if latitude > 28 else (2 if latitude > 15 else (5 if climate != 0 else 1))
				if climate == 2 and n < 0.18:
					tile = 6
				if n > 0.50:
					tile |= 0x20
				elif n > 0.23 - climate * 0.04:
					tile += 8
			if y == 0 or y == dimensions.y - 1:
				tile = 24
			terrain[index(cell)] = tile
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for river_id in range(15+climate*8+mass*3):
		var source := Vector2i(rng.randi_range(4,dimensions.x-7),rng.randi_range(3,dimensions.y-4))
		if water(source) or kind(source) == 8:
			continue
		var path: Array[Vector2i] = [source]
		var cell := source
		for step in range(16):
			if water(cell):
				for river_cell in path:
					terrain[index(river_cell)] |= 64
				break
			var best := NONE
			var best_score := INF
			for next in Hex.neighbors(cell):
				if not contains(next) or next in path or kind(next)==8:
					continue
				var score_value := -10.0 if water(next) else noise.get_noise_2d(next.x,next.y)
				if score_value < best_score:
					best_score = score_value
					best = next
			if best == NONE:
				break
			cell = best
			if not water(cell):
				path.append(cell)


func note(text: String, success := true) -> bool:
	report = text
	changed.emit()
	return success


func contains(cell: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, dimensions).has_point(cell)


func index(cell: Vector2i) -> int:
	return cell.y * dimensions.x + cell.x


func raw(cell: Vector2i) -> int:
	return terrain[index(cell)] if contains(cell) else 25


func water(cell: Vector2i) -> bool:
	return (raw(cell) & 0x3f) in [25,26]


func forest(cell: Vector2i) -> bool:
	return (raw(cell) & 0x20) == 0 and (raw(cell) & 31) in range(8,24)


func kind(cell: Vector2i) -> int:
	var value := raw(cell)
	if value & 32:
		return 10 if value & 128 else 9
	var id := value & 31
	return id & 7 if id < 24 else [8,11,12,10,9][mini(id - 24,4)]


func tile_name(cell: Vector2i) -> String:
	return ("Forested " if forest(cell) else "") + TERRAIN[kind(cell)]


func nearby(a: Vector2i, b: Vector2i) -> bool:
	return Hex.distance(a,b) <= 1


func reveal(cell: Vector2i) -> void:
	for here in work_area(cell):
		explored[here] = true


func add_ship(type: String, cell: Vector2i, port: String) -> int:
	ships.append({"type":type,"cell":cell,"port":port,"moves":SHIPS[type][0],"cargo":{},"trip":0,"destination":"","damage":0,"route":[],"leg":0,"route_on":false})
	return ships.size() - 1


func add_person(name: String, location: String, holder: int, skill := "") -> int:
	people.append({"name":name,"location":location,"holder":holder,"cell":NONE,"moves":1,"job":"","field":NONE,"skill":Catalog.profession(skill),"class":"Free Colonist","training":"","study":0,"role":"","order":"","work":0})
	return people.size() - 1


func residents(town: int) -> Array[int]:
	var ids: Array[int] = []
	for id in range(people.size()):
		if people[id].location == "town" and people[id].holder == town:
			ids.append(id)
	return ids


func passengers(ship: int) -> Array[int]:
	var ids: Array[int] = []
	for id in range(people.size()):
		if people[id].location == "ship" and people[id].holder == ship:
			ids.append(id)
	return ids


func held(goods: Dictionary, good: String) -> int:
	return goods.get(good,0)


func adjust(goods: Dictionary, good: String, amount: int) -> void:
	goods[good] = held(goods,good) + amount


func distance_step(from: Vector2i, to: Vector2i, sea: bool, budget: int) -> int:
	var frontier: Array[Vector2i] = [from]
	var costs := {from: 0}
	var cursor := 0
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		if costs[cell] >= budget or costs[cell] >= costs.get(to,2147483647):
			continue
		for next in Hex.neighbors(cell):
			if not contains(next) or water(next) != sea:
				continue
			var step := 1 if sea else land_cost(next)
			if cell == from and budget > 0 and not sea:
				step = mini(step, budget)
			var cost: int = costs[cell] + step
			if cost <= budget and cost < costs.get(next, 2147483647):
				costs[next] = cost
				frontier.append(next)
	return costs.get(to, -1)


func land_cost(cell: Vector2i) -> int:
	if "Road" in improvements.get(cell, []) or feature(cell) == "Mountain pass":
		return 1
	var type := kind(cell)
	if forest(cell):
		return [2,1,2,2,2,2,3,3][type]
	return [1,1,1,1,1,1,2,2,2,2,3,1,1][type]


func sail(id: int, cell: Vector2i) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var ship := ships[id]
	if ship.port != "America" or not contains(cell) or not water(cell):
		return note("Choose water in America.", false)
	var cost := sailing_cost(ship,cell)
	if cost < 0:
		return note("Destination is out of range or blocked by shoals.",false)
	ship.cell = cell
	ship.moves -= cost
	reveal(cell)
	return note("Ship moved.")


func land(ship: int, person: int, cell: Vector2i) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var s := ships[ship]
	if s.port != "America" or not contains(cell) or water(cell) or not nearby(s.cell,cell) or person not in passengers(ship):
		return note("Select an aboard colonist and adjacent land.",false)
	var p := people[person]
	p.location = "land"
	p.holder = -1
	p.cell = cell
	reveal(cell)
	disembarked.emit(person,s.cell,cell)
	return note("%s disembarked." % p.name)


func walk(id: int, cell: Vector2i) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var p := people[id]
	if p.location != "land" or p.order != "" or not contains(cell) or water(cell):
		return note("Activate a colonist and choose land.",false)
	var cost := distance_step(p.cell,cell,false,p.moves)
	if cost < 0:
		return note("Destination is beyond the colonist's movement.",false)
	p.cell = cell
	p.moves -= cost
	reveal(cell)
	if site_available(cell):
		return note("Colonist moved. This tile has an uncharted site.")
	return note("Colonist moved.")


func found(id: int, title: String) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var p := people[id]
	if p.location != "land" or p.role in ["Artillery","Damaged Artillery"] or kind(p.cell) in [8,10,11,12]:
		return note("Choose a suitable land tile.",false)
	for town in towns+rivals.settlements:
		if nearby(town.cell,p.cell):
			return note("Leave at least one tile between settlements.",false)
	var name := title.strip_edges()
	if name.is_empty():
		name = RivalAI.NAMES[nation][towns.size()] if RivalAI.NAMES.has(nation) and towns.size() < RivalAI.NAMES[nation].size() else "Colony %d" % (towns.size()+1)
	var site: Vector2i = p.cell
	if indigenous.site_at(site):
		return note("This site is already settled.", false)
	towns.append({"name":name,"cell":site,"goods":{"Food":18 if nation == "France" else 12},"buildings":Catalog.STARTERS.duplicate(),"project":"","hammers":0})
	join_town(id,towns.size()-1)
	indigenous.encroach(site,18)
	return note("%s founded." % name)


func join_town(person: int, town: int) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var p := people[person]
	if p.location != "land" or p.role in ["Artillery","Damaged Artillery"] or p.cell != towns[town].cell:
		return note("Move the colonist to the settlement first.",false)
	p.location = "town"
	p.holder = town
	p.job = ""
	p.field = NONE
	p.order = ""
	return note("%s joined %s." % [p.name,towns[town].name])


func leave_town(id: int) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var p := people[id]
	if p.location != "town" or residents(p.holder).size() < 2 or p.job == "Teach":
		return note("A settlement needs one resident.",false)
	p.cell = towns[p.holder].cell
	p.location = "land"
	p.holder = -1
	p.job = ""
	p.field = NONE
	release_teacher(p)
	p.training = ""
	p.study = 0
	return note("%s left the settlement." % p.name)


func board(id: int, ship: int) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var p := people[id]
	var s := ships[ship]
	if p.location != "land" or s.port != "America" or not nearby(s.cell,p.cell) or free_holds(ship) < 1:
		return note("Bring a land colonist next to a ship with a free hold.",false)
	p.location = "ship"
	p.holder = ship
	p.order = ""
	return note("%s boarded." % p.name)


func yield_at(cell: Vector2i, good: String) -> int:
	var id := GOODS.find("Food" if good == "Fishing" else good)
	if id < 0 or id >= 8 or not contains(cell) or (good == "Fishing" and not water(cell)):
		return 0
	var base := kind(cell)
	var amount: int = WOODS[base][id] if forest(cell) else OPEN[base][id]
	if water(cell) and id == 0:
		var land_edges := 0
		for neighbor in Hex.neighbors(cell):
			land_edges += int(contains(neighbor) and not water(neighbor))
		amount += land_edges/2
	if id == 0 and feature(cell) == "Floodplain":
		amount += 1
	if amount > 0 and not water(cell):
		if raw(cell) & 64:
			amount += 1
		if "Plow" in improvements.get(cell,[]) and id <= 3:
			amount += 1
		if "Road" in improvements.get(cell,[]) and id >= 4:
			amount += 1
	var bonus := tile_resource(cell)
	amount += bonus.get("bonuses",{}).get("Food" if good == "Fishing" else good,0)
	return amount


func assign(id: int, job: String, cell := NONE) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var p := people[id]
	if p.location != "town" or p.role in ["Artillery","Damaged Artillery"]:
		return note("Choose a resident.",false)
	var town := towns[p.holder]
	if (job in GOODS.slice(0,8) or job == "Fishing") and (cell != NONE or not RECIPES.has(job)):
		if not contains(cell) or cell == town.cell or not in_radius(cell,town.cell) or yield_at(cell,job) == 0 or (water(cell) and "Dock" not in town.buildings):
			return note("Choose a productive neighboring tile. Fishing requires a Dock.",false)
		for other in people:
			if not is_same(other,p) and other.location == "town" and other.field == cell:
				return note("Another worker is using this tile.",false)
	elif job == "Muskets" and "Armory" not in town.buildings:
		return note("Muskets require an Armory.",false)
	elif job == "Crosses" and "Church" not in town.buildings:
		return note("Preaching requires a Church.",false)
	elif job != "" and job != "Crosses" and not RECIPES.has(job):
		return note("Choose a listed job.",false)
	p.job = job
	p.field = cell
	return note("Job updated.")


func capacity(town: Dictionary) -> int:
	return 100 + 100 * int("Warehouse" in town.buildings) + 100 * int("Warehouse Expansion" in town.buildings)


func free_holds(id: int) -> int:
	var s := ships[id]
	var used := passengers(id).size()
	for amount in s.cargo.values():
		used += ceili(amount / 100.0)
	return SHIPS[s.type][1] - used


func cargo_room(id: int, good: String) -> int:
	var current := held(ships[id].cargo,good)
	return free_holds(id)*100 + posmod(-current,100)


func transfer(ship: int, town: int, good: String, amount: int, loading: bool, quiet := false) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var s := ships[ship]
	var t := towns[town]
	var source: Dictionary = t.goods if loading else s.cargo
	var destination: Dictionary = s.cargo if loading else t.goods
	var room := cargo_room(ship,good) if loading else capacity(t)-held(t.goods,good)
	if not loading and good == "Food":
		room = amount
	if s.port != "America" or not port_access(s.cell,t.cell) or amount < 1 or held(source,good) < amount or room < amount:
		return false if quiet else note("Check ship position, stock, and available space.",false)
	adjust(source,good,-amount)
	adjust(destination,good,amount)
	return true if quiet else note("Cargo transferred.")


func price(good: String) -> int:
	return maxi(1, PRICES[GOODS.find(good)] + held(market,good))


func trade(id: int, good: String, amount: int, buy: bool, quiet := false) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var s := ships[id]
	if s.port != "Europe" or not good in GOODS or amount < 1:
		return false if quiet else note("Trade at the European port.",false)
	var cost := (price(good)+1)*amount
	if buy:
		if gold < cost or cargo_room(id,good) < amount:
			return false if quiet else note("Insufficient gold or cargo room.",false)
		gold -= cost
		adjust(s.cargo,good,amount)
	else:
		if held(s.cargo,good) < amount:
			return false if quiet else note("Insufficient cargo.",false)
		gold += floori(price(good)*amount*(100-tax)/100.0)
		adjust(s.cargo,good,-amount)
	ledger.append({"turn":turn,"good":good,"amount":amount,"buy":buy,"gold":-cost if buy else floori(price(good)*amount*(100-tax)/100.0)})
	if ledger.size() > 200:
		ledger.pop_front()
	if amount >= 20:
		market[good] = clampi(held(market,good)+(1 if buy else -1),-2,3)
	return true if quiet else note("European trade completed.")


func depart(id: int, reverse := false, quiet := false) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var s := ships[id]
	if s.port == "At sea" and reverse:
		s.destination = "America" if s.destination == "Europe" else "Europe"
		s.trip = maxi(1,int(s.get("trip_length",3))-s.trip)
	elif s.port == "Europe" or (s.port == "America" and kind(s.cell) == 12):
		s.destination = "Europe" if s.port == "America" else "America"
		s.port = "At sea"
		s.trip = 2 if nation == "Netherlands" else 3
		s.trip_length = s.trip
		s.course = NONE
	else:
		return false if quiet else note("Reach a High Seas tile or depart from Europe.",false)
	return true if quiet else note("Voyage to %s underway." % s.destination)


func recruit(id: int, skill: String) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var cost := (45 if nation == "England" else 60) if skill == "" else 120
	if ships[id].port != "Europe" or free_holds(id)<1 or gold<cost or (skill == "" and recruits<1):
		return note("Recruitment needs a ship in Europe, room, and gold.",false)
	gold -= cost
	if skill == "":
		recruits -= 1
	add_person("Colonist %d" % (people.size()+1),"ship",id,skill)
	if skill == "":
		people.back()["class"] = ["Free Colonist","Indentured Servant","Petty Criminal"][posmod(turn+people.size(),3)]
	return note("New colonist aboard.")


func order_ship(type: String) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var cost: int = SHIPS[type][2]
	if gold < cost:
		return note("Insufficient gold.",false)
	gold -= cost
	add_ship(type,NONE,"Europe")
	return note("%s purchased in Europe." % type)


func repair(id: int, town: int) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var s := ships[id]
	var t := towns[town]
	if s.damage == 0 or s.port != "America" or not port_access(s.cell,t.cell) or ("Drydock" not in t.buildings and not has_harbor(t.cell)):
		return note("Repairs need a damaged ship at a Drydock or sheltered harbor.",false)
	s.damage = 0
	return note("Repairs complete.")


func construction(town_id: int, project: String, rush := false) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var t := towns[town_id]
	if project == "":
		t.project = ""
		return note("Construction paused.")
	var blocker := building_block(t,residents(town_id).size(),project)
	if blocker != "":
		return note(blocker,false)
	var costs: Array = BUILDINGS[project]
	if rush:
		var price_to_rush := maxi(0,costs[0]-t.hammers)*3 + maxi(0,costs[1]-held(t.goods,"Tools"))*6
		if gold < price_to_rush:
			return note("Rush needs %d gold." % price_to_rush,false)
		gold -= price_to_rush
		t.hammers = maxi(t.hammers,costs[0])
		t.goods.Tools = maxi(held(t.goods,"Tools"),costs[1])
	t.project = project
	complete_building(t,residents(town_id).size())
	return note("Construction order updated.")


func building_block(town: Dictionary, population: int, project: String) -> String:
	if not BUILDINGS.has(project) or project in town.buildings:
		return "Choose an available project."
	var costs: Array = BUILDINGS[project]
	if costs[3] != "" and costs[3] not in town.buildings:
		return "Requires %s." % costs[3]
	if population < costs[2]:
		return "Requires %d residents." % costs[2]
	if project in ["Dock","Drydock","Shipyard"] and water_beside(town.cell) == NONE:
		return "Maritime construction needs a coastal settlement."
	return ""


func complete_building(t: Dictionary, population: int) -> bool:
	if t.project == "" or building_block(t,population,t.project) != "":
		return false
	var costs: Array = BUILDINGS[t.project]
	if t.hammers < costs[0] or held(t.goods,"Tools") < costs[1]:
		return false
	t.hammers -= costs[0]
	adjust(t.goods,"Tools",-costs[1])
	t.buildings.append(t.project)
	t.project = ""
	return true


func school_tier(town: Dictionary) -> int:
	if "University" in town.buildings:
		return 3
	if "College" in town.buildings:
		return 2
	return int("Schoolhouse" in town.buildings)


func training_block(id: int, specialty: String) -> String:
	var p := people[id]
	if p.location != "town" or p.skill != "" or p.study > 0 or p.job == "Teach":
		return "Choose an untrained resident."
	var slots := school_tier(towns[p.holder])
	if not Catalog.PROFESSIONS.has(specialty):
		return "Choose a listed specialty."
	if slots < Catalog.PROFESSIONS[specialty][1]:
		return "The colony needs the appropriate school tier."
	var active := 0
	for other in residents(p.holder):
		active += int(people[other].study > 0)
	if active >= slots:
		return "All teaching slots are occupied."
	return ""


func train(id: int, skill: String, teacher := -1) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var named := Catalog.profession(skill)
	var blocker := training_block(id,named)
	if blocker != "":
		return note(blocker,false)
	var p := people[id]
	if teacher >= 0:
		var instructor := people[teacher]
		if teacher == id or instructor.location != "town" or instructor.holder != p.holder or Catalog.profession(instructor.skill) != named or instructor.training != "" or instructor.job == "Teach":
			return note("Choose an available resident who knows that specialty.",false)
		instructor.job = "Teach"
		instructor.field = NONE
	p.teacher = teacher
	p.training = named
	p.study = Catalog.PROFESSIONS[named][2] + int(p.get("class","Free Colonist") != "Free Colonist")
	return note("Training takes %d turns." % p.study)


func equip(id: int, role: String) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var p := people[id]
	if p.location != "town":
		return note("Equip a resident at a settlement.",false)
	var inventory: Dictionary = towns[p.holder].goods
	var next: Array = equipment(role)
	var previous: Array = equipment(p.role)
	for good in next:
		if held(inventory,good)+50*int(good in previous)<50:
			return note("Equipment needs 50 of each listed good.",false)
	for good in previous:
		adjust(inventory,good,50)
	for good in next:
		adjust(inventory,good,-50)
	p.role = role
	return note("Equipment updated.")


func equipment(role: String) -> Array:
	if role == "Dragoon":
		return ["Horses","Muskets"]
	return [EQUIPMENT[role]] if EQUIPMENT.has(role) else []


func order_land(id: int, order: String) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var p := people[id]
	if p.location != "land":
		return note("Select a colonist on the map.",false)
	p.work = 0
	if order in ["Clear","Plow","Road"]:
		var existing: Array = improvements.get(p.cell,[])
		if p.role != "Pioneer" or order in existing or (order == "Clear" and not forest(p.cell)) or (order == "Plow" and (forest(p.cell) or kind(p.cell) >= 8)):
			return note("Choose an eligible tile and an equipped pioneer.",false)
		p.work = 2 if Catalog.profession(p.skill) == "Hardy Pioneer" else 3
	p.order = order
	return note("Orders updated.")


func configure_route(id: int, first: int, second: int, good: String, amount: int) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	if first == second or amount < 1 or not good in GOODS:
		return note("Choose two distinct colonies and a cargo quantity.",false)
	for stop in [first,second]:
		if water_beside(towns[stop].cell) == NONE:
			return note("Both route stops need coastal access.",false)
	var s := ships[id]
	s.stops = []
	s.route = [first,second,good,amount]
	s.leg = 0
	s.route_on = true
	s.course = NONE
	return note("Route runs each turn while the ship is in America.")


func water_beside(cell: Vector2i, ship_type := "") -> Vector2i:
	for candidate in work_area(cell):
		if candidate != cell and water(candidate) and (ship_type == "" or ship_can_enter(ship_type,candidate)):
			return candidate
	return NONE


func advance_route(id: int) -> void:
	var s := ships[id]
	var stops: Array = s.get("stops", [])
	if stops.is_empty():
		advance_legacy_route(id)
		return
	if not s.route_on or s.port != "America":
		return
	var stop: Dictionary = stops[s.leg % stops.size()]
	var town: int = stop.town
	if not port_access(s.cell,towns[town].cell):
		follow_water_path(s,water_beside(towns[town].cell,s.type))
	if not port_access(s.cell,towns[town].cell):
		return
	for rule in stop.rules:
		var source: Dictionary = towns[town].goods if rule.load else s.cargo
		var room := cargo_room(id,rule.good) if rule.load else capacity(towns[town])-held(towns[town].goods,rule.good)
		var amount := mini(rule.amount,mini(held(source,rule.good),room))
		if amount > 0:
			transfer(id,town,rule.good,amount,rule.load,true)
	s.leg = (s.leg+1) % stops.size()


func add_route_rule(id: int, town: int, good: String, amount: int, loading: bool) -> bool:
	if finished or amount < 1 or good not in GOODS or water_beside(towns[town].cell) == NONE:
		return note("Choose a coastal stop, good and quantity.",false)
	var s := ships[id]
	var stops: Array = s.get("stops", [])
	if stops.is_empty() or stops.back().town != town:
		stops.append({"town":town,"rules":[]})
	stops.back().rules.append({"good":good,"amount":amount,"load":loading})
	s.stops = stops
	s.route_on = false
	s.leg = 0
	return note("Route rule added.")


func advance_legacy_route(id: int) -> void:
	var s := ships[id]
	if not s.route_on or s.port != "America":
		return
	var route: Array = s.route
	var town: int = route[s.leg]
	var goal := water_beside(towns[town].cell,s.type)
	if not port_access(s.cell,towns[town].cell):
		follow_water_path(s,goal)
	if port_access(s.cell,towns[town].cell):
		if transfer(id,town,route[2],route[3],s.leg == 0,true):
			s.leg = 1-s.leg


func tick_town(id: int) -> void:
	var t := towns[id]
	var workers := residents(id)
	var goods: Dictionary = t.goods
	adjust(goods,"Food",3-workers.size()*2)
	for person in workers:
		var p := people[person]
		if p.field != NONE and (not water(p.field) or "Dock" in t.buildings):
			var product: String = "Food" if p.job == "Fishing" else p.job
			var work: String = "Fishing" if water(p.field) else p.job
			var output := yield_at(p.field,p.job)+Catalog.bonus(p.skill,work)
			adjust(goods,product,output)
			var resource := tile_resource(p.field)
			if resource.get("reserve",0) > 0 and resource.bonuses.has(product):
				extraction[p.field] = int(extraction.get(p.field,0))+int(resource.bonuses[product])
		if p.job == "Crosses":
			crosses += 2 + Catalog.bonus(p.skill,"Crosses") + 2*int("Cathedral" in t.buildings)
		if p.study > 0 and Catalog.PROFESSIONS.has(p.training) and school_tier(t) >= Catalog.PROFESSIONS[p.training][1]:
			var teacher: int = p.get("teacher",-1)
			if teacher >= 0 and (people[teacher].location != "town" or people[teacher].holder != id or people[teacher].job != "Teach"):
				release_teacher(p)
				p.training = ""
				p.study = 0
				continue
			p.study -= 1
			if p.study == 0:
				p.skill = p.training
				p["class"] = "Free Colonist"
				release_teacher(p)
				p.training = ""
	for person in workers:
		var p := people[person]
		if not RECIPES.has(p.job):
			continue
		var input: String = RECIPES[p.job]
		var amount := mini(held(goods,input),workshop_capacity(p,t))
		adjust(goods,input,-amount)
		if p.job == "Hammers":
			t.hammers += amount
		else:
			adjust(goods,p.job,amount)
	if held(goods,"Food") < 0:
		goods.Food = 0
		if workers.size() > 1:
			people[workers.back()].location = "lost"
	elif held(goods,"Food") >= 200:
		adjust(goods,"Food",-200)
		add_person("Colonist %d" % (people.size()+1),"town",id)
	if held(goods,"Horses") >= 2 and held(goods,"Food") >= 2:
		adjust(goods,"Horses",2 if "Stables" in t.buildings else 1)
		adjust(goods,"Food",-2)
	if t.project != "":
		complete_building(t,residents(id).size())
	for good in goods:
		if good != "Food":
			goods[good] = mini(goods[good],capacity(t))


func brazil_coast() -> Vector2i:
	var best := NONE
	var score := -INF
	var target := Vector2(dimensions)*Vector2(0.76,0.67)
	for y in range(int(dimensions.y*0.48),int(dimensions.y*0.87)):
		for x in range(int(dimensions.x*0.40),dimensions.x-1):
			var cell := Vector2i(x,y)
			if water(cell) or kind(cell) in [8,10] or not water(cell+Vector2i.RIGHT):
				continue
			var candidate := float(local_yield(cell,"Sugar"))*0.8-Vector2(cell).distance_to(target)
			if candidate > score:
				score = candidate
				best = cell
	return best


func end_turn() -> void:
	local_yield_cache.clear()
	if finished:
		note("Campaign complete. Score %d." % score())
		return
	var before: Array[Dictionary] = []
	for town in towns:
		before.append(town.goods.duplicate())
	for id in range(towns.size()):
		tick_town(id)
	for p in people:
		p.moves = 2 if p.role == "Scout" or p.role == "Dragoon" else 1
		if p.location == "land" and p.work > 0 and p.order in ["Clear","Plow","Road"]:
			p.work -= 1
			if p.work == 0:
				if p.order == "Clear":
					terrain[index(p.cell)] = (raw(p.cell)&0xc0) | (raw(p.cell)&7)
				else:
					var changes: Array = improvements.get(p.cell,[])
					changes.append(p.order)
					improvements[p.cell] = changes
				indigenous.encroach(p.cell,8)
				p.order = ""
	for id in range(ships.size()):
		var s := ships[id]
		s.moves = maxi(1,SHIPS[s.type][0]-s.damage)
		if s.trip > 0:
			s.trip -= 1
			if s.trip == 0:
				s.port = s.destination
				s.crossings = int(s.get("crossings",0))+1
				s.damage = mini(s.damage+1,3) if s.crossings % 4 == 0 else s.damage
				if s.port == "America":
					if not contains(s.cell) or not water(s.cell):
						s.cell = Vector2i(dimensions.x-1,16)
					reveal(s.cell)
				s.destination = ""
		else:
			advance_route(id)
			if not s.route_on:
				advance_course(id)
	for wagon in wagons:
		advance_wagon(wagon)
	while crosses >= 12:
		crosses -= 12
		recruits += 1
	rivals.tick()
	indigenous.tick()
	for id in range(towns.size()):
		var town := towns[id]
		town.goods_delta = {}
		for good in GOODS:
			var previous: int = before[id].get(good,0) if id < before.size() else 0
			town.goods_delta[good] = held(town.goods,good)-previous
	turn += 1
	if turn % 8 == 0:
		var good: String = GOODS[(turn / 8 - 1) % GOODS.size()]
		var swing := 1 if turn % 16 == 8 else -1
		market[good] = clampi(held(market,good)+swing,-2,3)
		market_notice = "%s prices %s in Europe." % [good,"rose" if swing > 0 else "fell"]
	finished = year + (turn-1)/2 >= target_year
	note("Campaign complete. Score %d." % score() if finished else "Turn processed.")


func score() -> int:
	var count := 0
	for p in people:
		count += int(p.location != "lost")
	return count*5 + towns.size()*20 + gold/10 + discoveries*2


func save(path: String) -> bool:
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		return note("Save could not be written.",false)
	var values := [dimensions,terrain,ships,people,towns,explored,improvements,turn,year,gold,tax,crosses,recruits,nation,leader,target_year,finished,market,discovered_sites,wagons,ledger,market_notice,discoveries,extraction,world_seed,rivals.factions,rivals.settlements,indigenous.snapshot()]
	file.store_var([5,values])
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))
	return note("Campaign saved." if error == OK else "Save failed.",error == OK)


func load_slot(path: String) -> bool:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		return note("Slot is empty.",false)
	var data = file.get_var()
	if not data is Array or data.size()!=2 or data[0] not in [1,2,3,4,5] or not data[1] is Array or data[1].size() != [0,20,23,27,28,28][data[0]]:
		return note("Save format is invalid.",false)
	var v: Array = data[1]
	if not v[0] is Vector2i or not v[1] is PackedByteArray or v[0].x*v[0].y!=v[1].size() or not v[2] is Array or v[2].is_empty() or not v[3] is Array or v[3].is_empty() or not v[4] is Array or not v[19] is Array:
		return note("Save map or fleet is invalid.",false)
	dimensions=v[0]
	terrain=v[1]
	classify_geography()
	ships.assign(v[2])
	people.assign(v[3])
	towns.assign(v[4])
	explored=v[5]
	improvements=v[6]
	turn=v[7]
	year=v[8]
	gold=v[9]
	tax=v[10]
	crosses=v[11]
	recruits=v[12]
	nation=v[13]
	leader=v[14]
	target_year=v[15]
	finished=v[16]
	market=v[17]
	discovered_sites=v[18]
	wagons.assign(v[19])
	ledger.clear()
	if v.size() > 20:
		ledger.assign(v[20])
	market_notice = v[21] if v.size() > 21 else ""
	discoveries = v[22] if v.size() > 22 else 0
	for town in towns:
		for building in Catalog.STARTERS:
			if building not in town.buildings:
				town.buildings.append(building)
	extraction = v[23] if v.size()>23 else {}
	world_seed = v[24] if v.size()>24 else 1492
	rivals.campaign_ref = weakref(self)
	if v.size()>26:
		rivals.factions.assign(v[25])
		rivals.settlements.assign(v[26])
	else:
		rivals.start(self)
	if v.size() > 27:
		indigenous.restore(self,v[27])
	else:
		indigenous.start(self,false)
	return note("Campaign loaded.")

func build_ship(town: int, type: String) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var t := towns[town]
	var coast := water_beside(t.cell,type)
	var cost: int = SHIPS[type][2] / 4
	if "Shipyard" not in t.buildings or coast == NONE or t.hammers < cost or held(t.goods,"Tools") < 20:
		return note("Shipbuilding needs a Shipyard, %d hammers, and 20 tools." % cost,false)
	t.hammers -= cost
	adjust(t.goods,"Tools",-20)
	add_ship(type,coast,"America")
	return note("%s launched." % type)


func skip_person(id: int) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	if people[id].location != "land":
		return false
	people[id].moves = 0
	return note("Movement skipped this turn.")


func disband(id: int) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	if people[id].location != "land":
		return false
	people[id].location = "lost"
	return note("Colonist disbanded.")


func set_course(id: int, cell: Vector2i) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var s := ships[id]
	if s.port != "America" or not contains(cell) or not water(cell) or not ship_can_enter(s.type,cell):
		return note("Select a water destination in America.",false)
	s.course = cell
	s.route_on = false
	return note("Course plotted. Ship follows it at end of turn.")


func advance_course(id: int) -> void:
	var s := ships[id]
	var goal: Vector2i = s.get("course",NONE)
	if goal == NONE or s.port != "America":
		return
	follow_water_path(s,goal)
	if s.cell == goal:
		s.course = NONE


func follow_water_path(s: Dictionary, goal: Vector2i, reveal_path := true) -> void:
	var origin: Vector2i = s.cell
	var frontier: Array[Vector2i] = [origin]
	var prev := {origin:NONE}
	var cursor := 0
	while cursor < frontier.size() and not prev.has(goal):
		var cell := frontier[cursor]
		cursor += 1
		for next in Hex.neighbors(cell):
			if contains(next) and water(next) and ship_can_enter(s.get("type","Caravel"),next) and not prev.has(next):
				prev[next] = cell
				frontier.append(next)
	if not prev.has(goal):
		return
	var path: Array[Vector2i] = []
	while goal != origin:
		path.push_front(goal)
		goal = prev[goal]
	for step in path.slice(0,s.moves):
		s.cell = step
		s.moves -= 1
		if reveal_path:
			reveal(step)





func site_available(cell: Vector2i) -> bool:
	if not contains(cell) or water(cell) or discovered_sites.has(cell):
		return false
	return posmod(cell.x*37 + cell.y*61 + cell.x*cell.y*11,43) == 0


func explore_site(id: int) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var p := people[id]
	if p.location != "land" or p.role in ["Artillery","Damaged Artillery"] or not site_available(p.cell) or p.moves < 1:
		return note("An active colonist must stand on an uncharted site.",false)
	discovered_sites[p.cell] = true
	p.moves = 0
	discoveries += 1
	match posmod(p.cell.x*13 + p.cell.y*7, 4):
		0:
			var reward := 45 if Catalog.profession(p.skill) == "Seasoned Scout" else (35 if p.role == "Scout" else 15)
			gold += reward
			return note("Surveyed the site and recovered %d gold." % reward)
		1:
			reveal(p.cell + Vector2i(2, 0))
			reveal(p.cell + Vector2i(-2, 0))
			return note("Surveyed a lookout and charted nearby terrain.")
		2:
			add_person("Surveyor %d" % discoveries, "land", -1, "Food")
			people.back().cell = p.cell
			people.back().moves = 0
			return note("A surveyor joined your expedition.")
		_:
			return note("The survey found a landmark.")


func clear_skill(id: int) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	var p := people[id]
	if p.job == "Teach":
		return note("This resident is teaching a class.", false)
	p.skill = ""
	release_teacher(p)
	p.training = ""
	p.study = 0
	return note("Specialty cleared.")


func start_wagon(first: int, second: int, good: String, amount: int) -> bool:
	if finished:
		return note("This campaign has ended.",false)
	if first == second or amount < 1 or amount > 100:
		return note("Wagons need distinct stops and a load of at most 100.",false)
	var from: Vector2i = towns[first].cell
	var to: Vector2i = towns[second].cell
	var distance := distance_step(from,to,false,dimensions.x*dimensions.y)
	if distance < 1:
		return note("No land route connects those colonies.",false)
	var source := towns[first]
	if source.hammers < 20 or held(source.goods,"Tools") < 10:
		return note("A wagon needs 20 hammers and 10 tools at its source.",false)
	source.hammers -= 20
	adjust(source.goods,"Tools",-10)
	var duration := maxi(1,ceili(distance/3.0))
	if has_river_freight(from,to):
		duration = maxi(1,duration-1)
	wagons.append({"first":first,"second":second,"good":good,"amount":amount,"duration":duration,"remaining":0,"cargo":0,"returning":false})
	return note("Wagon route created. Each leg takes %d turns." % duration)


func advance_wagon(wagon: Dictionary) -> void:
	if wagon.remaining > 0:
		wagon.remaining -= 1
		if wagon.remaining > 0:
			return
	if wagon.returning:
		wagon.returning = false
	if wagon.cargo > 0:
		var target := towns[wagon.second]
		if wagon.good != "Food" and held(target.goods,wagon.good)+wagon.cargo > capacity(target):
			return
		adjust(target.goods,wagon.good,wagon.cargo)
		wagon.cargo = 0
		wagon.returning = true
		wagon.remaining = wagon.duration
		return
	var source: Dictionary = towns[wagon.first].goods
	if held(source,wagon.good) >= wagon.amount:
		adjust(source,wagon.good,-wagon.amount)
		wagon.cargo = wagon.amount
		wagon.remaining = wagon.duration



func tile_resource(cell: Vector2i) -> Dictionary:
	if not contains(cell) or posmod(cell.x*37 + cell.y*17 + world_seed,7) != 0:
		return {}
	var name := ""
	var type := kind(cell)
	if water(cell):
		if type != 11 or water_beside_land(cell) == false:
			return {}
		name = "Fishery"
	elif forest(cell):
		var choices := ["Game","Prime Timber"] if type == 7 else ["Game","Trapping Grounds","Prime Timber"]
		name = choices[posmod(cell.x+cell.y,choices.size())]
	else:
		name = ["Mineral Deposit","Oasis","Prime Farmland","Prime Cotton","Prime Tobacco","Prime Sugar","Mineral Deposit","Mineral Deposit","","Ore Deposit","Silver Deposit"][type]
	if name == "":
		return {}
	var entry: Array = Catalog.RESOURCE[name]
	var reserve: int = entry[1]
	if reserve > 0 and extraction.get(cell,0) >= reserve:
		return {}
	return {"name":name,"bonuses":entry[0],"reserve":reserve,"icon":entry[2]}


func water_beside_land(cell: Vector2i) -> bool:
	for candidate in Hex.neighbors(cell):
		if not water(candidate):
			return true
	return false


func workshop_capacity(person: Dictionary, town: Dictionary) -> int:
	var grade: String = person.get("class","Free Colonist")
	var baseline := 1 if grade == "Petty Criminal" else (2 if grade == "Indentured Servant" else 3)
	return baseline + Catalog.bonus(person.skill,person.job) + 2*int(WORKSHOP_UPGRADES[person.job] in town.buildings) + 3*int(FACTORIES.get(person.job,"") in town.buildings)


func release_teacher(student: Dictionary) -> void:
	var teacher: int = student.get("teacher", -1)
	if teacher >= 0 and people[teacher].job == "Teach":
		people[teacher].job = ""
	student.teacher = -1
func confront(ship: int, nation_name: String) -> bool:
	var s := ships[ship]
	for faction in rivals.factions:
		if faction.nation != nation_name:
			continue
		if finished or faction.relation != "War" or s.port != "America" or not nearby(s.cell,faction.ship) or s.moves <= 0 or s.type not in ["Privateer","Frigate"]:
			return note("An armed ship with moves must reach an enemy vessel at war.",false)
		s.moves = 0
		var won: bool = (16 if s.type == "Frigate" else 8)-s.damage*2 >= 7 + posmod(turn + faction.colonies,4)
		if won:
			faction.ship = faction.goal
			faction.gold = maxi(0,faction.gold-40)
			gold += 40
		else:
			s.damage = mini(3,s.damage+1)
		return note("Enemy vessel driven off. Recovered 40 gold." if won else "The enemy held. Your vessel took damage.")
	return false


func attack_colony(person: int, town: int) -> bool:
	var p := people[person]
	var t := rivals.settlements[town]
	var at_war := false
	for faction in rivals.factions:
		if faction.nation == t.nation:
			at_war = faction.relation == "War"
	if finished or not at_war or p.location != "land" or p.moves <= 0 or not nearby(p.cell,t.cell) or p.role not in ["Soldier","Dragoon","Artillery"]:
		return note("Bring an armed land unit with movement beside a colony at war.",false)
	p.moves = 0
	var strength: int = {"Soldier":2,"Dragoon":3,"Artillery":7}[p.role]
	strength += int(Catalog.profession(p.skill)=="Veteran Soldier")
	if strength < mini(6,t.population+1):
		if p.role == "Artillery":
			p.role = "Damaged Artillery"
		else:
			p.role = ""
		return note("The settlement held. Your unit lost its equipment.")
	rivals.settlements.remove_at(town)
	for faction in rivals.factions:
		if faction.nation == t.nation:
			faction.status = "Lost %s" % t.name
	towns.append({"name":t.name,"cell":t.cell,"goods":t.goods,"buildings":Catalog.STARTERS.duplicate(),"project":"","hammers":0})
	p.cell = t.cell
	var artillery: bool = p.role == "Artillery"
	if not artillery:
		join_town(person,towns.size()-1)
	for i in range(maxi(0,t.population-int(not artillery))):
		add_person("Resident %d" % (people.size()+1),"town",towns.size()-1)
	reveal(t.cell)
	return note("%s captured." % t.name)


func purchase_artillery(ship: int) -> bool:
	if finished or ships[ship].port != "Europe" or gold < 180 or free_holds(ship)<1:
		return note("Artillery costs 180 gold and one hold in Europe.",false)
	gold -= 180
	add_person("Artillery","ship",ship)
	people.back().role = "Artillery"
	return note("Artillery loaded.")



func colony_defense(town: Dictionary) -> int:
	if "Fortress" in town.buildings:
		return 200
	if "Fort" in town.buildings:
		return 150
	return 100 if "Stockade" in town.buildings else 0

func work_area(cell: Vector2i) -> Array[Vector2i]:
	var cells := Hex.within(cell,Hex.RADIUS)
	return cells.filter(contains)


func in_radius(a: Vector2i,b: Vector2i) -> bool:
	return Hex.distance(a,b) <= Hex.RADIUS


func port_access(berth: Vector2i, town: Vector2i) -> bool:
	return contains(berth) and water(berth) and in_radius(berth,town)


func feature(cell: Vector2i) -> String:
	return geography.get(cell,"")


func classify_geography() -> void:
	geography.clear()
	local_yield_cache.clear()
	for y in range(dimensions.y):
		for x in range(dimensions.x):
			var cell := Vector2i(x,y)
			var type := kind(cell)
			var land := 0
			var relief := 0
			var rivers := 0
			for next in Hex.neighbors(cell):
				land += int(not water(next))
				relief += int(kind(next) in [9,10])
				rivers += int(not water(next) and (raw(next)&64)!=0)
			if type == 11 and land >= 3:
				geography[cell] = "Sheltered harbor" if land >= 4 and land <= 5 else "Shoals"
			elif type in [9,10] and (raw(cell)&64)!=0:
				geography[cell] = "Rapids"
			elif type == 9 and relief >= 2 and land >= 5:
				geography[cell] = "Mountain pass"
			elif type < 8 and (raw(cell)&64)!=0:
				geography[cell] = "Floodplain" if rivers >= 2 else "Navigable river"


func ship_can_enter(ship_type: String, cell: Vector2i) -> bool:
	return feature(cell) != "Shoals" or ship_type not in ["Galleon","Frigate"]


func has_harbor(cell: Vector2i) -> bool:
	for tile in work_area(cell):
		if feature(tile) == "Sheltered harbor":
			return true
	return false


func sailing_cost(ship: Dictionary, target: Vector2i) -> int:
	var origin: Vector2i = ship.cell
	var visited := {origin:0}
	var queue: Array[Vector2i] = [origin]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		if cell == target:
			return visited[cell]
		if visited[cell] >= ship.moves:
			continue
		for next in Hex.neighbors(cell):
			if contains(next) and water(next) and ship_can_enter(ship.type,next) and not visited.has(next):
				visited[next] = visited[cell]+1
				queue.append(next)
	return -1


func local_yield(cell: Vector2i, good: String) -> int:
	var key := Vector3i(cell.x,cell.y,GOODS.find(good))
	if local_yield_cache.has(key):
		return local_yield_cache[key]
	var best := 0
	for tile in work_area(cell):
		if not water(tile) or good == "Food":
			best = maxi(best,yield_at(tile,good))
	local_yield_cache[key] = best
	return best


func has_river_freight(from: Vector2i, to: Vector2i) -> bool:
	var queue: Array[Vector2i] = []
	var seen := {}
	for tile in work_area(from):
		if freight_river(tile):
			queue.append(tile)
			seen[tile] = true
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		if in_radius(cell,to):
			return true
		for next in Hex.neighbors(cell):
			if freight_river(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return false


func freight_river(cell: Vector2i) -> bool:
	return contains(cell) and not water(cell) and (raw(cell)&64)!=0 and feature(cell)!="Rapids"

func reachable_land(origin: Vector2i, budget: int) -> Dictionary:
	var queue: Array[Vector2i] = [origin]
	var costs := {origin:0}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		if costs[cell] >= budget:
			continue
		for next in Hex.neighbors(cell):
			if not contains(next) or water(next):
				continue
			var step := land_cost(next)
			var cost: int = costs[cell] + (mini(step,budget) if cell == origin else step)
			if cost <= budget and cost < costs.get(next,2147483647):
				costs[next] = cost
				queue.append(next)
	return costs
