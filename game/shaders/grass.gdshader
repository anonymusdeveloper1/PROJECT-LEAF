shader_type spatial;
// Meadow grass, tall hiding grass and flowers, drawn as MultiMesh chunks. Each blade sways in the wind, rolling gusts
// sweep across the field, and blades bend away from whoever walks through: pushers[i] = (x, strength, z, radius) in
// world space, set every frame. Blades turn about their roots (they never stretch) and spring back smoothly. Flowers (flower = true) use the instance colour for their heads (vertex alpha 1).
render_mode cull_disabled, specular_disabled;

uniform vec4 pushers[24];
uniform int pusher_count = 0;
uniform vec3 base_color : source_color = vec3(0.10, 0.27, 0.07);
uniform vec3 mid_color : source_color = vec3(0.27, 0.53, 0.15);
uniform vec3 tip_color : source_color = vec3(0.66, 0.84, 0.30);
uniform float blade_height = 0.5;
uniform float wind = 0.09;                       // radians
uniform float gust = 0.16;                       // radians
uniform vec2 wind_dir = vec2(0.8, -0.6);
uniform float bend = 1.15;                       // radians of lean at full push
uniform bool flower = false;
varying float h;
varying float shade;
varying vec3 root_w;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	h = clamp(VERTEX.y / blade_height, 0.0, 1.0);
	vec3 root = MODEL_MATRIX[3].xyz;
	root_w = root;
	float y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - root.y;      // this vertex's height above the clump's root
	// how far the blades lean, as an angle (radians) in a direction: wind sway, rolling gusts, walkers pushing
	vec2 tilt = vec2(sin(TIME * 1.9 + root.x * 0.8 + root.z * 0.5), cos(TIME * 1.5 + root.z * 0.7 + root.x * 0.2)) * wind;
	float wave = sin(dot(root.xz, normalize(wind_dir)) * 0.32 - TIME * 1.7);
	wave = smoothstep(0.2, 1.0, wave);
	tilt += normalize(wind_dir) * wave * gust;
	for (int i = 0; i < 24; i++) {
		if (i >= pusher_count) { break; }
		vec4 p = pushers[i];                     // x, strength, z, radius; strength < 0 = springing back past upright
		vec2 d = root.xz - p.xz;
		float dist = length(d);
		float f = 1.0 - clamp(dist / p.w, 0.0, 1.0);
		f = f * f * (3.0 - 2.0 * f);             // soft falloff: blades ease in and out of the push
		tilt += (d / max(dist, 0.001)) * f * p.y * bend;
	}
	float a = length(tilt);
	vec2 dir = a > 0.0001 ? tilt / a : vec2(0.0);
	a = min(a, 1.35);                            // never flatter than about 77 degrees
	// turn the blade about its root instead of sliding it: the angle grows toward the tip so the blade curves, and
	// every point keeps its distance from the root, so nothing stretches
	float ah = a * (0.35 + 0.65 * h);
	vec3 world_off = vec3(dir.x * y * sin(ah), -y * (1.0 - cos(ah)), dir.y * y * sin(ah));
	float s2 = dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz);
	VERTEX += (transpose(mat3(MODEL_MATRIX)) * world_off) / s2;
	shade = 0.85 + 0.15 * wave;
}

void fragment() {
	vec3 c = h < 0.5 ? mix(base_color, mid_color, h * 2.0) : mix(mid_color, tip_color, (h - 0.5) * 2.0);
	// darker and lighter clumps across the meadow
	float patchy = noise(root_w.xz * 0.35) * 0.6 + noise(root_w.xz * 1.1) * 0.4;
	c *= mix(0.82, 1.12, patchy);
	if (flower) {
		c = mix(c * 0.9, COLOR.rgb * 1.15, COLOR.a);
		ALBEDO = c * shade;
	} else {
		ALBEDO = c * COLOR.rgb * shade;
	}
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.35, 0.45, 0.2) * h;
}

void light() {
	float ndl = abs(dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += (0.45 + 0.55 * ndl) * ATTENUATION * LIGHT_COLOR / PI;
}
