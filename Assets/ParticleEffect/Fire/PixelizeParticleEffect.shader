Shader "URP/PixelizeParticleEffect"
{
    Properties
    {
        [IntRange]_DownSampleValue("Down Sample Value",Range(0,7)) = 0
        [HDR]_BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _AlphaClip("Alpha Clip",Range(0,1)) = 0
        _MainTex("MainTex",2D) = "white"{}
    }
    
    SubShader
    {
         Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
        }
         
         pass
        {
            Blend One One
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainTex_ST;
            float _DownSampleValue;
            float _AlphaClip;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float4 color : TEXCOORD2;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                o.color = v.color;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                
                float downSampleValue = pow(2,10-_DownSampleValue);
                float2 centerUV = float2(0.5,0.5)/downSampleValue;
                float2 pixelizeUV = floor(i.uv*downSampleValue-centerUV)/downSampleValue+centerUV;
                float2 mainTexUV = pixelizeUV *_MainTex_ST.xy+_MainTex_ST.zw;
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,mainTexUV);
                clip(albedo.a-_AlphaClip);
                float4 result = float4(albedo.rgb*i.color.rgb*_BaseColor.rgb,albedo.a);
                return result;
            }
            
            ENDHLSL
        }
    }
}