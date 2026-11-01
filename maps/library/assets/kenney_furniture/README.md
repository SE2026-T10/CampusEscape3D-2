# Kenney Furniture Kit 2.0 (CC0)

31 models (`.glb`) from Kenney's Furniture Kit 2.0, <https://kenney.nl/assets/furniture-kit>, under CC0 1.0 (see `License.txt`, Kenney's own file). Credits: `CREDITS.md` at the project root.

Build input only. The folder's `.gdignore` keeps Godot from importing the files. `maps/library/tools/expansion/build_expansion.gd` (`_kenney`, `_kp`, `KENNEY_LOOKS`) reads them, places them at 2× scale (Kenney's models are half size), colours them with the map's looks and saves the merged meshes into `maps/library/scenes/expanded_library_expansion.tscn`. To use another model of the kit, copy its `.glb` from the kit's `Models/GLTF format` folder here and rebuild the expansion.

Used in the staff offices, balcony and corridor, the lobby and porch, the reading and browsing halls, book processing, the study rooms, the loading dock, storage, the west landing and the restricted archive: benchCushion, bookcaseClosed, bookcaseClosedDoors, bookcaseClosedWide, bookcaseOpen, books, cardboardBoxClosed, cardboardBoxOpen, chairCushion, chairDesk, coatRackStanding, computerKeyboard, computerMouse, computerScreen, kitchenCoffeeMachine, kitchenMicrowave, lampRoundFloor, lampRoundTable, lampSquareFloor, laptop, loungeChair, loungeSofa, plantSmall1, plantSmall2, plantSmall3, pottedPlant, rugRectangle, sideTableDrawers, tableCoffee, tableRound, trashcan.
