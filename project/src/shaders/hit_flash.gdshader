shader_type canvas_item;

// 受击染色闪白 - 替代 modulate 闪白，保留原色细节
// 用法: 在角色 Sprite2D 上应用，从脚本控制 flash_amount (0→1→0)
// 优势: 比单纯 modulate = Color(2,2,2) 更细腻，保留原图明暗层次
// 参数:
//   flash_color: 闪烁颜色（默认白色，也可以红色表示受伤）
//   flash_amount: 闪烁程度 (0=正常, 1=完全闪色)

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	// 保留原图的亮度，混合闪烁颜色
	// 使用 mix 而非直接叠加，保持细节
	float luminance = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 flash_result = mix(col.rgb, flash_color.rgb * luminance * 2.0, flash_amount);

	COLOR = vec4(flash_result, col.a);
}
