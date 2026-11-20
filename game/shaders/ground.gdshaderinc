// The ground shader body, shared by ground.gdshader and ground_lite.gdshader (LITE: Low graphics).
// The ground. Grass in soft darker and lighter patches; roads painted from the path map (path_tex, 0 = grass,
// 1 = middle of a road): packed earth with big flat cobblestones, scattered stones toward the ragged grassy edge,
// a darker rim where the grass meets the road; warm firelight round the camp; the woods under the Gloom darker and
// violet; slow cloud shadows.
render_mode specular_disabled;

uniform vec3 grass_a : source_color = vec3(0.34, 0.60, 0.20);
uniform vec3 grass_b : source_color = vec3(0.24, 0.47, 0.15);
uniform vec3 grass_c : source_color = vec3(0.42, 0.66, 0.24);
uniform vec3 camp_grass : source_color = vec3(0.47, 0.72, 0.29);
uniform vec3 dirt : source_color = vec3(0.58, 0.43, 0.29);
uniform vec3 dirt_dark : source_color = vec3(0.46, 0.33, 0.22);
uniform vec3 stone_a : source_color = vec3(0.66, 0.60, 0.52);
uniform vec3 stone_b : source_color = vec3(0.55, 0.50, 0.45);
uniform vec3 gloom_color : source_color = vec3(0.22, 0.17, 0.33);
uniform sampler2D path_tex : filter_linear, repeat_disable;
uniform float map_size = 64.0;
uniform float camp_radius = 4.0;
uniform float woods_radius = 21.0;
uniform vec4 gloom_patch = vec4(1.0);
uniform vec4 patch_angle = vec4(0.38, -0.38, 1.08, -1.08);
uniform float patch_half = 0.36;
uniform vec2 lake_center = vec2(0.0, 0.0);
uniform float lake_r = 0.0;
uniform vec3 sand : source_color = vec3(0.80, 0.72, 0.55);
uniform vec3 wet : source_color = vec3(0.20, 0.42, 0.18);
varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
// distance to the nearest and second nearest cell centre, and the nearest cell's id
vec3 voronoi(vec2 p, out vec2 id) {
	vec2 g = floor(p); vec2 f = fract(p);
	float d1 = 8.0; float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 c = o + 0.15 + 0.7 * hash2(g + o) - f;
			float d = dot(c, c);
			if (d < d1) { d2 = d1; d1 = d; id = g + o; } else if (d < d2) { d2 = d; }
		}
	}
	return vec3(sqrt(d1), sqrt(d2), 0.0);
}

void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
#ifdef LITE
	float n = noise(wp.xz * 0.35);
#else
	float n = noise(wp.xz * 0.35) * 0.65 + noise(wp.xz * 1.3) * 0.35;
#endif
	float n2 = noise(wp.xz * 0.12 + 7.0);
	vec3 c = mix(grass_a, grass_b, smoothstep(0.35, 0.7, n));
	c = mix(c, grass_c, smoothstep(0.55, 0.85, n2) * 0.6);
	float r = length(wp.xz);
	float lit = 1.0 - smoothstep(camp_radius - 1.6, camp_radius + 0.5, r + (n - 0.5) * 1.2);
	c = mix(c, camp_grass * vec3(1.08, 1.0, 0.82), lit * 0.5);
	// roads
	vec2 puv = wp.xz / map_size + 0.5;
	float ps = texture(path_tex, puv).r;
#ifdef LITE
	float ragged = (noise(wp.xz * 2.2) - 0.5) * 0.4;
#else
	float ragged = (noise(wp.xz * 2.2) - 0.5) * 0.32 + (noise(wp.xz * 7.0) - 0.5) * 0.14;
#endif
	float road = smoothstep(0.16, 0.24, ps + ragged);
	float rim = smoothstep(0.06, 0.16, ps + ragged) * (1.0 - road);
	vec3 earth = mix(dirt, dirt_dark, noise(wp.xz * 3.1) * 0.7);
#ifdef LITE
	vec3 road_col = earth;
#else
	vec2 id;
	vec3 v = voronoi(wp.xz * 2.1, id);
	float gap = v.y - v.x;
	float stone_here = step(0.22 + (1.0 - ps) * 0.75, hash(id + 3.7));      // packed in the middle, scattered at the edges
	float stone = smoothstep(0.05, 0.13, gap) * stone_here;
	vec3 st = mix(stone_a, stone_b, hash(id)) * (0.92 + 0.16 * noise(wp.xz * 9.0));
	st *= 1.0 - smoothstep(0.35, 0.0, v.x) * 0.0 + smoothstep(0.0, 0.25, v.x) * -0.08;
	vec3 road_col = mix(earth, st, stone);
#endif
	c = mix(c, c * 0.72, rim);
	c = mix(c, road_col, road);
	// the lake's shore: sand and pebbles at the water, then a ring of darker, damp grass (same outline as lake.gd)
	if (lake_r > 0.0) {
		vec2 ld = wp.xz - lake_center;
		float th = atan(ld.y, ld.x);
		float shore = lake_r * (1.0 + 0.16 * sin(2.0 * th + 1.3) + 0.10 * sin(3.0 * th + 0.4) + 0.06 * sin(5.0 * th + 2.1));
#ifdef LITE
		float dl = length(ld) - shore;
		vec3 sand_col = sand;
#else
		float dl = length(ld) - shore + (noise(wp.xz * 3.0) - 0.5) * 0.25;
		vec2 lid;
		vec3 lv = voronoi(wp.xz * 4.5, lid);
		vec3 sand_col = mix(sand, sand * 0.85, noise(wp.xz * 6.0));
		sand_col = mix(sand_col, mix(stone_a, stone_b, hash(lid)), smoothstep(0.04, 0.1, lv.y - lv.x) * step(0.55, hash(lid + 1.3)));
#endif
		c = mix(c, mix(c, wet, 0.6), 1.0 - smoothstep(0.5, 1.5, dl));
		c = mix(c, sand_col, 1.0 - smoothstep(0.35, 0.6, dl));
		c = mix(c, vec3(0.08, 0.22, 0.30), 1.0 - smoothstep(-0.2, 0.0, dl));
	}
	// the dirt round the campfire
	c = mix(c, earth, 1.0 - smoothstep(0.9, 1.5 + n * 0.3, r));
	// the Gloom over the woods, per patch
	float ang = atan(wp.x, -wp.z);
	float g = 0.0;
	for (int i = 0; i < 4; i++) {
		float d = abs(ang - patch_angle[i]);
		float inside = 1.0 - smoothstep(patch_half, patch_half + 0.12, d);
		g = max(g, inside * gloom_patch[i]);
	}
	float woods = smoothstep(woods_radius - 3.0, woods_radius + 1.0, r);
	c = mix(c, c * 0.6, woods * 0.4);
	c = mix(c, gloom_color, g * woods * 0.75);
#ifndef LITE
	// slow cloud shadows drifting over the meadow
	vec2 cp = wp.xz * 0.045 + vec2(TIME * 0.012, TIME * 0.007);
	float cloud = smoothstep(0.45, 0.75, noise(cp) * 0.7 + noise(cp * 2.1) * 0.3);
	c *= 1.0 - cloud * 0.18;
#endif
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
