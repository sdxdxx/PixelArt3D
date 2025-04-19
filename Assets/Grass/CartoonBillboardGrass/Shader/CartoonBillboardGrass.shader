Shader "URP/Cartoon/BillboardGrass"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _MainTex("MainTex",2D) = "white"{}
        
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
        _ShadowValue("Shadow Value",Range(0,1)) = 0.5
        
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
            "RenderPipeline" = "UniversalPipeline"
        }
    	
    	
        //UsePass "Universal Render Pipeline/Lit/DepthOnly"
        //UsePass "Universal Render Pipeline/Lit/DepthNormals"

        pass
        {
            Cull Off
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature _EnableFrameTexture
            #pragma shader_feature _EnableMultipleMeshMode
            #pragma shader_feature _EnableHoudiniDecodeMode
            
            //开启GPU Instance
            #pragma multi_compile_instancing

            #pragma multi_compile  _MAIN_LIGHT_SHADOWS
    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
    		#pragma multi_compile  _SHADOWS_SOFT
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);//定义贴图
            SAMPLER(sampler_MainTex);//定义采样器
            TEXTURE2D(_WindDistortionMap);
            SAMPLER(sampler_WindDistortionMap);
            TEXTURE2D(_FrameTex);
            SAMPLER(sampler_FrameTex);
            //----------贴图声明结束-----------

            //GPU Instance
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(half4, _BaseColor)
                UNITY_DEFINE_INSTANCED_PROP(float4,_MainTex_ST)
            
                UNITY_DEFINE_INSTANCED_PROP(float, _WindStrength)
                UNITY_DEFINE_INSTANCED_PROP(float, _U_Speed)
                UNITY_DEFINE_INSTANCED_PROP(float, _V_Speed)
                UNITY_DEFINE_INSTANCED_PROP(float4,_WindDistortionMap_ST)
                UNITY_DEFINE_INSTANCED_PROP(float,_Bias)
            
                UNITY_DEFINE_INSTANCED_PROP(float4,_FrameTex_ST)
                UNITY_DEFINE_INSTANCED_PROP(int,_FrameNum)
                UNITY_DEFINE_INSTANCED_PROP(float,_FrameRow)
                UNITY_DEFINE_INSTANCED_PROP(float,_FrameColumn)
                UNITY_DEFINE_INSTANCED_PROP(float,_FrameSpeed)
                UNITY_DEFINE_INSTANCED_PROP(float,_ShadowValue)
            
                UNITY_DEFINE_INSTANCED_PROP(float,_DecodeValue)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

            //SRP Bathcer
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            
            //----------变量声明结束-----------
            CBUFFER_END

            //AngleAxis3x3()接收一个角度（弧度制）并返回一个围绕提供轴旋转的矩阵
            float3x3 AngleAxis3x3(float angle, float3 axis)
            {
              float c, s;
              sincos(angle, s, c);

              float t = 1 - c;
              float x = axis.x;
              float y = axis.y;
              float z = axis.z;

              return float3x3(
	             t * x * x + c, t * x * y - s * z, t * x * z + s * y,
	             t * x * y + s * z, t * y * y + c, t * y * z - s * x,
	             t * x * z - s * y, t * y * z + s * x, t * z * z + c
	             );
            }

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float2 uv3 : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float3 posOS : TEXCOORD2;
                float4 color : TEXCOORD3;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                
                //Instance变量
                float windStrength = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_WindStrength);
                float2 windDistorationMap_FlowSpeed = float2(UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_U_Speed),UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_V_Speed));
                float4 windDistortionMap_ST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_WindDistortionMap_ST);
                float bias = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_Bias);
                
                float3 centerOffset = float3(0, 0, 0);
                
                #ifdef _EnableMultipleMeshMode
                    centerOffset = v.color;
                #endif

                #ifdef _EnableHoudiniDecodeMode
                    centerOffset = (float4(v.uv2,v.uv3)*2.0-1.0)*UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_DecodeValue);
                #endif
                v.vertex.xyz -= centerOffset;
                    
                //Billboard
                float3 camPosOS = TransformWorldToObject(_WorldSpaceCameraPos);//将摄像机的坐标转换到物体模型空间
                float3 newForwardDir = normalize(camPosOS - centerOffset); //计算新的forward轴
                float3 newRightDir = normalize(cross(float3(0, 1, 0), newForwardDir)); //计算新的right轴
                float3 newUpDir = normalize(cross(newForwardDir,newRightDir)); //计算新的up轴
                v.vertex.xyz = newRightDir * v.vertex.x + newUpDir * v.vertex.y + newForwardDir*v.vertex.z; //将原本的xyz坐标以在新轴上计算，相当于一个线性变换【原模型空间】->【新模型空间】
                
                //Wind
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz+centerOffset);
                float3 positionWS_0 = TransformObjectToWorld(float3(0,0,0)+centerOffset);
                windStrength = max(0.0001f,windStrength);
                float2 windUV = positionWS_0.xz*windDistortionMap_ST.xy + windDistortionMap_ST.zw + windDistorationMap_FlowSpeed*_Time.z;
                float2 windSample = ((SAMPLE_TEXTURE2D_LOD(_WindDistortionMap,sampler_WindDistortionMap, windUV,0).xy * 2 - 1)+bias) * windStrength;
                float3 wind = normalize(float3(windSample.x,0,windSample.y));
	            float3x3 windRotation = AngleAxis3x3(PI * windSample.x, newForwardDir);
                v.vertex.xyz = mul(windRotation,v.vertex.xyz);
                
                v.vertex.xyz += centerOffset;
                
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                o.posOS = v.vertex.xyz;
                o.color = v.color;
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(i);
                //Instance变量
                half3 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
                int frameNum = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _FrameNum);
                float frameRow = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _FrameRow);
                float frameColumn = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_FrameColumn);
                float frameSpeed = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_FrameSpeed);
                float shadowValue = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_ShadowValue);
                float4 frameTex_ST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial,_FrameTex_ST);
                
                float3 posWS = TransformObjectToWorld(i.posOS);
                float4 mainShadowCoord = TransformWorldToShadowCoord(posWS);
                Light mainLight = GetMainLight(mainShadowCoord);
                float3 nDirWS = i.nDirWS;
                float3 lDirWS = mainLight.direction.xyz;
                
                float2 mainTexUV;
                half4 mainTex;
                #ifdef _EnableFrameTexture
                    mainTexUV = i.uv * frameTex_ST.xy + frameTex_ST.zw;
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
                    mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainTexUV);
                #endif

                //shadow
            	float shadow = MainLightRealtimeShadow(mainShadowCoord);

                float halfLambert = dot(nDirWS,lDirWS)*0.5+0.5;
                half4 albedo = mainTex;
                
                half3 finalRGB = albedo*baseColor;
                finalRGB = lerp(finalRGB*shadowValue,finalRGB,shadow);

                clip(albedo.a-0.1);
                half4 result = half4(finalRGB,albedo.a);
                return result;
            }
            
            ENDHLSL
        }
    }
}