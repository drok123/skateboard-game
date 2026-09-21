shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec3 concrete_color : source_color = vec3(0.46, 0.45, 0.42);
uniform float roughness_base : hint_range(0.0, 1.0) = 0.94;
uniform float stain_strength : hint_range(0.0, 1.0) = 0.24;

varying vec3 world_pos;
varying vec3 world_normal;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i);
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float coarse = noise3(world_pos * 0.38);
	float fine = noise3(world_pos * 5.8 + vec3(7.0, 2.0, 11.0));
	float upward = smoothstep(0.1, 0.9, world_normal.y * 0.5 + 0.5);
	float depth_tone = smoothstep(0.0, 1.0, clamp(-world_pos.y / 3.1, 0.0, 1.0));
	vec3 color = concrete_color * (0.88 + coarse * 0.18 + fine * 0.035);
	color *= mix(1.0, 0.69, depth_tone);
	color *= 1.0 - pow(noise3(world_pos * vec3(0.6, 2.8, 0.6)), 2.0) * stain_strength * (1.0 - upward * 0.45);
	float pore = smoothstep(0.93, 0.99, fine);
	ALBEDO = clamp(color * (1.0 - pore * 0.18), vec3(0.07), vec3(0.82));
	ROUGHNESS = clamp(roughness_base + fine * 0.04, 0.7, 0.99);
	METALLIC = 0.0;
	SPECULAR = 0.20;
}
