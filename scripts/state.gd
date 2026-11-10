extends RefCounted
class_name QuarryState

const RESOURCE_NAMES := ["limestone", "coal", "iron_ore", "crushed_stone"]
const UPGRADE_NAMES := ["reinforced_pickaxe", "larger_backpack", "faster_mining", "efficient_crusher", "expanded_storage"]
var config: Dictionary
var money: int
var inventory := {"limestone": 0, "coal": 0, "iron_ore": 0, "crushed_stone": 0}
var storage := {"limestone": 0, "coal": 0, "iron_ore": 0, "crushed_stone": 0}
var upgrades := {}
var clock_minutes := 480.0
var player_position := [0.0, 1.0, 8.0]
var player_yaw := 0.0
var deposits := {}
var crushers := []

func _init(settings: Dictionary = {}) -> void:
	config = settings
	money = int(config.get("starting_money", 100))
	for key in UPGRADE_NAMES:
		upgrades[key] = false

func capacity() -> int:
	return int(config.get("backpack_capacity", 18)) + (16 if upgrades["larger_backpack"] else 0)

func storage_capacity() -> int:
	return int(config.get("storage_capacity", 40)) + (40 if upgrades["expanded_storage"] else 0)

func total(items: Dictionary) -> int:
	var result := 0
	for v in items.values():
		result += int(v)
	return result

func add_item(key: String, amount: int) -> int:
	if not inventory.has(key) or amount <= 0:
		return 0
	var taken: int = mini(amount, capacity() - total(inventory))
	inventory[key] += taken
	return taken

func sell(key: String, amount: int) -> int:
	if not inventory.has(key) or amount <= 0:
		return 0
	var sold: int = mini(amount, int(inventory[key]))
	inventory[key] -= sold
	money += sold * int(config["prices"].get(key, 0))
	return sold

func buy_upgrade(key: String) -> bool:
	if not upgrades.has(key) or upgrades[key]:
		return false
	var cost: int = int(config["upgrades"].get(key, 999999))
	if money < cost:
		return false
	money -= cost
	upgrades[key] = true
	return true

func buy_crusher() -> bool:
	var cost: int = int(config["crusher_price"])
	if money < cost:
		return false
	money -= cost
	return true

func deposit_item(key: String, amount: int) -> int:
	if not inventory.has(key) or amount <= 0:
		return 0
	var taken: int = mini(mini(amount, int(inventory[key])), storage_capacity() - total(storage))
	inventory[key] -= taken
	storage[key] += taken
	return taken

func withdraw_item(key: String, amount: int) -> int:
	if not storage.has(key) or amount <= 0:
		return 0
	var taken: int = mini(mini(amount, int(storage[key])), capacity() - total(inventory))
	storage[key] -= taken
	inventory[key] += taken
	return taken

func required_hits() -> int:
	return 2 if upgrades["reinforced_pickaxe"] else 4

func strike_interval() -> float:
	return 0.33 if upgrades["faster_mining"] else 0.58

func process_seconds() -> float:
	return float(config["crusher_seconds"]) * (0.55 if upgrades["efficient_crusher"] else 1.0)

func load_crusher(index: int, amount: int) -> int:
	if index < 0 or index >= crushers.size():
		return 0
	var crusher: Dictionary = crushers[index]
	var taken: int = mini(mini(amount, int(inventory["limestone"])), int(config["crusher_input_limit"]) - int(crusher["input"]))
	if taken <= 0:
		return 0
	inventory["limestone"] -= taken
	crusher["input"] += taken
	return taken

func start_crusher(index: int, factor := 1.0, automated := false) -> bool:
	if index < 0 or index >= crushers.size():
		return false
	var crusher: Dictionary = crushers[index]
	if bool(crusher["running"]) or int(crusher["input"]) <= 0:
		return false
	crusher["running"] = true
	crusher["remaining"] = process_seconds() * clampf(factor, 0.2, 1.0)
	crusher["automated"] = automated
	return true

func tick(seconds: float) -> void:
	if seconds <= 0:
		return
	clock_minutes += seconds * 0.5 # 48 real minutes per in-game day
	for crusher in crushers:
		if bool(crusher["running"]):
			crusher["remaining"] = maxf(0.0, float(crusher["remaining"]) - seconds)
			if float(crusher["remaining"]) <= 0.0:
				crusher["output"] = int(crusher["output"]) + int(crusher["input"])
				if bool(crusher.get("automated", false)):
					crusher["auto_done"] = int(crusher.get("auto_done", 0)) + int(crusher["input"])
				crusher["input"] = 0
				crusher["running"] = false

func collect_crusher(index: int) -> int:
	if index < 0 or index >= crushers.size():
		return 0
	var crusher: Dictionary = crushers[index]
	var taken: int = add_item("crushed_stone", int(crusher["output"]))
	crusher["output"] -= taken
	return taken

func new_crusher(pos: Vector3, yaw: float) -> void:
	crushers.append({"position": [pos.x, pos.y, pos.z], "yaw": yaw, "input": 0, "output": 0, "running": false, "remaining": 0.0, "hopper": 0, "automated": false, "auto_done": 0})

func snapshot() -> Dictionary:
	return {"version": 2, "money": money, "inventory": inventory.duplicate(true), "storage": storage.duplicate(true), "upgrades": upgrades.duplicate(true), "clock_minutes": clock_minutes, "player_position": player_position.duplicate(), "player_yaw": player_yaw, "deposits": deposits.duplicate(true), "crushers": crushers.duplicate(true)}

func restore(data: Dictionary) -> bool:
	# Version 1 = Phase 1 saves; version 2 adds Phase 2 business data stored beside this snapshot.
	if not int(data.get("version", -1)) in [1, 2]:
		return false
	for key in ["inventory", "storage", "upgrades", "crushers", "deposits", "player_position", "money", "clock_minutes", "player_yaw"]:
		if not data.has(key):
			return false
	if not data["inventory"] is Dictionary or not data["crushers"] is Array:
		return false
	money = maxi(0, int(data["money"]))
	for key in RESOURCE_NAMES:
		inventory[key] = maxi(0, int(data["inventory"].get(key, 0)))
		storage[key] = maxi(0, int(data["storage"].get(key, 0)))
	for key in UPGRADE_NAMES:
		upgrades[key] = bool(data["upgrades"].get(key, false))
	clock_minutes = maxf(0.0, float(data["clock_minutes"]))
	player_position = data["player_position"].duplicate()
	player_yaw = float(data["player_yaw"])
	deposits = data["deposits"].duplicate(true)
	crushers = data["crushers"].duplicate(true)
	for crusher in crushers:
		for key in ["input", "output", "hopper", "auto_done"]:
			crusher[key] = maxi(0, int(crusher.get(key, 0)))
		crusher["running"] = bool(crusher.get("running", false))
		crusher["remaining"] = maxf(0.0, float(crusher.get("remaining", 0.0)))
		crusher["automated"] = bool(crusher.get("automated", false))
	return true
