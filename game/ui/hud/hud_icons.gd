extends RefCounted
## The icons drawn in code (leaf, log, shard, tick, gem) and the cache of icon pictures. A part of the HUD (hud.gd).

const UiIcons := preload("res://scripts/ui_icons.gd")           # Phase G2: the shop tiles' pictures
## The ids icon() draws here; every other id is a shop tile's picture from ui_icons.gd.
const OWN_ICONS := ["leaves", "timber", "shards", "shard", "amber", "tick", "todo"]

var hud                                 # the HUD node (untyped on purpose: hud._stage_l and the rest are read at run time)
var _icons := {}
var _pictures := {}                     # G3: res:// path -> its texture (null when the file is not there)


func _init(h) -> void:
	hud = h


## An icon, made once in code and kept: a currency (leaves, timber, shards, amber), a goal's
## mark ("tick", "todo"), or a shop tile's picture (Phase G2, ui_icons.gd: "bow", "target", "heart", "tower", ...).
## A Texture2D is used as it is (the bows' pictures, G3). An unknown id gives a plain round disc (a tile writes its
## title's first letter on it).
func icon(k) -> Texture2D:
	if k is Texture2D:
		return k
	var id := str(k)
	match id:
		"leaves": return hud._leaf_tex
		"timber": return hud._log_tex
		"shards", "shard": return hud._shard_tex
	if not _icons.has(id):
		match id:
			"tick": _icons[id] = _make_tick(true)       # a goal met (the home's card)
			"todo": _icons[id] = _make_tick(false)      # a goal still to meet
			"amber": _icons[id] = _make_gem(Color(1.0, 0.78, 0.36), Color(0.95, 0.55, 0.15), Color(0.6, 0.3, 0.08), false)
			_: _icons[id] = UiIcons.texture(id)
	return _icons[id]


## icon(k) has a real picture for k (an unknown id gets the plain disc).
func _icon_known(k) -> bool:
	return k is Texture2D or OWN_ICONS.has(str(k)) or UiIcons.known(str(k))


## G3: a shop tile's own picture, the row key "picture" (a res:// path, e.g. res://assets/ui/bows/bow_sunwood.png),
## loaded once and kept. null when the row has none or the file is not there: the tile then shows its "icon".
func _picture(path: String) -> Texture2D:
	if path == "":
		return null
	if not _pictures.has(path):
		_pictures[path] = (load(path) as Texture2D) if ResourceLoader.exists(path) else null
	return _pictures[path]


## A faceted gem: a diamond (amber), light left facet, dark outline (64 x 64).
func _make_gem(light: Color, mid: Color, dark: Color, round_: bool) -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(32, 33)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var d := p.length() / 26.0 if round_ else (absf(p.x) / 20.0 + absf(p.y) / 28.0)
			if d >= 1.0:
				continue
			var col := mid if p.x > 0.0 else light
			if d > 0.82:
				col = dark
			elif d < 0.35 and p.y < 0.0:
				col = light.lightened(0.3)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## A goal's mark: a green disc with a white tick (met), or an open brown ring (not yet), 64 x 64.
func _make_tick(on: bool) -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(32, 32)
	var a := Vector2(17, 33)
	var m := Vector2(28, 44)
	var e := Vector2(47, 22)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c)
			var col := Color(0, 0, 0, 0)
			if on:
				if d < 29.0:
					col = Color(0.36, 0.66, 0.24) if d < 26.0 else Color(0.2, 0.42, 0.12)
					var t := minf(Geometry2D.get_closest_point_to_segment(p, a, m).distance_to(p), Geometry2D.get_closest_point_to_segment(p, m, e).distance_to(p))
					if t < 4.6:
						col = Color(1.0, 0.98, 0.9)
				col.a = clampf(29.0 - d, 0.0, 1.0) if d > 28.0 else col.a
			elif d < 25.0 and d > 19.0:
				col = Color(0.6, 0.45, 0.3, clampf(minf(25.0 - d, d - 19.0), 0.0, 1.0))
			if col.a > 0.0:
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _make_leaf() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var a := -0.7
	for y in n:
		for x in n:
			var p := (Vector2(x + 0.5, y + 0.5) / n) * 2.0 - Vector2.ONE
			var q := Vector2(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a)) * 1.08
			var d1 := (q - Vector2(0.55, 0)).length()
			var d2 := (q + Vector2(0.55, 0)).length()
			var edge := maxf(d1, d2)
			if edge < 1.0:
				var c := Color(0.98, 0.78, 0.2)
				if edge > 0.86:
					c = Color(0.72, 0.45, 0.08)
				elif absf(q.x) < 0.045 or (absf(q.x) < 0.3 and absf(absf(q.x) * 1.4 - (q.y + 0.6) * 0.5 + 0.2) < 0.04):
					c = Color(1.0, 0.92, 0.55)
				c.a = clampf((1.0 - edge) * 30.0, 0.0, 1.0)
				img.set_pixel(x, y, c)
			elif absf(q.x) < 0.05 and q.y > 0.75 and q.y < 1.0:
				img.set_pixel(x, y, Color(0.72, 0.45, 0.08))
	return ImageTexture.create_from_image(img)


## A faceted violet Gloom shard: a tall crystal with a lighter left facet and a pale core (64 x 64).
func _make_shard() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var top := Vector2(32, 4)
	var bottom := Vector2(32, 60)
	var left := Vector2(14, 26)
	var right := Vector2(50, 26)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var inside := Geometry2D.is_point_in_polygon(p, PackedVector2Array([top, right, bottom, left]))
			if not inside:
				continue
			var c := Color(0.52, 0.3, 0.86)                         # the right facet
			if p.x < 32.0:
				c = Color(0.72, 0.52, 0.98)                         # the lighter left facet
			if p.y < 26.0 and Geometry2D.is_point_in_polygon(p, PackedVector2Array([top, Vector2(41, 26), Vector2(23, 26)])):
				c = c.lightened(0.15)
			if Geometry2D.is_point_in_polygon(p, PackedVector2Array([Vector2(32, 16), Vector2(39, 30), Vector2(32, 46), Vector2(25, 30)])):
				c = Color(0.93, 0.86, 1.0)                          # the pale core
			var edge := minf(minf(Geometry2D.get_closest_point_to_segment(p, top, right).distance_to(p),
				Geometry2D.get_closest_point_to_segment(p, right, bottom).distance_to(p)),
				minf(Geometry2D.get_closest_point_to_segment(p, bottom, left).distance_to(p),
				Geometry2D.get_closest_point_to_segment(p, left, top).distance_to(p)))
			if edge < 2.2:
				c = Color(0.3, 0.14, 0.52)                          # a dark outline
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _make_log() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var centers := [Vector2(20, 42), Vector2(44, 42), Vector2(32, 21)]
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			for c in centers:
				var d := p.distance_to(c)
				if d < 12.5:
					var col := Color(0.55, 0.33, 0.16)
					if d < 10.0:
						col = Color(0.88, 0.68, 0.42)
					if d < 6.5 and d > 4.5:
						col = Color(0.7, 0.5, 0.28)
					if d < 1.8:
						col = Color(0.6, 0.4, 0.2)
					img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
