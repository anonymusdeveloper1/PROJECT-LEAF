extends RefCounted
## The shop cards' pictures (Phase G2, 20 Nov 2026; docs/PHASE_G_PLAN.md, G2 item 7): flat and readable at 48 px, in
## the game's warm palette with the marker badges' dark brown ink. Each is an SVG drawn once in code at SIZE pixels
## (with mipmaps, so it stays smooth when shown small) and kept, the way marker.gd draws its badges. hud.gd's icon(id)
## asks here for every id it does not draw itself (the currencies and the goal ticks).
## An unknown id gets a plain round disc: a shop tile writes its title's first letter on it (hud.gd).
## Some pictures are the marker badges' own art (the same drawings, cropped to their middle): they are copied here, so
## this file never depends on marker.gd's insides.

const SIZE := 128                       # pixels; shown at 48-56 HUD px (about 80 on the phone)
## Every picture drawn here, by id (a shop tile's "icon").
const IDS := ["bow", "target", "damage", "draw", "range", "heart", "speed", "magnet", "berries", "herbs", "honey", "fish",
	"goldfish", "tower", "barricade", "spikes", "well", "home", "pet", "mount", "garden", "pot", "fishing", "grow", "repair",
	"settings", "market", "stone", "flame", "chest", "sign"]
## Other names for the same pictures.
const ALIAS := {"health": "heart", "hp": "heart", "stall": "market", "cottage": "pet", "nest": "pet", "saddlery": "mount",
	"hearthtree": "home", "guardian": "stone", "fire": "flame", "campfire": "flame", "sunberries": "berries",
	"graphics": "settings", "mend": "repair", "signpost": "sign"}

