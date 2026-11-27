extends Node3D
## The Cat Ranger. The joystick moves it. Whenever an enemy is within RANGE it faces that enemy and keeps shooting,
## whether it is standing or moving; with no enemy near it lowers the bow.
##
## Clips come from CatRanger.glb (see CatRanger_clips.json next to it). An AnimationTree plays two things at once:
##   legs, hips, tail          Idle / Walk / Run, faster or slower so the feet match the ground speed, and backward
##                             when the cat backs away from what it is shooting at
##   spine and everything up   the Shoot loop while an enemy is near (blended in and out over AIM_BLEND seconds)
## The shooting stance is side-on: the chest is 64 degrees to the right of the aim. So while shooting on the move
## the hips are turned to point the legs along the way the cat is going (body_twist.gd) and the spine is turned back
## by the same amount, which leaves the chest, arms and bow exactly as they were authored.
## Mounted shooting uses five upper-body loops from assets/cat/mounted/shooting.res. The torso and arms turn for
## rear-quarter shots on one Shoot clock; the root, seated pelvis and knees follow the mount's heading.
## The hood, capelet and skirt are not in the clips: cloth.gd simulates them on top, after the body is posed.
## H1: the arrows she shoots come from Pools (arrow.gd POOL, _new_arrow, prewarm_arrows); the nocked one is her own.
## H3: her running potions live in her Effects holder (parts/effects_holder.gd, the child "Effects", `effects`): it hands
## Data the Damage and Speed shares (Data.set_effect_mults) and heals her through heal(); it clears when she is knocked out.

## The hero model to use, without ".glb" (its clips are hero_clips()). 23 Nov 2026: the outfit she wears
## (Save.cat_skin, balance.json cat_skins: res://assets/cat/skins/<id>.glb, the same skeleton and clips) when its file
## exists; else the original look (original_base()), so a missing file never breaks the game.
static func hero_base() -> String:
	var skin := Data.cat_skin_model(Save.cat_skin)
	if skin != "":
		return skin.get_basename()
	return original_base()


## The original look: "CatRanger" (the first one) or "CatRanger2" (the Meshy remake, same skeleton and clips).
## balance.json "hero_model" picks it; the test flag --cat1 / --cat2 overrides it.
static func original_base() -> String:
	var args := Data.args()
	var id := "CatRanger2" if args.has("--cat2") else ("CatRanger" if args.has("--cat1") else String(Data.b.get("hero_model", "CatRanger")))
	if not ResourceLoader.exists("res://assets/cat/%s.glb" % id):
		id = "CatRanger"
	return "res://assets/cat/" + id


static var _loaded_hero_base := ""


## The loaded hero's clips JSON (the bow hand, the cloth bones and their guards). An outfit with no clips JSON uses
## the original's. Before the hero is built, use the model she is meant to wear.
static func hero_clips() -> String:
	var base := _loaded_hero_base if _loaded_hero_base != "" else hero_base()
	var path := base + "_clips.json"
	if FileAccess.file_exists(path):
		return path
	return original_base() + "_clips.json"
const ArrowScene := preload("res://assets/cat/CatRanger_Arrow.glb")
const ArrowScript := preload("res://scripts/arrow.gd")
const EffectsHolder := preload("res://parts/effects_holder.gd")
const TwistScript := preload("res://scripts/body_twist.gd")
const ClothScript := preload("res://scripts/cloth.gd")
const RideScript := preload("res://scripts/ride_pose.gd")
const RideMotionScript := preload("res://scripts/ride_motion.gd")
const BowFaceScript := preload("res://scripts/bow_face.gd")
const MountedShooting := preload("res://assets/cat/mounted/shooting.res")
const SEAT_DROP := 0.35                                 # m from the cat's feet down to its seat: it sits on the saddle

const MAX_SPEED := 2.6                                  # m/s with the stick fully pushed
const WALK_BELOW := 1.05                                # m/s: slower than this plays Walk
const CLIP_SPEED := {"Walk": 0.65, "Run": 2.143}        # m/s each clip covers at playback speed 1
const SHOOT_LENGTH := 0.8333                            # seconds: one loop of Shoot
const SHOOT_RELEASE := 0.3667                           # seconds into Shoot: the arrow leaves the string
const SHOOT_NOCK := 0.80                                # seconds into Shoot: the next arrow is on the string (frame 25)
const RANGE := 5.5                                      # metres: about what the screen shows
const TURN := 12.0
const MAX_HP := 5
const AIM_BLEND := 0.2                                  # seconds for the bow to come up or go down
const STANCE_HIPS := -0.4206                            # -24.1 deg: where the hips sit in the authored stance
const HIPS_MIN := -2.4260                               # -139 deg and +11 deg: how far the hips may turn from the
const HIPS_MAX := 0.1920                                #   aim, which is 75 deg of twist either way below the chest
const KEEP_GAIT := 0.35                                 # 20 deg: do not swap forward / backward legs for less
const FIRE_CONE := 0.61                                 # 35 deg: hold the arrow until the body has turned this close
const UPPER_FROM := "spine"                             # this bone and everything above it follows the Shoot loop ...
const CLOTH_SIM := true                                 # simulate the hood, capelet and skirt (cloth.gd); -- --no-cloth-sim turns it off
const CLOTH := ["cape.", "hood.", "skirt."]             # ... except the cloth bones, which cloth.gd moves

var main
var model: Node3D
var anim: AnimationPlayer
var tree: AnimationTree
var twist: SkeletonModifier3D
var cloth: Node3D                                       # cloth.gd: the hood, capelet and skirt
var cloth_debug := false
var skeleton: Skeleton3D
var nocked: Node3D                                      # the arrow on the string
var state := "idle"                                     # idle / move / shoot / move_shoot / down
var hp := MAX_HP
var bow_mat: Array = []
var slow_t := 0.0                                       # seconds the cat is slowed (spores)
var reveal_t := 0.0                                     # seconds the cat stays visible after a shot
var target = null
var facing := 0.0
var aim_w := 0.0                                        # 0 bow carried .. 1 shooting
var legs_backward := false
var hips_turn := 0.0                                    # radians the hips are turned from the aim right now
var loco_clip := "Idle"
var loco_scale := 1.0
var shots_fired := 0
var invincible := false                                 # used by the automated test
var riding := false                                     # on Thistle (mount.gd): sits astride, Thistle runs, the cat shoots
var ride_pose: SkeletonModifier3D                       # ride_pose.gd: the legs astride the saddle
var ride_motion: SkeletonModifier3D                     # ride_motion.gd: she rides (rocks, leans, sways, jolts) and carries the bow
var bow_face: SkeletonModifier3D                        # bow_face.gd: the string turned toward her while the bow is carried
var _ride_y := 0.0
var _ride_w := 0.0
# 22 Nov 2026: the ride's motion (_ride_motion; balance.json mount.ride_*)
var _rm_bob_y := 0.0                                    # a spring that follows the saddle's height: how far it lags is
var _rm_bob_v := 0.0                                    #   how far her back gives with each bounce
var _rm_jolt := 0.0                                     # a skill's jolt: radians forward (+) or back, settling
var _rm_jolt_v := 0.0
var _rm_lean := Vector2.ZERO                            # her lean (forward, to her left), eased
var _rm_head := 0.0                                     # the mount's heading a frame ago (how fast it turns)
var _rm_turn := 0.0                                     # ... that, eased (radians a second)
var _rm_sway_t := 0.0                                   # frame time standing (the sway)
var _rm_on := false
var _bow_reach_of: Mesh                                 # the bow mesh _bow_reach was measured on
var _bow_reach := Vector2(-0.45, 0.5)
var jolts := 0                                          # skill jolts felt (the tests read it)
var frozen := false
var _was_aiming := false
var _shoot_t := 0.0
var _fired := false
var _invuln := 0.0
var _knock := Vector3.ZERO
var _vc_hero := false                                  # CatRanger2: vertex colours (the vc shader), not textures
var _dash_t := 0.0                                      # Phase E, the Leaf Dash: seconds of the dash left
var _dash_iframe := 0.0                                 # ... nothing can hurt the cat while > 0 (a hit then is a close call)
var _dash_cd := 0.0                                     # ... seconds before the next dash
var _dash_cd_total := 1.4
var _dash_dir := Vector3.ZERO
var _dash_speed := 0.0
var vel := Vector3.ZERO                                 # how fast the cat moves now (the Glowcap leads its lobs with it)
var _vel_from := Vector3.ZERO
var dashes := 0                                         # counted for the tests
var close_calls := 0
var _rod_hold: BoneAttachment3D                         # fishing: the rod in the bow paw (Phase C)
var _rod: Node3D
var effects: EffectsHolder                              # H3: her running potions (the child "Effects", made in _ready)
## The rod in the paw points forward and up, a little out to the side (in the cat's own frame); ROD_XF, the offset on
## the bow-hand bone, is worked out from this when the rod is put in the paw, so it fits any pose the hero idles in.
const ROD_DIR := Vector3(0.2, 0.62, 0.72)               # (out to the bow side, up, forward)


