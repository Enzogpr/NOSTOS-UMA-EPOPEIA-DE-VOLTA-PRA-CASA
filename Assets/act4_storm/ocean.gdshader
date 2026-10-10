shader_type canvas_item;
uniform float storm_clock = 0.0;
uniform float lightning = 0.0;
varying vec2 sea_position;
void vertex() {sea_position = VERTEX;}
float hash(vec2 p) {return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);}
void fragment() {
	vec2 p = floor(sea_position / 2.0);
	float swell = sin(p.x * 0.027 + p.y * 0.08 + storm_clock * 1.7) + sin(p.x * 0.043 - p.y * 0.051 + storm_clock * 1.3);
	float grain = hash(floor(p / 3.0));
	vec3 sea = mix(vec3(0.025, 0.075, 0.13), vec3(0.065, 0.22, 0.29), (swell + 2.0) * 0.25);
	sea += floor(grain * 4.0) * 0.007;
	if (swell > 1.70 && grain > 0.68) {sea += vec3(0.16, 0.25, 0.27);}
	COLOR = vec4(sea + lightning * vec3(0.43, 0.55, 0.61), 1.0);
}
