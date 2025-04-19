Shader "URP/ShaderURP_Water"
{
    Properties
    {
        [Header(Reflection)]
        _RefIntensity("RefIntensity",range(0,1)) = 0.6
        _Blur("BlurIntensity",float) = 0
    	
    	[Header(Interactive)]
    	_WaterRipple("Water Ripple",2D) = "black"{}
    	_RippleInt("Ripple Intensity(Vertex)",Range(0,1)) = 0.1
        
        [Header(Water Normal)]
        _NormalMap("Water Normal Map",2D) = "bump"{}
    	_NormalSpeed("Normal Speed",Vector) = (0.2,0.2,-0.33,-0.4)
        _NormalScale1("Normal Scale 1",float) = 10
        _NormalScale2("Normal Scale 2",float) = 7
        _NormalIntensity("Normal Intensity",Range(0,1)) = 0.5
        _NormalNoise("Normal Noise",Range(0,1)) = 0.68
        
        [Header(Water Color)]
        _ShallowColor("Shallow Color",color) = (1.0,1.0,1.0,1.0)
        _DeepColor("Deep Color",color) = (1.0,1.0,1.0,1.0)
        _WaterShallowRange("Water Shallow Range",range(0,5)) = 0.15
    	
    	[Header(Refraction)]
    	_RefractionInt("Refraction Intensity",Range(0,1)) = 1
        
        [Header(Causitics Tex)]
        _CausiticsTex("Causitics Tex",2D) = "black"{}
        _CausiticsScale("Causitics Scale",float) = 5.7
        _CausiticsRange("Causitics Range",float) = 2.15
         _CausiticsIntensity("Causitics Intensity",float) = 1.54
        _CausiticsSpeed("Causitics Speed",float) = 1
        
        [Header(Shore)]
        _ShoreCol("Shore Col",color) = (0,0,0,0)
        _ShoreRange("Shore Range",float) = 0.08
        _ShoreEdgeWidth("Shore Edge Width",range(-1,1)) = 0.02
        _ShoreEdgeIntensity("Shore Edge Intensity",range(0,1)) = 0.2
    	
    	[Header(Foam)]
    	_FoamNoise("Foam Noise",2D) = "white"{}
        _FoamRange("Foam Range",float) = 0.1
    	_FoamBend("Foam Bend",float) = 0.2
    	_FoamFrequency("Foam Frequency",float) = 1
    	_FoamSpeed("Foam Speed", float) = 1
    	_FoamDissolve("Foam Dissolve",Range(0,2)) = 0.2
    	_FoamCol("Foam Color",color) = (1,1,1,1)
    	
        
    	[Header(Light)]
    	_SpecInt("Specular Intensity",Range(0,1)) = 1
        _Smothness("Smothness",range(0,1)) = 0.5
    	_Metallic("Metallic",range(0,1)) = 0.5
        _SpecCol("Spec Col",color) = (1.0,1.0,1.0,1.0)
    }
    
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "Queue"="Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }
        
        //解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
    	
    	HLSLINCLUDE
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS
    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
    		#pragma multi_compile  _SHADOWS_SOFT

            #define kDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04)
            
            //----------贴图声明开始-----------
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_CameraNormalsTexture);
            SAMPLER(sampler_CameraNormalsTexture);
            TEXTURE2D(_CameraOpaqueTexture);//获取到摄像机渲染画面的Texture
            SAMPLER(sampler_CameraOpaqueTexture);
            
            TEXTURE2D(_ScreenSpaceReflectionTexture);//定义贴图
            SAMPLER(sampler_ScreenSpaceReflectionTexture);//定义采样器
    		
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
    		TEXTURE2D(_WaterRipple);
            SAMPLER(sampler_WaterRipple);
            TEXTURE2D(_CausiticsTex);
            SAMPLER(sampler_CausiticsTex);
    	
            TEXTURE2D(_FoamNoise);
            SAMPLER(sampler_FoamNoise);
    	
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            
            float _RefIntensity;
            half4 _ShallowColor;
            half4 _DeepColor;
            float _WaterShallowRange;
            
            float _NormalIntensity;
            float _NormalScale1;
            float _NormalScale2;
            float _NormalNoise;
            float4 _NormalSpeed;

    		float _RippleInt;
            
            float _Blur;
            float _CausiticsScale;
            float _CausiticsRange;
            float _CausiticsIntensity;
            float _CausiticsSpeed;
    	
            half4 _ShoreCol;
            float _ShoreRange;
            float _ShoreEdgeWidth;
            float _ShoreEdgeIntensity;

    		float _RefractionInt;

            float _FoamRange;
            float _FoamFrequency;
            float _FoamSpeed;
            float _FoamBend;
            float _FoamDissolve;
            half4 _FoamCol;
            float4 _FoamNoise_ST;

    		float _SpecInt;
            float _Smothness;
            float _Metallic;
            half4 _SpecCol;
            //----------变量声明结束-----------
            CBUFFER_END
    		
            //直接光镜面反射部分
            float3 CalculateSpecularResultColor(float3 albedo, float3 nDir, float3 lDir, float3 vDir, float smothness, float metallic, float3 specCol)
            {

            	float hDir = normalize(vDir+lDir);

            	float nDotl = max(saturate(dot(nDir,lDir)),0.000001);
				float nDotv = max(saturate(dot(nDir,vDir)),0.000001);
				float hDotv = max(saturate(dot(vDir,hDir)),0.000001);
            	
            	//粗糙度一家
				float perceptualRoughness = 1 - smothness;//粗糙度
				float roughness = perceptualRoughness * perceptualRoughness;//粗糙度二次方
				float squareRoughness = roughness * roughness;//粗糙度四次方
            	
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

            	//菲涅尔方程
				float3 F0 = lerp(kDielectricSpec.rgb, albedo, metallic);//使用Unity内置函数计算平面基础反射率
				float3 F = F0 + (1 - F0) *pow((1-hDotv),5);
            	

            	float3 SpecularResult = (D*G*F)/(4*nDotv*nDotl);

				 //因为之前少给漫反射除了一个PI，为保证漫反射和镜面反射比例所以多乘一个PI
				float3 specColor = SpecularResult * specCol * nDotl * PI;

            	return specColor;
            }

            //Remap
            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
             {
               return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
             }

            float3 UnpackScaleNormal(float4 packedNormal, float bumpScale)
            {
	            float3 normal = UnpackNormal(packedNormal);
            	normal.xy *= bumpScale;
            	normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
            	return normal;
            }

            float3 NormalBlendReoriented(float3 A, float3 B)
			{
				float3 t = A.xyz + float3(0.0, 0.0, 1.0);
				float3 u = B.xyz * float3(-1.0, -1.0, 1.0);
				return (t / t.z) * dot(t, u) - u;
			}

            float3 ReconstructWorldPositionFromDepth(float4 screenPos, float rawDepth)
            {
                float2 ndcPos = (screenPos/screenPos.w)*2-1;//map[0,1] -> [-1,1]
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
    	
            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            	float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float3 posWS : TEXCOORD2;
                float3 nDirWS : TEXCOORD3;
                float3 tDirWS : TEXCOORD4;
                float3 bDirWS : TEXCOORD5;
            	float4 shadowCoord : TEXCOORD6;
            };

            vertexOutput vert (vertexInput v)
            {
            	float3 posOS = v.vertex.xyz;
                vertexOutput o;
            	o.posWS = TransformObjectToWorld(v.vertex);
            	
            	//Interactive Water
            	float rippleHeight  = SAMPLE_TEXTURE2D_LOD(_WaterRipple,sampler_WaterRipple,v.uv,0).x;
            	o.posWS.y+=rippleHeight*_RippleInt*0.1f;
            	v.vertex.xyz = TransformWorldToObject(o.posWS);
            	
                float4 posCS = TransformObjectToHClip(v.vertex.xyz);
            	float4 originalPosCS = TransformObjectToHClip(posOS);
                o.pos = posCS;
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
            	o.tDirWS = normalize(TransformObjectToWorld(v.tangent));
            	o.bDirWS = normalize(mul(o.nDirWS,o.tDirWS)*v.tangent.w);
                o.uv = v.uv;
                o.screenPos = ComputeScreenPos(originalPosCS);
            	o.shadowCoord = TransformWorldToShadowCoord(o.posWS);
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
            	float2 screenPos = i.screenPos.xy/i.screenPos.w;
            	
            	//Vector
                float3x3 TBN = float3x3(
                  i.tDirWS.x, i.bDirWS.x, i.nDirWS.x,
                  i.tDirWS.y, i.bDirWS.y, i.nDirWS.y,
                  i.tDirWS.z, i.bDirWS.z, i.nDirWS.z
                );
                
                float3 nDirWS = i.nDirWS;
                
            	
            	//WaterNormal
                float2 normalUV = i.posWS.xz;
            	float2 normalUV1 = frac(normalUV/_NormalScale1 + _NormalSpeed.xy*0.1*_Time.y);
            	float2 normalUV2 = frac(normalUV/_NormalScale2  + _NormalSpeed.zw*0.1*_Time.y);
                float4 NormalMap1 = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV1);
                float4 NormalMap2 = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV2);
                float3 var_NormalMap1 = UnpackScaleNormal(NormalMap1,_NormalIntensity);
                float3 var_NormalMap2 = UnpackScaleNormal(NormalMap2,_NormalIntensity);
                float3 waterNormal = NormalBlendReoriented(var_NormalMap1,var_NormalMap2);
            	//InteractiveNormal
            	float3 rippleNormal= SAMPLE_TEXTURE2D(_WaterRipple,sampler_WaterRipple,i.uv);
            	//BlendNormal
            	waterNormal = waterNormal+rippleNormal;
            	waterNormal = mul(TBN,waterNormal);
            	waterNormal = normalize(waterNormal);

            	float2 noiseUV = waterNormal.xz/(1+i.pos.w);
            	
            	
            	//WaterDepth(Get Original Depth)
                float rawDepth0 = SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_CameraDepthTexture,screenPos).r;
                float3 posWS_frag0 = ReconstructWorldPositionFromDepth(i.screenPos,rawDepth0);
                float waterDepth0 = i.posWS.y - posWS_frag0.y;
            	
            	//Firstly Sample Depth Texture (Distortion)
            	float2 grabUV = screenPos;
            	grabUV.x += noiseUV*_NormalNoise;
            	float rawDepth1 =  SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,grabUV).r;
            	
                float3 posWS_frag1 = ReconstructWorldPositionFromDepth(i.screenPos,rawDepth1);

            	//Get Reflection And Refraction Mask
            	float ReflectionAndReflectionMask = step(posWS_frag1.y,i.posWS.y);
            	grabUV = screenPos;
            	grabUV.x += noiseUV*_NormalNoise/max(i.screenPos.w,1.2f)*ReflectionAndReflectionMask*_RefractionInt;

            	//Secondly Sample Depth Texture (Remove the parts that should not be distorted)
            	float rawDepth2 =  SAMPLE_TEXTURE2D(_CameraDepthTexture,sampler_PointClamp,grabUV).r;
                float3 posWS_frag2 = ReconstructWorldPositionFromDepth(i.screenPos,rawDepth2);

            	float waterDepth = i.posWS.y - posWS_frag2.y;
            	
            	//Caustics
                float causitics_range = saturate(exp(-waterDepth/_CausiticsRange));
                float2 causiticsUV = posWS_frag2.xz/_CausiticsScale;
                float2 causiticsUV1 = causiticsUV+frac(_Time.x*_CausiticsSpeed);
                float2 causiticsUV2 = causiticsUV-frac(_Time.x*_CausiticsSpeed);
                half3 CausiticsCol1 = SAMPLE_TEXTURE2D(_CausiticsTex,sampler_CausiticsTex,causiticsUV1+float2(0.1f,0.2f));
                half3 CausiticsCol2 = SAMPLE_TEXTURE2D(_CausiticsTex,sampler_CausiticsTex,causiticsUV2);
            	float3 CameraNormal = SAMPLE_TEXTURE2D(_CameraNormalsTexture,sampler_CameraNormalsTexture,grabUV);
            	float CausticsMask1 = saturate(CameraNormal.y*CameraNormal.y);
            	float CausticsMask2 = saturate(dot(CameraNormal,_MainLightPosition));
            	float CausticsMask = CausticsMask1*CausticsMask2;
                half3 CausiticsCol = min(CausiticsCol1,CausiticsCol2)*causitics_range*_CausiticsIntensity*CausticsMask;

            	//ReflectionColor
            	float2 reflectUV = screenPos;
            	reflectUV.x += noiseUV*_NormalNoise*ReflectionAndReflectionMask;
            	half4 refCol = SAMPLE_TEXTURE2D(_ScreenSpaceReflectionTexture,sampler_ScreenSpaceReflectionTexture,reflectUV);

            	//Refraction UnderWater
				half3 underWaterCol = SAMPLE_TEXTURE2D(_CameraOpaqueTexture,sampler_CameraOpaqueTexture,grabUV);
                underWaterCol = saturate(underWaterCol+CausiticsCol);
            	
            	//WaterColor
                float waterShallow_range =clamp(exp(-max(waterDepth0,waterDepth)/_WaterShallowRange),0,1);
                half4 waterCol = lerp(_DeepColor,_ShallowColor,waterShallow_range);
            	
            	//Light
                float3 nDir = waterNormal;
            	float3 lDir = _MainLightPosition.xyz;
            	float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                float3 hDir = SafeNormalize(lDir+vDir);
                float nDoth = dot(nDir,hDir);
            	float halfLambert = saturate(dot(nDir,lDir)*0.5+0.5);
            	float halfLambert_Modified = remap(halfLambert,0,1,0.5,1);
            	float3 SpecLight = CalculateSpecularResultColor(waterCol,nDir,lDir,vDir,_Smothness,_Metallic, _SpecCol)*_SpecInt;
            	waterCol.rgb = lerp(waterCol,waterCol*0.5f+_ShallowColor*0.5f,saturate(exp(-distance(i.posWS.xyz,_WorldSpaceCameraPos.xyz))));
            	waterCol.rgb = lerp(refCol*saturate(waterCol+0.3),waterCol,1-_RefIntensity)*halfLambert_Modified;
            	
            	//shadow
            	float shadow = MainLightRealtimeShadow(i.shadowCoord);
            	shadow = remap(shadow,0,1,0.7,1);
            	
            	float FinalA = waterCol.a;
            	
            	half3 WaterFinalColor = saturate(lerp(underWaterCol*waterCol,waterCol,FinalA)+SpecLight);
            	
            	//ShoreEdge
            	half3 shoreCol = _ShoreCol;
                float shoreRange = saturate(exp(-max(waterDepth0,waterDepth)/_ShoreRange));
                half3 shoreEdge = smoothstep(0.1,1-(_ShoreEdgeWidth-0.2),shoreRange)*shoreCol*_ShoreEdgeIntensity;

            	//Foam
                float foamX = saturate(1-waterDepth/_FoamRange);
                float foamRange = 1-smoothstep(_FoamBend-0.1,1,saturate(max(waterDepth0,waterDepth)/_FoamRange));//遮罩
                float foamNoise = SAMPLE_TEXTURE2D(_FoamNoise,sampler_FoamNoise,i.posWS.xz*_FoamNoise_ST.xy+_FoamNoise_ST.zw);
                half4 foam = sin(_FoamFrequency*foamX-_FoamSpeed*_Time.y);
                foam = saturate(step(foamRange,foam+foamNoise-_FoamDissolve))*foamRange*_FoamCol;
            	
                half3 FinalRGB = saturate(WaterFinalColor+shoreEdge+foam);
            	FinalRGB*=shadow;
            	
            	half4 result = half4(FinalRGB,1.0);
            	
                return result;
            }
    		
    	
    	ENDHLSL
        
        pass
        {
	        Name "WaterFront"

        	Cull Back
        	Tags{"LightMode" = "UniversalForward"}
	        
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            ENDHLSL
        }
        
    }
}