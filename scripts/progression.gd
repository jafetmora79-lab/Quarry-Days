extends RefCounted
class_name QuarryProgression
## Phase 5 progression rules (pure logic, no nodes - testable headless):
##  * tool tiers and mining damage (data/progression.json "tools", "materials")
##  * the finite rock formations: per-column unit counts stored in state.deposits[id]["columns"]
##  * business stages that gate equipment, lifetime earnings, the deep-excavation permit
##  * stationary rigs (drilling rig / rock breaker) extracting from the same formation columns
##  * story flags and lifetime mining statistics
## Every unit taken from a formation leaves its column exactly once (extract()), so the player, staff and
## machines can never create or duplicate material.

signal stage_reached(index: int)
signal formation_cleared(id: String)
signal site_cleared
signal quarry_level_reached(level: int)

const MIN_PER_SECOND := 0.5 # in-game minutes per real second (48-minute day)

var state: QuarryState
var business # QuarryBusiness (untyped: avoids a cyclic class dependency in tests)
var cfg: Dictionary
var stage := 0
var level_unlocked := 1                ## legacy: the small lower pit behind the $5,000 permit (1 = closed, 2 = open)
var legacy_migrated := false           ## the last restore() converted an old six-stage save
var quarry_level := 1                  ## Phase 7.1: the deepest of the four quarry levels reached so far (1..4)
const SCHEMA := 3                      ## save schema of the progression block: 1 = before Phase 7.1 (no field), 2 = quarry levels, 3 = Phase 9 twelve-stage ladder
var rigs: Array = []
var next_rig_id := 1
var story := {"intro_seen": false, "found": {}, "read": {}, "visits": {}, "journal": [], "fossil": "", "companion": {"state": "none"}, "milestones": {}}
## Phase 6.2 tutorial: weeds and rubble heaps still on the site. "cleared": id -> true, "units": heap id -> units
## left (heaps keep their remaining stone when saved), "done": the whole site is clean (hillside unlocked).
var cleanup := {"cleared": {}, "units": {}, "done": false}
var stats := {"hand": 0, "crew": 0, "rigs": 0, "chunks": 0, "best_tool": 0}

func _init(s: QuarryState, biz, settings: Dictionary) -> void:
	state = s
	business = biz
	cfg = settings

# ------------------------------------------------------------------ names, materials, tools

func display(res: String) -> String:
	return str(cfg.get("display_names", {}).get(res, res.replace("_", " ").capitalize()))

func material(res: String) -> Dictionary:
	return cfg.get("materials", {}).get(res, {"hp": 10, "hardness": 1})

func tools() -> Array:
	return cfg.get("tools", [])

func tool(tier := -1) -> Dictionary:
	if tier < 0 and state.equipped != "" and state.equipped in state.gear:
		var g := gear_def(state.equipped)
		if not g.is_empty() and str(g.get("kind", "tool")) == "tool":
			return g
	var t := state.tool_tier if tier < 0 else tier
	return tools()[clampi(t, 0, tools().size() - 1)]

# ------------------------------------------------------------------ extra tools and hauling aids (Phase 9.2)

## An extra tool or hauling aid, shaped like a ladder tool (id, title, cost, power / dps, interval, max_hardness, sound ...).
func gear_def(id: String) -> Dictionary:
	var g: Dictionary = cfg.get("gear", {}).get(id, {})
	if g.is_empty():
		return {}
	var out := g.duplicate(true)
	out["id"] = id
	return out

func gear_ids() -> Array:
	return cfg.get("gear", {}).keys()

## Ids of the tools you can hold right now: the ladder tool of tool_tier ("" stands for it) and every extra tool you own.
func held_options() -> Array:
	var out := [""]
	for id in gear_ids():
		if id in state.gear and str(cfg["gear"][id].get("kind", "tool")) == "tool":
			out.append(id)
	return out

func cycle_tool() -> String:
	var opts := held_options()
	var i := opts.find(state.equipped)
	state.equipped = str(opts[(i + 1) % opts.size()])
	return state.equipped

## Which of the five existing 3D tool models is shown for the tool in hand (extra tools reuse one; see the gear "model").
func model_tier() -> int:
	var t := tool()
	if t.has("class") and GearModels.tier_of(str(t.get("id", ""))) >= 0:
		return GearModels.tier_of(str(t["id"]))
	return state.tool_tier

## Damage multiplier of the tool in hand against a mineral (chisels are soft-rock specialists; powered tools use the compressor).
func tool_modifier(res: String) -> float:
	var t := tool()
	var m := float(t.get("affinity", {}).get(res, 1.0))
	if bool(t.get("powered", false)) and "air_compressor" in state.gear:
		m *= float(cfg.get("gear", {}).get("air_compressor", {}).get("power_mult", 1.0))
	return m

## Extra blocks hit by one blow of the tool in hand: [count, fraction of the damage].
func tool_aoe() -> Vector2:
	var t := tool()
	return Vector2(float(t.get("aoe", 0)), float(t.get("aoe_frac", 0.0)))

func gear_block_reason(id: String) -> String:
	var g := gear_def(id)
	if g.is_empty():
		return "Unknown item"
	if owns(id):
		return "Already owned"
	if not unlocked(id):
		return unlock_missing_text(id)
	if state.money < int(g["cost"]):
		return "Need $%d" % int(g["cost"])
	return ""

## Buys an extra tool or hauling aid. New tools go straight into your hand.
func buy_gear(id: String) -> bool:
	if gear_block_reason(id) != "":
		return false
	var g := gear_def(id)
	state.money -= int(g["cost"])
	if str(g.get("kind", "tool")) == "cart":
		state.carts.append(id)
	else:
		state.gear.append(id)
		if str(g.get("kind", "tool")) == "tool":
			state.equipped = id
	check_stages()
	return true

func next_tool() -> Dictionary:
	return tools()[state.tool_tier + 1] if state.tool_tier + 1 < tools().size() else {}

func speed_mult() -> float:
	return 1.25 if state.upgrades.get("faster_mining", false) else 1.0

func is_continuous(tier := -1) -> bool:
	return bool(tool(tier).get("continuous", false))

## Damage per swing (swing tools) - power tools use tool_dps().
func tool_power(tier := -1) -> float:
	var t := tool(tier)
	return float(t.get("power", float(t.get("dps", 10.0)) * 0.25))

func tool_interval(tier := -1) -> float:
	return float(tool(tier).get("interval", 0.25)) / speed_mult()

func tool_dps(tier := -1) -> float:
	var t := tool(tier)
	if t.has("dps"):
		return float(t["dps"]) * speed_mult()
	return tool_power(tier) / tool_interval(tier)

func can_mine(res: String, tier := -1) -> bool:
	return int(material(res).get("hardness", 1)) <= int(tool(tier).get("max_hardness", 1))

## Lowest tool that can work a material (for "too hard" hints).
func tool_for(res: String) -> Dictionary:
	for t in tools():
		if int(material(res).get("hardness", 1)) <= int(t.get("max_hardness", 1)):
			return t
	return tools().back()

func buy_next_tool() -> bool:
	var t := next_tool()
	if t.is_empty() or state.money < int(t["cost"]) or not unlocked(str(t["id"])):
		return false
	state.money -= int(t["cost"])
	state.tool_tier += 1
	state.equipped = ""
	stats["best_tool"] = maxi(int(stats["best_tool"]), state.tool_tier)
	check_stages()
	return true

