shader_type spatial;
// Violet Gloom mist lying over the woods of an unclaimed patch. amount 1 = thick, 0 = gone.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.55, 0.32, 0.85, 1.0);
uniform float amount = 1.0;
varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wp.xz * 0.22 + vec2(TIME * 0.05, TIME * 0.03);
	float n = noise(p) * 0.6 + noise(p * 2.3 - TIME * 0.04) * 0.4;
	vec2 e = UV * 2.0 - 1.0;
	float edge = 1.0 - smoothstep(0.55, 1.0, max(abs(e.x), abs(e.y)));
	ALBEDO = color.rgb;
	ALPHA = clamp(n * 1.3 - 0.25, 0.0, 1.0) * edge * amount * 0.55;
}
