extends Control

const GROW_TIME := 120.0
const CULTIVATE_TIME := 5.0
const SOW_TIME := 3.0
const HARVEST_TIME := 3.0
const SELL_TIME := 1.0
const PLOT_UNLOCK_PRICE := 100
const SEED_PRICE := 1
const SICKLE_PRICE := 25
const AXE_PRICE := 30
const HAMMER_KIT_PRICE := 40
const HARVEST_VALUE := 5
const LOG_VALUE := 4
const SAVE_PATH := "user://carl_oskar_harbor_save.json"
const STARTER_PRICE := 39

enum PlotState { UNTILLED, TILLED, GROWING, READY, HARVESTED, BLOCKED }
enum Terrain { PLAIN, TREE, STONE, FOREST }
enum Task { NONE, CULTIVATING, SOWING, HARVESTING, SELLING, CHOPPING, BREAKING }

var money := STARTER_PRICE
var seeds := 0
var wheat := 0
var logs := 0
var has_hoe := false
var starter_bought := false
var land_tip := false
var has_sickle := false
var has_axe := false
var has_hammer_kit := false
var plots: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var planted_at: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var owned_cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
var terrain: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var active_task := Task.NONE
var task_started := 0.0
var task_plot := -1
var selling_logs := false
var automation_enabled := false

# 160 * 180 = 28,800 cells, exactly 50 times the original 32 * 18.
const WORLD_SIZE := Vector2i(160, 180)
const PLACES := ["Hidden Meadow", "Pine Landing", "Lone Cabin"]
const PLACE_CELLS := [Vector2i(50, 85), Vector2i(80, 171), Vector2i(95, 137)]
const START_POSITION := Vector2(80, 172)
const LAKES := [Vector4(15, 6, 4.5, 3.2), Vector4(80, 85, 18, 25), Vector4(115, 30, 10, 14), Vector4(35, 110, 12, 16)]
var location := 1
const WALK_SPEED := 2.8
const ROUTES := [[Vector2i(80, 171), Vector2i(80, 164)]]
var discovered: Dictionary = {}
var discovery_revision := 0
var last_discovery_cell := Vector2i(-999, -999)
var first_harvest := false
var dig_progress: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var tool_buttons: Array[Button] = []
var atlas: Control
var minimap: Control
var player_position := START_POSITION
var walking := false
var walk_save_time := 0.0
var location_label: Label
var action_button: Button
var automation_button: Button
var buy_seed_button: Button
var sickle_button: Button
var axe_button: Button
var hammer_button: Button
var land_button: Button
var starter_button: Button
var equipment_label: Label
var money_label: Label
var seed_label: Label
var log_label: Label
var status_label: Label
var progress_label: Label
var hint_label: Label
var plot_area: Control
var world_view: SubViewportContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().auto_accept_quit = false
	load_game()
	reveal_surroundings()
	build_interface()
	update_interface()