## How much faster the next tool mines than the current one ("MINING POWER +40%").
func tool_gain_percent(from_tier: int, to_tier: int) -> int:
	return int(round((tool_dps(to_tier) / maxf(0.01, tool_dps(from_tier)) - 1.0) * 100.0))

## Staff miners carry company tools: they can work whatever the best owned tool can.
func crew_damage(hits_stat: float, yield_stat: float) -> float:
	var w: Dictionary = cfg.get("worker_tool", {})
	var base := float(w.get("damage", 9.0)) * (1.0 + float(w.get("power_per_tier", 0.35)) * maxf(0.0, float(state.tool_tier) - 1.0))
	return base * (4.0 / maxf(1.0, hits_stat)) * (1.0 + 0.25 * yield_stat)

# ------------------------------------------------------------------ formations

func fdef(id: String) -> Dictionary:
	return cfg.get("formations", {}).get(id, {})

func formation_ids() -> Array:
	return cfg.get("formations", {}).keys()

func is_formation(id: String) -> bool:
	return cfg.get("formations", {}).has(id)

func formation_active(id: String) -> bool:
	return is_formation(id) and int(fdef(id).get("level", 1)) <= level_unlocked

func dims(id: String) -> Vector2i:
	var tiers: Array = fdef(id)["tiers"]
	return Vector2i(tiers[0].size(), tiers.size()) # x = columns, y = rows

func column_count(id: String) -> int:
	var d := dims(id)
	return d.x * d.y

func column_tiers(id: String, i: int) -> int:
	var d := dims(id)
	return int(fdef(id)["tiers"][i / d.x][i % d.x])

func column_max(id: String, i: int) -> int:
	return column_tiers(id, i) * int(fdef(id)["chunk_units"])

func max_units(id: String) -> int:
	var n := 0
	for i in range(column_count(id)):
		n += column_max(id, i)
	return n

const PitZoneScript = preload("res://scripts/pit_zone.gd")

## Phase 6.3b: a formation lives in a frame ("world" by default, or "pit": the pit zone's gate-local frame) and is laid
## out either as a straight "grid" (sector x = world x, row y = world z) or as an "arc": columns are `sectors`
## angular slices (x index) of `rows` concentric rings (y index; row 0 is the inner ring) around `center`.
func formation_frame(id: String) -> Transform3D:
	if str(fdef(id).get("frame", "")) == "pit":
		return PitZoneScript.gate_transform(cfg.get("pit_zone", {}))
	return Transform3D.IDENTITY

func is_arc(id: String) -> bool:
	return str(fdef(id).get("layout", "grid")) == "arc"

## Angle (in the formation's own frame) of sector x's centre, arc layout only.
func arc_angle(id: String, x: float) -> float:
	var a: Array = fdef(id)["arc_deg"]
	var a0 := deg_to_rad(float(a[0]))
	var da := (deg_to_rad(float(a[1])) - a0) / float(dims(id).x)
	return a0 + (x + 0.5) * da

func arc_step(id: String) -> float:
	var a: Array = fdef(id)["arc_deg"]
	return (deg_to_rad(float(a[1])) - deg_to_rad(float(a[0]))) / float(dims(id).x)

## Ground-level centre of cell (x, y), world space. Works for indices just outside the grid too (neighbours).
func cell_pos(id: String, x: int, y: int) -> Vector3:
	var f := fdef(id)
	var d := dims(id)
	var c: Array = f["center"]
	var cell := float(f["cell"])
	var l: Vector3
	if is_arc(id):
		var ang := arc_angle(id, float(x))
		var r := float(f["r_inner"]) + (float(y) + 0.5) * cell
		l = Vector3(float(c[0]) + r * cos(ang), float(c[1]), float(c[2]) + r * sin(ang))
	else:
		l = Vector3(float(c[0]) + (float(x) - (d.x - 1) * 0.5) * cell, float(c[1]), float(c[2]) + (float(y) - (d.y - 1) * 0.5) * cell)
	return formation_frame(id) * l

## Column centre at ground level (world space).
func column_pos(id: String, i: int) -> Vector3:
	var d := dims(id)
	return cell_pos(id, i % d.x, i / d.x)

## Rotation about Y (world) of a column's box: its local x runs along the radius (arc) or world x (grid).
func column_yaw(id: String, i: int) -> float:
	var fy := formation_frame(id).basis.get_euler().y
	if is_arc(id):
		return fy - arc_angle(id, float(i % dims(id).x))
	return fy

## Box footprint (local x, local z) of a column: (cell, cell) for grids; (radial, tangential) for arcs.
func column_size(id: String, i: int) -> Vector2:
	var cell := float(fdef(id)["cell"])
	if is_arc(id):
		var r := float(fdef(id)["r_inner"]) + (float(i / dims(id).x) + 0.5) * cell
		return Vector2(cell, r * arc_step(id))
	return Vector2(cell, cell)

## Where the formation's centre is in the world (labels, discoveries, default positions).
func formation_origin_world(id: String) -> Vector3:
	var c: Array = fdef(id)["center"]
	return formation_frame(id) * Vector3(float(c[0]), float(c[1]), float(c[2]))

## Creates or migrates a formation record. Saves that already hold its columns keep them exactly.
func init_formation(id: String) -> Dictionary:
	var d: Dictionary = state.deposits.get(id, {})
	var n := column_count(id)
	var cols: Array = d.get("columns", [])
	if cols.size() != n:
		cols = []
		for i in range(n):
			cols.append(column_max(id, i))
	for i in range(n):
		cols[i] = clampi(int(cols[i]), 0, column_max(id, i))
	d["columns"] = cols
	d["formation"] = true
	d["resource"] = str(fdef(id)["resource"])
	d["infinite"] = false
	d["hits"] = int(d.get("hits", 0))
	d["generation"] = int(d.get("generation", 0))
	d["progress"] = maxf(0.0, float(d.get("progress", 0.0)))
	d["regrow_at"] = -1.0
	_sync_stock(d)
	d["cleared"] = bool(d.get("cleared", false)) or int(d["stock"]) <= 0
	state.deposits[id] = d
	return d

func _sync_stock(d: Dictionary) -> void:
	var s := 0
	for v in d["columns"]:
		s += int(v)
	d["stock"] = s
	d["broken"] = s <= 0

func units_left(id: String) -> int:
	return int(state.deposits.get(id, {}).get("stock", 0))

func column_units(id: String, i: int) -> int:
	return int(state.deposits[id]["columns"][i])

func chunks_left(id: String, i: int) -> int:
	return int(ceil(float(column_units(id, i)) / float(fdef(id)["chunk_units"])))

## True when the neighbour cell (nx, ny) lets a person reach the column: it is emptied, or it lies off the grid on a
## side that is open floor. Sides listed in the formation's "closed" data (W, E = -x / +x, N, S = -z / +z) are solid
## hillside beyond the grid, so they never count as open (Phase 6.1: only the cut face is exposed).
func _open_neighbour(id: String, d: Vector2i, nx: int, ny: int) -> bool:
	if nx < 0 or ny < 0 or nx >= d.x or ny >= d.y:
		var closed: Array = fdef(id).get("closed", [])
		var side := "W" if nx < 0 else ("E" if nx >= d.x else ("N" if ny < 0 else "S"))
		return not closed.has(side)
	return column_units(id, ny * d.x + nx) <= 0

