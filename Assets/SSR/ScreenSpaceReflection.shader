Shader "URP/PostProcessing/ScreenSpaceReflection"
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
        
        Cull Off 
        ZWrite Off
        ZTest Always
        
        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            #include  "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
            
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

            float GetLinearEyeDepth(float rawDepth)
            {
                float linearEyeDepth ;
                if (unity_OrthoParams.w>0.5)
                {
                    float depth01 = 1-rawDepth;
                    linearEyeDepth = lerp(_ProjectionParams.y, _ProjectionParams.z, depth01);
                }
                else
                {
                   linearEyeDepth = LinearEyeDepth(rawDepth,_ZBufferParams);
                }
                return linearEyeDepth;
            }

            float2 GetScreenPos(float3 posVS)
            {
                float2 screenPos;
                if (unity_OrthoParams.w>0.5)
                {
                    float2 ndcPos = posVS.xy/unity_OrthoParams.xy;
                    screenPos = ndcPos*0.5+0.5;
                }
                else
                {
                    float3 clipPos = mul((float3x3)unity_CameraProjection, posVS);
                    screenPos = (clipPos.xy / clipPos.z) * 0.5 + 0.5;
                }
                return screenPos;
            }
        ENDHLSL
        
        //SSR Pass
        pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag
            #pragma shader_feature SIMPLE_VS //基础视角空间SSR
            #pragma shader_feature BINARY_SEARCH_VS //视空间二分搜索SSR
            #pragma shader_feature BINARY_SEARCH_JITTER_VS //视空间二分搜索SSR+JitterDither
            #pragma shader_feature EFFICIENT_SS //逐像素屏幕空间SSR
            #pragma shader_feature EFFICIENT_JITTER_SS //逐像素屏幕空间SSR+JitterDither
            #pragma shader_feature HIZ_VS //HIZ算法SSR
            
            
            //----------贴图声明开始-----------
            //TEXTURE2D(_CameraDepthTexture);
            TEXTURE2D(_m_CameraDepthTexture);
            //TEXTURE2D(_CameraNormalsTexture);
            TEXTURE2D(_m_CameraNormalsTexture);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float4 _MainTex_ST;

            //Simple
            float _StepLength;
            float _Thickness;

            //BinarySearch
            float _MaxStepLength;
            float _MinDistance;

            //Efficient
            float _MaxReflectLength;
            int _DeltaPixel;

            //Jitter Dither
            float _DitherIntensity;
            
            //----------变量声明结束-----------
            CBUFFER_END
            

            //二分搜索SSR + Jitter Dither
            static half dither[16] =
            {
                0.0, 0.5, 0.125, 0.625,
                0.75, 0.25, 0.875, 0.375,
                0.187, 0.687, 0.0625, 0.562,
                0.937, 0.437, 0.812, 0.312
            };
            
            half4 ScreenSpaceReflection_BinarySearch_JitterDither(Varyings i)
            {
                float rawDepth = SAMPLE_TEXTURE2D(_m_CameraDepthTexture,sampler_PointClamp, i.texcoord).r;
                //float linear01Depth = Linear01Depth(rawDepth,_ZBufferParams);
                float3 posVS = ReconstructViewPositionFromDepth(i.texcoord,rawDepth);
                float3 nDirWS = SAMPLE_TEXTURE2D(_m_CameraNormalsTexture,sampler_PointClamp,i.texcoord).xyz;
                float3 nDirVS = TransformWorldToViewNormal(nDirWS);
                                
                float3 sampleNormalizeVector;
                if (unity_OrthoParams.w>0)
                {
                    float3 rayWS = normalize(-UNITY_MATRIX_V[2].xyz);//防止Raymarching视角变形
                    float3 rayVS = TransformWorldToViewDir(rayWS);
                    sampleNormalizeVector = normalize(reflect(rayVS,nDirVS));
                }
                else
                {
                    sampleNormalizeVector = normalize(reflect(normalize(posVS),nDirVS));
                }
                
                float3 samplePosVS = posVS;
                float3 lastSamplePosVS = posVS;
                float stepLength = _MaxStepLength;
                
                int maxStep = 64;
                float2 sampleScreenPos = i.texcoord.xy;
                float2 pixelPos = round(i.texcoord.xy*_ScreenParams.xy);
                int step;
                half4 result = half4(1.0,1.0,1.0,1.0);
                
                UNITY_LOOP
                for (step = 1; step<=maxStep; step++)
                {
                    lastSamplePosVS = samplePosVS;
                    samplePosVS += sampleNormalizeVector*stepLength;
                    float2 ditherUV = fmod(pixelPos, 4);  
                    float jitter = dither[ditherUV.x * 4 + ditherUV.y]*_DitherIntensity*2.5f;
                    float3 realSamplePosVS = samplePosVS + jitter*sampleNormalizeVector*stepLength;
                    sampleScreenPos = GetScreenPos(realSamplePosVS);

                    if (sampleScreenPos.x>1 || sampleScreenPos.y >1)
                    {
                        //超出屏幕直接剔除
                        break;
                    }
                    
                    float sampleRawDepth = SAMPLE_TEXTURE2D(_m_CameraDepthTexture,sampler_PointClamp,sampleScreenPos).r;
                    float sampleLinearEyeDepth = GetLinearEyeDepth(sampleRawDepth);

                    //判定成功
                    if ((sampleLinearEyeDepth<-realSamplePosVS.z))
                    {
                        float distance = (-realSamplePosVS.z)-sampleLinearEyeDepth;
                        
                        if (distance<_MinDistance)
                        {
                            //找到
                            float2 reflectScreenPos = sampleScreenPos;
                            half3 albedo_reflect =  SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, reflectScreenPos);
                            result.rgb = albedo_reflect*_BaseColor;
                            return result;
                        }
                        else
                        {
                            //未找到
                            stepLength *= 0.5f;
                            samplePosVS = lastSamplePosVS;
                        }
                    }
                }
                
                
                float3 vDir;
                if (unity_OrthoParams.w>0.5)
                {
                    float2 orthoSize = unity_OrthoParams.xy;
                    float2 ndcPos = i.texcoord * 2.0 - 1.0;
                    float3 viewPos = float3(unity_OrthoParams.xy * ndcPos.xy, 0);
                    viewPos.z =-1;
                    viewPos.y+=1.1;
                    posVS = -viewPos;
                    vDir = TransformViewToWorld(posVS);
                }
                else
                {
                    float3 posWS = mul(UNITY_MATRIX_I_V,float4(posVS,1)).xyz;
                    vDir = normalize(_WorldSpaceCameraPos.xyz - posWS.xyz);
                }
                
                float3 reflectVec = reflect(-vDir, nDirWS);
				half4 rgbm =  SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0,samplerunity_SpecCube0, reflectVec, 0);
                float3 skyboxReflectColor = DecodeHDREnvironment(rgbm, unity_SpecCube0_HDR);
                result = half4(skyboxReflectColor,1.0);
                return result;
            }
            
            
            half4 frag (Varyings i) : SV_TARGET
            {
                half4 result = ScreenSpaceReflection_BinarySearch_JitterDither(i);
                return result;
            }
            
            ENDHLSL
        }
        
    }
}