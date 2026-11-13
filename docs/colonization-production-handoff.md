# Colonization Godot production handoff

## Start here

- Baseline is **v019 Building Economy**, in `C:\[GPT stuff]\game-versions\v019-building-economy`. Open `game-versions\launcher\project.godot` in Godot 4.7.2 and press F5. The launcher discovers sibling versions and runs the chosen build in its own process. Keep older builds as playable checkpoints.
- This is a modifiable Godot adaptation. Borrow the original visual language, local assets, data and documented rules where useful, then evolve them in fresh code. The default quick test is historical Americas, France, leader Test. A separate early prototype reproduced the original five-option opening menu and skipped its animation.
- Keep Founding Fathers and independence out of the current design. The user plans to replace liberty bells with culture and redesign overcrowding. Printing Press and Newspaper have concept art and await that design. Treat other original-only entries, including the Custom House and Man-o-War, as reference inventory until deliberately scoped.
- Preserve two rings of settlement work area on the hex map. Preserve eight current and eight previous 200-turn records. A long-run test measures what the AI can reach under its current policy. A targeted fixture verifies a particular rule or option.
- The latest evidence is v019 source and the saved v019 batch. This handoff uses the existing v019 runs.

## Where to work

| File | Responsibility |
|---|---|
| campaign.gd | Campaign state, turn order, terrain and yields, economy, construction, equipment, training, movement, trade, combat, saves |
| catalog.gd | Professions, starter buildings, resource bonuses and reserves |
| rivals.gd | European coastal survey, settlement policy, construction demand, aggregate production, services, freight, trade and decision tallies |
| indigenous.gd | Community profiles, settlement projects, expansion, exchanges, horse contact, grievances, border contests and raids |
| campaign_ui.gd | Map selection, reports, campaign settings, colony controls and warehouse |
| campaign_map.gd, hex.gd, waves.gd | Hex geometry, terrain rendering, scenery, rivers, shoreline, animation and map overlays |
| settlement_view.gd, colony_art.gd, colony_surfaces.gd, survey_table.gd | Colony composition, atlas mappings and surfaces |
| worker_card.gd, workshop_slot.gd | Worker drag source and workshop drop target |

## Player inventory and rules

| System | v019 state |
|---|---|
| Campaign | Historical AMER2 and configurable seeded random maps. France, England, Spain, Netherlands and Portugal. Portugal starts off Brazil on the historical map. Campaign options, seasonal turns, score, save/load and autosave. |
| Terrain | Tundra, Desert, Plains, Prairie, Grassland, Savannah, Marsh, Swamp, Arctic, Hills, Mountains, Ocean, Sea Lane. Eight eligible land types have wooded variants. Six derived features are sheltered harbor, shoals, rapids, mountain pass, floodplain and navigable river. |
| Work area and yield | Two rings around the center, at most 19 hexes including the center. Printed chart is the baseline because local DOS data differs. Forests, rivers, improvements, reserves and special resources affect output. Fishing contributes Food, needs a Dock for assignment, and gets one extra Food per two adjacent land hexes. Floodplains add Food. Deep-draft Galleons and Frigates avoid shoals. |
| Goods | Food, Sugar, Tobacco, Cotton, Furs, Lumber, Ore, Silver, Horses, Tools, Muskets, Rum, Cloth, Cigars, Coats. Hammers, Crosses and gold are tracked separately. |
| Recipes | Lumber to Hammers, Ore to Tools, Tools to Muskets, Sugar to Rum, Cotton to Cloth, Tobacco to Cigars, Furs to Coats. Church/Cathedral support Crosses and immigration. Stables improve horse breeding. |
| Labor and settlement | Land, board, found, join or leave, assign field and workshop labor, food consumption and growth, shortage losses, warehouse stock and per-turn net changes. Free Colonist, Indentured Servant, Petty Criminal and 20 specialties. |
| Construction | One active order per settlement with pause/rush. Hammers overflow into later projects. Shared prerequisite, population, coastal, tool and hammer checks. Project picker hides missing building dependencies and explains other blockers. |
| Training | Click an untrained resident for valid profession sprites. Schoolhouse, College and University gate tiers and slots. Model supports an optional teacher. Colony picker uses school instruction. |
| Map orders | Select by click, move, sail, disembark, reveal, plot course, clear forest, plow, road and investigate uncharted sites. Equipment includes Pioneer, Scout, Soldier and Dragoon. Artillery and damaged artillery exist in the combat model. |
| Ships and trade | Caravel, Merchantman, Galleon, Privateer and Frigate. Cargo and passenger holds, Europe transit and reversal, trade, taxes, prices, recruitment, specialist hiring, ship purchases and construction, wear and repairs, route rules and wagon freight. |
| Conflict | Player naval confrontation and colony attacks, defense tiers, rival relations and limited harassment. Proposed formations, fleet battles, garrisons and task-force planners are still open. |
| Presentation | Fog, minimap, zoom, inspection and settlement labels, land/sea slide and disembark animation. Yield toggle displays all positive tile yields. Colony has drag between roster/workshop/hex, competing goods on outdoor drop, goods by type, green/red last-turn stock deltas, production sprites and hover details, Escape and Back to map. |

