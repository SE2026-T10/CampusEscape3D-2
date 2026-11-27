# Benchmark v?t li?u s?n ph?m Gardner B

C?ng m?y: **Intel(R) Core(TM) 5 210H**, **NVIDIA GeForce RTX 3050 6GB Laptop GPU**, Godot 4.7.2 stable / GL Compatibility, **1280?720**. C?ng camera overview, FOV 75?, Environment/sky/??n/exposure. Product scene c? ch?n guard nh?ng ???c ??ng b?ng trong l??t ?o render. Kh?ng ch?y authoring, test ho?c Movie Maker ??ng th?i v?i m?u ?o.

Tool t?t VSync v? Engine.max_fps, warmup **120 display frame**, ?o **8 gi?y/m?u**, r?i kh?i ph?c c?c gi? tr?. S? d??i l? kho?ng th?i gian gi?a process frame, **kh?ng ph?i GPU timing**.

| Ch? s? | S?n ph?m tr??c B | S?n ph?m B |
|---|---:|---:|
| Frames l?y m?u | 2687 | 2717 |
| Process interval p50 (ms) | 2.875 | 2.840 |
| p95 (ms) | 4.109 | 4.030 |
| p99 (ms) | 5.352 | 4.859 |
| Draw calls p50 | 1278 | 1224 |
| Primitives p50 | 1726889 | 1728753 |
| Render memory (MiB) | 459.54 | 461.25 |

Draw calls gi?m 4.2%; primitives t?ng 0.11%; memory t?ng 1.71 MiB. L?p ho?n thi?n m?i t?ch v?ng/material, c?n batching BoxMesh v? spindle theo material gi?m draw calls. C?c s? interval kh?ng cho th?y regression ??ng k? trong **m?u render t?nh ng?n n?y**; kh?ng ?? k?t lu?n v? gameplay d?i, GPU saturation ho?c d? ??a t?i ?a. Sai s? gi?a l??t ?o v? v? tr?/pose guard l?c ??ng b?ng v?n c? th? ?nh h??ng s? ??m.

Video gameplay c? ch?n AI ho?t ??ng l? b?ng ch?ng t??ng t?c/di chuy?n, kh?ng l?y FPS b? kh?a c?a Movie Maker l?m benchmark. Ch?a ?o gameplay uncapped d?i ho?c GPU timer trong ??t v?t li?u n?y.

[Raw tr??c](before-benchmark.json), [raw sau](after-benchmark.json), [camera/lighting](camera-comparison.json).
