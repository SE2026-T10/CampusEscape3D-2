class_name LevelSearch
extends RefCounted

## Filtered, paginated search over the map catalog (assignment VT-041). Data in, data out:
## it reads LevelCatalog.LEVELS (or a catalog passed in), changes nothing, and has no state.
##
## params (all optional; unknown keys are ignored so newer clients keep working):
##   query      String  case-insensitive text in the title or description (blank = no filter)
##   ids        Array   keep only these map ids (AND with query)
##   page       int     1-based, default 1; a page past the end is empty, not an error
##   page_size  int     1..MAX_PAGE_SIZE, default DEFAULT_PAGE_SIZE
## can_access: Callable(id: StringName) -> bool. A map it refuses is neither listed nor counted.
##   Left unset, every map is visible (what the menu always did).
##
## Result: {schema, ok, items, page, page_size, total, total_pages} plus `error` when ok is false.
## An error keeps every key with the same types, so a client written for schema 1 that reads
## `items` and `total` without checking `ok` still works. Every item is a copy of a LevelCatalog
## entry (id, title, scene, description). Order: title (ignoring case), then id.

const SCHEMA_VERSION := 1
const DEFAULT_PAGE_SIZE := 10
const MAX_PAGE_SIZE := 50


static func search(params: Dictionary = {}, catalog: Array = LevelCatalog.LEVELS, can_access: Callable = Callable()) -> Dictionary:
	var page = params.get("page", 1)
	var page_size = params.get("page_size", DEFAULT_PAGE_SIZE)
	var query = params.get("query", "")
	var ids = params.get("ids", [])
	if not page is int or page < 1:
		return _error("invalid_page", page if page is int else 1, page_size if page_size is int else DEFAULT_PAGE_SIZE)
	if not page_size is int or page_size < 1 or page_size > MAX_PAGE_SIZE:
		return _error("invalid_page_size", page, DEFAULT_PAGE_SIZE)
	if not query is String:
		return _error("invalid_query", page, page_size)
	if not ids is Array:
		return _error("invalid_ids", page, page_size)

	var needle := (query as String).strip_edges().to_lower()
	var pool: Array = []
	if needle == "" and (ids as Array).is_empty():
		pool = _browse(catalog, can_access)
	else:
		pool = _find(catalog, needle, ids, can_access)
	pool.sort_custom(_before)

	var p: int = page
	var size: int = page_size
	var total: int = pool.size()
	var start: int = (p - 1) * size
	var items: Array = []
	if start < total:
		items = pool.slice(start, mini(start + size, total))
	return {"schema": SCHEMA_VERSION, "ok": true, "items": items, "page": p, "page_size": size,
		"total": total, "total_pages": (total + size - 1) / size}


## Every map the viewer may open.
static func _browse(catalog: Array, can_access: Callable) -> Array:
	var out: Array = []
	for level in catalog:
		if _allowed(can_access, level.id):
			out.append(level.duplicate())
	return out


## The maps that match the text and the id list, and that the viewer may open.
static func _find(catalog: Array, needle: String, ids: Array, can_access: Callable) -> Array:
	var out: Array = []
	for level in catalog:
		if not _allowed(can_access, level.id):
			continue
		if not ids.is_empty() and not ids.has(level.id):
			continue
		if needle != "" and not (String(level.title).to_lower().contains(needle) or String(level.description).to_lower().contains(needle)):
			continue
		out.append(level.duplicate())
	return out


static func _allowed(can_access: Callable, id: StringName) -> bool:
	return not can_access.is_valid() or bool(can_access.call(id))


## Title ignoring case, then id: equal titles never swap places between calls or catalog orders.
static func _before(a: Dictionary, b: Dictionary) -> bool:
	var ta := String(a.title).to_lower()
	var tb := String(b.title).to_lower()
	if ta != tb:
		return ta < tb
	return String(a.id) < String(b.id)


static func _error(code: String, page: int, page_size: int) -> Dictionary:
	return {"schema": SCHEMA_VERSION, "ok": false, "error": code, "items": [], "page": page,
		"page_size": page_size, "total": 0, "total_pages": 0}
