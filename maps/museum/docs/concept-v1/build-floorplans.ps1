param([string]$OutputDirectory = 'D:/IT/SE_GAME_3D/maps/museum/docs/concept-v1')

# Editable, deterministic drawing. Uses only Windows System.Drawing.
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$W = 3200; $H = 1840
$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$svg = New-Object System.Text.StringBuilder
[void]$svg.AppendLine('<svg xmlns="http://www.w3.org/2000/svg" width="3200" height="1840" viewBox="0 0 3200 1840">')
[void]$svg.AppendLine('<title>Bảo tàng — bản thiết kế mặt bằng hai tầng</title>')
[void]$svg.AppendLine('<desc>Map game hư cấu. Kích thước ngoài 36 x 30 m; sân trong 12 x 12 m; hành lang 3 m. Tầng 1 và tầng 2 cùng hướng bắc.</desc>')
$navy = '#101D2B'; $panel = '#172839'; $muted = '#91A8B9'; $white = '#EFF5F6'
$cream = '#ECE9DF'; $wall = '#354A59'; $teal = '#007F88'; $amber = '#E9A928'; $red = '#B7464C'

function C([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
function Draw-Rect([double]$x,[double]$y,[double]$w,[double]$h,[string]$fill,[string]$stroke='',[double]$sw=1) {
    if($fill -ne 'none') { $b=New-Object System.Drawing.SolidBrush((C $fill)); $g.FillRectangle($b,[single]$x,[single]$y,[single]$w,[single]$h); $b.Dispose() }
    if($stroke) { $p=New-Object System.Drawing.Pen((C $stroke),[single]$sw); $g.DrawRectangle($p,[single]$x,[single]$y,[single]$w,[single]$h); $p.Dispose() }
    [void]$svg.AppendLine("<rect x='$x' y='$y' width='$w' height='$h' fill='$fill' stroke='$(if($stroke){$stroke}else{'none'})' stroke-width='$sw'/>")
}
function Draw-Path([object[]]$points,[string]$color,[double]$width=3,[switch]$Dashed,[switch]$Closed,[string]$fill='none') {
    $ps = [System.Drawing.PointF[]]@($points | ForEach-Object { New-Object System.Drawing.PointF([single]$_[0],[single]$_[1]) })
    $p=New-Object System.Drawing.Pen((C $color),[single]$width)
    $p.StartCap=[System.Drawing.Drawing2D.LineCap]::Round; $p.EndCap=[System.Drawing.Drawing2D.LineCap]::Round; $p.LineJoin=[System.Drawing.Drawing2D.LineJoin]::Round
    if($Dashed) { $p.DashPattern = [single[]]@(3,2) }
    if($Closed) {
        if($fill -ne 'none') { $b=New-Object System.Drawing.SolidBrush((C $fill)); $g.FillPolygon($b,$ps); $b.Dispose() }
        $g.DrawPolygon($p,$ps)
    } else { $g.DrawLines($p,$ps) }
    $p.Dispose()
    $tag = if($Closed){'polygon'}else{'polyline'}
    $coords = ($points | ForEach-Object { "$($_[0]),$($_[1])" }) -join ' '
    $dash = if($Dashed){"stroke-dasharray='$($width*3) $($width*2)'"}else{''}
    [void]$svg.AppendLine("<$tag points='$coords' fill='$fill' stroke='$color' stroke-width='$width' stroke-linejoin='round' stroke-linecap='round' $dash/>")
}
function Draw-Line([double]$x1,[double]$y1,[double]$x2,[double]$y2,[string]$color,[double]$width=3,[switch]$Dashed) {
    Draw-Path @(@($x1,$y1),@($x2,$y2)) $color $width -Dashed:$Dashed
}
function Draw-Circle([double]$x,[double]$y,[double]$r,[string]$fill,[string]$stroke='',[double]$sw=2) {
    $b=New-Object System.Drawing.SolidBrush((C $fill)); $g.FillEllipse($b,[single]($x-$r),[single]($y-$r),[single]($r*2),[single]($r*2)); $b.Dispose()
    if($stroke) { $p=New-Object System.Drawing.Pen((C $stroke),[single]$sw); $g.DrawEllipse($p,[single]($x-$r),[single]($y-$r),[single]($r*2),[single]($r*2)); $p.Dispose() }
    [void]$svg.AppendLine("<circle cx='$x' cy='$y' r='$r' fill='$fill' stroke='$(if($stroke){$stroke}else{'none'})' stroke-width='$sw'/>")
}
function Draw-Text([string]$value,[double]$x,[double]$y,[double]$size=24,[string]$color=$white,[string]$align='left',[switch]$Bold) {
    $style=if($Bold){[System.Drawing.FontStyle]::Bold}else{[System.Drawing.FontStyle]::Regular}
    $font=New-Object System.Drawing.Font('Segoe UI',[single]$size,$style,[System.Drawing.GraphicsUnit]::Pixel)
    $b=New-Object System.Drawing.SolidBrush((C $color))
    $sf=New-Object System.Drawing.StringFormat
    $sf.LineAlignment=[System.Drawing.StringAlignment]::Center
    $sf.Alignment=switch($align){'center'{[System.Drawing.StringAlignment]::Center};'right'{[System.Drawing.StringAlignment]::Far};default{[System.Drawing.StringAlignment]::Near}}
    $g.DrawString($value,$font,$b,[System.Drawing.PointF]::new([single]$x,[single]$y),$sf)
    $anchor=switch($align){'center'{'middle'};'right'{'end'};default{'start'}}
    $weight=if($Bold){700}else{400}
    $escaped=[System.Security.SecurityElement]::Escape($value)
    [void]$svg.AppendLine("<text x='$x' y='$y' font-family='Segoe UI,Arial,sans-serif' font-size='$size' font-weight='$weight' text-anchor='$anchor' dominant-baseline='central' fill='$color'>$escaped</text>")
    $font.Dispose(); $b.Dispose(); $sf.Dispose()
}

$S=32.0; $OY=375.0; $OX=175.0
function MR([double]$x,[double]$y,[double]$w,[double]$h,[string]$fill,[string]$stroke='',[double]$sw=1) { Draw-Rect ($OX+$x*$S) ($OY+$y*$S) ($w*$S) ($h*$S) $fill $stroke $sw }
function ML([double]$x1,[double]$y1,[double]$x2,[double]$y2,[string]$color=$wall,[double]$width=7,[switch]$Dashed) { Draw-Line ($OX+$x1*$S) ($OY+$y1*$S) ($OX+$x2*$S) ($OY+$y2*$S) $color $width -Dashed:$Dashed }
function Map-Path([object[]]$points,[string]$color,[double]$width=4,[switch]$Dashed) {
    $translated=@($points | ForEach-Object { ,@(($OX+$_[0]*$S),($OY+$_[1]*$S)) })
    Draw-Path $translated $color $width -Dashed:$Dashed
}
function MT([string]$value,[double]$x,[double]$y,[double]$size=23,[string]$color=$wall,[switch]$Bold) { Draw-Text $value ($OX+$x*$S) ($OY+$y*$S) $size $color 'center' -Bold:$Bold }
function Mark([string]$label,[double]$x,[double]$y,[string]$color=$amber,[double]$r=19) { Draw-Circle ($OX+$x*$S) ($OY+$y*$S) $r $color $white 2; MT $label $x $y 20 $navy -Bold }
function Door([double]$x,[double]$y,[bool]$vertical=$true,[bool]$locked=$false,[string]$lockLabel='K') {
    # Gap in wall is the clear opening; thin leaf/swing is only a plan symbol.
    $dc=if($locked){'#AD7A16'}else{'#8A9EA6'}
    if($vertical) { ML $x ($y-0.8) ($x+1.3) ($y-0.8) $dc 2; ML ($x+1.3) ($y-0.8) ($x+1.3) ($y+0.4) $dc 1 -Dashed }
    else { ML ($x-0.8) $y ($x-0.8) ($y+1.3) $dc 2; ML ($x-0.8) ($y+1.3) ($x+0.4) ($y+1.3) $dc 1 -Dashed }
    if($locked){Mark $lockLabel $x $y '#D7B75D' 13}
}
function Stair([string]$name,[double]$x,[double]$y,[string]$direction) {
    MR ($x+1) ($y+1.4) 6.8 2.8 '#C5D0D6' '#718694' 2
    for($i=0;$i -lt 12;$i++){ML ($x+1+$i*0.56) ($y+1.4) ($x+1+$i*0.56) ($y+4.2) '#8296A1' 1.4}
    ML ($x+1.5) ($y+2.8) ($x+7.2) ($y+2.8) $wall 2.5
    Map-Path @(@(($x+6.5),($y+2.4)),@(($x+7.2),($y+2.8)),@(($x+6.5),($y+3.2))) $wall 2.5
    MT "THANG $name" ($x+4.5) ($y+0.65) 21 $wall -Bold
    MT $direction ($x+4.5) ($y+4.95) 18 $wall
}
function Cover([double]$x,[double]$y,[double]$w,[double]$h) { MR $x $y $w $h '#9BAAA8' '#6A7F80' 2; MR ($x+0.2) ($y+0.2) ($w-0.4) ($h-0.4) '#B8C5BD' }
function Arrow([double]$x,[double]$y,[string]$direction,[string]$col=$teal) {
    $pts=switch($direction){'up'{@(@(($x-0.18),($y+0.3)),@($x,$y),@(($x+0.18),($y+0.3)))};'down'{@(@(($x-0.18),($y-0.3)),@($x,$y),@(($x+0.18),($y-0.3)))};'right'{@(@(($x-0.3),($y-0.18)),@($x,$y),@(($x-0.3),($y+0.18)))};default{@(@(($x+0.3),($y-0.18)),@($x,$y),@(($x+0.3),($y+0.18)))}}
    Map-Path $pts $col 4
}

Draw-Rect 0 0 $W $H $navy
Draw-Text 'CAMPUS ESCAPE 3D  /  MUSEUM CONCEPT 01' 80 60 23 '#6ED6CB' -Bold
Draw-Text 'ĐÊM Ở BẢO TÀNG' 80 124 58 $white -Bold
Draw-Text 'Mặt bằng chơi thử  •  Hai tầng quanh sân trong  •  Ba tác phẩm chính  •  Một đường thoát bằng dây' 82 184 27 $muted
Draw-Text '36 × 30 m' 3115 112 42 $white 'right' -Bold
Draw-Text 'Sân 12 × 12 m  /  Hành lang 3 m' 3115 165 23 $muted 'right'

foreach($floor in 1,2) {
    $OX=if($floor -eq 1){175.0}else{1765.0}
    $px=$OX-105
    Draw-Rect $px 240 1470 1195 $panel
    Draw-Text $(if($floor -eq 1){'01  TẦNG 1'}else{'02  TẦNG 2'}) ($px+30) 285 32 $white -Bold
    Draw-Text $(if($floor -eq 1){'Cao độ +0,00 m · Xâm nhập & tìm chìa khóa'}else{'Cao độ +4,50 m · Lấy tác phẩm & thoát'}) ($px+280) 287 22 $muted
    # Overall dimensions and north arrow.
    Draw-Line $OX 345 ($OX+1152) 345 '#6C8496' 1.5
    Draw-Line $OX 337 $OX 353 '#6C8496' 1.5
    Draw-Line ($OX+1152) 337 ($OX+1152) 353 '#6C8496' 1.5
    Draw-Rect ($OX+525) 327 102 33 $panel
    Draw-Text '36 m' ($OX+576) 343 20 $muted 'center'
    Draw-Line ($OX-38) $OY ($OX-38) ($OY+960) '#6C8496' 1.5
    Draw-Text '30 m' ($OX-65) ($OY+480) 18 $muted 'center'
    Draw-Line ($OX+1240) 408 ($OX+1240) 351 '#A5BBC8' 3
    Draw-Path @(@(($OX+1230),365),@(($OX+1240),345),@(($OX+1250),365)) '#A5BBC8' 3
    Draw-Text 'BẮC' ($OX+1240) 328 18 $muted 'center' -Bold
    MR 0 0 36 30 $cream
    MR 0 0 27 6 '#E9DFCD'
    MR 27 0 9 6 '#DAE3E7'
    MR 0 6 9 18 '#D6DFDB'
    MR 27 6 9 12 $(if($floor -eq 1){'#DAE2E4'}else{'#E5DBCB'})
    MR 0 24 9 6 '#DAE3E7'
    MR 9 24 18 6 '#E4DED4'
    if($floor -eq 1){MR 27 18 9 6 '#D9E0DE';MR 27 24 9 6 '#D8E0E2'}
    else{MR 27 18 9 12 '#D9E0DE'}
    MR 12 9 12 12 $(if($floor -eq 1){'#B8CBB8'}else{'#273E4D'})
    # Courtyard garden / upper void boundary.
    if($floor -eq 1) {
        MR 13 10 10 10 '#CCD8C3'
        MR 17.55 9 0.9 12 '#E6DEC8'; MR 12 14.55 12 0.9 '#E6DEC8'
        Draw-Circle ($OX+18*$S) ($OY+15*$S) 63 '#9DBCB8' '#E2E7D7' 9
        Draw-Circle ($OX+18*$S) ($OY+15*$S) 20 '#C6D6CB'
        foreach($tree in @(@(14,11),@(22,11),@(14,19),@(22,19))) {
            Draw-Circle ($OX+$tree[0]*$S) ($OY+$tree[1]*$S) 24 '#719785' '#90AB96' 6
        }
    } else {
        # Ghost of ground garden is schematic and remains visibly a void.
        MR 13 10 10 10 '#314C59'
        Draw-Circle ($OX+18*$S) ($OY+15*$S) 63 '#3C5C66' '#54727A' 3
        for($q=12.5;$q -le 23.5;$q+=1) {ML $q 9 $q 9.25 '#8CA7AD' 2;ML $q 20.75 $q 21 '#8CA7AD' 2}
        for($q=9.5;$q -le 20.5;$q+=1) {ML 12 $q 12.25 $q '#8CA7AD' 2;ML 23.75 $q 24 $q '#8CA7AD' 2}
    }
    ML 12 9 24 9 '#758F8F' 4; ML 12 9 12 21 '#758F8F' 4; ML 24 9 24 21 '#758F8F' 4
    if($floor -eq 1){ML 12 21 17 21 '#758F8F' 4;ML 19 21 24 21 '#758F8F' 4}else{ML 12 21 24 21 '#8CA7AD' 4}
    # Exterior wall with entry/window gap.
    ML 0 0 36 0; ML 0 0 0 30; ML 36 0 36 $(if($floor -eq 1){30}else{26.2})
    if($floor -eq 2){ML 36 27.8 36 30;ML 36 26.2 36 27.8 '#5BADA9' 4}
    if($floor -eq 1){ML 0 30 17 30;ML 19 30 36 30}else{ML 0 30 36 30}
    # North gallery double access, NE stair accessible from north gallery.
    ML 0 6 14 6; ML 16 6 22 6; ML 24 6 36 6
    Door 15 6 $false; Door 23 6 $false
    ML 27 0 27 2; ML 27 4 27 6; Door 27 3
    # West gallery double access to ring.
    ML 9 6 9 8.2; ML 9 9.8 9 18.2; ML 9 19.8 9 24
    Door 9 9; Door 9 19
    # East room, entrance centered y10. Exit options vary by floor.
    ML 27 6 27 9.2; ML 27 10.8 27 $(if($floor -eq 1){14.2}else{18})
    Door 27 10 $true ($floor -eq 2)
    if($floor -eq 1){ML 27 15.8 27 20.2;ML 27 21.8 27 26.2;ML 27 27.8 27 30;Door 27 15;Door 27 21;Door 27 27;ML 27 18 36 18;ML 27 24 36 24}
    else {ML 27 18 27 26.2;ML 27 27.8 27 30;Door 27 27;ML 27 18 31.2 18;ML 32.8 18 36 18;Door 32 18 $false $true '↓'}
    # South room and southwest stair.
    ML 0 24 16.8 24;ML 19.2 24 27 24;Door 18 24 $false
    ML 9 24 9 26.2;ML 9 27.8 9 30;Door 9 27
    Stair 'A' 0 24 $(if($floor -eq 1){'LÊN T2'}else{'XUỐNG T1'})
    Stair 'B' 27 0 $(if($floor -eq 1){'LÊN T2'}else{'XUỐNG T1'})
    # Opaque bases: avoid implying transparent glass occludes guards.
    Cover 3.2 10 2.3 3.0; Cover 3.2 16 2.3 3.0
    Cover 9 2.1 3.4 1.5; Cover 20.4 2.1 3.4 1.5
    if($floor -eq 1){Cover 30 10 3 2;Cover 29 19.5 1.7 3;Cover 33 19.5 1.7 3;Cover 29 25 2.8 1.2}
    else{Cover 30.2 10.5 2.5 3;Cover 28.8 20.2 2 3;Cover 33.2 20.2 1.8 3}
    # Patrol routes all pass through openings; G3 stays in the locked gallery.
    if($floor -eq 1){
        Map-Path @(@(7,9),@(10.5,9),@(10.5,22.5),@(18,22.5),@(18,27),@(12,27),@(18,27),@(18,22.5),@(10.5,22.5),@(10.5,19),@(7,19),@(7,9)) $red 4 -Dashed
        Mark 'G1' 7 15 $red 20
        Map-Path @(@(18,31),@(18,28.8),@(20.5,28.8),@(20.5,25.3),@(18,25.3),@(18,22.5),@(25.5,22.5),@(25.5,15),@(29,15),@(31.5,15),@(31.5,13)) $teal 5
        Map-Path @(@(25.5,15),@(25.5,7.5),@(15,7.5),@(15,3.9),@(25.3,3.9),@(25.3,3),@(29,3)) $teal 3 -Dashed
        Map-Path @(@(18,28.8),@(10.5,28.8),@(10.5,27),@(7.8,27)) $teal 3 -Dashed
        Arrow 18 29.5 'up';Arrow 23 22.5 'right';Arrow 25.5 17 'up'
        Mark 'K' 31.5 13 $amber 21
        Mark 'S' 18 30.7 '#6FD4C4' 21
        Mark 'L' 39 27 '#6FD4C4' 21
        ML 37 27 40 27 '#6FD4C4' 3 -Dashed
        MT 'SÂN NGOÀI' 39 28.3 17 '#B6C9D3'
        MT 'Điểm đáp dây' 39 29.1 15 '#91A8B9'
    } else {
        Map-Path @(@(7,19),@(7,9),@(10.5,9),@(10.5,7.5),@(15,7.5),@(15,4.9),@(23,4.9),@(23,7.5),@(10.5,7.5),@(10.5,19),@(7,19)) $red 4 -Dashed
        Mark 'G2' 7 15 $red 20
        Map-Path @(@(28.5,8.4),@(34.2,8.4),@(34.2,15.8),@(28.5,15.8),@(28.5,8.4)) $red 4 -Dashed
        Mark 'G3' 34.2 14.5 $red 20
        Map-Path @(@(7.8,27),@(12.5,27),@(12.5,25.2),@(18,25.2),@(18,22.5),@(10.5,22.5),@(10.5,19),@(6.3,19),@(6.3,20.8),@(1.5,20.8),@(1.5,12)) $teal 5
        Map-Path @(@(1.5,12),@(1.5,8.4),@(9,9),@(10.5,9),@(10.5,7.5),@(15,7.5),@(15,1.1),@(18,1.1)) $teal 5
        Map-Path @(@(18,1.1),@(25.2,1.1),@(25.2,4.6),@(23,4.6),@(23,7.5),@(25.5,7.5),@(25.5,10),@(28,10),@(28,9.2),@(35,9.2),@(35,10)) $teal 5
        Map-Path @(@(35,10),@(35,17),@(32,17),@(32,23),@(32,27),@(36,27),@(38.5,27)) $teal 5
        Map-Path @(@(18,27),@(27,27),@(31,27)) $teal 3 -Dashed
        Arrow 1.5 14 'up';Arrow 25.5 8.9 'down';Arrow 32 25.3 'down';Arrow 35 27 'right'
        Mark 'T1' 1.5 12 $amber 23;Mark 'T2' 35 10 $amber 23;Mark 'T3' 18 1.1 $amber 23
        Mark 'R' 32 23 $amber 21;Mark 'E' 36 27 '#6FD4C4' 22
        MT 'DÂY' 39 25.7 19 '#6FD4C4' -Bold
        MT 'xuống sân ngoài' 39 26.5 15 '#B6C9D3'
    }
    # Labels last, with clear areas reserved inside each room.
    if($floor -eq 1){
        MT 'PHÒNG TRƯNG BÀY LỊCH SỬ' 12.8 0.75 22 $wall -Bold
        MT 'PHÒNG' 4.5 7.0 22 $wall -Bold;MT 'ĐIÊU KHẮC' 4.5 7.8 22 $wall -Bold
        MT 'NHÂN VIÊN' 31.5 6.9 22 $wall -Bold;MT 'Chìa khóa phòng B' 31.5 7.7 17 '#5D7480'
        MT 'KHO PHỤ' 31.5 18.7 22 $wall -Bold
        MT 'PHÒNG DỊCH VỤ' 31.5 29.15 20 $wall -Bold
        MT 'SẢNH CHÍNH' 17.8 29.2 22 $wall -Bold
        MT 'SÂN TRONG' 18 12.1 30 '#36584C' -Bold
        MT '12 × 12 m' 18 13.1 22 '#36584C'
        MT 'Có thể đi vào' 18 17.2 18 '#36584C'
        MT 'LỐI VÀO' 18 32.0 21 '#6FD4C4' -Bold
    }else{
        MT 'PHÒNG TRANH C' 6.2 0.8 23 $wall -Bold
        MT 'PHÒNG A' 4.5 6.9 23 $wall -Bold
        MT 'PHÒNG B' 31.5 6.9 23 $wall -Bold
        MT 'Mở bằng chìa K' 31.5 7.6 17 '#7D671D'
        MT 'KHO PHỤC CHẾ' 31.5 19 22 $wall -Bold
        MT 'Đường tắt: mở từ B' 31.5 17.45 15 '#805F23'
        MT 'PHÒNG ĐỆM PHÍA NAM' 18 29.15 21 $wall -Bold
        MT 'KHOẢNG THÔNG TẦNG' 18 12.4 25 '#D3E3E4' -Bold
        MT 'Nhìn xuống sân tầng 1' 18 13.5 21 '#A7C3C9'
        MT 'Lan can quanh mép' 18 17.2 19 '#A7C3C9'
        MT 'Không có sàn tại đây' 18 18.2 19 '#A7C3C9'
    }
    MT 'HÀNH LANG VÒNG · RỘNG 3 m' 18 21.85 16 '#607B83'
    Draw-Text $(if($floor -eq 1){'G1: điêu khắc + hành lang + sảnh'}else{'G2: tây + bắc  /  G3: bên trong phòng B'}) ($px+30) 1390 22 $muted
}

# Clear common legend and construction notes.
Draw-Line 80 1480 3120 1480 '#324B5B' 2
Draw-Text 'KÝ HIỆU & QUY TẮC' 80 1528 23 $white -Bold
Draw-Line 80 1580 150 1580 $teal 6
Draw-Text 'Tuyến chơi gợi ý' 170 1580 24 $white
Draw-Line 485 1580 555 1580 $teal 4 -Dashed
Draw-Text 'Lối phụ / chuẩn bị thoát sớm' 575 1580 24 $white
Draw-Line 1050 1580 1120 1580 $red 5 -Dashed
Draw-Text 'Tuyến tuần tra' 1140 1580 24 $white
Draw-Circle 1480 1580 18 $amber
Draw-Text 'T1–T3: tác phẩm  ·  K: chìa  ·  R: dây' 1515 1580 24 $white
Draw-Circle 2180 1580 18 '#6FD4C4'
Draw-Text 'S: bắt đầu  ·  E: thoát  ·  L: điểm đáp' 2215 1580 24 $white
Draw-Rect 80 1625 70 32 '#9BAAA8' '#6A7F80' 2
Draw-Text 'Bệ đặc / vật che tầm nhìn' 170 1641 24 $white
Draw-Text 'A ↔ A, B ↔ B: cầu thang nối hai tầng' 690 1641 24 $white
Draw-Text 'Cửa B → phục chế: mở từ phía B; kho phục chế còn có lối phía nam.' 1415 1641 24 $muted
Draw-Text 'BẢN THIẾT KẾ HƯ CẤU LẤY CẢM HỨNG TỪ GARDNER — KHÔNG PHẢI MẶT BẰNG BẢO TÀNG THẬT.' 80 1725 21 '#9FB5C1'
Draw-Text 'Tường, ô cửa và kích thước trên sơ đồ là cơ sở dựng blockout; tuyến màu chỉ diễn tả luồng chơi.' 80 1768 22 '#7893A4'
Draw-Rect 2650 1725 160 14 '#E5EDF0';Draw-Rect 2810 1725 160 14 '#718B9C'
Draw-Text '0' 2650 1764 19 $muted 'center';Draw-Text '5' 2810 1764 19 $muted 'center';Draw-Text '10 m' 2970 1764 19 $muted 'center'
[void]$svg.AppendLine('</svg>')
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$bmp.Save((Join-Path $OutputDirectory 'floorplans.png'),[System.Drawing.Imaging.ImageFormat]::Png)
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'floorplans.svg'),$svg.ToString(),[System.Text.UTF8Encoding]::new($false))
$g.Dispose();$bmp.Dispose()
Write-Output "Created floorplans.png and floorplans.svg in $OutputDirectory"
