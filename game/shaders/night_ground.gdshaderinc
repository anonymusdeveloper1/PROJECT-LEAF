// The Burrows' night floor (night_ground.gdshader; night_ground_lite.gdshader defines LITE for Low graphics), drawn on
// one big plane from two small maps that night_floor.gd builds for each dungeon:
//   ground_map  r: the walkable ground's signed distance (0.5 = its edge, 4 m per unit, inside > 0.5)
//               g: worn (stones missing: earth, rubble, grass)   b: moss   a: wet (puddles, mud)
//   light_map   rgb: light baked in (lantern and torch pools, glow caps, crystals, embers, the Moonwell)
//               a: darker: far from the walkable ground, and the trees' and bushes' shade (for Low, which has no shadows)
//   style_map   one texel a metre north to south: the road's section there (r: bricks, g: cobbles, b: worn, a: mossy);
//               anything else is big flagstones
// The road: cool slate flagstones, brick and cobble stretches, worn stretches with earth showing, mossy ones; dark joints
// that turn mossy and grassy toward the edges, cracks, loose and missing stones, a ragged edge of moss and grass; ferns
// and fallen leaves lie on it; puddles catch a cool moon; soft moonlight dapples; warm orange pools at the lanterns and
// torches (the one warm colour). Off the road: dark leaf litter and moss. The arena: big pale flagstones, a disc of
// fitted rings round a carved sigil, thin ember cracks, a kerb of dark rocks and a warm glow beyond the rim. The
// Moonwell: pale moonstone rings round the spring. Everything reads with no lights (the light is in the maps).
render_mode specular_disabled;

uniform sampler2D ground_map : filter_linear, repeat_disable;
uniform sampler2D light_map : filter_linear, repeat_disable;
uniform sampler2D style_map : filter_linear, repeat_disable;
uniform vec2 style_z = vec2(0.0, 1.0);          // the style map's north end (world z) and length (m)
uniform float shade_k = 1.0;                    // how much of the baked shade shows (Medium and High have real shadows)
uniform vec2 map_from = vec2(0.0);
uniform vec2 map_size = vec2(64.0);
uniform vec4 arena = vec4(0.0);                 // the boss arena: centre x, z, radius, on
uniform vec4 well = vec4(0.0);                  // the Moonwell: centre x, z, radius, on
uniform vec3 stone_a : source_color = vec3(0.55, 0.57, 0.66);
uniform vec3 stone_b : source_color = vec3(0.50, 0.47, 0.58);
uniform vec3 stone_c : source_color = vec3(0.66, 0.68, 0.76);
uniform vec3 stone_d : source_color = vec3(0.43, 0.37, 0.53);  // the scattered darker flagstones
uniform vec3 brick : source_color = vec3(0.45, 0.41, 0.52);
uniform vec3 joint : source_color = vec3(0.16, 0.16, 0.22);
uniform vec3 earth : source_color = vec3(0.24, 0.21, 0.20);
uniform vec3 moss : source_color = vec3(0.27, 0.40, 0.25);
uniform vec3 grass : source_color = vec3(0.33, 0.48, 0.26);
uniform vec3 litter_a : source_color = vec3(0.17, 0.15, 0.15);
uniform vec3 litter_b : source_color = vec3(0.22, 0.18, 0.16);
uniform vec3 floor_moss : source_color = vec3(0.14, 0.21, 0.15);
uniform vec3 leaf_a : source_color = vec3(0.55, 0.35, 0.18);
uniform vec3 leaf_b : source_color = vec3(0.45, 0.22, 0.18);
uniform vec3 fern_col : source_color = vec3(0.17, 0.32, 0.18);
uniform vec3 puddle : source_color = vec3(0.04, 0.06, 0.12);
uniform vec3 moon : source_color = vec3(0.70, 0.80, 1.0);
uniform vec3 moonstone : source_color = vec3(0.70, 0.75, 0.86);
uniform vec3 rune : source_color = vec3(0.37, 0.91, 0.81);
uniform vec3 ember : source_color = vec3(1.0, 0.42, 0.12);       // the arena's cracks and glow
uniform vec3 mud : source_color = vec3(0.16, 0.15, 0.13);
uniform vec3 wash : source_color = vec3(1.0, 0.35, 0.82);       // the night's magenta wash, in big soft patches
uniform float wash_k = 0.0;
uniform float light_gain = 2.6;
uniform float dapple = 0.22;
varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
// flagstones: the distance to the nearest and second nearest cell centre (x, y), the nearest cell's id, and the
// vector from the point to that centre
vec2 voronoi(vec2 p, out vec2 id, out vec2 rel) {
	vec2 g = floor(p); vec2 f = fract(p);
	float d1 = 8.0; float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 c = o + 0.1 + 0.8 * hash2(g + o) - f;
			float d = mix(dot(c, c), max(c.x * c.x, c.y * c.y), 0.55);   // between round and square: cut flagstones
			if (d < d1) { d2 = d1; d1 = d; id = g + o; rel = c; } else if (d < d2) { d2 = d; }
		}
	}
	return vec2(sqrt(d1), sqrt(d2));
}
// slabs laid in rings round a centre: ring_w m wide, about arc_w m long. x: ring, y: slab in the ring, z: metres to
// the nearest joint
vec3 rings(vec2 q, float ring_w, float arc_w, float r0) {
	float d = length(q);
	float ri = floor((d - r0) / ring_w);
	float rf = fract((d - r0) / ring_w);
	float n = max(4.0, floor(6.2832 * (r0 + (ri + 0.5) * ring_w) / arc_w));
	float a = (atan(q.y, q.x) / 6.2832 + 0.5 + hash(vec2(ri, 3.1))) * n;
	float u = fract(a);
	float j = min(min(rf, 1.0 - rf) * ring_w, min(u, 1.0 - u) * 6.2832 * max(d, 0.3) / n);
	return vec3(ri, mod(floor(a), n), j);
}