func _ready() -> void:
	_build_model()
	Fx.blob(self, 0.42)
	hp = Data.cat_max_hp()
	effects = EffectsHolder.new()                       # H3: the Health, Damage and Speed Potions run here
	effects.name = "Effects"
	effects.main = main
	effects.max_hp = Data.cat_max_hp
	effects.heal = heal
	effects.stats_changed = Data.set_effect_mults
	add_child(effects)


## The hero model (hero_base(): the outfit she wears, or the original) and everything set up on it: the clips' loops,
## the arrow on the string (bone `arrow`), the skeleton modifiers (ride_pose, twist, ride_motion, bow_face), the
## AnimationTree, the cloth (cloth.gd / cloth_fit.gd) and the bow (apply_bow). _ready calls it once; apply_skin again
## after taking the old model away.
func _build_model() -> void:
	var base := hero_base()
	_asked_path = base + ".glb"
	model = null
	if base != original_base():
		# an outfit: used only when it really is a hero (the skeleton and the four clips); else the original, with a warning
		var ps := load(_asked_path) as PackedScene
		var m: Node3D = (ps.instantiate() as Node3D) if ps != null else null
		if m != null and _hero_ok(m):
			model = m
			_model_path = _asked_path
			_vc_hero = _uses_vc(model)           # coloured per face (the vc shader) unless it has textures
		else:
			push_warning("%s: not a usable hero model (it needs the CatRanger skeleton with the bone `arrow` and the clips Idle, Walk, Run and Shoot); the original look is worn instead" % _asked_path)
			if m != null:
				m.free()
	if model == null:
		base = original_base()
		_model_path = base + ".glb"
		model = (load(_model_path) as PackedScene).instantiate()
		_vc_hero = not base.ends_with("/CatRanger")
	_loaded_hero_base = base
	if _vc_hero:
		Props.apply_vc(model)                    # the remake is coloured per face, like every other LEAF model
	add_child(model)
	anim = _find(model, "AnimationPlayer")
	skeleton = _find(model, "Skeleton3D")
	for clip in ["Idle", "Walk", "Run", "Shoot"]:
		anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	anim.add_animation_library("mounted", MountedShooting)
	# the arrow on the string: the arrow asset rides the bone `arrow` with no offset. The rig aims that bone's Z
	# axis down the shaft (measured in Blender: asset frame = bone frame), and the asset's tip is +Z too.
	var hold := BoneAttachment3D.new()
	skeleton.add_child(hold)
	hold.bone_name = "arrow"
	nocked = Node3D.new()
	hold.add_child(nocked)
	_set_nocked(Save.bow)                               # G3: the equipped bow's own arrow (apply_bow swaps it)
	nocked.visible = false
	ride_pose = SkeletonModifier3D.new()
	ride_pose.set_script(RideScript)
	skeleton.add_child(ride_pose)                       # before the twist, so the seated legs turn with the hips
	twist = SkeletonModifier3D.new()
	twist.set_script(TwistScript)
	skeleton.add_child(twist)
	ride_motion = SkeletonModifier3D.new()
	ride_motion.set_script(RideMotionScript)
	skeleton.add_child(ride_motion)                     # after the twist, before the cloth (it swings with her)
	ride_motion.bow_weapon = _bow_hand()
	bow_face = SkeletonModifier3D.new()                 # 22 Nov 2026: the string toward her while the bow is carried
	bow_face.set_script(BowFaceScript)
	skeleton.add_child(bow_face)                        # after the riding modifier, so it corrects the final carry
	bow_face.max_turn = deg_to_rad(float(Data.b["cat"].get("bow_face_max_deg", 70.0)))
	_build_tree()
	cloth = Node3D.new()
	cloth.set_script(ClothScript)
	cloth.debug = cloth_debug
	cloth.fit_on = not Data.args().has("--no-cloth-fit")
	var args := Data.args()
	add_child(cloth)
	if not CLOTH_SIM or args.has("--no-cloth-sim") or not cloth.setup(skeleton):                       # after the twist, so the cloth hangs from the turned body
		cloth.queue_free()
		cloth = null
	apply_bow()


# ---------------------------------------------------------------- 23 Nov 2026: the cat's outfits (the Tailor's Nook)
var _model_path := ""                                   # the hero model on now (res://...glb)
var _asked_path := ""                                   # the one asked for (an outfit that is no usable hero: the original is on)
var _hide_tws: Array = []                               # set_hidden_look's tweens (stopped when the model is swapped)
var skin_swaps := 0                                     # models swapped in place (the tests read it)


## The model she wears now is the one Save.cat_skin asks for (hero_base()).
func skin_current() -> bool:
	return model != null and is_instance_valid(model) and _asked_path == hero_base() + ".glb"


## An outfit's model is a hero: an AnimationPlayer with the clips Idle, Walk, Run and Shoot, and a Skeleton3D with the
## bone `arrow` (the nocked arrow) and `spine` (the upper body's clip filter).
func _hero_ok(m: Node) -> bool:
	var ap := _find(m, "AnimationPlayer") as AnimationPlayer
	var sk := _find(m, "Skeleton3D") as Skeleton3D
	if ap == null or sk == null or sk.find_bone("arrow") < 0 or sk.find_bone(UPPER_FROM) < 0:
		return false
	for clip in ["Idle", "Walk", "Run", "Shoot"]:
		if not ap.has_animation(clip):
			return false
	return true


## The hero model on now (res://...glb).
func model_path() -> String:
	return _model_path


