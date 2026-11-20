shader_type spatial;
// A soft rim glow over a thing the cat can use, while it is within reach (marker.gd sets it as the thing's own
// meshes' overlay, so nothing else lights up). Additive: the edges turned away from the camera glow most, and the
// whole thing lifts a little. The faces are flat (low poly), so the glow is faceted too.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.86, 0.45, 1.0);
uniform float strength = 0.7;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.0);
	ALBEDO = color.rgb * (rim * 0.95 + 0.16) * strength;
}
