extends RefCounted
## H5 (Stage 2, 27 Nov 2026; the H5 map part 3.4): a Saddlery attachment's detail, inside the Saddlery's window (a tap
## on its picture on the Attachments tab; saddlery_window.gd inspect). Top to bottom:
##   - the attachment big and turning slowly (ui/kit/model_view.gd): its model fitted to the mount out now
##     (Data.gear_model(id, Save.mount_look): the same file mount.gd hangs on the saddle bone), coloured as on the mount
##     (Props.apply_vc_glow) and stood the way it sits there (mount.gd gear_frame); its picture when there is no file
##   - its name, what it does at its level (stations._saddle_note: the very numbers the mount uses), its description
##   - "Worn · Level 2 of 5" or "Owned · Level 1 of 5" once owned, and what the next level does
##   - the price of its one action, why it can't go further (red), then Back and the one button: Buy (not owned), Wear
##     (owned and not worn; between waves), Upgrade (the worn one while it can), else a grey Worn
## It is a window row of the card ({"kind": "window"}; card.gd), with the window API: content() on every rebuild of the
## card, tick(d) every frame, opened() once per visit, closed() once when the visit ends (Back, another tab, the X, a tap
## outside, another card). The 3D view is made once per attachment and mount look and moved into each rebuild's
## content (a leaf pickup or a save rebuilds the card), so its turn never restarts; closed() and another one free it.
## The rules stay in stations.gd; the one button runs the window's act() (it checks the level it showed is still next).
## Used by: ui/windows/saddlery_window.gd (its window row while an attachment is looked at), the tests.
## Uses: the Saddlery's window (shown_id, entry, state_line, act, back), ui/kit/model_view.gd, ui/kit/card_parts.gd (the
##       buttons), the HUD's tiles (price line, styles, fonts) and pictures, Data (gear_model, saddle_info,
##       shop_picture, word), Save.mount_look, main.mount (gear_frame), stations.gd (_saddle_note), Props.

const ModelView := preload("res://ui/kit/model_view.gd")
const CardParts := preload("res://ui/kit/card_parts.gd")
const ShopTiles := preload("res://ui/hud/shop_tiles.gd")   # the type of the HUD's tiles (hud.p_tiles)
const VIEW_PX := Vector2i(360, 300)     # the turning picture, HUD pixels
const STILL_PIC := 200.0                # the picture when there is no model file (as the build menu's detail)
const STILL_PAD := 8.0
const BTN := Vector2(220, 64)           # Back and the action
const MUTED := Color(0.45, 0.36, 0.26)
const WARN := Color(0.7, 0.28, 0.2)

var hud                                 # the HUD node (untyped on purpose, as in the HUD's parts)
var main
var _win: WeakRef                       # the Saddlery's window (weak: it holds this view)
var _view: ModelView                    # the turning attachment, kept across the card's rebuilds; null when none
var _view_key := ""                     # what it shows: "<attachment id>:<mount look>"


func _init(window) -> void:
	_win = weakref(window)
	hud = window.hud
	main = window.main


## The whole detail of the attachment the window is looking at; safe to call on every rebuild.
func content() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_PASS        # a drag still scrolls the dialog
	var w = _win.get_ref()
	if w == null or String(w.shown_id) == "":
		return box
	var aid := String(w.shown_id)
	var e: Dictionary = w.entry("attach", aid)
	box.set_meta("attachment_inspect", aid)
	box.add_child(_turning(aid))
	box.add_child(_label(String(e["name"]), 32, hud.TILE_INK, true))
	var lv := int(e["level"])
	var st = main.stations
	box.add_child(_label(String(st._saddle_note("attach", aid, maxi(lv, 1))), 24, hud.TILE_INK, false, "effect"))
	var desc := String(Data.saddle_info("attach", aid).get("desc", ""))
	if desc != "":
		box.add_child(_label(desc, 20, MUTED, false, "desc"))
	if lv >= 1:
		var level := _w("level_of") % [lv, int(e["top"])]
		var state := _w("worn") if String(e["state"]) == "worn" else _w("owned")
		box.add_child(_label(state + " · " + level, 21, MUTED, false, "level"))
		if lv < int(e["top"]):
			box.add_child(_label(_w("next_level") % String(st._saddle_note("attach", aid, lv + 1)), 20, MUTED, false, "next"))
	var tiles: ShopTiles = hud.p_tiles
	var price: Dictionary = e["price"]
	if tiles._price_kinds(price) > 0:
		var line: HBoxContainer = tiles._price_line(price, tiles._list_w())
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(line)
	if String(e["why"]) != "":
		box.add_child(_label(String(e["why"]), 21, WARN, false, "why"))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	buttons.mouse_filter = Control.MOUSE_FILTER_PASS
	buttons.add_child(_button(_w("back"), "grey", true, w.back))
	var act := String(e["action"])
	var tone := "blue" if act == "wear" else "green"
	buttons.add_child(_button(String(e["label"]), tone, act != "" and bool(e["can"]),
		w.act.bind("attach", aid, int(e["next"]))))
	box.add_child(buttons)
	return box


