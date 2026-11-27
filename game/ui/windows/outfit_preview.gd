extends RefCounted
## H5: the Tailor's Nook's picture and its layout (the owner's picture 1, 26 Nov 2026; the window's rules are in
## ui/windows/tailor_window.gd). It is the card's one window row ({"kind": "window"}; card.gd), so it has the window API:
## content() on every rebuild of the card, tick(d) every frame, opened() once per visit, closed() once when the visit ends
## (Back, the X, a tap outside, another card). Top to bottom:
##   - the cat big on a low stand, turning slowly (ui/kit/model_view.gd), dressed in the outfit tried on
##   - its name, its state or price under it ("Wearing", "Owned", or the price), and ONE button: Buy, Wear or Wearing
##   - the outfit cards in a grid (ui/kit/icon_grid.gd; an outfit not owned yet is grey but still tapped to try it on)
##   - Back
## The picture is its own model, made from the outfit's file (Data.cat_skin_model; the original is
## PlayerScript.original_base()): it never touches Save.cat_skin, the live cat or her stats. Only Buy and Wear (the
## rules in stations.gd) change the live cat.
## The 3D view is made once and moved into each rebuild's content (a leaf pickup or a purchase rebuilds the card), so
## its turn never restarts; trying on another outfit changes only what it shows. closed() frees it (a wave that blanks
## the card frees it with the old rows).
## Used by: ui/windows/tailor_window.gd, the tests. Uses: ui/kit/model_view.gd, ui/kit/icon_grid.gd,
##       ui/kit/card_parts.gd (the buttons), scripts/player.gd (original_base, the vertex-colour test), Props (the
##       stand's model and the colour shader), Data (the outfits), the window's state() and entries().

const ModelView := preload("res://ui/kit/model_view.gd")
const IconGrid := preload("res://ui/kit/icon_grid.gd")
const CardParts := preload("res://ui/kit/card_parts.gd")
const PlayerScript := preload("res://scripts/player.gd")
const VIEW_W := 380                     # the turning picture, HUD pixels (narrower when the dialog is)
const VIEW_H := 340
const STAND_PROP := "stepping_stone"    # the low stand: an existing prop, scaled to the cat
const STAND_WIDER := 0.85               # the stand's width, against the cat's widest side in her rest pose (arms and bow out):
                                        # wide enough round the paws, small enough that the cat fills the picture
const STAND_MAX_H := 0.1                # and no taller than this share of the cat
const SELECT_RING := Color(0.95, 0.72, 0.2)   # the card of the outfit shown: a gold ring
const IDLE := "Idle"                    # the clip the cat stands in
# H5 words (balance.json "windows" has no heading for the outfit grid yet)
const HEAD_OUTFITS := "Outfits"

var hud                                 # the HUD node (untyped on purpose, as in the HUD's parts)
var main
var _win: WeakRef                       # the Tailor's window (weak: it holds this view)
var _view: ModelView                    # the turning cat, kept across the card's rebuilds; null when none
var _view_id := ""                      # the outfit it shows
var views_made := 0                     # how many 3D views were made (the tests read it)


func _init(window) -> void:
	_win = weakref(window)
	hud = window.hud
	main = window.main


## The whole view for the outfit the window has selected; safe to call on every rebuild.
func content() -> Control:
	var box := VBoxContainer.new()
	box.set_meta("outfit_preview", true)
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_PASS        # a drag still scrolls the dialog
	var win = _win.get_ref()
	if win == null:
		return box
	var sel: String = win.selected_id()
	box.add_child(_turning(sel))
	var s: Dictionary = win.state(sel)
	box.add_child(_label(String(s["name"]), 30, true, hud.TILE_INK))
	box.add_child(_state_line(s))
	var act := CardParts.foot_button(hud, {"label": String(s["label"]), "tone": "green" if bool(s["enabled"]) else "grey",
		"enabled": bool(s["enabled"]), "action": s["action"]})
	act.remove_meta("footer")                           # a button of the view, not of the card's footer
	act.set_meta("outfit_action", true)
	act.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(act)
	box.add_child(_label(HEAD_OUTFITS, 24, true, hud.TILE_INK))
	var grid: GridContainer = IconGrid.make(hud, win.entries(), win.try_on)
	for c in grid.get_children():
		if c.has_meta("cell") and String(c.get_meta("cell")) == sel:
			_ring(c as PanelContainer)
	box.add_child(grid)
	var back: Button = CardParts.foot_button(hud, {"label": Data.word("back"), "tone": "grey", "enabled": true,
		"action": win.back})
	back.remove_meta("footer")
	back.set_meta("outfit_back", true)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	return box


