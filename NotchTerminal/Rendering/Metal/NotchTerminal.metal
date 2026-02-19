//
//  NotchTerminal.metal
//  NotchTerminal
//
//  Created by Marco Astorga González on 2026-02-17.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut notchVertex(uint vertexID [[vertex_id]]) {
    constexpr float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = positions[vertexID] * 0.5 + 0.5;
    return out;
}

fragment half4 notchFragment(VertexOut in [[stage_in]], constant float &time [[buffer(0)]]) {
    float2 uv = in.uv;
    
    // Smooth, slow time
    float t = time * 0.15;
    
    // Wave calculations
    float wave1 = sin((uv.x * 2.5) + t) * 0.5 + 0.5;
    float wave2 = sin((uv.y * 3.0) - (t * 0.9)) * 0.5 + 0.5;
    float wave3 = sin(((uv.x + uv.y) * 2.0) + (t * 1.4)) * 0.5 + 0.5;
    
    float aurora = (wave1 + wave2 + wave3) * 0.33;
    
    // Softer vignette
    float2 center = float2(0.5, 0.1); // Move center further down
    float d = distance(uv, center);
    float glow = smoothstep(1.2, 0.0, d); 
    
    // Vertical fade: forced pure black at the *very* top to blend with hardware notch, 
    // but allowing the glow to go higher up than before
    float verticalFade = smoothstep(0.98, 0.60, uv.y);
    glow *= verticalFade;
    
    // Brighter, more saturated color palette
    float3 color1 = float3(0.15, 0.02, 0.40); // Vibrant purple
    float3 color2 = float3(0.00, 0.20, 0.50); // Deep rich blue
    float3 color3 = float3(0.00, 0.40, 0.50); // Bright cyan
    
    // Mix colors
    float3 color = mix(color1, color2, aurora);
    color = mix(color, color3, wave3 * wave1);
    
    color += 0.04 * sin((uv.x * 12.0) + (uv.y * 12.0) + (time * 1.5));
    
    // Mask by glow
    color *= glow;

    // Stronger alpha signature so it stands out against the black
    float alpha = clamp(aurora * glow * 1.5, 0.0, 0.75);

    return half4(half3(color), half(alpha));
}

fragment half4 blackWindowFragment(VertexOut in [[stage_in]], constant float &time [[buffer(0)]]) {
    float2 uv = in.uv;
    float waveA = sin((uv.x * 8.0) + (time * 0.6));
    float waveB = sin((uv.y * 10.0) - (time * 0.5));
    float wave = (waveA + waveB) * 0.5;
    float vignette = smoothstep(1.0, 0.15, distance(uv, float2(0.5, 0.5)));

    float luma = 0.02 + (0.03 * vignette) + (0.01 * wave);
    return half4(half3(luma), half(0.85));
}

fragment half4 neonBorderFragment(VertexOut in [[stage_in]], constant float &time [[buffer(0)]]) {
    float2 uv = in.uv;
    
    // We want a traveling light effect around the perimeter.
    // Since UVs are 0 to 1, we can create a parameter 't' that goes 0 to 1 around the edge.
    // Instead of complex perimeter math, a radial or sweeping-angle approach is very "cyberpunk".
    
    // Convert UV to centered coordinates (-0.5 to 0.5)
    float2 centered = uv - 0.5;
    
    // Calculate angle from -PI to PI
    float angle = atan2(centered.y, centered.x);
    // Normalize to 0.0 - 1.0
    float angleNorm = (angle + M_PI_F) / (2.0 * M_PI_F);
    
    // Sweeping time
    float sweepTime = fract(time * 0.4);
    
    // Calculate distance between the sweep time and the current angle
    // Using fract to ensure it wraps around cleanly
    float diff = fract(angleNorm - sweepTime + 1.0);
    
    // Create a sharp head and a long tail for the light
    // We reverse the diff so the head is leading
    float tail = smoothstep(0.4, 0.0, diff); 
    
    // Add a secondary sweep going the opposite way or slightly offset for complexity
    float sweepTime2 = fract(-time * 0.25);
    float diff2 = fract(angleNorm - sweepTime2 + 1.0);
    float tail2 = smoothstep(0.3, 0.0, diff2);
    
    // Base color
    float3 headColor = float3(0.9, 0.2, 1.0); // Hot pink / Magenta
    float3 tailColor = float3(0.5, 0.1, 0.9); // Deep purple
    
    float3 color = mix(tailColor, headColor, tail);
    
    // Combine both sweeps
    float intensity = tail + (tail2 * 0.6);
    
    // Edge highlight (brightest right at the edges of the UV square)
    // Actually, in SwiftUI this will be masked by a stroke, so the whole view is only the stroke.
    // We can just output the sweeping color!
    
    // Add pulsing base glow
    float pulse = 0.3 + 0.2 * sin(time * 3.0);
    
    float3 finalColor = color * (intensity * 2.5 + pulse);
    
    return half4(half3(finalColor), half(1.0));
}
