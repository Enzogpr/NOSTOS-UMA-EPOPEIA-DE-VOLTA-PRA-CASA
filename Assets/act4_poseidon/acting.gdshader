shader_type canvas_item;
render_mode unshaded;
uniform vec4 region = vec4(0.0,0.0,1.0,1.0);
uniform float clock = 0.0;
uniform float speaking = 0.0;
uniform float walking = 0.0;
uniform float tension = 0.0;
uniform float contact = 0.0;
uniform float emergence = 1.0;
uniform float pressure = 0.0;
varying vec4 sprite_color;
void vertex() { sprite_color = COLOR; }
void fragment() {
	vec2 p = (UV-region.xy)/region.zw;
	vec2 at = UV;
	float hair = (1.0-smoothstep(0.22,0.50,p.y))*smoothstep(0.14,0.58,abs(p.x-0.5)*2.0);
	float cloth = smoothstep(0.28,0.78,p.y)*(1.0-smoothstep(0.2,0.65,p.x));
	at.x += sin(clock*2.0+p.y*9.0)*region.z*(0.002*hair+0.003*cloth);
	// A light upper-body nod; grip areas remain stable on contact illustrations.
	float head = 1.0-smoothstep(0.18,0.32,p.y);
	at.y += sin(clock*(2.3+tension))*region.w*0.0012*head*(1.0-contact);
	at.y += sin(clock*7.4)*region.w*0.0006*speaking*head*(1.0-contact);
	at.y += sin(clock*8.5+p.x*6.0)*region.w*0.002*walking*smoothstep(0.7,0.95,p.y);
	if (contact > 0.5) {
		vec2 grip = contact < 1.5 ? vec2(0.50,0.065) : vec2(0.28,0.22);
		float pinned = smoothstep(0.04,0.20,length(p-grip));
		float left_body = (1.0-smoothstep(0.43,0.58,p.x))*(1.0-smoothstep(0.72,0.99,p.y));
		at.x += sin(clock*2.8)*region.z*0.004*pinned*left_body;
		at.y += sin(clock*3.2+1.0)*region.w*0.002*pinned*left_body;
		// The head, both resisting hands and the gripping palm move together.
		float upper_left = (1.0-smoothstep(0.38,0.61,p.x))*(1.0-smoothstep(0.36,0.72,p.y));
		at.x += pressure*region.z*0.025*upper_left;
		at.y += pressure*region.w*0.014*upper_left;
	}
	at = clamp(at,region.xy+vec2(0.0002),region.xy+region.zw-vec2(0.0002));
	COLOR = texture(TEXTURE,at)*sprite_color;
	if (emergence < 0.999) COLOR.a *= smoothstep(1.0-emergence-0.06,1.0-emergence+0.06,p.y);
}
