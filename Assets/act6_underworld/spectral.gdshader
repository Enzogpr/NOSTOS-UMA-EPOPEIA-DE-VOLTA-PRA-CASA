shader_type canvas_item;
render_mode unshaded;
uniform float simulation_clock=0.0;
uniform vec4 region=vec4(0.0,0.0,1.0,1.0);
uniform vec4 spectral_color : source_color=vec4(0.3,0.8,0.8,0.65);
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
 vec2 local=(UV-region.xy)/region.zw;
 vec2 warped=UV+vec2(sin(local.y*13.0+simulation_clock*2.0)*0.003*region.z,0.0);
 warped=clamp(warped,region.xy+vec2(0.0002),region.xy+region.zw-vec2(0.0002));
 vec4 art=texture(TEXTURE,warped);
 float light=dot(art.rgb,vec3(0.25,0.55,0.20));
 vec3 color=spectral_color.rgb*(0.55+light*0.9);
 float breath=0.88+sin(simulation_clock*1.7+local.y*8.0)*0.08;
 COLOR=vec4(color,art.a*spectral_color.a*breath)*tint;
}
