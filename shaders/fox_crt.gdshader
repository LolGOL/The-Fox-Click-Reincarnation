shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_alpha : hint_range(0.0, 1.0) = 0.16;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.45;
uniform float aberration : hint_range(0.0, 0.02) = 0.001;
uniform float tear_strength : hint_range(0.0, 0.1) = 0.0;
uniform float bw_mode : hint_range(0.0, 1.0) = 0.0;
uniform float flash_red : hint_range(0.0, 1.0) = 0.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Горизонтальный разрыв экрана (tear) при высоком мицелии или пропуске глитча
	if (tear_strength > 0.0001) {
		float band = floor(uv.y * 24.0 + floor(TIME * 14.0));
		float rnd = hash(band);
		if (rnd > 0.82) {
			uv.x += (rnd - 0.91) * tear_strength * 4.0;
		}
	}

	// Хроматическая аберрация (расслаивание красного и голубого каналов)
	float r = texture(screen_texture, uv + vec2(aberration, 0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(aberration, 0.0)).b;
	vec3 col = vec3(r, g, b);

	// CRT-сканлайны
	float scan = sin(uv.y * 900.0 * 3.14159265) * 0.5 + 0.5;
	col *= 1.0 - scanline_alpha * (1.0 - scan);

	// Виньетка по краям монитора
	vec2 centered = uv - 0.5;
	float vig = 1.0 - dot(centered, centered) * vignette_strength * 1.8;
	col *= clamp(vig, 0.15, 1.0);

	// Жёсткий 1-битный ч/б режим для сделки «Кровавый оверклокинг»
	if (bw_mode > 0.5) {
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		col = luma > 0.11 ? vec3(0.95) : vec3(0.02);
	}

	// Красная вспышка при эволюции фазы или сбое
	col = mix(col, vec3(0.95, 0.06, 0.15), flash_red * 0.45);

	COLOR = vec4(col, 1.0);
}
