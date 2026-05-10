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

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

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

            struct v2f {
                float4 vertex : POSITION;
                float3 worldPos : TEXCOORD0;

                half3 tspace0 : TEXCOORD1; // tangent.x, bitangent.x, normal.x
                half3 tspace1 : TEXCOORD2; // tangent.y, bitangent.y, normal.y
                half3 tspace2 : TEXCOORD3; // tangent.z, bitangent.z, normal.z

                float4 realPos : float4;
                float2 uv : TEXCOORD4;
                fixed4 colour : COLOR0;
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

            float noise2(float4 pos) {
                return (1 + cos(pos.y)) * 0.5 * (1 + cos(pos.x)) * 0.5;
            }

            float smoothstep(float edge0, float edge1, float x) {
                x = clamp((x-edge0) / (edge1 - edge0), 0, 1);

                return x * x * (3 - 2 * x);
            }

            v2f vert(appdata v, float3 normal : NORMAL, float4 tangent : TANGENT) {
                v2f o;
                float4 offset = {0, 1, 0, 0};
                o.colour = v.colour;
                o.vertex = UnityObjectToClipPos(v.vertex + _Vertical_Displacement * offset * o.colour.z);
                o.realPos = v.vertex;
                o.uv = v.uv;

                o.worldPos = mul(unity_ObjectToWorld, v.vertex);

                half3 wNormal = UnityObjectToWorldNormal(normal);
                half3 wTangent = UnityObjectToWorldDir(tangent.xyz);
                // compute bitangent from cross product of normal and tangent
                half tangentSign = tangent.w * unity_WorldTransformParams.w;
                half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
                // output the tangent space matrix
                o.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
                o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
                o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                //Textures
                float4 aAlb = tex2D(_A_Albedo, i.uv);
                float4 bAlb = tex2D(_B_Albedo, i.uv);
                half3 aNorm = UnpackNormal(tex2D(_A_Normal, i.uv));
                half3 bNorm = UnpackNormal(tex2D(_B_Normal, i.uv));
                float4 aMAOHS = tex2D(_A_MAOHS, i.uv);
                float4 bMAOHS = tex2D(_B_MAOHS, i.uv);

                //Smoothstep
                float smth = i.colour.x + noise2(i.realPos);
                float t = smoothstep(_Blend_Distance * i.colour.x, _Blend_Distance + noise2(i.realPos), smth);

                // transform normal from tangent to world space
                float4 worldNormal;
                worldNormal.x = dot(i.tspace0, (1-t) * aAlb + t * bAlb);
                worldNormal.y = dot(i.tspace1, (1-t) * aAlb + t * bAlb);
                worldNormal.z = dot(i.tspace2, (1-t) * aAlb + t * bAlb);

                //Colour
                float4 c = aAlb * (1 - t) + bAlb * t;

                //MAOHS
                

                //Snow
                float4 w = {1, 1, 1, 1};
                c += w * 0.5 * (smoothstep(0.35, 0.8, perlinNoise(i.realPos / _NoiseScale)));

                return c;
            }

            ENDHLSL
        }
    }
}
