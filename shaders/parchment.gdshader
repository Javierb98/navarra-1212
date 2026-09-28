shader_type canvas_item;
// Parchment ground for every screen.
//
// This is the cheapest large win in the whole art plan: two octaves of value
// noise for the blotching, a fine grain on top and a soft vignette, and a flat
// colour rectangle reads as a page of a 13th-century codex. No texture files,
// no drawing, and it runs fine on the Pi's OpenGL ES 3 path.

uniform vec4 base_color : source_color = vec4(0.910, 0.863, 0.753, 1.0);
uniform vec4 stain_color : source_color = vec4(0.808, 0.741, 0.596, 1.0);
uniform float stain_scale : hint_range(1.0, 20.0) = 6.0;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.25;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.85;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float stains = fbm(uv * stain_scale);
	vec3 col = mix(base_color.rgb, stain_color.rgb, stains * 0.55);

	// Fine tooth of the vellum.
	float grain = hash(floor(uv * 1400.0));
	col -= (grain - 0.5) * grain_strength * 0.11;

	// Edges of a page always sit darker than the middle.
	float d = distance(uv, vec2(0.5));
	col *= 1.0 - d * d * vignette_strength;

	COLOR = vec4(col, base_color.a);
}
