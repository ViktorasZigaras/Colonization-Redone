extends RefCounted

const NONE := Vector2i(-1,-1)
const HORSE_YEAR := 1550
const HORSE_CONTACT := 8
const SPREAD_CONTACT := 6
const GRIEVANCE_LIMIT := 60
const GOODS := ["Food","Furs","Lumber","Cotton","Tobacco","Horses","Tools","Cloth"]
const WEAPONS := ["Bow","Spear","Club"]
const GROUPS := {
	"Innu":[Vector2i(27,6),"Travel camps","Furs",2,"Bow","#85c6aa"],
	"Mi'kmaq":[Vector2i(32,15),"Fish weir","Food",2,"Spear","#7ac6e4"],
	"Haudenosaunee":[Vector2i(24,16),"Three Sisters gardens","Food",3,"Bow","#e0acdd"],
	"Caddo":[Vector2i(16,21),"River gardens","Food",2,"Bow","#e9a968"],
	"Pueblo communities":[Vector2i(9,19),"Irrigated fields","Food",3,"Bow","#dba377"],
	"Taíno communities":[Vector2i(36,28),"Cassava gardens","Food",3,"Club","#f7ca73"],
	"Mexica":[Vector2i(17,27),"Chinampa gardens","Food",4,"Spear","#86d48a"],
	"Maya communities":[Vector2i(23,29),"Milpa fields","Food",3,"Spear","#9ed665"],
	"Tawantinsuyu":[Vector2i(33,47),"Terrace fields","Food",4,"Spear","#e9a088"],
}
const BUILD := {
	"Food store":[18,6,2],"Palisade":[24,10,3],"Exchange shelter":[18,6,3],
	"Horse enclosure":[24,8,3],
}
const DIRECTIONS := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]

var campaign_ref: WeakRef
var model:
	get: return campaign_ref.get_ref()
var settlements: Array[Dictionary] = []
var nations := {}
var borders := {}
var events: Array[String] = []
var next_id := 1
var land_reach := {}


func start(campaign, generated: bool) -> void:
	campaign_ref = weakref(campaign)
	settlements.clear()
	nations.clear()
	borders.clear()
	events.clear()
	land_reach.clear()
	next_id = 1
	for nation in GROUPS:
		var entry: Array = GROUPS[nation]
		var anchor: Vector2i = entry[0]
		if generated:
			anchor += Vector2i(posmod(model.world_seed + anchor.y*7,9)-4,0)
		var home := find_site(anchor, 16 if generated else 5)
		if home == NONE:
			continue
		nations[nation] = {"contact":{},"grievance":{},"horse_links":{},"horses":false}
		var first := add_settlement(nation, home, 4 if nation in ["Mexica","Tawantinsuyu"] else 3)
		first.buildings.append(entry[1])
		var nearby_site := find_site(home + Vector2i(2,0), 3)
		if nearby_site != NONE:
			add_settlement(nation, nearby_site, 2)


func add_settlement(nation: String, cell: Vector2i, population: int) -> Dictionary:
	var site := {"id":next_id,"name":"%s settlement %d" % [nation,next_id],"nation":nation,"cell":cell,"population":population,"goods":{"Food":14,"Lumber":8},"buildings":[],"project":"","work":0,"cooldown":0,"founded":model.turn}
	next_id += 1
	settlements.append(site)
	return site


func distance(a: Vector2i, b: Vector2i) -> int:
	return model.Hex.distance(a,b)


func find_site(anchor: Vector2i, radius: int) -> Vector2i:
	var best := NONE
	var score := -999
	for dy in range(-radius,radius+1):
		for dx in range(-radius,radius+1):
			var cell := anchor + Vector2i(dx,dy)
			if not model.contains(cell) or model.water(cell) or model.kind(cell) in [8,10]:
				continue
			if occupied(cell):
				continue
			var value: int = model.local_yield(cell,"Food")-distance(anchor,cell)*3
			if value > score:
				score = value
				best = cell
	return best


func occupied(cell: Vector2i) -> bool:
	for site in settlements:
		if distance(site.cell,cell) <= 1:
			return true
	for town in model.towns + model.rivals.settlements:
		if distance(town.cell,cell) <= 1:
			return true
	return false


func site_at(cell: Vector2i) -> bool:
	for settlement in settlements:
		if settlement.cell == cell:
			return true
	return false


