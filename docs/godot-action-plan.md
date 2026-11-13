# Godot implementation plan

The campaign starts on Historical America as France under Test. Keep map state, turn rules, and prices separate from Godot presentation so the rules can change without replacing the art.

| Stage | Work | Acceptance check | Status |
|---|---|---|---|
| 1 Expedition | Start, map navigation, movement, landfall, founding, turn clock and outdoor work | Sail, land, found a colony and collect a yield | Playable in v005 through the existing Historical America scenario |
| 2 Economy | Warehouse and capacity, food consumption, workshop inputs and outputs, construction, cargo limits, voyages, Europe trade and save/load | Carry lumber into construction or export it, reach Europe, sell for gold, save and reload the campaign | Implemented as a single-colony slice with simplified rules |
| 3 Colony depth | Multiple units and colonies, tile-specific yields for all goods, individual jobs and skills, growth, shortages, full construction tree, equipment and education | Two colonies produce and exchange goods. Individual workers can change jobs and train | Remaining |
| 4 Shipping and migration | Individual ship holds and passengers, sea-lane departure, voyage reversal, immigration, recruitment, ship purchasing, repair and trade routes | Carry recruits and mixed cargo on a repeatable two-port route | Remaining beyond the two-port prototype |
| 5 European rivalry | Opponents, diplomacy, foreign trade, privateering, blockades, combat, fortification and capture | Play through a rival contact, an exchange and a naval or land encounter | Remaining |
| 6 Campaign and interface | World options, additional starts and difficulty, reports, preferences, exploration and terrain orders, scoring and campaign flow | Start another scenario, use reports and orders, and complete the campaign flow | Remaining |

## v005 rules to revisit

The additional field-work selector gives a flat yield. Workshops are one recipe per colony per turn. The caravel has two goods holds, and the Europe trip takes two turns. The build uses fixed prices and tax, four construction projects and a single Godot save slot. Lumber, food and furs retain the earlier map-based assignment. These values are adaptation choices. Use the guide’s aid-card tables when expanding into individual workers, ships, and production sites.
