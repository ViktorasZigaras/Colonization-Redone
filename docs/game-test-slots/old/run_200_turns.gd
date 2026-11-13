extends SceneTree

const Model = preload("res://campaign.gd")
const CASES := [
	["A","Historical / France / observe",1492,false,1492,"France","observe",1,1],
	["B","Historical / France / frontier colony",1492,false,1492,"France","colony",1,1],
	["C","Historical / Portugal / observe",1492,false,1492,"Portugal","observe",1,1],
	["D","Historical / France / 1550 horse contact",1550,false,1492,"France","horses",1,1],
	["E","Historical / France / 1550 contact and gifts",1550,false,1492,"France","gifts",1,1],
	["F","Generated / mixed",1492,true,7,"France","observe",1,1],
	["G","Generated / large and wet",1492,true,17,"England","observe",2,2],
	["H","Generated / small and dry / late start",1550,true,999,"Netherlands","observe",0,0],
]
const TURN_COUNT := 200
const SAMPLE_TURNS := [0,25,50,100,150,200]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the output JSON path after --.")
		quit(2)
		return
	var file := FileAccess.open(args[0],FileAccess.WRITE)
	if file == null:
		push_error("Could not open output file.")
		quit(2)
		return
	var bytes := FileAccess.get_file_as_bytes("res://data/AMER2.MP")
	var results := []
	var failures := 0
	for scenario in CASES:
		if args.size() > 1 and scenario[0] != args[1]:
			continue
		var result := simulate(scenario,bytes)
		results.append(result)
		failures += int(result.has("failure"))
		print("%s %s" % [scenario[0],JSON.stringify(result.get("final",result))])
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"build":"v018-survey-and-industry","turns_requested":TURN_COUNT,"runs":results},"  "))
	file.close()
	quit(1 if failures else 0)


func simulate(scenario: Array, bytes: PackedByteArray) -> Dictionary:
	var m := Model.new()
	var result := {"id":scenario[0],"name":scenario[1],"year":scenario[2],"generated":scenario[3],"seed":scenario[4],"nation":scenario[5],"policy":scenario[6],"mass":scenario[7],"climate":scenario[8],"samples":[],"events":[],"gifts":0}
	if not m.start(bytes,{"year":scenario[2],"random":scenario[3],"seed":scenario[4],"nation":scenario[5],"mass":scenario[7],"climate":scenario[8],"target":1800}):
		result.failure = "Campaign setup failed."
		return result
	var contact_index := -1
	if scenario[6] != "observe":
		contact_index = setup_contact(m)
		if contact_index < 0:
			result.failure = "Contact fixture could not be established."
			return result
		result.contact = {"community":m.indigenous.settlements[contact_index].name,"colony_cell":str(m.towns[0].cell),"ship_cell":str(m.ships[0].cell)}
		if scenario[6] in ["horses","gifts"]:
			m.ships[0].cargo.Horses = 2
	var tally := new_ledger(m)
	var seen := {}
	observe_use(m,tally,seen,true)
	for step in range(TURN_COUNT+1):
		if step in SAMPLE_TURNS:
			result.samples.append(snapshot(m,step))
		var issue := validate(m)
		if issue != "":
			result.failure = "After %d turns: %s" % [step,issue]
			break
		if step == TURN_COUNT:
			break
		if m.finished:
			result.failure = "Campaign finished before 200 turns."
			break
		if scenario[6] == "gifts" and step % 4 == 0:
			# Fixture supplies food to isolate the effect of regular gifts.
			m.ships[0].cargo.Food = 5
			result.gifts += int(m.indigenous.offer_food(0,contact_index))
		
		var active_turn := m.turn
		m.end_turn()
		observe_use(m,tally,seen,false)
		for entry in m.indigenous.events:
			if entry.begins_with("Turn %d / " % active_turn):
				result.events.append(entry)
	result.final = snapshot(m,m.turn-1)
	result.use = tally
	result.inventory = inventory(m)
	result.rival_decisions = {}
	result.survey = {}
	result.industry = {}
	result.rival_buildings = {}
	result.rival_colonies_by_nation = {}
	result.tools_purchased = 0
	for faction in m.rivals.factions:
		result.survey[faction.nation] = faction.get("survey",{}).size()
		result.industry[faction.nation] = faction.get("industry_output",{})
		result.rival_decisions[faction.nation] = faction.get("tally",{})
		result.tools_purchased += faction.get("tools_purchased",0)
	for town in m.rivals.settlements:
		add(result.rival_colonies_by_nation,town.nation,1)
		for building in town.get("buildings",[]):
			add(result.rival_buildings,building,1)
	return result


func setup_contact(m: Model) -> int:
	for id in range(m.indigenous.settlements.size()):
		var site := m.indigenous.settlements[id]
		if site.nation != "Mi'kmaq":
			continue
		for berth: Vector2i in m.Hex.neighbors(site.cell):
			if not m.contains(berth) or not m.water(berth):
				continue
			for cell: Vector2i in m.Hex.neighbors(berth):
				if not m.contains(cell) or m.water(cell) or m.kind(cell) in [8,10] or m.indigenous.site_at(cell):
					continue
				m.ships[0].cell=berth
				if m.land(0,0,cell) and m.found(0,"Frontier test colony"):
					return id
	return -1


