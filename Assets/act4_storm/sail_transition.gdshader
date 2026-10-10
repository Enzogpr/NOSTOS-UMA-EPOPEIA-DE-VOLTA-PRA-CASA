shader_type canvas_item;
render_mode unshaded;

uniform sampler2D furled_texture : source_color, filter_nearest;
uniform float reef_amount : hint_range(0.0, 1.0) = 0.0;
varying vec4 ship_tint;

void vertex() {
	ship_tint = COLOR;
}

void fragment() {
	vec4 open_sails = texture(TEXTURE, UV);
	vec4 furled_sails = texture(furled_texture, UV);
	COLOR = mix(open_sails, furled_sails, reef_amount) * ship_tint;
}
