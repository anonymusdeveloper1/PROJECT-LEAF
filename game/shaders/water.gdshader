shader_type spatial;
// The lake by the tree home: turquoise in the shallows, deep blue in the middle, ripples drifting across, sun glints,
// and a soft foam line breathing at the shore. UV.x = 0 at the shore, 1 in the middle.
render_mode specular_schlick_ggx, cull_disabled;

uniform vec3 shallow : source_color = vec3(0.26, 0.66, 0.70);
uniform vec3 deep : source_color = vec3(0.05, 0.26, 0.44);
uniform vec3 foam : source_color = vec3(0.88, 0.97, 0.95);
uniform vec3 glint : source_color = vec3(1.0, 0.97, 0.85);
varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 1.2 + wp.x * 1.7 + wp.z * 1.3) * 0.008 * UV.x;
}

void fragment() {
	float d = UV.x;
	vec3 c = mix(shallow, deep, smoothstep(0.05, 0.75, d));
	// smooth ripples drifting across the surface (crossed sine waves, warped so they never look like a grid)
	vec2 p = wp.xz;
	float w1 = sin(p.x * 2.1 + TIME * 0.9 + sin(p.y * 1.3 + TIME * 0.5) * 1.4);
	float w2 = sin(p.y * 2.6 - TIME * 0.7 + sin(p.x * 1.7 - TIME * 0.4) * 1.2);
	float w3 = sin((p.x + p.y) * 3.3 + TIME * 1.3);
	float rip = 0.5 + 0.22 * w1 + 0.22 * w2 + 0.06 * w3;
	c += vec3(0.05, 0.09, 0.09) * smoothstep(0.62, 0.86, rip);
	c -= vec3(0.02, 0.03, 0.03) * smoothstep(0.38, 0.18, rip);
	// small round glints that twinkle
	vec2 g = p * 6.0;
	vec2 cell = floor(g);
	vec2 cp = fract(g) - 0.5 - (vec2(hash(cell), hash(cell + 7.1)) - 0.5) * 0.5;
	float dot_shape = 1.0 - smoothstep(0.03, 0.09, length(cp));
	float sparkle = dot_shape * step(0.965, hash(cell + floor(TIME * 2.2))) * smoothstep(0.55, 0.75, rip) * smoothstep(0.1, 0.4, d);
	float r1 = 0.5 + 0.5 * w1;
	float r2 = 0.5 + 0.5 * w2;
	// the foam line at the shore, breathing
	float edge = 0.07 + 0.03 * sin(TIME * 1.4 + atan(wp.x, wp.z) * 6.0);
	float f = 1.0 - smoothstep(edge * 0.5, edge, d);
	c = mix(c, foam, f * 0.85);
	ALBEDO = c;
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	METALLIC = 0.0;
	EMISSION = glint * sparkle * 1.6;
	vec3 n_world = normalize(vec3((r1 - 0.5) * 0.5, 1.0, (r2 - 0.5) * 0.5));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
}
