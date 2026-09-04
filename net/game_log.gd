extends Node
## Server-only JSONL match log -- see memory/plan.md's roadmap item 18.
## Appends one JSON object per line to <log dir>/<timestamp>.jsonl,
## opened once per process lifetime (the file stays open, appending)
## and kept for the whole match/process. A client peer's own calls are
## a no-op (NetworkManager.is_server() guard) -- only the host logs,
## per the human owner's own request ("o host deve fazer log de
## tudo"), so every call site below can call info()/warn()/error()
## unconditionally without its own server check.
##
## KNOWN LIMITATION, deliberately not solved this phase: this only
## captures events the code explicitly routes through info()/warn()/
## error() below. It does NOT intercept the engine's own native
## push_error()/push_warning() console output, and captures nothing
## from a process that crashes hard enough to never reach a call site
## here. Existing push_error()/push_warning() call sites got a paired
## GameLog.warn()/.error() call added alongside them (additive, not a
## replacement -- the console output is still useful on its own).
##
## Separate from the structured replay file Phases 19-20 build --
## deliberately split per the human owner's own request: this is a
## human-readable debug/incident log, the replay is a compact,
## deterministic reconstruction format. They serve different readers.

var _file: FileAccess = null
var _log_path: String = ""
var _log_dir: String = "user://logs"
## Timestamp filenames only have 1-second granularity -- 2 server
## processes started in the same wall-clock second (a real risk in
## this project's own 2-headless-process dev testing) would otherwise
## compute the identical path and silently clobber each other's log
## (FileAccess.WRITE truncates). Combined with the process id below,
## this counter also guarantees reset_for_testing() never reuses a
## path within one process/test run.
var _files_opened: int = 0


func info(event: String, data: Dictionary = {}) -> void:
	_write("info", event, data)


func warn(event: String, data: Dictionary = {}) -> void:
	_write("warn", event, data)


func error(event: String, data: Dictionary = {}) -> void:
	_write("error", event, data)


func current_log_path() -> String:
	return _log_path


## Test-only: closes any open file and points future writes at a fresh
## file under log_dir (a scratch directory in tests, never the real
## user://logs/ default) -- lets each test start from a known-clean
## state instead of depending on whatever a previous test already
## wrote to a shared, real log location.
func reset_for_testing(log_dir: String = "user://logs") -> void:
	if _file:
		_file.close()
	_file = null
	_log_path = ""
	_log_dir = log_dir


## Pure, no I/O -- directly unit-testable without touching the
## filesystem or NetworkManager.
static func format_line(
	level: String, event: String, data: Dictionary, timestamp: String
) -> String:
	return JSON.stringify({"timestamp": timestamp, "level": level, "event": event, "data": data})


func _write(level: String, event: String, data: Dictionary) -> void:
	if not NetworkManager.is_server():
		return
	_ensure_file_open()
	if not _file:
		return
	_file.store_line(format_line(level, event, data, Time.get_datetime_string_from_system()))
	_file.flush()


func _ensure_file_open() -> void:
	if _file:
		return
	DirAccess.make_dir_recursive_absolute(_log_dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	_log_path = "%s/%s_pid%d_%d.jsonl" % [_log_dir, stamp, OS.get_process_id(), _files_opened]
	_files_opened += 1
	_file = FileAccess.open(_log_path, FileAccess.WRITE)