func count_sites(nation: String) -> int:
	var total := 0
	for site in settlements:
		total += int(site.nation == nation)
	return total


func tick() -> void:
	if settlements.is_empty():
		return
	land_reach.clear()
	update_contact()
	for site in settlements.duplicate():
		produce(site)
		if site.cooldown > 0:
			site.cooldown -= 1
		if site.population >= 6 and site.goods.Food >= 24 and count_sites(site.nation) < 6 and (model.turn + site.id) % 9 == 0:
			expand(site)
	if model.turn % 3 == 0:
		resolve_borders()
		consider_european_targets()


func produce(site: Dictionary) -> void:
	var goods: Dictionary = site.goods
	var cell: Vector2i = site.cell
	var profile: Array = GROUPS[site.nation]
	var food: int = maxi(2,model.yield_at(cell,"Food")) + int(model.local_yield(cell,"Food")>model.yield_at(cell,"Food"))
	var special := int(profile[2] == "Food" and profile[1] in site.buildings)
	var food_capacity := 90 if "Food store" in site.buildings else 48
	var shelter_bonus := 1 if "Exchange shelter" in site.buildings and site.get("exchanges",0)>0 else 0
	goods.Food = clampi(goods.Food + food + special*int(profile[3]) + mini(site.population,8) - site.population + shelter_bonus,0,food_capacity)
	if goods.Food == 0 and site.population > 2:
		site.population -= 1
	if goods.Food >= 30 and site.population < 14:
		goods.Food -= 20
		site.population += 1
	goods.Lumber = mini(80,goods.Lumber+maxi(1,model.local_yield(cell,"Lumber"))+site.population/3)
	if profile[2] != "Food" and profile[1] in site.buildings:
		var good: String = profile[2]
		goods[good] = mini(80,goods.get(good,0)+int(profile[3]))
	if "Horse enclosure" in site.buildings and goods.get("Horses",0) >= 2 and goods.Food >= 8:
		goods.Horses = mini(40,goods.Horses+1)
		goods.Food -= 2
	build(site)


func build(site: Dictionary) -> void:
	if site.project == "":
		var choices: Array = [GROUPS[site.nation][1]]
		if site.goods.Food >= 38:
			choices.append("Food store")
		var pressure := false
		for value in nations[site.nation].grievance.values():
			pressure = pressure or value >= 34
		for other in settlements:
			if other.nation != site.nation and distance(other.cell,site.cell)<=4:
				pressure = true
				break
		if pressure:
			choices.push_front("Palisade")
		if site.get("exchanges",0)>0:
			choices.append("Exchange shelter")
		if nations[site.nation].horses and site.goods.Food >= 18 and (site.goods.get("Horses",0)>=2 or breeding_stock(site)):
			choices.append("Horse enclosure")
		for name in choices:
			var costs: Array = BUILD.get(name,[14,5,2])
			if name not in site.buildings and site.population >= costs[2]:
				site.project = name
				break
	if site.project == "":
		return
	var costs: Array = BUILD.get(site.project,[14,5,2])
	site.work += maxi(1,site.population/2)
	if site.work < costs[0] or site.goods.Lumber < costs[1]:
		return
	site.goods.Lumber -= costs[1]
	site.buildings.append(site.project)
	if site.project == "Horse enclosure":
		site.goods.Horses = maxi(2,site.goods.get("Horses",0))
		add_event("%s started raising horses." % site.name)
	site.work = 0
	site.project = ""


func expand(site: Dictionary) -> void:
	for delta in DIRECTIONS:
		var cell := find_site(site.cell + delta*3,2)
		if cell != NONE and reachable(site.cell,cell,7):
			site.population -= 2
			site.goods.Food -= 16
			add_settlement(site.nation,cell,2)
			return


func reachable(from: Vector2i, to: Vector2i, budget: int) -> bool:
	var key := Vector3i(from.x,from.y,budget)
	if not land_reach.has(key):
		land_reach[key] = model.reachable_land(from,budget)
	return land_reach[key].has(to)


