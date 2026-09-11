extends RefCounted
var templates := {}
var leaf_material: ShaderMaterial

func _init() -> void:
	leaf_material = ShaderMaterial.new()
	leaf_material.shader = load("res://graphics/foliage.gdshader")

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.set_color(color.lightened(0.035))
	st.add_vertex(b)
	st.set_color(color.darkened(0.06))
	st.add_vertex(c)

func leaf_cluster(st: SurfaceTool, pos: Vector3, extent: Vector3, color: Color, rng: RandomNumberGenerator) -> void:
	var ring: Array[Vector3] = []
	for i in 12:
		var angle := i*TAU/12.0
		ring.append(pos+Vector3(cos(angle)*extent.x,rng.randf_range(-0.06,0.06),sin(angle)*extent.z))
	var top := pos+Vector3(0,extent.y,0)
	var bottom := pos-Vector3(0,extent.y*0.7,0)
	for i in 12:
		triangle(st,ring[i],ring[(i+1)%12],top,color)
		triangle(st,ring[(i+1)%12],ring[i],bottom,color)
	# Small leaf silhouettes break up the bough surface instead of giant facets.
	for leaf in 36:
		var angle := rng.randf_range(0,TAU)
		var latitude := rng.randf_range(-0.8,0.8)
		var normal := Vector3(cos(angle)*cos(latitude),sin(latitude),sin(angle)*cos(latitude))
		var center := pos+normal*extent*1.03
		var tangent := normal.cross(Vector3.UP).normalized()*0.13
		var up := normal.cross(tangent).normalized()*0.20
		triangle(st,center-tangent,center+tangent,center+up,color.lightened(rng.randf_range(-0.04,0.04)))

func tree_mesh(kind: int, variant: int) -> ArrayMesh:
	var key := Vector2i(kind,variant)
	if templates.has(key):
		return templates[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1937 + kind*53 + variant*137
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	if kind == 0:
		for level in 6:
			var height := 1.4 + level*0.48
			var radius := 1.22 - level*0.16
			for arm in 7:
				var angle := arm*TAU/7.0 + level*1.3
				var center := Vector3(cos(angle)*radius*0.5,height,sin(angle)*radius*0.5)
				leaf_cluster(st,center,Vector3(radius*0.64,0.38,radius*0.64),Color("#284c35").lightened(level*0.013),rng)
		leaf_cluster(st,Vector3(0,4.2,0),Vector3(0.25,0.5,0.25),Color("#477342"),rng)
	else:
		for cluster in 28:
			var center := Vector3(rng.randf_range(-1,1),rng.randf_range(2.1,4.4),rng.randf_range(-1,1))
			leaf_cluster(st,center,Vector3(0.65,0.5,0.65),Color("#547534").lightened(rng.randf_range(-0.12,0.09)),rng)
	st.generate_normals()
	var result := st.commit()
	result.surface_set_material(0,leaf_material)
	templates[key]=result
	return result

func grass_mesh() -> ArrayMesh:
	if templates.has("grass"):
		return templates["grass"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for blade in 5:
		var angle := blade*2.4
		var base := Vector3(cos(angle)*0.08,0,sin(angle)*0.08)
		triangle(st,base+Vector3(-0.035,0,0),base+Vector3(0.035,0,0),base+Vector3(cos(angle)*0.12,0.22+blade*0.045,sin(angle)*0.12),Color("#6a813c"))
	st.generate_normals()
	var result := st.commit()
	result.surface_set_material(0,leaf_material)
	templates["grass"]=result
	return result
