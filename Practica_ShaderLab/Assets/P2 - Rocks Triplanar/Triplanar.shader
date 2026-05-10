// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/Triplanar"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Normal ("Normal", 2D) = "bump" {}
        _MAOHS ("MAOHS", 2D) = "white" {}
        _Tiling ("Tiling", Float) = 1.0
        [MaterialToggle] _UseLocalSpace("UseLocalSpace", Float) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

            CGPROGRAM
            #pragma surface surf Standard vertex:vert
            #pragma target 3.0

            sampler2D _MainTex;
            sampler2D _Normal;
            sampler2D _MAOHS;
            half _Tiling;
            half _UseLocalSpace;

            struct Input
            {
                float3 localCoord;
                float3 localNormal;
            };

            void vert(inout appdata_full v, out Input data)
            {
                UNITY_INITIALIZE_OUTPUT(Input, data);
                if(_UseLocalSpace == 0)
                    data.localCoord = mul(unity_ObjectToWorld, v.vertex);
                else
                    data.localCoord = v.vertex;
                data.localNormal = v.normal.xyz;
            }

            void surf(Input IN, inout SurfaceOutputStandard o)
            {
                // Blending factor of triplanar mapping
                float3 bf = normalize(abs(IN.localNormal));
                bf /= dot(bf, (float3)1);

                // Triplanar mapping
                float2 tx = IN.localCoord.yz * _Tiling;
                float2 ty = IN.localCoord.zx * _Tiling;
                float2 tz = IN.localCoord.xy * _Tiling;

                // Base color
                half4 cx = tex2D(_MainTex, tx) * bf.x;
                half4 cy = tex2D(_MainTex, ty) * bf.y;
                half4 cz = tex2D(_MainTex, tz) * bf.z;
                half4 color = (cx + cy + cz);
                o.Albedo = color.rgb;
                o.Alpha = color.a;

                // Normal map
                half4 nx = tex2D(_Normal, tx) * bf.x;
                half4 ny = tex2D(_Normal, ty) * bf.y;
                half4 nz = tex2D(_Normal, tz) * bf.z;
                o.Normal = UnpackScaleNormal(nx + ny + nz, 1);

                // MAOHS map
                half4 maohsx = tex2D(_MAOHS, tx) * bf.x;
                half4 maohsy = tex2D(_MAOHS, ty) * bf.y;
                half4 maohsz = tex2D(_MAOHS, tz) * bf.z;
                o.Metallic = maohsx.x + maohsy.x + maohsz.x;
                o.Occlusion = maohsx.y + maohsy.y + maohsz.y;
                o.Smoothness = maohsx.w + maohsy.w + maohsz.w;
            }
            ENDCG
    }
}
