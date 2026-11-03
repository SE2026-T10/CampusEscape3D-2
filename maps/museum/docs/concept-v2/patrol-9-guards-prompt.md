# Prompt — phương án 9 bảo an

Tool: built-in image_gen. Reference: floorplans-exterior-start.png.
Output: floorplans-patrol-9-guards.png.

```text
Edit the supplied museum floorplan into a polished, highly legible NEW PATROL PLAN infographic. Use case infographic-diagram. Reference/edit target: floorplans-exterior-start.png. Preserve the two side-by-side top-down floor plans, all room boundaries and doorway openings, courtyard, stairs, 36x30m building, ground-floor south front yard, outside spawn S, entrance D, upper-floor artworks T1,T2,T3, rope R, exit E and rope landing L. Do not move rope or change architecture. Keep Vietnamese room names. North up. Dark navy background, cream rooms, green courtyard, crisp architectural diagram. Render large landscape, detailed and sharp. Title "BẢO TÀNG — PHƯƠNG ÁN 9 BẢO AN". Subtitle "Tầng 1: 5 người | Tầng 2: 4 người". Remove ALL old guard routes G1/G2/G3 and ALL cyan suggested player paths so new routes are unambiguous. Remove old bottom-right proposal box, use its area for an indexed guard legend. NO perspective, no 3D.
Exactly NINE guards, exactly one clearly drawn patrol route per guard. Color-coded thick dashed lines with frequent directional arrowheads, circular numbered guard markers, and small hollow dots at route waypoints. Keep patrol lines inside walkable rooms/corridors and pass through existing doorway openings, never cut through walls or exhibit plinths. For a shared two-way doorway use out-and-back connected patrol route rather than inventing another doorway.
GROUND FLOOR left panel:
G1 orange: one room-local closed loop in PHÒNG ĐIÊU KHẮC, west side, around its two exhibit plinths, stays within room.
G2 purple: one room-local loop in PHÒNG TRƯNG BÀY LỊCH SỬ across north side around exhibits, stays in that room.
G3 blue: one local loop in NHÂN VIÊN, east middle upper room with key K, around furniture, stays within room.
G4 green: one complete rectangular loop around the OUTSIDE of the central courtyard in the surrounding ring corridor. Does not enter courtyard garden, does not patrol exterior yard.
G5 red: one connected route covering SẢNH CHÍNH south center and PHÒNG DỊCH VỤ southeast; crosses their actual connecting doorway, loops in each area and returns, stays out of the storage room and stairs/front yard.
UPPER FLOOR right panel:
G6 orange: one local loop in PHÒNG A west around exhibits T1, include a small labeled stop "Kiểm tra T1" by the artwork on west wall; stays inside A.
G7 purple: one local loop in PHÒNG TRANH C north around exhibits/T3, stays within C.
G8 blue: one local loop inside PHÒNG B east around its central exhibit/T2, never crosses locked B door or restoration shortcut.
G9 red: one connected patrol around courtyard upper ring corridor and into PHÒNG ĐỆM PHÍA NAM. Route uses existing corridor-to-south-buffer central doorway to cover buffer then returns through same doorway to resume corridor loop; never across courtyard void, never through locked gallery B or restoration room.
Use visible doorway detours where required. Put the nine IDs clearly in corresponding rooms, no duplicate guards. Lower legend with exact rows:
"TẦNG 1"
"G1 · Phòng điêu khắc"
"G2 · Trưng bày lịch sử"
"G3 · Phòng nhân viên"
"G4 · Vòng quanh sân trong"
"G5 · Sảnh chính + phòng dịch vụ"
"TẦNG 2"
"G6 · Phòng A — kiểm tra T1"
"G7 · Phòng C"
"G8 · Phòng B"
"G9 · Hành lang + phòng đệm nam"
Legend color swatch matches each route, reuse colors across separate floors fine. Bottom note "Nét đứt + mũi tên: tuyến tuần tra | Chấm tròn: điểm dừng | Bản thiết kế, chưa áp dụng vào Godot".
Prioritize exact guard counts, readable labels and truthful room-specific routes over decorative imagery. Preserve original map enough for direct comparison.
```
