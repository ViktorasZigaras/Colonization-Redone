extends RefCounted

const COLORS := {"France":"#5e91db","England":"#c45655","Spain":"#d3ad50","Netherlands":"#e38b54","Portugal":"#56ab82"}
const NAMES := {"France":["Quebec","Port Royal","Montreal"],"England":["Jamestown","Plymouth","Boston"],"Spain":["Santo Domingo","Havana","San Juan"],"Netherlands":["New Amsterdam","Fort Orange","New Rotterdam"],"Portugal":["Olinda","Salvador","Recife"]}
const EXPORTS := {"France":"Furs","England":"Lumber","Spain":"Sugar","Netherlands":"Tobacco","Portugal":"Sugar"}
var factions: Array[Dictionary] = []
var settlements: Array[Dictionary] = []
var campaign_ref: WeakRef
var model:
	get: return campaign_ref.get_ref()


func start(campaign) -> void:
	campaign_ref = weakref(campaign)
	factions.clear()
	settlements.clear()
	for nation in NAMES:
		if nation == model.nation:
			continue
		var band: int = model.NATIONS.find(nation)
		var coast: Vector2i = model.brazil_coast() if nation=="Portugal" else choose_coast(11+band*10)
		if coast != model.NONE and blocked(coast):
			coast = choose_coast(coast.y)
		if coast == Vector2i(-1,-1):
			coast = choose_coast(model.dimensions.y/2,model.dimensions.y)
		if coast == Vector2i(-1,-1):
			continue
		var entry: Vector2i = model.water_beside(coast)
		var start_cell := entry
		for x in range(entry.x+1,mini(model.dimensions.x,entry.x+7)):
			var next := Vector2i(x,entry.y)
			if not model.water(next):
				break
			start_cell = next
		factions.append({"nation":nation,"gold":300,"ship":start_cell,"goal":entry,"site":coast,"relation":"Peace","colonies":0,"status":"Seeking landfall"})


func choose_coast(row: int, radius := 10) -> Vector2i:
	for distance in range(radius):
		for direction in [-1,1]:
			var y: int = row+distance*direction
			for x in range(model.dimensions.x-5,8,-1):
				var cell := Vector2i(x,y)
				if not model.contains(cell) or model.water(cell) or model.kind(cell) in [8,10] or model.water_beside(cell)==Vector2i(-1,-1):
					continue
				if blocked(cell) or maxi(absi(cell.x-model.ships[0].cell.x),absi(cell.y-model.ships[0].cell.y)) < 5:
					continue
				return cell
	return Vector2i(-1,-1)


func blocked(cell: Vector2i) -> bool:
	for t in model.towns+settlements+model.indigenous.settlements:
		if model.nearby(t.cell,cell):
			return true
	return false


func tick() -> void:
	for faction in factions:
		reveal_coast(faction)
		if faction.ship != faction.goal:
			var state := {"cell":faction.ship,"moves":3}
			model.follow_water_path(state,faction.goal,false)
			if state.cell == faction.ship and faction.get("expedition",false):
				faction.expedition = false
				faction.goal = faction.ship
				faction.next_survey = model.turn+16
				record(faction,"Abandoned unreachable settlement site")
			faction.ship = state.cell
		elif faction.colonies == 0:
			settle(faction)
		elif faction.get("expedition",false):
			settle(faction)
		elif faction.colonies < NAMES[faction.nation].size() and model.turn >= faction.get("next_survey",0):
			plan_expansion(faction)
		if faction.relation == "War" and model.turn % 4 == 0:
			for ship in model.ships:
				if ship.port == "America" and model.nearby(ship.cell,faction.ship):
					var protected := false
					for town in model.towns:
						if model.nearby(ship.cell,town.cell) and model.colony_defense(town) >= 150:
							protected = true
							break
					if protected:
						continue
					ship.damage = mini(3,ship.damage+1)
					faction.status = "Harassed an enemy ship"
					break
		for town in settlements:
			if town.nation != faction.nation:
				continue
			town.goods.Food += 2 + int(model.local_yield(town.cell,"Food") >= 5)
			var good: String = EXPORTS[faction.nation]
			town.goods[good] = mini(model.capacity(town) if town.has("buildings") else 100,town.goods.get(good,0)+2+int(model.local_yield(town.cell,good)>0)+int(town.get("specialist","")!=""))
			if town.goods.Food >= 24:
				town.goods.Food -= 18
				town.population += 1
			manage_colony(town,faction,good)
		for town in settlements:
			if town.nation == faction.nation and "Dock" in town.get("buildings",[]):
				freight(faction,town,EXPORTS[faction.nation])
				break