func update_contact() -> void:
	var contacts := {}
	var foreign := {}
	var local_sites := sites_by_cell()
	for site in settlements:
		for town in model.towns:
			if distance(site.cell,town.cell) <= 4:
				observe(contacts,site.nation,model.nation)
				observe(foreign,site.nation,model.nation)
		for town in model.rivals.settlements:
			if distance(site.cell,town.cell) <= 4:
				observe(contacts,site.nation,town.nation)
				observe(foreign,site.nation,town.nation)
		for ship in model.ships:
			if ship.port == "America" and distance(site.cell,ship.cell) <= 2:
				observe(contacts,site.nation,model.nation)
		for cell in model.Hex.within(site.cell,4):
			if not local_sites.has(cell):
				continue
			var other: Dictionary = local_sites[cell]
			if site.nation != other.nation and reachable(site.cell,other.cell,8):
				observe(contacts,site.nation,other.nation)
	var eligible := {}
	for name in nations:
		eligible[name] = nations[name].horses
	for name in nations:
		var state: Dictionary = nations[name]
		var linked: Dictionary = contacts.get(name,{})
		for partner in linked:
			state.contact[partner] = state.contact.get(partner,0)+1
			if partner in foreign.get(name,{}):
				change_grievance(name,partner,2)
			if model.year+(model.turn-1)/2 < HORSE_YEAR or eligible[name]:
				continue
			var source: bool = eligible.get(partner,false) or (partner == "Spain" and partner != model.nation and partner in foreign.get(name,{}))
			source = source or european_herd_near(name,partner)
			if source:
				state.horse_links[partner] = state.horse_links.get(partner,0)+1
				var threshold := SPREAD_CONTACT if nations.has(partner) else HORSE_CONTACT
				if state.horse_links[partner] >= threshold and not state.horses:
					unlock_horses(name,partner)
		for partner in state.grievance.keys():
			if partner not in foreign.get(name,{}):
				change_grievance(name,partner,-1)


func observe(table: Dictionary, nation: String, partner: String) -> void:
	if not table.has(nation):
		table[nation] = {}
	table[nation][partner] = true


func european_herd_near(nation: String, partner: String) -> bool:
	if partner != model.nation:
		return false
	for site in settlements:
		if site.nation != nation:
			continue
		for town in model.towns:
			if town.goods.get("Horses",0) >= 2 and distance(site.cell,town.cell) <= 4:
				return true
		for ship in model.ships:
			if ship.port == "America" and ship.cargo.get("Horses",0) >= 2 and distance(site.cell,ship.cell) <= 2:
				return true
	return false


func unlock_horses(nation: String, partner: String) -> void:
	nations[nation].horses = true
	add_event("%s communities learned horse husbandry through contact with %s." % [nation,partner])


func change_grievance(nation: String, partner: String, amount: int) -> void:
	var grievance: Dictionary = nations[nation].grievance
	grievance[partner] = clampi(grievance.get(partner,0)+amount,0,100)


func encroach(cell: Vector2i, amount: int) -> void:
	var affected := {}
	for site in settlements:
		if distance(site.cell,cell) <= 4:
			affected[site.nation] = true
	for nation in affected:
		change_grievance(nation,model.nation,amount)


func resolve_borders() -> void:
	var considered := {}
	var local_sites := sites_by_cell()
	for a in settlements:
		for cell in model.Hex.within(a.cell,5):
			if not local_sites.has(cell):
				continue
			var b: Dictionary = local_sites[cell]
			if a.nation == b.nation or a.id >= b.id:
				continue
			var key: String = "/".join([a.nation,b.nation] if a.nation < b.nation else [b.nation,a.nation])
			if considered.has(key):
				continue
			considered[key] = true
			if not reachable(a.cell,b.cell,9):
				continue
			borders[key] = int(borders.get(key,0))+1
			if borders[key] < 3 or a.cooldown > 0 or b.cooldown > 0:
				continue
			var attacker: Dictionary = a if strength(a) >= strength(b) else b
			var defender: Dictionary = b if attacker.id == a.id else a
			if attacker.population < 4 or strength(attacker) < strength(defender)+1:
				continue
			var previous: String = defender.nation
			attacker.cooldown = 8
			defender.cooldown = 8
			borders[key] = 0
			attacker.goods.Food = maxi(0,attacker.goods.Food-8)
			defender.population = maxi(2,defender.population-1)
			defender.nation = attacker.nation
			defender.project = ""
			defender.work = 0
			# The settlement keeps its name, supplies and local infrastructure.
			if not nations[attacker.nation].horses:
				defender.buildings.erase("Horse enclosure")
				defender.goods.erase("Horses")
			add_event("%s took control of %s from %s." % [attacker.nation,defender.name,previous])