## 23 Nov 2026: puts on the outfit Save.cat_skin names (its model when the file exists, else the original look), in
## place, without restarting: the old model goes with everything built on it (the AnimationTree, the skeleton modifiers,
## the nocked arrow, the rod, the cloth), and _build_model sets up the new one the same way. What the cat is doing
## carries over: riding (the seat and the ride's springs pick up again), fishing (the rod back in the paw), hiding (the
## see-through look), the bow in her paw (apply_bow) and her health. Nothing happens when she already wears that model.
## True when the model changed.
func apply_skin() -> bool:
	if skin_current():
		return false
	var fishing := has_rod()
	var hidden_now := main != null and bool(main.get("hidden"))
	for tw in _hide_tws:
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
	_hide_tws.clear()
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	_flash_tw = null
	if cloth != null and is_instance_valid(cloth):
		cloth.detach()
		remove_child(cloth)
		cloth.queue_free()
	cloth = null
	if model != null and is_instance_valid(model):
		remove_child(model)                              # out of the tree now, so the two are never drawn together
		model.queue_free()
	model = null
	tree = null
	anim = null
	skeleton = null
	nocked = null
	twist = null
	ride_pose = null
	ride_motion = null
	bow_face = null
	_rod_hold = null
	_rod = null
	_bow_mesh = null
	_bow_reach_of = null
	_bow_reach = Vector2(-0.45, 0.5)
	_spheres = []
	_spheres_done = false
	_nocked_id = "-"
	loco_clip = "Idle"                                  # the new tree starts on Idle
	loco_scale = 1.0
	_was_aiming = false                                 # the Shoot loop starts again from the top
	_fired = false
	_shoot_t = 0.0
	_rm_on = false                                      # the ride's springs start at rest
	_build_model()
	tree.advance(0.0)                                   # posed at once (the rod is fitted to the pose)
	nocked.visible = false
	if fishing:
		set_fishing(true)
	if hidden_now:
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as GeometryInstance3D).transparency = 0.45
	skin_swaps += 1
	return true


## A model coloured per face (vertex colours and no texture), like every other LEAF model; a textured one keeps its
## own materials.
static func _uses_vc(root: Node) -> bool:
	var vc := false
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null:
				return false
			if mi.mesh is ArrayMesh and ((mi.mesh as ArrayMesh).surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR) != 0:
				vc = true
	return vc


## The bow in the cat's paw shows the one that is equipped (called at the start and after every purchase).
## G3: a bow with its own model, res://assets/cat/bows/bow_<id>.glb (a Skeleton3D with the cat rig's bone names and one
## skinned mesh), puts that mesh in the hero's SK_CatBow, skinned to the cat's own skeleton by bone name (_bow_parts),
## so drawing and shooting bend it as before. A bow without a file shows the hero's own bow mesh again, tinted to the
## bow (as before G3). The arrow on the string follows the bow (arrow.gd make).
func apply_bow() -> void:
	_set_nocked(Save.bow)
	var bow_mesh := model.find_child("SK_CatBow", true, false) as MeshInstance3D
	if bow_mesh == null:
		return
	_keep_orig_bow(bow_mesh)
	var parts := _bow_parts(Save.bow)
	if not parts.is_empty():
		_put_bow(bow_mesh, parts)
		return
	_restore_bow(bow_mesh)
	var tint := Color.html(String(Data.bow_info(Save.bow)["tint"]))
	if _vc_hero:
		bow_mesh.set_instance_shader_parameter("tint", tint)
		return
	for i in bow_mesh.get_surface_override_material_count():
		if not bow_mesh.has_meta("orig_%d" % i):
			bow_mesh.set_meta("orig_%d" % i, bow_mesh.get_active_material(i))
		var orig = bow_mesh.get_meta("orig_%d" % i)
		if orig is BaseMaterial3D:
			var mm := (orig as BaseMaterial3D).duplicate() as BaseMaterial3D
			mm.albedo_color = mm.albedo_color * tint
			if Save.bow != "twig":
				mm.emission_enabled = true
				mm.emission = tint * 0.25
			bow_mesh.set_surface_override_material(i, mm)


# ---------------------------------------------------------------- G3: each bow's own model and arrow
var _bow_cache := {}                                    # bow id -> _bow_parts (a loaded bow file, or {} for none)
var _nocked_id := "-"                                   # the bow whose arrow is on the string now


## The arrow on the string: bow bid's own arrow model (arrow.gd make), swapped only when the bow changes.
func _set_nocked(bid: String) -> void:
	if nocked == null or bid == _nocked_id:
		return
	_nocked_id = bid
	for c in nocked.get_children():
		nocked.remove_child(c)
		c.queue_free()
	nocked.add_child(ArrowScript.make(bid))


## Where bow bid's own model would be.
static func bow_path(bid: String) -> String:
	return "res://assets/cat/bows/bow_%s.glb" % bid


## The hero's own bow (its mesh, skin, material override and materials) is remembered on SK_CatBow before any swap, so
## a bow without a file can go back to it.
func _keep_orig_bow(bow_mesh: MeshInstance3D) -> void:
	if bow_mesh.has_meta("orig_kept"):
		return
	bow_mesh.set_meta("orig_kept", true)
	bow_mesh.set_meta("orig_mesh", bow_mesh.mesh)
	bow_mesh.set_meta("orig_skin", bow_mesh.skin)
	bow_mesh.set_meta("orig_override", bow_mesh.material_override)    # (a null meta is no meta: get_meta's default)
	for i in bow_mesh.get_surface_override_material_count():
		if not bow_mesh.has_meta("orig_%d" % i):
			bow_mesh.set_meta("orig_%d" % i, bow_mesh.get_active_material(i))


## The hero's own bow back in SK_CatBow (after a bow with its own model); the tint code then colours it.
func _restore_bow(bow_mesh: MeshInstance3D) -> void:
	var om = bow_mesh.get_meta("orig_mesh", null)
	if om == null or bow_mesh.mesh == om:
		return
	bow_mesh.mesh = om
	bow_mesh.skin = bow_mesh.get_meta("orig_skin", null)
	bow_mesh.material_override = bow_mesh.get_meta("orig_override", null)
	for i in bow_mesh.get_surface_override_material_count():
		bow_mesh.set_surface_override_material(i, null)


## Bow bid's own model, loaded once: {mesh, skin, mats, override, vc}, or {} when there is no file or it cannot be used
## (no skinned mesh, or a bone the cat's skeleton does not have: a warning says which; the tint is used instead).
## The new Skin has NAMED binds (each bind's name, or the bow file's bone at that bind's index) with the file's bind
## poses, so the cat's skeleton drives it whatever order its bones are in.
func _bow_parts(bid: String) -> Dictionary:
	if _bow_cache.has(bid):
		return _bow_cache[bid]
	var parts := {}
	var path := bow_path(bid)
	if ResourceLoader.exists(path):
		var ps := load(path) as PackedScene
		if ps != null:
			var root := ps.instantiate()
			parts = _bow_from(root, path)
			root.free()
	_bow_cache[bid] = parts
	return parts


func _bow_from(root: Node, path: String) -> Dictionary:
	var src: MeshInstance3D = null
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh != null and (src == null or (src.skin == null and mi.skin != null)):
			src = mi
	if src == null or src.skin == null:
		push_warning("%s: no skinned bow mesh in it; the cat's own bow is tinted instead" % path)
		return {}
	var src_sk: Skeleton3D = null
	if not src.skeleton.is_empty():
		src_sk = src.get_node_or_null(src.skeleton) as Skeleton3D
	if src_sk == null:
		src_sk = _find(root, "Skeleton3D") as Skeleton3D
	var from_skin := src.skin
	var skin := Skin.new()
	for i in from_skin.get_bind_count():
		var bname := String(from_skin.get_bind_name(i))
		if bname == "" and src_sk != null:
			var bi := from_skin.get_bind_bone(i)
			if bi >= 0 and bi < src_sk.get_bone_count():
				bname = src_sk.get_bone_name(bi)
		if bname == "" or skeleton.find_bone(bname) < 0:
			push_warning("%s: bind %d (\"%s\") is not a bone of the cat's skeleton; the cat's own bow is tinted instead" % [path, i, bname])
			return {}
		skin.add_named_bind(bname, from_skin.get_bind_pose(i))
	var mats: Array = []
	for i in src.mesh.get_surface_count():
		mats.append(src.get_surface_override_material(i))
	return {"mesh": src.mesh, "skin": skin, "mats": mats, "override": src.material_override, "vc": ArrowScript.has_vc(src)}


