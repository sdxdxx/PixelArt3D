Shader "URP/Snow_Composite"
{
    Properties
    {
        [Toggle(_EnableComposite)]_EnableComposite("Enable Composite",float) = 0.0
        _MainTex("Main Texture",2D) = "white"{}
        _HeightOffset("Height Offset",Range(0,0.5)) = 0.1
        
    }
    
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue" = "Geometry" 
            "RenderPipeline" = "UniversalPipeline"  
        }

        pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            
            Zwrite Off
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

            #pragma shader_feature _EnableComposite
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            TEXTURE2D(_SourceTex);//定义贴图
            SAMPLER(sampler_SourceTex);//定义采样器
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainTex_ST;
            float4 _SourceUV;
            float _HeightOffset;
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
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                half4 result = mainTex;
                
                #ifdef _EnableComposite
                half3 FinalRGB = half3(0,0,0);
                half4 sourceTex = SAMPLE_TEXTURE2D(_SourceTex,sampler_SourceTex,i.uv*_SourceUV.xy+_SourceUV.zw);
                float upRange = clamp(mainTex - _HeightOffset,0,1);
                float downRange = clamp(mainTex - _HeightOffset,-1,0);
                FinalRGB = sourceTex*upRange+downRange;
                result = half4(FinalRGB,mainTex.a);
                #endif
                
                return result;
            }
            
            ENDHLSL
        }
    }
}