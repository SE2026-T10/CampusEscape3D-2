# Museum runtime meshes

Generated offline; original GLB/glTF files are unchanged. Rebuild from the repository root with the official Godot 4.7.2 executable:

```text
godot --headless --path . --script res://maps/isg_museum/tools/prepare_courtyard_materials.gd
godot --path . --rendering-method gl_compatibility --script res://maps/isg_museum/tools/bake_tree_leaf_clusters.gd
godot --headless --path . --editor --quit
godot --headless --path . --script res://maps/isg_museum/tools/prepare_tree_lod.gd
godot --headless --path . --script res://maps/isg_museum/tools/prepare_art_assets.gd
godot --headless --path . --script res://maps/isg_museum/tools/prepare_display_base.gd
godot --headless --path . --script res://maps/isg_museum/tools/prepare_environment_modules.gd
```

| File | Adaptation | Triangles | License |
|---|---|---:|---|
| tree_small_02_near.scn | Native wood LOD + curved source leaf clusters | 42,820 | CC0 |
| tree_small_02_mid.scn | Same clusters, reduced curvature and wood LOD | 11,384 | CC0 |
| tree_small_02_far.scn | Same clusters, coarse curvature and wood LOD | 3,189 | CC0 |
| shrub_04.scn | Repeated hedge foliage reduced | 2,287 | CC0 |
| potted_plant_01.scn | Repeated indoor plants reduced | 10,636 | CC0 |
| terpsichore.scn | Reduced sculpture; wrapper supplies lit stone | 28,605 | CC BY-SA 4.0 |
| display_case_base.scn | Only triangles below 48% of source height retained | 16 | CC BY 4.0 |

Tree budgets and transition distances come from `resources/environment_art_layout.json`. Near/mid/far change at 18/26 m; no alpha fade overlap is used on Compatibility. All levels use identical source bounds, uniform scale and base-center anchor. Runtime geometry never instances the original 2,062,487-triangle tree.

`tree_leaf_clusters.png` is an offline Godot bake of the original CC0 Tree Small 02 leaves: 39 occupied spatial cells, three orthographic views per cell, 117 tiles in a 2048×1024 atlas. `tree_leaf_clusters.json` records the centers, view axes and UV tiles. The original native leaf LOD jumps from 177,711 to 16,075 triangles and loses canopy coverage. Curved cards retain every occupied cluster at all three levels; their curvature and the independent trunk/branch meshes consume the configured budgets. The full source is instantiated only by the offline baker. Source files and textures remain unchanged.

Hedge foliage uses the CC0 Shrub 04 leaf UV island on folded leaves, plus a recessed fill and the existing reduced shrub branches. It does not use the tree atlas as an opaque surface. The visible shell stays inside the existing 1.2 m cover envelope.

The cream stone albedo in `assets/materials/textures/derived/` is a low-contrast tint of the existing CC0 Marble012 texture. The two courtyard presets retain its normal and roughness maps at a gentle strength; they remain lit. See [v1.1 evidence](../../../docs/environment-art-v1_1/REPORT.md).

Gothic columns are normalized into `scenes/art/modules/gothic_column.tscn`. Arches, fountain basin, and balusters are selected by source mesh name during authoring. All parent transforms are retained, including the balustrade's reciprocal scales. Repeated stone visuals are combined into static ArrayMesh batches; their simple collision stays independent. This also preserves the geometry when authoring through the headless dummy renderer.

Terpsichore is an adaptation of **Glenn Gunhouse's** version of the Cleveland Museum of Art scan. The adapted mesh remains **CC BY-SA 4.0**, with the license retained in `TERPSICHORE-LICENSE.txt`. Source: [Terpsichore Lyran by Canova](https://sketchfab.com/3d-models/terpsichore-lyran-by-canova-aef74272b36a48a5a4e35189b048034c).

The display base is adapted from **Charlotte Kimberly Andreassen**, [Small Museum Display Case](https://sketchfab.com/3d-models/small-museum-display-case-bcc6c9850ce8455897196555418c6fa7), CC BY 4.0. Glass, shards and artifacts remain separate existing gameplay nodes.

Full source attribution, URLs, and adaptation notes: [ATTRIBUTION.md](../../../docs/environment-art-v1/ATTRIBUTION.md). Original asset metadata and licenses remain beside each source file. Reduction manifests are stored here and included in `resources/environment_art_manifest.json`.
