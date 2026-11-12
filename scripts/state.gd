extends RefCounted
class_name QuarryState

const RESOURCE_NAMES := ["limestone", "coal", "iron_ore", "crushed_stone", "copper_ore", "gold_ore"]
const UPGRADE_NAMES := ["reinforced_pickaxe", "larger_backpack", "faster_mining", "efficient_crusher", "expanded_storage", "hauling_harness"]
var config: Dictionary
var money: int
var inventory := {"limestone": 0, "coal": 0, "iron_ore": 0, "crushed_stone": 0, "copper_ore": 0, "gold_ore": 0}
var storage := {"limestone": 0, "coal": 0, "iron_ore": 0, "crushed_stone": 0, "copper_ore": 0, "gold_ore": 0}
var upgrades := {}
var clock_minutes := 480.0
var player_position := [0.0, 1.0, 8.0]
var player_yaw := 0.0
var deposits := {}
var crushers := []
# Phase 5
var tool_tier := 0          ## index into progression tools (0 hand hammer .. 4 jackhammer)
var earned := 0             ## lifetime sales revenue (drives the progression stages)
# Phase 9
var lifetime := {"mined": {}, "sold": {}}   ## units collected / sold per resource, ever (discoveries and deliveries)
var gear: Array = []                         ## ids of the extra tools bought beyond the five-tool ladder (see progression "gear")
var equipped := ""                           ## "" = the ladder tool of tool_tier, else the id of an owned extra tool in hand
var price_mult := 1.0                        ## buyers' pay factor of the current progression stage (see progression "price_mult")
var soil_units: Array = []                   ## soil units left per cell of the working ground (Phase 10.2); empty = untouched
var soil_dumped := 0                         ## soil units hauled to the spoil heap, ever
var carts: Array = []
var cart_load := {}                          ## cart id -> {resource: units}: what each cart carries (Phase 9.6)
var cart_pos := {}                           ## cart id -> [x, y, z, yaw]: where each cart stands                        ## ids of hauling aids owned (hand_cart, wheelbarrow, ...)
signal money_earned(amount: int, source: String)

func _init(settings: Dictionary = {}) -> void:
	config = settings
	money = int(config.get("starting_money", 100))
	for key in UPGRADE_NAMES:
		upgrades[key] = false

func capacity() -> int:
	return int(config.get("backpack_capacity", 18)) + (16 if upgrades["larger_backpack"] else 0) + (30 if upgrades.get("hauling_harness", false) else 0)

## Capacity of the best hauling aid owned (the load per trip is the bag plus one cart; you push one at a time).
func cart_capacity() -> int:
	var best := 0
	for id in carts:
		best = maxi(best, int(config.get("cart_capacity", {}).get(str(id), 0)))
	return best

# ------------------------------------------------------------------ carts (Phase 9.6): real containers, moved unit by unit

func cart_cap(id: String) -> int:
	return int(config.get("cart_capacity", {}).get(id, 0))

func cart_total(id: String) -> int:
	return total(cart_load.get(id, {}))

func cart_space(id: String) -> int:
	return maxi(0, cart_cap(id) - cart_total(id))

func cart_units(id: String, key: String) -> int:
	return int(cart_load.get(id, {}).get(key, 0))

func _cart_put(id: String, key: String, n: int) -> void:
	if not cart_load.has(id):
		cart_load[id] = {}
	cart_load[id][key] = int(cart_load[id].get(key, 0)) + n

func _cart_pull(id: String, key: String, n: int) -> void:
	cart_load[id][key] = int(cart_load[id].get(key, 0)) - n
	if int(cart_load[id][key]) <= 0:
		cart_load[id].erase(key)

## Bag -> cart. Every transfer moves what both sides can take, never more: nothing is created or lost.
func cart_load_from_bag(id: String, key: String, n: int) -> int:
	if not id in carts or not inventory.has(key) or n <= 0:
		return 0
	var m := mini(mini(n, int(inventory[key])), cart_space(id))
	if m <= 0:
		return 0
	inventory[key] -= m
	_cart_put(id, key, m)
	return m

func cart_unload_to_bag(id: String, key: String, n: int) -> int:
	if not id in carts or n <= 0:
		return 0
	var m := mini(mini(n, cart_units(id, key)), capacity() - total(inventory))
	if m <= 0:
		return 0
	_cart_pull(id, key, m)
	inventory[key] += m
	return m

func cart_store(id: String, key: String, n: int) -> int:
	if not id in carts or n <= 0:
		return 0
	var m := mini(mini(n, cart_units(id, key)), storage_capacity() - total(storage))
	if m <= 0:
		return 0
	_cart_pull(id, key, m)
	storage[key] += m
	return m

func cart_take(id: String, key: String, n: int) -> int:
	if not id in carts or not storage.has(key) or n <= 0:
		return 0
	var m := mini(mini(n, int(storage[key])), cart_space(id))
	if m <= 0:
		return 0
	storage[key] -= m
	_cart_put(id, key, m)
	return m