func reveal_coast(faction: Dictionary) -> void:
	var seen: Dictionary = faction.get("survey",{})
	for cell in model.work_area(faction.ship):
		seen[cell] = true
	faction.survey = seen


func survey_route(faction: Dictionary, anchor: Vector2i) -> void:
	var seen: Dictionary = faction.survey
	var best: Vector2i = faction.ship
	var score := 0
	for cell in model.Hex.within(faction.ship,2):
		if not model.contains(cell) or not model.water(cell) or model.Hex.distance(anchor,cell)>9:
			continue
		var gain := 0
		for tile in model.work_area(cell):
			if not seen.has(tile):
				gain += 2 if not model.water(tile) else 1
		if gain <= score:
			continue
		var probe := {"cell":faction.ship,"moves":3}
		model.follow_water_path(probe,cell,false)
		if probe.cell == cell:
			best = cell
			score = gain
	if best != faction.ship:
		faction.goal = best
		record(faction,"Assigned coastal survey")


func plan_expansion(faction: Dictionary) -> void:
	faction.next_survey = model.turn+8
	var anchor: Dictionary = {}
	for town in settlements:
		if town.nation == faction.nation and "Dock" in town.get("buildings",[]) and town.population >= 4 and town.goods.Food >= 8:
			anchor = town
			break
	if anchor.is_empty() or faction.gold < 240 or faction.relation == "War":
		record(faction,"Deferred expansion for readiness")
		return
	var best := Vector2i(-1,-1)
	var best_score := -INF
	var export: String = EXPORTS[faction.nation]
	for site in model.Hex.within(anchor.cell,9):
		if not model.contains(site) or model.water(site) or model.kind(site) in [8,10] or blocked(site):
			continue
		if model.Hex.distance(site,anchor.cell)<3 or model.water_beside(site)==model.NONE or not faction.survey.has(site):
			continue
		var berth: Vector2i = model.water_beside(site)
		var probe := {"cell":faction.ship,"moves":1}
		model.follow_water_path(probe,berth,false)
		if faction.ship != berth and probe.cell == faction.ship:
			continue
		var food: int = model.local_yield(site,"Food")
		if food < 3:
			continue
		var pressure := 0
		for community in model.indigenous.settlements:
			if model.Hex.distance(site,community.cell)<=3:
				var grievance: int = model.indigenous.nations[community.nation].grievance.get(faction.nation,0)
				pressure += 1 + grievance/15
		var score: float = food*3+model.local_yield(site,export)*2+int(model.has_harbor(site))*4-pressure*2-model.Hex.distance(anchor.cell,site)*0.75
		if score > best_score:
			best_score = score
			best = site
	if best == model.NONE:
		record(faction,"Deferred expansion for site")
		survey_route(faction,anchor.cell)
		return
	faction.gold -= 60
	anchor.goods.Food -= 8
	faction.site = best
	faction.goal = model.water_beside(best)
	faction.expedition = true
	faction.status = "Sailing to proposed settlement"
	record(faction,"Dispatched settlement expedition")


func settle(faction: Dictionary) -> void:
	var site: Vector2i = faction.site
	if blocked(site):
		if faction.get("expedition",false):
			faction.expedition = false
			record(faction,"Abandoned blocked settlement site")
			return
		site = choose_coast(site.y+4)
		if site == model.NONE:
			return
		faction.site = site
		faction.goal = model.water_beside(site)
		if faction.ship != faction.goal:
			return
	var title: String = NAMES[faction.nation][faction.colonies]
	settlements.append({"nation":faction.nation,"name":title,"cell":site,"population":1,"goods":{"Food":8}})
	faction.colonies += 1
	faction.expedition = false
	faction.next_survey = model.turn+12
	faction.status = "Founded %s" % title
	record(faction,"Founded settlement")


