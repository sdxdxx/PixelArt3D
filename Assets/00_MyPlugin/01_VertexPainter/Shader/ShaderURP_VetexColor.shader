Shader "URP/ShaderURP_VertexColor"
{
    Properties
    {
        
    }
    
    SubShader
    {
        Tags{
            "RenderPipeline" = "UniversalRenderPipeline"  
            "RenderType"="Opaque"
        }

        UsePass "Universal Render Pipeline/Unlit/DepthOnly"//解决深度引动模式Depth Priming Mode问题
        
        pass
        {
            HLSLPROGRAM

            #pragma vertex vert_Grass
            #pragma fragment frag

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInputGrass
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct vertexOutputGrass
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float4 color :  TEXCOORD2;
            };

            vertexOutputGrass vert_Grass (vertexInputGrass v)
            {
                vertexOutputGrass o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                o.color = v.color;
                return o;
            }

            half4 frag (vertexOutputGrass i) : SV_TARGET
            {
                return i.color;
            }
            
            ENDHLSL
        }
    }
}