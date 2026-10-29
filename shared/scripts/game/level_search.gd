class_name LevelSearch
extends RefCounted

## STUB (red step of test-first): the interface exists, the behaviour does not.

const SCHEMA_VERSION := 1
const DEFAULT_PAGE_SIZE := 10
const MAX_PAGE_SIZE := 50


static func search(_params: Dictionary = {}, _catalog: Array = LevelCatalog.LEVELS, _can_access: Callable = Callable()) -> Dictionary:
	return {"schema": SCHEMA_VERSION, "ok": false, "error": "not_implemented", "items": [], "page": 1,
		"page_size": DEFAULT_PAGE_SIZE, "total": 0, "total_pages": 0}
