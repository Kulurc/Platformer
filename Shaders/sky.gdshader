shader_type canvas_item;
// Sky gradient + sun glow + soft light rays. Used by LevelArt.
uniform vec4 top_col : source_color;
uniform vec4 mid_col : source_color;
uniform vec4 horizon_col : source_color;
uniform vec4 sun_col : source_color;
uniform vec2 sun = vec2(0.74, 0.36);
uniform float sun_power = 1.0;
uniform float rays = 0.35;
float hash(float n){ return fract(sin(n) * 43758.5453); }
float n1(float x){ float i = floor(x); float f = fract(x); f = f*f*(3.0-2.0*f); return mix(hash(i), hash(i+1.0), f); }
void fragment(){
	vec2 uv = UV;
	vec3 c = mix(top_col.rgb, mid_col.rgb, smoothstep(0.0, 0.5, uv.y));
	c = mix(c, horizon_col.rgb, smoothstep(0.45, 0.75, uv.y));
	vec2 d = (uv - sun) * vec2(1.7778, 1.0);
	float r = length(d);
	c += sun_col.rgb * sun_power * (exp(-r * 14.0) * 0.9 + exp(-r * 3.0) * 0.28);
	float ang = atan(d.y, d.x);
	float s = n1(ang * 16.0) * 0.6 + n1(ang * 41.0 + 3.0) * 0.4;
	s = smoothstep(0.5, 0.95, s);
	c += sun_col.rgb * rays * s * exp(-r * 1.4) * smoothstep(-0.1, 0.5, d.y);
	COLOR = vec4(c, 1.0);
}
