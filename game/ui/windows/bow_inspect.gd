extends RefCounted
## H4: the Bow Shop's inspect view (the owner's answer, 26 Nov 2026, Q11 a and b). A tap on a bow's picture in the Bow
## Shop (bow_shop_window.gd show_bow) shows it inside the same window, with Back; the shop's own Upgrade hides while
## you look. Top to bottom:
##   - the bow big and turning slowly, its arrow standing beside it (ui/kit/model_view.gd): the bow's own model
##     (player.gd bow_path) and its own arrow (arrow.gd make), coloured as the cat's paw shows them
##   - its damage at its level ("Damage 145%"), its own line (pierce, arrows, fire or ice, range, draw speed), its level
##     when owned ("Level 4 of 8")
##   - Q11 b: what each of its arrows really hits for, with the cat's Damage stat and any running potion ("Each arrow
##     hits for 13.4 (the cat's Damage +36%)"): the very number a shot from this bow uses
##   - the bow's own list row (its one button: Upgrade, Equip, Buy, or none), without the picture tap
##   - Back (the list again, scrolled where it was)
## A locked or unbought bow can be looked at too. It is a window row of the card ({"kind": "window"}; card.gd), with the
## window API: content() on every rebuild of the card, tick(d) every frame, opened() once per visit, closed() once when
## the visit ends (Back, the X, a tap outside, another card).
## The 3D view is made once per bow looked at and moved into each rebuild's content (a leaf pickup or a save rebuilds
## the card), so its turn never restarts; closed() and another bow free it.
## Used by: ui/windows/bow_shop_window.gd (its window row while a bow is looked at), the tests.
## Uses: the Bow Shop's window (inspect, bow_row, _bow_note, shown_cap, back), ui/kit/model_view.gd, ui/kit/list_row.gd,
##       ui/kit/card_parts.gd (the Back button), stat_list.gd (now_text), player.gd (bow_path), arrow.gd (make,
##       has_vc), Props (vc_surfaces), Data (bow_info, bow_level_mult, arrow_damage, effect_mult, word), Save.

const ModelView := preload("res://ui/kit/model_view.gd")
const ListRow := preload("res://ui/kit/list_row.gd")
const CardParts := preload("res://ui/kit/card_parts.gd")
const StatList := preload("res://ui/windows/stat_list.gd")
const PlayerScript := preload("res://scripts/player.gd")   # its static bow_path
const ArrowScript := preload("res://scripts/arrow.gd")     # its static make and has_vc
const VIEW_PX := Vector2i(360, 300)     # the turning picture, HUD pixels
const ARROW_GAP := 0.12                 # between the bow and the arrow beside it, in the models' metres

var hud                                 # the HUD node (untyped on purpose, as in the HUD's parts)
var main
var _shop: WeakRef                      # the Bow Shop's window (weak: it holds this view)
var _view: ModelView                    # the turning bow, kept across the card's rebuilds; null when none
var _view_bid := ""                     # the bow it shows


func _init(shop) -> void:
	_shop = weakref(shop)
	hud = shop.hud
	main = shop.main


## The whole view for the bow the shop is looking at (shop.inspect); safe to call on every rebuild.
func content() -> Control:
	var box := VBoxContainer.new()
	box.set_meta("bow_inspect", true)
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_PASS        # a drag still scrolls the dialog
	var shop = _shop.get_ref()
	if shop == null or String(shop.inspect) == "":
		return box
	var bid := String(shop.inspect)
	box.add_child(_turning(bid))
	var texts := lines(bid)
	for i in texts.size():
		box.add_child(_label(String(texts[i]), i == 0))
	var row: Dictionary = shop.bow_row(bid)
	if not row.is_empty():
		row.erase("on_picture")                         # here the picture is the turning bow above
		box.add_child(ListRow.make(hud, row))
	var back: Button = CardParts.foot_button(hud, {"label": Data.word("back"), "tone": "grey", "enabled": true,
		"action": shop.back})
	back.remove_meta("footer")                          # a button of the view, not of the card's footer
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


## The lines under the turning bow (the tests read them): its damage at its level ("Damage 145%"; level 1 for a bow not
## owned), its own line, its level when owned ("Level 4 of 8"), and what each of its arrows hits for.
func lines(bid: String) -> Array:
	var shop = _shop.get_ref()
	var lv := int(Save.bows.get(bid, 0))
	var out: Array = [Data.word("bow_damage") % roundi(float(Data.bow_info(bid)["damage"]) * Data.bow_level_mult(bid, maxi(lv, 1)) * 100.0)]
	if shop != null:
		out.append(String(shop._bow_note(bid)))
		if Save.bows.has(bid):
			out.append(Data.word("bow_level") % [lv, int(shop.shown_cap(bid))])
	var hit := arrow_hit(bid)
	if hit != "":
		out.append(hit)
	return out


