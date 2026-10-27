shader_type canvas_item;
render_mode unshaded;
uniform vec4 region = vec4(0.0,0.0,1.0,1.0);
uniform float clock = 0.0;
uniform float speaking = 0.0;
uniform float walking = 0.0;
varying vec4 sprite_color;
void vertex() { sprite_color = COLOR; }
void fragment() {
	vec2 local = (UV - region.xy) / region.zw;
	vec2 uv = UV;
	// Gentle cloth ripple and speaking motion, clipped to this atlas pose.
	float cloth = smoothstep(0.26,0.75,local.y) * (1.0-smoothstep(0.15,0.45,local.x));
	uv.x += sin(clock*2.4 + local.y*6.0) * region.z * 0.0035 * cloth;
	float head = 1.0-smoothstep(0.14,0.28,local.y);
	uv.y += sin(clock*11.0) * region.w * 0.0009 * speaking * head;
	float legs = smoothstep(0.70,0.90,local.y);
	uv.y += sin(clock*9.0 + local.x*8.0) * region.w * 0.003 * walking * legs;
	uv = clamp(uv, region.xy, region.xy+region.zw);
	COLOR = texture(TEXTURE,uv) * sprite_color;
}
