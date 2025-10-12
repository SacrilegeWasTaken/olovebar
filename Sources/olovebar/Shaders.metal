#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {
    float4 positions[6] = {
        float4(-1.0, -1.0, 0, 1),
        float4( 1.0, -1.0, 0, 1),
        float4(-1.0,  1.0, 0, 1),
        float4(-1.0,  1.0, 0, 1),
        float4( 1.0, -1.0, 0, 1),
        float4( 1.0,  1.0, 0, 1),
    };
    VertexOut outVertex;
    outVertex.position = positions[vertexID];
    return outVertex;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant float4 &color [[buffer(0)]]) {
    return color;
}
