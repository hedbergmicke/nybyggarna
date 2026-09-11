extends SubViewportContainer
# A real-time 3D presentation of the same persistent gameplay coordinates.
const UNIT := 3.0
var game: Control
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var farmer: Node3D
var left_leg: Node3D
var right_leg: Node3D
var fields: Node3D
var field_signature := ""
var materials := {}
var chunks := {}
var nature = preload("res://graphics/nature_meshes.gd").new()
var water_material: ShaderMaterial
var timber_material: ShaderMaterial
var held_hoe: Node3D
var last_chunk := Vector2i(-999, -999)

func setup(owner_game: Control) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#6e9db4")
	sky_material.sky_horizon_color = Color("#e4ceac")
	sky_material.ground_horizon_color = Color("#cbb991")
	sky_material.ground_bottom_color = Color("#4e5c45")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_color = Color("#879eab")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c2d8e0")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.ssao_enabled = true
	environment.ssao_radius = 1.3
	environment.ssao_intensity = 1.6
	environment.ssil_enabled = true
	environment.ssil_intensity = 0.5
	environment.ssr_enabled = true
	environment.glow_enabled = true
	environment.glow_intensity = 0.22
	environment.glow_hdr_threshold = 2.0
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.004
	environment.volumetric_fog_length = 64
	environment.volumetric_fog_albedo = Color("#c6cfbe")
	var atmosphere := WorldEnvironment.new()
	atmosphere.environment = environment
	world.add_child(atmosphere)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_color = Color("#ffe3b2")
	sun.light_energy = 1.65
	sun.light_angular_distance = 1.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110
	world.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15
	camera.far = 180
	world.add_child(camera)
	camera.current = true
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://graphics/lake_water.gdshader")
	timber_material = ShaderMaterial.new()
	timber_material.shader = load("res://graphics/timber.gdshader")
	build_landscape()
	build_farmer()
	fields = Node3D.new()
	world.add_child(fields)
	sync_fields()
	follow_camera()

