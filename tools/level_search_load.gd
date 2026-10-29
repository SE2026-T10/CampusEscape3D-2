extends SceneTree

## Load check for LevelSearch (assignment VT-041): 60 concurrent users, target p95 <= 2.0 s.
##   godot --headless --path . --script res://tools/level_search_load.gd
##   godot --headless --path . --script res://tools/level_search_load.gd -- 20000   (catalog size, default 2000)
##
## WHAT THIS IS: 60 real threads released at the same moment, each a "user" doing a session of 10 requests
## (browse, text, ids, paging, a denied map) over a synthetic seeded catalog. Latency is wall-clock per request
## and per session. WHAT IT IS NOT: a network or server load test. The game has no server; this measures the
## search function itself under 60-way CPU contention on this machine, so it is a lower bound on a real service.

const USERS := 60
const REQUESTS_PER_USER := 10
const P95_TARGET_SECONDS := 2.0

var _catalog: Array = []


func _initialize() -> void:
	var n := 2000
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and String(args[0]).is_valid_int():
		n = int(args[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var words := ["library", "archive", "basement", "roof", "lab", "hall", "tower", "vault", "garden", "gate"]
	for i in n:
		_catalog.append({"id": StringName("m%06d" % i), "title": "%s %s %d" % [words[rng.randi() % 10].capitalize(), words[rng.randi() % 10], i % 500],
			"scene": "res://fake/m%d.tscn" % i, "description": "A synthetic map about the %s and the %s." % [words[rng.randi() % 10], words[rng.randi() % 10]]})
	var deny := func(id: StringName) -> bool: return String(id).ends_with("7")   # roughly 10% refused
	var request_ms: Array = []
	var session_ms: Array = []
	request_ms.resize(USERS * REQUESTS_PER_USER)
	session_ms.resize(USERS)
	var gate := Semaphore.new()
	var threads: Array[Thread] = []
	var wall_start := 0
	for u in USERS:
		var th := Thread.new()
		th.start(func():
			gate.wait()
			var s0 := Time.get_ticks_usec()
			for r in REQUESTS_PER_USER:
				var t0 := Time.get_ticks_usec()
				var params: Dictionary
				match r % 5:
					0: params = {"page_size": 50}
					1: params = {"query": words[(u + r) % 10], "page": 1 + r % 3, "page_size": 20}
					2: params = {"ids": [StringName("m%06d" % ((u * 31 + r) % n)), StringName("m%06d" % ((u * 17 + r) % n))]}
					3: params = {"query": words[u % 10], "page": 5, "page_size": 10}
					4: params = {"query": "no such text", "page_size": 5}
				var res := LevelSearch.search(params, _catalog, deny)
				if not res.ok:
					push_error("unexpected error %s" % res.error)
				request_ms[u * REQUESTS_PER_USER + r] = (Time.get_ticks_usec() - t0) / 1000.0
			session_ms[u] = (Time.get_ticks_usec() - s0) / 1000.0)
		threads.append(th)
	wall_start = Time.get_ticks_usec()
	for u in USERS:
		gate.post()
	for th in threads:
		th.wait_to_finish()
	var wall_ms := (Time.get_ticks_usec() - wall_start) / 1000.0
	request_ms.sort()
	session_ms.sort()
	var p95_request := _percentile(request_ms, 95.0)
	var p95_session := _percentile(session_ms, 95.0)
	print("LOAD catalog=%d users=%d requests=%d cores=%d" % [n, USERS, USERS * REQUESTS_PER_USER, OS.get_processor_count()])
	print("LOAD per request  : p50=%.2f ms  p95=%.2f ms  max=%.2f ms" % [_percentile(request_ms, 50.0), p95_request, request_ms[-1]])
	print("LOAD per session  : p50=%.2f ms  p95=%.2f ms  max=%.2f ms  (10 requests each)" % [_percentile(session_ms, 50.0), p95_session, session_ms[-1]])
	print("LOAD wall clock for all 60 users: %.2f ms" % wall_ms)
	var ok := p95_request / 1000.0 <= P95_TARGET_SECONDS and p95_session / 1000.0 <= P95_TARGET_SECONDS
	print("LOAD target p95 <= %.1f s: %s" % [P95_TARGET_SECONDS, "MET" if ok else "NOT MET"])
	quit(0 if ok else 1)


## Nearest-rank percentile of an ascending-sorted array.
func _percentile(sorted: Array, p: float) -> float:
	var rank := int(ceil(p / 100.0 * sorted.size()))
	return float(sorted[clampi(rank - 1, 0, sorted.size() - 1)])
