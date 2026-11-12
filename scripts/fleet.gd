extends RefCounted
class_name QuarryFleet
## Phase 3 heavy machinery data: owned vehicles, their cargo, equipment upgrades and the
## rubble piles they work. Pure data (no nodes) so material handling is testable.
## Every transfer moves existing units; nothing is created except by pile regrowth.


var business: QuarryBusiness
var state: QuarryState
var cfg: Dictionary
var vehicles: Array = []
var next_id := 1
var upgrades := {"bucket": false, "cargo": false, "engine": false}
var piles := {}
var pile_minute := -1
var driving_id := -1

func _init(biz: QuarryBusiness, settings: Dictionary) -> void:
	business = biz
	state = biz.state
	cfg = settings
	for id in cfg.get("piles", {}):
		piles[id] = {"amount": int(cfg.get("pile_max", 30))}
	pile_minute = int(floor(state.clock_minutes))

func spec(type: String) -> Dictionary:
	return cfg["vehicles"].get(type, {})

## Vehicle types in shop order.
func types() -> Array:
	var out := []
	for k in cfg["vehicles"].keys():
		if not bool(cfg["vehicles"][k].get("starter", false)):      # Grandpa's machine is not for sale
			out.append(k)
	return out

## The family a type belongs to: "loader" (bucket), "truck" (tipping bed) or "excavator" (digs rock and fills a bucket).
func kind(type: String) -> String:
	return str(spec(type).get("kind", type))

func vehicle(id: int) -> Dictionary:
	for v in vehicles:
		if int(v["id"]) == id:
			return v
	return {}

func owns_kind(k: String) -> bool:
	for v in vehicles:
		if kind(str(v["type"])) == k:
			return true
	return false

func owns(type: String) -> bool:
	for v in vehicles:
		if str(v["type"]) == type:
			return true
	return false

# ------------------------------------------------------------------ purchasing

func buy_block_reason(type: String) -> String:
	var s := spec(type)
	if s.is_empty():
		return "Unknown vehicle"
	if bool(s.get("starter", false)):
		return "Not for sale"
	var req := str(s.get("requires", ""))
	if req != "" and not business.milestones.get(req, false):
		return "Requires the %s milestone" % {"mechanized": "Mechanized Quarry", "automated": "Automated Business"}.get(req, req)
	if vehicles.size() >= int(cfg.get("max_vehicles", 4)):
		return "Equipment yard full"
	if state.money < int(s["price"]):
		return "Need $%d" % int(s["price"])
	return ""

func buy(type: String, pos: Vector3, yaw := 0.0) -> Dictionary:
	if buy_block_reason(type) != "":
		return {}
	state.money -= int(spec(type)["price"])
	var count := 1
	for o in vehicles:
		if str(o["type"]) == type:
			count += 1
	var v := {"id": next_id, "type": type, "position": [pos.x, pos.y, pos.z], "yaw": yaw, "cargo": {}, "name": "%s %d" % [spec(type)["title"], count]}
	next_id += 1
	vehicles.append(v)
	return v

## Hands over a machine for free (Grandpa's excavator): the same record a purchase makes, no money, no limit check beyond the yard size.
func give(type: String, pos: Vector3, yaw := 0.0) -> Dictionary:
	if spec(type).is_empty() or vehicles.size() >= int(cfg.get("max_vehicles", 4)) + 1:
		return {}
	var v := {"id": next_id, "type": type, "position": [pos.x, pos.y, pos.z], "yaw": yaw, "cargo": {}, "name": str(spec(type)["title"])}
	next_id += 1
	vehicles.append(v)
	return v

func owns_type(type: String) -> bool:
	for v in vehicles:
		if str(v["type"]) == type:
			return true
	return false

func upgrade_block_reason(key: String) -> String:
	var u: Dictionary = cfg["upgrades"].get(key, {})
	if u.is_empty():
		return "Unknown upgrade"
	if upgrades[key]:
		return "Installed"
	if str(u.get("vehicle", "")) != "" and not owns_kind(str(u["vehicle"])):
		return "Buy a %s first" % str(u["vehicle"])
	if str(u.get("vehicle", "")) == "" and vehicles.is_empty():
		return "Buy a vehicle first"
	if state.money < int(u["cost"]):
		return "Need $%d" % int(u["cost"])
	return ""

func buy_upgrade(key: String) -> bool:
	if upgrade_block_reason(key) != "":
		return false
	state.money -= int(cfg["upgrades"][key]["cost"])
	upgrades[key] = true
	return true

# ------------------------------------------------------------------ performance

func capacity(v: Dictionary) -> int:
	var c := int(spec(str(v["type"]))["capacity"])
	for key in ["bucket", "cargo"]:
		var u: Dictionary = cfg["upgrades"][key]
		if upgrades[key] and str(u["vehicle"]) == kind(str(v["type"])):
			c += int(u["capacity_add"])
	return c

func cargo_total(v: Dictionary) -> int:
	var n := 0
	for k in v["cargo"]:
		n += int(v["cargo"][k])
	return n

func space(v: Dictionary) -> int:
	return maxi(0, capacity(v) - cargo_total(v))

func load_ratio(v: Dictionary) -> float:
	return float(cargo_total(v)) / float(maxi(1, capacity(v)))