## Exposed = on the formation's open edge or next to an emptied column (reachable from the floor).
func column_exposed(id: String, i: int) -> bool:
	if column_covered(id, i):
		return false
	var d := dims(id)
	var x := i % d.x
	var y := i / d.x
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _open_neighbour(id, d, x + o.x, y + o.y):
			return true
	return false

## True when an in-grid neighbour has been cut away: the column shows freshly exposed stone (not the original surface).
func column_cut_exposed(id: String, i: int) -> bool:
	var d := dims(id)
	var x := i % d.x
	var y := i / d.x
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + o.x
		var ny: int = y + o.y
		if nx >= 0 and ny >= 0 and nx < d.x and ny < d.y and column_units(id, ny * d.x + nx) <= 0:
			return true
	return false

## Index of the grid column of formation `id` that contains world position `p` (-1 outside the grid).
func cell_index_at(id: String, p: Vector3) -> int:
	if is_arc(id) or not is_formation(id):
		return -1
	var f := fdef(id)
	var d := dims(id)
	var c: Array = f["center"]
	var cell := float(f["cell"])
	var l := formation_frame(id).affine_inverse() * p
	var fx := (l.x - float(c[0])) / cell + (d.x - 1) * 0.5
	var fy := (l.z - float(c[2])) / cell + (d.y - 1) * 0.5
	var ix := int(round(fx))
	var iy := int(round(fy))
	if absf(fx - float(ix)) > 0.5001 or absf(fy - float(iy)) > 0.5001 or ix < 0 or iy < 0 or ix >= d.x or iy >= d.y:
		return -1
	return iy * d.x + ix

## Stacked levels: a column lies under the columns of the formations in its "cover" list (the rock of the level above,
## same place in plan). It cannot be reached, or mined, until every one of them has been cut away.
func column_covered(id: String, i: int) -> bool:
	var cover: Array = fdef(id).get("cover", [])
	if cover.is_empty():
		return false
	var p := column_pos(id, i)
	for cid in cover:
		if not state.deposits.has(str(cid)):
			init_formation(str(cid))
		var j := cell_index_at(str(cid), p)
		if j >= 0 and column_units(str(cid), j) > 0:
			return true
	return false

## Formations flagged "strict" (the hillside) only let a column be mined while it is exposed: nothing can be
## taken through the solid rock in front of it. Free-standing piles keep their old behaviour.
func column_minable(id: String, i: int) -> bool:
	return column_units(id, i) > 0 and not column_covered(id, i) and (not bool(fdef(id).get("strict", false)) or column_exposed(id, i))

## Outward direction from column i toward open floor (for worker standing spots).
func column_open_dir(id: String, i: int, from: Vector3) -> Vector3:
	var d := dims(id)
	var x := i % d.x
	var y := i / d.x
	var here := cell_pos(id, x, y)
	var best := Vector3.ZERO
	var best_d := INF
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + o.x
		var ny: int = y + o.y
		if _open_neighbour(id, d, nx, ny):
			var dir := (cell_pos(id, nx, ny) - here)
			dir.y = 0.0
			dir = dir.normalized()
			var dist := (here + dir * 2.0).distance_squared_to(from)
			if dist < best_d:
				best_d = dist
				best = dir
	return best if best != Vector3.ZERO else Vector3.BACK

func nearest_column(id: String, from: Vector3, exposed_only := true, max_dist := INF) -> int:
	if not state.deposits.has(id):
		return -1
	var best := -1
	var best_d := INF
	for i in range(column_count(id)):
		if column_units(id, i) <= 0 or column_covered(id, i) or (exposed_only and not column_exposed(id, i)):
			continue
		var p := column_pos(id, i)
		var dd := Vector2(p.x, p.z).distance_to(Vector2(from.x, from.z))
		if dd < best_d and dd <= max_dist:
			best_d = dd
			best = i
	return best

func cleared_fraction(ids: Array = []) -> float:
	if ids.is_empty():
		ids = cfg.get("starting_formations", [])
	var total := 0
	var left := 0
	for id in ids:
		if not state.deposits.has(id):
			init_formation(id)
		total += max_units(id)
		left += units_left(id)
	return 1.0 - float(left) / float(maxi(1, total))

## Applies mining damage to one column. At most `limit` units leave the column (the caller has room for
## them); damage beyond that is not banked. Returns {"units", "chunks", "column_emptied"}.
## Set by the game: (formation id, column) -> true while a person stands on the column. Nothing (tool, crew, rig,
## companion) may take rock out from under somebody's feet.
var protect := Callable()

func extract(id: String, col: int, damage: float, limit := 1 << 30, source := "hand") -> Dictionary:
	var out := {"units": 0, "chunks": 0, "column_emptied": false}
	if protect.is_valid() and col >= 0 and protect.call(id, col):
		return out
	if not state.deposits.has(id) or col < 0 or col >= column_count(id) or column_units(id, col) <= 0 or damage <= 0.0:
		return out
	var d: Dictionary = state.deposits[id]
	var hp := float(material(str(d["resource"])).get("hp", 10))
	d["progress"] = float(d["progress"]) + damage
	var avail := mini(limit, column_units(id, col))
	var n := mini(int(floor(float(d["progress"]) / hp)), maxi(0, avail))
	d["progress"] = float(d["progress"]) - float(n) * hp
	if n >= avail:
		d["progress"] = minf(float(d["progress"]), hp * 0.999) # no room / column empty: damage is not banked
	if n <= 0:
		return out
	var before := chunks_left(id, col)
	d["columns"][col] = column_units(id, col) - n
	d["mined"] = int(d.get("mined", 0)) + n
	_sync_stock(d)
	out["units"] = n
	out["chunks"] = before - chunks_left(id, col)
	out["column_emptied"] = column_units(id, col) <= 0
	stats["chunks"] = int(stats["chunks"]) + int(out["chunks"])
	stats[source] = int(stats.get(source, 0)) + n
	if int(d["stock"]) <= 0 and not bool(d.get("cleared", false)):
		d["cleared"] = true
		formation_cleared.emit(id)
	return out

## Fraction (0..1) of the top chunk of a column already removed: drives crack decals.
func top_chunk_damage(id: String, col: int) -> float:
	var cu := int(fdef(id)["chunk_units"])
	var u := column_units(id, col)
	if u <= 0:
		return 0.0
	var rem := u % cu
	var hp := float(material(str(state.deposits[id]["resource"])).get("hp", 10))
	var dmg := float(cu - rem) if rem > 0 else 0.0
	return clampf((dmg + float(state.deposits[id].get("progress", 0.0)) / hp) / float(cu), 0.0, 1.0)

# ------------------------------------------------------------------ stages

func stages() -> Array:
	return cfg.get("stages", [])

func stage_info(i := -1) -> Dictionary:
	return stages()[clampi(stage if i < 0 else i, 0, stages().size() - 1)]

