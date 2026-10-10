shader_type canvas_item;
uniform float storm_clock = 0.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec2 uv = UV;
	float water_mask = smoothstep(0.30, 0.42, uv.y) * (1.0 - smoothstep(0.62, 0.78, uv.y));
	uv.x += sin(uv.y * 115.0 + storm_clock * 2.5) * 0.0012 * water_mask;
	uv.y += sin(uv.x * 32.0 + storm_clock * 1.8) * 0.0007 * water_mask;
	COLOR = texture(TEXTURE, clamp(uv, vec2(0.001), vec2(0.999))) * tint;
}
