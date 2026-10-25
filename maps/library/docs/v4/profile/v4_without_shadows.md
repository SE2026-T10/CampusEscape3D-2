# Expanded Library — rendering profile (v4) — diagnostics: without shadows

`tools/expanded/profile_expanded.gd`, 2026-10-11T20:47:28, renderer opengl3, llvmpipe (LLVM 20.1.2, 256 bits), window (1280.0, 720.0). Load time: 1066 ms. 20 viewpoints × 120 frames (after 30 warm-up), guards patrolling.

**All views:** mean frame 131.32 ms (8 FPS), 95th percentile 209.18 ms; draw calls mean 283, max 626.

| View | Frame ms (mean) | Frame ms (p95) | Draw calls (mean) | Draw calls (max) | Objects | Primitives |
|---|---|---|---|---|---|---|
| 01_porch | 140.99 | 168.70 | 626 | 626 | 1000 | 43424 |
| 02_lobby | 124.02 | 151.23 | 482 | 482 | 856 | 34928 |
| 03_lobby_stair_S1 | 113.47 | 132.51 | 434 | 446 | 808 | 26789 |
| 04_browsing_hall | 99.50 | 113.96 | 211 | 212 | 585 | 11576 |
| 05_main_stacks | 222.32 | 260.11 | 137 | 147 | 511 | 244838 |
| 06_reading_hall | 151.65 | 174.73 | 392 | 412 | 766 | 54110 |
| 07_study_room | 129.29 | 151.75 | 93 | 93 | 467 | 15272 |
| 08_service_corridor | 159.54 | 190.69 | 531 | 547 | 905 | 55207 |
| 09_storage_S2 | 102.69 | 119.31 | 103 | 119 | 477 | 9243 |
| 10_dock_exit | 104.96 | 128.32 | 49 | 49 | 423 | 4584 |
| 11_balcony | 112.57 | 134.86 | 368 | 386 | 742 | 27522 |
| 12_lobby_from_balcony | 98.64 | 110.55 | 167 | 167 | 541 | 16904 |
| 13_upper_stacks | 204.77 | 237.37 | 130 | 152 | 504 | 242501 |
| 14_staff_corridor | 125.04 | 147.62 | 329 | 345 | 703 | 22331 |
| 15_office_card | 119.25 | 134.13 | 107 | 118 | 481 | 15620 |
| 16_archive_hall | 146.11 | 182.46 | 593 | 605 | 967 | 52805 |
| 17_archive_stacks | 135.92 | 159.27 | 113 | 122 | 487 | 46767 |
| 18_vault_manuscript | 96.61 | 111.58 | 39 | 39 | 413 | 3964 |
| 19_back_gate_landing | 138.60 | 166.05 | 578 | 588 | 952 | 58125 |
| 20_down_S2 | 100.49 | 115.06 | 173 | 181 | 547 | 10096 |
