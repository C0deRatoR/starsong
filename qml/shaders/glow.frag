#version 440
// Edge glow: light that falls off from every screen edge in two album colours.
// Motion modes vary how bright and thick the light is along the frame over time, and (when
// moving) let the colours drift round the screen.
// Rebuild after editing: /usr/lib/qt6/bin/qsb --qt6 -o qml/shaders/glow.frag.qsb qml/shaders/glow.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;        // window size in pixels
    vec4 colorA;
    vec4 colorB;
    float intensity; // 0..1, driven by the bass
    float thickness; // falloff distance in pixels
    float time;      // 0..2pi, loops; every wave below uses a whole multiple so the loop is seamless
    float mode;      // motion, see modes in Glow.qml: 0 still, 1 waves, 2 orbit, 3 twin orbit,
                     // 4 breathe, 5 aurora, 6 beat ripple
    float ripple;    // beat ripple progress 0..1 (1 = finished)
};

const float TAU = 6.28318;

// A comet at `head` (0..1 round the frame): bright head, tail fading behind it, sharp front.
vec4 comet(vec4 along, float head) {
    vec4 behind = fract(vec4(head) - along);
    vec4 ahead = fract(along - vec4(head));
    return max(exp(-behind * 7.0), exp(-ahead * 60.0));
}

void main() {
    vec2 p = qt_TexCoord0 * res;
    vec4 one = vec4(1.0);

    // Distance to each edge: left, right, top, bottom. Light from all four is added up; taking
    // only the nearest edge would leave diagonal seams in the corners, like a picture frame's mitre.
    vec4 d = vec4(p.x, res.x - p.x, p.y, res.y - p.y);

    // Where this pixel sits along each edge, as one loop around the frame (0..1, clockwise from
    // the top-left corner). Measuring along the edges keeps the waves seamless round the corners.
    float perim = 2.0 * (res.x + res.y);
    vec4 along = vec4(2.0 * res.x + 2.0 * res.y - p.y, // left, going up
                      res.x + p.y,                     // right, going down
                      p.x,                             // top, going right
                      2.0 * res.x + res.y - p.x)       // bottom, going left
                 / perim;

    int m = int(mode + 0.5);
    float topCentre = 0.5 * res.x / perim;
    vec4 shine = one; // brightness along each edge
    vec4 swell = one; // thickness along each edge
    if (m == 1) {
        // Waves: two travel round in opposite directions and brighten where they meet.
        vec4 wave = 0.5 + 0.25 * sin(TAU * along * 2.0 - time * 2.0)
                        + 0.25 * sin(TAU * along * 3.0 + time * 3.0);
        shine = 0.35 + 1.1 * wave;
        swell = 0.75 + 0.5 * wave;
    } else if (m == 2 || m == 3) {
        // Orbit: a comet leaves the top centre, goes clockwise round the screen and back.
        float head = fract(topCentre + time / TAU);
        vec4 c = comet(along, head);
        if (m == 3)
            c = max(c, comet(along, fract(head + 0.5))); // twin: a second one opposite
        shine = 0.12 + 1.7 * c;
        swell = 0.8 + 0.6 * c;
    } else if (m == 4) {
        // Breathe: the whole frame slowly brightens and dims.
        float b = 0.5 + 0.5 * sin(time * 2.0);
        shine = vec4(0.3 + 0.9 * b);
        swell = vec4(0.8 + 0.4 * b);
    } else if (m == 5) {
        // Aurora: fine shimmering ripples at several speeds.
        vec4 w = 0.5 + 0.2 * sin(TAU * along * 5.0 + time * 3.0)
                     + 0.2 * sin(TAU * along * 9.0 - time * 4.0)
                     + 0.1 * sin(TAU * along * 13.0 + time * 7.0);
        shine = 0.25 + 1.2 * w;
        swell = 0.7 + 0.6 * w;
    } else if (m == 6) {
        // Beat ripple: each bass hit sends light from the top centre down both sides.
        vec4 fromTop = min(fract(along - topCentre), fract(topCentre - along)); // 0 top .. 0.5 bottom
        vec4 front = exp(-abs(fromTop - ripple * 0.5) * 30.0) * (1.0 - ripple);
        shine = 0.35 + 1.8 * front;
        swell = 0.85 + 0.6 * front;
    }
    float moves = m == 0 ? 0.0 : 1.0;

    float core = dot(exp(-d / (2.5 * swell)) * shine, one);        // thin, bright rim at the edge
    float bloom = dot(exp(-d / (thickness * swell)) * shine, one); // coloured light spilling inward

    // Colour: still, it shifts slowly across the diagonal; flowing, it travels round the frame
    // (using the nearest edge's position, which matches its neighbour at each corner).
    vec2 lr = d.x < d.y ? vec2(d.x, along.x) : vec2(d.y, along.y);
    vec2 tb = d.z < d.w ? vec2(d.z, along.z) : vec2(d.w, along.w);
    float nearest = lr.x < tb.x ? lr.y : tb.y;
    float still = 0.5 + 0.5 * sin((qt_TexCoord0.x - qt_TexCoord0.y) * 3.14159 + time);
    float moving = 0.5 + 0.5 * sin(TAU * nearest - time);
    vec3 c = mix(colorA.rgb, colorB.rgb, mix(still, moving, moves));

    // The rim burns near-white and solid so it reads as a light source, not more background;
    // the bloom stays coloured and partly additive, lighting what's underneath.
    float rim = clamp(core * intensity, 0.0, 1.0);
    vec3 col = mix(c, mix(c, vec3(1.0), 0.6), rim);
    float a = clamp((core * 1.2 + 0.6 * bloom) * intensity, 0.0, 1.0);
    fragColor = vec4(col * a, a * mix(0.6, 1.0, rim)) * qt_Opacity;
}
