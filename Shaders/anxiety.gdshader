shader_type canvas_item;
// Separation anxiety / closeness comfort, applied to the whole screen.
//   separation 0..1 : cold, desaturated, tighter vignette (apart)
//   warmth     0..1 : warm tint with a slow steady pulse (close, cord taut)

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float separation = 0.0;
uniform float warmth = 0.0;
uniform float pulse_time = 0.0;  // fed from game time so it freezes on pause

void fragment() {
	vec4 c = texture(screen_texture, SCREEN_UV);
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(c.rgb, vec3(grey) * vec3(0.85, 0.93, 1.12), separation * 0.85);
	float pulse = 0.5 + 0.5 * sin(pulse_time * 1.7);
	col += vec3(0.07, 0.035, -0.01) * warmth * (0.55 + 0.45 * pulse);
	vec2 uv = (SCREEN_UV - 0.5) * vec2(1.0, 0.75);
	float v = smoothstep(0.3, 0.8, length(uv) * (1.0 + separation * 0.8));
	col *= 1.0 - v * (0.2 + separation * 0.7);
	COLOR = vec4(col, 1.0);
}
