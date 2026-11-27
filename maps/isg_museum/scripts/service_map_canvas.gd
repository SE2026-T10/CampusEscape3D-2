extends Control

var floor_index := 0:
	set(value):
		floor_index = value
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var scale_factor := minf((size.x-24)/36.0,(size.y-30)/30.0)
	var origin := (size-Vector2(36,30)*scale_factor)/2
	var rooms := [
		[Rect2(0,0,27,6),"LỊCH SỬ" if floor_index == 0 else "PHÒNG C"],
		[Rect2(27,0,9,6),"THANG B"],
		[Rect2(0,6,9,18),"ĐIÊU KHẮC" if floor_index == 0 else "PHÒNG A"],
		[Rect2(27,6,9,12),"NHÂN VIÊN" if floor_index == 0 else "PHÒNG B"],
		[Rect2(27,18,9,6),"KHO PHỤ · DÂY" if floor_index == 0 else "KHO PHỤC CHẾ"],
		[Rect2(27,24,9,6),"DỊCH VỤ" if floor_index == 0 else "TẬP KẾT T2"],
		[Rect2(0,24,9,6),"THANG A"],
		[Rect2(9,24,18,6),"SẢNH CHÍNH" if floor_index == 0 else "PHÒNG ĐỆM NAM"],
	]
	draw_rect(Rect2(origin,Vector2(36,30)*scale_factor),Color(0.65,0.65,0.52))
	for entry in rooms:
		var rect: Rect2 = entry[0]
		var target := Rect2(origin+rect.position*scale_factor,rect.size*scale_factor)
		draw_rect(target.grow(-2),Color(0.9,0.84,0.66))
		draw_rect(target,Color(0.2,0.24,0.23),false,2)
		var caption: String = entry[1]
		var font_size := 14 if rect.size.x < 10 else 16
		var text_size := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
		draw_string(font,target.get_center()+Vector2(-text_size.x/2,5),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(0.12,0.15,0.12))
	var courtyard := Rect2(origin+Vector2(12,9)*scale_factor,Vector2(12,12)*scale_factor)
	draw_rect(courtyard,Color(0.22,0.37,0.28) if floor_index == 0 else Color(0.16,0.2,0.24))
	draw_rect(courtyard,Color(0.9,0.73,0.3),false,3)
	if floor_index == 0:
		draw_circle(courtyard.get_center(),2.8*scale_factor,Color(0.71,0.67,0.56))
		draw_circle(courtyard.get_center(),1.7*scale_factor,Color(0.27,0.57,0.62))
		draw_line(courtyard.get_center()+Vector2(0,-6)*scale_factor,courtyard.get_center()+Vector2(0,-2.8)*scale_factor,Color(0.71,0.67,0.56),2*scale_factor)
		draw_line(courtyard.get_center()+Vector2(0,6)*scale_factor,courtyard.get_center()+Vector2(0,2.8)*scale_factor,Color(0.71,0.67,0.56),2*scale_factor)
		draw_line(courtyard.get_center()+Vector2(-6,0)*scale_factor,courtyard.get_center()+Vector2(-2.8,0)*scale_factor,Color(0.71,0.67,0.56),2*scale_factor)
		draw_line(courtyard.get_center()+Vector2(6,0)*scale_factor,courtyard.get_center()+Vector2(2.8,0)*scale_factor,Color(0.71,0.67,0.56),2*scale_factor)
	else:
		draw_string(font,courtyard.get_center()+Vector2(-60,0),"THÔNG TẦNG",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
		draw_string(font,courtyard.get_center()+Vector2(-62,24),"Không có sàn",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
	# White door gaps match the current authored room entrances.
	for data in [[Vector2(15,6),true],[Vector2(23,6),true],[Vector2(9,9),false],[Vector2(9,19),false],[Vector2(27,10),false],[Vector2(27,27),false],[Vector2(9,27),false],[Vector2(27,3),false],[Vector2(18,24),true]]:
		var at: Vector2 = origin+data[0]*scale_factor
		var direction := Vector2.RIGHT if data[1] else Vector2.DOWN
		draw_line(at-direction*0.7*scale_factor,at+direction*0.7*scale_factor,Color(0.65,0.65,0.52),5)
	if floor_index == 0:
		var at := origin+Vector2(27,21)*scale_factor
		draw_line(at-Vector2(0,.7)*scale_factor,at+Vector2(0,.7)*scale_factor,Color(0.65,0.65,0.52),5)
		draw_string(font,origin+Vector2(17,29)*scale_factor,"LỐI VÀO",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.12,0.15,0.12))
	else:
		draw_string(font,origin+Vector2(34.2,27)*scale_factor,"E →",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(0.1,0.45,0.22))
		for pos in [Vector2(9,27),Vector2(27,3)]:
			draw_circle(origin+pos*scale_factor,10,Color(0.15,0.5,0.65))
			draw_string(font,origin+pos*scale_factor+Vector2(-5,5),"V",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
