shader_type spatial;
// Every LEAF asset: one flat colour per face (vertex colour), lit the LEAF way:
//   soft wrap-around light with a gentle cartoon step, warm sun, cool rim light, a little contact shade near the
//   ground, saturated violet faces (eyes, crystals) glowing.
// The game tints per object: flash = white hit flash, gloom = how deep in the violet Gloom, tint = placeholder colour.
// A skin (mounts and pets) recolours one colour family, the fur or the scales: faces whose hue is within
// skin_from.y of skin_from.x (and that are not grey) get hue skin.x (or keep theirs if skin.x < 0), saturation times
// skin.y and value times skin.z; skin.w is how much (0 = off). Every face keeps its own light and shade.
render_mode specular_disabled;

instance uniform float flash = 0.0;
instance uniform float gloom = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform vec4 skin = vec4(0.0);
instance uniform vec4 skin_from = vec4(0.0);
instance uniform float glow = 0.0;            // the Burrows' night: its bright saturated faces (lantern glass, glow caps) shine

uniform vec3 gloom_color : source_color = vec3(0.36, 0.25, 0.58);
uniform vec3 rim_color : source_color = vec3(1.0, 0.93, 0.78);
uniform float rim_strength = 0.22;
uniform float violet_glow = 1.6;
uniform float wrap = 0.45;
uniform float step_soft = 0.18;
varying float world_y;

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec3 c = COLOR.rgb * tint.rgb;
	if (skin.w > 0.0) {
		vec3 h = rgb2hsv(c);
		float d = abs(fract(h.x - skin_from.x + 0.5) - 0.5);           // how far its hue is from the family's
		float m = (1.0 - smoothstep(skin_from.y * 0.75, skin_from.y, d)) * smoothstep(0.7, 0.82, h.y) * skin.w;   // not creams (linear colour: cream ~0.6, fur ~0.9)
		vec3 n = vec3(skin.x < 0.0 ? h.x : skin.x, clamp(h.y * skin.y, 0.0, 1.0), clamp(h.z * skin.z, 0.0, 1.0));
		c = mix(c, hsv2rgb(n), m);
	}
	float v = clamp((min(c.r, c.b) - c.g) * 3.0 - 0.3, 0.0, 1.0);
	c = mix(c, c * 0.42 + gloom_color * 0.30, gloom);
	c *= mix(0.72, 1.0, smoothstep(0.0, 0.35, world_y));          // contact shade at the base
	ALBEDO = mix(c, vec3(1.0), flash);
	ROUGHNESS = 1.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * v * violet_glow + vec3(flash * 0.5) + rim_color * rim * rim_strength * (0.4 + c);
	if (glow > 0.0) {
		float mx = max(c.r, max(c.g, c.b));
		float sat = (mx - min(c.r, min(c.g, c.b))) / max(mx, 1e-4);
		EMISSION += c * glow * smoothstep(0.5, 0.74, mx) * smoothstep(0.42, 0.62, sat);
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float w = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	float toon = smoothstep(0.32 - step_soft, 0.32 + step_soft, w);    // a soft cartoon step between lit and shade
	float lit = mix(w, toon, 0.55);
	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR / PI;
}
