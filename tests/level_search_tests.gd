extends RefCounted

## LevelSearch tests (assignment VT-041: filtered search, pagination, stable order).
## Called from tests/test_scene.gd; tests/level_search_runner.gd runs only this file (seconds, not 17 minutes).
##
## The contract these tests protect (risk: a schema/API change breaks an old client):
##   - the result always has the keys schema, ok, items, page, page_size, total, total_pages (+ error when ok is false);
##   - every item keeps the four keys of a LevelCatalog entry (id, title, scene, description);
##   - LevelCatalog.LEVELS itself is never changed or reordered by a search;
##   - old callers that pass {} (or unknown keys) still get every map.
## Test design: boundary value analysis on page (1, last, last+1, 0) and page_size (0, 1, 50, 51),
## and on the item count around one page (n = size-1, size, size+1).

const SEARCH_KEYS := ["schema", "ok", "items", "page", "page_size", "total", "total_pages"]
const ITEM_KEYS := ["id", "title", "scene", "description"]

var failures: Array[String] = []


func run(_host: Node = null) -> Array[String]:
	_t01_browse_defaults_and_schema()
	_t02_old_client_contract_and_catalog_untouched()
	_t03_bva_page_size()
	_t04_bva_page()
	_t05_bva_item_count_around_one_page()
	_t06_stable_order_with_ties()
	_t07_pages_partition_the_result()
	_t08_text_filter()
	_t09_id_filter()
	_t10_negative_invalid_types()
	_t11_authorization_browse_path()
	_t12_authorization_search_path()
	_t13_failure_path_keeps_schema()
	_t14_unknown_and_missing_params()
	print("  [search] LevelSearch: schema, boundaries (page 0/1/last/last+1, page_size 0/1/50/51), stable order, filters, authorization, failure path")
	return failures


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append("[search] " + message)


