shader_type canvas_item;

uniform float tile_size = 64.0;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.35);
uniform float border_thickness = 1.0;

uniform vec2 camera_offset = vec2(0.0, 0.0);
uniform float camera_zoom = 1.0;
uniform vec2 viewport_size = vec2(1152.0, 648.0);

uniform vec4 field_bounds = vec4(0.0, 0.0, 4096.0, 4096.0);

void fragment() {
	vec2 screen_pixels = SCREEN_UV * viewport_size;
	vec2 world_pos = (screen_pixels / camera_zoom) + camera_offset;

	if (world_pos.x < field_bounds.x || world_pos.x >= field_bounds.z) discard;
	if (world_pos.y < field_bounds.y || world_pos.y >= field_bounds.w) discard;

	vec2 grid_pos = mod(world_pos, tile_size);
	float half_border = border_thickness * 0.5;

	bool on_border_x = grid_pos.x < half_border || grid_pos.x > (tile_size - half_border);
	bool on_border_y = grid_pos.y < half_border || grid_pos.y > (tile_size - half_border);

	COLOR = (on_border_x || on_border_y) ? border_color : vec4(0.0);
}