## The marker badges' art (marker.gd's ART, the same drawings), in their 120 x 150 view round (60, 58); the gold fish
## is the badge's fish in gold.
const MARKER := {
	"bow": """<path d="M47 33 Q86 58 47 83" fill="none" stroke="#5B3417" stroke-width="10" stroke-linecap="round"/>
<path d="M47 33 Q86 58 47 83" fill="none" stroke="#C9813A" stroke-width="5" stroke-linecap="round"/>
<path d="M47 33 L47 83" stroke="#5B3417" stroke-width="2.5"/>
<path d="M36 58 H84" stroke="#5B3417" stroke-width="4.5" stroke-linecap="round"/>
<path d="M88 58 l-11 -7 v14 z" fill="#5B3417"/><path d="M36 58 l-4 -6 M36 58 l-4 6 M42 58 l-4 -6 M42 58 l-4 6" stroke="#D9483B" stroke-width="3" stroke-linecap="round"/>""",
	"target": """<circle cx="58" cy="60" r="25" fill="#FFF7E3" stroke="#5B3417" stroke-width="4.5"/>
<circle cx="58" cy="60" r="17" fill="#D9483B"/><circle cx="58" cy="60" r="10" fill="#FFF7E3"/><circle cx="58" cy="60" r="4.5" fill="#D9483B"/>
<path d="M85 33 L60 58" stroke="#5B3417" stroke-width="4.5" stroke-linecap="round"/>
<path d="M85 33 l-1 9 M85 33 l-9 1" stroke="#5B3417" stroke-width="4" stroke-linecap="round"/>""",
	"well": """<path d="M41 50 Q60 24 79 50" fill="none" stroke="#5B3417" stroke-width="4" stroke-linecap="round"/>
<path d="M40 50 h40 l-6 33 h-28 z" fill="#B87434" stroke="#5B3417" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M42 61 h36 M44 73 h32" stroke="#5B3417" stroke-width="3"/>
<ellipse cx="60" cy="50" rx="18" ry="4.5" fill="#5BB6EE" stroke="#5B3417" stroke-width="2.5"/>
<path d="M84 30 l2 5 l5 2 l-5 2 l-2 5 l-2 -5 l-5 -2 l5 -2 z" fill="#F2B640"/>""",
	"pet": """<path d="M46 62 h28 v22 h-28 z" fill="#FFF0D0" stroke="#5B3417" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M55 84 v-9 a5 5 0 0 1 10 0 v9 z" fill="#A8692E" stroke="#5B3417" stroke-width="2.5"/>
<path d="M33 63 Q35 33 60 31 Q85 33 87 63 Z" fill="#D9483B" stroke="#5B3417" stroke-width="4.5" stroke-linejoin="round"/>
<circle cx="49" cy="47" r="4.5" fill="#FFF7E3"/><circle cx="66" cy="41" r="4" fill="#FFF7E3"/><circle cx="75" cy="54" r="3.5" fill="#FFF7E3"/><circle cx="58" cy="56" r="3" fill="#FFF7E3"/>""",
	"market": """<path d="M41 52 V84 M79 52 V84" stroke="#5B3417" stroke-width="4.5" stroke-linecap="round"/>
<rect x="36" y="69" width="48" height="11" rx="2.5" fill="#B87434" stroke="#5B3417" stroke-width="4"/>
<path d="M54 69 l5 -11 l5 11 z" fill="#F08A2E" stroke="#5B3417" stroke-width="2"/>
<path d="M33 48 L40 32 H80 L87 48 Z" fill="#FFF7E3"/>
<path d="M48 32 L56 32 L54.6 48 L43.8 48 Z M64 32 L72 32 L76.2 48 L65.4 48 Z" fill="#5DA83A"/>
<path d="M33 48 a5.4 5.4 0 0 0 10.8 0 Z M54.6 48 a5.4 5.4 0 0 0 10.8 0 Z M76.2 48 a5.4 5.4 0 0 0 10.8 0 Z" fill="#FFF7E3" stroke="#5B3417" stroke-width="2.5"/>
<path d="M43.8 48 a5.4 5.4 0 0 0 10.8 0 Z M65.4 48 a5.4 5.4 0 0 0 10.8 0 Z" fill="#5DA83A" stroke="#5B3417" stroke-width="2.5"/>
<path d="M33 48 L40 32 H80 L87 48 Z" fill="none" stroke="#5B3417" stroke-width="4.5" stroke-linejoin="round"/>""",
	"sign": """<path d="M45 86 V30" stroke="#5B3417" stroke-width="6" stroke-linecap="round"/>
<path d="M48 31 H84 L75 42 L84 53 H48 Z" fill="#FF8A5B" stroke="#5B3417" stroke-width="4" stroke-linejoin="round"/>
<path d="M55 37 l3 6 l6 1 l-5 4 l1 6 l-5 -3 l-5 3 l1 -6 l-4 -4 l6 -1 z" fill="#FFF7E3" transform="translate(4 -2) scale(0.9)"/>
<path d="M36 86 H56" stroke="#5B3417" stroke-width="5" stroke-linecap="round"/>""",
	"stone": """<path d="M43 85 L45 43 Q60 27 75 43 L77 85 Z" fill="#A3ACB2" stroke="#4A4F55" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M60 76 c-9 -4 -9 -17 0 -24 c9 7 9 20 0 24 z M60 76 V56" fill="none" stroke="#47D18E" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M45 50 q7 -6 13 -1 M62 36 q6 -2 9 3" stroke="#5DA83A" stroke-width="4.5" fill="none" stroke-linecap="round"/>""",
	"garden": """<path d="M34 84 Q60 64 86 84 Z" fill="#8A5A2B" stroke="#5B3417" stroke-width="4" stroke-linejoin="round"/>
<path d="M60 77 V50" stroke="#3E6B1F" stroke-width="4.5" stroke-linecap="round"/>
<path d="M60 56 C47 56 38 46 38 34 C51 34 60 43 60 56 Z" fill="#7CC447" stroke="#3E6B1F" stroke-width="3.5" stroke-linejoin="round"/>
<path d="M60 52 C71 52 82 44 82 31 C69 31 60 39 60 52 Z" fill="#8FD656" stroke="#3E6B1F" stroke-width="3.5" stroke-linejoin="round"/>""",
	"pot": """<path d="M49 46 q-4 -5 0 -9 q4 -4 0 -9 M61 46 q-4 -5 0 -9 q4 -4 0 -9 M73 46 q-4 -5 0 -9" fill="none" stroke="#A9B2B8" stroke-width="3.5" stroke-linecap="round"/>
<path d="M38 55 h44 v6 q0 23 -22 23 q-22 0 -22 -23 z" fill="#555B63" stroke="#2E2A26" stroke-width="4.5" stroke-linejoin="round"/>
<rect x="33" y="51" width="54" height="8" rx="4" fill="#7A8189" stroke="#2E2A26" stroke-width="3.5"/>
<path d="M44 66 q4 8 12 10" stroke="#8A929A" stroke-width="3" fill="none" stroke-linecap="round"/>""",
	"fish": """<path d="M33 58 Q50 39 72 52 L87 41 L84 58 L87 75 L72 64 Q50 77 33 58 Z" fill="#5BB6EE" stroke="#24557A" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M52 50 q-4 8 0 16" stroke="#24557A" stroke-width="3" fill="none" stroke-linecap="round"/>
<circle cx="43" cy="55" r="3.2" fill="#24557A"/>""",
	"goldfish": """<path d="M33 58 Q50 39 72 52 L87 41 L84 58 L87 75 L72 64 Q50 77 33 58 Z" fill="#FFB13B" stroke="#8A4A12" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M52 50 q-4 8 0 16" stroke="#8A4A12" stroke-width="3" fill="none" stroke-linecap="round"/>
<path d="M57 53 q6 -1.5 10 2" stroke="#FFE9A8" stroke-width="3" fill="none" stroke-linecap="round"/>
<circle cx="43" cy="55" r="3.2" fill="#5B3417"/>
<path d="M44 28 l2 4.5 l4.5 2 l-4.5 2 l-2 4.5 l-2 -4.5 l-4.5 -2 l4.5 -2 z" fill="#FFE27A" stroke="#C98A12" stroke-width="1.2"/>""",
	"flame": """<path d="M60 86 C42 86 35 72 41 60 C45 52 50 49 50 39 C58 45 60 51 60 56 C64 49 68 42 66 31 C78 41 85 55 81 68 C78 80 70 86 60 86 Z" fill="#FF8A3B" stroke="#8A3A12" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M60 83 C52 83 48 76 52 68 C56 62 60 62 60 56 C66 62 70 70 68 76 C66 81 64 83 60 83 Z" fill="#FFD54A"/>""",
	"chest": """<rect x="35" y="52" width="50" height="31" rx="3" fill="#B87434" stroke="#5B3417" stroke-width="4.5"/>
<path d="M35 55 V47 Q60 30 85 47 V55 Z" fill="#D08A3E" stroke="#5B3417" stroke-width="4.5" stroke-linejoin="round"/>
<path d="M35 57 H85" stroke="#5B3417" stroke-width="3.5"/>
<rect x="54" y="52" width="12" height="14" rx="2.5" fill="#F2B640" stroke="#5B3417" stroke-width="3"/>"""}

