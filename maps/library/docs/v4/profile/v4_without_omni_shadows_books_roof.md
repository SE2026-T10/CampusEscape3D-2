# Expanded Library — rendering profile (v4) — diagnostics: without omni, shadows, books, roof

`tools/expanded/profile_expanded.gd`, 2026-10-11T20:59:11, renderer opengl3, llvmpipe (LLVM 20.1.2, 256 bits), window (1280.0, 720.0). Load time: 950 ms. 20 viewpoints × 120 frames (after 30 warm-up), guards patrolling.

**All views:** mean frame 66.78 ms (15 FPS), 95th percentile 87.25 ms; draw calls mean 280, max 620.

| View | Frame ms (mean) | Frame ms (p95) | Draw calls (mean) | Draw calls (max) | Objects | Primitives |
|---|---|---|---|---|---|---|
| 01_porch | 77.80 | 89.81 | 620 | 620 | 994 | 34940 |
| 02_lobby | 66.85 | 79.74 | 474 | 475 | 848 | 26401 |
| 03_lobby_stair_S1 | 67.53 | 79.49 | 456 | 461 | 830 | 25465 |
| 04_browsing_hall | 54.58 | 64.31 | 190 | 190 | 564 | 9716 |
| 05_main_stacks | 68.02 | 77.63 | 128 | 128 | 502 | 6704 |
| 06_reading_hall | 78.65 | 90.83 | 406 | 408 | 780 | 22144 |
| 07_study_room | 71.19 | 89.52 | 102 | 109 | 476 | 7415 |
| 08_service_corridor | 82.97 | 93.87 | 544 | 550 | 918 | 28474 |
| 09_storage_S2 | 57.14 | 66.40 | 105 | 115 | 479 | 7684 |
| 10_dock_exit | 42.78 | 50.52 | 44 | 44 | 418 | 2928 |
| 11_balcony | 62.85 | 73.20 | 400 | 400 | 774 | 23446 |
| 12_lobby_from_balcony | 57.04 | 65.70 | 172 | 176 | 546 | 8524 |
| 13_upper_stacks | 53.05 | 64.41 | 99 | 110 | 473 | 6805 |
| 14_staff_corridor | 79.48 | 94.62 | 312 | 321 | 686 | 20516 |
| 15_office_card | 70.24 | 80.42 | 109 | 116 | 483 | 7684 |
| 16_archive_hall | 75.41 | 86.00 | 593 | 595 | 967 | 32210 |
| 17_archive_stacks | 58.81 | 73.00 | 100 | 116 | 474 | 7370 |
| 18_vault_manuscript | 57.52 | 64.90 | 39 | 41 | 413 | 2414 |
| 19_back_gate_landing | 83.24 | 100.19 | 552 | 579 | 926 | 31314 |
| 20_down_S2 | 70.52 | 83.01 | 161 | 174 | 535 | 9843 |