func relation(nation: String, next: String) -> bool:
	for faction in factions:
		if faction.nation == nation:
			faction.relation = next
			return true
	return false


func trade(ship: int, town: int, good: String, count: int, buy: bool) -> bool:
	var s: Dictionary = model.ships[ship]
	var t: Dictionary = settlements[town]
	if s.port != "America" or not model.port_access(s.cell,t.cell) or count <= 0:
		return model.note("Bring the ship beside the rival settlement.",false)
	for faction in factions:
		if faction.nation == t.nation and faction.relation != "Peace":
			return model.note("Open peaceful relations to trade.",false)
	var source: Dictionary = t.goods if buy else s.cargo
	var target: Dictionary = s.cargo if buy else t.goods
	var payment: int = model.price(good)*count
	if model.held(source,good)<count or (buy and (model.gold<payment or model.cargo_room(ship,good)<count)) or (not buy and model.held(target,good)+count>100):
		return model.note("Check cargo, stock, gold and hold capacity.",false)
	model.adjust(source,good,-count)
	model.adjust(target,good,count)
	model.gold += -payment if buy else payment
	return model.note("Traded with %s." % t.name)


func manage_colony(town: Dictionary, faction: Dictionary, export: String) -> void:
	if not town.has("buildings"):
		town.merge({"buildings":["Carpenter Shop"],"hammers":0,"project":"","specialist":"","overflow":0,"pressure":0})
	var goods: Dictionary = town.goods
	var limit: int = model.capacity(town)
	if goods.get(export,0) >= limit-3:
		town.overflow += 1
	else:
		town.overflow = maxi(0,town.overflow-1)
	for site in model.indigenous.settlements:
		if model.Hex.distance(site.cell,town.cell)<=4 and model.indigenous.nations[site.nation].grievance.get(town.nation,0)>=40:
			town.pressure += 1
			break
	var ore: int = model.local_yield(town.cell,"Ore")
	var cotton: int = model.local_yield(town.cell,"Cotton")
	var timber: int = model.local_yield(town.cell,"Lumber")
	var demand := construction_demand(town,faction,export,ore,cotton,timber)
	var threshold := 18
	produce_industry(town,faction,ore,cotton,timber)
	var reserve := 300 if not faction.has("freight") else 120
	var best := ""
	var best_score := 0
	for project in model.BUILDINGS:
		if model.building_block(town,town.population,project) != "":
			continue
		count_use(faction,"eligible",project)
		if demand[project] < threshold:
			continue
		count_use(faction,"wanted",project)
		var tools: int = model.BUILDINGS[project][1]
		var price: int = maxi(1,model.price("Tools"))+2
		if tools > goods.get("Tools",0) and (tools-goods.get("Tools",0))*price > faction.gold-reserve:
			if demand[project] >= threshold:
				record(faction,"Deferred "+project+" for budget")
			continue
		if demand[project] >= threshold and demand[project] > best_score:
			best = project
			best_score = demand[project]
	if town.project == "" and best != "":
		var needed: int = maxi(0,model.BUILDINGS[best][1]-goods.get("Tools",0))
		if needed > 0:
			var price: int = maxi(1,model.price("Tools"))+2
			faction.gold -= needed*price
			model.adjust(goods,"Tools",needed)
			faction.tools_purchased = faction.get("tools_purchased",0)+needed
			record(faction,"Bought tools for "+best)
		town.project = best
		record(faction,"Queued "+best)
	if town.project != "":
		town.hammers += maxi(1,town.population/2)
		var project: String = town.project
		if model.complete_building(town,town.population):
			record(faction,"Completed "+project)
	use_services(town,faction)
	if "Dock" in town.buildings:
		goods.Food += 1
	if town.population>=3 and town.specialist=="" and faction.gold>=120 and model.local_yield(town.cell,export)>0:
		for name in model.Catalog.PROFESSIONS:
			if model.Catalog.PROFESSIONS[name][0] == export:
				town.specialist=name
				faction.gold-=120
				record(faction,"Hired "+name)
				break
	if town.specialist!="" and goods.get(export,0)>=3:
		var product: String = {"Furs":"Coats","Lumber":"Hammers","Sugar":"Rum","Tobacco":"Cigars"}[export]
		if product == "Hammers":
			if town.project == "":
				return
			town.hammers += 3
		else:
			if goods.get(product,0)>=limit:
				return
			goods[product] = mini(limit,goods.get(product,0)+3)
		goods[export] -= 3


