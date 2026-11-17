extends RefCounted

## Authoring/QA output only. Baseline input paths must remain separate constants.
const REPORTS := "res://maps/isg_museum/docs/reports/"
const GROUPS := ["images", "videos", "logs", "data", "snapshots", "reproduce"]

static func output_root(default_root: String) -> String:
	var result := default_root
	var arguments := OS.get_cmdline_user_args()
	for i in arguments.size():
		if arguments[i].begins_with("--output="):
			result = arguments[i].trim_prefix("--output=")
		elif arguments[i]=="--output" and i+1<arguments.size():
			result = arguments[i+1]
	assert(result.begins_with(REPORTS) and not ".." in result and not "\\" in result,
		"Report output must remain below museum docs/reports")
	return result.trim_suffix("/")+"/"

static func artifact(report_root: String, filename: String) -> String:
	assert(report_root.begins_with(REPORTS) and not ".." in report_root)
	assert(not filename.is_absolute_path() and not ".." in filename and not "\\" in filename)
	var group := "data"
	var extension := filename.get_extension().to_lower()
	if filename.get_slice("/",0) in GROUPS or filename in ["REPORT.md","VALIDATION.json"]:
		group = ""
	elif extension in ["png","jpg","jpeg","svg","webp","bmp","gif"]:
		group = "images"
	elif extension in ["avi","mp4","webm","mov","mkv","ogv"]:
		group = "videos"
	elif extension=="log":
		group = "logs"
	elif extension in ["tscn","tres","scn","res"]:
		group = "snapshots"
	elif extension in ["gd","py","ps1"]:
		group = "reproduce"
	var result := report_root.path_join(group).path_join(filename)
	assert(DirAccess.make_dir_recursive_absolute(result.get_base_dir())==OK)
	return result
