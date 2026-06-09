shader_type canvas_item;

// 稀有度描边发光 - 给装备图标/掉落物加稀有度颜色描边
// 用法: 在 Sprite2D/TextureRect 上设置 ShaderMaterial，调整参数
// 参数:
//   outline_color: 描边颜色（建议按稀有度：普通=灰、罕见=蓝、稀有=紫、史诗=金、传奇=橙红）
//   outline_width: 描边宽度（像素，1-3 适合图标）
//   glow_intensity: 发光强度（0-2，传奇/神话建议 1.2-1.8）
//   pulse_speed: 脉冲速度（仅当 glow_intensity > 0 时生效）

uniform vec4 outline_color : source_color = vec4(1.0, 0.8, 0.0, 1.0);
uniform float outline_width : hint_range(0.0, 5.0) = 2.0;
uniform float glow_intensity : hint_range(0.0, 3.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float alpha = col.a;

	// 检测边缘（采样周围像素判断是否为边界）
	float outline = 0.0;
	if (alpha < 0.5) {
		vec2 pixel_size = TEXTURE_PIXEL_SIZE * outline_width;
		for (float x = -1.0; x <= 1.0; x += 1.0) {
			for (float y = -1.0; y <= 1.0; y += 1.0) {
				if (x == 0.0 && y == 0.0) continue;
				vec2 offset = vec2(x, y) * pixel_size;
				float neighbor_alpha = texture(TEXTURE, UV + offset).a;
				if (neighbor_alpha > 0.5) {
					outline = 1.0;
					break;
				}
			}
			if (outline > 0.5) break;
		}
	}

	// 脉冲发光（用 TIME 实现呼吸效果）
	float pulse = 1.0;
	if (glow_intensity > 0.0) {
		pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
	}

	// 混合原色和描边
	if (outline > 0.5) {
		vec3 glow_col = outline_color.rgb * (1.0 + glow_intensity * pulse);
		COLOR = vec4(glow_col, outline_color.a);
	} else {
		// 对传奇物品，整体叠加微弱辉光
		if (glow_intensity > 0.0 && alpha > 0.5) {
			col.rgb += outline_color.rgb * glow_intensity * 0.2 * pulse;
		}
		COLOR = col;
	}
}