func accel(v: Dictionary) -> float:
	var s := spec(str(v["type"]))
	var penalty := float(cfg.get("load_penalty", 0.45))
	var a := float(s["accel"])
	if upgrades["engine"]:
		a *= float(cfg["upgrades"]["engine"]["accel_mult"])
		penalty *= float(cfg["upgrades"]["engine"]["load_penalty_mult"])
	return a * (1.0 - penalty * load_ratio(v))

func max_speed(v: Dictionary) -> float:
	var m := float(spec(str(v["type"]))["max_speed"])
	if upgrades["engine"]:
		m *= float(cfg["upgrades"]["engine"]["speed_mult"])
	return m

# ------------------------------------------------------------------ material handling

func add_cargo(v: Dictionary, res: String, n: int) -> int:
	var taken := mini(n, space(v))
	if taken <= 0 or not state.inventory.has(res):
		return 0
	v["cargo"][res] = int(v["cargo"].get(res, 0)) + taken
	return taken

func take_cargo(v: Dictionary, res: String, n: int) -> int:
	var taken := mini(n, int(v["cargo"].get(res, 0)))
	if taken <= 0:
		return 0
	v["cargo"][res] = int(v["cargo"][res]) - taken
	if int(v["cargo"][res]) <= 0:
		v["cargo"].erase(res)
	return taken

func pile_active(id: String) -> bool:
	var p: Dictionary = cfg["piles"].get(id, {})
	return not p.is_empty() and (not bool(p.get("expansion", false)) or business.expansion_unlocked)

func pile_resource(id: String) -> String:
	return str(cfg["piles"][id]["resource"])

## Loader scoop from a rubble pile: removes exactly what enters the bucket.
func scoop_pile(v: Dictionary, id: String) -> int:
	if kind(str(v["type"])) not in ["loader", "excavator"] or not piles.has(id) or not pile_active(id):
		return 0
	var n := mini(space(v), int(piles[id]["amount"]))
	if n <= 0:
		return 0
	piles[id]["amount"] = int(piles[id]["amount"]) - n
	add_cargo(v, pile_resource(id), n)
	return n

## Dump into a production endpoint (storage crate, crusher hopper, output storage).
## Material the target cannot accept stays in the vehicle.
func dump_to(v: Dictionary, ep: Dictionary) -> int:
	var moved := 0
	for res in v["cargo"].keys():
		var n := business.ep_put(ep, res, int(v["cargo"][res]), false)
		take_cargo(v, res, n)
		moved += n
	return moved

## Loader bucket -> truck bed.
func transfer(from: Dictionary, to: Dictionary) -> int:
	if from == to or kind(str(to["type"])) != "truck":
		return 0
	var moved := 0
	for res in from["cargo"].keys():
		var n := add_cargo(to, res, int(from["cargo"][res]))
		take_cargo(from, res, n)
		moved += n
	return moved

## Rubble regrows one unit per pile every `pile_regen_minutes` of game time.
func tick() -> void:
	var now := int(floor(state.clock_minutes))
	if pile_minute < 0 or pile_minute > now:
		pile_minute = now
		return
	var every := maxi(1, int(cfg.get("pile_regen_minutes", 5)))
	var cap := int(cfg.get("pile_max", 30))
	while pile_minute < now:
		pile_minute += 1
		if pile_minute % every == 0:
			for id in piles:
				if pile_active(id):
					piles[id]["amount"] = mini(cap, int(piles[id]["amount"]) + 1)

func total_material() -> int:
	var n := 0
	for v in vehicles:
		n += cargo_total(v)
	return n

# ------------------------------------------------------------------ save / load

func snapshot() -> Dictionary:
	return {"vehicles": vehicles.duplicate(true), "next_id": next_id, "upgrades": upgrades.duplicate(), "piles": piles.duplicate(true), "pile_minute": pile_minute, "driving_id": driving_id}

## Empty dictionary (Phase 1/2 save) gives no vehicles, full piles, no upgrades.
func restore(data: Dictionary) -> void:
	vehicles.clear()
	for raw in data.get("vehicles", []):
		if raw is Dictionary and cfg["vehicles"].has(str(raw.get("type", ""))) and raw.get("position") is Array and raw["position"].size() == 3:
			var cargo := {}
			for k in raw.get("cargo", {}):
				if state.inventory.has(k) and int(raw["cargo"][k]) > 0:
					cargo[k] = int(raw["cargo"][k])
			var same := 1
			for o in vehicles:
				if str(o["type"]) == str(raw["type"]):
					same += 1
			vehicles.append({"id": int(raw.get("id", 0)), "type": str(raw["type"]), "position": raw["position"].duplicate(), "yaw": float(raw.get("yaw", 0.0)), "cargo": cargo,
				"name": str(raw.get("name", "%s %d" % [spec(str(raw["type"]))["title"], same]))})
	next_id = int(data.get("next_id", 1))
	for v in vehicles:
		next_id = maxi(next_id, int(v["id"]) + 1)
		# Never trust a saved load above capacity.
		while cargo_total(v) > capacity(v):
			take_cargo(v, v["cargo"].keys()[0], cargo_total(v) - capacity(v))
	for k in upgrades:
		upgrades[k] = bool(data.get("upgrades", {}).get(k, false))
	var cap := int(cfg.get("pile_max", 30))
	for id in piles:
		piles[id]["amount"] = clampi(int(data.get("piles", {}).get(id, {}).get("amount", cap)), 0, cap)
	pile_minute = int(data.get("pile_minute", int(floor(state.clock_minutes))))
	driving_id = int(data.get("driving_id", -1))