### Resources and professions

Silver Deposit, Ore Deposit and Mineral Deposit have finite reserves. Other catalog entries are Trapping Grounds, Game, Oasis, Prime Cotton, Prime Tobacco, Prime Sugar, Prime Timber, Prime Farmland and Fishery.

Outdoor specialists are Expert Farmer, Expert Fisherman, Expert Fur Trapper, Expert Silver Miner, Expert Lumberjack, Expert Ore Miner, Master Sugar Planter, Master Cotton Planter and Master Tobacco Planter. Workshop specialists are Master Carpenter, Master Distiller, Master Weaver, Master Tobacconist, Master Fur Trader, Master Blacksmith and Master Gunsmith. Other specialties are Firebrand Preacher, Seasoned Scout, Hardy Pioneer and Veteran Soldier. Use catalog.gd for exact tier, duration and bonus.

## What the European AI actually does

- **Explore and settle.** Initial landfall is scripted by region, with Portugal using the Brazil heuristic. Ships retain a faction survey and choose reachable coastal survey moves for follow-up sites. The site must be seen and reachable. Scoring still reads the full work radius, even where its constituent tiles are unseen. The decision weighs food, exports, harbor, distance and grievances. Expansion needs peace, a Dock, four residents, eight Food and 240 gold. Dispatch spends 60 gold and eight Food. The ship sails and checks occupancy on arrival. The current three-colony cap comes from the name roster.
- **Produce and build.** Each colony runs one funded project at a time, checking prerequisites and scoring local demand. It reserves cash for freight and purchases missing tools up front. Carpenter Shops start in rival colonies. The AI can choose all other active projects. Industry uses aggregate local yield and labor. Tools can be spent locally or converted to muskets above a reserve. Education increases aggregate output rather than assigning individual specialist units. The original export-specialist path still runs alongside the broader workshop path, so audit both when tuning throughput.
- **Use buildings.** Dock contributes food and enables freight. Warehouses raise capacity, forts are counted as defensive service, churches accumulate crosses toward population, schools train aggregate labor, and stables trade food for horses. Drydock and Shipyard can repair a worn freight vessel at port. Shipyard lacks a rival shipbuilding decision. Do not infer battlefield protection from a defensive use counter alone.
- **Trade and freight.** One merchant per faction serves a qualifying dock, loads local goods and sells in Europe. Freight carries more processed goods as of v019. No multi-port freight planning, tool delivery to other colonies or purchase of imports on return legs. Rival specialists favor French furs, English lumber, Spanish and Portuguese sugar, and Dutch tobacco.
- **Defense and diplomacy.** Pressure near Indigenous settlements increases fortification demand. The expedition ship can harass nearby player shipping during war. There are no persistent rival field armies, garrison assignments, patrol routes, task-force planning, or rival-versus-rival attack policy.

