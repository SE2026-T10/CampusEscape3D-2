# Phase 13 — Performance Profiling and Optimisation

This phase added a reproducible benchmark, measured the game in three scenarios, found where the time goes, and made two rendering changes that the measurements justified.

**Read this first: every number here comes from one Linux cloud VM with no GPU.** The game was rendered by Mesa llvmpipe, a software OpenGL rasteriser. That makes rendering far slower, and fill-rate bound in a way a real GPU isn't, so the absolute frame rates say nothing about the Windows target. The CPU-side figures (game logic, physics, navigation) and the draw-call and object counts transfer much better. **No Windows measurement was made.** How to make one is under "Manual verification still required".

## Correction (Phase 14 QA pass)

The QA pass found a bug in the first version of the benchmark: with 13 or more guards, some extra guards started at exactly the same spot as one of the level's own guards. Each such pair blocked each other, and the "stuck" fallback fired again and again.

This affected:
- the stress runs (24 guards);
- the CPU scaling runs for 16–48 guards.

The tool now gives every extra guard its own start slot. Those runs were re-measured with the fixed tool: "before" on the pre-optimisation commit, in a separate worktree, and "after" on the current code. They are in `docs/performance/stress_rerun/` and `after_2splits_2048/cpu_scaling/`, and the stress and scaling figures on this page are the corrected ones.

The conclusions are unchanged: rendering dominates, and the optimisation gives about +35% FPS in the stress scenario. The normal and several scenarios were not affected. The old stress runs are kept in `baseline/`, `after_2splits/` and `after_2splits_2048/`, but are superseded; the intermediate "2 cascades" stage was not re-measured for stress.

## Test setup

