extends SceneTree

func walk_to(game, target: Vector2) -> void:
	var steps := 0
	while game.player_position.distance_to(target) > 0.07 and steps < 5000:
		game.move_player(target - game.player_position, 0.025)
		steps += 1
	assert(steps < 5000, "Destination must be reachable through the forest")

func _init() -> void:
	if not OS.get_user_data_dir().contains('.test-data'):
		push_error("Run with APPDATA and LOCALAPPDATA pointing to the project .test-data directory.")
		quit(1)
		return
	var game = load("res://main.gd").new()
	assert(game.WORLD_SIZE.x * game.WORLD_SIZE.y == 32 * 18 * 50)
	assert(game.player_position == game.START_POSITION and game.location == 1)
	assert(not game.has_hoe and not game.has_sickle and game.seeds == 0)
	assert(game.plots.size() == 10 and game.owned_cells.size() == 10)
	for cell in game.owned_cells:
		var neighbors := 0
		for other in game.owned_cells:
			if (cell - other).length_squared() == 1:
				neighbors += 1
		assert(neighbors > 0)
	for i in range(1, game.PLACE_CELLS.size()):
		assert(game.PLACE_CELLS[i].y >= 120)
	for route in game.ROUTES:
		for cell in route:
			assert(cell.y >= 120)
	game.reveal_surroundings()
	assert(not game.is_discovered(game.PLACE_CELLS[0]))
	game.buy_starter()
	assert(game.has_hoe and game.has_sickle and game.seeds == 4 and game.money == 0)
	assert(game.land_tip and not game.is_discovered(game.PLACE_CELLS[0]))
	game.buy_starter()
	assert(game.seeds == 4)
	game.save_game()
	var restored = load("res://main.gd").new()
	restored.load_game()
	assert(restored.land_tip and restored.starter_bought and restored.has_hoe)
	assert(restored.discovered == game.discovered)
	restored.free()
	# Walk between trunks using open half-cell corridors; no axe or paths needed.
	for target in [Vector2(80.5, 171.5), Vector2(50.5, 171.5), Vector2(50.5, 85.5), Vector2(50, 85)]:
		walk_to(game, target)
	assert(game.location == 0 and not game.has_axe)
	assert(game.is_discovered(game.PLACE_CELLS[0]))
	game.toggle_automation()
	game.run_automation()
	assert(not game.automation_enabled and game.active_task == game.Task.NONE)
	game.money = 10
	game.buy_seed()
	assert(game.money == 10 and game.seeds == 4)
	game.use_tool(game.Task.CULTIVATING)
	assert(game.plots[0] == game.PlotState.UNTILLED and game.dig_progress[0] == 1)
	game.use_tool(game.Task.CULTIVATING)
	game.use_tool(game.Task.CULTIVATING)
	assert(game.plots[0] == game.PlotState.TILLED)
	game.use_tool(game.Task.SOWING)
	game.finish_task()
	assert(game.seeds == 3 and game.plots[0] == game.PlotState.GROWING)
	game.plots[0] = game.PlotState.READY
	game.use_tool(game.Task.HARVESTING)
	game.finish_task()
	assert(game.wheat == 1 and game.first_harvest)
	game.start_selling(false)
	assert(game.active_task == game.Task.NONE and game.money == 10 and game.wheat == 1)
	game.run_automation()
	assert(game.money == 10 and game.wheat == 1)
	if game.active_task != game.Task.NONE:
		game.finish_task()
	for target in [Vector2(50.5, 85.5), Vector2(50.5, 171.5), Vector2(80.5, 171.5), game.START_POSITION]:
		walk_to(game, target)
	assert(game.location == 1)
	game.start_selling(false)
	assert(game.active_task == game.Task.SELLING)
	game.finish_task()
	assert(game.money == 15 and game.wheat == 0)
	game.save_game()
	restored = load("res://main.gd").new()
	restored.load_game()
	assert(restored.money == 15 and restored.wheat == 0 and restored.first_harvest)
	assert(restored.is_discovered(game.PLACE_CELLS[0]))
	assert(restored.discovered == game.discovered)
	restored.free()
	game.free()
	print("PASS: harbor start, manual supplies, hidden tip, ten plots, no northern buildings/paths, forest walk round trip, farming and shop-only sales, persistence")
	quit()
