extends Node
## Autoload singleton: tracks selected map and beaten maps.

var selected_map_id: String = "plains"
var beaten_maps: Dictionary = {}  # Dictionary[String, bool]
var procedural_difficulty: int = 1
var procedural_seed: int = -1  # -1 = generate new seed on battle start
var highest_procedural_difficulty_beaten: int = 0
var offense_difficulty: int = 1
var offense_seed: int = -1  # -1 = generate new seed on battle start
var highest_offense_difficulty_beaten: int = 0

# Campaign state
var campaign_active: bool = false
var campaign_gold: int = 0
var campaign_unit_bonus: int = 0
var campaign_gold_bonus: int = 0
var campaign_territories: Dictionary = {}   # {"forest": {"conquered": false}, ...}
var campaign_buildings: Dictionary = {}     # {"forest": [{"built": false, "mode": ""}, ...], ...}
var campaign_return_scene: String = ""
var campaign_attacking_territory: String = ""
var campaign_territory_reward: int = 0


func mark_beaten(map_id: String) -> void:
	beaten_maps[map_id] = true


func is_beaten(map_id: String) -> bool:
	return beaten_maps.has(map_id)


func init_campaign() -> void:
	campaign_active = true
	campaign_gold = 30
	campaign_unit_bonus = 0
	campaign_gold_bonus = 0
	campaign_return_scene = ""
	campaign_attacking_territory = ""
	campaign_territory_reward = 0
	campaign_territories = {
		"forest": {"conquered": false},
		"mountain": {"conquered": false},
		"volcano": {"conquered": false},
	}
	campaign_buildings = {
		"forest": [],
		"mountain": [],
		"volcano": [],
	}
	for i in range(3):
		campaign_buildings["forest"].append({"built": false, "mode": ""})
	for i in range(4):
		campaign_buildings["mountain"].append({"built": false, "mode": ""})
	for i in range(5):
		campaign_buildings["volcano"].append({"built": false, "mode": ""})


func recalculate_campaign_bonuses() -> void:
	campaign_unit_bonus = 0
	campaign_gold_bonus = 0
	for territory_id: String in campaign_buildings:
		for site: Dictionary in campaign_buildings[territory_id]:
			if not site["built"]:
				continue
			if site["mode"] == "unit":
				campaign_unit_bonus += 1
			elif site["mode"] == "gold":
				campaign_gold_bonus += 5


func add_campaign_gold(amount: int) -> void:
	campaign_gold += amount


func spend_campaign_gold(amount: int) -> bool:
	if campaign_gold < amount:
		return false
	campaign_gold -= amount
	return true
