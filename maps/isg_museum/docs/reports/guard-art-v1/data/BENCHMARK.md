# Guard animation ? current build measurement

Intel(R) Core(TM) 5 210H; NVIDIA GeForce RTX 3050 6GB Laptop GPU; GL Compatibility; 1280?720.
30 s measurement after 180 display-frame warmup. Nine normal AI actors active, player stationary outside, fixed courtyard camera; eight walking, G3 sleeping at sample end. Other Godot verification/capture processes were finished before this run. VSync disabled and Engine.max_fps=0 only in the measuring tool, restored afterward. No movie encoding during measurement.

| Metric | Value |
|---|---:|
| Display frames | 3073 |
| Process-frame interval p50 | 9.724 ms |
| p95 | 13.414 ms |
| p99 | 16.888 ms |
| Draw calls p50 | 1159 |
| Primitives p50 | 1830188 |
| Render memory p50 | 457.1 MiB |

These intervals are **not GPU timing**. Counters include the entire museum. Nine actors are processing but not all nine skins are simultaneously visible from this camera. No matched baseline was measured, so this does not establish added animation cost or spare GPU capacity. [Raw data](benchmark.json), [log](../logs/benchmark.log), [separate nine-guard video](../videos/nine-guards.avi).

Command: `godot --path . --script res://maps/isg_museum/tools/capture_guard_visuals.gd -- --benchmark`.
