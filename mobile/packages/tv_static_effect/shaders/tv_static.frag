#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uOpacity;

out vec4 fragColor;

// Hash functions for pseudo-random noise
float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash1(float p) {
    return fract(sin(p * 127.1) * 43758.5453);
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;

    // Quantise time to ~12 fps for choppy CRT feel
    float frame = floor(uTime * 12.0);

    // Per-pixel noise – each frame gets a completely new random field
    vec2 pixelCoord = floor(fragCoord / 2.0);
    float n = hash(pixelCoord + frame * 137.0);

    // Horizontal scan-line flicker: each row gets a random brightness
    // shift that changes at a slower rate than the pixel noise
    float rowFrame = floor(uTime * 1.0);
    float rowSeed = floor(fragCoord.y / 2.0);
    float rowFlicker = hash1(rowSeed + rowFrame * 91.0);
    // Bias toward mid-range so scan lines modulate, not dominate
    rowFlicker = mix(0.85, 1.15, rowFlicker);

    // Bright horizontal band that scrolls continuously down the screen
    float bandSpeed = 0.15; // full passes per second
    float bandCenter = mod(uTime * bandSpeed * uSize.y, uSize.y);
    float bandDist = abs(fragCoord.y - bandCenter);
    // Wrap-around: also check distance via the top/bottom edge
    bandDist = min(bandDist, uSize.y - bandDist);
    float band = smoothstep(30.0, 0.0, bandDist) * 0.35;

    // Combine: base noise * row flicker + bright band
    float intensity = n * rowFlicker + band;

    // Slight green tint like old CRT monitors
    vec3 color = vec3(intensity * 0.85, intensity * 0.9, intensity * 0.85);

    fragColor = vec4(color * uOpacity, uOpacity);
}
