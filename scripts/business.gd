extends RefCounted
class_name QuarryBusiness
## Phase 2 business simulation: employees, payroll, upgrades, structures, conveyors,
## automated sales and milestones. Pure data so it can be tested with accelerated time.
## Scene nodes (workers, machines) call into this class; it never touches nodes itself.

signal milestone_reached(id: String)
## A Cash Hopper finished selling `units` of `res` (one signal per material per tick, so a fast hopper groups its feedback; every unit is still accounted for).
signal cash_sold(index: int, res: String, units: int, money: int)

const PROFESSIONS := ["miner", "operator", "hauler"]      ## the sales clerk was retired: the Cash Hopper sells the stone (old saves drop their clerks on load)
const MINERALS := ["limestone", "coal", "iron_ore", "copper_ore", "gold_ore", "topsoil", "gravel"]
const SELL_ORDER := ["gold_ore", "copper_ore", "crushed_stone", "iron_ore", "coal", "limestone", "gravel", "topsoil"]
const MILESTONES := ["first_employee", "mechanized", "automated"]
const CHAIN_STEPS := ["mined", "fed", "processed", "stored", "sold"]
const TIME_STATS := ["strike_interval", "pickup_seconds", "load_seconds", "downtime", "handle_seconds", "sell_interval"]
const STORAGE_POS := Vector3(10, 0, 10) # default (Phase 1/2) storage crate position

var state: QuarryState
var cfg: Dictionary
var employees: Array = []
var next_employee_id := 1
var outputs: Array = []
var conveyors: Array = []
var inventory := {}                    ## delivered, not yet placed: "crusher", "conveyor_left", ...
var links: Array = []          # runtime, per conveyor: {"src": ep, "dst": ep, "resource": String}
var crusher_outputs: Array = [] # runtime, per crusher: index of directly attached output storage or -1
var authorized := {"limestone": false, "coal": false, "iron_ore": false, "crushed_stone": false, "copper_ore": false, "gold_ore": false, "topsoil": false, "gravel": false}
var milestones := {"first_employee": false, "mechanized": false, "automated": false}
var chain := {"mined": false, "fed": false, "processed": false, "stored": false, "sold": false}
var expansion_unlocked := false
var outstanding_debt := 0.0
var payroll_minute := -1
var daily := {}
var storage_pos := STORAGE_POS        # Phase 3: the storage crate can be relocated
var auto_crushed_sold := 0            # crushed stone sold through a Cash Hopper (milestone 3 goal; it was the clerk's before)
var prog                               # Phase 5 QuarryProgression (rig endpoints); set by main

func _init(quarry_state: QuarryState, settings: Dictionary = {}) -> void:
	state = quarry_state
	cfg = settings
	payroll_minute = int(floor(state.clock_minutes))

# ---------------------------------------------------------------- employees

func max_employees() -> int:
	return int(cfg.get("max_employees", 4))

func profession(key: String) -> Dictionary:
	return cfg["professions"].get(key, {})

func candidate(id: String) -> Dictionary:
	for c in cfg.get("candidates", []):
		if str(c["id"]) == id:
			return c
	return {}

func is_hired(candidate_id: String) -> bool:
	for e in employees:
		if str(e["candidate"]) == candidate_id:
			return true
	return false

func available_candidates() -> Array:
	var result := []
	for c in cfg.get("candidates", []):
		if not is_hired(str(c["id"])) and str(c.get("profession", "")) in PROFESSIONS:
			result.append(c)
	return result

func employee(id: int) -> Dictionary:
	for e in employees:
		if int(e["id"]) == id:
			return e
	return {}

func hire_block_reason(candidate_id: String) -> String:
	var c := candidate(candidate_id)
	if c.is_empty():
		return "Unknown candidate"
	if is_hired(candidate_id):
		return "Already employed"
	if employees.size() >= max_employees():
		return "Staff limit reached (%d)" % max_employees()
	if outstanding_debt > 0.0:
		return "Pay outstanding wages first"
	if state.money < hire_fee(c):
		return "Need $%d hiring fee" % hire_fee(c)
	return ""

const PERSONALITIES := ["friendly", "quiet", "enthusiastic", "serious", "humorous"]
const VARIANTS := 4
const HAIR_STYLES_F := ["ponytail", "bun", "long", "short"]
const HAIR_STYLES_M := ["short", "short", "cropped", "short"]
const ACCESSORIES := ["none", "hardhat", "cap", "glasses", "bandana", "earmuffs"]

## A worker's look (Phase 8.3): gender, hair style and colour, skin tone, height, outfit tint and one accessory. All of it is
## chosen once, stored with the employee and shown on the same character model, so a worker always looks the same.
static func make_look(gender: String, rng: RandomNumberGenerator) -> Dictionary:
	var styles: Array = HAIR_STYLES_F if gender == "f" else HAIR_STYLES_M
	return {"gender": gender, "hair": str(styles[rng.randi() % styles.size()]), "hair_tone": rng.randi() % 6, "skin": rng.randi() % 6,
		"height": rng.randi() % 4, "outfit": rng.randi() % 6, "accessory": str(ACCESSORIES[rng.randi() % ACCESSORIES.size()])}

