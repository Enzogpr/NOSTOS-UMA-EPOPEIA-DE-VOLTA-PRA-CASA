shader_type canvas_item;
render_mode unshaded;
uniform sampler2D atlas : source_color, filter_linear;
uniform float simulation_clock = 0.0;
uniform float revelation : hint_range(0.0, 1.0) = 0.0;
uniform bool true_path = false;
uniform bool plant_form = false;
uniform float seed = 0.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	float t=simulation_clock;
	vec2 uv=UV;
	float reality=true_path ? revelation : 0.0;
	float swell=sin(uv.x*11.0+t*2.4+seed)*0.024+sin(uv.x*24.0-t*1.7+seed)*0.009;
	vec2 warped=uv+vec2(sin(uv.y*18.0+t*1.5+seed)*0.016,swell)*(1.0-reality*0.92);
	vec2 local=(warped-vec2(0.12,0.28))/vec2(0.76,0.50);
	if (plant_form) { local=(warped-vec2(0.10))/vec2(0.80); }
	float inside=step(0.0,local.x)*step(local.x,1.0)*step(0.0,local.y)*step(local.y,1.0);
	vec2 tex_uv=(vec2(780.0,238.0)+clamp(local,vec2(0),vec2(1))*vec2(748.0,170.0))/vec2(1536.0,1024.0);
	if (plant_form) { tex_uv=(vec2(936.0,531.0)+clamp(local,vec2(0),vec2(1))*vec2(415.0,469.0))/vec2(1536.0,1024.0); }
	vec4 art=texture(atlas,tex_uv);
	float n=noise(uv*vec2(12.0,7.0)+vec2(t*0.38,-t*0.55)+seed);
	float detail=noise(uv*vec2(31.0,19.0)-vec2(t*0.7,t*0.1)+seed);
	float silhouette=art.a*inside;
	float dissolve=true_path ? 1.0 : smoothstep(revelation-0.10,revelation+0.13,n);
	float edge=exp(-abs(n-revelation)*32.0)*revelation*(1.0-revelation);
	float mist=exp(-dot((uv-vec2(0.5,0.48))/vec2(0.51,0.22),(uv-vec2(0.5,0.48))/vec2(0.51,0.22))*2.5);
	float smoke=mist*(0.10+n*0.15+detail*0.07)*(1.0-reality*0.85)*dissolve;
	float luminance=dot(art.rgb,vec3(0.25,0.6,0.15));
	vec3 spectral=mix(vec3(0.34,0.17,0.61),vec3(0.85,0.68,1.0),luminance);
	vec3 solid=art.rgb*vec3(1.03,1.0,0.79)+vec3(0.18,0.12,0.02)*revelation;
	vec3 color=mix(spectral,solid,reality);
	if (plant_form) { color=mix(art.rgb,spectral,revelation*0.70); }
	color+=vec3(0.76,0.50,1.0)*edge*1.2;
	float alpha=max(silhouette*mix(0.55+sin(t*2.0+uv.x*5.0+seed)*0.09,1.0,reality)*dissolve,smoke);
	if (plant_form) { alpha=max(silhouette*dissolve,smoke*revelation); }
	float feather=smoothstep(0.0,0.10,uv.x)*smoothstep(1.0,0.90,uv.x)*smoothstep(1.0,0.75,uv.y);
	COLOR=vec4(color,alpha*feather);
}
