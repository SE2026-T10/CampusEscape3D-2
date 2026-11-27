extends SceneTree

## Diagnostic only: weak references observe fixture lifetimes without retaining it.
const Suite := preload("res://maps/isg_museum/tests/post_b_fixes_tests.gd")
const ReportPaths := preload("res://maps/isg_museum/tools/report_paths.gd")
var observed: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func remember(object: Object, kind: String, label: String) -> void:
	observed.append({"id":object.get_instance_id(),"kind":kind,"label":label,"weak":weakref(object)})

func guard_ready(reference: WeakRef) -> void:
	var actor: Guard = reference.get_ref()
	if not is_instance_valid(actor): return
	remember(actor.machine,"machine",String(actor.name))
	for id in [GuardStateMachine.PATROL,GuardStateMachine.INVESTIGATE,GuardStateMachine.CHASE]:
		remember(actor.machine.get_state(id),"state",String(actor.name)+":"+str(id))

func node_added_to_fixture(node: Node) -> void:
	remember(node,"node",String(node.name))
	if node is Guard: node.ready.connect(guard_ready.bind(weakref(node)),CONNECT_ONE_SHOT)

func run() -> void:
	node_added.connect(node_added_to_fixture)
	var host := Node.new()
	root.add_child(host)
	var suite := Suite.new()
	var failures: Array[String] = await suite.run(host)
	var audio_samples: Array = suite.teardown_samples.duplicate(true)
	host.free()
	suite = null
	# Observe immediate teardown and a bounded deferred/audio drain separately.
	var immediate := 0
	for row in observed:
		if is_instance_valid(row.weak.get_ref()): immediate += 1
	for i in 120: await physics_frame
	node_added.disconnect(node_added_to_fixture)
	var alive := []
	var counts := {"node":0,"machine":0,"state":0}
	for row in observed:
		counts[row.kind] += 1
		if is_instance_valid(row.weak.get_ref()):
			alive.append({"id":row.id,"kind":row.kind,"label":row.label})
	var file := FileAccess.open(ReportPaths.artifact("res://maps/isg_museum/docs/reports/docs-cleanup-v1/","post-b-lifetime-audit.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"observed":counts,"alive_immediately_after_fixture":immediate,"alive_after_120_physics_frames":alive,"audio_teardown":audio_samples,"suite_failures":failures},"\t")+"\n")
	file.close()
	observed.clear()
	print("Teardown audit: ",counts,"; still alive: ",alive.size())
	quit(0 if failures.is_empty() and alive.is_empty() else 1)