## Bow parts into SK_CatBow: its mesh and named-bind skin (the cat's skeleton drives it), its own materials; a
## vertex-coloured bow gets the shared colour shader, untinted (it has its own colours).
func _put_bow(bow_mesh: MeshInstance3D, parts: Dictionary) -> void:
	if bow_mesh.mesh != parts["mesh"]:
		bow_mesh.skin = parts["skin"]
		bow_mesh.mesh = parts["mesh"]
	if bool(parts["vc"]):
		Props.vc_surfaces(bow_mesh)                     # the shared colour shader; M_Glow surfaces keep their glow
		bow_mesh.set_instance_shader_parameter("tint", Color(1, 1, 1))
		return
	var mats: Array = parts["mats"]
	for i in mini(bow_mesh.get_surface_override_material_count(), mats.size()):
		bow_mesh.set_surface_override_material(i, mats[i])
	bow_mesh.material_override = parts["override"]


## Fishing (fishing.gd): the bow goes away and the rod from the Fishing Spot sits in the bow paw (the bone named
## bones.bow_hand in the hero's clips JSON). A hero without that bone keeps its bow; the rod then stays on the rack.
func set_fishing(on: bool) -> void:
	var bow := model.find_child("SK_CatBow", true, false) as Node3D
	if not on:
		if _rod_hold != null and is_instance_valid(_rod_hold):
			_rod_hold.queue_free()
		_rod_hold = null
		_rod = null
		if bow:
			bow.visible = true
		return
	if has_rod():
		return
	var idx := skeleton.find_bone(_bow_hand())
	if idx < 0:
		return
	if bow:
		bow.visible = false
	_rod_hold = BoneAttachment3D.new()
	skeleton.add_child(_rod_hold)
	_rod_hold.bone_name = skeleton.get_bone_name(idx)
	_rod = Props.instance("fishing_rod")
	_rod_hold.add_child(_rod)
	_rod.transform = _rod_xf(idx)


func has_rod() -> bool:
	return _rod != null and is_instance_valid(_rod)


func rod_tip() -> Node3D:
	return Props.find_part(_rod, "marker_tip") if has_rod() else null


func _bow_hand() -> String:
	var path := hero_clips()
	if FileAccess.file_exists(path):
		var j = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(j) == TYPE_DICTIONARY:
			return String((j.get("bones", {}) as Dictionary).get("bow_hand", "weapon.L"))
	return "weapon.L"


## ROD_XF: the rod's place on the bone, so that in the world (right now, standing) its grip is in the paw and it points
## along ROD_DIR. The fishing_rod prop points along its own -Z from the grip.
func _rod_xf(idx: int) -> Transform3D:
	var bone_g: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(idx)
	var b := global_transform.basis.orthonormalized()
	var d := (b.x * ROD_DIR.x + Vector3.UP * ROD_DIR.y + b.z * ROD_DIR.z).normalized()
	var z := -d
	var x := Vector3.UP.cross(z).normalized()
	var y := z.cross(x)
	return bone_g.affine_inverse() * Transform3D(Basis(x, y, z), bone_g.origin)


## How far the cat shoots right now. Hidden in grass or a bush it holds its fire until an enemy is close (3 m):
## that first shot is the Ambush.
func _reach() -> float:
	return minf(3.0, Data.cat_range()) if main.hidden else Data.cat_range()


## Hidden in grass or a bush: the cat turns a little see-through.
func set_hidden_look(on: bool) -> void:
	_hide_tws = _hide_tws.filter(func(x): return x is Tween and (x as Tween).is_valid())
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var g := mi as GeometryInstance3D
		var tw := create_tween()
		tw.tween_property(g, "transparency", 0.45 if on else 0.0, 0.25)
		_hide_tws.append(tw)


## H3: health back from a potion (Effects "heal", the Effects holder's heal over time): never past her max health and
## never while she is down. A "+N" floats up, as the camp's rest does.
func heal(points: int) -> void:
	if points <= 0 or hp <= 0:
		return
	var before := hp
	hp = mini(hp + points, Data.cat_max_hp())
	if hp > before and main != null:
		Fx.text(main, global_position + Vector3(0, 1.4, 0), "+%d" % (hp - before), Color(0.5, 1.0, 0.5))


func revive(at: Vector3) -> void:
	hp = Data.cat_max_hp()
	global_position = at
	_invuln = 1.5
	_knock = Vector3.ZERO
	target = null
	Fx.sparkle(main, global_position + Vector3(0, 0.6, 0))


func _find(node: Node, type: String) -> Node:
	if node.is_class(type):
		return node
	for c in node.get_children():
		var r := _find(c, type)
		if r != null:
			return r
	return null


func _is_upper(bone: int) -> bool:
	while bone >= 0:
		var n := skeleton.get_bone_name(bone)
		for c in CLOTH:
			if n.begins_with(c):
				return false
		if n == UPPER_FROM:
			return true
		bone = skeleton.get_bone_parent(bone)
	return false


func _build_tree() -> void:
	var graph := AnimationNodeBlendTree.new()
	var loco := AnimationNodeTransition.new()
	loco.xfade_time = 0.18
	graph.add_node("loco", loco, Vector2.ZERO)
	var i := 0
	for clip in ["Idle", "Walk", "Run"]:
		var node := AnimationNodeAnimation.new()
		node.animation = clip
		graph.add_node("clip_" + clip, node, Vector2.ZERO)
		loco.add_input(clip)
		graph.connect_node("loco", i, "clip_" + clip)
		i += 1
	graph.add_node("loco_speed", AnimationNodeTimeScale.new(), Vector2.ZERO)
	graph.connect_node("loco_speed", 0, "loco")
	var shoot := AnimationNodeAnimation.new()
	shoot.animation = "Shoot"
	graph.add_node("clip_Shoot", shoot, Vector2.ZERO)
	graph.add_node("shoot_seek", AnimationNodeTimeSeek.new(), Vector2.ZERO)
	graph.connect_node("shoot_seek", 0, "clip_Shoot")
	graph.add_node("shoot_speed", AnimationNodeTimeScale.new(), Vector2.ZERO)
	graph.connect_node("shoot_speed", 0, "shoot_seek")
	var mix := AnimationNodeBlend2.new()
	mix.sync = true                                     # the Shoot loop keeps time even while it is blended out
	mix.filter_enabled = true
	var shoot_anim := anim.get_animation("Shoot")
	for t in shoot_anim.get_track_count():
		var path := shoot_anim.track_get_path(t)
		if path.get_subname_count() == 0:
			continue
		var bone := skeleton.find_bone(path.get_subname(0))
		if bone >= 0 and _is_upper(bone):
			mix.set_filter_path(path, true)
	graph.add_node("mix", mix, Vector2.ZERO)
	graph.connect_node("mix", 0, "loco_speed")
	graph.connect_node("mix", 1, "shoot_speed")
	# Dedicated upper-body mounted loops. The seat remains aligned with the mount while the torso and arms aim.
	# All five poses use the same draw/release clock, so changing direction cannot restart or duplicate a shot.
	var seated := AnimationNodeBlendSpace1D.new()
	seated.min_space = -150.0
	seated.max_space = 150.0
	seated.sync = true
	var mounted_clips := ["RearRight", "QuarterRight", "Front", "QuarterLeft", "RearLeft"]
	for p in mounted_clips.size():
		var node := AnimationNodeAnimation.new()
		node.animation = "mounted/" + mounted_clips[p]
		seated.add_blend_point(node, -150.0 + float(p) * 75.0, -1, mounted_clips[p])
	graph.add_node("seated", seated, Vector2.ZERO)
	graph.add_node("seated_seek", AnimationNodeTimeSeek.new(), Vector2.ZERO)
	graph.connect_node("seated_seek", 0, "seated")
	graph.add_node("seated_speed", AnimationNodeTimeScale.new(), Vector2.ZERO)
	graph.connect_node("seated_speed", 0, "seated_seek")
	var seat_mix := AnimationNodeBlend2.new()
	seat_mix.sync = true
	seat_mix.filter_enabled = true
	for t in shoot_anim.get_track_count():
		var path := shoot_anim.track_get_path(t)
		if path.get_subname_count() > 0:
			var bone := skeleton.find_bone(path.get_subname(0))
			if bone >= 0 and _is_upper(bone):
				seat_mix.set_filter_path(path, true)
	graph.add_node("seat_mix", seat_mix, Vector2.ZERO)
	graph.connect_node("seat_mix", 0, "mix")
	graph.connect_node("seat_mix", 1, "seated_speed")
	graph.connect_node("output", 0, "seat_mix")
	tree = AnimationTree.new()
	tree.tree_root = graph
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(anim)
	tree.active = true
	tree.set("parameters/loco/transition_request", "Idle")
	tree.set("parameters/loco_speed/scale", 1.0)
	tree.set("parameters/mix/blend_amount", 0.0)
	tree.set("parameters/shoot_speed/scale", 1.0)
	tree.set("parameters/seated_speed/scale", 1.0)
	tree.set("parameters/seat_mix/blend_amount", 0.0)


