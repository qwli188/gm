shader_type canvas_item;

// Boss 溶解/出现效果 - 登场/死亡的溶解动画
// 用法: 从脚本 Tween dissolve_amount: 0→1 (溶解), 1→0 (出现)
// 参数:
//   dissolve_amount: 溶解进度 (0=完整, 1=完全消失)
//   edge_color: 溶解边缘颜色（火焰橙/暗金/紫色）
//   edge_width: 边缘宽度 (0.0-0.2 合适)
//   noise_scale: 噪声缩放（调整溶解纹理细节）

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform float edge_width : hint_range(0.0, 0.3) = 0.08;
uniform float noise_scale : hint_range(1.0, 20.0) = 8.0;

// 简单噪声函数（无需外部纹理）
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	// 生成噪声（基于 UV 和缩放）
	float n = noise(UV * noise_scale);

	// 溶解判断：噪声值 < dissolve_amount 则透明
	float dissolve_threshold = dissolve_amount;
	float alpha_cutoff = n - dissolve_threshold;

	if (alpha_cutoff < 0.0) {
		discard; // 完全丢弃像素
	} else if (alpha_cutoff < edge_width) {
		// 边缘区域，混合发光颜色
		float edge_blend = alpha_cutoff / edge_width;
		col.rgb = mix(edge_color.rgb * 2.0, col.rgb, edge_blend);
		col.a *= (0.5 + 0.5 * edge_blend); // 边缘半透明
	}

	COLOR = col;
}
