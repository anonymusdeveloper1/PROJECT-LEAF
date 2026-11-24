shader_type spatial;
render_mode specular_disabled;
uniform float half_width = 0.42;
uniform float relax_m = 0.175;
uniform float draw : hint_range(0.0, 1.0) = 1.0;
instance uniform float gloom = 0.0;
instance uniform float flash = 0.0;
void vertex() {
	float middle = 1.0 - clamp(abs(VERTEX.x) / half_width, 0.0, 1.0);
	VERTEX.z += relax_m * (1.0 - draw) * middle;
}
void fragment() { ALBEDO = mix(COLOR.rgb * (1.0 - gloom * 0.75), vec3(1.0), flash); ROUGHNESS = 1.0; }
