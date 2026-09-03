extends CanvasLayer
## Phase 1's debug overlay: this client's ping to the server (ENet's own
## per-peer round-trip-time stat) and how often this client's own
## predicted character receives an authoritative snapshot. Scoped to
## Phase 1's "done" criteria (docs/blueprint's networking model); the
## Hitbox/Projectile Viewer and command console arrive with Phase 2.
## Pattern inherited from amazing-nauts' ui/hud/network_stats_overlay.gd.

@export var characters_path: NodePath = ^"../Characters"
@export var update_interval: float = 0.5

var _snapshot_count_this_window: int = 0
var _time_since_update: float = 0.0
var _tracked_character: CharacterController

@onready var _label: Label = $Label


func _process(delta: float) -> void:
	_ensure_tracking_own_character()
	_time_since_update += delta
	if _time_since_update < update_interval:
		return
	var rate := _snapshot_count_this_window / _time_since_update
	_label.text = "Ping: %dms | Snapshots/s: %.1f" % [_ping_ms(), rate]
	_snapshot_count_this_window = 0
	_time_since_update = 0.0


func _ensure_tracking_own_character() -> void:
	if is_instance_valid(_tracked_character):
		return
	var characters := get_node_or_null(characters_path)
	if not characters:
		return
	var own := characters.get_node_or_null(str(multiplayer.get_unique_id()))
	if own:
		_tracked_character = own
		_tracked_character.snapshot_received.connect(func(): _snapshot_count_this_window += 1)


func _ping_ms() -> int:
	if NetworkManager.is_server():
		return 0
	return NetworkManager.get_peer_rtt_ms(1)