static func look_from_id(id: int, gender: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 7919 + 17
	return make_look(gender, rng)

## Older saves have no identity fields: a stable personality and look from the employee id, and no introduction to replay.
static func ensure_identity(e: Dictionary) -> void:
	var id := int(e.get("id", 0))
	if not PERSONALITIES.has(str(e.get("personality", ""))):
		e["personality"] = PERSONALITIES[(id * 7 + 3) % PERSONALITIES.size()]
	e["variant"] = clampi(int(e.get("variant", id % VARIANTS)), 0, VARIANTS - 1)
	if not e.has("intro_done"):
		e["intro_done"] = true
	if not (e.get("look") is Dictionary):
		e["look"] = look_from_id(id, str(e.get("gender", "f" if id % 2 == 0 else "m")))
		e["look"]["height"] = int(e["variant"])
	e["gender"] = str(e["look"].get("gender", "m"))

## Custom names: trimmed, 1-20 characters, no control characters. Returns the stored name.
func rename_employee(id: int, new_name: String) -> String:
	var e := employee(id)
	if e.is_empty():
		return ""
	var n := new_name.strip_edges().replace("\n", " ").replace("\t", " ").substr(0, 20).strip_edges()
	if n != "":
		e["name"] = n
	return str(e["name"])

var _rng_look := RandomNumberGenerator.new()

func _look_rng() -> RandomNumberGenerator:
	_rng_look.randomize()
	return _rng_look

func hire(candidate_id: String) -> Dictionary:
	if hire_block_reason(candidate_id) != "":
		return {}
	var c := candidate(candidate_id)
	state.money -= hire_fee(c)
	var prof := str(c["profession"])
	var shift: Array = cfg.get("default_shifts", {}).get(prof, [480, 960])
	var e := {
		"id": next_employee_id, "candidate": candidate_id, "name": str(c["name"]), "profession": prof,
		"skill": int(c["skill"]), "base_wage": float(c["wage"]), "upgrade": 0,
		"assignment": default_assignment(prof), "shift_start": int(shift[0]), "shift_end": int(shift[1]),
		"owed": 0.0, "suspended": false, "carry": {}, "position": [], "yaw": 0.0,
		"task": "Arriving", "warning": "",
		"personality": PERSONALITIES[randi() % PERSONALITIES.size()], "variant": randi() % VARIANTS, "intro_done": false,
		"gender": str(c.get("gender", "m")), "look": QuarryBusiness.make_look(str(c.get("gender", "m")), _look_rng()),
		"stats": {"day": current_day(), "units_today": 0, "units_total": 0, "minutes_today": 0, "minutes_total": 0, "paid_today": 0, "paid_total": 0}
	}
	e["look"]["height"] = int(e["variant"])      # the old single "variant" and the new look agree on height
	next_employee_id += 1
	employees.append(e)
	_add_daily("hire_fees", hire_fee(c))
	check_milestones()
	return e

func fire(id: int) -> bool:
	var e := employee(id)
	if e.is_empty():
		return false
	# Final wages are always settled or kept as debt; firing never erases what is owed.
	var due := int(ceil(float(e["owed"]) - 0.0001))
	if due > 0 and state.money >= due:
		state.money -= due
		_record_wage(e, due)
	elif due > 0:
		outstanding_debt += float(e["owed"])
	employees.erase(e)
	check_milestones()
	return true

func default_assignment(prof: String) -> Dictionary:
	match prof:
		"miner": return {"resource": "limestone"}
		"operator": return {"crusher": 0}
		"hauler": return {"src": {"type": "storage"}, "dst": {"type": "crusher", "index": 0}}
	return {}

func assignment_valid(prof: String, a: Dictionary) -> bool:
	match prof:
		"miner":
			return a.size() == 1 and str(a.get("resource", "")) in MINERALS
		"operator":
			return a.size() == 1 and a.has("crusher") and int(a["crusher"]) >= 0
		"hauler":
			return a.size() == 2 and a.get("src") is Dictionary and a.get("dst") is Dictionary and route_resource(a["src"], a["dst"]) != ""
	return false

func assign(id: int, a: Dictionary) -> bool:
	var e := employee(id)
	if e.is_empty() or not assignment_valid(str(e["profession"]), a):
		return false
	e["assignment"] = a.duplicate(true)
	e["warning"] = ""
	return true

func set_shift(id: int, start_minute: int, end_minute: int) -> bool:
	var e := employee(id)
	start_minute = posmod(start_minute, 1440)
	end_minute = posmod(end_minute, 1440)
	if e.is_empty() or start_minute == end_minute:
		return false
	e["shift_start"] = start_minute
	e["shift_end"] = end_minute
	return true

static func on_shift_at(start_minute: int, end_minute: int, minute_of_day: int) -> bool:
	if start_minute == end_minute:
		return false
	if start_minute < end_minute:
		return minute_of_day >= start_minute and minute_of_day < end_minute
	return minute_of_day >= start_minute or minute_of_day < end_minute # overnight shift

func shift_hours(e: Dictionary) -> float:
	return float(posmod(int(e["shift_end"]) - int(e["shift_start"]), 1440)) / 60.0

func on_shift(e: Dictionary) -> bool:
	return on_shift_at(int(e["shift_start"]), int(e["shift_end"]), posmod(int(floor(state.clock_minutes)), 1440))

## True when the employee may perform work right now: on shift and paid up.
func can_work(e: Dictionary) -> bool:
	return employees.has(e) and on_shift(e) and not bool(e["suspended"])

func wage(e: Dictionary) -> float:
	return (float(e["base_wage"]) + float(cfg.get("wage_per_upgrade", 0.5)) * int(e["upgrade"])) * float(cfg.get("wage_scale", 1.0))

## Phase 5: hiring fees and wages scale with the much more productive quarry (data/business.json).
func hire_fee(c: Dictionary) -> int:
	return int(round(float(c["hire_fee"]) * float(cfg.get("hire_fee_scale", 1.0))))

# ---------------------------------------------------------------- upgrades & stats

func upgrade_info(e: Dictionary) -> Dictionary:
	var path: Array = profession(str(e["profession"])).get("upgrades", [])
	var level := int(e["upgrade"])
	if level >= path.size():
		return {}
	return path[level]

func buy_upgrade(id: int) -> bool:
	var e := employee(id)
	if e.is_empty():
		return false
	var info := upgrade_info(e)
	if info.is_empty() or state.money < int(info["cost"]):
		return false
	state.money -= int(info["cost"])
	e["upgrade"] = int(e["upgrade"]) + 1
	_add_daily("upgrades", int(info["cost"]))
	return true

func work_multiplier(e: Dictionary) -> float:
	var m := 1.0 + float(cfg.get("skill_speed_bonus", 0.15)) * (int(e["skill"]) - 1)
	if milestones["first_employee"]:
		m *= 1.0 + float(cfg.get("milestone_productivity_bonus", 0.05))
	return m

## Profession stat after upgrades, skill and milestone bonus. Durations shrink, others grow.
func stat(e: Dictionary, key: String) -> float:
	var prof := profession(str(e["profession"]))
	var value := float(prof.get(key, 0.0))
	var path: Array = prof.get("upgrades", [])
	for i in range(mini(int(e["upgrade"]), path.size())):
		var u: Dictionary = path[i]
		if str(u["stat"]) == key:
			value = value * float(u.get("mult", 1.0)) + float(u.get("add", 0.0))
	if key in TIME_STATS:
		value /= work_multiplier(e)
	return value

func carry_total(e: Dictionary) -> int:
	var n := 0
	for v in e["carry"].values():
		n += int(v)
	return n

func carry_add(e: Dictionary, res: String, n: int) -> void:
	e["carry"][res] = int(e["carry"].get(res, 0)) + n

func carry_take(e: Dictionary, res: String, n: int) -> int:
	var taken := mini(n, int(e["carry"].get(res, 0)))
	e["carry"][res] = int(e["carry"].get(res, 0)) - taken
	if int(e["carry"][res]) <= 0:
		e["carry"].erase(res)
	return taken

func note_mined(e: Dictionary, n: int) -> void:
	if n <= 0:
		return
	record_units(e, n)
	_add_daily("mined", n)
	chain["mined"] = true
	check_milestones()

func note_hauled(e: Dictionary, n: int) -> void:
	if n <= 0:
		return
	record_units(e, n)
	_add_daily("hauled", n)

func record_units(e: Dictionary, n: int) -> void:
	_roll_employee_day(e)
	e["stats"]["units_today"] += n
	e["stats"]["units_total"] += n

# ---------------------------------------------------------------- payroll

func current_day() -> int:
	return int(floor(state.clock_minutes / 1440.0))

## The starter box (the storage crate) empties its loose dirt (topsoil, gravel) into Grandpa's Cash Hopper by itself, dearest first, at STARTER_FEED_RATE units a second while the hopper has room.
## Dump a bucket in the box and it is sold; the crate can still be emptied by hand from its menu.
const STARTER_FEED_RATE := 12.0
const STARTER_FEED_KINDS := ["gravel", "topsoil"]         # the loose dirt you dig; the box feeds the hopper with it
var starter_feed := true
var _feed_acc := 0.0

func tick_starter_feed(seconds: float) -> void:
	if not starter_feed or int(state.storage.get("topsoil", 0)) + int(state.storage.get("gravel", 0)) <= 0:
		_feed_acc = 0.0
		return
	var hs := cash_hopper_indices()
	if hs.is_empty():
		return
	_feed_acc += STARTER_FEED_RATE * seconds
	var ep := {"type": "output", "index": int(hs[0])}
	for res in SELL_ORDER:
		if _feed_acc < 1.0:
			break
		if not STARTER_FEED_KINDS.has(res):
			continue                      # stone, coal and ore stay in the crate for the crusher chain and the haulers
		var n := mini(mini(int(_feed_acc), int(state.storage.get(res, 0))), ep_space(ep, res))
		if n <= 0:
			continue
		state.storage[res] = int(state.storage[res]) - n
		ep_put(ep, res, n, false)
		_feed_acc -= float(n)
	if int(state.storage.get("topsoil", 0)) + int(state.storage.get("gravel", 0)) <= 0:
		_feed_acc = 0.0

## Advance business time. Payroll is evaluated once per whole in-game minute,
## so large ticks (accelerated tests) and overnight shifts are handled exactly.
func tick(seconds: float) -> void:
	tick_sorters(seconds)
	_process_payroll()
	tick_conveyors(seconds)
	tick_cash_hoppers(seconds)
	tick_starter_feed(seconds)
	_scan_crushers()

func _process_payroll() -> void:
	var now := int(floor(state.clock_minutes))
	if payroll_minute < 0 or payroll_minute > now:
		payroll_minute = now
		return
	while payroll_minute < now:
		_process_minute(payroll_minute)
		payroll_minute += 1

func _process_minute(minute: int) -> void:
	var minute_of_day := posmod(minute, 1440)
	if outstanding_debt > 0.0:
		var debt_due := int(ceil(outstanding_debt - 0.0001))
		if state.money >= debt_due:
			state.money -= debt_due
			outstanding_debt = 0.0
			_add_daily("wages", debt_due, minute)
	for e in employees:
		_settle(e, minute)
		if on_shift_at(int(e["shift_start"]), int(e["shift_end"]), minute_of_day) and not bool(e["suspended"]):
			e["owed"] = float(e["owed"]) + wage(e) / 60.0
			_roll_employee_day(e, minute)
			e["stats"]["minutes_today"] += 1
			e["stats"]["minutes_total"] += 1
			_settle(e, minute)

func _settle(e: Dictionary, minute: int) -> void:
	var due := int(floor(float(e["owed"]) + 0.0001))
	if due <= 0:
		e["suspended"] = false
		return
	if state.money >= due:
		state.money -= due
		e["owed"] = maxf(0.0, float(e["owed"]) - due)
		e["suspended"] = false
		_record_wage(e, due, minute)
	else:
		e["suspended"] = true # stops working; wages stay owed until funds are available

func _record_wage(e: Dictionary, amount: int, minute := -1) -> void:
	_roll_employee_day(e, minute)
	e["stats"]["paid_today"] += amount
	e["stats"]["paid_total"] += amount
	_add_daily("wages", amount, minute)

func _roll_employee_day(e: Dictionary, minute := -1) -> void:
	var day := current_day() if minute < 0 else int(floor(minute / 1440.0))
	var s: Dictionary = e["stats"]
	if int(s["day"]) != day:
		s["day"] = day
		s["units_today"] = 0
		s["minutes_today"] = 0
		s["paid_today"] = 0

func unpaid_total() -> float:
	var total := outstanding_debt
	for e in employees:
		total += float(e["owed"])
	return total

func _add_daily(key: String, amount: int, minute := -1) -> void:
	var day := current_day() if minute < 0 else int(floor(minute / 1440.0))
	var k := str(day)
	if not daily.has(k):
		daily[k] = {"wages": 0, "revenue": 0, "mined": 0, "hauled": 0, "conveyed": 0, "crushed": 0, "sold": 0, "hire_fees": 0, "upgrades": 0}
		var keys: Array = daily.keys()
		keys.sort_custom(func(a, b): return int(a) < int(b))
		while keys.size() > 7:
			daily.erase(keys.pop_front())
	daily[k][key] = int(daily[k].get(key, 0)) + amount

func day_stats(day: int) -> Dictionary:
	return daily.get(str(day), {"wages": 0, "revenue": 0, "mined": 0, "hauled": 0, "conveyed": 0, "crushed": 0, "sold": 0, "hire_fees": 0, "upgrades": 0})

func record(key: String, amount: int) -> void:
	_add_daily(key, amount)

# ---------------------------------------------------------------- endpoints (storage, machines)
# An endpoint is {"type": "storage"|"crusher"|"output"|"conveyor"|"deposit", "index": int, "resource": String}

func output_capacity() -> int:
	return int(cfg.get("output_capacity", 30))

func output_total(i: int) -> int:
	return state.total(outputs[i]["items"])

# ---------------------------------------------------------------- Phase 9.6: hopper and sorting table (variants of the output bin)
# Both are "output" structures with a "variant": the same placement, belts (links), workers' endpoints, selling and saving. A
# plain output bin takes crushed stone only; the Small Hopper takes any material (capacity hopper_capacity); the Manual Sorting
# Table takes the three raw rocks and can sort them (see sorter_*).

const SORTABLE := ["limestone", "coal", "iron_ore"]

func variant_of(i: int) -> String:
	return str(outputs[i].get("variant", "output")) if i >= 0 and i < outputs.size() else "output"

func output_capacity_of(i: int) -> int:
	match variant_of(i):
		"hopper": return int(cfg.get("hopper_capacity", 60))
		"sorter": return int(cfg.get("sorter_capacity", 36))
		"cash_hopper": return int(cash_tier(i).get("capacity", 300))
	return output_capacity()

func variant_accepts(i: int, res: String) -> bool:
	match variant_of(i):
		"hopper": return true
		"sorter": return res in SORTABLE
		"cash_hopper": return res in QuarryState.RESOURCE_NAMES
	return res == "crushed_stone"

## Sorted units are a flag on units that stay in the table's items: they are never created, and leave with the items.
func sorter_sorted(i: int, res: String) -> int:
	return mini(int(outputs[i].get("sorted", {}).get(res, 0)), int(outputs[i]["items"].get(res, 0)))

func sorter_unsorted(i: int, res: String) -> int:
	var pending := int(outputs[i].get("sort_job", {}).get(res, 0))
	return maxi(0, int(outputs[i]["items"].get(res, 0)) - sorter_sorted(i, res) - pending)

func sorter_busy(i: int) -> bool:
	return float(outputs[i].get("sort_left", 0.0)) > 0.0

## Starts sorting one batch: up to sort_batch units of the rock the table holds most of (not yet sorted).
func sorter_start(i: int) -> bool:
	if variant_of(i) != "sorter" or sorter_busy(i):
		return false
	var best := ""
	var best_n := 0
	for res in SORTABLE:
		var n := sorter_unsorted(i, res)
		if n > best_n:
			best_n = n
			best = res
	if best == "":
		return false
	outputs[i]["sort_job"] = {best: mini(best_n, int(cfg.get("sort_batch", 10)))}
	outputs[i]["sort_left"] = float(cfg.get("sort_seconds", 6.0))
	return true

func tick_sorters(seconds: float) -> void:
	for i in range(outputs.size()):
		var o: Dictionary = outputs[i]
		if float(o.get("sort_left", 0.0)) <= 0.0:
			continue
		o["sort_left"] = maxf(0.0, float(o["sort_left"]) - seconds)
		if float(o["sort_left"]) <= 0.0:
			if not o.has("sorted"):
				o["sorted"] = {}
			for res in o.get("sort_job", {}):
				var n := mini(int(o["sort_job"][res]), int(o["items"].get(res, 0)) - sorter_sorted(i, str(res)))
				o["sorted"][res] = sorter_sorted(i, str(res)) + maxi(0, n)
			o["sort_job"] = {}

## Sorted rock sells at sort_bonus times the price. The units leave the table and are paid for; returns the money.
func sorter_sell(i: int) -> int:
	if variant_of(i) != "sorter":
		return 0
	var total := 0
	for res in SORTABLE:
		var n := sorter_sorted(i, res)
		if n <= 0:
			continue
		outputs[i]["items"][res] = int(outputs[i]["items"][res]) - n
		outputs[i]["sorted"][res] = int(outputs[i]["sorted"].get(res, 0)) - n
		var pay := state.payout(res, n, float(cfg.get("sort_bonus", 1.3)))
		state.add_income(pay, "sorted")
		state.note_lifetime("sold", res, n)
		total += pay
	return total

func ep_valid(ep: Dictionary) -> bool:
	match str(ep.get("type", "")):
		"storage": return true
		"crusher": return int(ep.get("index", -1)) >= 0 and int(ep["index"]) < state.crushers.size()
		"output": return int(ep.get("index", -1)) >= 0 and int(ep["index"]) < outputs.size()
		"conveyor": return int(ep.get("index", -1)) >= 0 and int(ep["index"]) < conveyors.size()
		"deposit": return str(ep.get("resource", "")) in MINERALS
		"rig": return prog != null and int(ep.get("index", -1)) >= 0 and int(ep["index"]) < prog.rigs.size()
	return false

## Units of `res` the endpoint can still accept.
func ep_space(ep: Dictionary, res: String) -> int:
	if not ep_valid(ep) or res == "":
		return 0
	match str(ep["type"]):
		"storage":
			if not state.storage.has(res):
				return 0                      # loose "soil" is not a stored material: it goes on the spoil heap
			return maxi(0, state.storage_capacity() - state.total(state.storage))
		"crusher":
			if res != "limestone":
				return 0
			var hc := int(cfg.get("crusher_hopper_capacity", 24)) * (2 if int(state.crushers[int(ep["index"])].get("tier", 1)) >= 2 else 1)
			return maxi(0, hc - int(state.crushers[int(ep["index"])].get("hopper", 0)))
		"output":
			if not variant_accepts(int(ep["index"]), res):
				return 0
			return maxi(0, output_capacity_of(int(ep["index"])) - output_total(int(ep["index"])))
		"conveyor":
			var c: Dictionary = conveyors[int(ep["index"])]
			if int(c["items"]) > 0 and str(c["resource"]) != res:
				return 0
			return maxi(0, int(cfg.get("conveyor_capacity", 3)) - int(c["items"]))
	return 0

## `automated` is false for player-driven deliveries (vehicles), which never count toward the chain milestone.
func ep_put(ep: Dictionary, res: String, n: int, automated := true) -> int:
	var added := mini(n, ep_space(ep, res))
	if added <= 0:
		return 0
	match str(ep["type"]):
		"storage": state.storage[res] = int(state.storage[res]) + added
		"crusher":
			var crusher: Dictionary = state.crushers[int(ep["index"])]
			crusher["hopper"] = int(crusher.get("hopper", 0)) + added
			if automated:
				chain["fed"] = true
		"output":
			outputs[int(ep["index"])]["items"][res] = int(outputs[int(ep["index"])]["items"].get(res, 0)) + added
			if automated:
				chain["stored"] = true
		"conveyor":
			var c: Dictionary = conveyors[int(ep["index"])]
			c["items"] = int(c["items"]) + added
			c["resource"] = res
	check_milestones()
	return added

func ep_available(ep: Dictionary, res: String) -> int:
	if not ep_valid(ep) or res == "":
		return 0
	match str(ep["type"]):
		"storage": return int(state.storage.get(res, 0))
		"crusher": return int(state.crushers[int(ep["index"])]["output"]) if res == "crushed_stone" else 0
		"output": return int(outputs[int(ep["index"])]["items"].get(res, 0))
		"rig": return int(prog.rigs[int(ep["index"])]["bin"].get(res, 0))
	return 0

func ep_take(ep: Dictionary, res: String, n: int) -> int:
	var taken := mini(n, ep_available(ep, res))
	if taken <= 0:
		return 0
	match str(ep["type"]):
		"storage": state.storage[res] = int(state.storage[res]) - taken
		"crusher": state.crushers[int(ep["index"])]["output"] = int(state.crushers[int(ep["index"])]["output"]) - taken
		"output": outputs[int(ep["index"])]["items"][res] = int(outputs[int(ep["index"])]["items"][res]) - taken
		"rig": prog.rig_take(prog.rigs[int(ep["index"])], res, taken)
	return taken

## Resource carried along a hauler route, or "" when the route makes no sense.
func route_resource(src: Dictionary, dst: Dictionary) -> String:
	var st := str(src.get("type", ""))
	var dt := str(dst.get("type", ""))
	if st == dt and int(src.get("index", 0)) == int(dst.get("index", 0)):
		return ""
	var res := ""
	match st:
		"deposit": res = str(src.get("resource", ""))
		"rig": res = prog.rig_resource(prog.rigs[int(src["index"])]) if ep_valid(src) else ""
		"crusher", "output": res = "crushed_stone"
		"storage":
			match dt:
				"crusher": res = "limestone"
				"output": res = "crushed_stone"
	var to_cash := dt == "output" and is_cash_hopper(int(dst.get("index", -1)))
	if to_cash and st == "storage":
		return "auto"                      # a belt from the crate to a Cash Hopper carries whatever the crate holds (see _auto_resource)
	if to_cash and st in ["deposit", "rig"] and res != "":
		return res
	if res == "" or not dt in ["storage", "crusher", "output"]:
		return ""
	if dt == "crusher" and res != "limestone":
		return ""
	if dt == "output" and res != "crushed_stone":
		return ""
	return res

# ---------------------------------------------------------------- machines (operator)

func hopper_to_input(index: int) -> int:
	if index < 0 or index >= state.crushers.size():
		return 0
	var crusher: Dictionary = state.crushers[index]
	if bool(crusher["running"]) or int(crusher.get("hopper", 0)) <= 0 or int(crusher["input"]) >= state.input_limit(index):
		return 0
	crusher["hopper"] = int(crusher["hopper"]) - 1
	crusher["input"] = int(crusher["input"]) + 1
	return 1

func crusher_output_full(index: int) -> bool:
	var crusher: Dictionary = state.crushers[index]
	return int(crusher["output"]) + int(crusher["input"]) > int(cfg.get("crusher_output_capacity", 24)) * (2 if int(crusher.get("tier", 1)) >= 2 else 1)

func operator_start(e: Dictionary, index: int) -> bool:
	if str(e["profession"]) != "operator" or not can_work(e):
		return false
	if index < 0 or index >= state.crushers.size() or crusher_output_full(index):
		return false
	return state.start_crusher(index, stat(e, "process_factor"), true)

## Operator collection into a directly attached output storage.
func operator_collect(e: Dictionary, index: int) -> int:
	if str(e["profession"]) != "operator" or index < 0 or index >= crusher_outputs.size():
		return 0
	var out := int(crusher_outputs[index])
	if out < 0:
		return 0
	var target := {"type": "output", "index": out}
	var n := ep_take({"type": "crusher", "index": index}, "crushed_stone", ep_space(target, "crushed_stone"))
	ep_put(target, "crushed_stone", n)
	return n

func _scan_crushers() -> void:
	for crusher in state.crushers:
		var done := int(crusher.get("auto_done", 0))
		if done > 0:
			crusher["auto_done"] = 0
			chain["processed"] = true
			_add_daily("crushed", done)
			check_milestones()

# ---------------------------------------------------------------- selling from every store

## Units of a material waiting in output storages and hoppers (the sorting table has its own sale).
func output_units(res: String) -> int:
	var n := 0
	for i in range(outputs.size()):
		if variant_of(i) != "sorter" and variant_of(i) != "cash_hopper":      # a Cash Hopper's queue is already on its way to being sold
			n += int(outputs[i]["items"].get(res, 0))
	return n

## Everything the sales booth can sell of a material: bag, storage bin, output storages and hoppers.
func sellable_units(res: String) -> int:
	return int(state.inventory.get(res, 0)) + int(state.storage.get(res, 0)) + output_units(res)

## Sells up to `limit` units of a material from the bag, then the storage bin, then the output storages, as ONE sale (one
## rounding, one payment). Returns {"units", "money", "bag", "storage", "output"}.
func sell_material(res: String, limit := 1 << 30) -> Dictionary:
	var out := {"units": 0, "money": 0, "bag": 0, "storage": 0, "output": 0}
	if not state.inventory.has(res):
		return out
	var left := limit
	var nb := mini(left, int(state.inventory[res]))
	state.inventory[res] -= nb
	left -= nb
	var ns := mini(left, int(state.storage.get(res, 0)))
	state.storage[res] = int(state.storage.get(res, 0)) - ns
	left -= ns
	var no := 0
	for i in range(outputs.size()):
		if left <= 0:
			break
		if variant_of(i) == "sorter" or variant_of(i) == "cash_hopper":
			continue
		var t := mini(left, int(outputs[i]["items"].get(res, 0)))
		if t > 0:
			outputs[i]["items"][res] = int(outputs[i]["items"][res]) - t
			left -= t
			no += t
	var units := nb + ns + no
	if units <= 0:
		return out
	var pay := state.payout(res, units)
	state.note_lifetime("sold", res, units)
	state.add_income(pay, "sale")
	out["units"] = units
	out["money"] = pay
	out["bag"] = nb
	out["storage"] = ns
	out["output"] = no
	return out

# ---------------------------------------------------------------- the Cash Hopper (replaces the sales clerk)
# A Cash Hopper is an "output" structure with variant "cash_hopper": the same placement, belts (links), mergers, backpressure and saving as every other bin.
# Whatever sits in its queue is sold one unit at a time at the tier's rate. The price is state.payout (the game's one price table). A unit leaves the queue
# and is paid for in the same step, so it can be removed once and credited once; the hopper never sells from the bag, the crate or other bins by itself.

func is_cash_hopper(i: int) -> bool:
	return variant_of(i) == "cash_hopper"

func cash_hopper_indices() -> Array:
	var out := []
	for i in range(outputs.size()):
		if is_cash_hopper(i):
			out.append(i)
	return out

func cash_tiers() -> Array:
	var t = cfg.get("cash_hopper", {}).get("tiers", [])
	if t is Array and not t.is_empty():
		return t
	return [{"name": "Old Hopper", "rate": 1.0, "capacity": 300, "upgrade_cost": 0}]

func cash_tier_index(i: int) -> int:
	if not is_cash_hopper(i):
		return 0
	return clampi(int(outputs[i].get("tier", 0)), 0, cash_tiers().size() - 1)

func cash_tier(i: int) -> Dictionary:
	return cash_tiers()[cash_tier_index(i)]

func cash_rate(i: int) -> float:
	return maxf(0.0, float(cash_tier(i).get("rate", 1.0)))

## Cost of the next tier, or -1 at the top.
func cash_upgrade_cost(i: int) -> int:
	if not is_cash_hopper(i) or cash_tier_index(i) >= cash_tiers().size() - 1:
		return -1
	return int(cash_tiers()[cash_tier_index(i) + 1].get("upgrade_cost", 0))

func cash_upgrade_block_reason(i: int) -> String:
	if not is_cash_hopper(i):
		return "Not a Cash Hopper"
	var cost := cash_upgrade_cost(i)
	if cost < 0:
		return "Already the best hopper"
	if state.money < cost:
		return "Need $%d" % cost
	return ""

func cash_upgrade(i: int) -> bool:
	if cash_upgrade_block_reason(i) != "":
		return false
	state.money -= cash_upgrade_cost(i)
	outputs[i]["tier"] = cash_tier_index(i) + 1
	return true

## Units waiting in the hopper's queue.
func cash_queue(i: int) -> int:
	return output_total(i) if is_cash_hopper(i) else 0

## The material it is selling right now ("" when idle).
func cash_current(i: int) -> String:
	return str(outputs[i].get("current", "")) if is_cash_hopper(i) else ""

## The queue's next unit: stay on the material in progress, otherwise the dearest material first.
func _cash_next(o: Dictionary) -> String:
	var cur := str(o.get("current", ""))
	if cur != "" and int(o["items"].get(cur, 0)) > 0:
		return cur
	for res in SELL_ORDER:
		if int(o["items"].get(res, 0)) > 0:
			return res
	for res in o["items"]:
		if int(o["items"][res]) > 0:
			return str(res)
	return ""

func cash_today(i: int) -> int:
	if not is_cash_hopper(i) or int(outputs[i].get("today_day", -1)) != current_day():
		return 0
	return int(outputs[i].get("today_money", 0))

func cash_today_units(i: int) -> int:
	if not is_cash_hopper(i) or int(outputs[i].get("today_day", -1)) != current_day():
		return 0
	return int(outputs[i].get("today_units", 0))

## Sells what the hopper's rate allows during `seconds`: each unit leaves the queue and is paid in one step. Works wherever the player is.
func tick_cash_hoppers(seconds: float) -> void:
	for i in range(outputs.size()):
		if not is_cash_hopper(i):
			continue
		var o: Dictionary = outputs[i]
		if state.total(o["items"]) <= 0:
			o["progress"] = 0.0
			o["current"] = ""
			continue
		o["progress"] = minf(float(o.get("progress", 0.0)) + cash_rate(i) * seconds, float(output_capacity_of(i)) + 1.0)
		var sold := {}
		while float(o["progress"]) >= 1.0:
			var res := _cash_next(o)
			if res == "":
				o["progress"] = 0.0
				break
			o["progress"] = float(o["progress"]) - 1.0
			o["current"] = res
			o["items"][res] = int(o["items"][res]) - 1
			var pay := state.payout(res, 1)
			state.note_lifetime("sold", res, 1)
			state.add_income(pay, "hopper")
			_add_daily("revenue", pay)
			_add_daily("sold", 1)
			if int(o.get("today_day", -1)) != current_day():
				o["today_day"] = current_day()
				o["today_money"] = 0
				o["today_units"] = 0
			o["today_money"] = int(o["today_money"]) + pay
			o["today_units"] = int(o["today_units"]) + 1
			o["total_money"] = int(o.get("total_money", 0)) + pay
			o["total_units"] = int(o.get("total_units", 0)) + 1
			if res == "crushed_stone":
				chain["sold"] = true
				auto_crushed_sold += 1
			if not sold.has(res):
				sold[res] = [0, 0]
			sold[res][0] += 1
			sold[res][1] += pay
		if state.total(o["items"]) <= 0:
			o["current"] = ""
			o["progress"] = 0.0
		for res in sold:
			cash_sold.emit(i, str(res), int(sold[res][0]), int(sold[res][1]))
		if not sold.is_empty():
			check_milestones()

## Moves material from the bag into the queue (one transaction per material, clamped to the room left, so nothing is created or lost).
## `keys` = the materials to deposit (empty = every material the bag holds). Returns {material: units}.
func cash_deposit_bag(i: int, keys := []) -> Dictionary:
	var moved := {}
	if not is_cash_hopper(i):
		return moved
	var ep := {"type": "output", "index": i}
	for res in (keys if not keys.is_empty() else state.inventory.keys()):
		var r := str(res)
		var n := mini(int(state.inventory.get(r, 0)), ep_space(ep, r))
		if n <= 0:
			continue
		state.inventory[r] = int(state.inventory[r]) - n
		ep_put(ep, r, n, false)
		moved[r] = n
	return moved

## A carried bucket tipped into the Cash Hopper: moves what fits out of `items` ({resource: units}, modified in place). Returns what went in.
func cash_deposit_items(i: int, items: Dictionary) -> Dictionary:
	var moved := {}
	if not is_cash_hopper(i):
		return moved
	var ep := {"type": "output", "index": i}
	for res in items.keys():
		var r := str(res)
		var n := mini(int(items.get(r, 0)), ep_space(ep, r))
		if n <= 0:
			continue
		items[r] = int(items[r]) - n
		if int(items[r]) <= 0:
			items.erase(r)
		ep_put(ep, r, n, false)
		moved[r] = n
	return moved

## The same from the storage crate (an explicit choice by the player: the crate never sells by itself).
func cash_deposit_crate(i: int, keys := []) -> Dictionary:
	var moved := {}
	if not is_cash_hopper(i):
		return moved
	var ep := {"type": "output", "index": i}
	for res in (keys if not keys.is_empty() else state.storage.keys()):
		var r := str(res)
		var n := mini(int(state.storage.get(r, 0)), ep_space(ep, r))
		if n <= 0:
			continue
		state.storage[r] = int(state.storage[r]) - n
		ep_put(ep, r, n, false)
		moved[r] = n
	return moved

## Tips (part of) a cart's load into the queue; returns the units moved.
func cash_deposit_cart(i: int, cart_id: String, res: String, n: int) -> int:
	if not is_cash_hopper(i):
		return 0
	var ep := {"type": "output", "index": i}
	var m := mini(mini(n, state.cart_units(cart_id, res)), ep_space(ep, res))
	if m <= 0:
		return 0
	state._cart_pull(cart_id, res, m)
	ep_put(ep, res, m, false)
	return m

## Totals over every Cash Hopper, for the Sales application.
func cash_summary() -> Dictionary:
	var q := 0
	var today := 0
	var total := 0
	var rate := 0.0
	for i in cash_hopper_indices():
		q += cash_queue(i)
		today += cash_today(i)
		total += int(outputs[i].get("total_money", 0))
		rate += cash_rate(i)
	return {"hoppers": cash_hopper_indices().size(), "queue": q, "today": today, "total": total, "rate": rate}

# ---------------------------------------------------------------- structures & conveyors

func buy(price: int) -> bool:
	if state.money < price:
		return false
	state.money -= price
	return true

func add_output(pos: Vector3, yaw: float, variant := "output") -> int:
	var items := {}
	for k in QuarryState.RESOURCE_NAMES:
		items[k] = 0
	var rec := {"position": [pos.x, pos.y, pos.z], "yaw": yaw, "items": items, "variant": variant, "sorted": {}, "sort_left": 0.0, "sort_job": {}}
	if variant == "cash_hopper":
		rec.merge({"tier": 0, "progress": 0.0, "current": "", "today_day": -1, "today_money": 0, "today_units": 0, "total_money": 0, "total_units": 0})
	outputs.append(rec)
	compute_links()
	return outputs.size() - 1

## kind: "straight" (2 m, flows along its facing), "left" or "right" (a 90 degree corner: material enters at the back and
## leaves through the left / right side, each half 1 m long).
func add_conveyor(pos: Vector3, yaw: float, kind := "straight") -> int:
	conveyors.append({"position": [pos.x, pos.y, pos.z], "yaw": yaw, "resource": "", "items": 0, "progress": 0.0, "pull": 0.0, "kind": kind})
	compute_links()
	return conveyors.size() - 1

static func v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

static func forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

func crusher_output_port(i: int) -> Vector3:
	var c: Dictionary = state.crushers[i]
	return v3(c["position"]) * Vector3(1, 0, 1) + forward(float(c["yaw"])) * 1.15

func crusher_input_port(i: int) -> Vector3:
	var c: Dictionary = state.crushers[i]
	return v3(c["position"]) * Vector3(1, 0, 1) - forward(float(c["yaw"])) * 1.15

## Half the length of a belt piece (centre to end face): 2 m belts, the 1 m short belt, the 3 m incline. Mergers and splitters are 2 x 2 m.
static func belt_half(kind: String) -> float:
	match kind:
		"short": return 0.5
		"incline": return 1.5
	return 1.0

const BELT_KINDS := ["straight", "left", "right", "merger", "short", "incline", "splitter"]

func conveyor_ends(pos: Vector3, yaw: float, kind := "straight") -> Array:
	var p := pos * Vector3(1, 0, 1)
	if kind == "left":
		return [p - forward(yaw), p + forward(yaw + PI * 0.5)]
	if kind == "right":
		return [p - forward(yaw), p + forward(yaw - PI * 0.5)]
	if kind == "splitter":
		return [p - forward(yaw), p + forward(yaw + PI * 0.5)]            # the input at the back, the first exit at the left side
	var h := belt_half(kind)
	return [p - forward(yaw) * h, p + forward(yaw) * h]

## Where material leaves a piece: its far end, or BOTH sides of a splitter.
func conveyor_outputs(pos: Vector3, yaw: float, kind: String) -> Array:
	var p := pos * Vector3(1, 0, 1)
	if kind == "splitter":
		return [p + forward(yaw + PI * 0.5), p + forward(yaw - PI * 0.5)]
	return [conveyor_ends(pos, yaw, kind)[1]]

## The merger (a 3-way junction): material comes in at the back and at BOTH sides, and leaves through the front. Its two side inlets sit 1 m from its centre.
func conveyor_side_inputs(pos: Vector3, yaw: float, kind: String) -> Array:
	if kind != "merger":
		return []
	var p := pos * Vector3(1, 0, 1)
	return [p + forward(yaw - PI * 0.5), p + forward(yaw + PI * 0.5)]

func belt_price(kind: String) -> int:
	var base := int(cfg["conveyor_price"])
	match kind:
		"merger": return int(cfg.get("merger_price", base * 2))
		"short": return int(cfg.get("short_price", int(base * 0.55)))
		"incline": return int(cfg.get("incline_price", int(base * 1.6)))
		"splitter": return int(cfg.get("splitter_price", int(base * 2.4)))
	return base

## Direction material travels as it leaves a belt piece through its far end.
static func belt_out_dir(yaw: float, kind: String) -> Vector3:
	if kind == "left" or kind == "splitter":
		return forward(yaw + PI * 0.5)
	if kind == "right":
		return forward(yaw - PI * 0.5)
	return forward(yaw)

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

## Nearest compatible endpoint around `point`. `as_source` picks crusher output sides, else input sides.
func _endpoint_near(point: Vector3, as_source: bool, skip_conveyor: int, level := 0.0) -> Dictionary:
	# Phase 1: a belt only connects to something on its own level (a physical connection): endpoints more than LEVEL_TOL above or below
	# the belt end are not linked, however close they are in plan
	for j in range(conveyors.size()):
		if j == skip_conveyor:
			continue
		var ends := conveyor_ends(v3(conveyors[j]["position"]), float(conveyors[j]["yaw"]), str(conveyors[j].get("kind", "straight")))
		var cands: Array = conveyor_outputs(v3(conveyors[j]["position"]), float(conveyors[j]["yaw"]), str(conveyors[j].get("kind", "straight"))) if as_source else [ends[0]]
		var hit := false
		for e in cands:
			if _flat(point, e) < 0.75 and absf(level - v3(conveyors[j]["position"]).y) <= LEVEL_TOL:
				hit = true
		if hit:
			return {"type": "conveyor", "index": j}
		if not as_source:
			for sp in conveyor_side_inputs(v3(conveyors[j]["position"]), float(conveyors[j]["yaw"]), str(conveyors[j].get("kind", "straight"))):
				if _flat(point, sp) < 0.75 and absf(level - v3(conveyors[j]["position"]).y) <= LEVEL_TOL:
					return {"type": "conveyor", "index": j}
	for i in range(state.crushers.size()):
		if _flat(point, crusher_output_port(i) if as_source else crusher_input_port(i)) < 1.0 and absf(level - v3(state.crushers[i]["position"]).y) <= LEVEL_TOL:
			return {"type": "crusher", "index": i}
	for i in range(outputs.size()):
		if _flat(point, v3(outputs[i]["position"])) < 1.7 and absf(level - v3(outputs[i]["position"]).y) <= LEVEL_TOL:
			return {"type": "output", "index": i}
	if _flat(point, storage_pos) < 2.0 and absf(level - storage_pos.y) <= LEVEL_TOL:
		return {"type": "storage"}
	if as_source and prog:
		for i in range(prog.rigs.size()):
			if _flat(point, prog.rig_bin_pos(prog.rigs[i])) < 1.3 and absf(level - prog.rig_bin_pos(prog.rigs[i]).y) <= LEVEL_TOL:
				return {"type": "rig", "index": i}
	return {}

const LEVEL_TOL := 0.75

## Link description for a conveyor at pos/yaw (also used for the placement preview).
func link_for(pos: Vector3, yaw: float, skip_conveyor := -1, kind := "straight") -> Dictionary:
	var ends := conveyor_ends(pos, yaw, kind)
	var out := {"src": _endpoint_near(ends[0], true, skip_conveyor, pos.y), "dst": _endpoint_near(ends[1], false, skip_conveyor, pos.y), "resource": ""}
	if kind == "splitter":
		out["dst2"] = _endpoint_near(conveyor_outputs(pos, yaw, kind)[1], false, skip_conveyor, pos.y)      # the second exit
	return out

func compute_links() -> void:
	links.clear()
	for i in range(conveyors.size()):
		links.append(link_for(v3(conveyors[i]["position"]), float(conveyors[i]["yaw"]), i, str(conveyors[i].get("kind", "straight"))))
	for i in range(conveyors.size()):
		links[i]["resource"] = _chain_resource(i)
	crusher_outputs.clear()
	for i in range(state.crushers.size()):
		var best := -1
		for j in range(outputs.size()):
			if _flat(crusher_output_port(i), v3(outputs[j]["position"])) < 2.4:
				best = j
				break
		crusher_outputs.append(best)

## What a conveyor chain starting at a non-conveyor source should pull.
func _chain_resource(i: int) -> String:
	var src: Dictionary = links[i]["src"]
	var cursor := i
	var seen := {}
	var terminal := {}
	while not seen.has(cursor):
		seen[cursor] = true
		var dst: Dictionary = links[cursor]["dst"]
		if dst.is_empty() and links[cursor].has("dst2"):
			dst = links[cursor]["dst2"]                         # a splitter: either exit leads to the same kind of terminal
		if dst.is_empty():
			return ""
		if str(dst["type"]) == "conveyor":
			cursor = int(dst["index"])
			continue
		terminal = dst
		break
	if terminal.is_empty() or src.is_empty() or str(src["type"]) == "conveyor":
		return ""
	return route_resource(src, terminal)

func describe_ep(ep: Dictionary) -> String:
	match str(ep.get("type", "")):
		"storage": return "Storage crate"
		"crusher": return "Crusher #%d" % (int(ep["index"]) + 1)
		"output": return "Output storage #%d" % (int(ep["index"]) + 1)
		"conveyor": return "Conveyor #%d" % (int(ep["index"]) + 1)
		"deposit": return "Loose " + str(ep["resource"]).replace("_", " ")
		"deposit_site": return "the deposit"
		"sell": return "the office"
		"rig": return "%s #%d" % [str(prog.machine(str(prog.rigs[int(ep["index"])]["type"]))["title"]), int(ep["index"]) + 1] if ep_valid(ep) else "a rig"
	return "nothing"

## Where belts merge the feeders take turns (deterministic round robin): a belt that fed the merger last waits while another belt feeding it has material
## ready at its end.
func _merge_turn_ok(dst: Dictionary, from_belt: int) -> bool:
	if str(dst.get("type", "")) != "conveyor":
		return true
	var m := int(dst["index"])
	if str(conveyors[m].get("kind", "straight")) != "merger" or int(conveyors[m].get("rr", -1)) != from_belt:
		return true
	for j in range(conveyors.size()):
		if j != from_belt and j < links.size() and links[j]["dst"] == dst and int(conveyors[j]["items"]) > 0 and float(conveyors[j]["progress"]) >= 1.0:
			return false
	return true

func tick_conveyors(seconds: float) -> void:
	if links.size() != conveyors.size():
		compute_links()
	var rate := float(cfg.get("conveyor_rate", 0.5))
	var capacity := int(cfg.get("conveyor_capacity", 3))
	for i in range(conveyors.size()):
		var c: Dictionary = conveyors[i]
		var link: Dictionary = links[i]
		if int(c["items"]) > 0:
			c["progress"] = minf(1.0, float(c["progress"]) + rate * seconds)
			var dst: Dictionary = link["dst"]
			var order := [dst]
			if link.has("dst2"):                                        # a splitter alternates between its two exits; a blocked exit is skipped
				order = [link["dst2"], dst] if int(c.get("sr", 0)) == 1 else [dst, link["dst2"]]
			if float(c["progress"]) >= 1.0:
				for target in order:
					if target.is_empty() or not _merge_turn_ok(target, i) or ep_put(target, str(c["resource"]), 1) != 1:
						continue
					if str(target["type"]) == "conveyor" and str(conveyors[int(target["index"])].get("kind", "straight")) == "merger":
						conveyors[int(target["index"])]["rr"] = i      # a merger remembers who fed it last, so the other feeder goes next
					if link.has("dst2"):
						c["sr"] = 1 if target == dst else 0             # the splitter's next piece goes out the other side
					c["items"] = int(c["items"]) - 1
					c["progress"] = 0.0
					if str(target["type"]) != "conveyor":
						_add_daily("conveyed", 1)
					if int(c["items"]) <= 0:
						c["resource"] = ""
					break
		var res := str(link["resource"])
		var src: Dictionary = link["src"]
		if res == "auto":
			res = _auto_resource(src, c)
		if res != "" and int(c["items"]) < capacity and (int(c["items"]) == 0 or str(c["resource"]) == res):
			c["pull"] = float(c["pull"]) + rate * seconds
			if float(c["pull"]) >= 1.0:
				c["pull"] = 0.0
				if ep_take(src, res, 1) == 1:
					if int(c["items"]) == 0:
						c["progress"] = 0.0
					c["items"] = int(c["items"]) + 1
					c["resource"] = res
		else:
			c["pull"] = 0.0

## A belt out of the storage crate toward a Cash Hopper: it keeps carrying the material already on it while the crate has more of it, then the dearest one.
func _auto_resource(src: Dictionary, c: Dictionary) -> String:
	var cur := str(c.get("resource", ""))
	if int(c["items"]) > 0 and cur != "":
		return cur if ep_available(src, cur) > 0 else ""
	for res in SELL_ORDER:
		if ep_available(src, res) > 0:
			return res
	return ""

## What a belt piece is doing, for its lamp and belt colour: "disconnected" (nothing feeds it or it leads nowhere),
## "blocked" (holds material that has reached the end but the next piece is full), "active" (carrying or loading)
## or "idle" (connected, empty). Reads state only; it never moves material.
func belt_status(i: int) -> String:
	if i < 0 or i >= conveyors.size() or links.size() != conveyors.size():
		return "disconnected"
	var link: Dictionary = links[i]
	var c: Dictionary = conveyors[i]
	if int(c["items"]) > 0:
		# material really slides along until it reaches the end; it is blocked there when nothing can take it (no next piece, or it is full)
		var space := ep_space(link["dst"], str(c["resource"])) if not link["dst"].is_empty() else 0
		if link.has("dst2") and not link["dst2"].is_empty():
			space += ep_space(link["dst2"], str(c["resource"]))
		if float(c["progress"]) >= 1.0 and space < 1:
			return "blocked"
		return "active"
	var no_exit: bool = link["dst"].is_empty() and (not link.has("dst2") or link["dst2"].is_empty())
	if link["src"].is_empty() or no_exit:
		return "disconnected"
	if float(c["pull"]) > 0.0:
		return "active"
	return "idle"

# ---------------------------------------------------------------- production overview

## What one machine is doing, for the Production Overview: {"state": "running" | "idle" | "blocked", "reason": String}. It reads state only.
func machine_status(kind: String, index: int) -> Dictionary:
	match kind:
		"crusher":
			if index < 0 or index >= state.crushers.size():
				return {"state": "idle", "reason": "Not placed"}
			var c: Dictionary = state.crushers[index]
			if bool(c["running"]):
				return {"state": "running", "reason": "Crushing, %.0f s left" % float(c["remaining"])}
			if crusher_output_full(index):
				return {"state": "blocked", "reason": "Output full: collect it or connect a belt to a bin"}
			var held := int(c.get("hopper", 0)) + int(c["input"])
			if held > 0:
				return {"state": "blocked", "reason": "Has limestone but no operator is running it"}
			if int(c["output"]) > 0 and (index >= crusher_outputs.size() or int(crusher_outputs[index]) < 0):
				var belted := false
				for l in links:
					if str(l["src"].get("type", "")) == "crusher" and int(l["src"].get("index", -1)) == index:
						belted = true
				if not belted:
					return {"state": "blocked", "reason": "Finished stone waiting: nothing takes it away"}
			return {"state": "idle", "reason": "No limestone to crush"}
		"conveyor":
			var s := belt_status(index)
			var kindname := "Merger" if str(conveyors[index].get("kind", "straight")) == "merger" else "Belt"
			match s:
				"active": return {"state": "running", "reason": "%s moving material" % kindname}
				"blocked":
					var dst: Dictionary = links[index]["dst"] if index < links.size() else {}
					return {"state": "blocked", "reason": "Blocked: %s is full" % describe_ep(dst) if not dst.is_empty() else "Blocked: nothing at its end"}
				"disconnected":
					var l: Dictionary = links[index] if index < links.size() else {"src": {}, "dst": {}}
					if l["dst"].is_empty() and l["src"].is_empty() and str(conveyors[index].get("kind", "straight")) != "merger":
						return {"state": "blocked", "reason": "Not connected at either end"}
					if l["dst"].is_empty():
						return {"state": "blocked", "reason": "Its output end is not connected"}
					if l["src"].is_empty() and str(conveyors[index].get("kind", "straight")) != "merger":
						return {"state": "idle", "reason": "Nothing feeds it yet"}
					return {"state": "idle", "reason": "Waiting for material"}
				_: return {"state": "idle", "reason": "Connected, waiting for material"}
		"output":
			if index < 0 or index >= outputs.size():
				return {"state": "idle", "reason": "Not placed"}
			var total := output_total(index)
			if is_cash_hopper(index):
				if total >= output_capacity_of(index):
					return {"state": "blocked", "reason": "Queue full (%d): the belts feeding it wait until it has sold some" % total}
				if total > 0:
					return {"state": "running", "reason": "Selling %s: %d waiting, %.0f units / s" % [cash_current(index).replace("_", " "), total, cash_rate(index)]}
				return {"state": "idle", "reason": "Waiting for material to sell"}
			if total >= output_capacity_of(index):
				return {"state": "blocked", "reason": "Full: sell or empty it, or the belts feeding it stop"}
			if total > 0:
				return {"state": "running", "reason": "Holding %d / %d" % [total, output_capacity_of(index)]}
			return {"state": "idle", "reason": "Empty"}
	return {"state": "idle", "reason": ""}

## Every placed machine with its status, for the Production Overview.
func production_overview() -> Array:
	var rows := []
	for i in range(state.crushers.size()):
		var s := machine_status("crusher", i)
		rows.append({"kind": "crusher", "index": i, "name": ("Advanced crusher #%d" if int(state.crushers[i].get("tier", 1)) >= 2 else "Crusher #%d") % (i + 1), "state": s["state"], "reason": s["reason"]})
	for i in range(conveyors.size()):
		var s := machine_status("conveyor", i)
		rows.append({"kind": "conveyor", "index": i, "name": ({"merger": "Merger #%d", "splitter": "Splitter #%d", "short": "Short conveyor #%d", "incline": "Incline conveyor #%d"}.get(str(conveyors[i].get("kind", "straight")), "Conveyor #%d")) % (i + 1), "state": s["state"], "reason": s["reason"]})
	for i in range(outputs.size()):
		var s := machine_status("output", i)
		rows.append({"kind": "output", "index": i, "name": "%s #%d" % [{"output": "Output storage", "hopper": "Small hopper", "sorter": "Sorting table", "cash_hopper": "Cash Hopper"}.get(variant_of(i), "Storage"), i + 1], "state": s["state"], "reason": s["reason"]})
	return rows

## Units currently on belts; used to prove conservation in tests.
func conveyor_total() -> int:
	var n := 0
	for c in conveyors:
		n += int(c["items"])
	return n

# ---------------------------------------------------------------- milestones

func has_profession(prof: String) -> bool:
	for e in employees:
		if str(e["profession"]) == prof:
			return true
	return false

func check_milestones() -> void:
	if not milestones["first_employee"] and employees.size() > 0:
		_reach("first_employee")
	if not milestones["mechanized"] and state.crushers.size() > 0 and has_profession("operator"):
		_reach("mechanized")
	if milestones["mechanized"] and not milestones["automated"]:
		for step in CHAIN_STEPS:
			if not chain[step]:
				return
		if auto_crushed_sold < sales_goal():
			return
		_reach("automated")

func _reach(id: String) -> void:
	milestones[id] = true
	if id == "automated":
		expansion_unlocked = true
	milestone_reached.emit(id)

## Phase 3 pacing: the chain must sell this much crushed stone, not just a single unit.
func sales_goal() -> int:
	return int(cfg.get("automated_sales_goal", 1))

func conveyors_unlocked() -> bool:
	return milestones["mechanized"]

# ---------------------------------------------------------------- save / load

func snapshot() -> Dictionary:
	return {
		"employees": employees.duplicate(true), "next_employee_id": next_employee_id,
		"outputs": outputs.duplicate(true), "conveyors": conveyors.duplicate(true),
		"authorized": authorized.duplicate(), "milestones": milestones.duplicate(), "chain": chain.duplicate(),
		"expansion_unlocked": expansion_unlocked, "outstanding_debt": outstanding_debt,
		"storage_pos": [storage_pos.x, storage_pos.y, storage_pos.z], "auto_crushed_sold": auto_crushed_sold,
		"payroll_minute": payroll_minute, "daily": daily.duplicate(true), "inventory": inventory.duplicate()
	}

## Restores Phase 2 data. An empty dictionary (Phase 1 save) yields a fresh business.
func restore(data: Dictionary) -> void:
	employees.clear()
	for raw in data.get("employees", []):
		if raw is Dictionary and str(raw.get("profession", "")) in PROFESSIONS:
			var e: Dictionary = raw.duplicate(true)
			e["id"] = int(e.get("id", 0))
			e["skill"] = clampi(int(e.get("skill", 1)), 1, 5)
			e["upgrade"] = clampi(int(e.get("upgrade", 0)), 0, 3)
			e["owed"] = maxf(0.0, float(e.get("owed", 0.0)))
			e["suspended"] = bool(e.get("suspended", false))
			e["shift_start"] = posmod(int(e.get("shift_start", 480)), 1440)
			e["shift_end"] = posmod(int(e.get("shift_end", 960)), 1440)
			e["base_wage"] = maxf(0.0, float(e.get("base_wage", 3.0)))
			var carry := {}
			for k in e.get("carry", {}):
				if int(e["carry"][k]) > 0 and state.inventory.has(k):
					carry[k] = int(e["carry"][k])
			e["carry"] = carry
			if not e.get("assignment") is Dictionary:
				e["assignment"] = default_assignment(str(e["profession"]))
			e["task"] = "Resuming"
			e["warning"] = ""
			var s: Dictionary = e.get("stats", {})
			for k in ["day", "units_today", "units_total", "minutes_today", "minutes_total", "paid_today", "paid_total"]:
				s[k] = int(s.get(k, 0))
			e["stats"] = s
			if not e.has("gender") and not (e.get("look") is Dictionary):
				var cand := candidate(str(e.get("candidate", "")))
				if not cand.is_empty():
					e["gender"] = str(cand.get("gender", "m"))
			ensure_identity(e)
			employees.append(e)
	next_employee_id = int(data.get("next_employee_id", 1))
	for e in employees:
		next_employee_id = maxi(next_employee_id, int(e["id"]) + 1)
	outputs = []
	for o in data.get("outputs", []):
		var items := {}
		for k in QuarryState.RESOURCE_NAMES:
			items[k] = maxi(0, int(o.get("items", {}).get(k, 0)))
		var var_name := str(o.get("variant", "output"))
		if not var_name in ["output", "hopper", "sorter", "cash_hopper"]:
			var_name = "output"
		var sorted := {}
		for k in SORTABLE:
			var sn := mini(maxi(0, int(o.get("sorted", {}).get(k, 0))), int(items[k])) if var_name == "sorter" else 0
			if sn > 0:
				sorted[k] = sn
		var job := {}
		for k in o.get("sort_job", {}):
			if str(k) in SORTABLE and var_name == "sorter":
				job[str(k)] = mini(maxi(0, int(o["sort_job"][k])), int(items[str(k)]))
		var orec := {"position": o["position"].duplicate(), "yaw": float(o.get("yaw", 0.0)), "items": items, "variant": var_name, "sorted": sorted,
			"sort_left": maxf(0.0, float(o.get("sort_left", 0.0))) if not job.is_empty() else 0.0, "sort_job": job}
		if var_name == "cash_hopper":
			orec["tier"] = clampi(int(o.get("tier", 0)), 0, cash_tiers().size() - 1)
			orec["progress"] = clampf(float(o.get("progress", 0.0)), 0.0, 1.0e6)
			orec["current"] = str(o.get("current", "")) if int(items.get(str(o.get("current", "")), 0)) > 0 else ""
			orec["today_day"] = int(o.get("today_day", -1))
			orec["today_money"] = maxi(0, int(o.get("today_money", 0)))
			orec["today_units"] = maxi(0, int(o.get("today_units", 0)))
			orec["total_money"] = maxi(0, int(o.get("total_money", 0)))
			orec["total_units"] = maxi(0, int(o.get("total_units", 0)))
		outputs.append(orec)
	inventory = {}
	var inv = data.get("inventory", {})
	if inv is Dictionary:
		for k in inv:
			inventory[str(k)] = maxi(0, int(inv[k]))
	conveyors = []
	for c in data.get("conveyors", []):
		var rec := {"position": c["position"].duplicate(), "yaw": float(c.get("yaw", 0.0)), "resource": str(c.get("resource", "")), "items": maxi(0, int(c.get("items", 0))), "progress": float(c.get("progress", 0.0)), "pull": float(c.get("pull", 0.0)), "kind": str(c.get("kind", "straight"))}
		if c.has("rr"):
			rec["rr"] = int(c["rr"])                        # a merger's turn marker
		if c.has("sr"):
			rec["sr"] = int(c["sr"])                        # a splitter's next exit
		conveyors.append(rec)
	for k in authorized:
		authorized[k] = bool(data.get("authorized", {}).get(k, false))
	for k in milestones:
		milestones[k] = bool(data.get("milestones", {}).get(k, false))
	for k in chain:
		chain[k] = bool(data.get("chain", {}).get(k, false))
	expansion_unlocked = bool(data.get("expansion_unlocked", milestones["automated"]))
	var sp = data.get("storage_pos", [])
	storage_pos = v3(sp) if sp is Array and sp.size() == 3 else STORAGE_POS
	auto_crushed_sold = maxi(0, int(data.get("auto_crushed_sold", 0)))
	outstanding_debt = maxf(0.0, float(data.get("outstanding_debt", 0.0)))
	payroll_minute = int(data.get("payroll_minute", int(floor(state.clock_minutes))))
	daily = data.get("daily", {}).duplicate(true)
	compute_links()

# ---------------------------------------------------------------- Phase 3: construction management

func structure_price(kind: String) -> int:
	match kind:
		"crusher": return int(state.config["crusher_price"])
		"output": return int(cfg["output_storage_price"])
		"conveyor": return int(cfg["conveyor_price"])
	return 0

func refund_value(kind: String, index := -1) -> int:
	var price := structure_price(kind)
	if kind == "output" and index >= 0 and index < outputs.size() and variant_of(index) != "output":
		price = int(cfg.get(variant_of(index) + "_price", price))
	if kind == "crusher" and index >= 0 and index < state.crushers.size() and int(state.crushers[index].get("tier", 1)) >= 2 and prog:
		price = int(prog.machine("advanced_crusher").get("price", price))
	return int(floor(price * 0.5))

func structure_count(kind: String) -> int:
	match kind:
		"crusher": return state.crushers.size()
		"output": return outputs.size()
		"conveyor": return conveyors.size()
		"storage": return 1
	return 0

func structure_record(kind: String, index: int) -> Dictionary:
	match kind:
		"crusher": return state.crushers[index] if index >= 0 and index < state.crushers.size() else {}
		"output": return outputs[index] if index >= 0 and index < outputs.size() else {}
		"conveyor": return conveyors[index] if index >= 0 and index < conveyors.size() else {}
	return {}

## Materials held by a structure, by resource (crusher hopper and loaded input are limestone).
func structure_contents(kind: String, index: int) -> Dictionary:
	var r := structure_record(kind, index)
	var out := {}
	match kind:
		"crusher":
			if not r.is_empty():
				out["limestone"] = int(r.get("hopper", 0)) + int(r["input"])
				out["crushed_stone"] = int(r["output"])
		"output":
			if not r.is_empty():
				out = r["items"].duplicate()
		"conveyor":
			if not r.is_empty() and int(r["items"]) > 0:
				out[str(r["resource"])] = int(r["items"])
	for k in out.keys():
		if int(out[k]) <= 0:
			out.erase(k)
	return out

func contents_total(c: Dictionary) -> int:
	var n := 0
	for k in c:
		n += int(c[k])
	return n

## Where a removed structure's contents can go: storage crate, other output storages
## (crushed stone), then the player's backpack. Returns the plan or {} if it cannot fit.
func _return_plan(kind: String, index: int) -> Array:
	var contents := structure_contents(kind, index)
	var crate_space := maxi(0, state.storage_capacity() - state.total(state.storage))
	var bag_space := maxi(0, state.capacity() - state.total(state.inventory))
	var plan := []
	for res in contents:
		var left := int(contents[res])
		var n := mini(left, crate_space)
		if n > 0:
			plan.append(["storage", -1, res, n])
			crate_space -= n
			left -= n
		if res == "crushed_stone":
			for j in range(outputs.size()):
				if left <= 0:
					break
				if kind == "output" and j == index:
					continue
				if not variant_accepts(j, res):
					continue
				var room := maxi(0, output_capacity_of(j) - output_total(j))
				for p in plan:
					if p[0] == "output" and p[1] == j:
						room -= int(p[3])
				n = mini(left, room)
				if n > 0:
					plan.append(["output", j, res, n])
					left -= n
		n = mini(left, bag_space)
		if n > 0:
			plan.append(["bag", -1, res, n])
			bag_space -= n
			left -= n
		if left > 0:
			return [false, plan]
	return [true, plan]

func sell_block_reason(kind: String, index: int) -> String:
	if kind == "storage":
		return "The main storage crate can be moved but not sold"
	if kind == "output" and is_cash_hopper(index):
		return "Grandpa's hopper is bolted to the ground"
	if structure_record(kind, index).is_empty():
		return "Nothing to sell"
	if not bool(_return_plan(kind, index)[0]):
		return "No room for its %d stored items - empty some storage first" % contents_total(structure_contents(kind, index))
	return ""

## Sells a structure for 50% of its price. Contents are moved (never created or lost),
## references in worker assignments are repaired, indices above it shift down.
func sell_structure(kind: String, index: int) -> int:
	if sell_block_reason(kind, index) != "":
		return -1
	var refund := refund_value(kind, index)
	_detach_structure(kind, index)
	state.money += refund
	return refund

## Takes a machine out of the yard: its contents go to the storage crate, other output storages or the bag (never lost), the record is removed, worker
## references are repaired and the links rebuilt.
func _detach_structure(kind: String, index: int) -> void:
	for step in _return_plan(kind, index)[1]:
		match str(step[0]):
			"storage": state.storage[step[2]] = int(state.storage[step[2]]) + int(step[3])
			"output": outputs[int(step[1])]["items"][step[2]] = int(outputs[int(step[1])]["items"][step[2]]) + int(step[3])
			"bag": state.inventory[step[2]] = int(state.inventory[step[2]]) + int(step[3])
	match kind:
		"crusher": state.crushers.remove_at(index)
		"output": outputs.remove_at(index)
		"conveyor": conveyors.remove_at(index)
	_fix_references(kind, index)
	compute_links()

## The Build Inventory key of a placed machine (what it becomes when it is stored).
func inventory_key_of(kind: String, index: int) -> String:
	match kind:
		"crusher":
			return "advanced_crusher" if int(state.crushers[index].get("tier", 1)) >= 2 else "crusher"
		"output":
			return variant_of(index)
		"conveyor":
			var bk := str(conveyors[index].get("kind", "straight"))
			return "conveyor" if bk == "straight" else "conveyor_" + bk
	return ""

## Why a machine cannot be returned to the Build Inventory ("" when it can).
func store_block_reason(kind: String, index: int) -> String:
	if kind == "storage":
		return "The main storage crate can be moved but not stored"
	if kind == "output" and is_cash_hopper(index):
		return "Grandpa's hopper is bolted to the ground"
	if structure_record(kind, index).is_empty():
		return "Nothing to store"
	if not bool(_return_plan(kind, index)[0]):
		return "No room for its %d stored items - empty some storage first" % contents_total(structure_contents(kind, index))
	return ""

## Picks a machine up into the Build Inventory: no money changes hands, its contents are returned to storage, and it can be placed again later.
## Returns the inventory key, or "" when it was refused.
func store_structure(kind: String, index: int) -> String:
	if store_block_reason(kind, index) != "":
		return ""
	var key := inventory_key_of(kind, index)
	if key == "":
		return ""
	_detach_structure(kind, index)
	inventory[key] = int(inventory.get(key, 0)) + 1
	return key

func _fix_ep(ep: Dictionary, kind: String, removed: int) -> Dictionary:
	if str(ep.get("type", "")) != kind:
		return ep
	var i := int(ep.get("index", -1))
	var out := ep.duplicate()
	if i == removed:
		out["index"] = -1 # dangling: worker stops with a warning until reassigned
	elif i > removed:
		out["index"] = i - 1
	return out

func _fix_references(kind: String, removed: int) -> void:
	for e in employees:
		var a: Dictionary = e["assignment"]
		if kind == "crusher" and a.has("crusher"):
			var c := int(a["crusher"])
			a["crusher"] = -1 if c == removed else (c - 1 if c > removed else c)
		if a.has("src"):
			a["src"] = _fix_ep(a["src"], kind, removed)
			a["dst"] = _fix_ep(a["dst"], kind, removed)

## Moves a structure's record; links are rebuilt so production reconnects at the new spot.
func move_structure(kind: String, index: int, pos: Vector3, yaw: float) -> bool:
	if kind == "storage":
		storage_pos = Vector3(pos.x, 0, pos.z)
	else:
		var r := structure_record(kind, index)
		if r.is_empty() or (kind == "output" and is_cash_hopper(index)):
			return false
		r["position"] = [pos.x, 0.0, pos.z]
		r["yaw"] = yaw
	compute_links()
	return true