## What Indigenous communities actually do

Nine profiles cover Innu, Mi'kmaq, Haudenosaunee, Caddo, Pueblo communities, TaÃ­no communities, Mexica, Maya communities and Tawantinsuyu. Each has a regional anchor, local production bonus and distinct first project. The first projects are Travel camps, Fish weir, Three Sisters gardens, River gardens, Irrigated fields, Cassava gardens, Chinampa gardens, Milpa fields and Terrace fields. Shared projects are Food store, Palisade, Exchange shelter and Horse enclosure. Goods are Food, Furs, Lumber, Cotton, Tobacco, Horses, Tools and Cloth.

Settlements produce, grow, build, exchange and expand. Reachable border pressure can lead to conquest. Captured sites keep their names and much of their infrastructure. European encroachment increases grievances, food gifts can lower them, and a reachable European settlement can be raided once grievances reach 60. The raid is a settlement-level resolution that can take food. Weapons are bows, spears and clubs. There are no musket weapons or individual professions in this subsystem.

Horse adoption has a 1550 gate, sustained European or inter-community contact, and a separate enclosure/breeding-stock check. The provisional rule leaves the source herd intact. The model uses aggregate populations and does not spawn persistent warriors, trade escorts or seasonal household parties. Inspect raid defense before adding patrols. Player defenses include fortification, while rival raid defense currently uses population alone.

## AI evidence and priorities

The v019 batch reached 200 turns in all eight cases. Every non-starter construction project completed somewhere. Carpenter Shop had 6,850 recorded uses. Shipyard completed 15 times with zero uses. Arsenal completed 10 times with one recorded production event. Workshop output was 9,216 Tools, 35,139 Hammers, 6,073 Cloth, 11,914 Coats, 2,197 Cigars, 5,471 Rum and 2,003 Muskets. These are batch totals. Eligibility and demand are colony-turn counts, and use events differ by building. Compare candidates, queues, completions and downstream use separately.

1. Make Shipyard demand depend on a funded replacement or expansion job. Test replacement, upkeep, local tools and use of a completed vessel.
2. Reserve construction tools against muskets production. Make Arsenal demand depend on expected equipment consumption. Track waste, blocked production and idle stock.
3. Teach freight to choose among colonies and deliver tools. Compare against direct purchase using matched scenarios.
4. Close survey information leaks. Add a land scout, survey-only yield scoring, and test incomplete information on both historical and generated coasts.
5. Add garrison coverage, patrol routes, and limited task forces with an objective and return plan. Model incidents, diplomacy, readiness and disengagement before autonomous attacks. Give Indigenous communities local patrols, escorts and household movement with explicit effects on food and home labor.
6. Keep culture, the press and overcrowding pending user direction. Proposed new ships and formations remain design references.

## Art direction and reference trail

Judge a populated colony and a coastal stretch at play size before generalizing. Compose the town as a settlement with lanes, groves, workshops and workers. Place texture and scenery where they give shape to empty areas. Preserve drag targets, tooltip legibility and the framed goods row. Build forests as irregular masses with layered crowns and clearings. Treat bends, beaches and river mouths individually. Use light-blue shallows, deeper offshore texture and restrained pixel foam. Use original atlas art and paired sheets as visual references. The proposed sprites are concept art.

