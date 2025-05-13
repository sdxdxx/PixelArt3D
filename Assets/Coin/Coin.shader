Shader "URP/Cartoon/Coin"
{
    Properties
    {
        [Header(Tint)]
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        
        [Header(PaintTex)]
        _MainTex("MainTex",2D) = "white"{}
        _PainEffectIntensity("Pain Effect Intensity",Range(0,1)) = 0.2
        _LossOfAccuracy("Loss Of Accuracy",Range(0,1)) = 0.75
        
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
        
    }
    
    SubShader
    {
         Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
    	
    	//解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Unlit/DepthOnly"
        UsePass "Universal Render Pipeline/Unlit/DepthNormalsOnly"

         pass
        {
            Tags { "LightMode" = "UniversalForward" }
            
            Cull Back
            Stencil 
            {
                Ref 0
                Comp Always
                Pass Replace
            }
            
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

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
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            half4 _BaseColor;
            float _PainEffectIntensity;
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
            float _LossOfAccuracy;
            //----------变量声明结束-----------
            CBUFFER_END

            //Remap
            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
             {
               return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
             }
            

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
                float3 nDirOS : TEXCOORD3;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv*_MainTex_ST.xy+_MainTex_ST.zw;
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                o.posWS = positionWS;
                o.nDirOS = v.normal;
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

                //通过丧失精度做出油画质感
                float lossOfAccuracy = (1-_LossOfAccuracy+0.01)*1000;
                nDir = round(nDir*lossOfAccuracy);
                nDir = nDir/lossOfAccuracy;
                vDir = round(vDir*lossOfAccuracy*1.1);
                vDir = vDir/lossOfAccuracy/1.1;
                
                float3 hDir = normalize(lDir+vDir);

                float3 nDirVS = TransformWorldToViewDir(nDir);
                half3 matcap = SAMPLE_TEXTURE2D(_MatCap,sampler_MatCap,abs(nDirVS.xy*0.5+0.5)).rgb;

                float mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv*_MainTex_ST.xy+_MainTex_ST.zw);
                mainTex = remap(mainTex,0,1,1-_PainEffectIntensity,1);
                half4 albedo = _BaseColor;
                
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
            	half3 Specular = _SpecularIntensity*pow(max(0,dot(nDir,hDir)),_SpecularPow)*_SpecularColor;
                Specular = smoothstep(_RangeSpecular-_SmoothSpecular,_RangeSpecular,Specular);
                
                half3 FinalRGB = lerp(1,matcap,_MatCapLerp)*Diffuse;//Matcap+Diffuse
                FinalRGB = lerp(_GreyColor*matcap,FinalRGB,mainTex);//整体增加笔触质感
                FinalRGB = saturate(FinalRGB+Specular);//添加高光
                
                return half4(FinalRGB,1.0);
            }
            
            ENDHLSL
        }
        
        //Outline
        pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Cull Front
            
            Stencil 
            {
                Ref 1
                Comp NotEqual
                Pass Keep
            }
            
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
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
                o.pos = TransformObjectToHClip(v.vertex.xyz+v.normal* _OutlineWidth * 0.1);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                return _OutlineColor;
            }
            
            ENDHLSL
        }
        
        
        pass
        {
	        Name "OutlineMask"

        	Tags{"LightMode" = "OutlineMask"}

            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            #pragma vertex vert
            #pragma fragment frag_OutlineMask

             struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float3 color : COLOR;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                return o;
            }

            half4 frag_OutlineMask (vertexOutput i) : SV_TARGET
            {
            	return half4(1,1,1,1);
            }
            ENDHLSL
        }
    }
}