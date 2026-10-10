shader_type canvas_item;

uniform float presence : hint_range(0.0, 1.0) = 1.0;
uniform float spectral : hint_range(0.0, 1.0) = 0.0;
uniform float flutter = 0.0;
uniform float elapsed = 0.0;
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	// Sprite region_rect retains atlas UVs, so motion is clipped to that region.
	vec4 tex = texture(TEXTURE, UV);
	float noise = fract(sin(dot(floor(UV * 420.0), vec2(127.1, 311.7))) * 43758.5453);
	float reveal = smoothstep(noise - 0.05, noise + 0.05, presence * 1.1) * step(0.001, presence);
	vec3 rgb = mix(tex.rgb, tex.rgb * vec3(0.94, 0.98, 1.08), spectral * 0.3);
	rgb += vec3(0.3, 0.55, 0.8) * spectral * flutter * sin(elapsed * 2.0) * 0.018;
	COLOR = vec4(rgb, tex.a * reveal) * sprite_tint;
}