void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 uv = (wp.xz - map_from) / map_size;
	vec4 gm = texture(ground_map, uv);
	vec4 lm = texture(light_map, uv);
	float sd = (0.5 - gm.r) * 4.0;                       // metres from the walkable edge (negative: on it)
	float n1 = noise(wp.xz * 0.45);
#ifdef LITE
	float n3 = n1;
	float rag = (n1 - 0.5) * 0.9;
#else
	float n3 = noise(wp.xz * 2.3);
	float rag = (n1 - 0.5) * 0.7 + (n3 - 0.5) * 0.45;
#endif
	vec3 emit = vec3(0.0);
	// ---- the forest floor: leaf litter and moss, darker away from the road
	float nm = noise(wp.xz * 0.21 + 3.1);
	vec3 c = mix(litter_a, litter_b, n1);
	c = mix(c, floor_moss, smoothstep(0.45, 0.75, nm) * 0.85);
	// mud by the water
	c = mix(c, mud, smoothstep(0.3, 0.7, gm.a) * step(0.2, sd));
	// ---- the verge: moss and grass spilling between the road and the litter
	float edge = sd + rag;
	float road = 1.0 - smoothstep(-0.5, 0.0, edge);
	float verge = 1.0 - smoothstep(0.0, 1.4, edge);
#ifdef LITE
	vec3 vc = mix(moss, grass, n1);
#else
	float blades = noise(wp.xz * vec2(9.0, 3.0)) * 0.6 + noise(wp.xz * vec2(3.0, 9.0)) * 0.4;
	vec3 vc = mix(moss, grass, smoothstep(0.35, 0.7, blades));
	vc *= 0.85 + 0.3 * n3;
