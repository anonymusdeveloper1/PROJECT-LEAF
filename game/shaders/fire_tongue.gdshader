shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Camera-facing, animated flame silhouettes. A supplied clock lets ground fire pause with gameplay.
uniform float clock = -1.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform bool orb = false;
uniform vec3 flight_direction = vec3(0.0);
varying float phase;

void vertex() {
	phase = float(INSTANCE_ID) * 2.17 + MODEL_MATRIX[3].x * 0.31;
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX[0] *= size.x;
	MODELVIEW_MATRIX[1] *= size.y;
	MODELVIEW_MATRIX[2] *= size.z;
	if (length(flight_direction) > 0.1) {
		vec2 along = (VIEW_MATRIX * vec4(-flight_direction, 0.0)).xy;
		along = normalize(along + vec2(0.0001));
		VERTEX.xy = mat2(vec2(along.y, -along.x), along) * VERTEX.xy;
	}
}

void fragment() {
	float t = (clock < 0.0 ? TIME : clock) + phase;
	if (orb) {
		vec2 p = UV * 2.0 - 1.0;
		float angle = atan(p.y, p.x);
		float rim = 0.82 + sin(angle * 7.0 + t * 14.0) * 0.055 + sin(angle * 11.0 - t * 9.0) * 0.035;
		float r = length(p);
		float hot = 1.0 - smoothstep(0.15, rim, r);
		vec3 fire = mix(vec3(1.0, 0.15, 0.008), vec3(1.0, 0.92, 0.42), hot);
		ALBEDO = fire;
		EMISSION = fire * 1.5;
		ALPHA = (1.0 - smoothstep(rim - 0.04, rim + 0.04, r)) * opacity;
	} else {
	float h = 1.0 - UV.y;
	float x = UV.x - 0.5;
	float bend = sin(h * 7.0 - t * 10.0) * h * 0.085 + sin(h * 15.0 - t * 16.0) * h * 0.025;
	float width = (0.38 * pow(max(1.0 - h, 0.0), 0.72) + 0.012) * (0.9 + 0.12 * sin(t * 12.0 + h * 11.0));
	float edge = width - abs(x + bend);
	float shape = smoothstep(-0.025, 0.025, edge) * smoothstep(0.0, 0.07, h) * (1.0 - smoothstep(0.84, 1.0, h));
	float hot = clamp(edge / max(width, 0.01), 0.0, 1.0) * (1.0 - h * 0.6);
	vec3 fire = mix(vec3(1.0, 0.075, 0.005), vec3(1.0, 0.48, 0.025), smoothstep(0.05, 0.45, hot));
	fire = mix(fire, vec3(1.0, 0.93, 0.48), smoothstep(0.45, 0.85, hot));
	ALBEDO = fire;
	EMISSION = fire * 1.4;
	ALPHA = shape * COLOR.a * opacity;
	}
	if (ALPHA < 0.015) { discard; }
}
