Shader "URP/PostProcessing/PixelizeBackground"
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
            TEXTURE2D(_PixelizeBackgroundMask);
            
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            //float4 _CameraOpaqueTexture_ST;
            float4 _MainTex_ST;
            float _DownSampleValue;
            //----------变量声明结束-----------
            CBUFFER_END

            float CalculateIsNotRange(float3 originPoint, float2 screenPos, float2 size)
            {
                float2 bias[4] = {float2(0.0,-1.0),float2(0.0,1.0),float2(1.0,0.0),float2(-1.0,0.0)};
                UNITY_LOOP
                for (int i =0; i<4; i++)
                {
                    float4 worldOriginToScreenPos1= ComputeScreenPos(TransformWorldToHClip(originPoint));
                    float2 worldOriginToScreenPos2= worldOriginToScreenPos1.xy/worldOriginToScreenPos1.w;
                    float2 realSampleUV = (floor((screenPos-worldOriginToScreenPos2)*size)+0.5+bias[i])/size+worldOriginToScreenPos2;
                    float sampleResult = SAMPLE_TEXTURE2D(_PixelizeBackgroundMask, sampler_PointClamp, realSampleUV).r;
                    if (sampleResult<0.5)
                    {
                        return 1;
                    }
                }
                return 0;
            }
            
            float2 screenPosGetTest(float2 texcoord)
            {
                return texcoord;
            }
            half4 frag (Varyings input) : SV_TARGET
            {
                float downSampleValue = pow(2,_DownSampleValue);
            	float2 size = floor(_ScreenParams.xy/downSampleValue);
            	float3 originPoint = float3(0,0,0);
                float2 screenPos  = input.texcoord;
                float4 worldOriginToScreenPos1= ComputeScreenPos(TransformWorldToHClip(originPoint));
                float2 worldOriginToScreenPos2= worldOriginToScreenPos1.xy/worldOriginToScreenPos1.w;
                float2 realSampleUV = (floor((input.texcoord-worldOriginToScreenPos2)*size)+0.5)/size+worldOriginToScreenPos2;
                
                half4 albedo =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_PointClamp, realSampleUV);
                return albedo*_BaseColor;
            }
            
            ENDHLSL
        }
    }
}