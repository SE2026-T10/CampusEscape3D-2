# Coverage — Expanded Library layout v2

2026-10-10T19:20:51 · 4.7.2-stable (official) · 600 s game time at ×4 · 6 guards · 2473 samples on a 1.5 m grid · access doors open · no player

Watched = inside a guard's view cone and range with a clear line of sight to a standing (1.5 m) or crouched (0.85 m) head.

| Area | Floor | Samples | Ever seen | Safe (<5%) | Mean standing | Mean crouched | Peak | Longest watch (s) | Worst spot's longest gap (s) | Sprint heard |
|---|---|---|---|---|---|---|---|---|---|---|
| A · Lobby | ground | 168 | 100% | 0% | 18.6% | 17.5% | 32% | 15.2 | 15.0 | 58% |
| A · Porch | ground | 24 | 42% | 75% | 2.6% | 2.6% | 10% | 3.5 | 24.8 | 19% |
| B · Main Stacks | ground | 292 | 88% | 28% | 10.6% | 10.2% | 33% | 16.0 | 21.0 | 31% |
| B · Browsing Hall | ground | 168 | 100% | 18% | 14.6% | 14.2% | 30% | 12.5 | 27.5 | 35% |
| C · Reading Hall | ground | 240 | 94% | 81% | 3.6% | 3.4% | 25% | 11.2 | 26.2 | 16% |
| C · Study 1 | ground | 32 | 6% | 100% | 0.0% | 0.0% | 1% | 1.0 | 103.0 | 6% |
| C · Study 2 | ground | 32 | 6% | 100% | 0.0% | 0.0% | 1% | 1.0 | 102.8 | 0% |
| C · Study 3 | ground | 30 | 0% | 100% | 0.0% | 0.0% | 0% | 0.0 | 600.0 | 0% |
| C · Study 4 | ground | 32 | 0% | 100% | 0.0% | 0.0% | 0% | 0.0 | 600.0 | 3% |
| D · Service Corridor | ground | 111 | 7% | 97% | 0.3% | 0.3% | 8% | 3.0 | 30.5 | 9% |
| D · Book Processing | ground | 158 | 0% | 100% | 0.0% | 0.0% | 0% | 0.0 | 600.0 | 7% |
| D · Storage | ground | 126 | 0% | 100% | 0.0% | 0.0% | 0% | 0.0 | 600.0 | 0% |
| D · Loading Dock | ground | 116 | 0% | 100% | 0.0% | 0.0% | 0% | 0.0 | 600.0 | 0% |
| E · Upper Stacks | upper | 450 | 83% | 35% | 7.8% | 7.5% | 24% | 15.2 | 42.8 | 25% |
| E · Staff Balcony | upper | 139 | 99% | 54% | 4.7% | 4.4% | 10% | 8.0 | 31.5 | 18% |
| E · Staff Corridor | upper | 48 | 96% | 83% | 3.5% | 3.4% | 8% | 5.2 | 36.2 | 20% |
| E · Office 1 | upper | 36 | 8% | 100% | 0.1% | 0.1% | 3% | 2.8 | 97.5 | 2% |
| E · Office 2 | upper | 36 | 42% | 100% | 0.7% | 0.7% | 4% | 4.0 | 97.0 | 2% |
| E · Office 3 | upper | 36 | 11% | 100% | 0.3% | 0.3% | 4% | 3.8 | 100.2 | 11% |
| F · Archive Hall | upper | 79 | 87% | 30% | 10.1% | 9.7% | 23% | 10.2 | 27.0 | 44% |
| F · Archive Stacks | upper | 59 | 76% | 42% | 7.6% | 7.3% | 22% | 8.5 | 28.2 | 33% |
| F · Vault | upper | 29 | 41% | 97% | 1.1% | 1.1% | 6% | 2.5 | 35.2 | 11% |
| F · Alcove | upper | 16 | 75% | 38% | 9.3% | 8.4% | 19% | 7.2 | 28.8 | 20% |
| F · Staff Stair Landing | upper | 16 | 56% | 44% | 8.0% | 8.0% | 18% | 7.0 | 30.8 | 11% |

**Routes** (sampled every metre along the navmesh; 'exposed metres' = the sum of each metre's exposure, the expected number of watched metres on one pass):

| Route | Length | Mean exposure | Peak | Ever seen | Exposed metres |
|---|---|---|---|---|---|
| Main route | 197 m | 8.5% | 27% | 79% | 20.1 |
| Alternative: stacks stair to the staff wing | 106 m | 14.5% | 32% | 100% | 15.2 |
| Long way out without the shortcut (G2 → S1 → lobby → G4) | 119 m | 9.7% | 28% | 84% | 13.7 |
| Shortcut SC1 (one-way, corridor → reading hall) | 7 m | 0.2% | 1% | 20% | 0.0 |

**Doorways guards stand in** (within 1 m of the centre):

| Doorway | Type | Occupied | Longest stay (s) |
|---|---|---|---|
| Stacks Arch (Reading Hall) | arch | 0.6% | 0.8 |
| S1 Top | stair | 1.0% | 1.0 |
| Staff Door (Stacks) G1b | door | 1.0% | 1.0 |
| Staff Wing Door G1a | door | 0.7% | 0.8 |

Heat maps: `ground.png`, `upper.png` (dark green: never watched; green → yellow: up to 15% of the time; yellow → red: 15–50%+; black: walls, grey: openings).
