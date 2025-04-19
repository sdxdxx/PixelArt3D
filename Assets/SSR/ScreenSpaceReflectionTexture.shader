Shader "URP/Test/ScreenSpaceReflectionTextureTest"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _ReflectionIntensity("Reflection Intensity",Range(0,1)) = 1.0
        _MainTex("MainTex",2D) = "white"{}
    }
    
    SubShader
    {
         Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
         
         pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            TEXTURE2D(_ScreenSpaceReflectionTexture);//定义贴图
            SAMPLER(sampler_ScreenSpaceReflectionTexture);//定义采样器
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainTex_ST;
            float _ReflectionIntensity;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
                float3 posWS : TEXCOORD3;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                float4 posCS = TransformObjectToHClip(v.vertex.xyz);
                o.pos = posCS;
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                o.screenPos = ComputeScreenPos(posCS);
                o.posWS = positionWS;
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                float2 screenPos = i.screenPos.xy/i.screenPos.w;
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                half4 ssrTex = SAMPLE_TEXTURE2D(_ScreenSpaceReflectionTexture,sampler_ScreenSpaceReflectionTexture,screenPos);
                half4 result = lerp(albedo,ssrTex,_ReflectionIntensity)*_BaseColor;
                return result;
            }
            
            ENDHLSL
        }

        //解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
    }
}