## A synthetic catalog of `n` maps with zero-padded ids and titles.
func _catalog(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append({"id": StringName("m%03d" % i), "title": "Map %03d" % i,
			"scene": "res://fake/m%03d.tscn" % i, "description": "Synthetic map number %d." % i})
	return out


func _ids(result: Dictionary) -> Array:
	var out: Array = []
	for item in result.get("items", []):
		out.append(item.id)
	return out


func _has_keys(d: Dictionary, keys: Array) -> bool:
	for k in keys:
		if not d.has(k):
			return false
	return true


func _deny(denied: Array) -> Callable:
	return func(id: StringName) -> bool: return not denied.has(id)


# --- T01 ---------------------------------------------------------------------------------------

func _t01_browse_defaults_and_schema() -> void:
	var r := LevelSearch.search({})
	_expect(_has_keys(r, SEARCH_KEYS), "T01: the result must have the keys %s, got %s." % [SEARCH_KEYS, r.keys()])
	_expect(r.get("schema") == LevelSearch.SCHEMA_VERSION and r.get("schema") == 1, "T01: schema must be 1, got %s." % r.get("schema"))
	_expect(r.get("ok") == true, "T01: browsing with {} must succeed, got %s." % r.get("ok"))
	_expect(r.get("page") == 1 and r.get("page_size") == 10, "T01: defaults must be page 1, page_size 10, got %s/%s." % [r.get("page"), r.get("page_size")])
	_expect(r.get("total") == LevelCatalog.LEVELS.size() and r.get("total_pages") == 1,
		"T01: total must be %d and total_pages 1, got %s/%s." % [LevelCatalog.LEVELS.size(), r.get("total"), r.get("total_pages")])
	_expect(r.get("items", []).size() == LevelCatalog.LEVELS.size(), "T01: both real maps must be returned, got %d." % r.get("items", []).size())


# --- T02 ---------------------------------------------------------------------------------------

func _t02_old_client_contract_and_catalog_untouched() -> void:
	var before := LevelCatalog.LEVELS.duplicate(true).hash()
	var order_before := LevelCatalog.ids()
	var r := LevelSearch.search({"query": "library", "page": 1, "page_size": 5})
	for item in r.get("items", []):
		_expect(_has_keys(item, ITEM_KEYS), "T02: an item lost one of %s: %s." % [ITEM_KEYS, item.keys()])
		var original := LevelCatalog.get_level(item.get("id", &""))
		for k in ITEM_KEYS:
			_expect(original.get(k) == item.get(k), "T02: item %s changed field '%s'." % [item.get("id"), k])
	_expect(r.get("items", []).size() == 2, "T02: 'library' must find both real maps, got %d." % r.get("items", []).size())
	_expect(LevelCatalog.LEVELS.duplicate(true).hash() == before, "T02: a search changed LevelCatalog.LEVELS.")
	_expect(LevelCatalog.ids() == order_before and LevelCatalog.ids()[0] == LevelCatalog.TUTORIAL,
		"T02: the menu order (tutorial first) must not change.")


# --- T03: BVA on page_size (lower 1, upper 50) --------------------------------------------------

func _t03_bva_page_size() -> void:
	var catalog := _catalog(120)
	var cases := {0: false, 1: true, 2: true, 49: true, 50: true, 51: false}
	for size in cases:
		var r := LevelSearch.search({"page_size": size}, catalog)
		_expect(r.get("ok") == cases[size], "T03: page_size %d must be %s, got ok=%s." % [size, "accepted" if cases[size] else "rejected", r.get("ok")])
		if cases[size]:
			_expect(r.get("items", []).size() == size, "T03: page_size %d must return %d items, got %d." % [size, size, r.get("items", []).size()])
		else:
			_expect(r.get("error") == "invalid_page_size", "T03: page_size %d must give invalid_page_size, got %s." % [size, r.get("error")])
	_expect(LevelSearch.search({"page_size": -1}, catalog).get("error") == "invalid_page_size", "T03: a negative page_size must be rejected.")


# --- T04: BVA on page (lower 1, last, last + 1) ------------------------------------------------

func _t04_bva_page() -> void:
	var catalog := _catalog(25)   # page_size 10 -> pages of 10, 10, 5
	var expected := {1: 10, 2: 10, 3: 5, 4: 0}
	for page in expected:
		var r := LevelSearch.search({"page": page, "page_size": 10}, catalog)
		_expect(r.get("ok") == true, "T04: page %d must be accepted (a page past the end is empty, not an error)." % page)
		_expect(r.get("items", []).size() == expected[page], "T04: page %d must hold %d items, got %d." % [page, expected[page], r.get("items", []).size()])
		_expect(r.get("total") == 25 and r.get("total_pages") == 3, "T04: page %d: total/total_pages must be 25/3, got %s/%s." % [page, r.get("total"), r.get("total_pages")])
	_expect(LevelSearch.search({"page": 0}, catalog).get("error") == "invalid_page", "T04: page 0 must be rejected.")
	_expect(LevelSearch.search({"page": -1}, catalog).get("error") == "invalid_page", "T04: page -1 must be rejected.")


# --- T05: BVA on the item count around one page (size - 1, size, size + 1) ----------------------

func _t05_bva_item_count_around_one_page() -> void:
	var expected := {0: 0, 1: 1, 9: 1, 10: 1, 11: 2}   # n -> total_pages at page_size 10
	for n in expected:
		var r := LevelSearch.search({"page_size": 10}, _catalog(n))
		_expect(r.get("ok") == true and r.get("total") == n, "T05: n=%d: ok and total must be true/%d, got %s/%s." % [n, n, r.get("ok"), r.get("total")])
		_expect(r.get("total_pages") == expected[n], "T05: n=%d: total_pages must be %d, got %s." % [n, expected[n], r.get("total_pages")])
		_expect(r.get("items", []).size() == mini(n, 10), "T05: n=%d: page 1 must hold %d items, got %d." % [n, mini(n, 10), r.get("items", []).size()])


# --- T06 ---------------------------------------------------------------------------------------

func _t06_stable_order_with_ties() -> void:
	# Equal titles must be ordered by id, whatever the order of the catalog; titles compare case-insensitively.
	var base: Array = [
		{"id": &"b", "title": "Same", "scene": "res://b.tscn", "description": "d"},
		{"id": &"a", "title": "Same", "scene": "res://a.tscn", "description": "d"},
		{"id": &"c", "title": "alpha", "scene": "res://c.tscn", "description": "d"},
		{"id": &"d", "title": "Zeta", "scene": "res://d.tscn", "description": "d"},
		{"id": &"e", "title": "same", "scene": "res://e.tscn", "description": "d"},
	]
	var reference := _ids(LevelSearch.search({}, base))
	_expect(reference == [&"c", &"a", &"b", &"e", &"d"], "T06: order must be title (case-insensitive) then id, got %s." % [reference])
	var rng := RandomNumberGenerator.new()
	rng.seed = 41   # fixed seed: the shuffles are the same every run
	for i in 20:
		var shuffled := base.duplicate()
		for j in range(shuffled.size() - 1, 0, -1):
			var k := rng.randi_range(0, j)
			var tmp = shuffled[j]
			shuffled[j] = shuffled[k]
			shuffled[k] = tmp
		_expect(_ids(LevelSearch.search({}, shuffled)) == reference, "T06: shuffle %d changed the result order." % i)
	_expect(_ids(LevelSearch.search({}, base)) == reference, "T06: the same call twice must give the same order.")


# --- T07 ---------------------------------------------------------------------------------------

func _t07_pages_partition_the_result() -> void:
	var catalog := _catalog(40)
	var full := _ids(LevelSearch.search({"page_size": 50}, catalog))
	var joined: Array = []
	var pages := int(LevelSearch.search({"page_size": 7}, catalog).get("total_pages", 0))
	_expect(pages == 6, "T07: 40 items at 7 per page must be 6 pages, got %d." % pages)
	for p in range(1, pages + 1):
		joined.append_array(_ids(LevelSearch.search({"page": p, "page_size": 7}, catalog)))
	_expect(joined == full, "T07: the pages joined must equal the full ordered result (no gap, no duplicate, same order).")
	_expect(joined.size() == 40, "T07: expected 40 items over all pages, got %d." % joined.size())


# --- T08 ---------------------------------------------------------------------------------------

func _t08_text_filter() -> void:
	_expect(_ids(LevelSearch.search({"query": "expanded"})) == [LevelCatalog.EXPANDED], "T08: 'expanded' must find only the Expanded Library.")
	_expect(_ids(LevelSearch.search({"query": "LIBRARY"})).size() == 2, "T08: the filter must ignore case.")
	_expect(_ids(LevelSearch.search({"query": "  expanded  "})) == [LevelCatalog.EXPANDED], "T08: the query must be trimmed.")
	_expect(_ids(LevelSearch.search({"query": "rare manuscript"})) == [LevelCatalog.EXPANDED], "T08: the filter must also search the description.")
	var none := LevelSearch.search({"query": "no such text anywhere"})
	_expect(none.get("ok") == true and none.get("items", []).is_empty() and none.get("total") == 0 and none.get("total_pages") == 0,
		"T08: no match must be ok with an empty page, got %s." % [none])
	_expect(LevelSearch.search({"query": "   "}).get("total") == LevelCatalog.LEVELS.size(), "T08: a blank query means no filter.")


# --- T09 ---------------------------------------------------------------------------------------

func _t09_id_filter() -> void:
	_expect(_ids(LevelSearch.search({"ids": [LevelCatalog.EXPANDED]})) == [LevelCatalog.EXPANDED], "T09: ids must restrict the result.")
	var unknown := LevelSearch.search({"ids": [&"no_such_map"]})
	_expect(unknown.get("ok") == true and unknown.get("total") == 0, "T09: an unknown id is an empty result, not an error.")
	_expect(_ids(LevelSearch.search({"ids": [LevelCatalog.TUTORIAL, LevelCatalog.EXPANDED], "query": "expanded"})) == [LevelCatalog.EXPANDED],
		"T09: ids and query must both apply (AND).")


# --- T10: negative tests ------------------------------------------------------------------------

func _t10_negative_invalid_types() -> void:
	var cases := [
		[{"page": "2"}, "invalid_page"],
		[{"page": 1.5}, "invalid_page"],
		[{"page_size": 10.5}, "invalid_page_size"],
		[{"page_size": "10"}, "invalid_page_size"],
		[{"query": 42}, "invalid_query"],
		[{"ids": "expanded_library"}, "invalid_ids"],
	]
	for c in cases:
		var params: Dictionary = c[0]
		var snapshot := params.duplicate(true)
		var r := LevelSearch.search(params)
		_expect(r.get("ok") == false and r.get("error") == c[1], "T10: %s must give error '%s', got ok=%s error=%s." % [params, c[1], r.get("ok"), r.get("error")])
		_expect(params == snapshot, "T10: the caller's params must not be modified.")


# --- T11: authorization, browse path ------------------------------------------------------------

func _t11_authorization_browse_path() -> void:
	var r := LevelSearch.search({}, LevelCatalog.LEVELS, _deny([LevelCatalog.EXPANDED]))
	_expect(_ids(r) == [LevelCatalog.TUTORIAL], "T11: a map the viewer may not open must not be listed, got %s." % [_ids(r)])
	_expect(r.get("total") == 1 and r.get("total_pages") == 1, "T11: total must count only allowed maps, got %s/%s." % [r.get("total"), r.get("total_pages")])
	var all_denied := LevelSearch.search({}, LevelCatalog.LEVELS, _deny([LevelCatalog.TUTORIAL, LevelCatalog.EXPANDED]))
	_expect(all_denied.get("ok") == true and all_denied.get("total") == 0, "T11: when nothing is allowed the result is empty, not an error.")


# --- T12: authorization, search path (the path the mutation removes) ---------------------------

func _t12_authorization_search_path() -> void:
	var deny := _deny([LevelCatalog.EXPANDED])
	var by_text := LevelSearch.search({"query": "library"}, LevelCatalog.LEVELS, deny)
	_expect(_ids(by_text) == [LevelCatalog.TUTORIAL], "T12: a text search must not return a denied map, got %s." % [_ids(by_text)])
	_expect(by_text.get("total") == 1, "T12: a text search's total must not count a denied map (it would leak that it exists), got %s." % by_text.get("total"))
	var by_id := LevelSearch.search({"ids": [LevelCatalog.EXPANDED]}, LevelCatalog.LEVELS, deny)
	_expect(by_id.get("items", []).is_empty() and by_id.get("total") == 0, "T12: asking for a denied map by id must look the same as an unknown id.")
	var by_both := LevelSearch.search({"query": "expanded", "ids": [LevelCatalog.EXPANDED]}, LevelCatalog.LEVELS, deny)
	_expect(by_both.get("total") == 0, "T12: query + ids must not return a denied map.")
	# Same viewer, no restriction: the map is visible again (the check is the only difference).
	_expect(_ids(LevelSearch.search({"query": "expanded"})) == [LevelCatalog.EXPANDED], "T12: with no restriction the map must be found.")


# --- T13: failure path tied to the schema risk --------------------------------------------------

func _t13_failure_path_keeps_schema() -> void:
	# A client written against schema 1 reads r.items and r.total without checking ok. An error must not
	# remove those keys or change their types, or that client breaks (the risk of this assignment).
	for params in [{"page": 0}, {"page_size": 51}, {"query": 1}]:
		var r := LevelSearch.search(params)
		_expect(_has_keys(r, SEARCH_KEYS + ["error"]), "T13: error result for %s lost keys: %s." % [params, r.keys()])
		_expect(r.get("schema") == 1 and r.get("ok") == false, "T13: error result for %s must keep schema 1 and ok=false." % [params])
		_expect(r.get("items") is Array and r.get("items", [1]).is_empty() and r.get("total") == 0 and r.get("total_pages") == 0,
			"T13: error result for %s must keep items=[] and total=0 (types intact), got %s." % [params, r])
		_expect(r.get("page") is int and r.get("page_size") is int, "T13: error result for %s must keep integer page and page_size." % [params])


# --- T14 ---------------------------------------------------------------------------------------

func _t14_unknown_and_missing_params() -> void:
	# An old client sends nothing new; a newer client may send keys this version does not know yet. Both work.
	var with_unknown := LevelSearch.search({"future_option": true, "sort": "random"})
	_expect(with_unknown.get("ok") == true and with_unknown.get("total") == LevelCatalog.LEVELS.size(),
		"T14: unknown params must be ignored, got ok=%s." % with_unknown.get("ok"))
	_expect(_ids(with_unknown) == _ids(LevelSearch.search({})), "T14: unknown params must not change the result.")
	var defaults := LevelSearch.search({})
	_expect(defaults.get("page") == 1 and defaults.get("page_size") == LevelSearch.DEFAULT_PAGE_SIZE, "T14: missing page/page_size must use the defaults.")
