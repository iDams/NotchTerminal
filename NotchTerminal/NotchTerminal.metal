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
    float2 center = float2(0.5, 0.2);
    float d = distance(uv, center);

    float caustic = sin((uv.x * 32.0) + (time * 2.2)) * 0.5 + 0.5;
    caustic += sin((uv.y * 27.0) - (time * 1.8)) * 0.5 + 0.5;
    caustic *= 0.5;

    float glow = smoothstep(0.65, 0.10, d) * (0.35 + 0.65 * (0.5 + 0.5 * sin(time * 1.6)));
    float vignette = smoothstep(0.9, 0.2, d);
    float shimmer = 0.12 * sin((uv.x + uv.y + time) * 14.0);

    float3 base = float3(0.04, 0.06, 0.09);
    float3 cyan = float3(0.10, 0.46, 0.80) * (0.25 + 0.75 * caustic);
    float3 bloom = float3(0.14, 0.72, 1.0) * glow;
    float3 color = base + (cyan * vignette) + bloom + shimmer;

    return half4(half3(color), half(0.62));
}
