extends Control

const Campaign = preload("res://campaign.gd")
const Map = preload("res://campaign_map.gd")
const ArtSets = preload("res://art_sets.gd")
const Surfaces = preload("res://colony_surfaces.gd")
const ColonyArt = preload("res://colony_art.gd")
const INK := Color("#172321")
const PAPER := Color("#e8ddc1")
const GOLD := Color("#e4b56c")
const MUTED := Color("#b2bdad")

var model := Campaign.new()
var map := Map.new()
var sidebar: VBoxContainer
var yield_buttons: Array[Button] = []
var colony_screen: PanelContainer
var colony_orders: VBoxContainer
var colony_title: Label
var surface_panels: Array[Array] = []
var colony_stock: HBoxContainer
var colony_choice: PopupPanel
var colony_workers: HFlowContainer
var colony_map: Map
var colony_status: Label
var colony_buildings: Control
var transport_line: Label
var scroll: ScrollContainer
var summary: Label
var status: Label
var tile_info: Label
var panel := "Fleet"
var fleet := 0
var person := 0
var town := 0
var route_stop := 0
var cell := Campaign.NONE
var field_job := "Food"
var ship_good := "Lumber"
var quantity := 10
var skill := "Food"
var role := "Pioneer"
var slot := 1
var world_type := "Historical America"
var difficulty := "Standard"
var leader := "Test"
var nation := "France"
var seed_value := 1492
var rebuild_pending := false
var stats: Label
var minimap := preload("res://minimap.gd").new()
var mass := 1
var form := 1
var climate := 1
var temperature := 1
var report_page := "Overview"
var epitaph := ""
var rival_index := 0
var rival_town := 0
var community_index := 0
var show_hints := true
var autosave := false
var preferences := ConfigFile.new()


func _ready() -> void:
	var frame := VBoxContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("separation",0)
	var skin := Theme.new()
	skin.default_font_size = 16
	skin.set_color("font_color","Label",PAPER)
	frame.theme = skin
	add_child(frame)
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel",background(INK,12))
	frame.add_child(header)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation",5)
	header.add_child(bar)
	var title := caption("Colonial Campaign",20,GOLD)
	bar.add_child(title)
	stats = caption("",14,PAPER)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(stats)
	for tab in ["Fleet","Europe","Colony","People","Rivals","Communities","Reports","Campaign"]:
		button(bar,tab,set_panel.bind(tab))
	yield_buttons.append(button(bar,"Yields",toggle_yields))
	button(bar,"End turn",end_turn)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation",0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(body)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(map)
	var aside := PanelContainer.new()
	aside.custom_minimum_size.x = 375
	aside.add_theme_stylebox_override("panel",background(INK,12))
	body.add_child(aside)
	var stack := VBoxContainer.new()
	aside.add_child(stack)
	summary = caption("",20,GOLD)
	stack.add_child(summary)
	stack.add_child(minimap)
	minimap.model = model
	minimap.camera = map
	minimap.centered.connect(center_on)
	tile_info = caption("",14,MUTED)
	tile_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile_info.custom_minimum_size.y = 44
	stack.add_child(tile_info)
	stack.add_child(HSeparator.new())
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	sidebar = VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sidebar)
	status = caption("",15,PAPER)
	status.custom_minimum_size.y = 49
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(HSeparator.new())
	stack.add_child(status)
	map.setup(model)
	build_colony_screen(frame.theme)
	load_preferences()
	apply_art()
	map.picked.connect(pick)
	map.inspected.connect(inspect)
	map.redraw_requested.connect(minimap.queue_redraw)
	model.changed.connect(refresh)
	new_game()


