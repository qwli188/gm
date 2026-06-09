shader_type canvas_item;

// 状态层叠加 - 给中冰冻/中毒/点燃的敌人加视觉效果
// 用法: 在敌人 Sprite 上动态应用，根据状态设置 status_type
// 参数:
//   status_type: 0=无, 1=冰冻(蓝晶), 2=中毒(绿脉动), 3=点燃(红闪烁)
//   effect_intensity: 效果强度 (0.0-1.0)

uniform int status_type : hint_range(0, 3) = 0;
uniform float effect_intensity : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	if (status_type == 1) {
		// 冰冻：叠加蓝色冰晶，带微弱闪烁
		vec3 ice_color = vec3(0.4, 0.7, 1.0);
		float ice_pulse = 0.8 + 0.2 * sin(TIME * 1.5);
		col.rgb = mix(col.rgb, ice_color, effect_intensity * 0.4 * ice_pulse);

		// 添加晶体高光（基于 UV 网格）
		float grid = step(0.8, fract(UV.x * 10.0)) + step(0.8, fract(UV.y * 10.0));
		col.rgb += vec3(0.6, 0.8, 1.0) * grid * effect_intensity * 0.3;

	} else if (status_type == 2) {
		// 中毒：绿色脉动，带流动感
		vec3 poison_color = vec3(0.2, 0.9, 0.3);
		float poison_pulse = 0.5 + 0.5 * sin(TIME * 3.0 + UV.y * 10.0);
		col.rgb = mix(col.rgb, poison_color, effect_intensity * 0.35 * poison_pulse);

	} else if (status_type == 3) {
		// 点燃：红橙闪烁，模拟火焰
		vec3 fire_color = vec3(1.0, 0.4, 0.1);
		float fire_flicker = 0.6 + 0.4 * sin(TIME * 8.0 + UV.x * 15.0);
		col.rgb = mix(col.rgb, fire_color, effect_intensity * 0.5 * fire_flicker);
		// 边缘更亮（模拟火焰边缘）
		float edge_glow = smoothstep(0.3, 0.7, sin(TIME * 5.0));
		col.rgb += fire_color * edge_glow * effect_intensity * 0.3;
	}

	COLOR = col;
}
