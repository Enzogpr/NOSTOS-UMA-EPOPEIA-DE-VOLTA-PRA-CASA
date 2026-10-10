shader_type canvas_item;
uniform float water = 0.0;
uniform float fire = 0.0;
uniform float dream = 0.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec2 uv = UV;
	// Less than a pixel of displacement; movement accompanies the static art.
	uv.x += sin(UV.y * 120.0 + TIME * 1.6) * 0.00065 * water * smoothstep(0.45, 0.75, UV.y);
	uv.x += sin(UV.y * 19.0 + TIME * 0.45) * 0.0006 * dream;
	vec4 art = texture(TEXTURE, clamp(uv, vec2(0.001), vec2(0.999)));
	float glow = (sin(TIME * 4.3) * 0.014 + sin(TIME * 7.1) * 0.009) * fire;
	art.rgb += vec3(1.0, 0.48, 0.16) * glow;
	COLOR = art * tint;
}
