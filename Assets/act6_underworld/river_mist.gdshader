shader_type canvas_item;
render_mode unshaded;

uniform vec2 camera_offset;
uniform vec2 traveler;
uniform vec2 clearing;
uniform float clock;
uniform float density = 0.46;

float hash21(vec2 p) {
	uvec2 cell = uvec2(ivec2(p));
	uint hash = (cell.x * 1597334677u) ^ (cell.y * 3812015801u);
	hash = (hash ^ (hash >> 16u)) * 2246822519u;
	return float(hash & 65535u) / 65535.0;
}

float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 blend = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + 1.0), blend.x), blend.y);
}

void fragment() {
	vec2 at = UV * vec2(1152.0, 648.0) + camera_offset;
	vec2 p = at / vec2(260.0, 105.0);
	float slow = noise2(p - vec2(clock * 0.055, clock * 0.013));
	float ripple = noise2(p * 2.15 + vec2(-clock * 0.105, slow * 0.88));
	float detail = noise2(p * 4.4 - vec2(clock * 0.15, ripple));
	float fog = smoothstep(0.33, 0.75, slow * 0.64 + ripple * 0.25 + detail * 0.11);
	float breathing_room = smoothstep(80.0, 330.0, length((at - traveler) * vec2(0.87, 1.2)));
	float clear_air = smoothstep(82.0, 245.0, length(at - clearing));
	vec3 color = mix(vec3(0.22, 0.40, 0.43), vec3(0.64, 0.77, 0.73), fog);
	COLOR = vec4(color, density * fog * breathing_room * clear_air);
}