func snapshot(m: Model, turns: int) -> Dictionary:
	var population := 0
	var horses := 0
	var enclosures := 0
	var groups := {}
	var max_grievance := 0
	var projects := 0
	for site in m.indigenous.settlements:
		population += site.population
		horses += int(site.goods.get("Horses",0))
		enclosures += int("Horse enclosure" in site.buildings)
		projects += site.buildings.size()
		groups[site.nation] = groups.get(site.nation,0)+1
	var adopters := []
	for name in m.indigenous.nations:
		var state: Dictionary = m.indigenous.nations[name]
		if state.horses:
			adopters.append(name)
		max_grievance = maxi(max_grievance,state.grievance.get(m.nation,0))
	return {"turns":turns,"indigenous_sites":m.indigenous.settlements.size(),"population":population,"buildings":projects,"owners":groups,"horse_nations":adopters,"enclosures":enclosures,"horses":horses,"player_grievance_max":max_grievance,"rival_colonies":m.rivals.settlements.size(),"player_colonies":m.towns.size(),"player_food":m.towns[0].goods.get("Food",0) if not m.towns.is_empty() else 0}


func validate(m: Model) -> String:
	var cells := {}
	var ids := {}
	for site in m.indigenous.settlements:
		if not m.contains(site.cell) or m.water(site.cell) or cells.has(site.cell) or ids.has(site.id):
			return "Invalid or duplicate settlement coordinate or ID."
		cells[site.cell] = true
		ids[site.id] = true
		if site.population < 2 or site.population > 14 or not m.indigenous.nations.has(site.nation):
			return "Invalid settlement population or owner."
		for good in site.goods:
			if site.goods[good] < 0 or good == "Muskets":
				return "Negative stock or forbidden weapon in a settlement."
		if "Horse enclosure" in site.buildings and not m.indigenous.nations[site.nation].horses:
			return "Enclosure present without husbandry."
	for site in m.towns+m.rivals.settlements:
		if cells.has(site.cell):
			return "European and Indigenous settlements overlap."
		cells[site.cell] = true
	return ""




func new_ledger(m: Model) -> Dictionary:
	var buildings := {}
	for profile in m.indigenous.GROUPS.values():
		buildings[profile[1]] = {"initial":0,"completed":0,"final":0,"eligible_idle_turns":0,"queued_turns":0}
	for name in m.indigenous.BUILD:
		buildings[name] = {"initial":0,"completed":0,"final":0,"eligible_idle_turns":0,"queued_turns":0}
	return {"buildings":buildings,"peak_native_sites":0,"peak_european_sites":0}


func observe_use(m: Model,tally: Dictionary,seen: Dictionary,initial: bool) -> void:
	tally.peak_native_sites = maxi(tally.peak_native_sites,m.indigenous.settlements.size())
	tally.peak_european_sites = maxi(tally.peak_european_sites,m.rivals.settlements.size())
	for row in tally.buildings.values():
		row.final = 0
	for site in m.indigenous.settlements:
		var before: Array = seen.get(site.id,[])
		for name in site.buildings:
			var row: Dictionary = tally.buildings[name]
			row.final += 1
			if name not in before:
				if initial:
					row.initial += 1
				else:
					row.completed += 1
		seen[site.id] = site.buildings.duplicate()
		var choices: Array = [m.indigenous.GROUPS[site.nation][1],"Food store","Palisade","Exchange shelter"]
		if m.indigenous.nations[site.nation].horses:
			choices.append("Horse enclosure")
		if site.project != "":
			tally.buildings[site.project].queued_turns += int(not initial)
		elif not initial:
			for name in choices:
				var costs: Array = m.indigenous.BUILD.get(name,[14,5,2])
				if name not in site.buildings and site.population >= costs[2]:
					tally.buildings[name].eligible_idle_turns += 1


func inventory(m: Model) -> Dictionary:
	var result := {"player_buildings":{},"player_professions":{},"player_training":{},"player_ships":{},"player_jobs":{},"player_roles":{},"player_stores":{},"player_cargo":{},"rival_stores":{},"indigenous_stores":{},"rival_expedition_ships":m.rivals.factions.size(),"routes":{"ship":0,"wagon":m.wagons.size()}}
	for t in m.towns:
		for name in t.buildings:
			add(result.player_buildings,name,1)
		add_goods(result.player_stores,t.goods)
	for p in m.people:
		if p.location == "lost":
			continue
		add(result.player_professions,p.skill if p.skill != "" else "Untrained",1)
		add(result.player_jobs,p.job if p.job != "" else "Unassigned",1)
		add(result.player_roles,p.role if p.role != "" else "Unequipped",1)
		if p.study > 0:
			add(result.player_training,p.training,1)
	for ship in m.ships:
		add(result.player_ships,ship.type,1)
		add_goods(result.player_cargo,ship.cargo)
		result.routes.ship += int(ship.route_on)
	for t in m.rivals.settlements:
		add_goods(result.rival_stores,t.goods)
	for t in m.indigenous.settlements:
		add_goods(result.indigenous_stores,t.goods)
	return result


func add_goods(target: Dictionary,source: Dictionary) -> void:
	for name in source:
		add(target,name,source[name])


func add(target: Dictionary,name: String,amount: int) -> void:
	target[name] = target.get(name,0)+amount