## [label, current, target] for each requirement of stage i.
func requirement_progress(i: int) -> Array:
	var out := []
	var req: Dictionary = stage_info(i).get("req", {})
	for k in req:
		var target = req[k]
		match k:
			"earned": out.append(["Earn $%d total" % int(target), float(state.earned), float(target)])
			"tool": out.append(["Own the %s" % str(tool(int(target))["title"]), float(state.tool_tier), float(target)])
			"employees": out.append(["Hire %d worker" % int(target), float(business.employees.size() if business else 0), float(target)])
			"crushers": out.append(["Own %d crusher" % int(target), float(state.crushers.size()), float(target)])
			"cleared": out.append(["Clear %d%% of the first deposits" % int(float(target) * 100.0), cleared_fraction(), float(target)])
			"quarry_level": out.append(["Open quarry level %d" % int(target), float(quarry_level), float(target)])
			"milestones":
				for m in target:
					out.append([milestone_title(str(m)), 1.0 if milestone_done(str(m)) else 0.0, 1.0])
			"owns":
				for o in target:
					out.append(["Own the %s" % item_title(str(o)), 1.0 if owns(str(o)) else 0.0, 1.0])
			"discover":
				for r in target:
					out.append(["Discover %s" % display(str(r)).to_lower(), 1.0 if discovered(str(r)) else 0.0, 1.0])
			"delivered":
				for r in target:
					out.append(["Sell %d %s" % [int(target[r]), display(str(r)).to_lower()], float(delivered(str(r))), float(target[r])])
			"excavated":
				var lv := int(target.get("level", 1))
				out.append(["Clear %d%% of quarry level %d" % [int(float(target.get("fraction", 0.5)) * 100.0), lv], level_cleared_fraction(lv), float(target.get("fraction", 0.5))])
	return out

func requirements_met(i: int) -> bool:
	for r in requirement_progress(i):
		if float(r[1]) < float(r[2]) - 0.00001:
			return false
	return true

func check_stages() -> void:
	while stage + 1 < stages().size() and requirements_met(stage + 1):
		stage += 1
		stage_reached.emit(stage)
	check_levels()
	apply_stage_effects()

## The stage sets what buyers pay (a small quarry sells small lots): data "price_mult" of the stage, 1.0 from Moving Mountains on.
func apply_stage_effects() -> void:
	state.price_mult = float(stage_info().get("price_mult", 1.0))

# ------------------------------------------------------------------ quarry levels (Phase 7.1)

func levels() -> Array:
	return cfg.get("quarry_levels", [])

## 1-based level definition ({} when it does not exist).
func level_def(n: int) -> Dictionary:
	return levels()[n - 1] if n >= 1 and n <= levels().size() else {}

func level_formations(n: int) -> Array:
	var out := []
	for id in level_def(n).get("formations", []):
		if is_formation(str(id)):
			out.append(str(id))
	return out

## A level exists in the game once it is marked built and its formations are defined.
func level_built(n: int) -> bool:
	var d := level_def(n)
	return not d.is_empty() and bool(d.get("built", false)) and not level_formations(n).is_empty()

## Share (0..1) of a level's rock that has been excavated; 0 for a level that has no formations yet.
func level_cleared_fraction(n: int) -> float:
	var ids := level_formations(n)
	if ids.is_empty():
		return 0.0
	return cleared_fraction(ids)

## Level n can be entered: it is built, every level above it is reached, and the previous level is cut far enough.
func level_unlock_met(n: int) -> bool:
	if n <= 1:
		return true
	return level_built(n) and level_cleared_fraction(n - 1) >= float(level_def(n).get("unlock", 0.6)) - 0.00001

## Opens the next quarry level when the level above it has been excavated enough (never closes one).
func check_levels() -> void:
	while quarry_level < levels().size() and level_unlock_met(quarry_level + 1):
		quarry_level += 1
		quarry_level_reached.emit(quarry_level)

## Brings a progression save block up to the current schema. Each step only adds what the older format lacked; nothing
## in the old data is changed or dropped, so mined rock, stages, machines and rigs carry over untouched.
static func migrate(data: Dictionary) -> Dictionary:
	var d := data.duplicate(true)
	var v := int(d.get("schema", 1))
	if v < 2:
		d["quarry_level"] = clampi(int(d.get("quarry_level", 1)), 1, 4)
		v = 2
	d["schema"] = maxi(v, 2)      # restore() converts the stage ladder (schema 3) because it needs the game data
	return d

## Lowest stage consistent with what an older save already owns (nothing is ever taken away).
func implied_stage(vehicle_types: Array = []) -> int:
	var s := 0
	if state.tool_tier >= 1:
		s = stage_index("tools")
	if business and (business.employees.size() > 0 or business.milestones.get("first_employee", false)):
		s = maxi(s, stage_index("crew"))
	if state.crushers.size() > 0 or (business and (business.outputs.size() > 0 or business.conveyors.size() > 0)) or vehicle_types.size() > 0:
		s = maxi(s, stage_index("industry"))
	if "truck" in vehicle_types or (business and business.milestones.get("automated", false)) or rigs.size() > 0:
		s = maxi(s, stage_index("large"))
	for vt in vehicle_types:                     # Phase 8.2: owning a machine implies the stage that unlocks it
		if cfg.get("vehicle_gates", {}).has(str(vt)):
			s = maxi(s, stage_index(str(cfg["vehicle_gates"][str(vt)])))
	if level_unlocked >= 2:
		s = maxi(s, stage_index("deep"))
	return s

func stage_id() -> String:
	return str(stage_info()["id"])

func stage_index(id: String) -> int:
	var real: String = str(cfg.get("legacy_stage_ids", {}).get(id, id))     # the six old stage ids still work
	for i in range(stages().size()):
		if str(stages()[i]["id"]) == real:
			return i
	return 0

## Stage a feature, vehicle or machine opens at ("" = not stage-gated).
func gate_stage(feature: String) -> String:
	if cfg.get("feature_gates", {}).has(feature):
		return str(cfg["feature_gates"][feature])
	if cfg.get("vehicle_gates", {}).has(feature):
		return str(cfg["vehicle_gates"][feature])
	var m: Dictionary = cfg.get("machines", {}).get(feature, {})
	if not m.is_empty():
		return str(m.get("stage_id", ""))
	var u: Dictionary = cfg.get("unlocks", {}).get(feature, {})
	return str(u.get("stage", ""))

## Equipment / feature gates: the stage, plus the discoveries, milestones and equipment of the item's "unlocks" entry.
func unlocked(feature: String) -> bool:
	var g := gate_stage(feature)
	if g != "" and stage < stage_index(g) and not owns(feature):
		return false
	return unlock_met(feature)

func feature_stage_title(feature: String) -> String:
	var g := gate_stage(feature)
	return str(stage_info(stage_index(g))["title"]) if g != "" else ""

# ------------------------------------------------------------------ hybrid unlocks (Phase 9.1)
## cfg["unlocks"][id] = {"stage", "owns": [ids], "discover": [minerals], "delivered": {mineral: n}, "milestones": [ids],
## "earned": n, "quarry_level": n, "story": [flags]}. Money is the item's own price. One evaluator serves every item.