## Q11 b: what one arrow of bow bid really hits for now, with the cat's Damage stat and any running potion. It is the
## very number every shot uses: player.gd _fire looses each arrow with Data.arrow_damage() (the cat's damage x her Damage
## stat x the bow's damage x its level x a running potion's share, which core/effects.gd stat_mult hands Data through
## the cat's Effects holder). No sum is made here: Data.arrow_damage(bid) is that same sum for bow bid at its level (a
## bow not owned at level 1), so every bow shows what its arrow would hit for in the cat's paw.
## The one-off doubles (an ambush, a close call's arrow) are not counted: they are not the arrow's own damage.
func arrow_hit(bid: String) -> String:
	var dmg: String = main.stations._short_num(Data.arrow_damage(bid))   # "13.4", "12"
	var potion := Data.effect_mult("damage")
	if potion > 0.0:
		return String(Data.word("arrow_hit_potion")) % [dmg, StatList.now_text("damage"), "+%d%%" % roundi(potion * 100.0)]
	return String(Data.word("arrow_hit")) % [dmg, StatList.now_text("damage")]


# ---------------------------------------------------------------- the turning bow
## The 3D view of bow bid: the one made for it before, moved out of the old content (which the card is freeing), or a
## new one (the old bow's goes).
func _turning(bid: String) -> ModelView:
	if _view != null and is_instance_valid(_view) and not _view.is_queued_for_deletion() and _view_bid == bid:
		var p := _view.get_parent()
		if p != null:
			p.remove_child(_view)
		return _view
	_drop_view()
	_view = ModelView.new()
	_view.setup(VIEW_PX)
	_view.set_meta("model_view", true)
	_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_view.show_node(_bow_and_arrow(bid))
	_view_bid = bid
	return _view


func _drop_view() -> void:
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	_view = null
	_view_bid = ""


## The bow standing up with its arrow beside it, tip up. Both models are long along +Z in their files (the arrow's
## origin is its nock), so one turn stands them both up.
func _bow_and_arrow(bid: String) -> Node3D:
	var holder := Node3D.new()
	var lay := Node3D.new()
	lay.rotation_degrees = Vector3(-90.0, 0.0, 0.0)   # +Z (their length) becomes up
	holder.add_child(lay)
	var bow_box := AABB()
	var bow := _bow_model(bid)
	if bow != null:
		lay.add_child(bow)
		bow_box = ModelView.box_of(bow)
	var arrow: Node3D = ArrowScript.make(bid)
	lay.add_child(arrow)
	var a_box := ModelView.box_of(arrow)
	arrow.position = Vector3(bow_box.end.x + ARROW_GAP - a_box.position.x, bow_box.get_center().y - a_box.get_center().y,
		bow_box.get_center().z - a_box.get_center().z)
	return holder


## Bow bid's own model as one plain mesh: the mesh player.gd puts in the cat's paw (_bow_from picks the skinned one),
## shown without the cat's skeleton, coloured the way _put_bow colours it (a vertex-coloured bow gets the shared colour
## shader with its M_Glow parts kept, Props.vc_surfaces; the others keep their own materials). Null when the bow has no
## model file.
func _bow_model(bid: String) -> MeshInstance3D:
	var path := PlayerScript.bow_path(bid)
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var root := ps.instantiate()
	var src: MeshInstance3D = null
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh != null and (src == null or (src.skin == null and mi.skin != null)):
			src = mi
	var out: MeshInstance3D = null
	if src != null:
		out = MeshInstance3D.new()
		out.mesh = src.mesh
		if ArrowScript.has_vc(src):
			Props.vc_surfaces(out)
		else:
			out.material_override = src.material_override
			for i in mini(out.get_surface_override_material_count(), src.get_surface_override_material_count()):
				out.set_surface_override_material(i, src.get_surface_override_material(i))
	root.free()
	return out


## A line under the turning bow: the first (its damage) bold and bigger, in ink; the others as a row's short lines.
func _label(text: String, first: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 28 if first else 20)
	l.add_theme_color_override("font_color", hud.TILE_INK if first else Color(0.45, 0.36, 0.26))
	if first:
		l.add_theme_font_override("font", hud.p_tiles._bold())
	return l
