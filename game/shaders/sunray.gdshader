shader_type spatial;
// A soft ray of sunlight slanting through the trees: brightest at the top, fading to nothing, breathing slowly.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

instance uniform float phase = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.93, 0.7, 1.0);
uniform float strength = 0.16;

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	across = smoothstep(0.0, 0.8, across);
	float down = smoothstep(1.0, 0.15, UV.y) * smoothstep(0.0, 0.12, UV.y);
	float breathe = 0.65 + 0.35 * sin(TIME * 0.4 + phase);
	ALBEDO = color.rgb * across * down * strength * breathe;
}