## Is this equipment owned? Ladder tools by their id (everything up to tool_tier), extra tools, hauling aids, rig types, crushers.
func owns(id: String) -> bool:
	for i in range(tools().size()):
		if str(tools()[i]["id"]) == id:
			return i <= state.tool_tier
	if id in state.gear or id in state.carts:
		return true
	if id == "crusher":
		return state.crushers.size() > 0
	for r in rigs:
		if str(r.get("type", "")) == id:
			return true
	return false

func discovered(res: String) -> bool:
	if int(state.lifetime["mined"].get(res, 0)) > 0 or int(state.inventory.get(res, 0)) > 0 or int(state.storage.get(res, 0)) > 0:
		return true
	for k in state.deposits:                                   # old saves have no lifetime record: their dug-out rock is the evidence
		var d: Dictionary = state.deposits[k]
		if str(d.get("resource", "")) == res and (int(d.get("mined", 0)) > 0 or int(d.get("hits", 0)) > 0 or int(d.get("generation", 0)) > 0):
			return true
	return false

func delivered(res: String) -> int:
	return int(state.lifetime["sold"].get(res, 0))

func milestone_done(id: String) -> bool:
	match id:
		"cleanup_done": return bool(cleanup.get("done", false))
		"workshop_upgrade":
			for k in state.upgrades:
				if state.upgrades[k]:
					return true
			return state.gear.size() > 0 or state.tool_tier >= 3
		"crusher_built": return state.crushers.size() > 0
	if bool(story.get("milestones", {}).get(id, false)):
		return true
	return business != null and bool(business.milestones.get(id, false))

func milestone_title(id: String) -> String:
	return str(cfg.get("milestone_titles", {}).get(id, id.replace("_", " ")))

func item_title(id: String) -> String:
	for t in tools():
		if str(t["id"]) == id:
			return str(t["title"])
	var g: Dictionary = cfg.get("gear", {}).get(id, {})
	return str(g.get("title", id.replace("_", " ").capitalize()))

## [[label, met], ...] for every requirement of an item except its price.
func unlock_reqs(id: String) -> Array:
	var u: Dictionary = cfg.get("unlocks", {}).get(id, {})
	var out := []
	var g := gate_stage(id)
	if g != "":
		var si := stage_index(g)
		out.append(["Stage %d: %s" % [si + 1, str(stage_info(si)["title"])], stage >= si])
	if u.is_empty():
		return out
	for o in u.get("owns", []):
		out.append(["Own the %s" % item_title(str(o)), owns(str(o))])
	for r in u.get("discover", []):
		out.append(["Discover %s" % display(str(r)).to_lower(), discovered(str(r))])
	var dl: Dictionary = u.get("delivered", {})
	for r in dl:
		out.append(["Sell %d %s (%d so far)" % [int(dl[r]), display(str(r)).to_lower(), mini(delivered(str(r)), int(dl[r]))], delivered(str(r)) >= int(dl[r])])
	for m in u.get("milestones", []):
		out.append([milestone_title(str(m)), milestone_done(str(m))])
	if u.has("earned"):
		out.append(["Earn $%d in total" % int(u["earned"]), state.earned >= int(u["earned"])])
	if u.has("quarry_level"):
		out.append(["Open quarry level %d" % int(u["quarry_level"]), quarry_level >= int(u["quarry_level"])])
	for f in u.get("story", []):
		out.append(["Story: %s" % str(f).replace("_", " "), bool(story.get(str(f), false)) or bool(story.get("milestones", {}).get(str(f), false))])
	return out

## Everything except the price is satisfied. Owned equipment is never locked.
func unlock_met(id: String) -> bool:
	if owns(id):
		return true
	var u: Dictionary = cfg.get("unlocks", {}).get(id, {})
	if u.is_empty():
		return true
	for r in unlock_reqs(id):
		if not bool(r[1]):
			return false
	return true

## "Needs Stage 6: Power and Pressure; discover iron ore; ..." for the shop's lock line ("" when nothing is missing).
func unlock_missing_text(id: String) -> String:
	if owns(id):
		return ""
	var parts := []
	for r in unlock_reqs(id):
		if not bool(r[1]):
			parts.append(str(r[0]))
	return "" if parts.is_empty() else "Needs " + "; ".join(parts)

# ------------------------------------------------------------------ deep excavation

func permit_cost() -> int:
	return int(cfg.get("excavation", {}).get("permit_cost", 5000))

func permit_block_reason() -> String:
	if level_unlocked >= 2:
		return "The lower level is already open"
	if not unlocked("permit"):
		return "Reach the %s stage first" % feature_stage_title("permit")
	if state.money < permit_cost():
		return "Need $%d" % permit_cost()
	return ""

func buy_permit() -> bool:
	if permit_block_reason() != "":
		return false
	state.money -= permit_cost()
	level_unlocked = 2
	return true

# ------------------------------------------------------------------ rigs (stationary machines)

func machine(type: String) -> Dictionary:
	return cfg.get("machines", {}).get(type, {})

func pad(formation: String, p: int) -> Dictionary:
	var pads: Array = fdef(formation).get("pads", [])
	if p < 0 or p >= pads.size():
		return {}
	var a: Array = pads[p]
	# pads of formations in the pit frame are given in that frame: bring them into world space
	var fx := formation_frame(formation)
	return {"pos": fx * Vector3(float(a[0]), float(a[1]), float(a[2])), "yaw": float(a[3]) + fx.basis.get_euler().y}

func pad_taken(formation: String, p: int) -> bool:
	for r in rigs:
		if str(r["formation"]) == formation and int(r["pad"]) == p:
			return true
	return false

func free_pad(formation: String) -> int:
	for p in range(fdef(formation).get("pads", []).size()):
		if not pad_taken(formation, p):
			return p
	return -1

func rig_block_reason(type: String, formation: String) -> String:
	var m := machine(type)
	if m.is_empty() or type == "advanced_crusher":
		return "Unknown machine"
	if not unlocked(type):
		return "Unlocks at the %s stage" % feature_stage_title(type)
	if not formation_active(formation):
		return "That formation is not reachable yet"
	if formation_locked(formation) != "":
		return formation_locked(formation)
	if units_left(formation) <= 0:
		return "That formation is cleared"
	if int(material(str(fdef(formation)["resource"]))["hardness"]) > int(m["max_hardness"]):
		return "%s is too hard for the %s" % [display(str(fdef(formation)["resource"])), str(m["title"])]
	if free_pad(formation) < 0:
		return "Every drilling pad at the %s is taken" % str(fdef(formation)["title"])
	if state.money < int(m["price"]):
		return "Need $%d" % int(m["price"])
	return ""

func buy_rig(type: String, formation: String) -> Dictionary:
	if rig_block_reason(type, formation) != "":
		return {}
	state.money -= int(machine(type)["price"])
	var r := {"id": next_rig_id, "type": type, "formation": formation, "pad": free_pad(formation), "level": 0, "on": true,
		"bin": {}, "cost_acc": 0.0, "target": -1, "status": "Starting", "working": false}
	next_rig_id += 1
	rigs.append(r)
	check_stages()
	return r

func rig_index(id: int) -> int:
	for i in range(rigs.size()):
		if int(rigs[i]["id"]) == id:
			return i
	return -1

