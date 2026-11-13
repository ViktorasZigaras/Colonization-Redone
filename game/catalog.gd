extends RefCounted

const WORKSHOPS := {"Hammers":"Carpenter Shop","Tools":"Blacksmith House","Rum":"Distiller House","Cloth":"Weaver House","Cigars":"Tobacconist House","Coats":"Fur Trader House","Muskets":"Armory","Crosses":"Church"}
const STARTERS := ["Carpenter Shop","Blacksmith House","Distiller House","Weaver House","Tobacconist House","Fur Trader House"]
# Label, job or role, school tier, training turns, output bonus.
const PROFESSIONS := {
	"Expert Farmer":["Food",1,3,2], "Expert Fisherman":["Fishing",1,3,2],
	"Expert Fur Trapper":["Furs",1,3,3], "Expert Silver Miner":["Silver",1,3,2],
	"Expert Lumberjack":["Lumber",1,3,3], "Expert Ore Miner":["Ore",1,3,2],
	"Master Sugar Planter":["Sugar",2,4,3], "Master Cotton Planter":["Cotton",2,4,3],
	"Master Tobacco Planter":["Tobacco",2,4,3], "Master Carpenter":["Hammers",1,3,3],
	"Master Distiller":["Rum",2,4,3], "Master Weaver":["Cloth",2,4,3],
	"Master Tobacconist":["Cigars",2,4,3], "Master Fur Trader":["Coats",2,4,3],
	"Master Blacksmith":["Tools",2,4,3], "Master Gunsmith":["Muskets",2,4,3],
	"Firebrand Preacher":["Crosses",3,5,3], "Seasoned Scout":["Scout",1,3,0],
	"Hardy Pioneer":["Pioneer",1,3,0], "Veteran Soldier":["Soldier",2,4,0],
}

const RESOURCE := {
	"Silver Deposit":[{"Silver":3},18,"Ag"],"Ore Deposit":[{"Ore":4},28,"Fe"],
	"Mineral Deposit":[{"Ore":2,"Silver":1},24,"Mn"],"Trapping Grounds":[{"Furs":3},0,"Fu"],
	"Game":[{"Food":2,"Furs":1},0,"G"],"Oasis":[{"Food":3,"Cotton":1},0,"O"],
	"Prime Cotton":[{"Cotton":3},0,"C"],"Prime Tobacco":[{"Tobacco":3},0,"T"],
	"Prime Sugar":[{"Sugar":3},0,"S"],"Prime Timber":[{"Lumber":4},0,"L"],
	"Prime Farmland":[{"Food":3},0,"W"],"Fishery":[{"Food":3},0,"F"],
}

static func profession(skill: String) -> String:
	if PROFESSIONS.has(skill):
		return skill
	for name in PROFESSIONS:
		if PROFESSIONS[name][0] == skill:
			return name
	return ""


static func bonus(skill: String, job: String) -> int:
	var name := profession(skill)
	if name != "" and PROFESSIONS[name][0] == job:
		return PROFESSIONS[name][3]
	return 0