func material(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.88
		materials[color] = mat
	return materials[color]

func mesh_node(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = material(color)
	item.position = pos
	parent.add_child(item)
	return item

func box(parent: Node3D, pos: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = dimensions
	return mesh_node(parent, shape, pos, color)

func ball(parent: Node3D, pos: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radial_segments = 24
	shape.rings = 12
	var item := mesh_node(parent, shape, pos, color)
	item.scale = dimensions
	return item

func cone(parent: Node3D, pos: Vector3, bottom: float, top: float, height: float, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = 10
	return mesh_node(parent, shape, pos, color)

func point(cell: Vector2, height := 0.0) -> Vector3:
	return Vector3(cell.x * UNIT, height, cell.y * UNIT)

func build_landscape() -> void:
	var ground := box(world, Vector3(game.WORLD_SIZE.x * UNIT * 0.5, -0.3, game.WORLD_SIZE.y * UNIT * 0.5), Vector3(game.WORLD_SIZE.x * UNIT + 12, 0.6, game.WORLD_SIZE.y * UNIT + 12), Color("#788653"))
	var soil := ShaderMaterial.new()
	soil.shader = load("res://graphics/forest_floor.gdshader")
	ground.material_override = soil
	for lake in game.LAKES:
		var shore := cone(world, point(Vector2(lake.x, lake.y), 0.015), 1, 1, 0.025, Color("#b6ab79"))
		(shore.mesh as CylinderMesh).radial_segments = 96
		shore.scale = Vector3(lake.z * UNIT + 0.9, 1, lake.w * UNIT + 0.9)
		var water := cone(world, point(Vector2(lake.x, lake.y), 0.04), 1, 1, 0.025, Color("#599aa5"))
		(water.mesh as CylinderMesh).radial_segments = 96
		water.material_override = water_material
		water.scale = Vector3(lake.z * UNIT, 1, lake.w * UNIT)
	box(world, point(Vector2(80, 177), 0.04), Vector3(game.WORLD_SIZE.x * UNIT, 0.05, 24), Color("#599aa5")).material_override = water_material
	# A timber pier extends from the southern shore into the harbor water.
	for board in 30:
		var plank := box(world, point(Vector2(80, 171 + board / 6.0), 0.16 + sin(board*5.0)*0.012), Vector3(3.0, 0.18, 0.44), Color("#97764d"))
		plank.material_override = timber_material
		for nail_x in [-1.25, 1.25]:
			cone(world, point(Vector2(80, 171 + board / 6.0), 0.26) + Vector3(nail_x,0,0), 0.025, 0.025, 0.012, Color("#4a4339"))
	for y in [172, 174, 176]:
		for x in [79.55, 80.45]:
			cone(world, point(Vector2(x, y), 0.35), 0.12, 0.12, 1.2, Color("#6d5139"))
	var boat := point(Vector2(81.3, 174.5), 0.25)
	ball(world, boat, Vector3(1.8, 0.65, 4.2), Color("#74513a"))
	ball(world, boat + Vector3(0, 0.2, 0), Vector3(1.35, 0.3, 3.5), Color("#b19767"))
	box(world, boat + Vector3(0, 0.35, 0), Vector3(1.6, 0.14, 0.35), Color("#6d5139"))
	for route in game.ROUTES:
		for i in range(route.size() - 1):
			var a := Vector2(route[i])
			var b := Vector2(route[i + 1])
			box(world, point((a + b) * 0.5, 0.025), Vector3(absf(a.x - b.x) * UNIT + 3.6, 0.04, absf(a.y - b.y) * UNIT + 3.6), Color("#baa87c"))
	for i in game.PLACES.size():
		var pos := point(Vector2(game.PLACE_CELLS[i]))
		var label := Label3D.new()
		label.text = game.PLACES[i]
		label.font_size = 44
		label.pixel_size = 0.016
		label.position = pos + Vector3(0, 3.8, -1)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("#fff0cb")
		world.add_child(label)
		if i > 0:
			cottage(pos + Vector3(-2.4, 0, -5.1), i == 1)


func cottage(pos: Vector3, shop: bool) -> void:
	box(world, pos + Vector3(0, 1.25, 0), Vector3(3.6, 2.5, 2.7), Color("#9a5145"))
	for side in [-1, 1]:
		var roof := box(world, pos + Vector3(side * 0.95, 2.9, 0), Vector3(2.3, 0.22, 3.2), Color("#594e43"))
		roof.rotation.z = side * -0.48
		box(world, pos + Vector3(side * 1.13, 1.45, 1.37), Vector3(0.65, 0.8, 0.08), Color("#f6d698"))
	box(world, pos + Vector3(0, 0.75, 1.4), Vector3(0.75, 1.5, 0.12), Color("#594536"))
	box(world, pos + Vector3(0.8, 3.3, -0.6), Vector3(0.5, 1.5, 0.5), Color("#7b7770"))
	for plank in 14:
		var siding := box(world,pos+Vector3(0,0.12+plank*0.17,1.37),Vector3(3.68,0.13,0.09),Color("#80614a"))
		siding.material_override = timber_material
	for side in [-1,1]:
		box(world,pos+Vector3(side*1.13,1.45,1.45),Vector3(0.72,0.88,0.1),Color("#cbbd99"))
		var pane := box(world,pos+Vector3(side*1.13,1.45,1.52),Vector3(0.53,0.66,0.03),Color("#e4af56"))
		var warm := StandardMaterial3D.new()
		warm.albedo_color = Color("#d3a15b")
		warm.emission_enabled = true
		warm.emission = Color("#f5af4e")
		warm.emission_energy_multiplier = 0.7
		pane.material_override = warm
		box(world,pos+Vector3(side*1.13,1.45,1.55),Vector3(0.04,0.7,0.04),Color("#5c4935"))
		box(world,pos+Vector3(side*1.13,1.45,1.55),Vector3(0.56,0.04,0.04),Color("#5c4935"))
	for shingle in 12:
		for side in [-1,1]:
			var strip := box(world,pos+Vector3(side*0.95,3.06,-1.45+shingle*0.26),Vector3(2.3,0.04,0.23),Color("#4b504b").lightened((shingle%3)*0.025))
			strip.rotation.z = side*-0.48
	box(world,pos+Vector3(0,0.13,1.8),Vector3(2.2,0.25,0.7),Color("#6f6655"))
	box(world,pos+Vector3(0,0.06,2.2),Vector3(2.5,0.12,0.45),Color("#7f7761"))
	if shop:
		var sign := Label3D.new()
		sign.text = "PINE LANDING • TRADING POST"
		sign.position = pos + Vector3(0, 2.25, 1.5)
		sign.font_size = 32
		sign.pixel_size = 0.006
		world.add_child(sign)

func build_farmer() -> void:
	farmer = Node3D.new()
	world.add_child(farmer)
	left_leg = Node3D.new()
	right_leg = Node3D.new()
	for leg in [left_leg, right_leg]:
		farmer.add_child(leg)
		leg.position = Vector3(-0.19 if leg == left_leg else 0.19, 0.65, 0)
		box(leg, Vector3(0, -0.25, 0), Vector3(0.25, 0.5, 0.28), Color("#6c5943"))
		ball(leg, Vector3(0, -0.53, 0.09), Vector3(0.33, 0.23, 0.48), Color("#4b3c32"))
	ball(farmer, Vector3(0, 0.98, 0), Vector3(0.78, 0.9, 0.5), Color("#608da7"))
	ball(farmer, Vector3(0, 1.65, 0), Vector3(0.68, 0.72, 0.64), Color("#e5b78b"))
	ball(farmer, Vector3(0, 1.92, 0), Vector3(0.72, 0.3, 0.69), Color("#a84d3d"))
	box(farmer, Vector3(0, 1.86, 0.3), Vector3(0.55, 0.08, 0.28), Color("#a84d3d"))
	for side in [-1, 1]:
		ball(farmer, Vector3(side * 0.43, 0.95, 0), Vector3(0.25, 0.65, 0.28), Color("#608da7"))
		ball(farmer, Vector3(side * 0.44, 0.67, 0), Vector3(0.22, 0.25, 0.23), Color("#e5b78b"))
	for side in [-1,1]:
		ball(farmer,Vector3(side*0.15,1.68,0.285),Vector3(0.07,0.08,0.04),Color("#39362c"))
		box(farmer,Vector3(side*0.2,1.0,0.24),Vector3(0.07,0.58,0.025),Color("#684d33"))
	ball(farmer,Vector3(0,1.58,0.34),Vector3(0.13,0.13,0.13),Color("#c9956b"))
	box(farmer,Vector3(0,0.71,0.18),Vector3(0.6,0.09,0.1),Color("#4f3d2b"))
	box(farmer,Vector3(0,0.71,0.245),Vector3(0.13,0.095,0.025),Color("#bba366"))
	held_hoe = Node3D.new()
	farmer.add_child(held_hoe)
	held_hoe.position = Vector3(0.48,0.68,0.05)
	var shaft := cone(held_hoe,Vector3(0,0,0.24),0.025,0.025,1.3,Color("#80633c"))
	shaft.rotation.x = 0.65
	box(held_hoe,Vector3(0,-0.5,0.61),Vector3(0.32,0.07,0.15),Color("#798588"))

func sync_fields() -> void:
	var signature := str(game.plots) + str(game.dig_progress)
	if field_signature == signature:
		return
	field_signature = signature
	for child in fields.get_children():
		child.free()
	for i in game.plots.size():
		var cell: Vector2i = game.owned_cells[i]
		var pos := point(Vector2(game.PLACE_CELLS[0])) + Vector3(cell.x * 1.05 - 2.1, 0.07, cell.y * 1.05 - 0.5)
		box(fields, pos, Vector3(0.97, 0.08, 0.97), Color("#513928") if game.plots[i] != game.PlotState.UNTILLED else Color("#93a868"))
		if game.plots[i] == game.PlotState.TILLED or game.dig_progress[i] > 0:
			for row in (3 if game.plots[i] == game.PlotState.TILLED else game.dig_progress[i]):
				box(fields, pos + Vector3(row * 0.25 - 0.25, 0.055, 0), Vector3(0.08, 0.04, 0.8), Color("#382a1e"))
		if game.plots[i] == game.PlotState.BLOCKED:
			if game.terrain[i] == game.Terrain.STONE:
				ball(fields, pos + Vector3(0, 0.25, 0), Vector3(0.7, 0.6, 0.7), Color("#687773"))
			else:
				cone(fields, pos + Vector3(0, 0.65, 0), 0.4, 0, 1.2, Color("#365d46"))
		if game.plots[i] in [game.PlotState.GROWING, game.PlotState.READY]:
			for sprout in 6:
				cone(fields, pos + Vector3((sprout % 3) * 0.25 - 0.25, 0.24, (sprout / 3) * 0.3 - 0.2), 0.09, 0.03, 0.4, Color("#d1b459") if game.plots[i] == game.PlotState.READY else Color("#91aa52"))

func follow_camera() -> void:
	var focus := point(game.player_position, 0.65) + Vector3(0, 0, -1.2)
	farmer.position = point(game.player_position)
	camera.position = focus + Vector3(0, 19, 16)
	camera.look_at(focus)

func _process(_delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(farmer):
		return
	stream_landscape()
	var previous := Vector2(farmer.position.x, farmer.position.z)
	var next: Vector2 = game.player_position * UNIT
	if previous.distance_to(next) > 0.001:
		var direction := next - previous
		farmer.rotation.y = atan2(direction.x, direction.y)
	held_hoe.visible = game.has_hoe
	held_hoe.rotation.x = sin(game.now()*9)*0.35 if game.active_task == game.Task.CULTIVATING else 0.0
	left_leg.rotation.x = sin(game.now() * 12) * 0.45 if game.walking else 0.0
	right_leg.rotation.x = -left_leg.rotation.x
	follow_camera()
	sync_fields()

# Only nearby 8x8 chunks have scene nodes; geography is deterministic on revisit.
func stream_landscape() -> void:
	var center := Vector2i(floori(game.player_position.x / 8), floori(game.player_position.y / 8))
	if center == last_chunk:
		return
	last_chunk = center
	var wanted := {}
	for y in range(maxi(0, center.y - 1), mini(ceili(game.WORLD_SIZE.y / 8.0), center.y + 2)):
		for x in range(maxi(0, center.x - 1), mini(ceili(game.WORLD_SIZE.x / 8.0), center.x + 2)):
			var chunk := Vector2i(x, y)
			wanted[chunk] = true
			if not chunks.has(chunk):
				var holder := Node3D.new()
				world.add_child(holder)
				chunks[chunk] = holder
				build_chunk(chunk, holder)
	for chunk in chunks.keys():
		if not wanted.has(chunk):
			chunks[chunk].queue_free()
			chunks.erase(chunk)

func build_chunk(chunk: Vector2i, holder: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 731204 + chunk.x * 73856093 + chunk.y * 19349663
	for y in range(chunk.y * 8, mini(chunk.y * 8 + 8, game.WORLD_SIZE.y)):
		for x in range(chunk.x * 8, mini(chunk.x * 8 + 8, game.WORLD_SIZE.x)):
			var cell := Vector2(x, y)
			var pos := point(cell)
			if game.is_lake(cell):
				continue
			if x < 2 or x > game.WORLD_SIZE.x - 3 or y < 2 or y > game.WORLD_SIZE.y - 3:
				var rock := ball(holder, pos + Vector3(0, 1.1, 0), Vector3(4.5, rng.randf_range(3.0, 6.5), 4.0), Color("#687773"))
				rock.rotation.y = rng.randf_range(0, TAU)
			elif game.tree_at(Vector2i(cell)):
				var height := rng.randf_range(0.85,1.22)
				var kind := 1 if (x+y)%3 == 0 else 0
				cone(holder,pos+Vector3(0,1.6*height,0),0.17,0.07,3.2*height,Color("#b5b3a0") if kind == 1 else Color("#594630"))
				var crown := MeshInstance3D.new()
				crown.mesh = nature.tree_mesh(kind,posmod(x+y,4))
				crown.position = pos
				crown.scale = Vector3.ONE*height
				crown.rotation.y = rng.randf_range(0,TAU)
				holder.add_child(crown)
				if kind == 1:
					for scar in 4:
						box(holder,pos+Vector3(0,0.5+scar*0.45,0.155),Vector3(0.22,0.045,0.015),Color("#58594e"))
			elif not game.on_path(cell) and not game.is_clearing(cell) and rng.randf() < 0.3:
				var stone := ball(holder,pos+Vector3(0.4,0.12,0.4),Vector3(0.5,0.32,0.7),Color("#727769"))
				stone.rotation = Vector3(0.2,rng.randf_range(0,TAU),0.2)
	add_ground_cover(chunk,holder)

func add_ground_cover(chunk: Vector2i, holder: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 812 + chunk.x*731 + chunk.y*931
	var transforms: Array[Transform3D] = []
	for i in 1500:
		var cell := Vector2(chunk.x*8+rng.randf_range(0,8),chunk.y*8+rng.randf_range(0,8))
		if cell.x >= game.WORLD_SIZE.x-2 or cell.y >= game.WORLD_SIZE.y-2 or cell.x < 2 or cell.y < 2 or game.is_lake(cell) or game.on_path(cell) or game.on_dock(cell):
			continue
		if cell.distance_to(Vector2(game.PLACE_CELLS[0])) < 1.2:
			continue
		var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*rng.randf_range(0.6,1.4))
		transforms.append(Transform3D(basis,point(cell,0.04)))
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = nature.grass_mesh()
	batch.instance_count = transforms.size()
	for i in transforms.size():
		batch.set_instance_transform(i,transforms[i])
	var cover := MultiMeshInstance3D.new()
	cover.multimesh = batch
	cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(cover)