#endif
	c = mix(c, vc, verge * 0.9);
	c *= mix(1.0, 0.5, lm.a * shade_k);
	// ---- fallen leaves: on the litter, the verge and now and then the road
	vec2 lc = wp.xz * 2.2;
	vec2 li = floor(lc);
	float lh = hash(li + 5.7);
	if (lh < 0.07 + 0.1 * (1.0 - road)) {
		float ang = hash(li + 1.3) * 6.2832;
		vec2 lf = fract(lc) - 0.5 - (hash2(li) - 0.5) * 0.4;
		vec2 r = vec2(lf.x * cos(ang) - lf.y * sin(ang), lf.x * sin(ang) + lf.y * cos(ang));
		float e = r.x * r.x / 0.06 + r.y * r.y / 0.012;
		float leaf = 1.0 - smoothstep(0.7, 1.0, e);
		c = mix(c, mix(leaf_a, leaf_b, hash(li + 2.2)) * (0.75 + 0.5 * hash(li + 8.8)), leaf * 0.9);
	}
	// ---- the road
	float wet = gm.a + (n1 - 0.5) * 0.3;
	if (gm.a > 0.2) {
		wet += (noise(wp.xz * 1.9 + 7.7) - 0.5) * 0.22;     // ragged puddle edges
	}
	vec4 sty = texture(style_map, vec2(0.5, (wp.z - style_z.x) / style_z.y));
	if (road > 0.002) {
		vec2 id;
		vec2 rel;
		float cob = step(0.5, sty.g + (n1 - 0.5) * 0.5);    // a cobbled stretch: smaller stones
		float vs = mix(1.2, 2.5, cob);
		vec2 v = voronoi(wp.xz * vs, id, rel);            // big flagstones (about 0.8 m), or cobbles
		float gap = (v.y - v.x) / vs;                     // metres to the joint
		float h = hash(id);
		vec3 st = mix(stone_a, stone_b, h);
		st = mix(st, stone_c, step(0.8, hash(id + 1.7)) * 0.7);
		st = mix(st, stone_d, step(0.86, hash(id + 9.3)));
#ifndef LITE
		st *= 0.9 + 0.2 * noise(wp.xz * 5.0 + h * 13.0);
		// a crack through some stones
		float ca = hash(id + 6.1) * 3.1416;
		float crack = abs(dot(rel, vec2(cos(ca), sin(ca))) + (noise(wp.xz * 7.0) - 0.5) * 0.12);
		st *= 1.0 - (1.0 - smoothstep(0.0, 0.03, crack)) * step(0.62, hash(id + 2.4)) * 0.55;
#endif
		// a bevel: the north-west rim catches the moon, the south-east one is in shade
		float rim = smoothstep(0.0, 0.11, gap);
		float lit = dot(normalize(rel + vec2(1e-4)), vec2(0.6, 0.8));
		st *= 0.86 + 0.14 * rim + (1.0 - rim) * lit * 0.12;
		// patches of small bricks between the flagstones (whole flagstones' places, so no brick is cut in half)
		vec2 cc = wp.xz + rel / vs;
		float bp = max(step(0.69, noise(cc * 0.17 + 11.0)) * (1.0 - cob), step(hash(id + 5.5), sty.r * 0.9));
		if (bp > 0.0) {
			vec2 bq = wp.xz * vec2(2.5, 4.4);
			bq.x += floor(bq.y) * 0.5;
			vec2 bi = floor(bq);
			vec2 bf = fract(bq);
			float bg = min(min(bf.x, 1.0 - bf.x) / 2.5, min(bf.y, 1.0 - bf.y) / 4.4);
			vec3 bc = mix(brick, stone_b, hash(bi)) * (0.85 + 0.25 * hash(bi + 0.7));
			st = mix(st, bc, bp);
			gap = mix(gap, bg, bp);
		}
		// loose and missing stones: earth, a little rubble and grass where they were (worn read at the stone's middle, so
		// a stone is there or not as a whole)
		float worn = texture(ground_map, (cc - map_from) / map_size).g + sty.b * 0.4;
		float miss = step(hash(id + 4.1), 0.04 + worn * 0.75);
		vec3 hole = mix(earth, moss, smoothstep(0.5, 0.8, n3) * 0.6);
		vec2 pc = wp.xz * 4.0;
		vec2 pf = fract(pc) - 0.5 - (hash2(floor(pc)) - 0.5) * 0.5;
		hole = mix(hole, st * 0.75, (1.0 - smoothstep(0.12, 0.2, length(pf))) * step(0.6, hash(floor(pc) + 0.4)));   // pebbles
		st = mix(st, hole, miss);
		// the joints: dark, mossy and grassy toward the edges and where it is damp
		float mossy = clamp(gm.b + sty.a * 0.6 + verge * 0.7 + 0.1, 0.0, 1.0);
		vec3 jc = mix(joint, moss * 0.85, mossy);
		float in_joint = (1.0 - smoothstep(0.025, 0.07, gap)) * (1.0 - miss);
		vec3 rc = mix(st, jc, in_joint);
		rc = mix(rc, moss, clamp(gm.b + sty.a * 0.55, 0.0, 1.0) * smoothstep(0.45, 0.75, noise(wp.xz * 1.3 + 4.0)) * 0.75);
		// wet stones are darker
		rc *= 1.0 - smoothstep(0.2, 0.5, wet) * 0.25;
		c = mix(c, rc, road);
	}
