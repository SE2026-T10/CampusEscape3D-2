# Expanded Library — rendering profile (v4) — diagnostics: without omni

`tools/expanded/profile_expanded.gd`, 2026-10-11T20:40:52, renderer opengl3, llvmpipe (LLVM 20.1.2, 256 bits), window (1280.0, 720.0). Load time: 1017 ms. 20 viewpoints × 120 frames (after 30 warm-up), guards patrolling.

**All views:** mean frame 148.55 ms (7 FPS), 95th percentile 231.15 ms; draw calls mean 406, max 881.

| View | Frame ms (mean) | Frame ms (p95) | Draw calls (mean) | Draw calls (max) | Objects | Primitives |
|---|---|---|---|---|---|---|
| 01_porch | 142.58 | 159.66 | 837 | 855 | 1211 | 49697 |
| 02_lobby | 143.57 | 176.15 | 668 | 701 | 1042 | 42184 |
| 03_lobby_stair_S1 | 141.87 | 162.91 | 604 | 636 | 978 | 33579 |
| 04_browsing_hall | 124.55 | 140.49 | 307 | 311 | 681 | 14123 |
| 05_main_stacks | 240.40 | 283.18 | 203 | 203 | 577 | 246908 |
| 06_reading_hall | 156.80 | 200.15 | 637 | 671 | 1011 | 62426 |
| 07_study_room | 126.65 | 147.61 | 161 | 172 | 535 | 21784 |
| 08_service_corridor | 154.08 | 180.10 | 774 | 803 | 1148 | 64004 |
| 09_storage_S2 | 124.48 | 151.75 | 137 | 137 | 511 | 11628 |
| 10_dock_exit | 107.91 | 118.04 | 60 | 92 | 434 | 4931 |
| 11_balcony | 135.27 | 152.46 | 582 | 606 | 956 | 36086 |
| 12_lobby_from_balcony | 127.60 | 148.03 | 256 | 267 | 630 | 19549 |
| 13_upper_stacks | 229.88 | 268.11 | 141 | 172 | 515 | 243905 |
| 14_staff_corridor | 144.56 | 163.55 | 483 | 530 | 857 | 29322 |
| 15_office_card | 128.22 | 154.51 | 182 | 202 | 556 | 20260 |
| 16_archive_hall | 167.47 | 186.23 | 854 | 881 | 1228 | 62232 |
| 17_archive_stacks | 164.76 | 190.09 | 178 | 191 | 552 | 51121 |
| 18_vault_manuscript | 125.33 | 146.85 | 54 | 54 | 428 | 5140 |
| 19_back_gate_landing | 152.55 | 174.05 | 774 | 804 | 1148 | 66062 |
| 20_down_S2 | 132.46 | 154.01 | 231 | 251 | 605 | 13279 |
