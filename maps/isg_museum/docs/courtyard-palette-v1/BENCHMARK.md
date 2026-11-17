# Courtyard palette: fixed-angle render comparison

Intel(R) Core(TM) 5 210H; NVIDIA GeForce RTX 3050 6GB Laptop GPU; GL Compatibility; 1280?720. Same Player camera, Environment, sky, sun, lights and exposure; editing map frozen. VSync disabled, Engine.max_fps=0, restored after measurement. 120 display-frame warmup then 8 s per condition. No movie encoding or concurrent agent Godot checks during this run.

| Metric | Before | After |
|---|---:|---:|
| Measured display frames | 2695 | 2121 |
| Process interval p50 | 2.724 ms | 3.189 ms |
| p95 | 4.582 ms | 7.581 ms |
| p99 | 6.512 ms | 12.129 ms |
| Draw calls p50 | 1113 | 1215 |
| Primitives p50 | 1645615 | 1646967 |
| Render memory | 460.2 MiB | 460.2 MiB |

+102 draw calls (9.2%) and +1352 primitives reflect split surfaces/material roles. This is a short render-only sample with no guard AI; process intervals are **not GPU frame times**. Both palettes remain resident for F7, so memory readings include both. Do not extrapolate gameplay FPS or spare capacity. Preserve material-aware batching in phase B and measure gameplay separately.

[Raw data](benchmark.json), [log including shutdown texture diagnostic](benchmark.log).
Command: `godot --path . --script res://maps/isg_museum/tools/capture_courtyard_palette.gd -- --benchmark`.
