Shader "URP/Cartoon/PixelizeObject"
{
    Properties
    {
        [Header(Tint)]
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        
        _MainTex("MainTex",2D) = "white"{}
        
        [Header(MatCap)]
        _MatCap("Mat Cap",2D) = "white"{}
        _MatCapLerp("MatCapLerp",Range(0,1)) = 1
        
         [Header(Diffuse)]
        _RangeDark("Range Dark",Range(0,1)) = 0.3
        _SmoothDark("Smooth Dark",Range(0,0.2)) = 0
        _RangeLight("Range Light",Range(0,1)) = 0.7
        _SmoothLight("Smooth Light",Range(0,0.2)) = 0
        _LightColor("Light Color",Color) = (1,1,1,1)
        _GreyColor("Grey Color",Color) = (0.5,0.5,0.5,1)
        _DarkColor("Dark Color",Color) = (0,0,0,1)
        
        [Header(Specular)]
        _SpecularIntensity("Specular Intensity",Range(0,1)) = 1
        _SpecularPow("Specular Power",Range(0.1,200)) = 50
        _SpecularColor("Specular Color",Color) = (1,1,1,1)
        _RangeSpecular("Range Specular",Range(0,1)) = 0.9
        _SmoothSpecular("Smooth Specular",Range(0,0.2)) = 0
        
        [Header(Outline)]
        _OutlineColor("Outline Color",Color) = (0.0,0.0,0.0,0.0)
        _OutlineWidth("Outline Width",Range(0,5)) = 1
    	[IntRange]_ID("Mask ID", Range(0,254)) = 100
    	
    	[Header(DownSample)]
    	[IntRange]_DownSampleValue("Down Sample Value",Range(0,5)) = 0
    	[Toggle(_EnableObjectCenterPoint)]_EnableObjectCenterPoint("Enable Object Center Point",float) = 0.0
    }
    
    SubShader
    {
         Tags
        {
            "RenderType" = "Opaque"
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
            half4 _LightColor;
            half4 _GreyColor;
            half4 _DarkColor;
            float _RangeDark;
            float _RangeLight;
            float _SmoothDark;
            float _SmoothLight;
            float _MatCapLerp;
            float4 _MainTex_ST;

            float _SpecularIntensity;
            float _SpecularPow;
            half4 _SpecularColor;
            float _RangeSpecular;
            float _SmoothSpecular;

			int _DownSampleValue;

			int _ID;
            //----------变量声明结束-----------
            CBUFFER_END

         TEXTURE2D(_CameraDepthTexture);
         TEXTURE2D(_m_CameraDepthTexture);
		 SAMPLER(sampler_CameraDepthTexture);
         
         TEXTURE2D(_PixelizeObjectMask);
         
         TEXTURE2D(_PixelizeObjectCartoonTex);

        //Remap
        float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
         {
           return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
         }

         float CalculateIsNotRange(float3 originPoint, float2 screenPos, float2 size, float rawDepth)
            {
                float2 bias[4] = {float2(0.0,-1.0),float2(0.0,1.0),float2(1.0,0.0),float2(-1.0,0.0)};
             	float4 pixelizeObjectParam = SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp,screenPos);
             	float pixelizeObjectParamMask = step(pixelizeObjectParam.a,1-0.000001f);
                UNITY_LOOP
                for (int i =0; i<4; i++)
                {
                    float4 worldOriginToScreenPos1= ComputeScreenPos(TransformWorldToHClip(originPoint));
                    float2 worldOriginToScreenPos2= worldOriginToScreenPos1.xy/worldOriginToScreenPos1.w;
                    float2 realSampleUV = (floor((screenPos-worldOriginToScreenPos2)*size)+0.5+bias[i])/size+worldOriginToScreenPos2;
                	float realRawDepth = SAMPLE_TEXTURE2D(_m_CameraDepthTexture,sampler_PointClamp,realSampleUV);
                	float4 realPixelizeObjectParam = SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp,realSampleUV);
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
         
        //解决深度引动模式Depth Priming Mode问题
        //UsePass "Universal Render Pipeline/Lit/DepthNormals"
        
        Pass
        {
        	Name "CustomNormalsPass"

        	Tags{"LightMode" = "DepthNormals"}
        	
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
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
            	float4 screenPos : TEXCOORD2;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
            	float3 posWS = TransformObjectToWorld(v.vertex).xyz;
                o.pos = posCS;
                o.nDirWS = normalize(TransformObjectToWorldNormal(v.normal));
                o.uv = v.uv;
            	o.screenPos = ComputeScreenPos(posCS);
                return o;
            }

            float4 frag (vertexOutput i) : SV_TARGET
            {
            	float vertexRawDepth = i.pos.z;
            	float2 screenPos = i.screenPos.xy/i.screenPos.w;
            	
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
            	float4 realPixelizeObjectParam = SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp,realSampleUV);
            	float realRawMask = step(realPixelizeObjectParam.a*255,_ID+0.5f)*step(_ID-0.5f,realPixelizeObjectParam.a*255);
            	float rawMask = step(realPixelizeObjectParam.a,1-0.000001f);
            	float temp = step(vertexRawDepth,realPixelizeObjectParam.r)*(rawMask - realRawMask);
            	float realMask = max(temp,realRawMask);
            	float isNotInRange = CalculateIsNotRange(originPoint,screenPos,size, vertexRawDepth);
	            if (isNotInRange)
	            {
		            discard;
	            }
            	
            	float3 normalWS = NormalizeNormalPerPixel(i.nDirWS);
            	return float4(normalWS,1);
            }
            
            ENDHLSL
        }
        
        //DepthOnly Pass
        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            ColorMask R

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            #if defined(LOD_FADE_CROSSFADE)
			    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
			#endif

            float _OutlineWidth;

			struct Attributes
			{
			    float4 position     : POSITION;
			    float2 texcoord     : TEXCOORD0;
         		float3 color           : COLOR;
			    UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct Varyings
			{
			    #if defined(_ALPHATEST_ON)
			        float2 uv       : TEXCOORD0;
			    #endif
			    float4 positionCS   : SV_POSITION;
				float3 color             : TEXCOORD1;
				float4 screenPos     : TEXCOORD2;
			    UNITY_VERTEX_INPUT_INSTANCE_ID
			    UNITY_VERTEX_OUTPUT_STEREO
			};

			Varyings DepthOnlyVertex(Attributes input)
			{
			    Varyings output = (Varyings)0;
			    UNITY_SETUP_INSTANCE_ID(input);
			    UNITY_TRANSFER_INSTANCE_ID(input, output);
			    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

			    #if defined(_ALPHATEST_ON)
			        output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
			    #endif
				
			    output.positionCS = TransformObjectToHClip(input.position.xyz+input.color* _OutlineWidth * 0.1);
				output.screenPos = ComputeScreenPos(output.positionCS);
			    return output;
			}

			half DepthOnlyFragment(Varyings input) : SV_TARGET
			{
			    UNITY_SETUP_INSTANCE_ID(input);
			    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

				float vertexRawDepth = input.positionCS.z;
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
            	float4 realPixelizeObjectParam = SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp,realSampleUV);
            	float realRawMask = step(realPixelizeObjectParam.a*255,_ID+0.5f)*step(_ID-0.5f,realPixelizeObjectParam.a*255);
            	float rawMask = step(realPixelizeObjectParam.a,1-0.000001f);
            	float temp = step(vertexRawDepth,realPixelizeObjectParam.r)*(rawMask - realRawMask);
            	float realMask = max(temp,realRawMask);
            	float isNotInRange = CalculateIsNotRange(originPoint,screenPos,size, vertexRawDepth);
	            if (isNotInRange)
	            {
		            discard;
	            }

			    #if defined(_ALPHATEST_ON)
			        Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
			    #endif

			    #if defined(LOD_FADE_CROSSFADE)
			        LODFadeCrossFade(input.positionCS);
			    #endif

			    return input.positionCS.z;
			}
            ENDHLSL
        }
        
        //Cartoon Rendering
        Pass
        {
            Tags { "LightMode" = "PixelizeObjectCartoonPass" }
            
            Stencil
            {
                Ref [_ID]
                Comp Always
                Pass Replace
            }
            
            Blend SrcAlpha OneMinusSrcAlpha
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
            TEXTURE2D(_MatCap);
            SAMPLER(sampler_MatCap);
            
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
                o.uv = v.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                o.posWS = positionWS;
            	o.screenPos = ComputeScreenPos(posCS);
                return o;
            }

            float CalculateDiffuseLightResult(float3 nDir, float3 lDir, float lightRadience, float shadow)
            {
                float nDotl = dot(nDir,lDir);
                float lambert = max(0,nDotl);
                float halfLambert = nDotl*0.5+0.5;
                half3 result = lambert*shadow*lightRadience;
                return result;
            }
            
            half4 frag (vertexOutput i) : SV_TARGET
            {
            	
                float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
                Light mainLight = GetMainLight(shadowCoord);
                float3 nDir= i.nDirWS;
                float3 lDir = mainLight.direction;
                float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
                float3 hDir = normalize(lDir+vDir);

                float3 nDirVS = TransformWorldToViewDir(i.nDirWS);
                half3 matcap = SAMPLE_TEXTURE2D(_MatCap,sampler_MatCap,abs(nDirVS.xy*0.5+0.5)).rgb;

                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv*_MainTex_ST.xy+_MainTex_ST.zw);
                half4 albedo = _BaseColor*mainTex;
                
                float mainLightRadiance = mainLight.distanceAttenuation;
                float mainDiffuse = CalculateDiffuseLightResult(nDir,lDir,mainLightRadiance,mainLight.shadowAttenuation);

                uint lightCount = GetAdditionalLightsCount();
            	float additionalDiffuse = half3(0,0,0);
            	float additionalSpecular = half3(0,0,0);
				for (uint lightIndex = 0; lightIndex < lightCount; lightIndex++)
				{
				    Light additionalLight = GetAdditionalLight(lightIndex, i.posWS, 1);
					half3 additionalLightColor = additionalLight.color;
					float3 additionalLightDir = additionalLight.direction;
					// 光照衰减和阴影系数
                    float additionalLightRadiance =  additionalLight.distanceAttenuation;
					float perDiffuse = CalculateDiffuseLightResult(nDir,additionalLightDir,additionalLightRadiance,additionalLight.shadowAttenuation);
				    additionalDiffuse += perDiffuse;
				}

                float diffuse = mainDiffuse+additionalDiffuse;
                float diffuseDarkMask = 1-smoothstep(_RangeDark-_SmoothDark,_RangeDark,diffuse);//暗部
                float diffuseLightMask = smoothstep(_RangeLight-_SmoothLight,_RangeLight,diffuse);//亮部
                float diffuseGreyMask = 1-diffuseDarkMask-diffuseLightMask;//中部
                
                half3 Diffuse = albedo*(_DarkColor*diffuseDarkMask+diffuseGreyMask*_GreyColor+_LightColor*diffuseLightMask);
            	half3 Specular = _SpecularIntensity*pow(max(0,dot(nDir,hDir)),_SpecularPow);
                Specular = smoothstep(_RangeSpecular-_SmoothSpecular,_RangeSpecular,Specular)*_SpecularColor;
                
                half3 FinalRGB = lerp(1,matcap,_MatCapLerp)*Diffuse;//Matcap+Diffuse
                FinalRGB = saturate(FinalRGB+Specular);//添加高光
                return half4(FinalRGB,1.0);
            }
            
            ENDHLSL
        }
        
        //Outline
        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "PixelizeObjectOutlinePass" }
            
           Stencil
            {
                Ref [_ID]
                Comp NotEqual
            }
            
            ZWrite On
            Cull Front
            
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            //----------贴图声明开始-----------
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _OutlineColor;
            float _OutlineWidth;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float3 color : COLOR;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float3 nDirWS : TEXCOORD1;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz+v.color* _OutlineWidth * 0.1);
                o.nDirWS = TransformObjectToWorldNormal(v.color);
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                return _OutlineColor;
            }
            
            ENDHLSL
        }
        
       //PixelizeObjectMask
        Pass
        {
	        Name "PixelizeObjectMaskPass"

        	Tags{"LightMode" = "PixelizeObjectMaskPass"}
	        
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
            half4 _OutlineColor;
            float _OutlineWidth;
            
             vertexOutput vert_PixelizeMask (vertexInput v)
            {
                vertexOutput o;
            	v.vertex.xyz = v.vertex.xyz+v.color* _OutlineWidth * 0.1;
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
            	/*
            	//正交摄像机判断
            	if (unity_OrthoParams.w > 0.5)
            	{
            		//float linearEyeDepth = distance(_WorldSpaceCameraPos.xyz,posWS.xyz);
            		float linearEyeDepth = LinearEyeDepth(posWS,unity_MatrixV);
            		rawDepth = 1-(linearEyeDepth - _ProjectionParams.y) / (_ProjectionParams.z - _ProjectionParams.y);
            		rawDepth = TransformObjectToHClip(i.posOS).z;
            	}
	            else
	            {
		            float linearEyeDepth = TransformObjectToHClip(i.posOS).w;
            		rawDepth = (rcp(linearEyeDepth)-_ZBufferParams.w)/_ZBufferParams.z;
	            }
	            */
            	float id = _ID;
            	id = id/255.0;
            	return float4(rawDepth,_DownSampleValue/5.0,0,id);
            }
            
            ENDHLSL
        }

		//PixelizeObjectPass
		Pass
        {
	        Name "PixelizeObjectPass"
	        ZWrite On
        	Tags{"LightMode" = "UniversalForWard"}
	        
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
            half4 _OutlineColor;
            float _OutlineWidth;
            
             vertexOutput vert_Pixelize (vertexInput v)
            {
                vertexOutput o;
            	v.vertex.xyz = v.vertex.xyz+v.color* _OutlineWidth * 0.1;
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
            	float4 realPixelizeObjectParam = SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp,realSampleUV);
            	float realRawMask = step(realPixelizeObjectParam.a*255,_ID+0.5f)*step(_ID-0.5f,realPixelizeObjectParam.a*255);
            	float rawMask = step(realPixelizeObjectParam.a,1-0.000001f);
            	float temp = step(vertexRawDepth,realPixelizeObjectParam.r)*(rawMask - realRawMask);
            	float realMask = max(temp,realRawMask);
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
            				float4 realPixelizeObjectParam_Bias = SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp,realSampleUVBias);
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
            	
            	 realPixelizeObjectParam = SAMPLE_TEXTURE2D(_PixelizeObjectMask,sampler_PointClamp,realSampleUV);
            	 realRawMask = step(realPixelizeObjectParam.a*255,_ID+0.5f)*step(_ID-0.5f,realPixelizeObjectParam.a*255);
            	half3 finalRGB = SAMPLE_TEXTURE2D(_PixelizeObjectCartoonTex,sampler_PointClamp,realSampleUV);
            	half4 result = half4(finalRGB,1.0);
				return result;
            }
            
            ENDHLSL
        }
    }
}