// Solid audio-reactive Mandelbulb for transparent stream compositing.
// The object uses a distance-field normal and conventional three-point lighting.

const PI: f32 = 3.14159265359;
const MAX_STEPS: i32 = 34;

fn rotate_x(p: vec3<f32>, angle: f32) -> vec3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec3<f32>(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

fn rotate_y(p: vec3<f32>, angle: f32) -> vec3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec3<f32>(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

// Returns distance and an orbit trap used for the chrome interference bands.
fn mandelbulb_distance(point: vec3<f32>, power: f32) -> vec2<f32> {
    var z = point;
    var derivative = 1.0;
    var radius = 0.0;
    var trap = 8.0;

    for (var iteration = 0; iteration < 8; iteration++) {
        radius = length(z);
        trap = min(trap, abs(length(z.xy) - 0.42));
        if radius > 2.4 {
            break;
        }
        if radius < 0.00001 {
            z += vec3<f32>(0.00001, 0.0, 0.0);
            radius = length(z);
        }

        let theta = acos(clamp(z.z / radius, -1.0, 1.0));
        let phi = atan2(z.y, z.x);
        let radius_power = pow(radius, power);
        derivative = pow(radius, power - 1.0) * power * derivative + 1.0;
        let powered_theta = theta * power;
        let powered_phi = phi * power;
        z = radius_power * vec3<f32>(
            sin(powered_theta) * cos(powered_phi),
            sin(powered_theta) * sin(powered_phi),
            cos(powered_theta),
        ) + point;
    }

    let safe_radius = max(radius, 0.00001);
    let distance = 0.5 * log(safe_radius) * safe_radius / max(derivative, 0.00001);
    return vec2<f32>(distance, trap);
}

fn scene_distance(point: vec3<f32>, audio: vec3<f32>) -> vec2<f32> {
    var p = rotate_y(point, iTime * 0.16 + audio.x * 0.10);
    p = rotate_x(p, -0.28 + sin(iTime * 0.11) * 0.08 + audio.y * 0.06);

    // Each frequency family owns a different axis. This reads as a changing
    // silhouette instead of the whole object breathing in and out.
    let axes = vec3<f32>(
        1.0 + audio.x * 0.15,
        1.0 + audio.y * 0.18,
        1.0 - audio.z * 0.09,
    );
    p /= axes;
    let twist = (audio.y * 0.12 + audio.z * 0.06) * sin(p.y * 3.2 + iTime * 0.35);
    p = rotate_y(p, twist);

    let sample = mandelbulb_distance(p, 7.85 + audio.y * 0.75 - audio.z * 0.30);
    return vec2<f32>(sample.x * min(axes.x, min(axes.y, axes.z)), sample.y);
}

fn surface_normal(point: vec3<f32>, audio: vec3<f32>) -> vec3<f32> {
    let epsilon = 0.0028;
    let e1 = vec3<f32>(1.0, -1.0, -1.0);
    let e2 = vec3<f32>(-1.0, -1.0, 1.0);
    let e3 = vec3<f32>(-1.0, 1.0, -1.0);
    let e4 = vec3<f32>(1.0, 1.0, 1.0);
    return normalize(
        e1 * scene_distance(point + e1 * epsilon, audio).x +
        e2 * scene_distance(point + e2 * epsilon, audio).x +
        e3 * scene_distance(point + e3 * epsilon, audio).x +
        e4 * scene_distance(point + e4 * epsilon, audio).x
    );
}

@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
    let count = arrayLength(&freqs);
    let bass_raw = clamp((freqs[0] + freqs[1] + freqs[2] + freqs[3]) * 0.25, 0.0, 1.0);
    let middle_index = count / 2u;
    let middle_raw = clamp((freqs[middle_index] + freqs[min(middle_index + 1u, count - 1u)]) * 0.5, 0.0, 1.0);
    let treble_raw = clamp((freqs[count - 2u] + freqs[count - 1u]) * 0.5, 0.0, 1.0);
    let bass = smoothstep(0.012, 0.24, bass_raw);
    let middle = smoothstep(0.009, 0.19, middle_raw);
    let treble = smoothstep(0.006, 0.15, treble_raw);
    let audio = vec3<f32>(bass, middle, treble);

    let aspect = iResolution.x / iResolution.y;
    var uv = position.xy / iResolution.xy;
    uv = (uv - vec2<f32>(0.875, 0.805)) * vec2<f32>(aspect, 1.0);

    let ray_origin = vec3<f32>(0.0, 0.0, 3.55);
    let ray_direction = normalize(vec3<f32>(uv * 6.70, -2.35));
    var travel = 0.0;
    var hit = false;
    var trap = 1.0;
    var point = ray_origin;

    for (var step = 0; step < MAX_STEPS; step++) {
        point = ray_origin + ray_direction * travel;
        let sample = scene_distance(point, audio);
        trap = min(trap, sample.y);
        if abs(sample.x) < 0.0015 {
            hit = true;
            break;
        }
        travel += max(abs(sample.x) * 0.78, 0.004);
        if travel > 6.4 {
            break;
        }
    }

    if !hit {
        return vec4<f32>(0.0);
    }

    let normal = surface_normal(point, audio);
    let view = -ray_direction;
    let key_direction = normalize(vec3<f32>(-0.55, -0.72, 0.80));
    let fill_direction = normalize(vec3<f32>(0.70, 0.18, 0.45));
    let key = max(dot(normal, key_direction), 0.0);
    let fill = max(dot(normal, fill_direction), 0.0);
    let half_vector = normalize(key_direction + view);
    let specular = pow(max(dot(normal, half_vector), 0.0), 42.0);
    let rim = pow(1.0 - max(dot(normal, view), 0.0), 3.0);

    let deep_steel = vec3<f32>(0.075, 0.16, 0.22);
    let blue_steel = vec3<f32>(0.16, 0.43, 0.59);
    let pale_cyan = vec3<f32>(0.39, 0.67, 0.72);
    let neutral_chrome = vec3<f32>(0.38, 0.43, 0.47);
    let highlight = vec3<f32>(0.92, 0.98, 1.0);
    let color_phase = 0.5 + 0.5 * sin(iTime * 0.085 + middle * 0.30);
    let dark_material = mix(deep_steel, blue_steel, color_phase);
    let light_material = mix(neutral_chrome, pale_cyan, color_phase);
    let material_variation = smoothstep(0.02, 0.28, trap);
    let base = mix(light_material, dark_material, material_variation);
    var color = base * (0.24 + key * 0.82 + fill * 0.24);
    color += highlight * specular * (0.72 + treble * 0.20);
    color += mix(blue_steel, pale_cyan, color_phase) * rim * 0.34;
    color *= 0.96 + middle * 0.05;
    return vec4<f32>(color, 0.98);
}