func strength(site: Dictionary) -> int:
	var mounted: int = 2 if site.goods.get("Horses",0) >= 4 else 0
	return site.population + 2*int("Palisade" in site.buildings) + mounted


func consider_european_targets() -> void:
	for site in settlements:
		if site.cooldown > 0 or site.population < 4:
			continue
		var anger: Dictionary = nations[site.nation].grievance
		for town in model.towns + model.rivals.settlements:
			var own: bool = not town.has("nation")
			var nation: String = model.nation if own else town.nation
			if anger.get(nation,0) < GRIEVANCE_LIMIT or distance(site.cell,town.cell)>4 or not reachable(site.cell,town.cell,8):
				continue
			var defense: int = model.residents(model.towns.find(town)).size()+model.colony_defense(town)/50 if own else town.population
			var won: bool = strength(site)>defense+2
			site.cooldown = 9
			change_grievance(site.nation,nation,-18)
			if won:
				var supplies: Dictionary = town.goods
				var food_taken := mini(10,supplies.get("Food",0))
				supplies.Food = supplies.get("Food",0)-food_taken
				site.goods.Food += food_taken
			add_event("%s %s %s with %s." % [site.nation,"raided" if won else "was repelled at",town.name,GROUPS[site.nation][4].to_lower()+"s"])
			break


func exchange(ship_id: int, id: int, good: String, amount: int, buy: bool) -> bool:
	if model.finished or good not in GOODS or amount <= 0 or id < 0 or id >= settlements.size():
		return model.note("Choose a settlement and permitted cargo.",false)
	var site := settlements[id]
	var ship: Dictionary = model.ships[ship_id]
	if ship.port != "America" or not model.port_access(ship.cell,site.cell):
		return model.note("Bring the ship next to the settlement.",false)
	if nations[site.nation].grievance.get(model.nation,0)>=GRIEVANCE_LIMIT:
		return model.note("Relations are too strained for trade. Offer supplies to reopen contact.",false)
	if good == "Horses" and not nations[site.nation].horses:
		return model.note("Horse trade requires established husbandry.",false)
	var source: Dictionary = site.goods if buy else ship.cargo
	var target: Dictionary = ship.cargo if buy else site.goods
	var payment: int = model.price(good)*amount
	var room: int = model.cargo_room(ship_id,good) if buy else 80-model.held(target,good)
	if model.held(source,good)<amount or room<amount or (buy and model.gold<payment):
		return model.note("Check cargo, stocks, hold capacity, and gold.",false)
	model.adjust(source,good,-amount)
	model.adjust(target,good,amount)
	model.gold += -payment if buy else payment
	site.exchanges = site.get("exchanges",0)+1
	change_grievance(site.nation,model.nation,-6 if "Exchange shelter" in site.buildings else -3)
	return model.note("Traded with %s." % site.name)


func offer_food(ship_id: int, id: int) -> bool:
	if model.finished or id < 0 or id >= settlements.size():
		return false
	var site := settlements[id]
	var ship: Dictionary = model.ships[ship_id]
	if ship.port != "America" or not model.port_access(ship.cell,site.cell) or ship.cargo.get("Food",0)<5:
		return model.note("Bring a ship alongside with five Food.",false)
	model.adjust(ship.cargo,"Food",-5)
	model.adjust(site.goods,"Food",5)
	change_grievance(site.nation,model.nation,-14)
	return model.note("Supplies offered. Grievance fell.")


func add_event(text: String) -> void:
	events.append("Turn %d / %s" % [model.turn,text])
	if events.size()>30:
		events.pop_front()


func snapshot() -> Dictionary:
	return {"settlements":settlements,"nations":nations,"borders":borders,"events":events,"next_id":next_id}


func restore(campaign, state: Dictionary) -> void:
	campaign_ref = weakref(campaign)
	settlements.assign(state.settlements)
	nations = state.nations
	borders = state.borders
	events.assign(state.events)
	next_id = state.next_id



func sites_by_cell() -> Dictionary:
	var result := {}
	for site in settlements:
		result[site.cell] = site
	return result


func breeding_stock(site: Dictionary) -> bool:
	for other in settlements:
		if other.id != site.id and other.goods.get("Horses",0)>=2 and distance(site.cell,other.cell)<=6:
			return true
	if european_herd_near(site.nation,model.nation):
		return true
	for town in model.rivals.settlements:
		if town.nation=="Spain" and distance(site.cell,town.cell)<=6:
			return true
	return false