func _loco(clip: String, scale: float) -> void:
	if clip != loco_clip:
		loco_clip = clip
		tree.set("parameters/loco/transition_request", clip)
	loco_scale = scale
	tree.set("parameters/loco_speed/scale", scale)


func _process(delta: float) -> void:
	if frozen:
		return
	_invuln = maxf(0.0, _invuln - delta)
	slow_t = maxf(0.0, slow_t - delta)
	reveal_t = maxf(0.0, reveal_t - delta)
	model.visible = _invuln <= 0.0 or fmod(_invuln, 0.12) < 0.08        # blink while hurt
	position += _knock * delta
	_knock = _knock.lerp(Vector3.ZERO, 1.0 - exp(-9.0 * delta))

	var joy: Vector2 = main.joystick.vector
	var moving := hp > 0 and joy.length() > 0.01
	var dir := Vector3.ZERO
	var speed := 0.0
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_dash_iframe = maxf(0.0, _dash_iframe - delta)
	if _dash_t > 0.0 and hp > 0:
		# the Leaf Dash: straight along its line (walls and pillars still hold the cat), the cat keeps aiming and shooting
		_dash_t -= delta
		position += _dash_dir * _dash_speed * delta
		slow_t = 0.0
		moving = true
		dir = _dash_dir
		speed = _dash_speed
		if fmod(_dash_t, 0.06) < delta:
			Fx.petals(main, global_position + Vector3(0, 0.4, 0))
	elif moving:
		dir = Vector3(joy.x, 0.0, joy.y).normalized()               # screen up = away from the camera = -Z
		speed = Data.cat_speed() * minf(joy.length(), 1.0) * (0.55 if slow_t > 0.0 else 1.0)
		if riding:
			speed *= Data.pick("mount", "speed_by_level", Data.mount_level())
		position += dir * speed * delta
	position = main.world.constrain(position, 0.3, false)
	vel = vel.lerp((global_position - _vel_from) / maxf(delta, 0.0001), 0.5) if delta > 0.0 else vel
	_vel_from = global_position
	if main.guardian != null:
		position = main.guardian.push_out(position, 0.3)       # the cat never walks through the Moss Warden
	# on Thistle the cat sits in the saddle, astride, and rides the hops
	var on_mount: bool = riding and main.mount != null
	_ride_w = move_toward(_ride_w, 1.0 if on_mount else 0.0, delta / 0.25)
	var ride_want: float = main.mount.rider_height() - SEAT_DROP if on_mount else 0.0
	# seated, she keeps to the saddle as it bounds (22 Nov 2026: closer than before, so the ride's bob is in time)
	_ride_y = lerpf(_ride_y, ride_want, 1.0 - exp(-(40.0 if on_mount and _ride_w >= 0.999 else 16.0) * delta))
	model.position.y = _ride_y
	var heading: float = main.mount.rotation.y if on_mount else 0.0
	if cloth != null:
		cloth.follow(global_position, delta)

	# The mount follows the thumb. The rider acquires enemies across the wider, forward-centred firing arc.
	var cone := aim_cone() if on_mount else PI
	var mount_ahead := Vector3(sin(heading), 0, cos(heading)) if on_mount else Vector3.ZERO
	var keep := minf(PI, cone + deg_to_rad(float(Data.b["mount"]["aim_cone_keep_deg"]))) if on_mount else PI
	if hp <= 0:
		target = null
	elif target == null or not is_instance_valid(target) or target.dead or not main.target_ok(target) \
			or target.global_position.distance_to(global_position) > _reach() + 1.0 \
			or not main.in_cone(global_position, target.global_position, mount_ahead, keep):
		target = main.nearest_enemy(global_position, _reach(), mount_ahead, cone)
	elif target == main.stations.dummy:
		var other = main.nearest_enemy(global_position, Data.cat_range(), mount_ahead, cone)
		if other != null and other != target:
			target = other
	var aiming: bool = target != null
	aim_w = move_toward(aim_w, 1.0 if aiming else 0.0, delta / AIM_BLEND)
	ride_pose.amount = _ride_w

	# the body faces what it shoots at; with nothing to shoot it faces the way it goes
	var aim_error := 0.0
	var aim_offset := 0.0                                           # the target's bearing seen from the body
	if aiming:
		var to: Vector3 = target.global_position - global_position
		var want := atan2(to.x, to.z)
		var turn_to := want
		if on_mount:
			turn_to = heading + clampf(wrapf(want - heading, -PI, PI), -cone, cone)
		facing = lerp_angle(facing, turn_to, 1.0 - exp(-TURN * delta))
		aim_offset = wrapf(want - facing, -PI, PI)
		aim_error = absf(aim_offset)
	elif on_mount:
		facing = lerp_angle(facing, heading, 1.0 - exp(-TURN * delta))      # sits facing the way Thistle runs
	elif moving:
		facing = lerp_angle(facing, atan2(dir.x, dir.z), 1.0 - exp(-TURN * delta))
	if on_mount:
		facing = heading + clampf(wrapf(facing - heading, -PI, PI), -cone, cone)   # the mount turned: she keeps within it
	rotation.y = heading if on_mount else facing

	# the legs: along the way the cat is going, forward or backward, whichever twists the body less
	var want_turn := 0.0
	var backward := false
	if aiming and moving:
		var ahead := wrapf(atan2(dir.x, dir.z) - facing, -PI, PI)           # travel direction seen from the aim
		var behind := wrapf(ahead - PI, -PI, PI)
		var turn_fwd := clampf(ahead, HIPS_MIN, HIPS_MAX)
		var turn_back := clampf(behind, HIPS_MIN, HIPS_MAX)
		var miss_fwd := absf(ahead - turn_fwd)
		var miss_back := absf(behind - turn_back)
		if legs_backward:
			backward = miss_back <= miss_fwd + KEEP_GAIT
		else:
			backward = miss_back < miss_fwd - KEEP_GAIT
		want_turn = turn_back if backward else turn_fwd
	elif aiming:
		want_turn = STANCE_HIPS
	legs_backward = backward
	hips_turn = lerpf(hips_turn, want_turn, 1.0 - exp(-10.0 * delta))
	twist.hips_yaw = hips_turn * aim_w * (1.0 - _ride_w)
	twist.upper_yaw = (STANCE_HIPS - hips_turn) * aim_w * (1.0 - _ride_w)
	ride_pose.leg_yaw = 0.0
	if on_mount:
		# Upper-body animation aims independently of the forward-facing seat and character root.
		var turn := wrapf(facing - heading, -PI, PI)
		twist.hips_yaw = 0.0
		twist.upper_yaw = 0.0
		tree.set("parameters/seated/blend_position", rad_to_deg(turn))
	else:
		# Once the root faces the target on foot, the fading mounted layer must use its front pose.
		tree.set("parameters/seated/blend_position", 0.0)
	twist.aim_yaw = wrapf(aim_offset + facing - rotation.y, -PI, PI)
	twist.aim_lock = aim_w if not on_mount or aim_error < FIRE_CONE else 0.0
	_ride_motion(delta, on_mount, heading)

	model.rotation.x = lerpf(model.rotation.x, 0.26 if _dash_t > 0.0 else 0.0, 1.0 - exp(-18.0 * delta))   # leans into a dash
	if moving and not riding:
		var clip := "Walk" if speed < WALK_BELOW else "Run"
		var rate := clampf(speed / CLIP_SPEED[clip], 0.6, 1.7 if _dash_t <= 0.0 else 2.0)
		_loco(clip, -rate if (backward and aim_w > 0.5) else rate)
	else:
		_loco("Idle", 1.0)
	tree.set("parameters/mix/blend_amount", aim_w)
	tree.set("parameters/seat_mix/blend_amount", _ride_w * aim_w)
	if bow_face:
		bow_face.weight = 0.0 if has_rod() else 1.0 - aim_w   # the string toward her while carried; not while drawing or fishing

	# shooting: a clock that runs with the Shoot loop
	if aiming and not _was_aiming:
		tree.set("parameters/shoot_seek/seek_request", 0.0)
		tree.set("parameters/seated_seek/seek_request", 0.0)
		_shoot_t = 0.0
		_fired = false
	_was_aiming = aiming
	var draw := Data.cat_draw() / Data.bow_draw_mult(Save.bow)     # the bow's draw_mult: 1.25 = a 25% slower draw
	tree.set("parameters/shoot_speed/scale", draw)
	tree.set("parameters/seated_speed/scale", draw)
	if aiming:
		_shoot_t += delta * draw
		if _shoot_t >= SHOOT_LENGTH:
			_shoot_t -= SHOOT_LENGTH
			_fired = false
		# the arrow goes at the release, or a moment later if the body is still turning to a new enemy
		if not _fired and _shoot_t >= SHOOT_RELEASE and _shoot_t < SHOOT_NOCK - 0.1 \
				and aim_w > 0.9 and aim_error < FIRE_CONE:
			_fired = true
			_fire()
	nocked.visible = aim_w > 0.5 and (not _fired or _shoot_t >= SHOOT_NOCK)

	if hp <= 0:
		state = "down"
	elif aiming:
		state = "move_shoot" if moving else "shoot"
	else:
		state = "move" if moving else "idle"


