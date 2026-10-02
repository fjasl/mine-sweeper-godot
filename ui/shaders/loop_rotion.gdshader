shader_type canvas_item;

// 平铺数量
uniform vec2 tile_count = vec2(4.0, 4.0);

// 自转角度
uniform float rotation_angle = 0.0;

// 自转速度
uniform float rotation_speed : hint_range(-3.0, 3.0) = 1.0;

// 移动速度（向左上）
uniform vec2 move_speed = vec2(-0.5, -0.5);

void fragment() {
    // 1️⃣ 计算整体偏移（向左上移动）
    vec2 uv = UV + TIME * move_speed;

    // 2️⃣ 平铺 UV
    uv *= tile_count;

    // 3️⃣ 取出每个格子的局部 UV
    vec2 grid_uv = fract(uv);

    // 4️⃣ 自转（绕格子中心）
    grid_uv -= 0.5;

    float angle = rotation_angle + TIME * rotation_speed;
    float s = sin(angle);
    float c = cos(angle);
    grid_uv = mat2(vec2(c, -s), vec2(s, c)) * grid_uv;

    grid_uv += 0.5;

    // 5️⃣ 采样
    COLOR = texture(TEXTURE, grid_uv);
}