func rig_dps(r: Dictionary) -> float:
	var m := machine(str(r["type"]))
	var v := float(m.get("dps", 5.0))
	var ups: Array = m.get("upgrades", [])
	for k in range(mini(int(r["level"]), ups.size())):
		v *= float(ups[k].get("mult", 1.0))
	return v

## Units per in-game hour at the current target (for the "clear production rate" readout).
func rig_rate_per_hour(r: Dictionary) -> float:
	var res := str(fdef(str(r["formation"])).get("resource", "limestone"))
	return rig_dps(r) / float(material(res)["hp"]) * 60.0 / MIN_PER_SECOND

func rig_bin_total(r: Dictionary) -> int:
	var n := 0
	for v in r["bin"].values():
		n += int(v)
	return n

func rig_bin_cap(r: Dictionary) -> int:
	return int(machine(str(r["type"])).get("bin", 40))

func rig_upgrade_info(r: Dictionary) -> Dictionary:
	var ups: Array = machine(str(r["type"])).get("upgrades", [])
	return ups[int(r["level"])] if int(r["level"]) < ups.size() else {}

func upgrade_rig(r: Dictionary) -> bool:
	var u := rig_upgrade_info(r)
	if u.is_empty() or state.money < int(u["cost"]):
		return false
	state.money -= int(u["cost"])
	r["level"] = int(r["level"]) + 1
	return true

## Target column for a rig: the nearest column with rock within reach of its drill head.
func rig_target(r: Dictionary) -> int:
	var p := pad(str(r["formation"]), int(r["pad"]))
	if p.is_empty():
		return -1
	return nearest_column(str(r["formation"]), p["pos"], false, float(machine(str(r["type"])).get("reach", 4.5)))

## Runs every rig for `seconds` of real (unpaused) time. Returns extraction events for the visuals.
func tick_rigs(seconds: float) -> Array:
	var events := []
	for r in rigs:
		var m := machine(str(r["type"]))
		r["working"] = false
		if not bool(r["on"]):
			r["status"] = "Switched off"
			continue
		var id := str(r["formation"])
		var col := rig_target(r)
		r["target"] = col
		if col < 0:
			r["status"] = "No rock in reach - formation cleared here"
			continue
		var space := rig_bin_cap(r) - rig_bin_total(r)
		if space <= 0:
			r["status"] = "Output bin full - collect it"
			continue
		r["cost_acc"] = float(r["cost_acc"]) + float(m.get("cost_per_min", 1.0)) * seconds * MIN_PER_SECOND
		var due := int(floor(float(r["cost_acc"])))
		if due > 0:
			if state.money < due:
				r["cost_acc"] = minf(float(r["cost_acc"]), float(due))
				r["status"] = "No money for fuel and power"
				continue
			state.money -= due
			r["cost_acc"] = float(r["cost_acc"]) - due
			if business:
				business.record("rig_costs", due)
		r["working"] = true
		r["status"] = "Drilling"
		var ex := extract(id, col, rig_dps(r) * seconds, space, "rigs")
		if int(ex["units"]) > 0:
			var res := str(state.deposits[id]["resource"])
			r["bin"][res] = int(r["bin"].get(res, 0)) + int(ex["units"])
			events.append({"rig": r, "formation": id, "column": col, "units": int(ex["units"]), "chunks": int(ex["chunks"]), "emptied": bool(ex["column_emptied"])})
	return events

## World position of a rig's output bin (rigs creep forward from their pad as the face recedes).
func rig_bin_pos(r: Dictionary) -> Vector3:
	var p := pad(str(r["formation"]), int(r["pad"]))
	if p.is_empty():
		return Vector3.ZERO
	var yaw := float(p["yaw"])
	var fwd := QuarryBusiness.forward(yaw)
	var base: Vector3 = p["pos"] + fwd * float(r.get("advance", 0.0))
	return base + Basis(Vector3.UP, yaw) * Vector3(0.5, 0, 0.25)

func rig_take(r: Dictionary, res: String, n: int) -> int:
	var t := mini(n, int(r["bin"].get(res, 0)))
	if t <= 0:
		return 0
	r["bin"][res] = int(r["bin"][res]) - t
	if int(r["bin"][res]) <= 0:
		r["bin"].erase(res)
	return t

func rig_resource(r: Dictionary) -> String:
	return str(r["bin"].keys()[0]) if not r["bin"].is_empty() else str(fdef(str(r["formation"]))["resource"])

# ------------------------------------------------------------------ site cleanup (Phase 6.2)

func cleanup_cfg() -> Dictionary:
	return cfg.get("cleanup", {})

## Item ids: "w0".. for weed clumps, "h0".. for rubble heaps.
func cleanup_ids() -> Array:
	var out := []
	for i in range(cleanup_cfg().get("weeds", []).size()):
		out.append("w%d" % i)
	for i in range(cleanup_cfg().get("heaps", []).size()):
		out.append("h%d" % i)
	return out

func cleanup_pos(id: String) -> Vector2:
	var key := "weeds" if id.begins_with("w") else "heaps"
	var a: Array = cleanup_cfg().get(key, [])[int(id.substr(1))]
	return Vector2(float(a[0]), float(a[1]))

func cleanup_total() -> int:
	return cleanup_ids().size()

func cleanup_left() -> int:
	var n := 0
	for id in cleanup_ids():
		if not cleanup["cleared"].get(id, false):
			n += 1
	return n

func heap_units_left(id: String) -> int:
	return int(cleanup["units"].get(id, int(cleanup_cfg().get("heap_units", 5))))

func cleanup_active() -> bool:
	return not bool(cleanup["done"]) and cleanup_total() > 0

## Marks one item cleared. Returns true when this was the last one (the site is now clean).
func clear_cleanup_item(id: String) -> bool:
	cleanup["cleared"][id] = true
	if not bool(cleanup["done"]) and cleanup_left() == 0:
		cleanup["done"] = true
		site_cleared.emit()
		return true
	return false

## Empty string = open. Formations flagged "requires_cleanup" stay closed until the site is clean.
func formation_locked(id: String) -> String:
	if bool(fdef(id).get("requires_cleanup", false)) and cleanup_active():
		return "Clear the weeds and rubble first (%d left)" % cleanup_left()
	var ql := int(fdef(id).get("quarry_level", 1))
	if ql > quarry_level:
		return "Quarry level %d is not open yet: cut %d%% of level %d first" % [ql, int(float(level_def(ql).get("unlock", 0.6)) * 100.0), ql - 1]
	return ""

# ------------------------------------------------------------------ story

func discovery(id: String) -> Dictionary:
	return cfg.get("story", {}).get("discoveries", {}).get(id, {})

func mark_found(id: String) -> void:
	story["found"][id] = true

## Reading a discovery pays its reward exactly once (save/load safe).
func read_discovery(id: String) -> int:
	if not story["found"].get(id, false) or story["read"].get(id, false):
		return 0
	story["read"][id] = true
	var reward := int(discovery(id).get("reward", 0))
	state.add_income(reward, "discovery")
	return reward

# ------------------------------------------------------------------ the fossil (Phase 7.6)

func fossil_cfg() -> Dictionary:
	return cfg.get("fossil", {})

## "" (still buried), "found" (uncovered, undecided), "collector" or "scientist" (decided for good).
func fossil_state() -> String:
	return str(story.get("fossil", ""))