## Half the mounted firing arc, centred on the mount's joystick-controlled heading.
func aim_cone() -> float:
	return deg_to_rad(float(Data.b["mount"]["aim_cone_deg"]))


## The current bow's full shooting cycle, including draw upgrades. Attachments use the same pace.
func attack_interval() -> float:
	return SHOOT_LENGTH * Data.bow_draw_mult(Save.bow) / maxf(Data.cat_draw(), 0.001)


## 22 Nov 2026 (the owner: "make the cat move while riding"): what ride_motion.gd needs this frame, from the mount's real
## motion (balance.json mount.ride_*, see its _note_ride):
##   her hips rock with the saddle bone's own tilt (ride_follow), her back takes some of it back (ride_upright)
##   her back gives with each bounce: a spring follows the saddle's height, and how far it lags bends her (ride_bob)
##   she leans forward with the mount's speed (ride_lean) and into its turns (ride_turn), sways a little standing still
##   (ride_sway), and a skill's jolt (ride_jolt) kicks her forward or back and settles
##   her head stays level (ride_head_steady); while she aims her chest and arms are left as the aim has them
##   (ride_aim_steady); not aiming she carries the bow clear of the mount (ride_bow_*)
## Frame time only (clamped), so nothing runs on while the game is away.
func _ride_motion(delta: float, on_mount: bool, heading: float) -> void:
	var rm = ride_motion
	if rm == null:
		return
	rm.amount = _ride_w
	rm.aim = aim_w
	if _ride_w <= 0.001 or main.mount == null:
		_rm_on = false
		_rm_jolt = 0.0
		_rm_jolt_v = 0.0
		_rm_lean = Vector2.ZERO
		return
	var mb: Dictionary = Data.b["mount"]
	var m = main.mount
	var dt := clampf(delta, 0.0, 0.05)
	var anchor: float = m.rider_height()
	if not _rm_on:                                    # just got on: the springs start at rest
		_rm_on = true
		_rm_bob_y = anchor
		_rm_bob_v = 0.0
		_rm_head = heading
		_rm_turn = 0.0
	# the mount's forward, seen from her body (she may be turned to aim)
	var seat := wrapf(heading - rotation.y, -PI, PI) if on_mount else 0.0
	rm.fwd = Vector3(sin(seat), 0.0, cos(seat))
	# her hips rock with the saddle
	var sk_b := skeleton.global_transform.basis.orthonormalized()
	var tilt: Quaternion = m.saddle_tilt() if m.has_method("saddle_tilt") else Quaternion.IDENTITY
	var tilt_sk := Quaternion(sk_b.inverse() * Basis(tilt) * sk_b)
	rm.hip_tilt = Quaternion.IDENTITY.slerp(tilt_sk, clampf(float(mb.get("ride_follow", 0.0)), 0.0, 1.0))
	rm.upright = float(mb.get("ride_upright", 0.0))
	# the springs (the bounce under her, a skill's jolt), in small steps
	var bw := TAU * maxf(float(mb.get("ride_bob_hz", 4.5)), 0.1)
	var bz := float(mb.get("ride_bob_damp", 0.55))
	var jw := TAU * maxf(float(mb.get("ride_jolt_hz", 2.2)), 0.1)
	var jz := float(mb.get("ride_jolt_damp", 0.35))
	var steps := maxi(1, ceili(dt / 0.02))
	var h := dt / float(steps)
	for i in steps:
		_rm_bob_v += (bw * bw * (anchor - _rm_bob_y) - 2.0 * bz * bw * _rm_bob_v) * h
		_rm_bob_y += _rm_bob_v * h
		_rm_jolt_v += (-jw * jw * _rm_jolt - 2.0 * jz * jw * _rm_jolt_v) * h
		_rm_jolt += _rm_jolt_v * h
	var give := clampf(anchor - _rm_bob_y, -0.15, 0.15)            # metres: + the saddle came up under her
	var bob := deg_to_rad(float(mb.get("ride_bob", 0.0))) * give / 0.1
	# speed and turns (the mount's own heading)
	var spd: float = m.speed() if m.has_method("speed") else 0.0
	var sp := clampf(spd / maxf(float(mb.get("ride_lean_full_mps", 3.5)), 0.1), 0.0, 1.0)
	var rate := clampf(wrapf(heading - _rm_head, -PI, PI) / maxf(dt, 0.0001), -4.0, 4.0) if dt > 0.0 else 0.0
	_rm_head = heading
	_rm_turn = lerpf(_rm_turn, rate, 1.0 - exp(-6.0 * dt))
	var turn_max := deg_to_rad(float(mb.get("ride_turn_max", 12.0)))
	var turn := clampf(float(mb.get("ride_turn", 0.0)) * atan(spd * _rm_turn / 9.8), -turn_max, turn_max)
	# a slow sway standing still
	_rm_sway_t += dt
	var sway := deg_to_rad(float(mb.get("ride_sway", 0.0))) * (1.0 - sp)
	var hz := float(mb.get("ride_sway_hz", 0.35))
	var sway_v := Vector2(0.5 * sway * sin(TAU * hz * 0.7 * _rm_sway_t + 1.3), sway * sin(TAU * hz * _rm_sway_t))
	var want := Vector2(deg_to_rad(float(mb.get("ride_lean", 0.0))) * sp, turn) + sway_v
	_rm_lean = _rm_lean.lerp(want, 1.0 - exp(-6.0 * dt))
	rm.lean = Vector2(_rm_lean.x + bob + _rm_jolt, _rm_lean.y)
	rm.head_steady = float(mb.get("ride_head_steady", 0.0))
	rm.aim_steady = float(mb.get("ride_aim_steady", 1.0))
	# the bow, carried clear of the mount
	var reach := _bow_tips()
	rm.bow_lo = reach.x
	rm.bow_hi = reach.y
	rm.bow_lift = float(mb.get("ride_bow_lift_m", 0.0))
	rm.bow_out = float(mb.get("ride_bow_out_m", 0.0))
	rm.bow_fwd = float(mb.get("ride_bow_fwd_m", 0.0))
	rm.bow_tilt_fwd = deg_to_rad(float(mb.get("ride_bow_tilt_fwd", 0.0)))
	rm.bow_tilt_out = deg_to_rad(float(mb.get("ride_bow_tilt_out", 0.0)))
	rm.bow_clear = float(mb.get("ride_bow_clear_m", 0.0))
	rm.bow_more_max = deg_to_rad(float(mb.get("ride_bow_more_max", 0.0)))
	rm.seat_y = SEAT_DROP
	rm.bow_on = not has_rod()
	# clear of the mount's head, ears and horns (the owner, 22 Nov 2026)
	rm.mount_skel = m._skel if m.has_method("rider_hazards") else null
	rm.hazards = m.rider_hazards() if rm.mount_skel != null else []
	rm.spheres = rider_spheres()
	rm.clear_margin = float(mb.get("ride_clear_m", 0.03))
	rm.clear_max = deg_to_rad(float(mb.get("ride_clear_max", 35.0)))
	rm.clear_slide = float(mb.get("ride_clear_slide_m", 0.0))


