void GridEffect_float(
    float2 UV,
    float ScanSize,
    float LineAmount,
    float WorldScale,
    float3 Color,
    out float3 OutColor,
    out float Alpha
)
{
    float2 scaledUV = UV * WorldScale;
    float cellSize = ScanSize;
    float lineWidth = LineAmount * 0.08;
    float2 cellCoord = frac(scaledUV / cellSize);
    
    float glowX = 1.0 - smoothstep(0.0, lineWidth, cellCoord.x);
    float glowX2 = 1.0 - smoothstep(1.0 - lineWidth, 1.0, cellCoord.x);
    float glowY = 1.0 - smoothstep(0.0, lineWidth, cellCoord.y);
    float glowY2 = 1.0 - smoothstep(1.0 - lineWidth, 1.0, cellCoord.y);
    
    float borderGlow = max(max(glowX, glowX2), max(glowY, glowY2));
    
    float isIntersection = (glowX + glowX2) * (glowY + glowY2);
    borderGlow = saturate(borderGlow + isIntersection * 0.5);
    
    OutColor = Color * borderGlow;
    Alpha = borderGlow;
}