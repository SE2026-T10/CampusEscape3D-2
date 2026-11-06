extends GameMenus

func refresh() -> void:
	super()
	# The map's result sheet replaces the shared generic victory panel.
	win_panel.hide()
