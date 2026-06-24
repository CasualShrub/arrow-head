shader_type spatial;

render_mode unshaded, blend_mix, cull_disabled;

uniform int sector_count = 8;
uniform int aimed_sector = -1;
uniform int occupied_mask = 0;

uniform vec4 empty_color : source_color =
    vec4(0.9, 0.35, 0.15, 0.12);

uniform vec4 occupied_color : source_color =
    vec4(0.9, 0.35, 0.15, 0.50);

uniform vec4 highlight_color : source_color =
    vec4(1.0, 0.7, 0.4, 0.95);

uniform vec4 line_color : source_color =
    vec4(0.95, 0.45, 0.25, 0.7);

uniform float edge_width = 0.02;
uniform float outer_ring_width = 0.02;

bool sector_occupied(int sector) {
    return (occupied_mask & (1 << sector)) != 0;
}

void fragment() {

    vec2 p = UV * 2.0 - 1.0;

    float r = length(p);

    if (r > 1.0) {
        discard;
    }

    float angle = atan(p.y, p.x);

    if (angle < 0.0) {
        angle += TAU;
    }

    float sector_size =
        TAU / float(max(sector_count, 1));

    int sector =
        int(floor(angle / sector_size));

    vec4 color =
        sector_occupied(sector)
        ? occupied_color
        : empty_color;

    if (sector == aimed_sector) {
        color = highlight_color;
    }

    float local_angle =
        mod(angle, sector_size);

    float edge_dist =
        min(
            local_angle,
            sector_size - local_angle
        );

    bool radial_edge =
        edge_dist < edge_width;

    bool outer_edge =
        abs(r - 1.0) < outer_ring_width;

    if (radial_edge || outer_edge) {
        color = line_color;

        if (sector == aimed_sector) {
            color = highlight_color;
        }
    }

    ALBEDO = color.rgb;
    ALPHA = color.a;
}