func count_use(faction: Dictionary, ledger: String, building: String) -> void:
	if not faction.has(ledger):
		faction[ledger] = {}
	model.adjust(faction[ledger],building,1)


func construction_demand(town: Dictionary, faction: Dictionary, export: String, ore: int, cotton: int, timber: int) -> Dictionary:
	var goods: Dictionary = town.goods
	var sugar: int = model.local_yield(town.cell,"Sugar")
	var tobacco: int = model.local_yield(town.cell,"Tobacco")
	var furs: int = model.local_yield(town.cell,"Furs")
	var market: int = goods.get(export,0)
	var repair: int = faction.get("freight",{}).get("wear",0)
	var pressure: int = town.pressure
	var docks: bool = "Dock" in town.buildings
	return {
		"Dock":23,"Warehouse":town.overflow*3,"Warehouse Expansion":town.overflow*3-12,
		"Drydock":repair*14+int(market>=70)*18,"Shipyard":market/3+repair*7,
		"Stockade":pressure*2,"Fort":pressure*2-32,"Fortress":pressure*2-75,
		"Carpenter Shop":timber*5,"Lumber Mill":timber*5,
		"Blacksmith House":ore*8,"Blacksmith Shop":ore*7,"Iron Works":ore*7+int(goods.get("Tools",0)<30)*8,
		"Weaver House":cotton*7,"Weaver Shop":cotton*6,"Textile Mill":cotton*6,
		"Tobacconist House":tobacco*6,"Tobacconist Shop":tobacco*6,"Cigar Factory":tobacco*6,
		"Distiller House":sugar*6,"Rum Distillery":sugar*6,"Rum Factory":sugar*6,
		"Fur Trader House":furs*6,"Fur Trading Post":furs*6,"Fur Factory":furs*6,
		"Armory":pressure*2+int(goods.get("Tools",0)>=35)*12,"Magazine":pressure*2-15,"Arsenal":pressure*2-40,
		"Stables":int(goods.Food>=14 and (pressure>=8 or model.local_yield(town.cell,"Food")>=5))*20,
		"Church":town.population*3,"Cathedral":town.population*2+int(town.get("crosses",0)>=12)*12,
		"Schoolhouse":town.population*3+int(docks)*6,"College":town.population*2+int(ore+cotton>=5)*10,
		"University":town.population*2+int(town.get("trained",0)>=2)*10,
	}


func use_services(town: Dictionary, faction: Dictionary) -> void:
	var buildings: Array = town.buildings
	var goods: Dictionary = town.goods
	for building in ["Stockade","Fort","Fortress","Warehouse","Warehouse Expansion","Dock"]:
		if building in buildings and (not building.begins_with("Warehouse") or goods.values().max()>100):
			count_use(faction,"used",building)
	if "Stables" in buildings and goods.Food>=10 and goods.get("Horses",0)<40:
		goods.Food -= 2
		model.adjust(goods,"Horses",2)
		count_use(faction,"used","Stables")
	var church := "Cathedral" if "Cathedral" in buildings else "Church"
	if church in buildings:
		town.crosses = town.get("crosses",0)+(3 if church=="Cathedral" else 1)
		if town.crosses>=30:
			town.crosses -= 30
			town.population += 1
		count_use(faction,"used",church)
	var school := "University" if "University" in buildings else ("College" if "College" in buildings else "Schoolhouse")
	if school in buildings and goods.Food>=10:
		town.study = town.get("study",0)+1
		if town.study>=12:
			town.study = 0
			town.trained = mini(4,town.get("trained",0)+1)
			count_use(faction,"used",school)
	var berth := "Shipyard" if "Shipyard" in buildings else "Drydock"
	var ship: Dictionary = faction.get("freight",{})
	if berth in buildings and ship.get("phase","")=="America" and model.port_access(ship.cell,town.cell) and ship.get("wear",0)>0:
		ship.wear = 0
		count_use(faction,"used",berth)


