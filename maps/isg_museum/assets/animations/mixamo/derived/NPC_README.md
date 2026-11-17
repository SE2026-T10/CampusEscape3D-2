# Museum civilian NPC animation library

Uses the existing Jose Manuel CC BY 4.0 guard rig/skin without rebuilding it. Original model attribution is in models/characters/low_poly_security_guard/source.json. Animation sources are Adobe Mixamo npc_talking.fbx and receptionist_talking.fbx, take mixamo_com. Original FBX files and their terms remain unchanged; see ../LICENSE.txt.

Rebuild: Godot 4.7.2 --headless --path . --script res://maps/isg_museum/tools/prepare_npc_assets.gd
Read-only validation: same command with -- --check.
Then run build_contract_teammate.gd and build_service.gd. Main museum scene keeps the same scene instances and interaction roots.

The NPC preparer inherits only the converter API of prepare_guard_assets.gd and never invokes its rigging/save pipeline. It sets target to the saved guard skeleton and reuses the same local-rest correction, target translations and fixed-XZ hips rule. Standing/seated idle and RESET are immutable shared animations. Talking clips are separate resources in npc_animations.res. Reception talking keeps the source seated legs/vertical movement and matches mean hips height to seated_idle. The last 0.35 seconds blends to the first pose for looping. At runtime one AnimationPlayer owns playback with 0.2-second blends. A SkeletonModifier3D adds limited head/chest watch after playback without rotating hips or interaction actors.

Materials are privately duplicated only for shirt, vest and trousers; face/skin and source mesh/skin remain shared. Two detached held-weapon meshes are hidden for civilian roles. Guard materials/resources remain unchanged. Role anchors are documented in npc_animation_manifest.json and authored by the two map builders.