| Item | Value |
|---|---|
| Hardware | Intel Xeon @ 2.10 GHz (KVM virtual machine), 2 vCPUs, 8 GB RAM, **no GPU** |
| GPU / renderer | Mesa llvmpipe (LLVM 20.1.2, 256-bit), software OpenGL, under Xvfb; Godot's Compatibility (OpenGL) renderer, the project's setting |
| OS | Ubuntu 24.04 (Linux) |
| Godot | 4.7.2.stable.official.ed1daf0bf |
| Build | the editor binary running the project, so a debug build (`OS.is_debug_build()` true); not an exported release build |
| Resolution | 1280×720 window; one diagnostic run at 640×360 |
| Vsync / frame cap | vsync off, `Engine.max_fps = 0` |
| Test scene | `scenes/level/library_graybox.tscn` (the real level), started by `tools/benchmark.gd` |
| NPC counts | normal 3 (the level's guards), several 8, stress 24; CPU scaling also at 16, 32 and 48 |
| Repeats | rendering: normal ×3, several ×2, stress ×2 per stage; headless: ×3 per scenario and stage |
| Run length | 30 s measured after 5 s warm-up (simulated time); diagnostics 20 s |

## The benchmark (`tools/benchmark.gd`)

```
# rendering (a window): what a player gets
godot --path . --resolution 1280x720 --script res://tools/benchmark.gd -- --scenario=normal --out=docs/performance/my_run
# CPU only: no rendering, exactly one physics tick per frame, as fast as possible
godot --headless --fixed-fps 60 --path . --script res://tools/benchmark.gd -- --scenario=stress --out=docs/performance/my_run
```

Options:
- `--scenario=normal|several|stress`
- `--npcs=N`
- `--seconds`, `--warmup`
- `--label`
- `--disable=…` — diagnostic switches; see the script header

**The scenario is the same every run:**
- The player stands at the spawn with no input.
- Extra guards are spread along the level's three patrol routes.
- A benchmark camera flies a fixed loop through every room, driven by simulated time, so every run sees the same path.
- A RUN noise is emitted every 4 s at the next of six fixed points, so guards investigate. This gives navigation and AI work, not just patrolling.
- No run ended with a guard catching the player.

**What is measured, every frame:**

| Measure | How |
|---|---|
| Frame time, FPS | wall clock between frames; average FPS = frames ÷ time; 1% low = 1000 ÷ 99th-percentile frame time |
| Script CPU time | timing probes at the lowest and highest processing priority, around every other node's `_physics_process` (per physics tick, summed per frame) and `_process` |
| Guard AI cost | guards and their Vision and Hearing nodes are put in their own priority band, with probes around it. This covers state machine, perception, raycasts and path following. |
| Guard animation cost | the same, around GuardPresentation and its AnimationPlayer |
| Render CPU / GPU time | `RenderingServer.viewport_get_measured_render_time_cpu/gpu` + frame setup time. On llvmpipe the "GPU" timer is also CPU work. |
| Other | frame − scripts − render CPU: the physics engine step, navigation (including the avoidance callbacks, where guards call `move_and_slide`), scene tree and sync |
| Rendering counts | draw calls, objects and primitives in the frame |
| Memory | static memory, video memory (as Godot reports it), object, node and orphan-node counts |
| Physics / navigation | active bodies, collision pairs, navigation agents; Godot's own process / physics / navigation time monitors (these are the slowest frame of the last second, so they are a cross-check only) |
| NPCs | guard count, guards moving each frame |

**Effects of the tool itself:**
- Samples go into one array allocated before measuring starts (7.7 MB, included in the static-memory figures), so the tool's storage doesn't grow during the run.
- Moving guards into their own priority band shifts them by at most one tick relative to other scripts.

**Outputs:**
- Each run writes `frames.csv` and `summary.json` (plus `screenshot.png` when rendering).
- `docs/performance/analyse.py` turns all runs into `docs/performance/results.md` and the charts (Python 3 + matplotlib, a developer tool only).

## Results before optimising: where the time goes

Normal gameplay (3 guards), rendering at 1280×720 on llvmpipe, mean of 3 runs:

| Part | ms per frame | Share |
|---|---|---|
| Rendering (CPU, which on llvmpipe does all the GPU work) | 109.1 | 91% |
| Other (physics engine, navigation, tree) | 12.5 | 10% |
| Scripts, physics ticks + process (all game logic, HUD, audio) | 1.7 | 1.4% |
| **Frame** | **119.6** (8.37 FPS, 1% low 5.59) | |

The shares add up to slightly more than 100% because "other" is clamped at zero per frame. The game was also running about 7 physics ticks per rendered frame, close to Godot's limit of 8, so on this machine the simulation was close to falling behind real time.

**CPU-only cost (headless, one physics tick per frame), mean of 3 runs:**

| Scenario | Guards | CPU ms per frame (mean / p95) | Guard AI ms per tick | Guard animation ms | Other ms |
|---|---|---|---|---|---|
| normal | 3 | 0.72 / 1.07 | 0.067 | 0.034 | 0.40 |
| several | 8 | 1.19 / 1.74 | 0.150 | 0.075 | 0.64 |
| stress | 24 | 2.33 / 3.31 | 0.381 | 0.204 | 1.26 |

The game logic is cheap. Even 48 guards cost 3.8 ms of CPU per frame (`chart_cpu_scaling.png`): roughly linear, about 0.014–0.02 ms per guard for AI plus perception. The largest CPU part is "other" (physics engine and navigation). **Nothing on the CPU side justified optimising.**

**Rendering diagnostics** (`chart_diagnostics.png`; normal scenario, 20 s; one thing changed at a time; baseline about 123–126 ms):

| Change | Frame ms | What it shows |
|---|---|---|
| sun shadows off | 63 | the sun's shadow passes cost about half the frame |
| resolution 640×360 | 49 | llvmpipe is heavily fill-rate bound (pixel cost) |
| all decoration hidden | 85 | decoration costs about 30% (draws and shadow casters) |
| sun shadow 2 cascades instead of 4 | 99 | most of the shadow cost is the 4 cascade passes (draw calls 365 → 290) |
| 2 cascades + 2048 shadow atlas | 90 | the smaller atlas also helps (fewer shadow-map pixels) |
| omni lights off | 101 | the 17 omni lights cost about 20% (per-pixel lighting) |
| books hidden | 105 | about 6,600 book instances cost about 15% |
| shadow atlas 2048 alone | 113 | |
| shadow distance 40 m | 125 | no effect: the level is small |
| books cast no shadow | 122 | already the case; no effect |
| all UI layers hidden | 119 | the HUD is not a cost (it only moves time between counters) |

**The bottleneck is rendering, and within it the sun's 4-cascade shadow map.** Turning shadows off, removing lights or hiding decoration would change how the level looks, so those were not done. Cascade count and atlas size can be changed without a visible difference, which was checked as described below.

## Optimisations (both measured; one commit each)

1. **The sun's shadow uses 2 cascades instead of 4.**
   - Change: `KeyLight.directional_shadow_mode = PSSM 2 splits` in the library scene.
   - Commit: `perf: sun shadow uses 2 cascades instead of 4 (measured)`.
2. **The directional shadow atlas is 2048 instead of 4096.**
   - Change: the project setting `rendering/lights_and_shadows/directional_shadow/size`.
   - Commit: `perf: directional shadow atlas 2048 instead of 4096 (measured)`.

**Visual check.** `tools/capture_views.gd` rendered the 8 fixed viewpoints and the top-down view before and after each step (`docs/performance/visual/`). The renders were compared pixel by pixel:
- Mean difference: 0.1–0.6 of 255.
- Pixels differing by more than 16 levels: 0.01–0.9% per view.
- What differs is shadow edges and shadow-acne patterns (see `visual/compare_*.png`, where the third panel is the difference ×8).

### Before / after (rendering, 1280×720, llvmpipe)

| Scenario | Avg FPS before → after | 1% low | Frame ms mean | Frame ms p95 | Render CPU ms | Draw calls |
|---|---|---|---|---|---|---|
| normal (3) | 8.37 → **11.61** (+39%) | 5.59 → 7.85 | 119.6 → 86.2 (−28%) | 158.0 → 115.6 | 109.1 → 77.4 | 359 → 302 |
| several (8) | 8.18 → **11.41** (+39%) | 5.94 → 7.69 | 122.2 → 87.6 (−28%) | 155.7 → 114.9 | 109.3 → 77.5 | 441 → 371 |
| stress (24) | 7.85 → **10.57** (+35%) | 5.55 → 7.08 | 127.3 → 94.6 (−26%) | 160.6 → 127.7 | 109.4 → 79.1 | 730 → 607 |

**What each step contributed (normal):**
- 2 cascades: 8.37 → 10.61 FPS.
- 2048 atlas: 10.61 → 11.61 FPS.

**Run-to-run variation:** average FPS stayed within about ±3% for the same build and scenario (ranges in `results.md`).

**Physics ticks per frame (normal run 1):** 6.9 → 5.2. The simulation is less pressed against Godot's 8-steps-per-frame limit.

**Headless CPU** was unchanged within noise, as expected for a rendering-only change:
- normal 0.72 → 0.77 ms;
- several 1.19 → 1.14 ms;
- stress 2.33 → 2.14 ms.

**Video memory** was reported as 32 MB both before and after. Godot's monitor does not appear to include the directional shadow atlas on this renderer, so the memory saved by the smaller atlas is not measured.

## Memory and allocation

GDScript frees objects by reference counting; it has no tracing garbage collector and no collection pauses. Allocation was checked through memory and object counts over a 300 s headless run (normal):
- **Static memory:** 65.0 MB at the start, then steady between 65.8 and 66.0 MB from 30 s to the end. That is about 1 MB of warm-up, then no growth.
- **Objects:** varied between 3,054 and 3,089 (short-lived noise events and tweens) with no upward trend.
- **Nodes and orphan nodes:** nodes constant at 936; orphan nodes 0.

There is no sign of a leak. Memory grows with guard count: 65.8 MB (3 guards) to 74.5 MB (48), about 0.19 MB per guard.

## Frame-time spikes

The headless CPU runs show rare single-frame spikes:
- How often: 0–7 frames above 8 ms per 1,800-frame run.
- Size: up to 51 ms, all of it in "other", none in the scripts.
- Pattern: they don't line up with the noise events, and they appear both before and after the change.

On a shared 2-vCPU VM this is consistent with scheduling. They can't be attributed further without a native profiler, so they are recorded here, not explained. The p95 and p99 figures are unaffected.

## Evidence files (`docs/performance/`)

| File / folder | Content |
|---|---|
| `results.md` | every table, generated from the runs |
| `chart_frame_breakdown.png` | frame time by part, before/after, 3 scenarios |
| `chart_fps.png` | average and 1% low FPS, before/after |
| `chart_diagnostics.png` | what each part costs |
| `chart_cpu_scaling.png` | CPU cost from 3 to 48 guards |
| `chart_frametime_series.png` | frame time over a run, before/after |
| `scenario_screenshots.png` | benchmark frames for normal / several / stress (after) |
| `baseline/`, `after_2splits/`, `after_2splits_2048/` | each run's `frames.csv`, `summary.json` and screenshot (rendering and headless); `after_2splits_2048/cpu_scaling/`; `after_2splits_2048/headless/long_normal_300s/` |
| `diag/` | the diagnostic runs |
| `visual/` | fixed viewpoints before, after 2 cascades, and after both changes, plus `compare_*.png` |

**About these captures:** they come from the benchmark's own instrumentation and Godot's monitors, not from screenshots of the Godot editor's Profiler or Visual Profiler. The editor isn't available in this environment.

## Verification record (2026-10-05)

| Check | Result |
|---|---|
| Full test suite | `All tests passed (… Phase 12 presentation, Phase 13 performance).`, exit 0, 2 min 44 s; the same 8 expected warnings |
| `tests/performance_tests.gd` | the sun keeps shadows with 2 cascades; atlas 2048; benchmark scenarios and statistics |
| Mutations | 4 cascades again, atlas 4096 again, sun shadows off, and a percentile off-by-one each fail the suite |
| Main menu scene, 300 frames | no script errors |
| Benchmark runs | 59 recorded runs (rendering, headless, diagnostics, scaling, 300 s), no script errors |

## Manual verification still required (Windows)

1. **Run the benchmark on the target PC.** Use the console build of Godot 4.7.2 from the project folder, for example:
   ```
   Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1920x1080 --script res://tools/benchmark.gd -- --scenario=normal --out=docs/performance/windows/normal_r1
   ```
   Repeat for `several` and `stress`, and fill in the hardware table: CPU, GPU, driver, RAM, Windows version.
2. **Godot's own profiler:** press F5, then open Debugger:
   - **Profiler:** start, play for 30 s, stop.
   - **Visual Profiler:** GPU and CPU times per render stage.
   - **Monitors:** FPS, process and physics time, draw calls, memory.

   Save screenshots in `docs/performance/windows/`. This shows whether rendering is still the largest cost on a real GPU.
3. **An exported release build** may be faster than the debug run measured here. Measuring it needs the export templates.
4. **Shadows on a real GPU:** check they still look right with 2 cascades and the 2048 atlas, especially the sunlit patches on the walls.

## Known limitations

- **Hardware:** the only measurements are on a GPU-less VM, so the size of the rendering gain on Windows is unknown. Cascade count and atlas size are cheaper on any GPU, but by how much has to be measured there.
- **Optimisation not taken:** omni lights and decoration have a measurable cost but were left alone, because reducing them would change the look.
- **Guard draw calls:** the guard model is about 20 separate meshes, about 18 extra draw calls per guard in the stress run (stress: 730 vs 359 draw calls before the optimisation). That's fine at the game's 3 guards. Merging the meshes would need a skinned model, which wasn't justified by these measurements.
- **Benchmark coverage:** chase and catch aren't exercised, since a catch would freeze the scene. Investigation is.
- **Navigation time:** reported only inside "other" and as Godot's once-per-second monitor; there is no separate per-frame figure.