- [Manual inventory](guide-inventory.md) and [initial action plan](godot-action-plan.md)
- [Original source and asset recovery](colonization-source-recovery.md). The local DOS executable is compiled with overlays. Use manuals, local data and art for routine implementation. There is no recovered original source tree.
- [1500â€“1800 reference pool](1500-1800-design-reference.md) for ships, military formations, terrain, professions, resources, goods and industries. Sloop and bateau were the first proposed extra hulls. Militia and light infantry were the first proposed new military roles.
- [Colonial sponsors and contested regions](colonial-sponsors-and-rivalries.md). Portugal is now active. Sweden, Denmark-Norway and Russia are regional scenario ideas. Companies can be sponsors within their parent powers. Key regions include the Caribbean, Brazil, Hudson/Delaware, Acadia/Hudson Bay/Great Lakes/Ohio, and Florida/Gulf/Mississippi.
- [AI exploration and defense design](ai-exploration-and-defense-plan.md)
- [Population](../README.md), [buildings](../README.md), [ships](../README.md), [military](../README.md)

## Test and release routine

Use [current test records](game-test-slots/current/summary.md) and the neighboring previous folder. The current runner is `game-test-slots/current/run_200_turns.gd`. Run it against the selected project with `--headless --path <project> --script <runner> -- <output.json> <case-letter>`. Cases Aâ€“H include historical and generated maps, a Portuguese player, a frontier colony, horse-contact and gifts. Preserve scenario seeds and policies for comparisons. Check completed turns, failure fields and runtime logs before rotating exactly eight JSON records into each slot.

For UI changes, import assets and run a graphical smoke check with actual selection, dragging, menus and screenshots. Exercise save/load when changing state. Keep the launcher and version path discoverable. Update this handoff after major changes and distinguish observed outcomes from implemented branches and planned behavior.

## Construction catalog

Costs are hammers, tools and minimum population. Prerequisites below are building dependencies. Maritime projects additionally require coast access.

| Building | Hammers | Tools | Population | Building prerequisite |
|---|---:|---:|---:|---|
| Carpenter Shop | 39 | 0 | 1 |  |
| Tobacconist House | 52 | 0 | 3 |  |
| Distiller House | 52 | 0 | 3 |  |
| Fur Trader House | 52 | 0 | 3 |  |
| Warehouse | 80 | 0 | 1 |  |
| Warehouse Expansion | 80 | 20 | 1 | Warehouse |
| Dock | 52 | 0 | 1 |  |
| Drydock | 80 | 50 | 6 | Dock |
| Shipyard | 240 | 100 | 8 | Drydock |
| Lumber Mill | 52 | 0 | 3 | Carpenter Shop |
| Armory | 52 | 0 | 1 |  |
| Magazine | 120 | 50 | 8 | Armory |
| Blacksmith House | 52 | 0 | 3 |  |
| Weaver House | 52 | 0 | 3 |  |
| Blacksmith Shop | 64 | 20 | 4 | Blacksmith House |
| Weaver Shop | 64 | 20 | 4 | Weaver House |
| Tobacconist Shop | 64 | 20 | 4 | Tobacconist House |
| Rum Distillery | 64 | 20 | 4 | Distiller House |
| Fur Trading Post | 56 | 20 | 3 | Fur Trader House |
| Stables | 64 | 0 | 1 |  |
| Church | 52 | 0 | 3 |  |
| Cathedral | 176 | 100 | 8 | Church |
| Schoolhouse | 64 | 0 | 4 |  |
| College | 160 | 50 | 8 | Schoolhouse |
| University | 200 | 100 | 10 | College |
| Iron Works | 240 | 100 | 8 | Blacksmith Shop |
| Cigar Factory | 160 | 100 | 8 | Tobacconist Shop |
| Textile Mill | 160 | 100 | 8 | Weaver Shop |
| Rum Factory | 160 | 100 | 8 | Rum Distillery |
| Fur Factory | 160 | 100 | 6 | Fur Trading Post |
| Arsenal | 240 | 100 | 8 | Magazine |
| Stockade | 64 | 0 | 3 |  |
| Fort | 120 | 100 | 4 | Stockade |
| Fortress | 320 | 200 | 8 | Fort |




