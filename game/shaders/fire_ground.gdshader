shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float clock = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float heat : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float grain = noise(p * 6.0);
	float r = length(p) + (grain - 0.5) * 0.16;
	float edge = 1.0 - smoothstep(0.65, 0.99, r);
	float flow = noise(p * 8.0 + vec2(clock * 0.9, -clock * 1.3));
	float embers = smoothstep(0.48, 0.82, flow) * (0.65 + 0.35 * sin(clock * 11.0 + grain * 18.0));
	vec3 scorch = vec3(0.12, 0.055, 0.022);
	vec3 glow = mix(vec3(1.0, 0.09, 0.006), vec3(1.0, 0.6, 0.06), embers);
	ALBEDO = mix(scorch, glow, embers * heat * 0.75);
	EMISSION = glow * embers * heat * 1.35;
	ALPHA = edge * opacity * 0.78;
}
