# Museum guard rig

Source: Low poly security guard by Jose Manuel, CC BY 4.0.
https://sketchfab.com/3d-models/low-poly-security-guard-abaf0f47b2c4413986919bb5c673face
https://creativecommons.org/licenses/by/4.0/

Derivative changes: metre/foot normalization (uniform 1.78/1.910836), anatomical A-pose landmarks, segment-distance smooth skin weights (up to 3 influences padded to 4), inverse global rest binds, baked A-to-T rest pose conversion. Original mesh topology, colours and accessories retained. Godot imports 4776 triangles plus one tiny two-segment line surface. The primitive type of that source surface is preserved (not converted to triangles). No X Bot geometry is included.

Rebuild from repository root with Godot 4.7.2:
`godot --headless --path . --script res://maps/isg_museum/tools/prepare_guard_assets.gd`
Validate read-only by adding `-- --check`.

The authoring tool builds the skeleton, weights, animation library, visual scene and map-local actor scene offline. It requires the original GLB plus reference_tpose.fbx and seven guard FBX clips already imported by Godot. No Blender, cloud autorigger or runtime .local dependency. Source files remain unchanged. Skeleton proportions are measured landmarks in build_skeleton(); bind_a is the source A pose, bind_t the target T rest. CPU verification skins actual vertices with the same inverse rest binds used by the renderer.
