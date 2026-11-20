shader_type spatial;
// The same LEAF look for MultiMesh scatter (trees, bushes, rocks): INSTANCE_CUSTOM.r is the Gloom amount, and plants
// sway in the wind, their tops more than their trunks. The Burrows' night woods (Phase E dungeons): INSTANCE_CUSTOM.b
// darkens and cools them, INSTANCE_CUSTOM.a makes their bright saturated faces shine (lantern glass, glow caps), and
// at night INSTANCE_CUSTOM.g is the lanterns' warm light on them (the camp's coral canopies need no night).
render_mode specular_disabled;

uniform vec3 gloom_color : source_color = vec3(0.36, 0.25, 0.58);
uniform vec3 rim_color : source_color = vec3(1.0, 0.93, 0.78);
uniform float sway = 0.04;
uniform float wrap = 0.45;
varying float g;
varying float coral;
varying float world_y;
varying float night;
varying float shine;

void vertex() {
	g = INSTANCE_CUSTOM.r;
	coral = INSTANCE_CUSTOM.g;
	night = INSTANCE_CUSTOM.b;
	shine = INSTANCE_CUSTOM.a;
	vec3 root = MODEL_MATRIX[3].xyz;
	float h = max(VERTEX.y, 0.0);
	float gust = 0.6 + 0.4 * sin(TIME * 0.6 + root.x * 0.08);
	VERTEX.x += sin(TIME * 0.9 + root.x * 0.31 + root.z * 0.17) * sway * h * h * 0.15 * gust;
	VERTEX.z += cos(TIME * 0.7 + root.z * 0.29) * sway * h * h * 0.10 * gust;
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec3 c = COLOR.rgb;
	// coral-pink canopies: leaf-green faces turn coral, keeping their light and shade (by day only: at night .g is warmth)
	float warm = night > 0.0 ? coral : 0.0;
	float cor = night > 0.0 ? 0.0 : coral;
	float leafy = step(c.r * 1.12, c.g) * step(c.b, c.g);
	float lum = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(c, vec3(1.0, 0.36, 0.34) * lum * 2.1, cor * leafy);
	c = mix(c, c * 0.40 + gloom_color * 0.32, g);
	c *= mix(0.72, 1.0, smoothstep(0.0, 0.35, world_y));
	vec3 lit = COLOR.rgb;
	// the night: darker and a little cooler (the foliage stays a deep green), warm where a lantern is near
	vec3 cool = vec3(dot(c, vec3(0.3, 0.55, 0.15))) * vec3(0.62, 1.0, 0.9);
	c = mix(c, cool, night * 0.4) * mix(1.0, 0.6, night);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	float v = clamp((min(c.r, c.b) - c.g) * 3.0 - 0.3, 0.0, 1.0);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * v * 1.6 + rim_color * rim * 0.18 * (0.4 + c) * (1.0 - g * 0.7) * (1.0 - night * 0.6);
	EMISSION += c * vec3(1.0, 0.5, 0.18) * warm * 1.6;
	if (shine > 0.0) {
		float mx = max(lit.r, max(lit.g, lit.b));
		float sat = (mx - min(lit.r, min(lit.g, lit.b))) / max(mx, 1e-4);
		EMISSION += lit * shine * smoothstep(0.5, 0.74, mx) * smoothstep(0.42, 0.62, sat);
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float w = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	float toon = smoothstep(0.14, 0.5, w);
	DIFFUSE_LIGHT += mix(w, toon, 0.55) * ATTENUATION * LIGHT_COLOR / PI;
}
