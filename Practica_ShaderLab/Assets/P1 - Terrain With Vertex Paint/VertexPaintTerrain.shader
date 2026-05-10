Shader "Custom/VertexPaintTerrain"
{
    Properties
    {
        _Uv_Scales("Uv Scales", Float) = 1
        _A_Albedo("A - Albedo", 2D) = "white" {}
        _B_Albedo("B - Albedo", 2D) = "white" {}
        _A_Normal("A - Normal", 2D) = "bump" {}
        _B_Normal("B - Normal", 2D) = "bump" {}
        _A_MAOHS("A - MAOHS", 2D) = "white" {}
        _B_MAOHS("B - MAOHS", 2D) = "white" {}
        _NoiseScale("NoiseScale", Float) = 10
        _Blend_Distance("Blend Distance", Float) = 0.1
        _Snow_Metallic("Snow Metallic", Float) = 0
        _Snow_Smoothness("Snow Smoothness", Float) = 0.02
        _Snow_AO("Snow AO", Float) = 0
        _Vertical_Displacement("Vertical Displacement", Float) = 50
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        CGPROGRAM
        #pragma surface surf Standard vertex:vert
        #pragma target 3.0

        float _NoiseScale;
        float _Blend_Distance;
        float _Uv_Scales;
        float _Snow_Metallic;
        float _Snow_Smoothness;
        float _Snow_AO;
        float _Vertical_Displacement;

        sampler2D _A_Albedo;
        sampler2D _B_Albedo;

        sampler2D _A_Normal;
        sampler2D _B_Normal;

        sampler2D _A_MAOHS;
        sampler2D _B_MAOHS;

        struct appdata {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
            fixed4 colour : COLOR0;
            };

        struct Input {
            float3 localNormal;
            float4 localCoord : TEXCOORD1;
            float3 worldPos : TEXCOORD2;

            fixed4 colour : COLOR0;
            INTERNAL_DATA
            };

        inline float easeIn(float interpolator){
            return interpolator * interpolator;
        }

        float easeOut(float interpolator){
            return 1 - easeIn(1 - interpolator);
        }

        float easeInOut(float interpolator){
            float easeInValue = easeIn(interpolator);
            float easeOutValue = easeOut(interpolator);
            return lerp(easeInValue, easeOutValue, interpolator);
        }

        float rand3dTo1d(float3 value, float3 dotDir = float3(12.9898, 78.233, 37.719)){
            //make value smaller to avoid artefacts
            float3 smallValue = sin(value);
            //get scalar value from 3d vector
            float random = dot(smallValue, dotDir);
            //make value more random by making it bigger and then taking the factional part
            random = frac(sin(random) * 143758.5453);
            return random;
        }

        float3 rand3dTo3d(float3 value){
            return float3(
                rand3dTo1d(value, float3(12.989, 78.233, 37.719)),
                rand3dTo1d(value, float3(39.346, 11.135, 83.155)),
                rand3dTo1d(value, float3(73.156, 52.235, 09.151))
            );
        }

        float perlinNoise(float3 value){
            float3 fraction = frac(value);

            float interpolatorX = easeInOut(fraction.x);
            float interpolatorY = easeInOut(fraction.y);
            float interpolatorZ = easeInOut(fraction.z);

            float cellNoiseZ[2];
            [unroll]
            for(int z=0;z<=1;z++){
                float cellNoiseY[2];
                [unroll]
                for(int y=0;y<=1;y++){
                    float cellNoiseX[2];
                    [unroll]
                    for(int x=0;x<=1;x++){
                        float3 cell = floor(value) + float3(x, y, z);
                        float3 cellDirection = rand3dTo3d(cell) * 2 - 1;
                        float3 compareVector = fraction - float3(x, y, z);
                        cellNoiseX[x] = dot(cellDirection, compareVector);
                    }
                    cellNoiseY[y] = lerp(cellNoiseX[0], cellNoiseX[1], interpolatorX);
                }
                cellNoiseZ[z] = lerp(cellNoiseY[0], cellNoiseY[1], interpolatorY);
            }
            float noise = lerp(cellNoiseZ[0], cellNoiseZ[1], interpolatorZ);
            return noise + 0.5;
        }

        float smoothstep(float edge0, float edge1, float x) {
            x = clamp((x-edge0) / (edge1 - edge0), 0, 1);

            return x * x * (3 - 2 * x);
        }

        void vert(inout appdata_full v, out Input data) {
            float4 offset = {0, 1, 0, 0};
            data.colour = v.color;
            data.localCoord = v.vertex;
            v.vertex += _Vertical_Displacement * offset * data.colour.z;

            data.worldPos = mul(unity_ObjectToWorld, v.vertex);
            data.localNormal = v.normal.xyz;
        }

        void surf(Input IN, inout SurfaceOutputStandard o) {
            //Textures
            float4 aAlb = tex2D(_A_Albedo, IN.localCoord.xz);
            float4 bAlb = tex2D(_B_Albedo, IN.localCoord.xz);
            half4 aNorm = tex2D(_A_Normal, IN.localNormal.xz);
            half4 bNorm = tex2D(_B_Normal, IN.localNormal.xz);
            float4 aMAOHS = tex2D(_A_MAOHS, IN.localCoord.xz);
            float4 bMAOHS = tex2D(_B_MAOHS, IN.localCoord.xz);

            //Smoothstep
            float smth = IN.colour.x;
            float t = smoothstep((1 - _Blend_Distance) * 0.5, (1 + _Blend_Distance) * 0.5, smth);

            //Colour
            float4 c = lerp(aAlb, bAlb, t);

            //Normal
            half4 n = lerp(aNorm, bNorm, t);

            //MAOHS
            half4 maohs = lerp(aMAOHS, bMAOHS, t);

            //Snow
            float4 w = {1, 1, 1, 1};
            float snow = 0.5 * smoothstep((1 - _Blend_Distance) * 0.5, (1 + _Blend_Distance) * 0.5, perlinNoise(IN.worldPos / _NoiseScale));

            o.Albedo = lerp(c.rgb, w.rgb, snow);
            o.Alpha = lerp(c.a, w.a, snow);
            o.Metallic = lerp(maohs.x, _Snow_Metallic, snow);
            o.Occlusion = lerp(maohs.y, _Snow_AO, snow);
            o.Smoothness = lerp(maohs.w, _Snow_Smoothness, snow);
        }

        ENDCG
    }
}