func cart_sell(id: String, key: String, n: int) -> int:
	if not id in carts or n <= 0:
		return 0
	var m := mini(n, cart_units(id, key))
	if m <= 0:
		return 0
	_cart_pull(id, key, m)
	note_lifetime("sold", key, m)
	add_income(int(round(float(m) * unit_price(key))), "sale")
	return m

## Every unit the player owns in any container (bag, storage, carts): the conserved quantity in transfers.
func all_units() -> int:
	var n := total(inventory) + total(storage)
	for id in cart_load:
		n += total(cart_load[id])
	return n

func note_lifetime(kind: String, key: String, amount: int) -> void:
	if amount > 0:
		lifetime[kind][key] = int(lifetime[kind].get(key, 0)) + amount

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
	note_lifetime("mined", key, taken)
	return taken

func sell(key: String, amount: int) -> int:
	if not inventory.has(key) or amount <= 0:
		return 0
	var sold: int = mini(amount, int(inventory[key]))
	inventory[key] -= sold
	note_lifetime("sold", key, sold)
	add_income(int(round(float(sold) * unit_price(key))), "sale")
	return sold

## What the buyers pay for one unit right now (the base price times the stage's pay factor).
func unit_price(key: String) -> float:
	return float(config["prices"].get(key, 0)) * price_mult

## Every revenue source goes through here so lifetime earnings (stage progress) stay honest.
func add_income(amount: int, source := "sale") -> void:
	if amount <= 0:
		return
	money += amount
	earned += amount
	money_earned.emit(amount, source)

func buy_upgrade(key: String) -> bool:
	if not upgrades.has(key) or upgrades[key]:
		return false
	var cost: int = int(config["upgrades"].get(key, 999999))
	if money < cost:
		return false
	money -= cost
	upgrades[key] = true
	if key == "reinforced_pickaxe":
		tool_tier = maxi(tool_tier, 2)
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

## Hits for the small (non-formation) deposits: quarry face and east expansion rocks.
func required_hits() -> int:
	return 2 if upgrades["reinforced_pickaxe"] or tool_tier >= 2 else 4

func strike_interval() -> float:
	return 0.33 if upgrades["faster_mining"] else 0.58

func process_seconds(index := -1) -> float:
	var t := float(config["crusher_seconds"]) * (0.55 if upgrades["efficient_crusher"] else 1.0)
	if index >= 0 and index < crushers.size() and int(crushers[index].get("tier", 1)) >= 2:
		t *= float(config.get("advanced_speed_mult", 0.45))
	return t

## Input batch limit; the advanced crusher takes twice as much per run.
func input_limit(index: int) -> int:
	var n := int(config["crusher_input_limit"])
	if index >= 0 and index < crushers.size() and int(crushers[index].get("tier", 1)) >= 2:
		n *= int(config.get("advanced_capacity_mult", 2))
	return n

func load_crusher(index: int, amount: int) -> int:
	if index < 0 or index >= crushers.size():
		return 0
	var crusher: Dictionary = crushers[index]
	var taken: int = mini(mini(amount, int(inventory["limestone"])), input_limit(index) - int(crusher["input"]))
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
	crusher["remaining"] = process_seconds(index) * clampf(factor, 0.2, 1.0)
	crusher["batch"] = int(crusher["input"])
	crusher["duration"] = float(crusher["remaining"])
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

func new_crusher(pos: Vector3, yaw: float, tier := 1) -> void:
	crushers.append({"position": [pos.x, pos.y, pos.z], "yaw": yaw, "input": 0, "output": 0, "running": false, "remaining": 0.0, "hopper": 0, "automated": false, "auto_done": 0, "tier": tier})

# ------------------------------------------------------------------ Phase 4: sustainable deposits
# Each deposit holds a visible stock of units. Breaking it yields pieces out of that stock; the stock
# regrows one unit at a fixed in-game interval, so a deposit is never gone for long. The quarry face
# (`infinite`) is a hand-mining fallback that never runs out, so a broke player can always recover.

func deposit_max(res: String) -> int:
	return int(config.get("deposit_stock", {}).get(res, 20))

func deposit_regrow(res: String) -> float:
	return float(config.get("deposit_regrow_minutes", {}).get(res, 5))

## Adds any missing Phase 4 fields (old saves) without changing what the save already recorded.
func ensure_deposit(kind: String, res: String, infinite := false) -> Dictionary:
	if not deposits.has(kind):
		deposits[kind] = {"hits": 0, "broken": false, "generation": 0}
	var d: Dictionary = deposits[kind]
	d["resource"] = res
	d["infinite"] = infinite
	if not d.has("stock"):
		# Phase 1-3 saves: a broken deposit starts empty and regrows; an intact one is full.
		d["stock"] = 0 if bool(d.get("broken", false)) else deposit_max(res)
		d["regrow_at"] = clock_minutes + deposit_regrow(res) if int(d["stock"]) < deposit_max(res) else -1.0
	if infinite:
		d["stock"] = deposit_max(res)
		d["broken"] = false
	d["stock"] = clampi(int(d["stock"]), 0, deposit_max(res))
	d["broken"] = int(d["stock"]) <= 0
	d["hits"] = int(d.get("hits", 0))
	d["regrow_at"] = float(d.get("regrow_at", -1.0))
	return d

