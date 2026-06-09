shader_type canvas_item;

// 屏幕暗角/氛围 - 配合死亡之雾等机制
// 用法: 应用在覆盖全屏的 ColorRect 上，设为半透明背景
// 参数:
//   vignette_intensity: 暗角强度 (0.0-1.0)
//   vignette_radius: 暗角半径 (0.3-1.0, 越小中心亮区越小)
//   vignette_color: 暗角颜色（黑色/深紫/血红等）

uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float vignette_radius : hint_range(0.1, 1.5) = 0.7;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	// 计算到中心的距离
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);

	// 暗角渐变（中心亮，边缘暗）
	float vignette = smoothstep(vignette_radius, vignette_radius * 1.5, dist);
	vignette *= vignette_intensity;

	// 混合暗角颜色
	COLOR = vec4(vignette_color.rgb, vignette);
}