func tick(_delta: float) -> void:
	pass


func opened() -> void:
	pass


## The visit ends: the 3D view goes.
func closed() -> void:
	_drop_view()


## What the turning view shows now (the tests read it): its attachment's model path ("" for none or the picture).
func model_path() -> String:
	if _view == null or not is_instance_valid(_view):
		return ""
	return String(_view.get_meta("model_path", ""))


# ---------------------------------------------------------------- the turning attachment
## The 3D view of attachment aid fitted to the mount out now: the one made before (moved out of the old content, which
## the card is freeing), or a new one (the old one goes). Its picture instead when the look has no fitted file.
func _turning(aid: String) -> Control:
	var look := Save.mount_look
	var key := "%s:%s" % [aid, look]
	if _view != null and is_instance_valid(_view) and not _view.is_queued_for_deletion() and _view_key == key:
		var p := _view.get_parent()
		if p != null:
			p.remove_child(_view)
		return _view
	_drop_view()
	var path := Data.gear_model(aid, look)              # "" when this look has no fitted file
	var n: Node3D = null
	if path != "":
		var ps := load(path) as PackedScene
		if ps != null:
			n = ps.instantiate() as Node3D
	if n == null:
		return _still(aid)
	Props.apply_vc_glow(n)                              # coloured as mount.gd colours it on the saddle bone
	var holder := Node3D.new()
	holder.add_child(n)
	n.transform = _saddle_turn()
	_view = ModelView.new()
	_view.setup(VIEW_PX)
	_view.set_meta("model_view", true)
	_view.set_meta("model_path", path)
	_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_view.show_node(holder)
	_view_key = key
	return _view


func _drop_view() -> void:
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	_view = null
	_view_key = ""


## How the attachment sits on the mount out now: the turn of its saddle bone in the mount's own space (mount.gd
## gear_frame; its file is made in that bone's frame), so the camera sees it from the mount's front. No turn without a
## mount (or with the placeholder, which has no saddle bone).
func _saddle_turn() -> Transform3D:
	var m = main.get("mount") if main != null else null
	if m != null and is_instance_valid(m) and m.has_method("gear_frame"):
		var f: Transform3D = m.gear_frame()
		return Transform3D(f.basis.orthonormalized(), Vector3.ZERO)
	return Transform3D.IDENTITY


## The attachment's picture (its shop picture, else its icon) in the tiles' soft square, when it has no model to turn.
func _still(aid: String) -> Control:
	var sq := Panel.new()
	sq.set_meta("detail_pic", true)
	var side := STILL_PIC + STILL_PAD * 2.0
	sq.custom_minimum_size = Vector2(side, side)
	sq.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sq.add_theme_stylebox_override("panel", hud.p_tiles._ui_style("pic"))
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var raw: Variant = String(Data.saddle_info("attach", aid).get("icon", "saddlery"))
	var own: Texture2D = hud.p_icons._picture(Data.shop_picture("attachments", aid))
	if own != null:
		raw = own
	var pic := TextureRect.new()
	pic.texture = hud.icon(raw)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = STILL_PAD
	pic.offset_top = STILL_PAD
	pic.offset_right = -STILL_PAD
	pic.offset_bottom = -STILL_PAD
	sq.add_child(pic)
	return sq


# ---------------------------------------------------------------- small parts
## A centred line: bold for the name; `tag` is its meta (the tests find "effect", "desc", "level", "next", "why").
func _label(text: String, size: int, ink: Color, bold: bool, tag := "") -> Label:
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
	if tag != "":
		l.set_meta(tag, true)
	return l


## One of the detail's buttons: the footer's button (the card kit draws it), but not the card's footer. A press runs
## the action, then the card refreshes (card_parts.gd).
func _button(label: String, tone: String, on: bool, action: Callable) -> Button:
	var b: Button = CardParts.foot_button(hud, {"label": label, "tone": tone if on else "grey", "enabled": on, "action": action})
	b.remove_meta("footer")
	b.custom_minimum_size = BTN
	return b


static func _w(key: String) -> String:
	return String(Data.word(key))