func caption(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	return label


func background(color: Color, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_content_margin_all(margin)
	return box


func button(parent: Node, title: String, action: Callable) -> Button:
	var control := Button.new()
	control.text = title
	control.custom_minimum_size.y = 31
	control.pressed.connect(action)
	parent.add_child(control)
	return control


func buttons(entries: Array) -> void:
	var row := HBoxContainer.new()
	sidebar.add_child(row)
	for entry in entries:
		var control := button(row,entry[0],entry[1])
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func choice(title: String, values: Array, current: int, action: Callable) -> void:
	sidebar.add_child(caption(title,14,MUTED))
	var menu := OptionButton.new()
	sidebar.add_child(menu)
	for value in values:
		menu.add_item(str(value))
	if values.is_empty():
		menu.disabled = true
	else:
		menu.select(clampi(current,0,values.size()-1))
	menu.item_selected.connect(action)


func text_line(text: String) -> void:
	var line := caption(text,15,PAPER)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(line)


func set_panel(next: String) -> void:
	if panel != next:
		scroll.scroll_vertical = 0
	panel = next
	refresh()


func set_index(index: int, key: StringName) -> void:
	set(key,index)
	refresh()


func choose_value(index: int, choices: Array, key: StringName) -> void:
	set(key,choices[index])
	refresh()


func refresh() -> void:
	if model.ships.is_empty():
		return
	fleet = clampi(fleet,0,model.ships.size()-1)
	person = clampi(person,0,model.people.size()-1)
	town = clampi(town,0,maxi(0,model.towns.size()-1))
	route_stop = clampi(route_stop,0,maxi(0,model.towns.size()-1))
	var year := model.year + (model.turn-1)/2
	stats.text = "%s / %s    %s %d    %d gold" % [model.nation,model.leader,"Spring" if model.turn%2 else "Autumn",year,model.gold]
	summary.text = panel
	status.text = model.report
	if not rebuild_pending:
		rebuild_pending = true
		call_deferred("rebuild")


func rebuild() -> void:
	rebuild_pending = false
	colony_screen.visible = panel == "Colony" and not model.towns.is_empty()
	if colony_screen.visible:
		refresh_colony_screen()
	map.area_center = Campaign.NONE
	map.queue_redraw()
	for child in sidebar.get_children():
		sidebar.remove_child(child)
		child.queue_free()
	match panel:
		"Fleet": fleet_panel()
		"Europe": europe_panel()
		"Rivals": rivals_panel()
		"Communities": communities_panel()
		"Colony":
			if not colony_screen.visible:
				colony_panel()
		"People": people_panel()
		"Reports": reports_panel()
		"Campaign": campaign_panel()


func goods_line(goods: Dictionary) -> String:
	var items: Array[String] = []
	for good in goods:
		if goods[good]>0:
			items.append("%d %s" % [goods[good],good.to_lower()])
	return ", ".join(items) if not items.is_empty() else "Empty"


func fleet_panel() -> void:
	var labels := []
	for id in range(model.ships.size()):
		labels.append("%d. %s / %s" % [id+1,model.ships[id].type,model.ships[id].port])
	choice("Vessel",labels,fleet,set_index.bind(&"fleet"))
	var s := model.ships[fleet]
	text_line("%d moves / %d free holds / %d wear\nCargo: %s" % [s.moves,model.free_holds(fleet),s.damage,goods_line(s.cargo)])
	if s.port == "At sea":
		text_line("%s in %d turns" % [s.destination,s.trip])
	if s.port == "America":
		var names := []
		var ids := model.passengers(fleet)
		for id in ids:
			names.append(model.people[id].name)
		if not ids.is_empty():
			choice("Passenger for landfall",names,maxi(0,ids.find(person)),choose_passenger.bind(ids))
		if show_hints:
			text_line("Click water to sail. Click adjacent land to disembark.")
		button(sidebar,"Center ship",center_on.bind(s.cell))
		button(sidebar,"Plot course to selected water",model.set_course.bind(fleet,cell))
	buttons([["Depart / reverse",model.depart.bind(fleet,true)],["Recruit",model.recruit.bind(fleet,"")],["Hire specialist",model.recruit.bind(fleet,skill)]])
	var careers := Campaign.Catalog.PROFESSIONS.keys()
	choice("Specialist to hire",careers,careers.find(skill),choose_value.bind(careers,&"skill"))
	choice("Cargo good",Campaign.GOODS,Campaign.GOODS.find(ship_good),choose_value.bind(Campaign.GOODS,&"ship_good"))
	var amount := SpinBox.new()
	amount.min_value=1
	amount.max_value=600
	amount.value=quantity
	sidebar.add_child(amount)
	amount.value_changed.connect(set_amount)
	if s.port == "Europe":
		text_line("Buy %d / sell %d / tax %d%%" % [model.price(ship_good)+1,model.price(ship_good),model.tax])
		buttons([["Buy",trade.bind(true)],["Sell",trade.bind(false)]])
		for type in Campaign.SHIPS:
			button(sidebar,"Buy %s / %d gold" % [type,Campaign.SHIPS[type][2]],model.order_ship.bind(type))
	if not model.towns.is_empty():
		town_picker("Cargo colony","town",town)
		buttons([["Load",transfer.bind(true)],["Unload",transfer.bind(false)],["Repair",model.repair.bind(fleet,town)]])
	if model.towns.size()>1:
		town_picker("Route unload stop","route_stop",route_stop)
		buttons([["Run route",configure_route],["Stop route",stop_route]])
		button(sidebar,"Build wagon route",start_wagon)
		if s.route_on:
			var stops: Array = s.get("stops",[])
			var next: int = s.route[s.leg] if stops.is_empty() else stops[s.leg].town
			text_line("Route active. Next stop: %s" % model.towns[next].name)
		var custom: Array = s.get("stops",[])
		buttons([["Add load rule",add_route_rule.bind(true)],["Add unload rule",add_route_rule.bind(false)]])
		buttons([["Run custom route",run_custom_route],["Clear custom route",clear_custom_route]])
		for stop in custom:
			for rule in stop.rules:
				text_line("%s / %s %d %s" % [model.towns[stop.town].name,"Load" if rule.load else "Unload",rule.amount,rule.good])


func choose_passenger(index: int, ids: Array) -> void:
	person = ids[index]


func set_amount(value: float) -> void:
	quantity = int(value)


func trade(buy: bool) -> void:
	model.trade(fleet,ship_good,quantity,buy)


func transfer(load_cargo: bool) -> void:
	model.transfer(fleet,town,ship_good,quantity,load_cargo)


func configure_route() -> void:
	model.configure_route(fleet,town,route_stop,ship_good,quantity)


func stop_route() -> void:
	if model.finished:
		return
	model.ships[fleet].route_on=false
	model.note("Trade route paused.")


func town_picker(title: String, key: StringName, selected: int) -> void:
	var names := []
	for place in model.towns:
		names.append(place.name)
	choice(title,names,selected,set_index.bind(key))


func colony_panel() -> void:
	if model.towns.is_empty():
		text_line("Disembark a colonist, then found a colony from People.")
		return
	var t := model.towns[town]
	text_line("Production")
	if t.project != "":
		var cost: Array = Campaign.BUILDINGS[t.project]
		text_line("%s   %d / %d hammers" % [t.project,t.hammers,cost[0]])
		var progress := ProgressBar.new()
		progress.max_value = cost[0]
		progress.value = t.hammers
		progress.show_percentage = false
		sidebar.add_child(progress)
		buttons([["Rush",model.construction.bind(town,t.project,true)],["Pause",model.construction.bind(town,"")]])
	else:
		text_line("%d hammers available" % t.hammers)
	var palette := HFlowContainer.new()
	sidebar.add_child(palette)
	var population := model.residents(town).size()
	for name in Campaign.BUILDINGS:
		if name in t.buildings:
			continue
		var costs: Array = Campaign.BUILDINGS[name]
		if costs[3] != "" and costs[3] not in t.buildings:
			continue
		var blocker := model.building_block(t,population,name)
		var hint := "%s\n%d hammers   %d tools   %d residents" % [name,costs[0],costs[1],costs[2]]
		if costs[3] != "":
			hint += "\nRequires "+costs[3]
		if blocker != "" and not hint.contains(blocker.trim_suffix(".")):
			hint += "\n"+blocker
		var entry := sprite_button(ColonyArt.building(name),hint,Vector2(61,47))
		if name == "Warehouse Expansion":
			entry.text = "2"
		entry.pressed.connect(model.construction.bind(town,name))
		if blocker != "":
			entry.modulate = Color("#9f9179")
		palette.add_child(entry)
	if "Shipyard" in t.buildings:
		for type in Campaign.SHIPS:
			var ship := sprite_button(Map.object_art(type),"Build "+type,Vector2(61,47))
			ship.pressed.connect(model.build_ship.bind(town,type))
			palette.add_child(ship)


func sprite_button(texture: Texture2D, hint: String, extent: Vector2) -> Button:
	var entry := Button.new()
	entry.icon = texture
	entry.expand_icon = true
	entry.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	entry.tooltip_text = hint
	entry.custom_minimum_size = extent
	return entry


func choices(title: String) -> HFlowContainer:
	if is_instance_valid(colony_choice):
		colony_choice.queue_free()
	colony_choice = PopupPanel.new()
	colony_choice.transparent_bg = false
	add_child(colony_choice)
	var panel_body := VBoxContainer.new()
	colony_choice.add_child(panel_body)
	panel_body.add_child(caption(title,17,GOLD))
	var palette := HFlowContainer.new()
	panel_body.add_child(palette)
	return palette


func show_choices() -> void:
	colony_choice.popup_centered(Vector2i(430,0))


func open_training(id: int) -> void:
	person = id
	var p := model.people[id]
	if p.skill != "" or p.study > 0 or p.job == "Teach":
		return
	var palette := choices("Train "+p.name)
	for name in Campaign.Catalog.PROFESSIONS:
		if model.training_block(id,name) != "":
			continue
		var details: Array = Campaign.Catalog.PROFESSIONS[name]
		var duration: int = details[2]+int(p.get("class","Free Colonist")!="Free Colonist")
		var entry := sprite_button(ColonyArt.resident(name),"%s\n%s   %d turns" % [name,details[0],duration],Vector2(50,58))
		entry.pressed.connect(start_training.bind(id,name))
		palette.add_child(entry)
	if palette.get_child_count()==0:
		colony_choice.queue_free()
		model.note("Training requires an available school slot.")
		return
	show_choices()


func start_training(id: int, name: String) -> void:
	colony_choice.hide()
	model.train(id,name)


func resident() -> int:
	var ids := model.residents(town)
	return person if person in ids else (ids[0] if not ids.is_empty() else -1)


func people_panel() -> void:
	var labels := []
	var ids := []
	for id in range(model.people.size()):
		var p := model.people[id]
		if p.location!="lost":
			ids.append(id)
			labels.append("%s / %s" % [p.name,p.location])
	choice("Colonist",labels,maxi(0,ids.find(person)),choose_person.bind(ids))
	var p := model.people[person]
	text_line("Skill: %s / Equipment: %s\nOrders: %s / Movement: %d" % [p.skill if p.skill!="" else p.get("class","Free Colonist"),p.role if p.role!="" else "None",p.order if p.order!="" else "Active",p.moves])
	if p.skill!="" or p.study>0:
		button(sidebar,"Clear specialty",model.clear_skill.bind(person))
	if p.study>0:
		text_line("Training in %s / %d turns" % [p.training,p.study])
	if p.location=="town":
		var roles := ["None","Pioneer","Scout","Soldier","Dragoon"]
		choice("Equipment",roles,roles.find(role),choose_value.bind(roles,&"role"))
		buttons([["Equip",equip],["Leave colony",model.leave_town.bind(person)]])
	elif p.location=="land":
		button(sidebar,"Center colonist",center_on.bind(p.cell))
		if model.site_available(p.cell):
			button(sidebar,"Survey site",model.explore_site.bind(person))
		buttons([["Found colony",model.found.bind(person,"")],["Board ship",model.board.bind(person,fleet)]])
		if not model.towns.is_empty():
			town_picker("Join settlement","town",town)
			button(sidebar,"Join selected colony",model.join_town.bind(person,town))
		buttons([["Sentry",model.order_land.bind(person,"Sentry")],["Fortify",model.order_land.bind(person,"Fortify")],["Activate",model.order_land.bind(person,"")]])
		buttons([["Clear",model.order_land.bind(person,"Clear")],["Plow",model.order_land.bind(person,"Plow")],["Road",model.order_land.bind(person,"Road")]])
		buttons([["Wait",cycle_person],["Skip",model.skip_person.bind(person)],["Disband",model.disband.bind(person)]])
		if show_hints:
			text_line("Click land to move. Terrain improvements require a pioneer.")


func choose_person(index: int, ids: Array) -> void:
	person=ids[index]
	refresh()


func equip() -> void:
	model.equip(person,"" if role=="None" else role)


func cycle_person() -> void:
	for offset in range(1,model.people.size()+1):
		var id := (person+offset)%model.people.size()
		if model.people[id].location=="land" and model.people[id].moves>0:
			person=id
			center_on(model.people[id].cell)
			refresh()
			return


func reports_panel() -> void:
	var pages := ["Overview","Trade history","Colony adviser","Labor adviser","Immigration adviser","Naval adviser"]
	choice("Adviser",pages,pages.find(report_page),choose_value.bind(pages,&"report_page"))
	match report_page:
		"Trade history":
			text_line(model.market_notice if model.market_notice != "" else "European prices are stable.")
			var history := model.ledger.duplicate()
			history.reverse()
			for item in history:
				text_line("Turn %d / %s %d %s / %+d gold" % [item.turn,"Bought" if item.buy else "Sold",item.amount,item.good,item.gold])
			return
		"Colony adviser":
			for id in range(model.towns.size()):
				var t := model.towns[id]
				text_line("%s / %d residents / %d hammers / %s" % [t.name,model.residents(id).size(),t.hammers,goods_line(t.goods)])
			return
		"Labor adviser":
			for p in model.people:
				if p.location != "lost":
					text_line("%s / %s / %s / %s" % [p.name,p.location,p.job,p.skill])
			return
		"Immigration adviser":
			text_line("%d awaiting passage / %d of 12 crosses" % [model.recruits,model.crosses])
			return
		"Naval adviser":
			for s in model.ships:
				text_line("%s / %s / %d wear / %s" % [s.type,s.port,s.damage,goods_line(s.cargo)])
			return
	text_line("Campaign score %d / target year %d\nImmigration pool %d / crosses %d of 12" % [model.score(),model.target_year,model.recruits,model.crosses])
	text_line("Colonies and warehouses")
	for id in range(model.towns.size()):
		var t := model.towns[id]
		text_line("%s / %d residents / %s" % [t.name,model.residents(id).size(),goods_line(t.goods)])
	text_line("Fleet")
	for s in model.ships:
		text_line("%s / %s / %s" % [s.type,s.port,goods_line(s.cargo)])
	text_line("Wagon routes")
	for wagon in model.wagons:
		text_line("%s to %s / %s / %d turns remaining" % [model.towns[wagon.first].name,model.towns[wagon.second].name,wagon.good,wagon.remaining])
	text_line("Labor")
	for p in model.people:
		if p.location!="lost":
			text_line("%s / %s / %s" % [p.name,p.location,p.job if p.job!="" else "Unassigned"])
	text_line("European sell prices")
	for good in Campaign.GOODS:
		text_line("%s  %d" % [good,model.price(good)])


func campaign_panel() -> void:
	choice("All art",ArtSets.MODES,ArtSets.mode("Terrain"),set_all_art)
	for category in ArtSets.CATEGORIES:
		choice(category+" art",ArtSets.MODES,ArtSets.mode(category),set_art.bind(category))
	var worlds := ["Historical America","Generated New World"]
	choice("World",worlds,worlds.find(world_type),choose_value.bind(worlds,&"world_type"))
	var nations := Campaign.NATIONS
	choice("Nation",nations,nations.find(nation),choose_value.bind(nations,&"nation"))
	var levels := ["Relaxed","Standard","Lean"]
	choice("Difficulty",levels,levels.find(difficulty),choose_value.bind(levels,&"difficulty"))
	var input := LineEdit.new()
	input.text=leader
	input.placeholder_text="Leader name"
	input.text_changed.connect(set_leader)
	sidebar.add_child(input)
	var seed_input := SpinBox.new()
	seed_input.min_value=0
	seed_input.max_value=2147483647
	seed_input.value=seed_value
	seed_input.prefix="Seed "
	seed_input.value_changed.connect(set_seed)
	sidebar.add_child(seed_input)
	if world_type != "Historical America":
		choice("Land mass",["Small","Medium","Large"],mass,set_index.bind(&"mass"))
		choice("Land form",["Archipelago","Mixed","Continents"],form,set_index.bind(&"form"))
		choice("Temperature",["Cool","Temperate","Warm"],temperature,set_index.bind(&"temperature"))
		choice("Climate",["Dry","Normal","Wet"],climate,set_index.bind(&"climate"))
	button(sidebar,"Start new campaign",new_game)
	choice("Save slot",["1","2","3","Autosave"],slot-1,select_slot)
	buttons([["Save",save],["Load",load_campaign]])
	var inscription := LineEdit.new()
	inscription.text = epitaph
	inscription.placeholder_text = "Epitaph for the Hall of Fame"
	inscription.text_changed.connect(set_epitaph)
	sidebar.add_child(inscription)
	button(sidebar,"Retire and score",retire)
	for entry in preferences.get_value("campaign","hall",[]):
		text_line("%s / %d points / %s" % [entry.leader,entry.score,entry.epitaph])
	text_line("Best score: %d" % int(preferences.get_value("campaign","best_score",0)))
	check("Fog of war",map.fog,set_map_flag.bind(&"fog"))
	check("Tile grid",map.grid,set_map_flag.bind(&"grid"))
	check("Terrain seams",map.seams,set_map_flag.bind(&"seams"))
	check("Context hints",show_hints,set_hint)
	check("Autosave after turns",autosave,set_autosave)


func check(title: String, enabled: bool, action: Callable) -> void:
	var toggle := CheckBox.new()
	toggle.text=title
	toggle.button_pressed=enabled
	sidebar.add_child(toggle)
	toggle.toggled.connect(action)


func set_leader(value: String) -> void:
	leader=value


func set_seed(value: float) -> void:
	seed_value=int(value)


func select_slot(index: int) -> void:
	slot=index+1


func set_hint(value: bool) -> void:
	show_hints=value
	save_preferences()


func set_autosave(value: bool) -> void:
	autosave=value
	save_preferences()


func set_all_art(index: int) -> void:
	for category in ArtSets.CATEGORIES:
		ArtSets.modes[category] = index
	save_preferences()
	apply_art()


func set_art(index: int, category: String) -> void:
	ArtSets.modes[category] = index
	save_preferences()
	apply_art()


func apply_art() -> void:
	map.rebuild_ground()
	colony_map.rebuild_ground()
	for panel in surface_panels:
		panel[0].add_theme_stylebox_override("panel",Surfaces.wood(panel[1],panel[2]))
	colony_screen.add_theme_stylebox_override("panel",Surfaces.wood(16,Color.WHITE) if ArtSets.mode("Surfaces")>0 else background(Color("#36281d"),16))
	refresh()


func set_map_flag(value: bool, key: StringName) -> void:
	map.set(key,value)
	save_preferences()
	map.queue_redraw()


func new_game() -> void:
	var options := {"nation":nation,"leader":leader if not leader.strip_edges().is_empty() else "Test","random":world_type!="Historical America","seed":seed_value,"mass":mass,"form":form,"climate":climate,"temperature":temperature,"gold":{"Relaxed":550,"Standard":350,"Lean":180}[difficulty],"tax":{"Relaxed":5,"Standard":10,"Lean":15}[difficulty]}
	if model.start(FileAccess.get_file_as_bytes("res://data/AMER2.MP"),options):
		reset_selection()
		set_panel("Fleet")


func reset_selection() -> void:
	fleet=0
	person=0
	town=0
	route_stop=0
	cell=Campaign.NONE
	map.selected=cell
	for s in model.ships:
		if s.port=="America":
			center_on(s.cell)
			break


func save() -> void:
	model.save(slot_path())


func load_campaign() -> void:
	if model.load_slot(slot_path()):
		reset_selection()
		refresh()


func end_turn() -> void:
	model.end_turn()
	if model.finished:
		record_score()
	if autosave:
		model.save("user://campaign-autosave.save")


func retire() -> void:
	model.finished=true
	record_score()
	model.note("Campaign retired. Final score %d." % model.score())


func center_on(where: Vector2i) -> void:
	if model.contains(where):
		map.center=Campaign.Hex.position(where)
		map.queue_redraw()
		minimap.queue_redraw()


func inspect(where: Vector2i) -> void:
	if not model.contains(where):
		tile_info.text=""
	elif map.fog and not model.explored.has(where):
		tile_info.text="Unexplored / %d, %d" % [where.x,where.y]
	else:
		tile_info.text="%s / %d, %d" % [model.tile_name(where),where.x,where.y]
		if (model.water(where) and model.water_beside_land(where)) or (not model.water(where) and model.water_beside(where) != Campaign.NONE):
			tile_info.text += " / Coastal"
		if model.feature(where) != "":
			tile_info.text += " / "+model.feature(where)
		var resource := model.tile_resource(where)
		if not resource.is_empty():
			tile_info.text += " / " + resource.name
		if model.site_available(where):
			tile_info.text+=" / uncharted site"


func pick(where: Vector2i, alternate: bool) -> void:
	cell=where
	map.selected=where
	inspect(where)
	if alternate:
		return
	for id in range(model.towns.size()):
		if model.towns[id].cell==where:
			town=id
			set_panel("Colony")
			return
	for id in range(model.ships.size()):
		if model.ships[id].port=="America" and model.ships[id].cell==where:
			fleet=id
			set_panel("Fleet")
			return
	for id in range(model.people.size()):
		if model.people[id].location=="land" and model.people[id].cell==where:
			person=id
			set_panel("People")
			return
	if model.finished:
		return
	for id in range(model.indigenous.settlements.size()):
		if model.indigenous.settlements[id].cell == where and (model.explored.has(where) or not map.fog):
			community_index = id
			set_panel("Communities")
			return
	if panel=="Fleet":
		if model.water(where):
			model.sail(fleet,where)
		else:
			var ids := model.passengers(fleet)
			if not ids.is_empty():
				person=person if person in ids else ids[0]
				if model.land(fleet,person,where):
					set_panel("People")
	elif panel=="People":
		model.walk(person,where)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: end_turn()
			KEY_F1: set_panel("Reports")
			KEY_F2: set_panel("Europe")
			KEY_F3: set_panel("Colony")
			KEY_F4: set_panel("People")
			KEY_F5: set_panel("Fleet")
			KEY_F6: set_panel("Campaign")
			KEY_F7: set_panel("Rivals")
			KEY_F8: set_panel("Communities")
			KEY_Z:
				map.zoom = minf(64,map.zoom*1.25)
				map.queue_redraw()
			KEY_X:
				map.zoom = maxf(8,map.zoom/1.25)
				map.queue_redraw()
			KEY_S:
				if event.ctrl_pressed:
					save()
			KEY_L:
				if event.ctrl_pressed:
					load_campaign()
			KEY_F:
				if model.found(person,""):
					town=model.towns.size()-1
					set_panel("Colony")


func slot_path() -> String:
	return "user://campaign-autosave.save" if slot == 4 else "user://campaign-%d.save" % slot



func start_wagon() -> void:
	model.start_wagon(town,route_stop,ship_good,quantity)



func load_preferences() -> void:
	if preferences.load("user://settings.cfg") != OK:
		return
	ArtSets.modes = preferences.get_value("display","art",{})
	map.fog = preferences.get_value("display","fog",true)
	map.grid = preferences.get_value("display","grid",false)
	map.seams = preferences.get_value("display","seams",true)
	show_hints = preferences.get_value("display","hints",true)
	autosave = preferences.get_value("campaign","autosave",false)


func save_preferences() -> void:
	preferences.set_value("display","art",ArtSets.modes)
	preferences.set_value("display","fog",map.fog)
	preferences.set_value("display","grid",map.grid)
	preferences.set_value("display","seams",map.seams)
	preferences.set_value("display","hints",show_hints)
	preferences.set_value("campaign","autosave",autosave)
	preferences.save("user://settings.cfg")


func record_score() -> void:
	var hall: Array = preferences.get_value("campaign","hall",[])
	var result := {"leader":model.leader,"score":model.score(),"epitaph":epitaph,"turn":model.turn,"nation":model.nation}
	if result not in hall:
		hall.append(result)
		hall.sort_custom(func(a,b): return a.score > b.score)
		preferences.set_value("campaign","hall",hall.slice(0,10))
		save_preferences()
	if model.score() > int(preferences.get_value("campaign","best_score",0)):
		preferences.set_value("campaign","best_score",model.score())
		save_preferences()


func add_route_rule(loading: bool) -> void:
	model.add_route_rule(fleet,town,ship_good,quantity,loading)


func run_custom_route() -> void:
	var s := model.ships[fleet]
	if model.finished or s.get("stops",[]).size() < 2:
		model.note("Add at least two stops.")
		return
	s.route_on = true
	s.course = Campaign.NONE
	model.note("Custom route started.")


func clear_custom_route() -> void:
	if model.finished:
		return
	var s := model.ships[fleet]
	s.stops = []
	s.route_on = false
	s.leg = 0
	model.note("Custom route cleared.")


func set_epitaph(value: String) -> void:
	epitaph = value


func europe_panel() -> void:
	var vessels := []
	for s in model.ships:
		vessels.append("%s / %s" % [s.type,s.port])
	choice("Harbor vessel",vessels,fleet,set_index.bind(&"fleet"))
	var s := model.ships[fleet]
	text_line("Docks: %d awaiting passage / %d free holds" % [model.recruits,model.free_holds(fleet)])
	if s.port != "Europe":
		text_line("Send a ship to Europe to use the harbor and docks.")
		return
	text_line("Harbor cargo: %s" % goods_line(s.cargo))
	text_line(model.market_notice)
	var careers := Campaign.Catalog.PROFESSIONS.keys()
	choice("Specialty",careers,careers.find(skill),choose_value.bind(careers,&"skill"))
	buttons([["Recruit",model.recruit.bind(fleet,"")],["Hire specialist",model.recruit.bind(fleet,skill)]])
	choice("Market good",Campaign.GOODS,Campaign.GOODS.find(ship_good),choose_value.bind(Campaign.GOODS,&"ship_good"))
	var amount := SpinBox.new()
	amount.min_value=1
	amount.max_value=600
	amount.value=quantity
	sidebar.add_child(amount)
	amount.value_changed.connect(set_amount)
	text_line("Buy %d / sell %d / tax %d%%" % [model.price(ship_good)+1,model.price(ship_good),model.tax])
	buttons([["Buy",trade.bind(true)],["Sell",trade.bind(false)]])
	for type in Campaign.SHIPS:
		button(sidebar,"Buy %s / %d gold" % [type,Campaign.SHIPS[type][2]],model.order_ship.bind(type))
	button(sidebar,"Buy artillery / 180 gold",model.purchase_artillery.bind(fleet))
	button(sidebar,"Depart for America",model.depart.bind(fleet))

func rivals_panel() -> void:
	var nations := []
	for faction in model.rivals.factions:
		nations.append(faction.nation)
	if nations.is_empty():
		text_line("There are no rival expeditions on this map.")
		return
	rival_index = clampi(rival_index,0,nations.size()-1)
	choice("European power",nations,rival_index,set_index.bind(&"rival_index"))
	var faction := model.rivals.factions[rival_index]
	text_line("%s / %s / %d gold" % [faction.nation,faction.relation,faction.gold])
	text_line(faction.status)
	for decision in faction.get("decisions",[]).slice(-3):
		text_line(decision)
	buttons([["Offer peace",diplomacy.bind("Peace")],["Declare war",diplomacy.bind("War")]])
	button(sidebar,"Engage vessel with selected ship",model.confront.bind(fleet,faction.nation))
	var towns := model.rivals.settlements
	if towns.is_empty():
		return
	var names := []
	for settlement in towns:
		names.append("%s / %s" % [settlement.name,settlement.nation])
	rival_town = clampi(rival_town,0,towns.size()-1)
	choice("Rival settlement",names,rival_town,set_index.bind(&"rival_town"))
	var t := towns[rival_town]
	map.area_center = t.cell if model.explored.has(t.cell) or not map.fog else Campaign.NONE
	map.queue_redraw()
	if model.explored.has(t.cell) or not map.fog:
		button(sidebar,"Center settlement",center_on.bind(t.cell))
	text_line("%d residents / %s" % [t.population,goods_line(t.goods)])
	choice("Trade good",Campaign.GOODS,Campaign.GOODS.find(ship_good),choose_value.bind(Campaign.GOODS,&"ship_good"))
	var amount := SpinBox.new()
	amount.min_value = 1
	amount.max_value = 100
	amount.value = quantity
	sidebar.add_child(amount)
	amount.value_changed.connect(set_amount)
	buttons([["Buy",rival_trade.bind(true)],["Sell",rival_trade.bind(false)]])
	button(sidebar,"Attack with selected land unit",model.attack_colony.bind(person,rival_town))


func diplomacy(relation: String) -> void:
	if not model.finished:
		model.rivals.relation(model.rivals.factions[rival_index].nation,relation)
		model.note("Relations updated.")


func rival_trade(buy: bool) -> void:
	if not model.finished:
		model.rivals.trade(fleet,rival_town,ship_good,quantity,buy)

func communities_panel() -> void:
	var ids := []
	var names := []
	for id in range(model.indigenous.settlements.size()):
		var site := model.indigenous.settlements[id]
		if map.fog and not model.explored.has(site.cell):
			continue
		ids.append(id)
		names.append(site.name)
	if ids.is_empty():
		text_line("Explore the coast to find communities.")
		return
	if community_index not in ids:
		community_index = ids[0]
	choice("Settlement",names,ids.find(community_index),choose_value.bind(ids,&"community_index"))
	var site := model.indigenous.settlements[community_index]
	map.area_center = site.cell
	map.queue_redraw()
	var state: Dictionary = model.indigenous.nations[site.nation]
	var profile: Array = model.indigenous.GROUPS[site.nation]
	text_line("%s / %d residents" % [site.nation,site.population])
	button(sidebar,"Center settlement",center_on.bind(site.cell))
	text_line("Local bonus: +%d %s with %s" % [profile[3],str(profile[2]).to_lower(),profile[1]])
	text_line("Store: %s" % goods_line(site.goods))
	text_line("Buildings: %s" % ", ".join(site.buildings))
	if site.project != "":
		text_line("Building %s / %d work" % [site.project,site.work])
	text_line("Contact: %d turns / Grievance: %d of 60" % [state.contact.get(model.nation,0),state.grievance.get(model.nation,0)])
	text_line("Horse husbandry: %s / Weapons: %s" % ["available" if state.horses else "unavailable",profile[4]])
	var goods: Array = model.indigenous.GOODS
	choice("Exchange good",goods,goods.find(ship_good),choose_value.bind(goods,&"ship_good"))
	var amount := SpinBox.new()
	amount.min_value=1
	amount.max_value=80
	amount.value=quantity
	sidebar.add_child(amount)
	amount.value_changed.connect(set_amount)
	buttons([["Buy",community_trade.bind(true)],["Sell",community_trade.bind(false)]])
	button(sidebar,"Offer 5 Food",model.indigenous.offer_food.bind(fleet,community_index))
	for event in model.indigenous.events.slice(-6):
		text_line(event)


func community_trade(buy: bool) -> void:
	var good := ship_good if ship_good in model.indigenous.GOODS else "Food"
	model.indigenous.exchange(fleet,community_index,good,quantity,buy)

func build_colony_screen(skin: Theme) -> void:
	colony_screen = PanelContainer.new()
	colony_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	colony_screen.theme = skin
	colony_screen.add_theme_stylebox_override("panel",background(Color("#36281d"),16))
	add_child(colony_screen)
	colony_screen.hide()
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation",10)
	colony_screen.add_child(page)
	var banner := HBoxContainer.new()
	page.add_child(banner)
	colony_title = caption("",34,Color("#f5d494"))
	colony_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner.add_child(colony_title)
	yield_buttons.append(button(banner,"Yields",toggle_yields))
	button(banner,"End turn",end_turn)
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation",12)
	page.add_child(middle)
	var landscape := preload("res://survey_table.gd").new()
	landscape.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var settlement := PanelContainer.new()
	settlement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var paper := StyleBoxTexture.new()
	paper.texture = preload("res://art/parchment.png")
	paper.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	paper.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		paper.set_content_margin(side,10)
	settlement.add_theme_stylebox_override("panel",paper)
	middle.add_child(settlement)
	var settlement_page := VBoxContainer.new()
	settlement.add_child(settlement_page)
	settlement_page.add_child(caption("Settlement",24,Color("#493720")))
	colony_buildings = preload("res://settlement_view.gd").new()
	colony_buildings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settlement_page.add_child(colony_buildings)
	middle.add_child(landscape)
	colony_map = Map.new()
	colony_map.setup(model)
	colony_map.zoom = 70
	colony_map.fog = false
	colony_map.focus_radius = true
	colony_map.picked.connect(pick_colony_hex)
	colony_map.worker_dropped.connect(drop_outdoor)
	landscape.add_child(colony_map)
	var book := PanelContainer.new()
	book.custom_minimum_size.x = 318
	surface_panels.append([book,12,Color("#8f7761")])
	middle.add_child(book)
	var orders_scroll := ScrollContainer.new()
	orders_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	book.add_child(orders_scroll)
	colony_orders = VBoxContainer.new()
	colony_orders.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	orders_scroll.add_child(colony_orders)
	var bench := PanelContainer.new()
	surface_panels.append([bench,5,Color("#8a7356")])
	bench.custom_minimum_size.y = 62
	page.add_child(bench)
	colony_workers = HFlowContainer.new()
	colony_workers.add_theme_constant_override("h_separation",8)
	bench.add_child(colony_workers)
	transport_line = caption("",15,PAPER)
	var quay := PanelContainer.new()
	surface_panels.append([quay,5,Color("#77837b")])
	page.add_child(quay)
	quay.add_child(transport_line)
	var warehouse := PanelContainer.new()
	surface_panels.append([warehouse,5,Color.WHITE])
	page.add_child(warehouse)
	var footer := HBoxContainer.new()
	warehouse.add_child(footer)
	colony_stock = HBoxContainer.new()
	colony_stock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colony_stock.add_theme_constant_override("separation",3)
	footer.add_child(colony_stock)
	button(footer,"Back to map",set_panel.bind("Fleet"))
	colony_status = caption("",15,PAPER)
	page.add_child(colony_status)


func refresh_colony_screen() -> void:
	var t := model.towns[town]
	var population := model.residents(town).size()
	colony_title.text = "%s    |    %d %s" % [t.name,population,"resident" if population==1 else "residents"]
	colony_map.center = Campaign.Hex.position(t.cell)
	colony_map.area_center = t.cell
	colony_map.work_town = town
	colony_map.selected = cell
	colony_map.queue_redraw()
	colony_status.text = model.report
	var berths: Array[String] = []
	for ship in model.ships:
		if ship.port == "America" and model.port_access(ship.cell,t.cell):
			berths.append("%s / %s" % [ship.type,goods_line(ship.cargo)])
	transport_line.text = "Harbor   "+(", ".join(berths) if not berths.is_empty() else "No vessels")
	for parent in [colony_orders,colony_workers,colony_buildings,colony_stock]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	for good in Campaign.GOODS:
		var slot_frame := PanelContainer.new()
		slot_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_frame.add_theme_stylebox_override("panel",background(Color("#3c251bc0"),3))
		colony_stock.add_child(slot_frame)
		var stack := VBoxContainer.new()
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.tooltip_text = good+"\nStock change last completed turn"
		stack.mouse_filter = Control.MOUSE_FILTER_STOP
		slot_frame.add_child(stack)
		var sprite := TextureRect.new()
		sprite.texture = ColonyArt.goods(good)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.custom_minimum_size.y = 24
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(sprite)
		var count := caption(str(t.goods.get(good,0)),14,PAPER)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(count)
		var change: int = t.get("goods_delta",{}).get(good,0)
		var delta := caption(("%+d" % change) if change!=0 else "",13,Color("#a9d68a") if change>0 else Color("#ffa491"))
		delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		delta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(delta)
	var active_buildings := {}
	for name in t.buildings:
		var job := building_job(name)
		if job != "":
			active_buildings[job] = name
	for id in model.residents(town):
		colony_workers.add_child(make_worker(id))
	for name in t.buildings:
		var job := building_job(name)
		if job != "" and active_buildings.get(job)!=name:
			continue
		if (name == "Warehouse" and "Warehouse Expansion" in t.buildings) or (name == "Stockade" and ("Fort" in t.buildings or "Fortress" in t.buildings)) or (name == "Fort" and "Fortress" in t.buildings) or (name == "Dock" and ("Drydock" in t.buildings or "Shipyard" in t.buildings)) or (name == "Drydock" and "Shipyard" in t.buildings):
			continue
		var card := VBoxContainer.new()
		card.custom_minimum_size.x = 95
		card.add_theme_constant_override("separation",1)
		colony_buildings.add_child(card)
		var building := preload("res://workshop_slot.gd").new()
		building.job = building_job(name)
		building.assigned.connect(drop_indoor)
		building.tooltip_text = name
		building.icon = ColonyArt.building(name)
		if name == "Warehouse Expansion":
			building.text = "2"
		building.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		building.flat = true
		building.expand_icon = true
		building.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		building.custom_minimum_size = Vector2(95,55)
		card.add_child(building)
		if building.job != "" and active_buildings.get(building.job)==name:
			var workers := HFlowContainer.new()
			card.add_child(workers)
			for id in model.residents(town):
				if model.people[id].job == building.job and model.people[id].field == Campaign.NONE:
					workers.add_child(make_worker(id,true))
	colony_buildings.place_buildings()
	var previous := sidebar
	sidebar = colony_orders
	colony_panel()
	sidebar = previous


func building_job(name: String) -> String:
	for job in Campaign.Catalog.WORKSHOPS:
		if name in [Campaign.Catalog.WORKSHOPS[job],Campaign.WORKSHOP_UPGRADES.get(job,""),Campaign.FACTORIES.get(job,"")]:
			return job
	return ""


func make_worker(id: int, small := false) -> Button:
	var p := model.people[id]
	var worker := preload("res://worker_card.gd").new()
	worker.worker_id = id
	worker.icon = ColonyArt.resident(p.skill,p.get("class","Free Colonist"))
	worker.expand_icon = true
	worker.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	worker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	worker.custom_minimum_size = Vector2(28,34) if small else Vector2(46,51)
	worker.flat = small
	worker.tooltip_text = "%s\n%s   %s" % [p.name,p.skill if p.skill!="" else "Untrained",p.job if p.job!="" else "Idle"]
	if p.study > 0:
		worker.tooltip_text += "\nTraining: %s (%d turns)" % [p.training,p.study]
	worker.pressed.connect(open_training.bind(id))
	return worker


func pick_colony_hex(where: Vector2i, alternate: bool) -> void:
	cell = where
	colony_map.selected = where
	colony_map.queue_redraw()
	if not alternate and resident() >= 0:
		drop_outdoor(resident(),where)


func _input(event: InputEvent) -> void:
	if colony_screen != null and colony_screen.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_instance_valid(colony_choice) and colony_choice.visible:
			colony_choice.hide()
		else:
			set_panel("Fleet")
		get_viewport().set_input_as_handled()

func toggle_yields() -> void:
	map.show_yields = not map.show_yields
	colony_map.show_yields = map.show_yields
	for control in yield_buttons:
		control.text = "Yields on" if map.show_yields else "Yields"
	map.queue_redraw()
	colony_map.queue_redraw()


func drop_outdoor(id: int, where: Vector2i) -> void:
	var t := model.towns[town]
	if id not in model.residents(town) or where==t.cell or not model.in_radius(where,t.cell):
		return
	if model.water(where) and "Dock" not in t.buildings:
		model.note("Fishing requires a Dock.")
		return
	for p in model.people:
		if p.location=="town" and p.field==where and not is_same(p,model.people[id]):
			model.note("Another worker is using this tile.")
			return
	var palette := choices("Work this hex")
	var jobs := ["Fishing"] if model.water(where) else Campaign.GOODS.slice(0,8)
	for job in jobs:
		var amount := model.yield_at(where,job)
		if amount <= 0:
			continue
		amount += Campaign.Catalog.bonus(model.people[id].skill,job)
		var entry := sprite_button(ColonyArt.goods("Fish" if job=="Fishing" else job),"%s   %d per turn" % [job,amount],Vector2(52,52))
		entry.text = str(amount)
		entry.pressed.connect(commit_field.bind(id,job,where))
		palette.add_child(entry)
	if palette.get_child_count()==0:
		colony_choice.queue_free()
		return
	show_choices()


func commit_field(id: int, job: String, where: Vector2i) -> void:
	colony_choice.hide()
	model.assign(id,job,where)


func drop_indoor(id: int, job: String) -> void:
	if id in model.residents(town):
		model.assign(id,job)