func build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#f5ead5")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 42
	layout.offset_top = 20
	layout.offset_right = -42
	layout.offset_bottom = -20
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)
	var title := Label.new()
	title.text = "CarlOskar"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#3f5d3d"))
	layout.add_child(title)
	var inventory := HBoxContainer.new()
	inventory.add_theme_constant_override("separation", 24)
	layout.add_child(inventory)
	equipment_label = make_inventory_label("", "#5d5a4f")
	inventory.add_child(equipment_label)
	seed_label = make_inventory_label("", "#4f783a")
	inventory.add_child(seed_label)
	log_label = make_inventory_label("", "#6b4931")
	inventory.add_child(log_label)
	money_label = make_inventory_label("", "#76502e")
	inventory.add_child(money_label)
	layout.add_child(HSeparator.new())
	plot_area = Control.new()
	plot_area.clip_contents = true
	plot_area.custom_minimum_size = Vector2(0, 360)
	plot_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(plot_area)
	world_view = preload("res://world_view.gd").new()
	plot_area.add_child(world_view)
	world_view.setup(self)
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color("#4a6048"))
	status_label.add_theme_font_size_override("font_size", 17)
	layout.add_child(status_label)
	progress_label = Label.new()
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label.add_theme_font_size_override("font_size", 18)
	progress_label.add_theme_color_override("font_color", Color("#76502e"))
	layout.add_child(progress_label)
	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_color_override("font_color", Color("#4a6048"))
	layout.add_child(hint_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	layout.add_child(actions)
	for entry in [["Hacka", Task.CULTIVATING], ["Frön", Task.SOWING], ["Lie", Task.HARVESTING], ["Yxa", Task.CHOPPING], ["Hammare", Task.BREAKING]]:
		var button := make_button(95, 38, 15)
		button.text = entry[0]
		button.pressed.connect(use_tool.bind(entry[1]))
		tool_buttons.append(button)
		actions.add_child(button)
	action_button = make_button(100, 38, 15)
	action_button.text = "Sälj"
	action_button.pressed.connect(func():
		if location == 1 and active_task == Task.NONE and (logs > 0 or wheat > 0):
			start_selling(logs > 0))
	actions.add_child(action_button)
	automation_button = make_button(180, 38, 14)
	automation_button.pressed.connect(toggle_automation)
	actions.add_child(automation_button)
	location_label = Label.new()
	location_label.add_theme_color_override("font_color", Color("#4a6048"))
	layout.add_child(location_label)
	var shop := VBoxContainer.new()
	shop.add_theme_constant_override("separation", 6)
	layout.add_child(shop)
	var shop_title := Label.new()
	shop_title.text = "Pine Landing • köp och sälj på plats"
	shop_title.add_theme_font_size_override("font_size", 18)
	shop_title.add_theme_color_override("font_color", Color("#3f5d3d"))
	shop.add_child(shop_title)
	starter_button = make_button(360, 36, 15)
	starter_button.text = "Köp hacka, lie och 4 fröpåsar – 39 kr"
	starter_button.pressed.connect(buy_starter)
	shop.add_child(starter_button)
	var shop_items := HBoxContainer.new()
	shop_items.add_theme_constant_override("separation", 12)
	shop.add_child(shop_items)
	buy_seed_button = make_button(155, 42, 15)
	buy_seed_button.text = "🌱 Fröpåse (1 kr)"
	buy_seed_button.pressed.connect(buy_seed)
	shop_items.add_child(buy_seed_button)
	sickle_button = make_button(160, 42, 15)
	sickle_button.pressed.connect(buy_sickle)
	shop_items.add_child(sickle_button)
	axe_button = make_button(150, 42, 15)
	axe_button.pressed.connect(buy_axe)
	shop_items.add_child(axe_button)
	hammer_button = make_button(190, 42, 15)
	hammer_button.pressed.connect(buy_hammer_kit)
	shop_items.add_child(hammer_button)
	land_button = make_button(110, 42, 14)
	land_button.text = "Mark 100 kr"
	land_button.pressed.connect(func():
		if not available_cells().is_empty():
			buy_land(available_cells()[0]))
	shop_items.add_child(land_button)
	minimap = preload("res://exploration_map.gd").new()
	minimap.setup(self, true)
	plot_area.add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.position -= Vector2(196, 170)
	minimap.size = Vector2(184, 158)
	atlas = preload("res://exploration_map.gd").new()
	atlas.setup(self, false)
	add_child(atlas)
	atlas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atlas.visible = false

func make_inventory_label(label_text: String, color: String) -> Label:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(color))
	return label

