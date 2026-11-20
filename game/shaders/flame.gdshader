shader_type spatial;
// The campfire's flame: glowing, licking upward, never still. Uses the flame mesh's own colours.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float height = 0.6;                     // the flame's height (m): set per campfire, so big flames sway too
uniform float sway = 1.0;                       // how far it sways (the bigger fires of home levels 4-6 sway more)
uniform float glow = 2.6;
uniform vec3 tint = vec3(1.0);                  // Shardfire (Phase D): the flame's brightness in this colour; 1,1,1 keeps its own

void vertex() {
	float h = clamp(VERTEX.y / height, 0.0, 1.0);
	float t = TIME;
	VERTEX.x += (sin(t * 9.0 + VERTEX.y * 7.0) * 0.045 + sin(t * 23.0 + VERTEX.z * 11.0) * 0.012) * h * sway;
	VERTEX.z += cos(t * 7.5 + VERTEX.y * 6.0) * 0.04 * h * sway;
	VERTEX.y *= 1.0 + 0.16 * sin(t * 11.0) * h + 0.08 * sin(t * 27.0) * h;
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (dot(c, vec3(0.333)) > 0.95) { c = vec3(1.0, 0.62, 0.15); }     // placeholder white: make it fire
	if (distance(tint, vec3(1.0)) > 0.01) { c = vec3(dot(c, vec3(0.3, 0.55, 0.15))) * tint * tint * 0.7; }
	float flick = 0.85 + 0.15 * sin(TIME * 17.0) * sin(TIME * 5.3);
	ALBEDO = c * glow * flick;
}
