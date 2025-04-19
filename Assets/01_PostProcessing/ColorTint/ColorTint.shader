Shader "URP/PostProcessing/ColorTint"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
    }
    
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline" = "UniversalPipeline"  
        }
        
        
        
        Pass
        {
            Cull Off 
            ZWrite Off
            
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            #include  "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_CameraOpaqueTexture);//获取到摄像机渲染画面的Texture
            SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_m_CameraNormalsTexture);
            TEXTURE2D(_m_CameraDepthTexture);
            TEXTURE2D(_CameraDepthTexture);
            
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            //float4 _CameraOpaqueTexture_ST;
            float4 _MainTex_ST;
            //----------变量声明结束-----------
            CBUFFER_END

             float3 ReconstructViewPositionFromDepth(float2 screenPos, float rawDepth)
            {
                float2 ndcPos = screenPos*2-1;//map[0,1] -> [-1,1]
            	float3 viewPos;
                if (unity_OrthoParams.w)
                {
					float depth01 = 1-rawDepth;
                	viewPos = float3(unity_OrthoParams.xy * ndcPos.xy, 0);
                	viewPos.z = -lerp(_ProjectionParams.y, _ProjectionParams.z, depth01);
                }
                else
                {
	                float depth01 = Linear01Depth(rawDepth,_ZBufferParams);
                	float3 clipPos = float3(ndcPos.x,ndcPos.y,1)*_ProjectionParams.z;// z = far plane = mvp result w
	                viewPos = mul(unity_CameraInvProjection,clipPos.xyzz).xyz * depth01;
                }
            	
                return viewPos;
            }
            
            half4 frag (Varyings i) : SV_TARGET
            {
                half4 albedo =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord)*_BaseColor;
                half4 result = half4(albedo.rgb,1.0);
                return result;
            }
            
            ENDHLSL
        }
    }
}