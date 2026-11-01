# Surface detail textures

Eight grey, tileable 512 px textures made in code for this project by `maps/library/tools/expansion/make_surface_textures.py` (no third-party images): terrazzo, plaster, wood_grain, wood_planks, carpet_weave, speckle, concrete, stone_blocks.

The surface detail shader (`maps/library/assets/materials/surface_detail.gdshader`) multiplies a batched box's colour by one of them, divided by the texture's mean, so the approved colours stay and only fine detail is added. Which colour, faces and area get which texture is set in `maps/library/tools/expansion/make_surface_detail.gd`, which writes `surface_detail.tres`.

To change a texture: edit the script, run it, update the texture's mean in `make_surface_detail.gd` and run that tool.