## Takes up to `want` pieces out of a deposit's stock (nothing is created beyond the stock).
func mine_yield(kind: String, want: int) -> int:
	var d: Dictionary = deposits[kind]
	if bool(d.get("infinite", false)):
		return want
	var n := mini(want, int(d["stock"]))
	d["stock"] = int(d["stock"]) - n
	d["mined"] = int(d.get("mined", 0)) + n # lifetime units taken (statistics / conservation checks)
	d["broken"] = int(d["stock"]) <= 0
	if float(d.get("regrow_at", -1.0)) < 0.0 and int(d["stock"]) < deposit_max(str(d["resource"])):
		d["regrow_at"] = clock_minutes + deposit_regrow(str(d["resource"]))
	return n

## Regrows every deposit by whole units for the in-game time that has passed. Returns changed ids.
func regrow_deposits() -> Array:
	var changed := []
	for kind in deposits:
		var d: Dictionary = deposits[kind]
		if not d.has("resource") or bool(d.get("infinite", false)) or bool(d.get("formation", false)):
			continue
		var res := str(d["resource"])
		var cap := deposit_max(res)
		if int(d["stock"]) >= cap:
			d["regrow_at"] = -1.0
			continue
		if float(d["regrow_at"]) < 0.0:
			d["regrow_at"] = clock_minutes + deposit_regrow(res)
			continue
		var before := int(d["stock"])
		while clock_minutes >= float(d["regrow_at"]) and int(d["stock"]) < cap:
			d["stock"] = int(d["stock"]) + 1
			d["regrow_at"] = float(d["regrow_at"]) + deposit_regrow(res)
		if int(d["stock"]) >= cap:
			d["regrow_at"] = -1.0
		d["broken"] = int(d["stock"]) <= 0
		if int(d["stock"]) != before:
			changed.append(kind)
	return changed

## Minutes until the next unit regrows (or -1 when full / infinite).
func regrow_eta(kind: String) -> float:
	var d: Dictionary = deposits.get(kind, {})
	if d.is_empty() or bool(d.get("infinite", false)) or float(d.get("regrow_at", -1.0)) < 0.0:
		return -1.0
	return maxf(0.0, float(d["regrow_at"]) - clock_minutes)

func snapshot() -> Dictionary:
	return {"version": 2, "tool_tier": tool_tier, "earned": earned, "money": money, "inventory": inventory.duplicate(true), "storage": storage.duplicate(true), "upgrades": upgrades.duplicate(true), "clock_minutes": clock_minutes, "player_position": player_position.duplicate(), "player_yaw": player_yaw, "deposits": deposits.duplicate(true), "crushers": crushers.duplicate(true), "lifetime": lifetime.duplicate(true), "gear": gear.duplicate(), "equipped": equipped, "carts": carts.duplicate(), "cart_load": cart_load.duplicate(true), "cart_pos": cart_pos.duplicate(true), "soil_units": soil_units.duplicate(), "soil_dumped": soil_dumped}

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
	# Phase 5: Phase 1-4 players already swung a pickaxe; keep it (or the reinforced one) - never confiscate.
	if data.has("tool_tier"):
		tool_tier = clampi(int(data["tool_tier"]), 0, 4)
	else:
		tool_tier = 2 if upgrades["reinforced_pickaxe"] else 1
	earned = maxi(0, int(data.get("earned", 0)))
	lifetime = {"mined": {}, "sold": {}}
	var lt = data.get("lifetime", {})
	if lt is Dictionary:
		for kind in ["mined", "sold"]:
			var src = lt.get(kind, {})
			if src is Dictionary:
				for k in src:
					lifetime[kind][str(k)] = maxi(0, int(src[k]))
	gear = []
	for g in data.get("gear", []):
		if not str(g) in gear:
			gear.append(str(g))
	carts = []
	for g in data.get("carts", []):
		if not str(g) in carts:
			carts.append(str(g))
	equipped = str(data.get("equipped", ""))
	cart_load = {}
	var cl = data.get("cart_load", {})
	if cl is Dictionary:
		for id in cl:
			if str(id) in carts and cl[id] is Dictionary:
				var room := cart_cap(str(id))
				for k in cl[id]:
					if str(k) in RESOURCE_NAMES:
						var n := mini(maxi(0, int(cl[id][k])), room)
						room -= n
						if n > 0:
							_cart_put(str(id), str(k), n)
	soil_units = []
	for u in data.get("soil_units", []):
		soil_units.append(maxi(0, int(u)))
	soil_dumped = maxi(0, int(data.get("soil_dumped", 0)))
	cart_pos = {}
	var cp = data.get("cart_pos", {})
	if cp is Dictionary:
		for id in cp:
			if str(id) in carts and cp[id] is Array and cp[id].size() >= 4:
				cart_pos[str(id)] = [float(cp[id][0]), float(cp[id][1]), float(cp[id][2]), float(cp[id][3])]
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
		crusher["tier"] = clampi(int(crusher.get("tier", 1)), 1, 2)
	return true
