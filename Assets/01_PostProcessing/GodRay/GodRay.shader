Shader "URP/PostProcessing/GodRay"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
    }
    
    SubShader
    {
        Tags{
            "RenderPipeline" = "UniversalRenderPipeline"  
            "RenderType"="Opaque"
        }
        
        Cull Off 
        ZWrite Off
        ZTest Always
        
        HLSLINCLUDE
        #define MAIN_LIGHT_CALCULATE_SHADOWS  //定义阴影采样
        #define _MAIN_LIGHT_SHADOWS_CASCADE //启用级联阴影
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"  //阴影计算库
            #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include  "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            #define MAX_RAY_LENGTH 50
            #define random(seed) sin(seed * 641.5467987313875 + 1.943856175)
            
            //----------贴图声明开始-----------
            TEXTURE2D(_CameraOpaqueTexture);//获取到摄像机渲染画面的Texture
            SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float _Intensity;
            int _StepTime;
            float _RandomNumber;
            float _Scattering;
            //----------变量声明结束-----------
            CBUFFER_END

            float3 ReconstructWorldPositionFromDepth(float2 screenPos, float rawDepth)
            {
                float2 ndcPos = screenPos*2-1;//map[0,1] -> [-1,1]
            	float3 worldPos;
                if (unity_OrthoParams.w)
                {
					float depth01 = 1-rawDepth;
                	float3 viewPos = float3(unity_OrthoParams.xy * ndcPos.xy, 0);
                	viewPos.z = -lerp(_ProjectionParams.y, _ProjectionParams.z, depth01);
                	worldPos = mul(UNITY_MATRIX_I_V, float4(viewPos, 1)).xyz;
                }
                else
                {
	                float depth01 = Linear01Depth(rawDepth,_ZBufferParams);
                	float3 clipPos = float3(ndcPos.x,ndcPos.y,1)*_ProjectionParams.z;// z = far plane = mvp result w
	                float3 viewPos = mul(unity_CameraInvProjection,clipPos.xyzz).xyz * depth01;
	                worldPos = mul(UNITY_MATRIX_I_V,float4(viewPos,1)).xyz;
                }
                return worldPos;
            }

            float GetLightAttenuation(float3 position)
            {
                float4 shadowCoord= TransformWorldToShadowCoord(position); //把采样点的世界坐标转到阴影空间
                float intensity = MainLightRealtimeShadow(shadowCoord); //进行shadow map采样
                return intensity; //返回阴影值
            }

            //米氏散射简化版本
            float ComputeScattering(float lightDotView, float scattering)
            {
                float result = 1.0f - scattering * scattering;
                result /= (4.0f * PI * pow(1.0f + scattering * scattering - (2.0f * scattering) * lightDotView, 1.5f));
                return result;
            }
        ENDHLSL
        
         pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag_GodRayRange
            
            half4 frag_GodRayRange (Varyings i) : SV_TARGET
            {
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_CameraDepthTexture,i.texcoord).r;
                float3 posWS_frag = ReconstructWorldPositionFromDepth(i.texcoord, rawDepth);
                
                float3 startPos = _WorldSpaceCameraPos; //摄像机上的世界坐标
                float3 vDir = normalize(posWS_frag - startPos); //视线方向
                
                float3 lDir = _MainLightPosition.xyz; //视线方向
                float rayLength = length(posWS_frag - startPos); //视线长度
                rayLength = min(rayLength, MAX_RAY_LENGTH); //限制最大步进长度，MAX_RAY_LENGTH这里设置为20

                float3 final = startPos + vDir * rayLength; //定义步进结束点

                half3 sumIntensity = 0; //累计光强
                float2 step = 1.0 / _StepTime; //定义单次插值大小，_StepTime为步进次数
                step.y *= 0.4;
                float seed = random((_ScreenParams.y * i.texcoord.y + i.texcoord.x) * _ScreenParams.x + _RandomNumber);
                for(float i = step.x ; i < 1; i += step.x) //光线步进
                {
                    seed = random(seed);
                    float3 currentPosition = lerp(startPos, final, i + seed * step.y); //当前世界坐标
                    float atten = GetLightAttenuation(currentPosition);//阴影采样，intensity为强度因子
                    float3 light = atten*ComputeScattering(dot(lDir,vDir),_Scattering); 
                    sumIntensity += light; 
                }
                sumIntensity /= _StepTime;
                
                half3 finalRGB = sumIntensity;
                half4 result = half4(finalRGB,1.0);
                return result;
            }
            
            ENDHLSL
        }
        
         pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag_Blur
            
            CBUFFER_START(UnityPerMaterial)
            uniform float4 _BlitTexture_TexelSize;
            float _BlurRange;
            CBUFFER_END
            
             half4 frag_Blur(Varyings i) : SV_TARGET
            {
                half4 tex = SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp,i.texcoord);
                //四角像素
                //注意这个【_BlurRange】，这就是扩大卷积核范围的参数
                tex+=SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp,i.texcoord+float2(-1,-1)*_BlitTexture_TexelSize.xy*_BlurRange); 
                tex+=SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp,i.texcoord+float2(1,-1)*_BlitTexture_TexelSize.xy*_BlurRange);
                tex+=SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp,i.texcoord+float2(-1,1)*_BlitTexture_TexelSize.xy*_BlurRange);
                tex+=SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp,i.texcoord+float2(1,1)*_BlitTexture_TexelSize.xy*_BlurRange);
                return tex/5.0;
            }
            
            ENDHLSL
        }
        
          pass
        {
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment frag_Composite
            
            TEXTURE2D(_GodRayRangeTexture);
            SAMPLER(sampler_GodRayRangeTexture);
            
             half4 frag_Composite (Varyings i) : SV_TARGET
            {
                half4 albedo = SAMPLE_TEXTURE2D(_BlitTexture,sampler_PointClamp,i.texcoord);
                half3 godRayRange = SAMPLE_TEXTURE2D(_GodRayRangeTexture,sampler_GodRayRangeTexture,i.texcoord);
                float intensity = _Intensity*20;
                half3 finalRGB = godRayRange*albedo*intensity*_BaseColor+albedo;
                half4 result = half4(finalRGB,1.0);
                return result;
            }
            
            ENDHLSL
        }

        
      
    }
}