Shader "URP/CartoonTree/SimpleLeaves"
{
    Properties
    {
    	_BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainTex("MainTex",2D) = "white"{}
    	
    	[Header(Diffuse)]
        _SmoothValue("Smooth Value",Range(0,0.1)) = 0
        _ShadowValue("Shadow Value",Range(0,0.8)) = 0
        
        [Space(20)]
        //Wind
        _WindDistortionMap("Wind Distortion Map",2D) = "black"{}
        _WindStrength("WindStrength",float) = 0
        _U_Speed("U_Seed",float) = 0
        _V_Speed("V_Seed",float) = 0
        _Bias("Wind Bias",Range(-1.0,1.0)) = 0
	    
        
        [Space(20)]
        //FrameTexture
        [Toggle(_EnableFrameTexture)] _EnableFrameTexture("Enable Frame Texture",float) = 0
        _FrameTex("Sprite Frame Texture", 2D) = "white" {}
        _FrameNum("Frame Num",int) = 24
        _FrameRow("Frame Row",int) = 5
        _FrameColumn("Frame Column",int) = 5
        _FrameSpeed("Frame Speed",Range(0,10)) = 3
    	
    	[Space(20)]
        [Toggle(_EnableMultipleMeshMode)]_EnableMultipleMeshMode("Enable Multiple Mesh Mode",float) = 0
    	[Toggle(_EnableHoudiniDecodeMode)]_EnableDecodeMode("Enable Houdini Decode Mode",float) = 0
        _DecodeValue("Decode Value",float) = 10000
    }
    
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
        	"Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"  
        }

        //解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
    	
    	HLSLINCLUDE
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

    		#pragma shader_feature _EnableFrameTexture
    		#pragma shader_feature _EnableMultipleMeshMode
    		#pragma shader_feature _EnableHoudiniDecodeMode

    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS
    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
    		#pragma multi_compile  _SHADOWS_SOFT
    		
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            TEXTURE2D(_WindDistortionMap);
			SAMPLER(sampler_WindDistortionMap);
    		TEXTURE2D(_FrameTex);
            SAMPLER(sampler_FrameTex);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
    		half4 _BaseColor;
            float4 _MainTex_ST;
    		float _WindStrength;
    		float _U_Speed;
    		float _V_Speed;
    		float4 _WindDistortionMap_ST;
    		float _Bias;

    		float4 _FrameTex_ST;
			int _FrameNum;
    		float _FrameRow;
    		float _FrameColumn;
    		float _FrameSpeed;
    		
    		float _ShadowValue;
    		float _SmoothValue;
    		
    		float _DecodeValue;
            //----------变量声明结束-----------
            CBUFFER_END
    		
            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            	float4 color : COLOR;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float2 uv3 : TEXCOORD2;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float3 posWS : TEXCOORD2;
            	float3 nDirWS_Origin : TEXCOORD3;
            };

            vertexOutput vert (vertexInput v)
            {

            	float3 centerOffset = float3(0, 0, 0);
                #ifdef _EnableMultipleMeshMode
                    centerOffset = v.color;
                #endif

            	#ifdef _EnableHoudiniDecodeMode
                    centerOffset = (float4(v.uv2,v.uv3)*2.0-1.0)*_DecodeValue;
                #endif
            	
                v.vertex.xyz -= centerOffset;
                    
                //Billboard
                float3 camPosOS = TransformWorldToObject(_WorldSpaceCameraPos);//将摄像机的坐标转换到物体模型空间
                float3 newForwardDir = normalize(camPosOS - centerOffset); //计算新的forward轴
                float3 newRightDir = normalize(cross(float3(0, 1, 0), newForwardDir)); //计算新的right轴
                float3 newUpDir = normalize(cross(newForwardDir,newRightDir)); //计算新的up轴
                v.vertex.xyz = newRightDir * v.vertex.x + newUpDir * v.vertex.y + newForwardDir*v.vertex.z; //将原本的xyz坐标以在新轴上计算，相当于一个线性变换【原模型空间】->【新模型空间】
            	v.vertex.xyz += centerOffset;
            	
            	float3 posWS = TransformObjectToWorld(v.vertex);
            	float windStrength = _WindStrength+0.001f;
            	float2 windUV = posWS.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + float2(_U_Speed,_V_Speed) * _Time.y;
		        float3 windSample = (SAMPLE_TEXTURE2D_LOD(_WindDistortionMap,sampler_WindDistortionMap, windUV,0).xyz * 2 - 1);
		        float3 wind = normalize(windSample)* windStrength*0.3;
		        
            	v.vertex.xyz = v.vertex.xyz +wind;
            	
                vertexOutput o;
            	
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                o.posWS = TransformObjectToWorld(v.vertex);
            	o.nDirWS_Origin = TransformObjectToWorldNormal(v.color) ;
                return o;
            }

    		float CalculateDiffuseLightResult(float3 nDir, float3 lDir, float lightRadience, float shadow)
            {
                float nDotl = dot(nDir,lDir);
                float lambert = max(0,nDotl);
                float halfLambert = nDotl*0.5+0.5;
                half3 result = halfLambert*shadow*lightRadience;
                return result;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                 //Instance变量
                half3 baseColor = _BaseColor;
                int frameNum = _FrameNum;
                float frameRow = _FrameRow;
                float frameColumn = _FrameColumn;
                float frameSpeed = _FrameSpeed;
                float shadowValue = _ShadowValue;
            	
                float2 mainTexUV;
                half4 mainTex;
                #ifdef _EnableFrameTexture
                    mainTexUV = TRANSFORM_TEX(i.uv, _FrameTex);
                    float perX = 1.0f /frameRow;
                    float perY = 1.0f /frameColumn;
                    float currentIndex = fmod(_Time.z*frameSpeed,frameNum);
                    int rowIndex = currentIndex/frameRow;
                    int columnIndex = fmod(currentIndex,frameColumn);
                    float2 realMainTexUV = mainTexUV*float2(perX,perY)+float2(perX*columnIndex,perY*rowIndex);
                    mainTex =   SAMPLE_TEXTURE2D(_FrameTex, sampler_FrameTex, realMainTexUV);
                    
                #else
                    float4 mainTex_ST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MainTex_ST);
                    mainTexUV = i.uv*mainTex_ST.xy+mainTex_ST.zw;
                    mainTex =  SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainTexUV);
                #endif

            	float4 shadowCoord = TransformWorldToShadowCoord(i.posWS);
                Light mainLight = GetMainLight(shadowCoord);
                float3 nDir= i.nDirWS;
                float3 lDir = mainLight.direction;
                float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
                float3 hDir = normalize(lDir+vDir);

                float3 nDirVS = TransformWorldToViewDir(i.nDirWS);
            	
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
                float mask1 = 1-smoothstep(0.2-_SmoothValue,0.2,diffuse);
                float mask2 = 1-smoothstep(0.41-_SmoothValue,0.41,diffuse);
                float mask3 = 1-smoothstep(0.624-_SmoothValue,0.624,diffuse);
                float mask4 = 1-smoothstep(0.823-_SmoothValue,0.823,diffuse);
                float mask5 = 1-smoothstep(0.965-_SmoothValue,0.965,diffuse);
                float mask6 = 1 - mask5;
                mask2 = mask2 -mask1;
                mask3 = mask3 -mask2-mask1;
                mask4 = mask4 -mask3 - mask2 -mask1;
                mask5 = mask5 - mask4 -mask3 - mask2 -mask1;
                
                
                half3 diffuseColor1 = _BaseColor*albedo*mask1*half3(0.2829f,0.2976f,0.3584f);
                half3 diffuseColor2 = _BaseColor*albedo*mask2*half3(0.4024f,0.4244f,0.4811f);
                half3 diffuseColor3 = _BaseColor*albedo*mask3*half3(0.4396f,0.4660f,0.5377f);
                half3 diffuseColor4 = _BaseColor*albedo*mask4*half3(0.6031f,0.6451f,0.7641f);
                half3 diffuseColor5 = _BaseColor*albedo*mask5*half3(0.6776f,0.7272f,0.8584f);
                half3 diffuseColor6 = _BaseColor*albedo*mask6;
                half3 Diffuse = diffuseColor1+diffuseColor2+diffuseColor3+diffuseColor4+diffuseColor5+diffuseColor6;

            	half3 finalRGB = Diffuse;
                clip(albedo.a-0.1);

            	
                half4 result = half4(finalRGB,albedo.a);
                return result;
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

		// shadow casting pass with empty fragment
		Pass
		{
		Name "GrassShadowCaster"
		Tags{ "LightMode" = "ShadowCaster" }

		ZWrite On
		ZTest LEqual

		HLSLPROGRAM

		 #pragma vertex vert
		#pragma fragment frag_shadow
		
		#pragma target 4.6

		half4 frag_shadow(vertexOutput i) : SV_TARGET
		{
			float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
			//alpha clip
			float2 mainTexUV = i.uv *_MainTex_ST.xy+_MainTex_ST.zw;
			half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,mainTexUV);
			clip(mainTex.a-0.1);
			return 1;
		 }

		ENDHLSL
		}
    }
}