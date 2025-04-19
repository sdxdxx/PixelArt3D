Shader "URP/MySimplePBR2/Test"
{
    Properties
    {
    	[Header(Main Layer)]
    	_MainTex("Main Texture",2D) = "white"{}
    	
    	[Header(PBR)]
        _ColorTint("Color Tint",Color) = (1.0,1.0,1.0,1.0)
        _DarkColor("Dark Color",Color) = (0,0,0,1.0)
    	_Smoothness("Smoothness",Range(0,1)) = 0
    	_Metallic("Metallic",Range(0,1)) = 0
    	
    	[Header(Normal)]
    	_NormalMap("Normal Map",2D) = "bump"{}
    	_NormalInt("Normal Intensity",Range(0,5)) = 1
    }
    
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"  
        }
        
        //深度和法线信息写入
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
    	UsePass "Universal Render Pipeline/Lit/DepthNormals"
    	
    	HLSLINCLUDE
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
    		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
    	

    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS
    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
    		#pragma multi_compile  _SHADOWS_SOFT

    		#pragma shader_feature _EnableSubLayer
    		#pragma shader_feature _EnableSubLayerMask
    	
    		#define kDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04)
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
    		TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
    		TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
    		TEXTURE2D(_PixelizeBackgroundMask);
    	
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _ColorTint;
            half4 _DarkColor;

    		float _NormalInt;
    		float4 _NormalMap_ST;
            
            float _Smoothness;
            float _Metallic;
    	
            float4 _MainTex_ST;
            //----------变量声明结束-----------
            CBUFFER_END

    		 //Remap
            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
             {
               return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
             }
    	
    		float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
			 {
			 return F0 + (max(float3(1 ,1, 1) * (1 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
			}
    	
			float3 FresnelLerp (half3 F0, half3 F90, half cosA)
			{
			    half t = Pow4 (1 - cosA);   // FAST WAY
			    return lerp (F0, F90, t);
			}

    		float3 UnpackScaleNormal(float4 packedNormal, float bumpScale)
            {
	            float3 normal = UnpackNormal(packedNormal);
            	normal.xy *= bumpScale;
            	normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
            	return normal;
            }
            
            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            	float4 tangent : TANGENT;
            	float4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float3 posWS : TEXCOORD2;
            	float4 screenPos : TEXCOORD3;
            	float4 shadowCoord : TEXCOORD4;
            	float3 tDirWS : TEXCOORD5;
            	float3 bDirWS : TEXCOORD6;
            	float4 color : TEXCOORD7;
            };

            vertexOutput vert (vertexInput v)
            {
            	float3 posWS = TransformObjectToWorld(v.vertex);
                vertexOutput o;
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
                o.pos = posCS;
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                o.posWS = TransformObjectToWorld(v.vertex);
            	o.screenPos = ComputeScreenPos(posCS);
            	o.shadowCoord = TransformWorldToShadowCoord(o.posWS);
            	o.tDirWS = normalize(TransformObjectToWorld(v.tangent));
            	o.bDirWS = normalize(cross(o.nDirWS,o.tDirWS)*v.tangent.w);
            	o.color = v.color;
                return o;
            }

    		half3 CalculatePBRResult(float3 nDir, float3 lDir, float3 vDir, half3 MainTex, float smoothness, float metallic, float shadow)
            {
				float3 hDir = normalize(vDir+lDir);

				float nDotl = max(saturate(dot(nDir,lDir)),0.000001);
				float nDotv = max(saturate(dot(nDir,vDir)),0.000001);
				float hDotv = max(saturate(dot(vDir,hDir)),0.000001);
				float hDotl = max(saturate(dot(lDir,hDir)),0.000001);
				float nDoth = max(saturate(dot(nDir,hDir)),0.000001);

				//光照颜色
				float3 lightCol = _MainLightColor.rgb;

				//粗糙度一家
				float perceptualRoughness = 1 - smoothness;//粗糙度
				float roughness = perceptualRoughness * perceptualRoughness;//粗糙度二次方
				float squareRoughness = roughness * roughness;//粗糙度四次方

				//直接光镜面反射部分

				//法线分布函数NDF
				float lerpSquareRoughness = pow(lerp(0.002,1,roughness),2);
				//Unity把roughness lerp到了0.002,
				//目的是保证在smoothness为0表面完全光滑时也会留有一点点高光

				float D = lerpSquareRoughness / (pow((pow(dot(nDir,hDir),2)*(lerpSquareRoughness-1)+1),2)*PI);

				//几何(遮蔽)函数
				float kInDirectLight = pow(roughness+1,2)/8;
				float kInIBL = pow(roughness,2)/2;//IBL：间接光照
				float Gleft = nDotl / lerp(nDotl,1,kInDirectLight);
				float Gright = nDotv / lerp(nDotv,1,kInIBL);
				float G = Gleft*Gright;

				float3 Albedo = MainTex;
            	
				//菲涅尔方程
				float3 F0 = lerp(kDielectricSpec.rgb, Albedo, metallic);//使用Unity内置函数计算平面基础反射率
				float3 F = F0 + (1 - F0) *pow((1-hDotv),5);


				 float3 SpecularResult = (D*G*F)/(4*nDotv*nDotl);

				//因为之前少给漫反射除了一个PI，为保证漫反射和镜面反射比例所以多乘一个PI
				float3 specColor = SpecularResult * lightCol * nDotl * PI;
				 
				//直接光漫反射部分
				//漫反射系数
				float kd = (1-F)*(1-metallic);

				float3 diffColor = kd*Albedo*lightCol*nDotl;//此处为了达到和Unity相近的渲染效果也不去除这个PI

				 float3 DirectLightResult = diffColor + specColor;

				//间接光漫反射
				half3 ambient_contrib = SampleSH(nDir);

				float3 ambient = 0.03 * Albedo;

				float3 iblDiffuse = max(half3(0, 0, 0), ambient.rgb + ambient_contrib);
				float3 Flast = fresnelSchlickRoughness(max(nDotv, 0.0), F0, roughness);
				 float kdLast = (1 - Flast) * (1 - metallic);

				float3 iblDiffuseResult = iblDiffuse * kdLast * Albedo;

				//间接光镜面反射
				float mip_roughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
				float3 reflectVec = reflect(-vDir, nDir);

				half mip = mip_roughness * UNITY_SPECCUBE_LOD_STEPS;
				half4 rgbm =  SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0,samplerunity_SpecCube0, reflectVec, mip);

				float3 iblSpecular = DecodeHDREnvironment(rgbm, unity_SpecCube0_HDR);

				float surfaceReduction = 1.0 / (roughness*roughness + 1.0); //Liner空间
				//float surfaceReduction = 1.0 - 0.28*roughness*perceptualRoughness; //Gamma空间

				float oneMinusReflectivity = 1 - max(max(SpecularResult.r, SpecularResult.g), SpecularResult.b);
				float grazingTerm = saturate(smoothness + (1 - oneMinusReflectivity));
				float4 IndirectResult = float4(iblDiffuse * kdLast * Albedo + iblSpecular * surfaceReduction * FresnelLerp(F0, grazingTerm, nDotv), 1);
            	
            	float3 result_RBR = lerp(DirectLightResult*_DarkColor,DirectLightResult,shadow) + IndirectResult*_MainLightColor.rgb;

            	return  result_RBR;
            }

    		half3 CalculateDepthRim(float4 screenPos, float3 nDirVS, half3 RimColor, float RimOffset)
            {
            	float2 screenPos_Modified = screenPos.xy/screenPos.w;
				float2 screenPos_Offset = screenPos_Modified + nDirVS.xy*RimOffset*0.001f/max(1,screenPos);//偏移后的视口坐标
				float depthOffsetTex = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,screenPos_Offset);
				float depthTex = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,screenPos_Modified);
				float depthOffset = Linear01Depth(depthOffsetTex,_ZBufferParams);
				float depth = Linear01Depth(depthTex,_ZBufferParams);
				float screenDepthRim = saturate(depthOffset - depth);
            	half3 depthRim = screenDepthRim*RimColor;
            	return depthRim;
            }

    		float3 NormalBlendReoriented(float3 A, float3 B)
			{
				float3 t = A.xyz + float3(0.0, 0.0, 1.0);
				float3 u = B.xyz * float3(-1.0, -1.0, 1.0);
				return (t / t.z) * dot(t, u) - u;
			}
    		
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

    		float _PixelizeBackGroundDownSampleValue;
            half4 frag (vertexOutput i) : SV_TARGET
            {
            	float2 screenPos = i.screenPos.xy/i.screenPos.w;
            	float downSampleValue = pow(2,_PixelizeBackGroundDownSampleValue);
            	float2 size = floor(_ScreenParams.xy/downSampleValue);
            	float3 originPoint = float3(0,0,0);
	           int isNotInRange = CalculateIsNotRange(originPoint,screenPos,size);
                if (isNotInRange)
                {
                    discard;
                }
            	
            	//MainTex
            	float2 mainTexUV = i.uv *_MainTex_ST.xy+_MainTex_ST.zw;
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,mainTexUV);
            	mainTex.rgb *=_ColorTint.rgb; 
            	
            	//TBN Matrix & SampleNormalMap
				 float3x3 TBN = float3x3(i.tDirWS,i.bDirWS,i.nDirWS);
            	float2 normalUV = i.uv*_NormalMap_ST.xy+_NormalMap_ST.zw;
            	float4 packedNormal = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV);
            	float3 var_NormalMap = UnpackScaleNormal(packedNormal,_NormalInt);

				//Vector
				float3 nDir = normalize(mul(var_NormalMap,TBN));
            	float3 nDirVS = normalize(mul((float3x3)UNITY_MATRIX_V, i.nDirWS));
            	float dayMask = smoothstep(0,1,_MainLightPosition.y);
   				float nightMask = smoothstep(0,1,-_MainLightPosition.y);
   				float3 lDir =_MainLightPosition*dayMask + (-_MainLightPosition*nightMask);
            	float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
            	

            	//shadow
            	float shadow = MainLightRealtimeShadow(i.shadowCoord);

            	//PBR
            	half3 result_RBR = CalculatePBRResult(nDir,lDir,vDir,mainTex,_Smoothness,_Metallic,shadow);
            	half3 FinalRGB = result_RBR*remap(dayMask,0,1,0.3,1);
            	
                return half4(FinalRGB,1.0);
            }
    	ENDHLSL
	    
        pass
        {
	        Tags{"LightMode"="UniversalForward"}
            
            cull off
             
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            ENDHLSL
        }

		pass
        {
	        Tags{"LightMode"="PixelizeBackgroundMask"}
            
            cull off
             
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag_Mask

            half4 frag_Mask (vertexOutput i) : SV_TARGET
            {
            	float4 result = float4(1,0,0,0);
                return result;
            }
            
            
            ENDHLSL
        }

		
    	
    	// shadow casting pass with empty fragment
		Pass
		{
			Tags{ "LightMode" = "ShadowCaster" }

			ZWrite On
			ZTest LEqual

			HLSLPROGRAM

			 #pragma vertex vert
			#pragma fragment frag_shadow
			
			#pragma target 4.6

			half4 frag_shadow(vertexOutput i) : SV_TARGET
			{
				return 1;
			 }

			ENDHLSL
		}
    }
}