## True when the fossil's columns have really been mined out.
func fossil_exposed() -> bool:
	var f := fossil_cfg()
	var id := str(f.get("formation", ""))
	if f.is_empty() or not is_formation(id) or not state.deposits.has(id):
		return false
	for c in f.get("columns", []):
		if int(c) >= column_count(id) or column_units(id, int(c)) > 0:
			return false
	return true

## Marks the fossil found the first time its rock is gone. Returns true on that moment.
func check_fossil() -> bool:
	if fossil_state() != "" or not fossil_exposed():
		return false
	story["fossil"] = "found"
	journal_add("fossil_found")
	return true

func fossil_pos() -> Vector3:
	var f := fossil_cfg()
	var id := str(f.get("formation", ""))
	var cols: Array = f.get("columns", [0])
	var sum := Vector3.ZERO
	for c in cols:
		sum += column_pos(id, int(c))
	return sum / float(maxi(1, cols.size()))

## The final decision. Pays once; later calls do nothing. Returns the money paid (0 when refused).
func fossil_choose(who: String) -> int:
	if fossil_state() != "found":
		return 0
	var b: Dictionary = fossil_cfg().get("buyers", {}).get(who, {})
	if b.is_empty():
		return 0
	story["fossil"] = who
	var price := int(b.get("price", 0))
	state.add_income(price, "fossil")
	journal_add(str(b.get("journal", "")))
	if who == "scientist":
		story["fossil_egg"] = true       # Phase 7.7: Dr. Marsh's team brings the egg the next day
		story["companion"] = {"state": "pending", "ready_day": current_day + 1}
	return price

# ------------------------------------------------------------------ quarry milestones (Phase 8.2)

func milestone_defs() -> Array:
	return cfg.get("quarry_milestones", [])

func milestone_met(m: Dictionary) -> bool:
	var w: Dictionary = m.get("when", {})
	if w.has("quarry_level") and quarry_level < int(w["quarry_level"]):
		return false
	if w.has("cleared"):
		var c: Dictionary = w["cleared"]
		if level_cleared_fraction(int(c["level"])) < float(c["fraction"]):
			return false
	if w.has("mined"):
		var id := str(w["mined"]["formation"])
		if not state.deposits.has(id) or int(state.deposits[id].get("mined", 0)) <= 0:
			return false
	return true

## Pays each excavation milestone once (money only: it does not count as sales). Returns the newly reached ones.
func check_quarry_milestones() -> Array:
	var out := []
	for m in milestone_defs():
		var id := str(m["id"])
		if story["milestones"].get(id, false) or not milestone_met(m):
			continue
		story["milestones"][id] = true
		state.money += int(m.get("reward", 0))
		out.append(m)
	return out

## Progress of one milestone for the UI: a 0..1 fraction (1 when done).
func milestone_progress(m: Dictionary) -> float:
	if story["milestones"].get(str(m["id"]), false):
		return 1.0
	var w: Dictionary = m.get("when", {})
	if w.has("cleared"):
		return clampf(level_cleared_fraction(int(w["cleared"]["level"])) / float(w["cleared"]["fraction"]), 0.0, 1.0)
	if w.has("quarry_level"):
		return clampf(float(quarry_level - 1) / float(maxi(1, int(w["quarry_level"]) - 1)), 0.0, 1.0)
	return 0.0

# ------------------------------------------------------------------ the companion (Phase 7.7)

var current_day := 0          ## in-game day number, kept up to date by main

func companion_cfg() -> Dictionary:
	return cfg.get("companion", {})

func companion() -> Dictionary:
	return story["companion"]

## "" (none yet), "egg", "hatchling", "juvenile" or "adult" for the given in-game day.
func companion_stage(day: int) -> String:
	var c: Dictionary = story["companion"]
	var st := str(c.get("state", "none"))
	if st == "egg":
		var hatch := int(c.get("egg_day", 0)) + int(companion_cfg().get("egg_days", 2))
		return "egg" if day < hatch else "hatchling"
	if st == "alive":
		var born := int(c.get("born_day", 0))
		var cc := companion_cfg()
		var j := born + int(cc.get("hatchling_days", 3))
		var a := j + int(cc.get("juvenile_days", 4))
		return "hatchling" if day < j else ("juvenile" if day < a else "adult")
	return ""

## The egg is on the porch waiting to be picked up.
func companion_egg_waiting(day: int) -> bool:
	var c: Dictionary = story["companion"]
	return str(c.get("state", "")) == "pending" and day >= int(c.get("ready_day", 0)) and bool(c.get("marsh_done", false))

## Dr. Marsh has to come by in person before the egg is handed over.
func marsh_due() -> bool:
	var c: Dictionary = story["companion"]
	return str(c.get("state", "")) == "pending" and current_day >= int(c.get("ready_day", 0)) and not bool(c.get("marsh_done", false))

## Journal pages that appear as the quarry is cleared and dug (Part 12): level 1 records, level 2 notes, level 3 sketch.
func check_level_journal() -> Array:
	var out := []
	for key in walter_cfg().get("level_journal", {}):
		var met := (bool(cleanup.get("done", false)) if str(key) == "cleaned" else quarry_level >= int(key))
		if met and journal_add(str(walter_cfg()["level_journal"][key])):
			out.append(str(walter_cfg()["level_journal"][key]))
	return out

func companion_take_egg(day: int) -> bool:
	if not companion_egg_waiting(day):
		return false
	story["companion"] = {"state": "egg", "egg_day": day}
	journal_add("companion_egg")
	return true

## Called when the egg has hatched: the companion is alive from this day on.
func companion_hatch(day: int, name_text: String) -> void:
	var c: Dictionary = story["companion"]
	if str(c.get("state", "")) != "egg":
		return
	var names: Array = companion_cfg().get("default_names", ["Pebble"])
	story["companion"] = {"state": "alive", "born_day": int(c.get("egg_day", 0)) + int(companion_cfg().get("egg_days", 2)),
		"name": name_text.strip_edges() if name_text.strip_edges() != "" else str(names[0]), "stage_seen": "hatchling"}

func companion_rename(name_text: String) -> void:
	if str(story["companion"].get("state", "")) == "alive" and name_text.strip_edges() != "":
		story["companion"]["name"] = name_text.strip_edges().substr(0, 16)

func companion_stage_def(day: int) -> Dictionary:
	return companion_cfg().get("stages", {}).get(companion_stage(day), {})

## Can the companion break this resource with its tail? Same hardness rule as the player's tools.
func companion_can_break(res: String, day: int) -> bool:
	var sd := companion_stage_def(day)
	return bool(sd.get("smash", false)) and int(material(res).get("hardness", 1)) <= int(sd.get("max_hardness", 0))

# ------------------------------------------------------------------ Walter (Phase 7.5)

func walter_cfg() -> Dictionary:
	return cfg.get("walter", {})

func journal_entry(id: String) -> Dictionary:
	return walter_cfg().get("journal", {}).get(id, {})

## Adds a journal entry once. Returns true when it is new.
func journal_add(id: String) -> bool:
	if id in story["journal"] or journal_entry(id).is_empty():
		return false
	story["journal"].append(id)
	return true

