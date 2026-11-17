#version 440
// Fisheye lens: maps a flat stack of lyric lines onto a drum, so the middle line is large
// and lines above and below shrink and fade as they curve away.
// Rebuild after editing: /usr/lib/qt6/bin/qsb --qt6 -o qml/shaders/lens.frag.qsb qml/shaders/lens.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    float yn = qt_TexCoord0.y * 2.0 - 1.0;          // -1 top .. 1 bottom
    float depth = sqrt(max(1.0 - yn * yn, 0.0));     // 1 at the centre, 0 at the rim
    float v = 0.5 + asin(clamp(yn, -1.0, 1.0)) / 3.14159;
    float u = 0.5 + (qt_TexCoord0.x - 0.5) / (0.55 + 0.45 * depth); // far lines get narrower
    if (u < 0.0 || u > 1.0) {
        fragColor = vec4(0.0);
        return;
    }
    fragColor = texture(source, vec2(u, v)) * depth * qt_Opacity; // premultiplied fade
}