func make_button(width: float, height: float, font_size: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(width, height)
	button.add_theme_font_size_override("font_size", font_size)
	return button

func _process(_delta: float) -> void:
	update_walking(_delta)
	var state_changed := false
	for index in plots.size():
		if plots[index] == PlotState.GROWING and growth_for(index) >= 1.0:
			plots[index] = PlotState.READY
			state_changed = true
	if active_task != Task.NONE and task_progress() >= 1.0:
		finish_task()
		state_changed = true
	if automation_enabled and active_task == Task.NONE:
		run_automation()
	if state_changed:
		save_game()
	update_interface()

func now() -> float:
	return Time.get_ticks_msec() / 1000.0

func growth_for(index: int) -> float:
	return clampf((Time.get_unix_time_from_system() - planted_at[index]) / GROW_TIME, 0.0, 1.0)

func task_duration() -> float:
	match active_task:
		Task.CULTIVATING: return CULTIVATE_TIME
		Task.SOWING: return SOW_TIME
		Task.HARVESTING: return 1.0 if has_sickle else HARVEST_TIME
		Task.SELLING: return SELL_TIME
		Task.CHOPPING: return 5.0
		Task.BREAKING: return 5.0
	return 1.0

func task_progress() -> float:
	return clampf((now() - task_started) / task_duration(), 0.0, 1.0)

func start_task(task: Task, plot_index := -1) -> void:
	active_task = task
	task_plot = plot_index
	task_started = now()

func finish_task() -> void:
	match active_task:
		Task.CULTIVATING:
			plots[task_plot] = PlotState.TILLED
		Task.SOWING:
			plots[task_plot] = PlotState.GROWING
			planted_at[task_plot] = Time.get_unix_time_from_system()
			seeds -= 1
		Task.HARVESTING:
			plots[task_plot] = PlotState.HARVESTED
			wheat += 1
			first_harvest = true
		Task.SELLING:
			if selling_logs:
				logs -= 1
				money += LOG_VALUE
			else:
				wheat -= 1
				money += HARVEST_VALUE
				var sold_plot := plots.find(PlotState.HARVESTED)
				if sold_plot >= 0:
					plots[sold_plot] = PlotState.UNTILLED
		Task.CHOPPING:
			plots[task_plot] = PlotState.UNTILLED
			logs += 2 if terrain[task_plot] == Terrain.FOREST else 1
		Task.BREAKING:
			plots[task_plot] = PlotState.UNTILLED
	active_task = Task.NONE
	task_plot = -1
	selling_logs = false

func toggle_automation() -> void:
	if not first_harvest:
		return
	automation_enabled = not automation_enabled
	if automation_enabled and active_task == Task.NONE:
		run_automation()
	save_game()
	update_interface()

func run_automation() -> void:
	if not first_harvest or location != 0:
		return
	var tilled_plot := plots.find(PlotState.TILLED)
	var blocked_plot := find_clearable_block()
	if blocked_plot >= 0:
		start_task(Task.CHOPPING if terrain[blocked_plot] != Terrain.STONE else Task.BREAKING, blocked_plot)
		return
	var ready_plot := plots.find(PlotState.READY)
	if ready_plot >= 0:
		start_task(Task.HARVESTING, ready_plot)
		return
	if tilled_plot >= 0:
		if seeds > 0:
			start_task(Task.SOWING, tilled_plot)
		return
	var untilled_plot := plots.find(PlotState.UNTILLED)
	if untilled_plot >= 0:
		start_task(Task.CULTIVATING, untilled_plot)

func start_selling(should_sell_logs: bool) -> void:
	if location != 1 or active_task != Task.NONE:
		return
	if (logs if should_sell_logs else wheat) <= 0:
		return
	selling_logs = should_sell_logs
	start_task(Task.SELLING)

func can_clear(plot_index: int) -> bool:
	return has_hammer_kit if terrain[plot_index] == Terrain.STONE else has_axe

func find_clearable_block() -> int:
	for index in plots.size():
		if plots[index] == PlotState.BLOCKED and can_clear(index):
			return index
	return -1

func buy_seed() -> void:
	if location != 1 or not starter_bought:
		return
	if money >= SEED_PRICE and active_task == Task.NONE:
		money -= SEED_PRICE
		seeds += 1
		save_game()

func buy_sickle() -> void:
	if location != 1 or not starter_bought:
		return
	if money >= SICKLE_PRICE and not has_sickle and active_task == Task.NONE:
		money -= SICKLE_PRICE
		has_sickle = true
		save_game()

func buy_axe() -> void:
	if location != 1 or not starter_bought:
		return
	if money >= AXE_PRICE and not has_axe and active_task == Task.NONE:
		money -= AXE_PRICE
		has_axe = true
		save_game()

func buy_hammer_kit() -> void:
	if location != 1 or not starter_bought:
		return
	if money >= HAMMER_KIT_PRICE and not has_hammer_kit and active_task == Task.NONE:
		money -= HAMMER_KIT_PRICE
		has_hammer_kit = true
		save_game()

func terrain_for(cell: Vector2i) -> int:
	if cell in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(2, 0), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(0, 2)]:
		return Terrain.FOREST
	var pattern: int = posmod(cell.x * 73 + cell.y * 31 + 17, 100)
	if pattern < 45:
		return Terrain.PLAIN
	if pattern < 70:
		return Terrain.TREE
	if pattern < 88:
		return Terrain.STONE
	return Terrain.FOREST

func buy_land(cell: Vector2i) -> void:
	if location != 0 or active_task != Task.NONE or money < PLOT_UNLOCK_PRICE or not available_cells().has(cell):
		return
	money -= PLOT_UNLOCK_PRICE
	owned_cells.append(cell)
	var land_terrain: int = terrain_for(cell)
	terrain.append(land_terrain)
	plots.append(PlotState.BLOCKED if land_terrain != Terrain.PLAIN else PlotState.UNTILLED)
	planted_at.append(0.0)
	dig_progress.append(0)
	save_game()