#ifndef LITE
	// ---- ferns lying flat at the edges and now and then on the road
	vec2 fc = wp.xz * 0.62;
	vec2 fi = floor(fc);
	if (hash(fi + 2.9) < 0.03 + verge * 0.22 * (1.0 - smoothstep(0.6, 1.6, sd))) {
		vec2 ff = fract(fc) - 0.5 - (hash2(fi + 9.1) - 0.5) * 0.3;
		float rr = length(ff) / 0.45;
		float ang = atan(ff.y, ff.x) + hash(fi) * 6.2832;
		float w = 0.9 * pow(max(1.0 - rr, 0.0), 0.7) * (0.82 + 0.18 * sin(rr * 30.0));
		float frond = (1.0 - smoothstep(w - 0.12, w, abs(sin(ang * 3.0)))) * step(rr, 1.0) * step(0.08, rr);
		float vein = 1.0 - smoothstep(0.0, 0.05, abs(sin(ang * 3.0)));
		c = mix(c, fern_col * (0.75 + 0.5 * rr) * (1.0 - vein * 0.3), frond * 0.9);
	}
#endif
	// ---- puddles: dark water with a cool moon in it and a bright rim
	float pud = smoothstep(0.52, 0.56, wet) * step(sd, 1.2);
	if (pud > 0.0) {
		// the sky in it: long soft streaks of moonlight (up and down the screen, as reflections run), the lanterns' light
#ifdef LITE
		float sky = noise(wp.xz * vec2(2.2, 0.45) + 5.0);
#else
		float sky = noise(wp.xz * vec2(2.2, 0.45) + vec2(5.0, TIME * 0.12));
#endif
		c = mix(c, puddle, pud);
		float streak = smoothstep(0.5, 0.9, sky);
		emit += (moon * (0.1 + 0.32 * streak) + lm.rgb * 0.5) * pud;          // the moonlit sky in the water
		float glint = smoothstep(0.51, 0.53, wet) - smoothstep(0.53, 0.57, wet);
		emit += moon * glint * 0.55;                                          // a bright rim where it meets the stones
	}
	// ---- the arena: big pale flagstones, a disc of fitted rings round a carved sigil (the boss fights on it), thin ember
	// cracks between some stones, a kerb of dark rocks, a warm glow on the ground beyond the rim
	if (arena.w > 0.5) {
		vec2 q = wp.xz - arena.xy;
		float d = length(q);
		float rr = arena.z;
		if (d < rr + 4.5) {
			float inside = 1.0 - smoothstep(rr + 0.1, rr + 0.7, d + rag * 0.4);
			float jd;
			float sh;
			if (d < 1.7) {
				jd = 1.7 - d;
				sh = 0.55;
			} else if (d < 4.7) {
				vec3 sl = rings(q, 1.0, 1.15, 1.7);
				jd = min(sl.z, 4.7 - d);
				sh = hash(sl.xy + 0.3);
			} else {
				vec2 aid;
				vec2 arel;
				vec2 av = voronoi(q * 0.72 + 31.0, aid, arel);
				jd = min((av.y - av.x) / 0.72, d - 4.7);
				sh = hash(aid);
			}
			vec3 sc = mix(stone_a, stone_c, 0.35 + 0.45 * sh) * (0.9 + 0.16 * fract(sh * 7.3));
			if (d < 1.7) {
				// the sigil: two rings, a six-petalled flower and spokes cut into the centre slab, an ember at its heart
				float a = atan(q.y, q.x);
				float cut = 1.0 - smoothstep(0.03, 0.06, abs(d - 1.48));
				cut = max(cut, 1.0 - smoothstep(0.03, 0.06, abs(d - 0.95)));
				cut = max(cut, (1.0 - smoothstep(0.03, 0.07, abs(d - (0.3 + 0.55 * abs(cos(a * 3.0)))))) * step(d, 0.95));
				cut = max(cut, (1.0 - smoothstep(0.02, 0.05, abs(sin(a * 6.0)) * d)) * step(0.95, d) * step(d, 1.48));
				cut = max(cut, 1.0 - smoothstep(0.12, 0.16, d));
				sc = mix(sc, joint, cut * 0.85);
				emit += ember * (1.0 - smoothstep(0.0, 0.18, d)) * 0.8;
			}
			float in_j = 1.0 - smoothstep(0.03, 0.075, jd);
#ifdef LITE
			float pulse = 1.0;
#else
			float pulse = 0.75 + 0.25 * sin(TIME * 1.7 + sh * 20.0);
#endif
			float hot = step(0.9, fract(sh * 13.7)) * in_j * step(1.6, d);
			sc = mix(sc, joint, in_j * (1.0 - hot));
			sc = mix(sc, ember * 0.55, hot);
			float kerb = smoothstep(rr - 0.75, rr - 0.6, d) * (1.0 - smoothstep(rr + 0.05, rr + 0.2, d));
			sc = mix(sc, joint * 1.5, kerb);
			c = mix(c, sc, inside);
			emit += ember * hot * inside * 0.9 * pulse;
			float beyond = smoothstep(rr + 0.2, rr + 1.0, d) * (1.0 - smoothstep(rr + 1.5, rr + 4.5, d)) * smoothstep(0.2, 1.0, sd)
				* smoothstep(0.35, -0.1, q.y / max(d, 0.01));        // north and the sides only (the gate is south)
			emit += ember * beyond * (0.1 + 0.2 * n1);
		}
	}
	// ---- the Moonwell: pale moonstone rings round the spring, softly lit by the moon
	if (well.w > 0.5) {
		vec2 q = wp.xz - well.xy;
		float d = length(q);
		float rr = well.z * 0.72;
		if (d < rr + 0.6) {
			vec3 sl = rings(q, 0.95, 1.0, 0.0);
			vec3 sc = moonstone * (0.86 + 0.22 * hash(sl.xy + 1.9));
			sc = mix(sc, moss, step(0.9, hash(sl.xy + 4.4)) * 0.5);
			sc = mix(sc, mix(joint, moss, 0.5), 1.0 - smoothstep(0.03, 0.07, sl.z));
			float inside = 1.0 - smoothstep(rr - 0.2, rr + 0.5, d + rag * 0.5);
			c = mix(c, sc, inside);
			emit += moon * sc * inside * 0.08 * (1.0 - smoothstep(0.0, rr, d) * 0.6);
		}
	}
	// ---- soft moonlight dapples through the canopy, mostly on the road, and the night's magenta wash in big patches
#ifdef LITE
	float dap = smoothstep(0.55, 0.85, noise(wp.xz * 0.23));
#else
	float dap = smoothstep(0.55, 0.85, noise(wp.xz * 0.23 + vec2(TIME * 0.02, TIME * 0.013)));
#endif
	emit += c * moon * dap * dapple * (0.35 + 0.65 * road);
	float wz = smoothstep(0.3, 0.85, noise(wp.xz * 0.07 + 21.0));
	emit += c * wash * wz * wash_k;
	// ---- light baked in: warm pools at the lanterns and torches, teal at the glow caps, violet at the crystals
	emit += c * lm.rgb * light_gain + lm.rgb * 0.07;
	ALBEDO = c;
	EMISSION = emit;
	ROUGHNESS = 1.0;
}
