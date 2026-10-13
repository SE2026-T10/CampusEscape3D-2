# Performance — release 1.1.0 (both maps)

Measured with `tools/benchmark.gd`, the Phase 13 benchmark, which now takes `--level=tutorial|expanded`. The tutorial's scenarios and camera loop are unchanged; the Expanded Library has its own camera loop (the mission's main route: up S1, through the staff wing and the archive, down S2 and back through the lobby) and noise points on both floors.

| Scenario | Tutorial | Expanded Library |
|---|---|---|
| normal | 3 guards (the level's own) | 6 guards (the level's own) |
| stress | 24 guards (3 own + 21 extra on the level's routes) | 24 guards (6 own + 18 extra on the level's routes) |

In both: a fixed camera loop at walking height, a RUN noise every 4 s at the next of a fixed list of points (guards investigate: AI and navigation work, not just patrolling), 5 s warm-up, 30 s measured, vsync off.

## Results on the development VM (this release, commit 484761d + this phase's tool changes)

**Machine:** Linux VM (Ubuntu 24.04), 2 vCPUs (Intel Xeon @ 2.10 GHz), **no GPU**: rendering by Mesa llvmpipe (software OpenGL). 1280×720, Compatibility renderer (OpenGL 3.3), Godot 4.7.2 debug build (the editor binary). Runs in `vm/render/` and `vm/headless/`.

**These frame rates say nothing about real hardware**: llvmpipe rasterises on the CPU. What does transfer: the comparison between the two maps on the same machine, the draw calls and objects, and the headless CPU cost.

| Run | Guards | Avg FPS | 1% low | Frame ms mean / p95 | Render CPU ms | Scripts ms (physics + process) | Guard AI ms per frame | Draw calls | Objects | Primitives |
|---|---|---|---|---|---|---|---|---|---|---|
| tutorial normal | 3 | 9.3 | 5.1 | 107.2 / 147.1 | 94.1 | 1.43 + 0.55 | 0.57 | 302 | 677 | 28,598 |
| **expanded normal** (r1, r2) | 6 | **8.9, 8.6** | 5.7, 4.9 | 112.0 / 141.9, 116.7 / 153.0 | 98.5, 102.0 | 1.97 + 0.64 | 0.90 | 341 | 734 | 26,472 |
| tutorial stress | 24 | 8.5 | 6.0 | 118.1 / 152.7 | 96.2 | 5.17 + 0.82 | 3.21 | 600 | 991 | 32,501 |
| **expanded stress** (r1, r2) | 24 | **7.9, 7.8** | 5.9, 5.5 | 127.2 / 155.9, 128.5 / 167.7 | 104.6, 105.9 | 5.75 + 0.94 | 3.59 | 550 | 955 | 29,463 |

**CPU only** (headless, `--fixed-fps 60`: one physics tick per frame, no rendering; the whole cost of game logic, physics and navigation):

| Run | Guards | CPU frame ms mean / p95 | Guard AI ms per tick | Stuck events |
|---|---|---|---|---|
| tutorial normal | 3 | 0.81 / 1.28 | 0.076 | 0 |
| expanded normal | 6 | 1.34 / 1.93 | 0.150 | 0 |
| tutorial stress | 24 | 2.52 / 3.48 | 0.434 | 1 |
| expanded stress | 24 | 2.50 / 3.34 | 0.429 | 0 |

**Findings:**
- On the same machine the Expanded Library renders at about 93% of the tutorial's frame rate (normal 8.6–8.9 vs 9.3 FPS; stress 7.8–7.9 vs 8.5), with a similar number of draw calls (341 vs 302 normal; 550 vs 600 stress) and fewer primitives along the camera loop. Rendering is about 90% of the frame in both maps.
- Game logic stays cheap: 24 guards cost 2.5 ms of CPU per frame in either map; the Expanded Library's 6 guards cost 1.3 ms.
- Memory is flat over each run (static memory growth ≤ 0.8 MB).
- **Stuck events:** in the rendered stress runs of the Expanded Library, one added benchmark guard on the floor-changing connector route (BenchGuard06) was held up three times at the foot of the main stair and on it, where the lobby route's four guards and the connector's two cross, and each time moved on to its next point after 5 s (the guard's built-in recovery). This is the known shared-route limitation (README, Known limitations: guards sharing one route can block each other at a narrow spot for about 5 s); the level itself has one guard per route, and its six guards had 0 stuck events in every run here and in the 900 s soaks of `docs/expanded/v2/` and later. The tutorial stress run shows the same effect once (as in Phase 13).
- No optimisation was made in this phase. The Phase 6 optimisations (batching the decoration, light budgets, book draw distance, fewer shadow casters, 40 m shadow distance) were measured in `docs/expanded/v4/profile/`.

## Targets: about 60 FPS normal, at least 45 FPS stress — on Windows

**Not measured yet for this release.** The targets are for the target hardware, and no measurement on Windows was possible from this environment. The reference from the v1.0.0 validation (same laptop, tutorial only, `docs/performance/windows/`): **202.8 FPS normal, 153.2 FPS stress** (Windows 10, i5-8265U, MX130, 1280×720, debug build). On the VM, the tutorial ran at about 11.6 FPS in Phase 13 and 9.3 here: the VM is a poor predictor of the GPU, so the Expanded Library needs its own Windows runs.

**How to run them** (from the project folder, with the Godot editor on the laptop, `D:\godot4\godot_v4.7.2-stable_win64.exe`, or its `_console` twin for a console window). Each takes about 40 s; the results go into this folder:

```
D:\godot4\godot_v4.7.2-stable_win64.exe --path . --resolution 1280x720 --script res://tools/benchmark.gd -- --level=expanded --scenario=normal --out=docs/performance/release_1_1/windows/render/expanded_normal_r1
D:\godot4\godot_v4.7.2-stable_win64.exe --path . --resolution 1280x720 --script res://tools/benchmark.gd -- --level=expanded --scenario=stress --out=docs/performance/release_1_1/windows/render/expanded_stress_r1
D:\godot4\godot_v4.7.2-stable_win64.exe --path . --resolution 1280x720 --script res://tools/benchmark.gd -- --level=tutorial --scenario=normal --out=docs/performance/release_1_1/windows/render/tutorial_normal_r1
D:\godot4\godot_v4.7.2-stable_win64.exe --path . --resolution 1280x720 --script res://tools/benchmark.gd -- --level=tutorial --scenario=stress --out=docs/performance/release_1_1/windows/render/tutorial_stress_r1
```

Each run writes `summary.json` (`fps_avg`, `fps_1pct_low`, the per-metric means and percentiles, the OS, CPU, GPU, resolution and build) and `frames.csv`. Pass: `fps_avg` ≥ about 60 in `expanded_normal`, ≥ 45 in `expanded_stress`.
