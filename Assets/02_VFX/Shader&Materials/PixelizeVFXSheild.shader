Shader "URP/VFX/PixelizeVFXSheild"
{
    Properties
    {
    	[Header(Mode)]
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc("Blend Src Factor", float) = 5   //SrcAlpha
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst("Blend Dst Factor", float) = 10  //OneMinusSrcAlpha
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", float) = 2 //Back
    	
    	[Space(20)]
    	
       [Header(Tint)]
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainTex("MainTex",2D) = "white"{}
    	
    	[Space(20)]
    	
    	[Header(Fresnel)]
    	_FresnelPow("Fresnel Power",Range(1,70)) = 1
    	_FresnelIntensity("Fresnel Intensity",Range(0,5)) = 1
    	
    	[Space(20)]
    	[Header(Dissolve)]
    	_DissolveEdgeColor("Dissolve Edge Color",Color) = (1.0,1.0,1.0,1.0)
    	_DissolveNoiseMap("Dissolve Noise Map",2D) = "black"{}
    	_DissolveEdge("Dissolve Edge",Range(0,0.2)) = 0
    	_DissolveRange("Dissolve Range",Range(0,1)) = 0
    	
    	[Space(20)]
       
    	[Header(Down Sample)]
    	[IntRange]_DownSampleValue("Down Sample Value",Range(0,5)) = 0
    	[Toggle(_EnableObjectCenterPoint)]_EnableObjectCenterPoint("Enable Object Center Point",float) = 0.0
    	[IntRange]_ID("Mask ID", Range(0,254)) = 100
    }
    
    SubShader
    {
         Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        	"Queue" = "Transparent+100"
        }
         
         HLSLINCLUDE
         #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

         #pragma shader_feature _EnableObjectCenterPoint
         
         CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
			half4 _DissolveEdgeColor;
	        float _FresnelPow;
	        float _FresnelIntensity;
			float _DissolveRange;
			float _DissolveEdge;
            float4 _MainTex_ST;
            float4 _DissolveNoiseMap_ST;
			int _DownSampleValue;
			int _ID;
            //----------变量声明结束-----------
            CBUFFER_END

         TEXTURE2D(_DissolveNoiseMap);
         TEXTURE2D(_m_CameraDepthTexture);
         TEXTURE2D(_PixelizeVFXMask);
         TEXTURE2D(_PixelizeVFXCartoonTex);
         
        //Remap
        float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
         {
           return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
         }

         float CalculateIsNotRange(float3 originPoint, float2 screenPos, float2 size, float rawDepth)
            {
                float2 bias[4] = {float2(0.0,-1.0),float2(0.0,1.0),float2(1.0,0.0),float2(-1.0,0.0)};
             	float4 pixelizeObjectParam = SAMPLE_TEXTURE2D(_PixelizeVFXMask,sampler_PointClamp,screenPos);
             	float pixelizeObjectParamMask = step(pixelizeObjectParam.a,1-0.000001f);
                UNITY_LOOP
                for (int i =0; i<4; i++)
                {
                    float4 worldOriginToScreenPos1= ComputeScreenPos(TransformWorldToHClip(originPoint));
                    float2 worldOriginToScreenPos2= worldOriginToScreenPos1.xy/worldOriginToScreenPos1.w;
                    float2 realSampleUV = (floor((screenPos-worldOriginToScreenPos2)*size)+0.5+bias[i])/size+worldOriginToScreenPos2;
                	float realRawDepth = SAMPLE_TEXTURE2D(_m_CameraDepthTexture,sampler_PointClamp,realSampleUV);
                	float4 realPixelizeObjectParam = SAMPLE_TEXTURE2D(_PixelizeVFXMask,sampler_PointClamp,realSampleUV);
                	float realRawMask = step(realPixelizeObjectParam.a*255,_ID+0.5f)*step(_ID-0.5f,realPixelizeObjectParam.a*255);
                	float rawMask = step(realPixelizeObjectParam.a,1-0.000001f);
                	float temp = step(rawDepth,realPixelizeObjectParam.r)*(rawMask - realRawMask)*pixelizeObjectParamMask;
                	float realMask = max(temp,realRawMask);
                	
                    if (realMask<0.1)
                    {
                        return 1;
                    }
                }
                return 0;
            }

         float CalculateInlineRange(float3 originPoint, float2 screenPos, float2 size, float rawDepth, float inlinePixel)
        {
	        float2 bias[4] = {float2(0.0,-inlinePixel),float2(0.0,inlinePixel),float2(inlinePixel,0.0),float2(-inlinePixel,0.0)};
            float4 pixelizeObjectParam = SAMPLE_TEXTURE2D(_PixelizeVFXMask,sampler_PointClamp,screenPos);
            float pixelizeObjectParamMask = step(pixelizeObjectParam.a,1-0.000001f);
	        float4 worldOriginToScreenPos1= ComputeScreenPos(TransformWorldToHClip(originPoint));
	        float2 worldOriginToScreenPos2= worldOriginToScreenPos1.xy/worldOriginToScreenPos1.w;
            UNITY_LOOP
            for (int i =0; i<4; i++)
            {
                float2 realSampleUV = (floor((screenPos-worldOriginToScreenPos2)*size)+0.5+bias[i])/size+worldOriginToScreenPos2;
                float realRawDepth = SAMPLE_TEXTURE2D(_m_CameraDepthTexture,sampler_PointClamp,realSampleUV);
                float4 realPixelizeObjectParam = SAMPLE_TEXTURE2D(_PixelizeVFXMask,sampler_PointClamp,realSampleUV);
                float realRawMask = step(realPixelizeObjectParam.a*255,_ID+0.5f)*step(_ID-0.5f,realPixelizeObjectParam.a*255);
                float rawMask = step(realPixelizeObjectParam.a,1-0.000001f);
                float temp = step(rawDepth,realPixelizeObjectParam.r)*(rawMask - realRawMask)*pixelizeObjectParamMask;
                float realMask = max(temp,realRawMask);
                
                if (realMask<0.1)
                {
                    return 1;
                }
            }
        	return 0;
        }
         
         ENDHLSL
         
        //Cartoon Rendering
        Pass
        {
            Tags { "LightMode" = "PixelizeVFXCartoonPass" }
            
            
            //Blend SrcAlpha OneMinusSrcAlpha
            Cull Back
            
            ZWrite On
            
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            // 主光源和阴影
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            // 多光源和阴影
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            //----------贴图声明结束-----------
            
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
                float3 posWS : TEXCOORD2;
            	float4 screenPos : TEXCOORD3;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
                o.pos = posCS;
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                o.posWS = positionWS;
            	o.screenPos = ComputeScreenPos(posCS);
                return o;
            }
            
            half4 frag (vertexOutput i) : SV_TARGET
            {
            	float3 cameraPosWS;
                if (unity_OrthoParams.w)
                {
                    float2 ndcPos = i.screenPos.xy/i.screenPos.w*2-1;//map[0,1] -> [-1,1]
                    float3 viewPos = float3(unity_OrthoParams.xy * ndcPos.xy, 0);
                    cameraPosWS = mul(UNITY_MATRIX_I_V, float4(viewPos, 1)).xyz;
                }
                else
                {
                    cameraPosWS = _WorldSpaceCameraPos;
                }
            	
                float2 screenPos = i.screenPos.xy/i.screenPos.w;
                float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
                Light mainLight = GetMainLight(shadowCoord);
                float3 nDir= i.nDirWS;
                float3 lDir = mainLight.direction;
                float3 vDir = normalize(cameraPosWS - i.posWS.xyz);
                float3 hDir = normalize(lDir+vDir);
            	
                float nDotv = dot(nDir,vDir);
            	
            	float fresnel = saturate(pow(max(0,1-nDotv),_FresnelPow));
            	
            	half3 finalRGB = fresnel;
            	half finalA = 1-fresnel;
                return float4(finalRGB,finalA);
            }
            
            ENDHLSL
        }
        
       //PixelizeObjectMask
        Pass
        {
	        Name "PixelizeVFXMaskPass"

        	Tags{"LightMode" = "PixelizeVFXMaskPass"}
	        
            HLSLPROGRAM
            
            #pragma vertex vert_PixelizeMask
            #pragma fragment frag_PixelizeMask
            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
             struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            	float3 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirOS : TEXCOORD1;
                float3 posOS : TEXCOORD2;
            	float4 screenPos : TEXCOORD3;
            };
            
            SAMPLER(sampler_PixelizeMask);
            
             vertexOutput vert_PixelizeMask (vertexInput v)
            {
                vertexOutput o;
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
            	o.screenPos = ComputeScreenPos(posCS);
                o.pos = posCS;
                o.nDirOS = v.color;
                o.uv = v.uv;
                o.posOS = v.vertex.xyz;
                return o;
            }

            float4 frag_PixelizeMask (vertexOutput i) : SV_TARGET
            {
            	float2 screenPos = i.screenPos.xy/i.screenPos.w;
            	float3 posWS = TransformObjectToWorld(i.posOS).xyz;
            	
            	float rawDepth;
				rawDepth = TransformObjectToHClip(i.posOS).z;
            	float id = _ID;
            	id = id/255.0;
            	return float4(rawDepth,0,0,id);
            }
            
            ENDHLSL
        }

		//PixelizeObjectPass
		Pass
        {
	        Name "PixelizeObjectPass"
	        Lighting Off
            Blend [_BlendSrc] [_BlendDst]
            Cull[_CullMode]
	        ZWrite Off
        	Tags{"LightMode" = "UniversalForward"}
	        
            HLSLPROGRAM
            
            #pragma vertex vert_Pixelize
            #pragma fragment frag_Pixelize

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
             struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            	float3 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirOS : TEXCOORD1;
                float3 posOS : TEXCOORD2;
            	float4 screenPos : TEXCOORD3;
            	float4 posCS : TEXCOORD4;
            };

            TEXTURE2D(_GrabTexForClearObject);
            TEXTURE2D(_GrabTexForPixelizeObject);
            
             vertexOutput vert_Pixelize (vertexInput v)
            {
                vertexOutput o;
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
            	o.screenPos = ComputeScreenPos(posCS);
                o.pos = posCS;
                o.nDirOS = v.normal;
                o.uv = v.uv;
                o.posOS = v.vertex.xyz;
             	o.posCS = posCS;
                return o;
            }
            
            half4 frag_Pixelize (vertexOutput input) : SV_TARGET
            {
            	float vertexRawDepth = input.posCS.z;
            	float2 screenPos = input.screenPos.xy/input.screenPos.w;
            	float downSampleValue = pow(2,_DownSampleValue);
            	
            	float2 size = floor(_ScreenParams.xy/downSampleValue);

            	float3 originPoint = float3(0,0,0);
            	#ifdef _EnableObjectCenterPoint
            		originPoint = TransformObjectToWorld(float3(0,0,0));
            	#endif

            	//判断像素是否在范围内的问题
                float4 worldOriginToScreenPos1= ComputeScreenPos(TransformWorldToHClip(originPoint));
                float2 worldOriginToScreenPos2= worldOriginToScreenPos1.xy/worldOriginToScreenPos1.w;
                float2 realSampleUV = (floor((screenPos-worldOriginToScreenPos2)*size)+0.5)/size+worldOriginToScreenPos2;
            	float4 realPixelizeObjectParam = SAMPLE_TEXTURE2D(_PixelizeVFXMask,sampler_PointClamp,realSampleUV);
            	float realRawMask = step(realPixelizeObjectParam.a*255,_ID+0.5f)*step(_ID-0.5f,realPixelizeObjectParam.a*255);
            	
            	float isNotInRange = CalculateIsNotRange(originPoint,screenPos,size, vertexRawDepth);
	            if (isNotInRange)
	            {
		            discard;
	            }
            	
            	//解决两个像素化物体相交的采样遮罩问题
	            if (realRawMask<0.5)
	            {
		            float2 sampleUVPerBias = downSampleValue.xx/_ScreenParams.xy;
	            	//方法2
	            	int isFindValue = 0;
	            	UNITY_LOOP
		            for (int i =1; i <32; i++)
		            {
			            float2 bias[4] = {float2(i,i),float2(i,-i),float2(-i,i),float2(-i,-i)};
	            		UNITY_LOOP
            			for (int j = 0; j<4; j++)
            			{
            				float2 realSampleUVBias = realSampleUV + bias[j]*sampleUVPerBias;
            				float4 realPixelizeObjectParam_Bias = SAMPLE_TEXTURE2D(_PixelizeVFXMask,sampler_PointClamp,realSampleUVBias);
            				float realRawMask_bias = step(realPixelizeObjectParam_Bias.a*255,_ID+0.5f)*step(_ID-0.5f,realPixelizeObjectParam_Bias.a*255);
            				
				            if (realRawMask_bias>0.5)
				            {
			            		realSampleUV = realSampleUVBias;
				            	isFindValue = 1;
				            	break;
				            }
            			}
		            	
			            if (isFindValue)
			            {
				            break;
			            }
		            }
	            }
            	float2 noiseUV = realSampleUV *_DissolveNoiseMap_ST.xy + _DissolveNoiseMap_ST.zw;
            	float dissolveNoise = SAMPLE_TEXTURE2D(_DissolveNoiseMap,sampler_PointRepeat,noiseUV).r;
            	float realDisovleRange = _DissolveRange*2;
            	float alpha = step(realDisovleRange,realSampleUV.y+dissolveNoise);
            	float stepEdgeTempMask = step(_DissolveRange*2+_DissolveEdge,realSampleUV.y+dissolveNoise);
            	float edgeMask = alpha - stepEdgeTempMask;
            	float4 pixelizeObjectCartoonTex = SAMPLE_TEXTURE2D(_PixelizeVFXCartoonTex,sampler_PointClamp,realSampleUV);
            	half3 finalRGB = lerp(pixelizeObjectCartoonTex.rgb*_BaseColor.rgb,_DissolveEdgeColor,edgeMask)*_FresnelIntensity;
            	half fianlA = (1-pixelizeObjectCartoonTex.a)*alpha;
            	half4 result = half4(finalRGB,fianlA);
				return result;
            }
            
            ENDHLSL
        }
    }
}