shader_type spatial;

uniform float min_height;
uniform float max_height;
uniform sampler2D height_color: repeat_disable;
uniform vec3 hole_local_pos = vec3(0.0);
uniform float hole_radius = 0.0;
uniform float stripe_width = 3.0;

// Fairway stripe colors: #136d15 and #117c13
const vec3 STRIPE_A = vec3(0.0745, 0.4275, 0.0824);
const vec3 STRIPE_B = vec3(0.0667, 0.4863, 0.0745);

// Diagonal XZ direction so stripes run at 45° relative to world axes,
// producing visible parallel lines on plateaus regardless of their orientation.
const vec3 STRIPE_DIR = vec3(0.7071, 0.0, 0.7071);

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
	vec3 terrain_color = texture(height_color, vec2(t, 0.0)).rgb;

	float flat_mask = step(0.999, COLOR.r);
	if (flat_mask > 0.0) {
		float stripe_val = dot(local_pos, STRIPE_DIR) / stripe_width;
		ALBEDO = mix(STRIPE_A, STRIPE_B, step(0.5, fract(stripe_val)));
	} else {
		ALBEDO = terrain_color;
	}
}
