shader_type canvas_item;
// Whole-screen finish: colour lift, gentle contrast, vignette, film grain, slight colour fringe.
// `desat` greys everything except strongly saturated colours (e.g. a red cord). Used by LevelArt.
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float vignette = 0.55;
uniform float grain = 0.045;
uniform float desat = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float ca = 0.002;
uniform vec4 lift : source_color = vec4(0.0, 0.0, 0.0, 1.0);
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
vec3 rgb2hsv(vec3 c){
	vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
void fragment(){
	vec2 uv = SCREEN_UV;
	vec2 o = (uv - 0.5) * ca;
	vec3 c = vec3(texture(screen, uv + o).r, texture(screen, uv).g, texture(screen, uv - o).b);
	vec3 hsv = rgb2hsv(c);
	float keep = smoothstep(0.5, 0.75, hsv.y) * smoothstep(0.3, 0.5, hsv.z);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * tint.rgb, desat * (1.0 - keep));
	c = c + lift.rgb * (1.0 - c);
	c = mix(c, c * c * (3.0 - 2.0 * c), 0.3);
	float v = distance(uv * vec2(1.0, 0.8), vec2(0.5, 0.4));
	c *= 1.0 - vignette * smoothstep(0.25, 0.75, v);
	c += (h(uv * vec2(1280.0, 720.0) + fract(TIME * 7.0) * 113.0) - 0.5) * grain;  // animated grain
	COLOR = vec4(c, 1.0);
}
