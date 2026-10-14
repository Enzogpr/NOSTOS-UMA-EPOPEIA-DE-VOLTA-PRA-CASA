shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_image : hint_screen_texture, repeat_disable, filter_linear;
uniform float fatigue = 0.0;
uniform float closure = 0.0;
uniform float day_pressure = 0.0;
uniform vec2 vision_center = vec2(0.5, 0.48);
uniform float clock = 0.0;
void fragment() {
	vec2 px = vec2(1.0) / vec2(textureSize(screen_image, 0));
	float weight = smoothstep(0.45, 1.0, fatigue);
	vec2 shift = vec2(sin(clock * 1.1), cos(clock * 0.85)) * weight * 3.0 * px;
	vec2 at = SCREEN_UV + shift;
	vec2 radius = px * weight * 2.3;
	vec4 picture = texture(screen_image, at) * 0.4;
	picture += texture(screen_image, at + vec2(radius.x, 0.0)) * 0.15;
	picture += texture(screen_image, at - vec2(radius.x, 0.0)) * 0.15;
	picture += texture(screen_image, at + vec2(0.0, radius.y)) * 0.15;
	picture += texture(screen_image, at - vec2(0.0, radius.y)) * 0.15;
	// A tightening aperture: darkness advances from every border toward the gaze.
	float radius_clear = max(0.025, 0.86 - weight * 0.69 - day_pressure * 0.13);
	float distance_from_gaze = length((UV - vision_center) * vec2(1.25, 1.0));
	float sight = 1.0 - smoothstep(radius_clear - 0.055, radius_clear + 0.075, distance_from_gaze);
	picture.rgb *= sight * (1.0 - closure);
	COLOR = vec4(picture.rgb, 1.0);
}