func produce_industry(town: Dictionary, faction: Dictionary, ore: int, cotton: int, timber: int) -> void:
	var limit: int = model.capacity(town)
	for chain in [
		[["Blacksmith House","Blacksmith Shop","Iron Works"],"Ore","Tools",ore],
		[["Weaver House","Weaver Shop","Textile Mill"],"Cotton","Cloth",cotton],
		[["Carpenter Shop","Lumber Mill"],"Lumber","Hammers",timber],
		[["Tobacconist House","Tobacconist Shop","Cigar Factory"],"Tobacco","Cigars",model.local_yield(town.cell,"Tobacco")],
		[["Distiller House","Rum Distillery","Rum Factory"],"Sugar","Rum",model.local_yield(town.cell,"Sugar")],
		[["Fur Trader House","Fur Trading Post","Fur Factory"],"Furs","Coats",model.local_yield(town.cell,"Furs")],
		[["Armory","Magazine","Arsenal"],"Tools","Muskets",maxi(0,town.goods.get("Tools",0)-30)]
	]:
		var tier := 0
		for i in range(chain[0].size()):
			if chain[0][i] in town.buildings:
				tier = i+1
		if tier==0 or chain[3]<=0:
			continue
		var product: String = chain[2]
		if product=="Hammers" and town.project=="":
			continue
		var amount: int = mini(chain[3],tier+1+int(town.get("trained",0)>0))
		if product!="Hammers":
			amount = mini(amount,limit-town.goods.get(product,0))
		if amount<=0:
			continue
		if product=="Hammers":
			town.hammers += amount
		else:
			model.adjust(town.goods,product,amount)
		if chain[1]=="Tools":
			model.adjust(town.goods,"Tools",-amount)
		count_use(faction,"used",chain[0][tier-1])
		faction.industry_output = faction.get("industry_output",{})
		model.adjust(faction.industry_output,product,amount)


func freight(faction: Dictionary, town: Dictionary, export: String) -> void:
	if not faction.has("freight"):
		if faction.gold < 180 or town.goods.get(export,0)<20:
			return
		faction.gold -= 180
		record(faction,"Commissioned merchant vessel")
		faction.freight = {"phase":"America","turns":0,"cargo":{},"cell":faction.ship}
	var ship: Dictionary = faction.freight
	if ship.turns > 0:
		ship.turns -= 1
		if ship.turns != 0:
			return
		if ship.phase == "Europe":
			for good in ship.cargo:
				faction.gold += ship.cargo[good]*model.price(good)
			record(faction,"Sold shipment in Europe")
			ship.cargo.clear()
			ship.phase = "Return"
			ship.turns = 3
		else:
			ship.phase = "America"
			ship.wear = mini(3,ship.get("wear",0)+1)
		return
	var berth: Vector2i = model.water_beside(town.cell)
	if berth == model.NONE:
		return
	var state := {"cell":ship.cell,"moves":maxi(1,4-ship.get("wear",0))}
	model.follow_water_path(state,berth,false)
	ship.cell=state.cell
	if ship.cell != berth:
		return
	var product: String = {"Furs":"Coats","Lumber":"Lumber","Sugar":"Rum","Tobacco":"Cigars"}[export]
	for good in [product,export,"Cloth","Coats","Cigars","Rum"]:
		if not ship.cargo.has(good) and town.goods.get(good,0)>=10:
			ship.cargo[good] = mini(30,town.goods[good])
			town.goods[good] -= ship.cargo[good]
	if not ship.cargo.is_empty():
		ship.phase = "Europe"
		ship.turns = 3
		record(faction,"Dispatched freight")


func record(faction: Dictionary, entry: String) -> void:
	if not faction.has("decisions"):
		faction.decisions = []
		faction.tally = {}
	faction.decisions.append("Turn %d / %s" % [model.turn,entry])
	if faction.decisions.size()>24:
		faction.decisions.pop_front()
	faction.tally[entry] = faction.tally.get(entry,0)+1


