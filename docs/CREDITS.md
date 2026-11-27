# Credits

Third-party assets used in Campus Escape 3D.

| Asset | Author | Licence | Source | Used in |
|---|---|---|---|---|
| Furniture Kit 2.0 | Kenney ([www.kenney.nl](https://www.kenney.nl)) | [CC0 1.0](http://creativecommons.org/publicdomain/zero/1.0/) | [kenney.nl/assets/furniture-kit](https://kenney.nl/assets/furniture-kit) | Expanded Library: 31 of the kit's 140 models, in `maps/library/assets/kenney_furniture/` (with the kit's `License.txt`) |

| Kalam (Regular, Bold) | Indian Type Foundry | [SIL Open Font License 1.1](https://openfontlicense.org) | [Google Fonts](https://fonts.google.com/specimen/Kalam), [github.com/google/fonts/tree/main/ofl/kalam](https://github.com/google/fonts/tree/main/ofl/kalam) | Expanded Library: the handwriting of the mission note (`shared/scripts/ui/paper_note.gd`), in `shared/assets/fonts/kalam/` (with the licence, `OFL.txt`) |

CC0 asks for no attribution; Kenney is credited here anyway. The OFL lets the font be bundled with the game; it may not be sold on its own, and its licence file stays with it.

The Kenney models are build input only: `maps/library/tools/expansion/build_expansion.gd` reads them, recolours them with the map's own colours and merges them into `maps/library/scenes/expanded_library_expansion.tscn`. Their folder has a `.gdignore`, so the editor does not import them and the exported game does not contain the original files.

## Made for this project

| Asset | Made by | Where |
|---|---|---|
| Surface detail textures (terrazzo, plaster, wood grain, wood planks, carpet weave, speckle, concrete, stone blocks) | generated in code by `maps/library/tools/expansion/make_surface_textures.py` | `maps/library/assets/textures/surface/`, used by `maps/library/assets/materials/surface_detail.tres` |
