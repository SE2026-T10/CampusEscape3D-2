# Museum runtime meshes

Generated offline; original GLB/glTF files are unchanged. Rebuild from the repository root with the official Godot 4.7.2 executable:

```text
godot --headless --path . --script res://maps/isg_museum/tools/prepare_tree_lod.gd
godot --headless --path . --script res://maps/isg_museum/tools/prepare_art_assets.gd
godot --headless --path . --script res://maps/isg_museum/tools/prepare_display_base.gd
godot --headless --path . --script res://maps/isg_museum/tools/prepare_environment_modules.gd
```

| File | Adaptation | Triangles | License |
|---|---|---:|---|
| tree_small_02_near.scn | Godot meshoptimizer LOD, referenced vertices compacted | 18,589 | CC0 |
| tree_small_02_far.scn | Further reduced LOD | 577 | CC0 |
| shrub_04.scn | Repeated hedge foliage reduced | 2,287 | CC0 |
| potted_plant_01.scn | Repeated indoor plants reduced | 10,636 | CC0 |
| terpsichore.scn | Reduced sculpture; wrapper supplies lit stone | 28,605 | CC BY-SA 4.0 |
| display_case_base.scn | Only triangles below 48% of source height retained | 16 | CC BY 4.0 |

Tree near detail is below the initial 30–60k target. The far LOD is deliberately sparse; see the acceptance limitations in the implementation report. Runtime geometry never instances the original 2,062,487-triangle tree. Visibility changes at 19 m; no alpha fade overlap is used on Compatibility.

Gothic columns are normalized into `scenes/art/modules/gothic_column.tscn`. Arches, fountain basin, and balusters are selected by source mesh name during authoring. All parent transforms are retained, including the balustrade's reciprocal scales. Repeated stone visuals are combined into static ArrayMesh batches; their simple collision stays independent. This also preserves the geometry when authoring through the headless dummy renderer.

Terpsichore is an adaptation of **Glenn Gunhouse's** version of the Cleveland Museum of Art scan. The adapted mesh remains **CC BY-SA 4.0**, with the license retained in `TERPSICHORE-LICENSE.txt`. Source: [Terpsichore Lyran by Canova](https://sketchfab.com/3d-models/terpsichore-lyran-by-canova-aef74272b36a48a5a4e35189b048034c).

The display base is adapted from **Charlotte Kimberly Andreassen**, [Small Museum Display Case](https://sketchfab.com/3d-models/small-museum-display-case-bcc6c9850ce8455897196555418c6fa7), CC BY 4.0. Glass, shards and artifacts remain separate existing gameplay nodes.

Full source attribution, URLs, and adaptation notes: [ATTRIBUTION.md](../../../docs/environment-art-v1/ATTRIBUTION.md). Original asset metadata and licenses remain beside each source file. Reduction manifests are stored here and included in `resources/environment_art_manifest.json`.
