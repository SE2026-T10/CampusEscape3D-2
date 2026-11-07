extends Control

var date: Dictionary = {}
var bold_font: SystemFont
var days: Array[int] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bold_font = SystemFont.new()
	bold_font.font_names = PackedStringArray(["Arial"])
	bold_font.font_weight = 700

func set_date(value: Dictionary) -> void:
	date = value.duplicate()
	days.clear()
	var first := {"year":date.year,"month":date.month,"day":1,"hour":0,"minute":0,"second":0}
	var next := first.duplicate()
	next.month += 1
	if next.month == 13:
		next.month = 1
		next.year += 1
	var first_day := int(Time.get_unix_time_from_datetime_dict(first)/86400)
	var offset := posmod(first_day+4,7)
	var count := int((Time.get_unix_time_from_datetime_dict(next)-Time.get_unix_time_from_datetime_dict(first))/86400)
	for cell in 42:
		var day := cell-offset+1
		days.append(day if day > 0 and day <= count else 0)
	queue_redraw()

func _draw() -> void:
	if date.is_empty():
		return
	var ink := Color(.14,.18,.14)
	var soft := Color(.7,.73,.68)
	draw_rect(Rect2(0,0,600,850),Color(.98,.975,.94))
	draw_rect(Rect2(0,0,600,165),Color(.13,.29,.19))
	# A decorative botanical header stays crisp on the wall and the reading sheet.
	for i in 12:
		var x := float(i)*55-15
		var y := 42.0+sin(i*1.8)*23
		draw_circle(Vector2(x,y),45,Color(.23,.4,.23))
		draw_line(Vector2(x,65),Vector2(x+24,8),Color(.47,.6,.32),3)
		for petal in 6:
			var angle := petal*TAU/6
			draw_circle(Vector2(x,y)+Vector2(cos(angle),sin(angle))*7,5,Color(.93,.94,.84))
		draw_circle(Vector2(x,y),3,Color(.92,.74,.3))
	draw_string(bold_font,Vector2(25,136),"THÁNG %02d   %04d"%[date.month,date.year],HORIZONTAL_ALIGNMENT_LEFT,-1,40,Color.WHITE)
	var left := 24.0
	var top := 216.0
	var width := 552.0/7
	var height := 91.0
	var names := ["CN","T2","T3","T4","T5","T6","T7"]
	for column in 7:
		draw_string(bold_font,Vector2(left+column*width+20,198),names[column],HORIZONTAL_ALIGNMENT_LEFT,-1,21,ink)
	for cell in 42:
		var at := Vector2(left+(cell%7)*width,top+(cell/7)*height)
		var area := Rect2(at,Vector2(width,height))
		var today: bool = days[cell] == int(date.day)
		if today:
			draw_rect(area.grow(-2),Color(.87,.93,.84))
			draw_rect(area.grow(-2),Color(.22,.4,.22),false,2)
		draw_rect(area,soft,false,1)
		if days[cell] > 0:
			draw_string(bold_font if today else ThemeDB.fallback_font,at+Vector2(9,32),str(days[cell]),HORIZONTAL_ALIGNMENT_LEFT,-1,29 if today else 24,ink)
	draw_string(ThemeDB.fallback_font,Vector2(24,808),"Hôm nay  %02d/%02d/%04d"%[date.day,date.month,date.year],HORIZONTAL_ALIGNMENT_LEFT,-1,23,ink)
	draw_rect(Rect2(0,832,600,18),Color(.13,.29,.19))