## 22 Nov 2026: a skill jolts her in the saddle (mount.gd calls this as the move goes; "pounce_land" as a Pounce comes
## down): her body is kicked forward (+) or back (-) by at most balance.json mount.ride_jolt[kind] degrees, then settles
## (ride_jolt_hz, ride_jolt_damp).
func ride_jolt(kind: String) -> void:
	var mb: Dictionary = Data.b["mount"]
	var deg := float((mb.get("ride_jolt", {}) as Dictionary).get(kind, 0.0))
	if deg == 0.0 or not riding:
		return
	var w := TAU * maxf(float(mb.get("ride_jolt_hz", 2.2)), 0.1)
	var z := clampf(float(mb.get("ride_jolt_damp", 0.35)), 0.05, 0.95)
	var zz := sqrt(1.0 - z * z)
	var peak := exp(-z / zz * atan(zz / z)) / w           # how far a kick of 1 rad/s takes a damped spring at most
	_rm_jolt_v += deg_to_rad(deg) / peak
	jolts += 1


## 22 Nov 2026: what of the cat must stay clear of the mount's head, ears and horns while she rides, as spheres fitted to
## her own mesh (once): [[bone, centre in that bone's frame, radius], ...]: her head (with the hood), the tips and middles
## of her ears, her chest. ride_motion.gd leans her away when a mount point comes inside one.
var _spheres: Array = []
var _spheres_done := false