func journal_entries() -> Array:
	var out := []
	for id in story["journal"]:
		var e := journal_entry(str(id))
		if not e.is_empty():
			out.append({"id": str(id), "title": str(e.get("title", "")), "text": str(e.get("text", ""))})
	return out

func visit_def(id: String) -> Dictionary:
	for v in walter_cfg().get("visits", []):
		if str(v["id"]) == id:
			return v
	return {}

func visit_condition_met(v: Dictionary) -> bool:
	var w: Dictionary = v.get("when", {})
	if w.has("stage") and stage < stage_index(str(w["stage"])):
		return false
	if w.has("quarry_level") and quarry_level < int(w["quarry_level"]):
		return false
	if bool(w.get("cleaned", false)) and not bool(cleanup.get("done", false)):
		return false
	if w.has("fossil") and str(story.get("fossil", "")) != str(w["fossil"]):
		return false
	if w.has("companion") and not (companion_stage(current_day) in w["companion"]):
		return false
	if bool(w.get("marsh", false)) and not marsh_due():
		return false
	return true

## The first visit whose condition is met and which Walter has not made yet ("" when none).
func due_visit() -> String:
	if not bool(story["intro_seen"]):
		return ""
	for v in walter_cfg().get("visits", []):
		if not story["visits"].get(str(v["id"]), false) and visit_condition_met(v):
			return str(v["id"])
	return ""

## Walter has said his piece: the visit never repeats and its journal entry is kept.
func complete_visit(id: String) -> void:
	if story["visits"].get(id, false):
		return
	story["visits"][id] = true
	journal_add(str(visit_def(id).get("journal", "")))
	if id == "marsh_egg" and str(story["companion"].get("state", "")) == "pending":
		story["companion"]["marsh_done"] = true

# ------------------------------------------------------------------ save / load

func snapshot() -> Dictionary:
	return {"schema": SCHEMA, "quarry_level": quarry_level, "stage": stage, "level_unlocked": level_unlocked, "rigs": rigs.duplicate(true), "next_rig_id": next_rig_id,
		"story": story.duplicate(true), "stats": stats.duplicate(true), "cleanup": cleanup.duplicate(true)}

## Empty dictionary = Phase 1-4 save: stage derived from what is owned, never lower than earned.
func restore(raw_data: Dictionary, vehicle_types: Array = []) -> void:
	var data := QuarryProgression.migrate(raw_data)
	quarry_level = clampi(int(data.get("quarry_level", 1)), 1, maxi(1, levels().size()))
	level_unlocked = clampi(int(data.get("level_unlocked", 1)), 1, 2)
	rigs = []
	for raw in data.get("rigs", []):
		if raw is Dictionary and not machine(str(raw.get("type", ""))).is_empty() and is_formation(str(raw.get("formation", ""))):
			var r: Dictionary = raw.duplicate(true)
			r["id"] = int(r.get("id", 0))
			r["pad"] = int(r.get("pad", 0))
			r["level"] = clampi(int(r.get("level", 0)), 0, machine(str(r["type"])).get("upgrades", []).size())
			r["on"] = bool(r.get("on", true))
			var bin := {}
			for k in r.get("bin", {}):
				if state.inventory.has(k) and int(r["bin"][k]) > 0:
					bin[k] = int(r["bin"][k])
			r["bin"] = bin
			while rig_bin_total(r) > rig_bin_cap(r):
				rig_take(r, rig_resource(r), rig_bin_total(r) - rig_bin_cap(r))
			r["cost_acc"] = clampf(float(r.get("cost_acc", 0.0)), 0.0, 1.0)
			r["target"] = -1
			r["status"] = "Resuming"
			r["working"] = false
			rigs.append(r)
	next_rig_id = int(data.get("next_rig_id", 1))
	for r in rigs:
		next_rig_id = maxi(next_rig_id, int(r["id"]) + 1)
	# Phase 6.2: saves from before the cleanup tutorial have nothing to clean (the hillside is simply open)
	var cu = data.get("cleanup", null)
	cleanup = {"cleared": {}, "units": {}, "done": true}
	if cu is Dictionary:
		cleanup["done"] = bool(cu.get("done", false)) or cleanup_total() == 0
		for k in cu.get("cleared", {}):
			cleanup["cleared"][str(k)] = true
		for k in cu.get("units", {}):
			cleanup["units"][str(k)] = clampi(int(cu["units"][k]), 0, int(cleanup_cfg().get("heap_units", 5)))
	var st = data.get("story", {})
	story = {"intro_seen": bool(st.get("intro_seen", true)) if st is Dictionary else true, "found": {}, "read": {}, "visits": {}, "journal": [], "fossil": "", "companion": {"state": "none"}, "milestones": {}}
	if st is Dictionary:
		for k in st.get("milestones", {}):
			story["milestones"][str(k)] = true
		var fs := str(st.get("fossil", ""))
		story["fossil"] = fs if fs in ["found", "collector", "scientist"] else ""
		if bool(st.get("fossil_egg", false)):
			story["fossil_egg"] = true
		var cs = st.get("companion", {})
		if cs is Dictionary and str(cs.get("state", "none")) in ["pending", "egg", "alive"]:
			story["companion"] = {"state": str(cs["state"])}
			if bool(cs.get("marsh_done", false)):
				story["companion"]["marsh_done"] = true
			if bool(st.get("dino_mining_seen", false)):
				story["dino_mining_seen"] = true
			for k in ["ready_day", "egg_day", "born_day"]:
				if cs.has(k):
					story["companion"][k] = int(cs[k])
			for k in ["name", "stage_seen"]:
				if cs.has(k):
					story["companion"][k] = str(cs[k]).substr(0, 16)
		for k in st.get("visits", {}):
			story["visits"][str(k)] = true
		for k in st.get("journal", []):
			if not str(k) in story["journal"]:
				story["journal"].append(str(k))
		for k in st.get("found", {}):
			story["found"][str(k)] = true
		for k in st.get("read", {}):
			story["read"][str(k)] = true
	var s = data.get("stats", {})
	for k in stats:
		stats[k] = maxi(0, int(s.get(k, 0))) if s is Dictionary else 0
	if int(raw_data.get("schema", 1)) < SCHEMA:
		# Phase 9.1: an old six-stage save lands on the new stage that opens everything it already had (never lower)
		var old_stage := clampi(int(data.get("stage", 0)), 0, 5)
		var map: Array = cfg.get("legacy_stage_map", [0, 1, 4, 5, 6, 8])
		stage = maxi(clampi(int(map[old_stage]), 0, stages().size() - 1), implied_stage(vehicle_types))
		legacy_migrated = true
	else:
		stage = clampi(int(data.get("stage", 0)), 0, stages().size() - 1)
	check_stages()
	if not (st is Dictionary and st.has("milestones")):
		# a save from before Phase 8.2: what it has already dug counts as reached, with no windfall
		for m in milestone_defs():
			if milestone_met(m):
				story["milestones"][str(m["id"])] = true
	if story["intro_seen"] and not (st is Dictionary and st.has("visits")):
		# a save from before Phase 7.5: Walter does not come back for everything the player has already done
		journal_add("handover")
		for v in walter_cfg().get("visits", []):
			if visit_condition_met(v):
				complete_visit(str(v["id"]))
