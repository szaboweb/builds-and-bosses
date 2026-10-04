shader_type canvas_item;
uniform bool enabled = false;

void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	if (enabled) {
		sample_color.rgb = floor(sample_color.rgb * 4.0 + 0.5) / 4.0;
	}
	COLOR = sample_color;
}
