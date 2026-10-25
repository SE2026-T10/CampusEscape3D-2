# Expanded Library — rendering profile (v4) — diagnostics: without books

`tools/expanded/profile_expanded.gd`, 2026-10-11T20:55:49, renderer opengl3, llvmpipe (LLVM 20.1.2, 256 bits), window (1280.0, 720.0). Load time: 1022 ms. 20 viewpoints × 120 frames (after 30 warm-up), guards patrolling.

**All views:** mean frame 166.23 ms (6 FPS), 95th percentile 200.52 ms; draw calls mean 406, max 874.

| View | Frame ms (mean) | Frame ms (p95) | Draw calls (mean) | Draw calls (max) | Objects | Primitives |
|---|---|---|---|---|---|---|
| 01_porch | 178.41 | 200.52 | 836 | 854 | 1210 | 42904 |
| 02_lobby | 158.10 | 171.26 | 667 | 700 | 1041 | 35392 |
| 03_lobby_stair_S1 | 159.52 | 179.44 | 604 | 636 | 978 | 33580 |
| 04_browsing_hall | 145.85 | 166.43 | 308 | 311 | 682 | 14126 |
| 05_main_stacks | 168.42 | 193.91 | 187 | 187 | 561 | 10280 |
| 06_reading_hall | 188.22 | 215.50 | 631 | 668 | 1005 | 31776 |
| 07_study_room | 179.47 | 199.66 | 162 | 171 | 536 | 15386 |
| 08_service_corridor | 194.10 | 216.63 | 768 | 799 | 1142 | 38762 |
| 09_storage_S2 | 156.64 | 177.52 | 137 | 137 | 511 | 11628 |
| 10_dock_exit | 155.67 | 180.44 | 72 | 109 | 446 | 5075 |
| 11_balcony | 163.38 | 196.21 | 583 | 605 | 957 | 33223 |
| 12_lobby_from_balcony | 147.12 | 170.78 | 245 | 266 | 619 | 12628 |
| 13_upper_stacks | 146.73 | 167.67 | 159 | 192 | 533 | 10383 |
| 14_staff_corridor | 177.41 | 199.18 | 479 | 493 | 853 | 29273 |
| 15_office_card | 171.22 | 194.33 | 181 | 201 | 555 | 13820 |
| 16_archive_hall | 180.67 | 206.28 | 832 | 874 | 1206 | 43051 |
| 17_archive_stacks | 157.26 | 181.30 | 196 | 209 | 570 | 13644 |
| 18_vault_manuscript | 150.23 | 171.34 | 54 | 54 | 428 | 5140 |
| 19_back_gate_landing | 193.45 | 230.13 | 781 | 800 | 1155 | 41272 |
| 20_down_S2 | 152.73 | 176.08 | 230 | 243 | 604 | 13268 |