func rider_spheres() -> Array:
	if _spheres_done:
		return _spheres
	_spheres_done = true
	var head := skeleton.find_bone("head")
	var chest := skeleton.find_bone("chest")
	var sets := {"head": [], "chest": [], "ear.L": [], "ear.R": []}
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.skin == null or mi.name == "SK_CatBow":
			continue
		var bind_of := {}                                  # bone -> bind index in this skin
		for i in mi.skin.get_bind_count():
			var b := mi.skin.get_bind_bone(i)
			if b < 0:
				b = skeleton.find_bone(String(mi.skin.get_bind_name(i)))
			bind_of[b] = i
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var weights = arr[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null or verts.is_empty():
				continue
			var stride := int(float(bones.size()) / float(verts.size()))
			for v in verts.size():
				var best := -1
				var bw := 0.0
				for k in stride:
					var w: float = weights[v * stride + k]
					if w > bw:
						bw = w
						best = int(bones[v * stride + k])
				if best < 0 or best >= mi.skin.get_bind_count():
					continue
				var bone := mi.skin.get_bind_bone(best)
				if bone < 0:
					bone = skeleton.find_bone(String(mi.skin.get_bind_name(best)))
				var nm := skeleton.get_bone_name(bone) if bone >= 0 else ""
				var key := ""
				if nm == "head" or nm.begins_with("hood."):
					key = "head"
				elif nm == "ear.L" or nm == "ear.R":
					key = nm
				elif nm == "chest" or nm.begins_with("shoulder."):
					key = "chest"
				if key == "":
					continue
				var to_bone := {"head": head, "chest": chest, "ear.L": skeleton.find_bone("ear.L"), "ear.R": skeleton.find_bone("ear.R")}[key] as int
				if not bind_of.has(to_bone):
					continue
				(sets[key] as Array).append(mi.skin.get_bind_pose(bind_of[to_bone]) * verts[v])
	for key in ["head", "chest"]:
		var pts: Array = sets[key]
		if pts.size() < 8:
			continue
		var lo: Vector3 = pts[0]
		var hi: Vector3 = pts[0]
		for p in pts:
			lo = lo.min(p)
			hi = hi.max(p)
		var c := (lo + hi) * 0.5
		var ds: Array = []
		for p in pts:
			ds.append(c.distance_to(p))
		ds.sort()
		var r: float = ds[int(ds.size() * (0.85 if key == "head" else 0.7))]
		_spheres.append([head if key == "head" else chest, c, r, key])
	for key in ["ear.L", "ear.R"]:
		var pts: Array = sets[key]
		if pts.is_empty():
			continue
		var tip: Vector3 = pts[0]
		for p in pts:
			if (p as Vector3).length() > tip.length():
				tip = p
		var eb := skeleton.find_bone(key)
		_spheres.append([eb, tip * 0.92, 0.035, key + " tip"])
		_spheres.append([eb, tip * 0.5, 0.045, key + " middle"])
	return _spheres


## How far the bow in the paw reaches along its bone's +Y: (lower tip, upper tip), from its mesh as bound (measured once
## per bow mesh). For the bow carry in the saddle.
func _bow_tips() -> Vector2:
	var bm := model.find_child("SK_CatBow", true, false) as MeshInstance3D
	if bm == null or bm.mesh == null or bm.skin == null:
		return _bow_reach
	if bm.mesh == _bow_reach_of:
		return _bow_reach
	_bow_reach_of = bm.mesh
	var bind := -1
	var bone := _bow_hand()
	for i in bm.skin.get_bind_count():
		var nm := String(bm.skin.get_bind_name(i))
		if nm == "" and bm.skin.get_bind_bone(i) >= 0 and bm.skin.get_bind_bone(i) < skeleton.get_bone_count():
			nm = skeleton.get_bone_name(bm.skin.get_bind_bone(i))
		if nm == bone:
			bind = i
			break
	if bind < 0:
		return _bow_reach
	var bp := bm.skin.get_bind_pose(bind)
	var lo := 0.0
	var hi := 0.0
	for sidx in bm.mesh.get_surface_count():
		var arr := bm.mesh.surface_get_arrays(sidx)
		for v in arr[Mesh.ARRAY_VERTEX]:
			var y: float = (bp * (v as Vector3)).y
			lo = minf(lo, y)
			hi = maxf(hi, y)
	if hi - lo > 0.1:
		_bow_reach = Vector2(lo, hi)
	return _bow_reach


func _fire() -> void:
	var start := nocked.global_position
	var aim_at: Vector3 = target.global_position + Vector3(0.0, target.aim_height, 0.0)
	var bow := Data.bow_info(Save.bow)
	var n := int(bow["arrows"])
	var spread := deg_to_rad(float(bow["spread_deg"]))
	var fire := Data.bow_burn(Save.bow)                  # G3: the Ember Bow's fire arrows ({} for the others)
	var ice := Data.bow_frost(Save.bow)                  # 22 Nov 2026: the Frost Bow's ice arrows ({} for the others)
	var dmg := Data.arrow_damage()
	if main.ambush_ready and target != main.stations.dummy:
		main.ambush_ready = false
		dmg *= 2.0
		Fx.text(main, target.global_position + Vector3(0, float(target.aim_height) * 2.0 + 0.6, 0), "Ambush!", Color(1.0, 0.85, 0.3))
		Fx.sparkle(main, start)
	elif main.empowered_t > 0.0 and target != main.stations.dummy:
		main.empowered_t = 0.0                           # Phase E: a close call's arrow hits double
		dmg *= 2.0
		Fx.text(main, target.global_position + Vector3(0, float(target.aim_height) * 2.0 + 0.6, 0), "Double!", Color(0.6, 1.0, 0.8))
		Fx.sparkle(main, start)
	reveal_t = 1.4
	for k in n:
		var dir := aim_at - start
		if n > 1:
			dir = dir.rotated(Vector3.UP, spread * (float(k) - (n - 1) * 0.5))
		var arrow := Pools.take(ArrowScript.POOL, _new_arrow)  # H1: from the arrow pool (arrow.gd)
		main.add_child(arrow)
		arrow.launch(start, dir, main, dmg, int(bow["pierce"]), fire, Save.bow, ice)
	shots_fired += 1
	Sfx.play("shoot", -10.0)
	# 22 Nov 2026: the release: a glint and a puff or sparks at the bow (about where the arrow rests on it), and the bow
	# flashes for a moment
	var aim := (aim_at - start).normalized()
	Fx.shot_burst(main, start + aim * ArrowScript.length_for(Save.bow) * 0.8, aim, Data.bow_fx(Save.bow))
	_recoil_flash()


## H1: a new arrow for the pool (Pools.take makes one only when none is waiting), already wearing the equipped bow's
## model and trail, so a shot with that bow makes nothing new.
func _new_arrow() -> Node:
	var a: Node3D = ArrowScript.new()
	a.dress(Save.bow, Data.bow_burn(Save.bow))
	return a


## H1: the first arrows, made ahead when the camp opens (balance.json pools.arrows, by graphics level).
func prewarm_arrows() -> void:
	Pools.prewarm(ArrowScript.POOL, _new_arrow, Pools.size_for("arrows"))


var _bow_mesh: MeshInstance3D                           # the cat's SK_CatBow (found once)
var _flash_tw: Tween


## 22 Nov 2026: the bow flashes pale for a moment as the arrow goes (a bow drawn with the shared colour shader; the
## plain CatRanger bow's own materials have no flash).
func _recoil_flash() -> void:
	if _bow_mesh == null or not is_instance_valid(_bow_mesh):
		_bow_mesh = model.find_child("SK_CatBow", true, false) as MeshInstance3D
	if _bow_mesh == null or _bow_mesh.mesh == null:
		return
	var vc := false
	for i in _bow_mesh.mesh.get_surface_count():
		vc = vc or _bow_mesh.get_active_material(i) is ShaderMaterial
	if not vc:
		return
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	_flash_tw = create_tween()
	_flash_tw.tween_method(_set_bow_flash, 0.5, 0.0, 0.15)


func _set_bow_flash(v: float) -> void:
	if _bow_mesh != null and is_instance_valid(_bow_mesh):
		_bow_mesh.set_instance_shader_parameter("flash", v)


func hurt(from: Vector3, amount := 1) -> void:
	if invincible or _invuln > 0.0 or hp <= 0 or main.world.inside_camp(global_position):
		return
	if _dash_iframe > 0.0:
		_close_call()                                # mid-dash: nothing hurts, and the next arrow hits double
		return
	main.fight.busy()
	if riding and main.mount != null and main.mount.hp > 0:
		_invuln = 1.2                                # the mount takes the hit for the cat
		main.mount.hurt(amount, from)
		if main.area != null:
			main.burrows.on_cat_hurt()
		return
	hp = maxi(0, hp - amount)
	_invuln = 1.2
	if main.area != null:
		main.burrows.on_cat_hurt()                   # Phase E: the run is saved (and a gauntlet chest stays shut)
	var away := global_position - from
	away.y = 0.0
	_knock = away.normalized() * 4.0
	main.on_player_hurt()
	if hp <= 0:
		effects.clear()                              # H3: her potions end (and Data's Damage and Speed shares go back)
		main.on_player_down()


# ---------------------------------------------------------------- Phase E: the Leaf Dash
## A dash of burrows.dash.distance metres in dir (a screen direction; the stick's or the facing when zero), in
## dash.time seconds, untouchable for dash.iframes seconds. False when it is recharging or the cat is down.
func dash(dir: Vector2) -> bool:
	if hp <= 0 or frozen or _dash_cd > 0.0 or _dash_t > 0.0:
		return false
	var dc: Dictionary = Data.burrow_cfg()["dash"]
	var d3 := Vector3(dir.x, 0.0, dir.y)
	if d3.length() < 0.01:
		d3 = Vector3(sin(facing), 0.0, cos(facing))
	_dash_dir = d3.normalized()
	var dist := float(dc["distance"]) + float(Data.run_mods.get("dash_dist", 0.0))
	var secs := float(dc["time"])
	_dash_speed = dist / secs
	_dash_t = secs
	_dash_iframe = float(dc["iframes"])
	_dash_cd_total = float(dc["cooldown"]) * (1.0 - float(Data.run_mods.get("dash_cd", 0.0)))
	_dash_cd = _dash_cd_total
	if target == null and dir.length() > 0.01:
		facing = atan2(_dash_dir.x, _dash_dir.z)
	dashes += 1
	Fx.boing(model, 0.18)
	Fx.dust(main, global_position, 6, 1.0)
	Fx.petals(main, global_position + Vector3(0, 0.5, 0))
	if ResourceLoader.exists("res://assets/sfx/whoosh.wav"):
		Sfx.play("whoosh", -6.0)
	else:
		Sfx.play("pop", -10.0)
	return true


## Something would have hurt the cat mid-dash: it is ignored, and the next arrow within close_call_s hits double.
func _close_call() -> void:
	close_calls += 1
	main.empowered_t = float(Data.burrow_cfg()["dash"]["close_call_s"])
	Fx.text(main, global_position + Vector3(0, 1.7, 0), "Close call!", Color(0.6, 1.0, 0.8))
	Fx.sparkle(main, global_position + Vector3(0, 1.0, 0))


## How far the dash has recharged (1 = ready); the HUD draws an arc under the health bar while it is below 1.
func dash_ready_frac() -> float:
	if _dash_cd <= 0.0:
		return 1.0
	return clampf(1.0 - _dash_cd / maxf(_dash_cd_total, 0.01), 0.0, 1.0)


func dashing() -> bool:
	return _dash_t > 0.0
