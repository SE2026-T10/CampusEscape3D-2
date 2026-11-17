# Museum guard animations

Derived from the seven guard clips supplied from Adobe Mixamo; the original FBX files and their Adobe Mixamo terms remain in ../LICENSE.txt and ../source.json. Not a standalone redistribution license for the original Mixamo assets.

Generated offline by tools/prepare_guard_assets.gd in Godot 4.7.2. Reference is X Bot mixamo_com T pose, not Take 001. No X Bot meshes are exported. Local rest quaternion correction and target rest positions handle changed proportions; there is one target skeleton per actor. Walk/run retain vertical hip motion and remove XZ motion. Sit/stand also keep the horizontal chair anchor fixed. All local positional offsets are adjusted rather than deleting tracks. Last loop key matches first key. Sleep derives from sitting_idle with periodic neck/head and upper-spine nod. RESET records target local rests.

The scene AnimationPlayer owns playback with 0.18?0.20 s crossfade. AnimationTree is supplied as an inactive authoring graph to avoid double evaluation. Source travel/duration gives measured nominal playback speeds in resources/guard_animation_manifest.json. G3 transitions are interruptible by actual movement/chase, never gate AI and never write actor transforms or perception.
