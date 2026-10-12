# Coverage — Expanded Library layout v3

2026-10-10T19:20:51 · 4.7.2-stable (official) · 600 s game time at ×4 · 6 guards · 2469 samples on a 1.5 m grid · access doors open · no player

Watched = inside a guard's view cone and range with a clear line of sight to a standing (1.5 m) or crouched (0.85 m) head.

| Area | Floor | Samples | Ever seen | Safe (<5%) | Mean standing | Mean crouched | Peak | Longest watch (s) | Worst spot's longest gap (s) | Sprint heard |
|---|---|---|---|---|---|---|---|---|---|---|
| A · Lobby | ground | 164 | 98% | 2% | 19.6% | 18.5% | 33% | 15.8 | 12.0 | 61% |
| A · Porch | ground | 24 | 12% | 100% | 0.3% | 0.3% | 3% | 0.8 | 28.2 | 1% |
| B · Main Stacks | ground | 292 | 75% | 44% | 6.8% | 6.6% | 22% | 14.5 | 48.8 | 19% |
| B · Browsing Hall | ground | 168 | 96% | 58% | 5.9% | 5.7% | 21% | 10.2 | 24.0 | 14% |
| C · Reading Hall | ground | 240 | 98% | 80% | 3.6% | 3.4% | 16% | 8.5 | 21.8 | 18% |
| C · Study 1 | ground | 32 | 6% | 100% | 0.0% | 0.0% | 1% | 1.0 | 102.8 | 7% |
| C · Study 2 | ground | 32 | 6% | 100% | 0.0% | 0.0% | 1% | 1.0 | 102.8 | 0% |
| C · Study 3 | ground | 30 | 0% | 100% | 0.0% | 0.0% | 0% | 0.0 | 600.0 | 0% |
| C · Study 4 | ground | 32 | 0% | 100% | 0.0% | 0.0% | 0% | 0.0 | 600.0 | 6% |
| D · Service Corridor | ground | 111 | 100% | 0% | 13.4% | 13.1% | 21% | 9.5 | 21.0 | 34% |
| D · Book Processing | ground | 158 | 11% | 96% | 0.4% | 0.4% | 9% | 5.0 | 50.5 | 10% |
| D · Storage | ground | 126 | 64% | 54% | 4.7% | 4.6% | 16% | 8.8 | 21.2 | 18% |
| D · Loading Dock | ground | 116 | 96% | 30% | 7.3% | 6.3% | 14% | 7.8 | 47.0 | 18% |
| E · Upper Stacks | upper | 450 | 83% | 36% | 7.9% | 7.7% | 22% | 14.8 | 48.0 | 24% |
| E · Staff Balcony | upper | 139 | 99% | 52% | 4.8% | 4.5% | 12% | 8.0 | 27.5 | 18% |
| E · Staff Corridor | upper | 48 | 96% | 83% | 3.4% | 3.3% | 8% | 5.2 | 37.2 | 20% |
| E · Office 1 | upper | 36 | 8% | 100% | 0.2% | 0.1% | 3% | 3.0 | 97.0 | 2% |
| E · Office 2 | upper | 36 | 42% | 100% | 0.7% | 0.7% | 4% | 4.0 | 99.8 | 2% |
| E · Office 3 | upper | 36 | 11% | 100% | 0.3% | 0.3% | 4% | 3.8 | 100.0 | 11% |
| F · Archive Hall | upper | 79 | 87% | 28% | 11.3% | 10.8% | 25% | 10.5 | 28.2 | 49% |
| F · Archive Stacks | upper | 59 | 75% | 44% | 8.5% | 8.1% | 28% | 10.8 | 28.0 | 33% |
| F · Vault | upper | 29 | 41% | 93% | 1.4% | 1.3% | 12% | 2.5 | 31.2 | 11% |
| F · Alcove | upper | 16 | 88% | 25% | 15.2% | 13.4% | 27% | 10.0 | 28.2 | 25% |
| F · Staff Stair Landing | upper | 16 | 50% | 50% | 5.6% | 5.5% | 14% | 5.5 | 33.2 | 8% |

**Routes** (sampled every metre along the navmesh; 'exposed metres' = the sum of each metre's exposure, the expected number of watched metres on one pass):

| Route | Length | Mean exposure | Peak | Ever seen | Exposed metres |
|---|---|---|---|---|---|
| Main route | 200 m | 11.2% | 35% | 88% | 27.0 |
| Alternative: stacks stair to the staff wing | 106 m | 12.5% | 35% | 100% | 13.3 |
| Long way out without the shortcut (G2 → S1 → lobby → G4) | 119 m | 14.1% | 35% | 100% | 20.4 |
| Way out through the back gate (the shortcut) | 67 m | 10.2% | 28% | 74% | 7.9 |
| Shortcut SC1 (one-way, corridor → reading hall) | 7 m | 10.4% | 14% | 100% | 1.0 |

**Doorways guards stand in** (within 1 m of the centre):

| Doorway | Type | Occupied | Longest stay (s) |
|---|---|---|---|
| Stacks Arch (Reading Hall) | arch | 0.7% | 1.0 |
| Storage Door | door | 1.6% | 1.0 |
| Dock Door | door | 0.5% | 0.2 |
| Storage–Dock Door | door | 0.6% | 0.5 |
| S1 Top | stair | 1.0% | 1.0 |
| Staff Door (Stacks) G1b | door | 1.0% | 1.0 |
| Staff Wing Door G1a | door | 0.9% | 1.0 |

Heat maps: `ground.png`, `upper.png` (dark green: never watched; green → yellow: up to 15% of the time; yellow → red: 15–50%+; black: walls, grey: openings).