func tick(_delta: float) -> void:
	pass


func opened() -> void:
	pass


## The visit ends: the 3D view goes.
func closed() -> void:
	_drop_view()


## The outfit the picture shows now ("" when no view is up): the tests read it.
func shown_id() -> String:
	return _view_id if _view != null and is_instance_valid(_view) else ""


## The turning picture (null when none): the tests read it.
func view() -> ModelView:
	return _view if _view != null and is_instance_valid(_view) and not _view.is_queued_for_deletion() else null


## The line under the name: "Wearing", "Owned", or the price (red when she cannot pay it), or a short note
## ("Between waves", "Coming later").
func _state_line(s: Dictionary) -> Control:
	var cost: Dictionary = s["cost"]
	if not cost.is_empty() and String(s["kind"]) == "new" and bool(s["buyable"]):
		var line: HBoxContainer = IconGrid.amount_line(hud, cost, float(_view_w()), true)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.set_meta("outfit_price", true)
		return line
	return _label(String(s["note"]), 22, false, Color(0.45, 0.36, 0.26))


# ---------------------------------------------------------------- the turning cat
func _view_w() -> int:
	return mini(VIEW_W, int(hud.p_tiles._list_w()))


## The 3D view showing outfit id: the one made before (moved out of the old content, which the card is freeing), made
## to show id when it showed another, or a new one when it is gone.
func _turning(id: String) -> ModelView:
	if _view != null and is_instance_valid(_view) and not _view.is_queued_for_deletion():
		var p := _view.get_parent()
		if p != null:
			p.remove_child(_view)
		if _view_id != id:
			_view.show_node(_cat_on_stand(id))
			_view_id = id
		return _view
	_view = ModelView.new()
	_view.setup(Vector2i(_view_w(), VIEW_H))
	_view.set_meta("model_view", true)
	_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_view.show_node(_cat_on_stand(id))
	_view_id = id
	views_made += 1
	return _view


func _drop_view() -> void:
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	_view = null
	_view_id = ""


## The cat in outfit id standing on the low stand, her feet on its top.
func _cat_on_stand(id: String) -> Node3D:
	var holder := Node3D.new()
	var cat := _hero(id)
	if cat == null:
		return holder
	holder.add_child(cat)
	var cb: AABB = ModelView.box_of(cat)
	var stand := Props.instance(STAND_PROP)
	holder.add_child(stand)
	var sb: AABB = ModelView.box_of(stand)
	if sb.size.x > 0.0001 and sb.size.z > 0.0001 and sb.size.y > 0.0001:
		var k: float = maxf(cb.size.x, cb.size.z) * STAND_WIDER / maxf(sb.size.x, sb.size.z)
		var ky: float = minf(k, cb.size.y * STAND_MAX_H / sb.size.y)
		stand.scale = Vector3(k, ky, k)
		var c := cb.get_center()
		var sc := sb.get_center()
		stand.position = Vector3(c.x - sc.x * k, cb.position.y - sb.end.y * ky + 0.01, c.z - sc.z * k)
	return holder


## A hero model for outfit id, in its standing pose, coloured as the game colours it; null when no file loads.
## An outfit with no usable file shows the original look, as the game's own cat does (hero_base).
func _hero(id: String) -> Node3D:
	var path := Data.cat_skin_model(id)                 # "" for the original, and for an outfit whose file is missing
	var original := path == ""
	if original:
		path = PlayerScript.original_base() + ".glb"
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var m := ps.instantiate() as Node3D
	if m == null:
		return null
	var vc: bool = not path.ends_with("/CatRanger.glb") if original else PlayerScript._uses_vc(m)
	if vc:
		Props.apply_vc(m)                               # coloured per face, as the live cat (player.gd _build_model)
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null and ap.has_animation(IDLE):
		ap.get_animation(IDLE).loop_mode = Animation.LOOP_LINEAR
		ap.autoplay = IDLE
	return m


## The gold ring round the card of the outfit shown (a copy of the tile style, so the shared one stays plain).
func _ring(cell: PanelContainer) -> void:
	var base: StyleBox = hud.p_tiles._ui_style("tile")
	var sb := base.duplicate() as StyleBoxFlat
	if sb != null:
		sb.border_color = SELECT_RING
		sb.set_border_width_all(5)
		cell.add_theme_stylebox_override("panel", sb)
	cell.set_meta("selected", true)


func _label(text: String, size: int, bold: bool, ink: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ink)
	if bold:
		l.add_theme_font_override("font", hud.p_tiles._bold())
	return l
