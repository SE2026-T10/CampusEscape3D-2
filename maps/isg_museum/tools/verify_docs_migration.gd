extends SceneTree

## Read/instantiate archived resources; never enter old snapshots into gameplay.
const MANIFEST := "res://maps/isg_museum/docs/reports/docs-cleanup-v1/data/path-migration.json"
const ReportPaths := preload("res://maps/isg_museum/tools/report_paths.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var checked := []
	var scripts := []
	var errors := []
	for row in manifest.files:
		if row.category=="reproduce" and String(row.new_path).get_extension()=="gd":
			var script: Script = load("res://"+row.new_path)
			if script==null or not script.can_instantiate(): errors.append(row.new_path)
			else: scripts.append(row.new_path)
		if row.category not in ["snapshot","snapshots"]: continue
		var path: String = "res://"+row.new_path
		if path.get_extension() not in ["tscn","tres","scn","res"]: continue
		var resource := load(path)
		if resource==null:
			errors.append(path)
			continue
		if resource is PackedScene:
			var scene: Node = resource.instantiate()
			if scene==null: errors.append(path)
			else: scene.free()
		for entry in ResourceLoader.get_dependencies(path):
			var dependency := entry.get_slice("::",entry.get_slice_count("::")-1)
			if dependency.begins_with("res://") and not FileAccess.file_exists(dependency):
				errors.append(path+" -> "+dependency)
		checked.append(path)
	var output := ReportPaths.artifact("res://maps/isg_museum/docs/reports/docs-cleanup-v1/","snapshot-load-check.json")
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"resources":checked,"reproduction_scripts":scripts,"errors":errors},"\t")+"\n")
	file.close()
	for error in errors: push_error(error)
	print("Archived snapshot resources: ",checked.size()," loaded; ",errors.size()," errors")
	quit(0 if errors.is_empty() else 1)