static var _cache := {}                 # id -> its texture
static var failed: Array = []           # ids whose SVG did not load (the tests check this stays empty)


## There is a picture for this id (else texture() gives the plain disc).
static func known(id: String) -> bool:
	return IDS.has(String(ALIAS.get(id, id)))


## The picture for an id, made once (a plain round disc for an unknown one).
static func texture(id: String) -> Texture2D:
	var k := String(ALIAS.get(id, id))
	if not IDS.has(k):
		k = "?"
	if _cache.has(k):
		return _cache[k]
	var view := "28 26 64 64" if MARKER.has(k) else "0 0 64 64"     # the badges' art sits round (60, 58)
	var art := String(MARKER[k]) if MARKER.has(k) else _art(k)
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"%s\">%s</svg>" % [SIZE, SIZE, view, art]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	if err != OK or img.is_empty():
		failed.append(k)
		push_warning("ui_icons: the '%s' picture did not load" % k)
		img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.79, 0.5, 0.23))
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[k] = tex
	return tex


## A star's points ("x,y x,y ..."): n tips at r1, the dips between them at r2, the first tip straight up.
static func _star(cx: float, cy: float, r1: float, r2: float, n: int) -> String:
	var pts := PackedStringArray()
	for i in n * 2:
		var a := -PI * 0.5 + PI * float(i) / float(n)
		var r := r1 if i % 2 == 0 else r2
		pts.append("%.1f,%.1f" % [cx + cos(a) * r, cy + sin(a) * r])
	return " ".join(pts)


