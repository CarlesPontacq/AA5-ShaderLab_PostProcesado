void WorldGridEffect_float(
    float worldPosition,
    float objectPosition,
    float worldScale,
    float lineAmount,
    float lineColor,
    float scanIntensity,
    out float gridIntensity,
    out float finalColor
)
{
    float2 scaledPos = worldPosition / worldScale;
    
    float cellSize = 1.0;
    
    float2 gridCoords = frac(scaledPos.xy);
    
    float2 distToLine = min(gridCoords, 1.0 - gridCoords);
    
    float lineWidth = 0.05;
    
    float intensityX = 1.0 - smoothstep(0.0, lineWidth, distToLine.x);
    float intensityY = 1.0 - smoothstep(0.0, lineWidth, distToLine.y);
    
    float rawGridIntensity = max(intensityX, intensityY);
    
    float isCorner = step(0.95, max(gridCoords.x, gridCoords.y)) *
                     step(0.95, max(1.0 - gridCoords.x, 1.0 - gridCoords.y));
    
    float finalGridIntensity = rawGridIntensity * scanIntensity;
    
    float gridBlend = smoothstep(0.0, lineAmount, finalGridIntensity);
    
    float gridColor = lineColor * gridBlend;
    
    gridIntensity = finalGridIntensity;
    finalColor = gridColor;
}