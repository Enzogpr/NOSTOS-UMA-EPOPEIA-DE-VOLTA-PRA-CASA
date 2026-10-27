shader_type canvas_item;
render_mode unshaded;
uniform float clock = 0.0;
uniform float emergence = 0.0;

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = fract(p);
	t = t*t*(3.0-2.0*t);
	vec2 k = vec2(127.1,311.7);
	float a = fract(sin(dot(cell,k))*43758.5453);
	float b = fract(sin(dot(cell+vec2(1.0,0.0),k))*43758.5453);
	float c = fract(sin(dot(cell+vec2(0.0,1.0),k))*43758.5453);
	float d = fract(sin(dot(cell+vec2(1.0,1.0),k))*43758.5453);
	return mix(mix(a,b,t.x),mix(c,d,t.x),t.y);
}
float mist(vec2 p) {
	return noise(p)*0.57 + noise(p*2.03+19.0)*0.28 + noise(p*4.07)*0.15;
}
void fragment() {
	vec2 uv = UV;
	float drift = mist(uv*8.0+vec2(clock*0.12,-clock*0.07));
	vec2 p = uv+vec2((drift-0.5)*0.055,sin(clock*0.7)*0.008);
	// Only a suggestion of a head and shoulders, without limbs or any features.
	float crown = length((p-vec2(0.67,0.23))/vec2(0.066,0.119));
	float shoulders = length((p-vec2(0.67,0.43))/vec2(0.202,0.194));
	float body = length((p-vec2(0.67,0.58))/vec2(0.148,0.30));
	float distance = min(crown,min(shoulders,body));
	float mass = 1.0-smoothstep(0.64,1.10,distance+(drift-0.5)*0.32);
	float veil = mist(uv*vec2(11.0,15.0)+vec2(-clock*0.15,clock*0.035));
	float dissolve = (1.0-smoothstep(0.56,0.76,uv.y))*smoothstep(0.02,0.13,uv.y);
	float opacity = mass*dissolve*(0.53+veil*0.22)*emergence;
	vec3 shadow = mix(vec3(0.014,0.034,0.048),vec3(0.15,0.23,0.27),veil*0.30);
	// Moving bright mist passes in front of the mass, breaking up its outline.
	float fog = smoothstep(0.48,0.74,veil)*mass*dissolve*0.24*emergence;
	COLOR = vec4(mix(shadow,vec3(0.38,0.51,0.55),fog*2.4),opacity);
}
