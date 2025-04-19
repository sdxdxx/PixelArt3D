Shader "URP/PostProcessing/NormalLine"
{
    Properties
    {
        
    }
    
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline" = "UniversalPipeline"  
        }
        
        Cull Off 
        ZWrite Off
        ZTest Always
        
        pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
           #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            #include  "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            
            //----------贴图声明开始-----------
            //TEXTURE2D(_CameraNormalsTexture);
            //TEXTURE2D(_CameraDepthTexture);
            TEXTURE2D(_m_CameraNormalsTexture);
            TEXTURE2D(_m_CameraDepthTexture);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            //----------变量声明结束-----------
            CBUFFER_END
            
            half3 CalculateDepthNormalMapEdge(float2 screenPos, float size)
            {
                //float3 lum = float3(0.2125,0.7154,0.0721);//转化为luminance亮度值
                float3 lum = float3(0.33,0.33,0.33);//转化为自定义luminance亮度值
                float2 pixelPos = screenPos*_ScreenParams.xy;

                float2 bias[4] = {float2(0,size),float2(size,0),float2(-size,0),float2(0,-size)};
                float3 nDirWS_00 = SAMPLE_TEXTURE2D(_m_CameraNormalsTexture,sampler_PointClamp, screenPos);
                float rawDepth = SAMPLE_TEXTURE2D(_m_CameraDepthTexture,sampler_PointClamp, screenPos).r;
                float mc_00 = dot(nDirWS_00,lum);
                UNITY_LOOP
                for (int i = 0; i<4; i++)
                {
                    float2 samplePixelPos = pixelPos+bias[i];
                    float2 sampleScreenPos = samplePixelPos/_ScreenParams.xy;
                    float3 nDirWS_sample = SAMPLE_TEXTURE2D(_m_CameraNormalsTexture,sampler_PointClamp, sampleScreenPos);
                    float sampleRawDepth = SAMPLE_TEXTURE2D(_m_CameraDepthTexture,sampler_PointClamp, sampleScreenPos).r;
                    float mc_sample= dot(nDirWS_sample,lum);

                    if ((abs(rawDepth-sampleRawDepth)>0.001))
                    {
                        return half3(0,0,1);
                    }
                    
                    if (abs(mc_00-mc_sample)>0.05)
                    {
                        return half3(1,0,0);
                    }
                    
                }
                
                return 0;
            }
            
            half4 frag (Varyings i) : SV_TARGET
            {
                half4 albedo =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);
                half3 nomralLine = CalculateDepthNormalMapEdge(i.texcoord,1);
                float3 nDirWS_00 = SAMPLE_TEXTURE2D(_m_CameraNormalsTexture, sampler_PointClamp, i.texcoord).xyz;
                half4 result = half4(nomralLine,1.0);
                return result;
            }
            
            ENDHLSL
        }
    }
}