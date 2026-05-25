shader_type spatial;

uniform float min_height;
uniform float max_height;
uniform sampler2D height_color: repeat_disable;
uniform vec3 hole_local_pos = vec3(0.0);
uniform float hole_radius = 0.0;

varying float height;
varying vec3 local_pos;

void vertex() {
	height = length(VERTEX);
	local_pos = VERTEX;
}

void fragment() {
	if (hole_radius > 0.0 && distance(local_pos, hole_local_pos) < hole_radius) {
		discard;
	}
	float t = height / (max_height - min_height) - (min_height / (max_height - min_height));
	vec3 color = texture(height_color, vec2(t, 0.0)).rgb;
	ALBEDO = color;
}
