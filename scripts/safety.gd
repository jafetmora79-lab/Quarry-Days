extends Node
class_name QuarrySafety
## Phase 8.1: lightweight stuck-player safeguard. It never replaces sound geometry; it only catches the player when
## they end up somewhere they cannot get out of:
##   * a fall of a metre or more that is followed by no way out (no climb, no walk away) for a few seconds,
##   * dropping below the lowest floor of the quarry.
## The player is put back on the last safe ground they stood on, a second or so before the fall.

signal rescued(reason: String)

const DROP := 1.0            ## a fall at least this deep starts the watch
const WATCH := 5.0           ## seconds without a way out before the rescue
const ESCAPE_UP := 0.9       ## climbing this far back up counts as getting out
const ESCAPE_FAR := 7.0      ## so does walking this far away (down a ramp, along a trench)

var game
var player: CharacterBody3D
var enabled := true
var ring: Array = []         ## recent grounded positions
var rescues := 0
var last_reason := ""
var watching := false
var land_pos := Vector3.ZERO
var watch_t := 0.0
var safe_for_watch := Vector3.ZERO
var airborne := 0.0
var last_ground_y := 0.0
var _sample := 0.0

func setup(g) -> void:
	game = g
	player = g.player
	name = "Safety"
	last_ground_y = player.global_position.y

func safe_pos() -> Vector3:
	if ring.is_empty():
		return Vector3(0, 0.2, 8)
	return ring[maxi(0, ring.size() - 5)]

func void_limit() -> float:
	return (game.pit_zone.deepest_y - 3.0) if game.pit_zone else -12.0

func tick(delta: float) -> void:
	if not enabled or player == null or not is_instance_valid(player) or game.driving != null or game.sleeping:
		return
	var y := player.global_position.y
	if y < void_limit():
		rescue("fell below the quarry floor")
		return
	if player.is_on_floor():
		if airborne > 0.15:
			var drop := last_ground_y - y
			if drop >= DROP:
				watching = true
				land_pos = player.global_position
				watch_t = 0.0
		airborne = 0.0
		last_ground_y = y
		_sample -= delta
		if _sample <= 0.0 and not watching:
			_sample = 0.25
			ring.append(player.global_position)
			if ring.size() > 16:
				ring.pop_front()
	else:
		if airborne == 0.0 and not watching:
			safe_for_watch = safe_pos()
		airborne += delta
	if watching:
		watch_t += delta
		var p := player.global_position
		if p.y - land_pos.y >= ESCAPE_UP or Vector2(p.x - land_pos.x, p.z - land_pos.z).length() >= ESCAPE_FAR:
			watching = false
		elif watch_t >= WATCH:
			rescue("trapped in a pit")

## Puts the player back on safe ground. Also available on demand (the Unstuck key).
func rescue(reason := "stuck") -> void:
	var to := safe_for_watch if watching else safe_pos()
	player.global_position = to + Vector3(0, 0.15, 0)
	player.velocity = Vector3.ZERO
	watching = false
	airborne = 0.0
	watch_t = 0.0
	last_ground_y = to.y
	rescues += 1
	last_reason = reason
	if game.hud:
		game.hud.toast("Back on solid ground", "You %s. Climbing out is not possible there, so you were lifted back out." % reason, "info")
	rescued.emit(reason)
