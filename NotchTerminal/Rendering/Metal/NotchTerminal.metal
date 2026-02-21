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

struct AuroraColors {
    float3 color1;
    float3 color2;
    float3 color3;
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

fragment half4 notchFragment(VertexOut in [[stage_in]], 
                             constant float &time [[buffer(0)]],
                             constant AuroraColors &colors [[buffer(1)]]) {
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
    
    // Mix colors dynamically from buffer
    float3 color = mix(colors.color1, colors.color2, aurora);
    color = mix(color, colors.color3, wave3 * wave1);
    
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

fragment half4 neonBorderFragment(VertexOut in [[stage_in]], 
                                  constant float &time [[buffer(0)]],
                                  constant AuroraColors &colors [[buffer(1)]]) {
    float2 uv = in.uv;
    
    // Smooth, elegant sweeping flow
    float t = time * 0.8;
    
    float flowMix = 0.5 + 0.5 * sin(uv.x * 3.1415 + t);
    float flowMixY = 0.5 + 0.5 * cos(uv.y * 3.1415 - t * 0.5);
    float colorMix = mix(flowMix, flowMixY, 0.5);
    
    float3 baseColor = mix(colors.color1, colors.color2, saturate(colorMix));
    
    float pulse = 0.8 + 0.2 * sin(time * 1.5);
    float intensityFlow = 0.8 + 0.2 * sin((uv.x * 4.0) - (time * 2.0));
    
    float3 finalColor = baseColor * pulse * intensityFlow * 1.5;
    
    return half4(half3(finalColor), half(1.0));
}

#include <SwiftUI/SwiftUI_Metal.h>

[[ stitchable ]] half4 crtFilter(float2 position, half4 color, float2 size, float time) {
    float2 uv = position / size;
    
    // 1. Curvature (barrel distortion) just for the black borders
    float2 crt_uv = uv * 2.0 - 1.0;
    float2 offset = crt_uv.yx / 8.0; 
    float2 curved_uv = crt_uv + crt_uv * offset * offset;
    
    // Solid black outside the tube
    if (abs(curved_uv.x) > 1.0 || abs(curved_uv.y) > 1.0) {
        return half4(0.0, 0.0, 0.0, 1.0); 
    }
    
    // 2. Scanlines
    float scanline = sin(uv.y * size.y * 1.5) * 0.04;
    
    // 3. Vignette (darken edges)
    float vignette = distance(uv, float2(0.5, 0.5));
    vignette = smoothstep(1.0, 0.2, vignette);
    
    // 4. Static noise
    float noise = fract(sin(dot(uv, float2(12.9898, 78.233)) + time * 10.0) * 43758.5453) * 0.03;
    
    // Total darkening alpha
    float darkness = (1.0 - vignette) + scanline + noise;
    
    return half4(0.0, 0.0, 0.0, clamp(half(darkness), 0.0h, 1.0h));
}
