shader_type spatial;
// The Burrows' night lights that need no light (they look the same on Low): soft additive discs drawn from a MultiMesh.
//   billboard = 1: a halo facing the camera (lanterns, glow caps, crystals) at the instance's place and scale
//   billboard = 0: a pool of light lying on the ground (the instance's own transform, a PlaneMesh)
//   drift > 0:     fireflies: each wanders round its spot and blinks (INSTANCE_ID), all in the vertex shader
// The colour is the MultiMesh's instance colour; its alpha is the strength.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float billboard = 1.0;
uniform float drift = 0.0;
uniform float energy = 1.0;
varying float blink;

void vertex() {
	blink = 1.0;
	vec3 pos = MODEL_MATRIX[3].xyz;
	if (drift > 0.0) {
		float id = float(INSTANCE_ID);
		pos += vec3(sin(TIME * 0.53 + id * 1.37), 0.45 * sin(TIME * 0.91 + id * 0.73), cos(TIME * 0.47 + id * 2.11)) * drift;
		blink = 0.25 + 0.75 * smoothstep(-0.2, 0.9, sin(TIME * (1.1 + fract(id * 0.37)) + id * 2.3));
	}
	if (billboard > 0.5) {
		float sc = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sc, INV_VIEW_MATRIX[1] * sc, INV_VIEW_MATRIX[2] * sc, vec4(pos, 1.0));
	}
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float a = clamp(1.0 - dot(d, d), 0.0, 1.0);
	ALBEDO = COLOR.rgb * COLOR.a * energy * a * a * blink;
}
