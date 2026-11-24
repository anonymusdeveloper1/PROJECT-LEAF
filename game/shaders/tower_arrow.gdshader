shader_type spatial;
render_mode specular_disabled;
uniform float arrow_length = 0.48;
uniform vec4 tip_color : source_color = vec4(1.0);
uniform vec4 fletch_color : source_color = vec4(1.0);
uniform float glow = 0.0;
instance uniform float gloom = 0.0;
instance uniform float flash = 0.0;
varying float along;
void vertex() { along = VERTEX.z / arrow_length; }
void fragment() {
	float tip = step(0.75, along);
	float feathers = 1.0 - step(0.2, along);
	float shade = 0.8 + dot(COLOR.rgb, vec3(0.333)) * 0.3;
	vec3 color = mix(COLOR.rgb, fletch_color.rgb * shade, feathers);
	color = mix(color, tip_color.rgb * shade, tip);
	ALBEDO = mix(color * (1.0 - gloom * 0.75), vec3(1.0), flash);
	ROUGHNESS = 0.9;
	EMISSION = color * glow * max(tip, feathers);
}