## A cog's outline ("x,y x,y ..."): `teeth` teeth from r_in out to r_out.
static func _gear(cx: float, cy: float, r_in: float, r_out: float, teeth: int) -> String:
	var pts := PackedStringArray()
	for i in teeth:
		var a := TAU * float(i) / float(teeth)
		for p in [[-0.22, r_in], [-0.13, r_out], [0.13, r_out], [0.22, r_in]]:
			var aa := a + float(p[0])
			var rr := float(p[1])
			pts.append("%.1f,%.1f" % [cx + cos(aa) * rr, cy + sin(aa) * rr])
	return " ".join(pts)


## The pictures drawn for the shop (a 64 x 64 view, outlines in the badges' ink #5B3417).
static func _art(k: String) -> String:
	match k:
		"heart":
			return """<path d="M32 55 C20 47 7 38 7 24 C7 15 14 9 21.5 9 C26.5 9 30 12 32 16 C34 12 37.5 9 42.5 9 C50 9 57 15 57 24 C57 38 44 47 32 55 Z" fill="#E5533F" stroke="#5B3417" stroke-width="4" stroke-linejoin="round"/>
<path d="M15 22 C15.5 17.5 18.5 15 22 15" fill="none" stroke="#FFFFFF" stroke-opacity="0.75" stroke-width="3.5" stroke-linecap="round"/>"""
		"damage":                                   # an arrowhead striking: a burst behind its tip
			return ("""<polygon points="%s" fill="#FFD54A" stroke="#E0692E" stroke-width="2.5" stroke-linejoin="round"/>""" % _star(44.0, 20.0, 16.0, 8.0, 8)) + """
<path d="M11 53 L37 27" stroke="#5B3417" stroke-width="8.5" stroke-linecap="round"/>
<path d="M11 53 L37 27" stroke="#C9813A" stroke-width="4" stroke-linecap="round"/>
<path d="M15 49 L15 56 M15 49 L8 49 M20 44 L20 51 M20 44 L13 44" stroke="#D9483B" stroke-width="3.5" stroke-linecap="round"/>
<path d="M48 16 L44.5 32.5 L36 28 L31.5 19.5 Z" fill="#B7C0C6" stroke="#5B3417" stroke-width="3.5" stroke-linejoin="round"/>"""
		"draw":                                     # draw speed: an arrow flying fast
			return """<path d="M4 22 H16 M8 42 H18 M2 32 H11" stroke="#5B3417" stroke-opacity="0.45" stroke-width="3.5" stroke-linecap="round"/>
<path d="M20 32 H46" stroke="#5B3417" stroke-width="8.5" stroke-linecap="round"/>
<path d="M20 32 H46" stroke="#C9813A" stroke-width="4" stroke-linecap="round"/>
<path d="M24 32 L18 25 M24 32 L18 39 M30 32 L24 25 M30 32 L24 39" stroke="#D9483B" stroke-width="3.5" stroke-linecap="round"/>
<path d="M59 32 L44 23 L47.5 32 L44 41 Z" fill="#B7C0C6" stroke="#5B3417" stroke-width="3.5" stroke-linejoin="round"/>"""
		"range":                                    # a spyglass: seeing (and shooting) further
			return """<g transform="translate(30 34) rotate(-32)">
<rect x="-27" y="-5" width="13" height="10" rx="2.5" fill="#8A5A2B" stroke="#5B3417" stroke-width="3"/>
<rect x="-15" y="-7.5" width="17" height="15" rx="2.5" fill="#C9813A" stroke="#5B3417" stroke-width="3"/>
<rect x="1" y="-10.5" width="24" height="21" rx="3" fill="#D08A3E" stroke="#5B3417" stroke-width="3.5"/>
<rect x="19" y="-12" width="7" height="24" rx="2.5" fill="#F2B640" stroke="#5B3417" stroke-width="3"/>
<ellipse cx="28" cy="0" rx="2.5" ry="9" fill="#5BB6EE" stroke="#5B3417" stroke-width="2.5"/>
<path d="M5 -5 H16" stroke="#FFFFFF" stroke-opacity="0.6" stroke-width="2.5" stroke-linecap="round"/>
</g>"""
		"speed":                                    # a paw on the run
			return """<path d="M4 32 H15 M3 42 H20 M7 52 H24" stroke="#5B3417" stroke-opacity="0.45" stroke-width="3.5" stroke-linecap="round"/>
<ellipse cx="39" cy="44" rx="12.5" ry="10.5" fill="#D08A3E" stroke="#5B3417" stroke-width="3.5"/>
<ellipse cx="23.5" cy="29.5" rx="4.8" ry="6" fill="#D08A3E" stroke="#5B3417" stroke-width="3"/>
<ellipse cx="32.5" cy="21" rx="4.8" ry="6.2" fill="#D08A3E" stroke="#5B3417" stroke-width="3"/>
<ellipse cx="45.5" cy="21" rx="4.8" ry="6.2" fill="#D08A3E" stroke="#5B3417" stroke-width="3"/>
<ellipse cx="54.5" cy="29.5" rx="4.8" ry="6" fill="#D08A3E" stroke="#5B3417" stroke-width="3"/>
<path d="M32 41 Q36 38 41 39" stroke="#FFFFFF" stroke-opacity="0.5" stroke-width="2.5" fill="none" stroke-linecap="round"/>"""
		"magnet":                                   # pulls golden leaves in
			return """<path d="M25 12 C27 5 33 3 39 5 C37 11 31 14 25 12 Z" fill="#F2B640" stroke="#8A5A12" stroke-width="2" stroke-linejoin="round"/>
<path d="M26 11.5 Q32 8 38 5.5" stroke="#8A5A12" stroke-width="1.5" fill="none" stroke-linecap="round"/>
<path d="M10 18 H26 V38 A6 6 0 0 0 38 38 V18 H54 V38 A22 22 0 0 1 10 38 Z" fill="#E5533F" stroke="#5B3417" stroke-width="3.5" stroke-linejoin="round"/>
<rect x="10" y="18" width="16" height="9" fill="#E8ECEF" stroke="#5B3417" stroke-width="3.5" stroke-linejoin="round"/>
<rect x="38" y="18" width="16" height="9" fill="#E8ECEF" stroke="#5B3417" stroke-width="3.5" stroke-linejoin="round"/>
<path d="M15 32 V40" stroke="#FFFFFF" stroke-opacity="0.6" stroke-width="3" stroke-linecap="round"/>"""
		"berries":                                  # Sunberries
			return """<path d="M32 18 C35 10 44 7 52 9 C49 17 40 20 32 18 Z" fill="#7CC447" stroke="#3E6B1F" stroke-width="3" stroke-linejoin="round"/>
<path d="M32 18 Q30 13 27 10" stroke="#3E6B1F" stroke-width="3" fill="none" stroke-linecap="round"/>
<circle cx="32" cy="28" r="11" fill="#FF8A3B" stroke="#5B3417" stroke-width="3.5"/>
<circle cx="21" cy="43" r="11" fill="#FF8A3B" stroke="#5B3417" stroke-width="3.5"/>
<circle cx="43" cy="43" r="11" fill="#FF8A3B" stroke="#5B3417" stroke-width="3.5"/>
<circle cx="28" cy="24" r="3" fill="#FFE27A"/><circle cx="17" cy="39" r="3" fill="#FFE27A"/><circle cx="39" cy="39" r="3" fill="#FFE27A"/>"""
		"herbs":                                    # a tied bunch of three sprigs
			return """<g transform="translate(32 46) rotate(-40) translate(-32 -46)"><path d="M32 46 C25 37 26 22 32 13 C38 22 39 37 32 46 Z" fill="#5DA83A" stroke="#3E6B1F" stroke-width="3" stroke-linejoin="round"/>
<path d="M32 42 V20" stroke="#3E6B1F" stroke-width="2" stroke-linecap="round"/></g>
<g transform="translate(32 46) rotate(40) translate(-32 -46)"><path d="M32 46 C25 37 26 22 32 13 C38 22 39 37 32 46 Z" fill="#8FD656" stroke="#3E6B1F" stroke-width="3" stroke-linejoin="round"/>
<path d="M32 42 V20" stroke="#3E6B1F" stroke-width="2" stroke-linecap="round"/></g>
<path d="M32 46 C24 36 25 18 32 7 C39 18 40 36 32 46 Z" fill="#7CC447" stroke="#3E6B1F" stroke-width="3" stroke-linejoin="round"/>
<path d="M32 42 V14" stroke="#3E6B1F" stroke-width="2" stroke-linecap="round"/>
<path d="M29 50 L26 59 M32 50 V60 M35 50 L38 59" stroke="#3E6B1F" stroke-width="3" stroke-linecap="round"/>
<rect x="25" y="44" width="14" height="7" rx="2.5" fill="#D9483B" stroke="#5B3417" stroke-width="2.5"/>"""
		"honey":                                    # a honey jar with a cloth lid
			return """<path d="M17 27 Q17 22 22 22 H42 Q47 22 47 27 V50 Q47 58 39 58 H25 Q17 58 17 50 Z" fill="#F2B640" stroke="#5B3417" stroke-width="3.5" stroke-linejoin="round"/>
<path d="M38 23 V29 a3 3 0 0 0 6 0 V23 Z" fill="#E09A20"/>
<rect x="14" y="12" width="36" height="11" rx="3.5" fill="#D9483B" stroke="#5B3417" stroke-width="3.5"/>
<path d="M18 23 H46" stroke="#5B3417" stroke-width="3"/>
<rect x="23" y="34" width="18" height="14" rx="3" fill="#FFF7E3" stroke="#5B3417" stroke-width="2.5"/>
<polygon points="32,36.5 36,38.8 36,43.2 32,45.5 28,43.2 28,38.8" fill="#F2B640" stroke="#8A5A12" stroke-width="1.8"/>
<path d="M21 30 V48" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="3" stroke-linecap="round"/>"""
		"tower":                                    # the acorn tower: a wooden tower under an acorn cap
			return """<path d="M19 59 L22.5 30 H41.5 L45 59 Z" fill="#B87434" stroke="#5B3417" stroke-width="3.5" stroke-linejoin="round"/>
<path d="M21.5 41 H42.5 M20.5 50 H43.5" stroke="#5B3417" stroke-width="2.5"/>
<rect x="29.5" y="34" width="5" height="9" rx="2.5" fill="#5B3417"/>
<path d="M27 59 V53 A5 5 0 0 1 37 53 V59 Z" fill="#5B3417"/>
<path d="M14 32 Q14 13 32 11 Q50 13 50 32 Z" fill="#8A5A2B" stroke="#5B3417" stroke-width="3.5" stroke-linejoin="round"/>
<path d="M20 26 L26 20 M26 30 L37 19 M35 30 L44 22" stroke="#6B4220" stroke-width="2.2" stroke-linecap="round"/>
<path d="M32 11 Q31 6 34 3" stroke="#5B3417" stroke-width="3.5" fill="none" stroke-linecap="round"/>
<path d="M13 59 H51" stroke="#5B3417" stroke-width="3.5" stroke-linecap="round"/>"""
		"barricade":                                # three sharpened stakes and a beam
			return """<path d="M10 58 V24 L16 13 L22 24 V58 Z" fill="#C9813A" stroke="#5B3417" stroke-width="3.5" stroke-linejoin="round"/>
<path d="M26 58 V20 L32 9 L38 20 V58 Z" fill="#D08A3E" stroke="#5B3417" stroke-width="3.5" stroke-linejoin="round"/>
<path d="M42 58 V24 L48 13 L54 24 V58 Z" fill="#C9813A" stroke="#5B3417" stroke-width="3.5" stroke-linejoin="round"/>
<path d="M13 30 V38 M29 26 V34 M45 30 V36" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="2.5" stroke-linecap="round"/>
<path d="M6 44 L58 32 V40 L6 52 Z" fill="#8A5A2B" stroke="#5B3417" stroke-width="3" stroke-linejoin="round"/>"""
		"spikes":                                   # a plank of spikes
			return """<path d="M8 47 L14 24 L20 47 Z M20 47 L26 16 L32 47 Z M32 47 L38 20 L44 47 Z M44 47 L50 26 L56 47 Z" fill="#C4CBD0" stroke="#4A4F55" stroke-width="3" stroke-linejoin="round"/>
<path d="M14 29 L12.8 44 M26 22 L24.5 44 M38 26 L36.6 44 M50 31 L48.8 44" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="2" stroke-linecap="round"/>
<rect x="5" y="46" width="54" height="11" rx="3.5" fill="#8A5A2B" stroke="#5B3417" stroke-width="3.5"/>
<path d="M11 51.5 H53" stroke="#6B4220" stroke-width="2"/>"""
		"home":                                     # the Hearthtree: a tree home with a warm window and its fire
			return """<path d="M23 59 Q26 50 26 38 H38 Q38 50 41 59 Z" fill="#A8692E" stroke="#5B3417" stroke-width="3.5" stroke-linejoin="round"/>
<g fill="#3E6B1F" stroke="#3E6B1F" stroke-width="7"><circle cx="32" cy="22" r="15"/><circle cx="18" cy="30" r="10.5"/><circle cx="46" cy="30" r="10.5"/></g>
<g fill="#7CC447"><circle cx="32" cy="22" r="15"/><circle cx="18" cy="30" r="10.5"/><circle cx="46" cy="30" r="10.5"/></g>
<circle cx="26" cy="17" r="4" fill="#9BE36B"/>
<path d="M28 59 V52 A4 4 0 0 1 36 52 V59 Z" fill="#5B3417"/>
<circle cx="33.5" cy="45.5" r="2" fill="#FFD54A"/>
<path d="M14 59 H52" stroke="#5B3417" stroke-width="3.5" stroke-linecap="round"/>
<path d="M48 58 C44 58 43 54.5 45 52 C46 50.5 47 49.5 47 47.5 C50 49.5 52 52.5 51 55.5 C50.5 57 49.5 58 48 58 Z" fill="#FF8A3B" stroke="#8A3A12" stroke-width="2" stroke-linejoin="round"/>"""
		"mount":                                    # a saddle (the Saddlery) on its blanket, a stirrup hanging
			return """<path d="M5 33 Q32 28 59 33 L57 44 Q32 48 7 44 Z" fill="#D9483B" stroke="#5B3417" stroke-width="3" stroke-linejoin="round"/>
<path d="M10 40 Q32 36.5 54 40" stroke="#FFF7E3" stroke-opacity="0.85" stroke-width="2" fill="none" stroke-linecap="round"/>
<path d="M36 41 V49" stroke="#5B3417" stroke-width="3.5" stroke-linecap="round"/>
<path d="M32 48 H40 L45 59 H27 Z M34 51.5 H38 L40.5 56 H31.5 Z" fill="#F2B640" fill-rule="evenodd" stroke="#5B3417" stroke-width="2.8" stroke-linejoin="round"/>
<path d="M9 9 C14 12 15 20 20 25 C26 30 37 30 43 27 C46 25 47 22 49 20 L55 21 C56 27 53 33 46 35 C36 38 22 38 14 35 C8 31 6 19 9 9 Z" fill="#A8692E" stroke="#5B3417" stroke-width="3.5" stroke-linejoin="round"/>
<circle cx="52" cy="17.5" r="4" fill="#8A5A2B" stroke="#5B3417" stroke-width="3"/>
<path d="M13 24 C16 30 24 33 33 33" stroke="#FFFFFF" stroke-opacity="0.45" stroke-width="2.5" fill="none" stroke-linecap="round"/>"""
		"fishing":                                  # a rod, its line and a bobber on the water
			return """<path d="M9 58 L51 9" stroke="#5B3417" stroke-width="6.5" stroke-linecap="round"/>
<path d="M9 58 L51 9" stroke="#C9813A" stroke-width="3" stroke-linecap="round"/>
<circle cx="18" cy="48" r="5.5" fill="#A3ACB2" stroke="#5B3417" stroke-width="2.8"/>
<path d="M51 9 Q57 22 51 33" stroke="#5B3417" stroke-opacity="0.75" stroke-width="1.8" fill="none"/>
<path d="M40 54 Q51 49 60 54" stroke="#5BB6EE" stroke-width="3.5" fill="none" stroke-linecap="round"/>
<path d="M44 40 A7 7 0 0 1 58 40 Z" fill="#E5533F"/>
<path d="M44 40 A7 7 0 0 0 58 40 Z" fill="#FFF7E3"/>
<circle cx="51" cy="40" r="7" fill="none" stroke="#5B3417" stroke-width="2.8"/>"""
		"grow":                                     # a sapling and a golden arrow up
			return """<path d="M6 58 Q19 47 32 58 Z" fill="#8A5A2B" stroke="#5B3417" stroke-width="3" stroke-linejoin="round"/>
<path d="M19 53 V32" stroke="#3E6B1F" stroke-width="3.5" stroke-linecap="round"/>
<path d="M19 40 C11 40 6 34 6 26 C14 26 19 31 19 40 Z" fill="#7CC447" stroke="#3E6B1F" stroke-width="3" stroke-linejoin="round"/>
<path d="M19 35 C27 35 32 29 32 21 C24 21 19 26 19 35 Z" fill="#8FD656" stroke="#3E6B1F" stroke-width="3" stroke-linejoin="round"/>
<path d="M47 7 L59 22 H52 V50 H42 V22 H35 Z" fill="#F2B640" stroke="#5B3417" stroke-width="3.5" stroke-linejoin="round"/>
<path d="M45 26 V45" stroke="#FFFFFF" stroke-opacity="0.6" stroke-width="2.5" stroke-linecap="round"/>"""
		"repair":                                   # a hammer and a spark
			return """<g transform="translate(32 32) rotate(38) translate(-32 -32)">
<rect x="28" y="24" width="8" height="34" rx="3" fill="#C9813A" stroke="#5B3417" stroke-width="3"/>
<path d="M29 46 H35 M29 51 H35" stroke="#5B3417" stroke-width="2"/>
<rect x="15" y="10" width="34" height="15" rx="3.5" fill="#A3ACB2" stroke="#4A4F55" stroke-width="3.5"/>
<path d="M19 14.5 H40" stroke="#FFFFFF" stroke-opacity="0.6" stroke-width="2.5" stroke-linecap="round"/>
</g>""" + ("""<polygon points="%s" fill="#FFD54A" stroke="#C98A12" stroke-width="1.5" stroke-linejoin="round"/>""" % _star(49.0, 50.0, 8.0, 3.0, 4))
		"settings":                                 # a cog
			return ("""<polygon points="%s" fill="#C9813A" stroke="#5B3417" stroke-width="3.5" stroke-linejoin="round"/>""" % _gear(32.0, 32.0, 20.0, 27.0, 8)) + """
<circle cx="32" cy="32" r="13" fill="none" stroke="#A8692E" stroke-width="3"/>
<circle cx="32" cy="32" r="7.5" fill="#FFF7E3" stroke="#5B3417" stroke-width="3.5"/>
<path d="M17 24 A17 17 0 0 1 27 15.5" stroke="#FFFFFF" stroke-opacity="0.55" stroke-width="3" fill="none" stroke-linecap="round"/>"""
	# an unknown id: a plain round disc (the tile writes its title's first letter on it)
	return """<circle cx="32" cy="32" r="26" fill="#C9813A" stroke="#5B3417" stroke-width="3.5"/>
<path d="M14 27 A19 19 0 0 1 27 13.5" stroke="#FFFFFF" stroke-opacity="0.5" stroke-width="3.5" fill="none" stroke-linecap="round"/>"""
