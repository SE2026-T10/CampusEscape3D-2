# Kenney Furniture Kit 2.0 (CC0)

27 models (`.glb`) from Kenney's Furniture Kit 2.0, <https://kenney.nl/assets/furniture-kit>, under CC0 1.0 (see `License.txt`, Kenney's own file). Credits: `CREDITS.md` at the project root.

Build input only. The folder's `.gdignore` keeps Godot from importing the files. `maps/library/tools/expansion/build_expansion.gd` (`_kenney`, `_kp`, `KENNEY_LOOKS`) reads them, places them at 2× scale (Kenney's models are half size), colours them with the map's looks and saves the merged meshes into `maps/library/scenes/expanded_library_expansion.tscn`. To use another model of the kit, copy its `.glb` from the kit's `Models/GLTF format` folder here and rebuild the expansion.

Used in the staff offices and the lobby: benchCushion, bookcaseClosed, bookcaseClosedDoors, bookcaseClosedWide, bookcaseOpen, books, cardboardBoxClosed, cardboardBoxOpen, chairCushion, chairDesk, coatRackStanding, computerKeyboard, computerMouse, computerScreen, kitchenCoffeeMachine, lampRoundTable, lampSquareFloor, laptop, loungeChair, loungeSofa, plantSmall2, pottedPlant, rugRectangle, sideTableDrawers, tableCoffee, tableRound, trashcan.
