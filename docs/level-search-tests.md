# LevelSearch: how to run the tests (assignment VT-041)

`LevelSearch` (`shared/scripts/game/level_search.gd`) adds filtered, paginated search with a stable order over the map catalog. It is data in, data out: it reads `LevelCatalog.LEVELS`, changes nothing and adds no dependency.

You need Godot **4.7.2** (`bash tools/ci/setup_godot.sh` prints its path) and the project imported once (`bash tools/ci/validate.sh`, or `godot --headless --path . --editor --quit`).

```
export GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64

# 1. The LevelSearch tests only (seconds). Passes only on exit 0 + the PASSED line + no SCRIPT ERROR.
bash tools/ci/run_level_search_tests.sh

# 2. Flaky review: 100 random test orders, 300 shuffle seeds, 60 concurrent threads, no clock use.
$GODOT --headless --path . --script res://tools/level_search_flaky.gd

# 3. Load check: 60 concurrent users, target p95 <= 2.0 s (optional argument: catalog size, default 2000).
$GODOT --headless --path . --script res://tools/level_search_load.gd
$GODOT --headless --path . --script res://tools/level_search_load.gd -- 20000

# 4. The whole suite, which now includes the LevelSearch tests (about 17 minutes).
bash tools/ci/run_tests.sh
```

The contract the tests protect: the result always has `schema, ok, items, page, page_size, total, total_pages` (plus `error` when `ok` is false); every item keeps the four keys of a `LevelCatalog` entry; `LevelCatalog.LEVELS` and the menu order are never changed; an old caller that sends `{}` still gets every map.

Note: a script that fails to compile can still make headless Godot exit 0 and print the PASSED line, so never trust the exit code alone (see `tools/ci/run_level_search_tests.sh`).
