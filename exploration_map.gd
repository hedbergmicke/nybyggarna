extends Control
var game: Control
var small := false
var reveal_all := false
var terrain_image: Image
var map_texture: ImageTexture
var displayed_image: Image
var last_revision := -1
var last_reveal := false

func setup(owner_game: Control, is_small: bool) -> void:
	game = owner_game
	small = is_small
	mouse_filter = Control.MOUSE_FILTER_IGNORE if small else Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terrain_image = Image.create(game.WORLD_SIZE.x, game.WORLD_SIZE.y, false, Image.FORMAT_RGB8)
	for y in game.WORLD_SIZE.y:
		for x in game.WORLD_SIZE.x:
			var p := Vector2(x, y)
			var color := Color("#426444") if posmod(x * 73 + y * 31, 10) < 7 else Color("#526d47")
			if game.on_dock(p):
				color = Color("#d1b782")
			elif game.is_lake(p):
				color = Color("#5e9dab")
			elif x < 2 or y < 2 or x > game.WORLD_SIZE.x - 3 or y > game.WORLD_SIZE.y - 3:
				color = Color("#8b8a7c")
			elif game.on_path(p):
				color = Color("#d1b782")
			elif game.is_clearing(p):
				color = Color("#9d9b62")
			terrain_image.set_pixel(x, y, color)
	refresh_texture()

func toggle_map(uncovered: bool) -> void:
	if visible and reveal_all == uncovered:
		hide()
	else:
		reveal_all = uncovered
		show()
		refresh_texture()

func refresh_texture() -> void:
	if last_revision == game.discovery_revision and last_reveal == reveal_all:
		return
	last_revision = game.discovery_revision
	last_reveal = reveal_all
	var fogged := Image.create(game.WORLD_SIZE.x, game.WORLD_SIZE.y, false, Image.FORMAT_RGB8)
	fogged.fill(Color.BLACK)
	if reveal_all and not small:
		fogged = terrain_image.duplicate()
	else:
		for key in game.discovered:
			var x: int = int(key) % game.WORLD_SIZE.x
			var y: int = int(key) / game.WORLD_SIZE.x
			fogged.set_pixel(x, y, terrain_image.get_pixel(x, y))
	displayed_image = fogged
	if map_texture == null:
		map_texture = ImageTexture.create_from_image(fogged)
	else:
		map_texture.update(fogged)

func _process(_delta: float) -> void:
	if visible:
		refresh_texture()
		queue_redraw()

func _draw() -> void:
	if map_texture == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#101919"))
	var area: Rect2
	var region: Rect2
	if small:
		area = Rect2(6, 24, size.x - 12, size.y - 30)
		region = Rect2(game.player_position - Vector2(12, 9), Vector2(24, 18))
		# Pad world edges with darkness rather than repeat the texture.
		var clipped := region.intersection(Rect2(Vector2.ZERO, Vector2(game.WORLD_SIZE)))
		var target := Rect2(area.position + (clipped.position - region.position) / region.size * area.size, clipped.size / region.size * area.size)
		draw_texture_rect_region(map_texture, target, clipped)
		draw_string(ThemeDB.fallback_font, Vector2(8, 17), "MINIMAP • N ↑ • F2", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#f4dfad"))
	else:
		var scale_factor := minf((size.x - 80) / game.WORLD_SIZE.x, (size.y - 120) / game.WORLD_SIZE.y)
		var map_size: Vector2 = Vector2(game.WORLD_SIZE) * scale_factor
		area = Rect2((size - map_size) * 0.5 + Vector2(0, 10), map_size)
		region = Rect2(Vector2.ZERO, Vector2(game.WORLD_SIZE))
		draw_texture_rect(map_texture, area, false)
		draw_string(ThemeDB.fallback_font, Vector2(30, 36), "MINNESOTA • " + ("Hela kartan (tillfällig vy)" if reveal_all else "Upptäckta områden"), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#f4dfad"))
		draw_string(ThemeDB.fallback_font, Vector2(30, size.y - 24), "F2: upptäckt • Shift+F2: visa allt • Esc: stäng", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#f4dfad"))
	var label_rects: Array[Rect2] = []
	for i in game.PLACES.size():
		var cell: Vector2i = game.PLACE_CELLS[i]
		if not (reveal_all and not small) and not game.is_discovered(cell):
			continue
		var pos := area.position + (Vector2(cell) + Vector2(0.5, 0.5) - region.position) / region.size * area.size
		if not area.has_point(pos):
			continue
		draw_circle(pos, 3, Color("#e1b86e"))
		if not small:
			var text_size := ThemeDB.fallback_font.get_string_size(game.PLACES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
			var label_pos := pos + Vector2(6, -5)
			for offset in [Vector2(6, -5), Vector2(6, 18), Vector2(-text_size.x - 8, -5), Vector2(-text_size.x - 8, 18), Vector2(6, 36)]:
				var candidate := Rect2(pos + offset - Vector2(0, 14), Vector2(text_size.x, 18))
				var overlaps := false
				for used in label_rects:
					if candidate.intersects(used):
						overlaps = true
				if not overlaps:
					label_pos = pos + offset
					label_rects.append(candidate)
					break
			draw_string(ThemeDB.fallback_font, label_pos, game.PLACES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#f4dfad"))
	# A trader's tip is a marker, not an exploration reveal.
	if not small and game.land_tip:
		var tip: Vector2 = area.position + (Vector2(game.PLACE_CELLS[0]) + Vector2(0.5, 0.5) - region.position) / region.size * area.size
		draw_circle(tip, 6, Color("#ec4444"))
		draw_arc(tip, 8, 0, TAU, 24, Color("#ffd1b3"), 1.5)
		draw_string(ThemeDB.fallback_font, tip + Vector2(12, 18), "Obebodd mark • handlarens tips", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ff9696"))
	var player: Vector2 = area.position + (game.player_position + Vector2(0.5, 0.5) - region.position) / region.size * area.size
	draw_circle(player, 4, Color("#ffdd57"))
	draw_arc(player, 6, 0, TAU, 20, Color.WHITE, 1.5)
	draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2), Color("#aa9670"), false, 2)