func save_game() -> void:
	var cell_data: Array = []
	for cell in owned_cells:
		cell_data.append([cell.x, cell.y])
	var data := {
		"world_version": 3,
		"has_hoe": has_hoe,
		"starter_bought": starter_bought,
		"land_tip": land_tip,
		"discovered": discovered.keys(),
		"first_harvest": first_harvest,
		"dig_progress": dig_progress,
		"location": location,
		"player_position": [player_position.x, player_position.y],
		"money": money,
		"seeds": seeds,
		"wheat": wheat,
		"logs": logs,
		"plots": plots,
		"planted_at": planted_at,
		"owned_cells": cell_data,
		"terrain": terrain,
		"automation_enabled": automation_enabled,
		"has_sickle": has_sickle,
		"has_axe": has_axe,
		"has_hammer_kit": has_hammer_kit,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	location = clampi(int(data.get("location", 0)), 0, PLACES.size() - 1)
	player_position = Vector2(PLACE_CELLS[location])
	var saved_position = data.get("player_position", [])
	if saved_position is Array and saved_position.size() == 2:
		var candidate := Vector2(float(saved_position[0]), float(saved_position[1]))
		if candidate.is_finite() and can_walk(candidate):
			player_position = candidate
	update_location()
	discovered.clear()
	for key in data.get("discovered", []):
		var cell_id := int(key)
		if cell_id >= 0 and cell_id < WORLD_SIZE.x * WORLD_SIZE.y:
			discovered[cell_id] = true
	discovery_revision += 1
	last_discovery_cell = Vector2i(-999, -999)
	money = int(data.get("money", 0))
	seeds = int(data.get("seeds", 1))
	wheat = int(data.get("wheat", 0))
	logs = int(data.get("logs", 0))
	automation_enabled = bool(data.get("automation_enabled", false))
	has_hoe = bool(data.get("has_hoe", false))
	starter_bought = bool(data.get("starter_bought", false))
	land_tip = bool(data.get("land_tip", false))
	has_sickle = bool(data.get("has_sickle", false))
	has_axe = bool(data.get("has_axe", false))
	has_hammer_kit = bool(data.get("has_hammer_kit", false))
	plots.clear()
	for state in data.get("plots", [PlotState.UNTILLED]):
		plots.append(int(state))
	planted_at.clear()
	for planted_time in data.get("planted_at", [0.0]):
		planted_at.append(float(planted_time))
	owned_cells.clear()
	for cell_data in data.get("owned_cells", [[0, 0]]):
		owned_cells.append(Vector2i(int(cell_data[0]), int(cell_data[1])))
	terrain.clear()
	for terrain_type in data.get("terrain", []):
		terrain.append(int(terrain_type))
	if terrain.is_empty():
		for cell in owned_cells:
			terrain.append(Terrain.PLAIN)
	first_harvest = bool(data.get("first_harvest", wheat > 0 or plots.has(PlotState.HARVESTED)))
	automation_enabled = automation_enabled and first_harvest
	dig_progress.clear()
	for value in data.get("dig_progress", []):
		dig_progress.append(clampi(int(value), 0, 2))
	if dig_progress.size() != plots.size():
		dig_progress.resize(plots.size())
		dig_progress.fill(0)
	reveal_surroundings()
	if plots.is_empty() or plots.size() != owned_cells.size() or terrain.size() != owned_cells.size() or planted_at.size() != plots.size():
		reset_game(false)

func reset_game(save_after_reset := true) -> void:
	location = 1
	player_position = START_POSITION
	walking = false
	first_harvest = false
	dig_progress = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	discovered.clear()
	last_discovery_cell = Vector2i(-999, -999)
	reveal_surroundings()
	if is_instance_valid(atlas):
		atlas.hide()
	money = STARTER_PRICE
	seeds = 0
	wheat = 0
	logs = 0
	plots = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	planted_at = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	owned_cells = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
	terrain = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	automation_enabled = false
	has_hoe = false
	starter_bought = false
	land_tip = false
	has_sickle = false
	has_axe = false
	has_hammer_kit = false
	active_task = Task.NONE
	task_plot = -1
	if save_after_reset:
		save_game()
	if is_instance_valid(action_button):
		update_interface()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and is_instance_valid(atlas):
		if event.keycode == KEY_F2:
			atlas.toggle_map(event.shift_pressed)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and atlas.visible:
			atlas.hide()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		reset_game()
		get_viewport().set_input_as_handled()

func update_interface() -> void:
	if not is_instance_valid(money_label):
		return
	equipment_label.text = "Hacka • Lie" if has_hoe and has_sickle else "Inga verktyg"
	money_label.text = "Pengar: %d kr" % money
	seed_label.text = "Fröer: %d" % seeds
	log_label.text = "Stockar: %d • Vete: %d" % [logs, wheat]
	status_label.text = "Mark: %d • Växer: %d • Skördeklar: %d" % [plots.size(), plots.count(PlotState.GROWING), plots.count(PlotState.READY)]
	progress_label.text = "Välj ett verktyg för att arbeta hemma."
	if active_task != Task.NONE:
		progress_label.text = "%s: %d %%" % [["", "Kultiverar", "Sår", "Skördar", "Säljer", "Fäller", "Spräcker sten"][active_task], roundi(task_progress() * 100)]
	hint_label.text = "F2: upptäcktskarta • Shift+F2: hela kartan • WASD/pilar: gå"
	if not first_harvest:
		var index := plots.find(PlotState.UNTILLED)
		hint_label.text += " • Första skörden låser upp automation."
		if index >= 0:
			progress_label.text += " Hacktag: %d/3." % dig_progress[index]
	for i in tool_buttons.size():
		tool_buttons[i].disabled = location != 0 or active_task != Task.NONE or automation_enabled
	tool_buttons[0].disabled = tool_buttons[0].disabled or not has_hoe
	tool_buttons[2].disabled = tool_buttons[2].disabled or not has_sickle
	tool_buttons[3].disabled = tool_buttons[3].disabled or not has_axe
	tool_buttons[4].disabled = tool_buttons[4].disabled or not has_hammer_kit
	action_button.disabled = location != 1 or active_task != Task.NONE or (wheat == 0 and logs == 0) or automation_enabled
	automation_button.text = ("Automation: PÅ" if automation_enabled else "Starta automation") if first_harvest else "Låst: första skörden"
	automation_button.disabled = not first_harvest or location != 0
	land_button.disabled = location != 0 or active_task != Task.NONE or money < PLOT_UNLOCK_PRICE
	buy_seed_button.disabled = location != 1 or not starter_bought or money < SEED_PRICE or active_task != Task.NONE
	sickle_button.text = "Lie (ägs)" if has_sickle else "Lie (25 kr)"
	sickle_button.disabled = location != 1 or not starter_bought or has_sickle or money < SICKLE_PRICE or active_task != Task.NONE
	axe_button.text = "Yxa (ägs)" if has_axe else "Yxa (30 kr)"
	axe_button.disabled = location != 1 or not starter_bought or has_axe or money < AXE_PRICE or active_task != Task.NONE
	hammer_button.text = "Hammare (ägs)" if has_hammer_kit else "Hammare (40 kr)"
	hammer_button.disabled = location != 1 or not starter_bought or has_hammer_kit or money < HAMMER_KIT_PRICE or active_task != Task.NONE
	starter_button.visible = not starter_bought
	starter_button.disabled = location != 1 or active_task != Task.NONE or money < STARTER_PRICE
	if not starter_bought:
		progress_label.text = "Välkommen till Pine Landing. Köp startutrustningen i butiken."
	elif wheat > 0:
		progress_label.text = "Bär skörden till Pine Landing och sälj den i hamnbutiken."
	elif location != 0 and land_tip:
		progress_label.text = "Handlaren: En obebodd glänta finns åt nordväst. Följ den röda pricken på F2-kartan."
	location_label.text = "Plats: %s" % (PLACES[location] if location >= 0 else "Minnesota wilderness")

func use_tool(task: Task) -> void:
	if location != 0 or active_task != Task.NONE or automation_enabled:
		return
	var index := -1
	match task:
		Task.CULTIVATING:
			if not has_hoe:
				return
			index = plots.find(PlotState.UNTILLED)
			if index >= 0 and not first_harvest:
				dig_progress[index] += 1
				if dig_progress[index] >= 3:
					plots[index] = PlotState.TILLED
					dig_progress[index] = 0
				save_game()
				return
		Task.SOWING:
			if seeds > 0:
				index = plots.find(PlotState.TILLED)
		Task.HARVESTING:
			if not has_sickle:
				return
			index = plots.find(PlotState.READY)
		Task.CHOPPING, Task.BREAKING:
			for i in plots.size():
				if plots[i] == PlotState.BLOCKED and can_clear(i) and (terrain[i] == Terrain.STONE) == (task == Task.BREAKING):
					index = i
					break
	if index >= 0:
		start_task(task, index)

func available_cells() -> Array[Vector2i]:
	var available: Array[Vector2i] = []
	for cell in owned_cells:
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var candidate: Vector2i = cell + direction
			if not owned_cells.has(candidate) and not available.has(candidate):
				available.append(candidate)
	available.sort_custom(func(a: Vector2i, b: Vector2i): return a.x + a.y < b.x + b.y)
	return available

func on_path(point: Vector2) -> bool:
	for route in ROUTES:
		for i in range(route.size() - 1):
			var nearest := Geometry2D.get_closest_point_to_segment(point, Vector2(route[i]), Vector2(route[i + 1]))
			if point.distance_to(nearest) < 0.65:
				return true
	return false

func is_lake(point: Vector2) -> bool:
	if point.y >= 173:
		return true
	for lake in LAKES:
		if pow((point.x - lake.x) / lake.z, 2) + pow((point.y - lake.y) / lake.w, 2) < 1.0:
			return true
	return false

func is_clearing(point: Vector2) -> bool:
	for place in PLACE_CELLS:
		if point.distance_to(Vector2(place)) < 2.8:
			return true
	return false

func tree_at(cell: Vector2i) -> bool:
	var p := Vector2(cell)
	return not is_lake(p) and not is_clearing(p) and not on_path(p) and posmod(cell.x * 73 + cell.y * 31, 10) < 7

func on_dock(p: Vector2) -> bool:
	return p.x >= 79.5 and p.x <= 80.5 and p.y >= 171 and p.y <= 176

func can_walk(point: Vector2) -> bool:
	if point.x < 2 or point.x > WORLD_SIZE.x - 3 or point.y < 2 or point.y > WORLD_SIZE.y - 3:
		return false
	if on_dock(point):
		return true
	if is_lake(point):
		return false
	# Trees block only their trunks. The spaces between them remain walkable.
	var cell := Vector2i(point.round())
	if tree_at(cell) and point.distance_to(Vector2(cell)) < 0.22:
		return false
	return true

func update_location() -> void:
	location = -1
	for i in PLACES.size():
		if player_position.distance_to(Vector2(PLACE_CELLS[i])) < 2.5:
			location = i
			return

func move_player(direction: Vector2, delta: float) -> void:
	var motion := direction.normalized() * WALK_SPEED * minf(delta, 0.05)
	var next := player_position + Vector2(motion.x, 0)
	if can_walk(next):
		player_position = next
	next = player_position + Vector2(0, motion.y)
	if can_walk(next):
		player_position = next
	update_location()
	reveal_surroundings()

func update_walking(delta: float) -> void:
	var direction := Vector2.ZERO
	if active_task == Task.NONE and not (is_instance_valid(atlas) and atlas.visible):
		direction.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		direction.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var was_walking := walking
	walking = direction != Vector2.ZERO
	if walking:
		automation_enabled = false
		move_player(direction, delta)
		walk_save_time += delta
	if (was_walking and not walking) or walk_save_time >= 1.0:
		walk_save_time = 0.0
		save_game()

func reveal_surroundings() -> void:
	var center := Vector2i(player_position.round())
	if center == last_discovery_cell:
		return
	last_discovery_cell = center
	for y in range(maxi(0, center.y - 3), mini(WORLD_SIZE.y, center.y + 4)):
		for x in range(maxi(0, center.x - 3), mini(WORLD_SIZE.x, center.x + 4)):
			if Vector2(x, y).distance_to(Vector2(center)) <= 3.0:
				discovered[y * WORLD_SIZE.x + x] = true
	discovery_revision += 1

func is_discovered(cell: Vector2i) -> bool:
	return discovered.has(cell.y * WORLD_SIZE.x + cell.x)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()

func buy_starter() -> void:
	if location != 1 or starter_bought or active_task != Task.NONE or money < STARTER_PRICE:
		return
	money -= STARTER_PRICE
	has_hoe = true
	has_sickle = true
	seeds += 4
	starter_bought = true
	land_tip = true
	save_game()
