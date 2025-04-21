Shader "URP/Snow"
{
    Properties
    {
        [Header(Main Layer)]
    	_MainTex("Main Texture",2D) = "white"{}
    	
    	[Header(PBR)]
        _ColorTint("Color Tint",Color) = (1.0,1.0,1.0,1.0)
        _DarkColor("Dark Color",Color) = (0,0,0,1.0)
    	_MetallicSmoothnessTex("Metallic Smoothness Texture",2D) = "white"{}
    	_Smoothness("Smoothness",Range(0,1)) = 0
    	_Metallic("Metallic",Range(0,1)) = 0
    	
    	[Header(Normal)]
    	_NormalMap("Normal Map",2D) = "bump"{}
    	_NormalInt("Normal Intensity",Range(0,5)) = 1
    	_Normal2HeightInt("Normal To Height Map Intensity",Range(0,1)) = 0.5
        
        _Tess("Tessellation", Range(1, 32)) = 20
        _Height("Height",Range(0,1)) = 1
        [Toggle(_EnableTessDis)]_EnableTessDis("Enable Tess Distance",float) = 0.0
        _MaxTessDistance("Max Tess Distance", Range(1, 32)) = 20
        _MinTessDistance("Min Tess Distance", Range(1, 32)) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
            "Queue"="Geometry"
        }
        
        //解决深度引动模式Depth Priming Mode问题
        UsePass "Universal Render Pipeline/Lit/DepthOnly"
        UsePass "Universal Render Pipeline/Lit/DepthNormals"
        
        HLSLINCLUDE
        // Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
    		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
    	

    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS
    		#pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
    		#pragma multi_compile  _SHADOWS_SOFT
    	
    		#define kDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04)

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float _Tess;
            float _MaxTessDistance;
            float _MinTessDistance;
            float _Height;

            half4 _ColorTint;
            half4 _DarkColor;

    		float _NormalInt;
			float _Normal2HeightInt;
    		float4 _NormalMap_ST;
            
            float _Smoothness;
            float _Metallic;
    	
            half4 _RimCol;
            float _RimWidth;
            CBUFFER_END
            
			TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
			TEXTURE2D(_HeightMap);
            SAMPLER(sampler_HeightMap);
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
    		TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
    		TEXTURE2D(_MetallicSmoothnessTex);
            SAMPLER(sampler_MetallicSmoothnessTex);

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

			float3 Height2Normal(float intensity, float2 uv)
            {
	            float color0 =  SAMPLE_TEXTURE2D_LOD(_HeightMap,sampler_HeightMap, uv+half4(-1,0,0,0)*0.004,0);
            	float color1 = SAMPLE_TEXTURE2D_LOD(_HeightMap,sampler_HeightMap, uv+half4(1,0,0,0)*0.004,0);
            	float color2 = SAMPLE_TEXTURE2D_LOD(_HeightMap,sampler_HeightMap, uv+half4(0,-1,0,0)*0.004,0);
            	float color3 = SAMPLE_TEXTURE2D_LOD(_HeightMap,sampler_HeightMap, uv+half4(0,1,0,0)*0.004,0);

            	float2 ddxy = float2(color0 - color1, color2-color3);
            	float3 normal = float3((ddxy*intensity*5),1.0);
            	normal = normalize(normal);
            	return normal;
            }

            // 顶点着色器的输入
            struct Attributes
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            	float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            // 片段着色器的输入
            struct Varyings
            {
                float4 color : COLOR;
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 posWS:TEXCOORD1;
            	float3 nDirWS : TEXCOORD2;
            	float3 tDirWS : TEXCOORD3;
            	float3 bDirWS : TEXCOORD4;
            	float4 shadowCoord : TEXCOORD5;
            };

            // 为了确定如何细分三角形，GPU使用了四个细分因子。三角形面片的每个边缘都有一个因数。
            // 三角形的内部也有一个因素。三个边缘向量必须作为具有SV_TessFactor语义的float数组传递。
            // 内部因素使用SV_InsideTessFactor语义
            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };

            // 该结构的其余部分与Attributes相同，只是使用INTERNALTESSPOS代替POSITION语意，否则编译器会报位置语义的重用
            struct ControlPoint
            {
                float4 vertex : INTERNALTESSPOS;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
                float3 normal : NORMAL;
            	float4 tangent : TANGENT;
            };

            // 顶点着色器，此时只是将Attributes里的数据递交给曲面细分阶段
            ControlPoint BeforeTessVertProgram(Attributes v)
            {
                ControlPoint p;
        
                p.vertex = v.vertex;
                p.uv = v.uv;
                p.normal = v.normal;
                p.color = v.color;
            	p.tangent = v.tangent;
        
                return p;
            }

            // 随着距相机的距离减少细分数
            float CalcDistanceTessFactor(float4 vertex, float minDist, float maxDist, float tess)
            {
                float result = tess;
                
                #ifdef _EnableTessDis
                float3 worldPosition = TransformObjectToWorld(vertex.xyz);
                float dist = distance(worldPosition,  GetCameraPositionWS());
                float f = clamp(1.0 - (dist - minDist) / (maxDist - minDist), 0.01, 1.0) * tess;
                result = f;
                # endif
                
                return (result);
            }
            
            // Patch Constant Function决定Patch的属性是如何细分的。这意味着它每个Patch仅被调用一次，
            // 而不是每个控制点被调用一次。这就是为什么它被称为常量函数，在整个Patch中都是常量的原因。
            // 实际上，此功能是与HullProgram并行运行的子阶段。
            // 三角形面片的细分方式由其细分因子控制。我们在MyPatchConstantFunction中确定这些因素。
            // 当前，我们根据其距离相机的位置来设置细分因子
            TessellationFactors MyPatchConstantFunction(InputPatch<ControlPoint, 3> patch)
            {
                float minDist = _MinTessDistance;
                float maxDist = _MaxTessDistance;
            
                TessellationFactors f;
            
                float edge0 = CalcDistanceTessFactor(patch[0].vertex, minDist, maxDist, _Tess);
                float edge1 = CalcDistanceTessFactor(patch[1].vertex, minDist, maxDist, _Tess);
                float edge2 = CalcDistanceTessFactor(patch[2].vertex, minDist, maxDist, _Tess);
            
                // make sure there are no gaps between different tessellated distances, by averaging the edges out.
                f.edge[0] = (edge1 + edge2) / 2;
                f.edge[1] = (edge2 + edge0) / 2;
                f.edge[2] = (edge0 + edge1) / 2;
                f.inside = (edge0 + edge1 + edge2) / 3;
                return f;
            }

            //细分阶段非常灵活，可以处理三角形，四边形或等值线。我们必须告诉它必须使用什么表面并提供必要的数据。
            //这是 hull 程序的工作。Hull 程序在曲面补丁上运行，该曲面补丁作为参数传递给它。
            //我们必须添加一个InputPatch参数才能实现这一点。Patch是网格顶点的集合。必须指定顶点的数据格式。
            //现在，我们将使用ControlPoint结构。在处理三角形时，每个补丁将包含三个顶点。此数量必须指定为InputPatch的第二个模板参数
            //Hull程序的工作是将所需的顶点数据传递到细分阶段。尽管向其提供了整个补丁，
            //但该函数一次仅应输出一个顶点。补丁中的每个顶点都会调用一次它，并带有一个附加参数，
            //该参数指定应该使用哪个控制点（顶点）。该参数是具有SV_OutputControlPointID语义的无符号整数。
            [domain("tri")]//明确地告诉编译器正在处理三角形，其他选项：
            [outputcontrolpoints(3)]//明确地告诉编译器每个补丁输出三个控制点
            [outputtopology("triangle_cw")]//当GPU创建新三角形时，它需要知道我们是否要按顺时针或逆时针定义它们
            [partitioning("fractional_odd")]//告知GPU应该如何分割补丁，现在，仅使用整数模式
            [patchconstantfunc("MyPatchConstantFunction")]//GPU还必须知道应将补丁切成多少部分。这不是一个恒定值，每个补丁可能有所不同。必须提供一个评估此值的函数，称为补丁常数函数（Patch Constant Functions）
            ControlPoint hull(InputPatch<ControlPoint, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }

			Varyings AfterTessVertProgram (Attributes v)
			{
				Varyings o;
                float height = SAMPLE_TEXTURE2D_LOD(_HeightMap,sampler_HeightMap,v.uv,0).r*_Height;
				o.vertex = TransformObjectToHClip(v.vertex+v.normal*height);
				o.uv = v.uv;
				o.posWS = TransformObjectToWorld(v.vertex+v.normal*height);
            	o.nDirWS = TransformObjectToWorldNormal(v.normal);
            	o.tDirWS = normalize(TransformObjectToWorld(v.tangent));
            	o.bDirWS = normalize(mul(o.nDirWS,o.tDirWS)*v.tangent.w);
            	o.color = v.color;
            	o.shadowCoord = TransformWorldToShadowCoord(o.posWS);
                return o;
			}

            //HUll着色器只是使曲面细分工作所需的一部分。一旦细分阶段确定了应如何细分补丁，
            //则由Domain着色器来评估结果并生成最终三角形的顶点。
            //Domain程序将获得使用的细分因子以及原始补丁的信息，原始补丁在这种情况下为OutputPatch类型。
            //细分阶段确定补丁的细分方式时，不会产生任何新的顶点。相反，它会为这些顶点提供重心坐标。
            //使用这些坐标来导出最终顶点取决于域着色器。为了使之成为可能，每个顶点都会调用一次域函数，并为其提供重心坐标。
            //它们具有SV_DomainLocation语义。
            //在Demain函数里面，我们必须生成最终的顶点数据。
            [domain("tri")]//Hull着色器和Domain着色器都作用于相同的域，即三角形。我们通过domain属性再次发出信号
            Varyings domain(TessellationFactors factors, OutputPatch<ControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
            {
                Attributes v;
        
                //为了找到该顶点的位置，我们必须使用重心坐标在原始三角形范围内进行插值。
                //X，Y和Z坐标确定第一，第二和第三控制点的权重。
                //以相同的方式插值所有顶点数据。让我们为此定义一个方便的宏，该宏可用于所有矢量大小。
                #define DomainInterpolate(fieldName) v.fieldName = \
                        patch[0].fieldName * barycentricCoordinates.x + \
                        patch[1].fieldName * barycentricCoordinates.y + \
                        patch[2].fieldName * barycentricCoordinates.z;
    
                    //对位置、颜色、UV、法线等进行插值
                    DomainInterpolate(vertex)
                    DomainInterpolate(uv)
                    DomainInterpolate(color)
                    DomainInterpolate(normal)
            		DomainInterpolate(tangent)
                    
                    //现在，我们有了一个新的顶点，该顶点将在此阶段之后发送到几何程序或插值器。
                    //但是这些程序需要Varyings数据，而不是Attributes。为了解决这个问题，
                    //我们让域着色器接管了原始顶点程序的职责。
                    //这是通过调用其中的AfterTessVertProgram（与其他任何函数一样）并返回其结果来完成的。
                    return AfterTessVertProgram(v);
            }
            
            // 片段着色器
            half4 frag(Varyings i) : SV_TARGET 
            {
            	
                //MainTex
            	float2 mainTexUV = i.uv *_MainTex_ST.xy+_MainTex_ST.zw;
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,mainTexUV);
            	mainTex.rgb *=_ColorTint.rgb; 
            	
            	//TBN Matrix & SampleNormalMap
				 float3x3 TBN = float3x3(i.tDirWS,i.bDirWS,i.nDirWS);
            	float2 normalUV = i.uv*_NormalMap_ST.xy+_NormalMap_ST.zw;
            	float4 packedNormal = SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,normalUV);
            	float3 var_NormalMap = UnpackScaleNormal(packedNormal,_NormalInt);
            	float3 normal  = Height2Normal(_Normal2HeightInt,i.uv);
            	float3 final_Normal = NormalBlendReoriented(var_NormalMap,normal);

				//Vector
				float3 nDir = normalize(mul(final_Normal,TBN));
            	float3 nDirVS = normalize(mul((float3x3)UNITY_MATRIX_V, nDir));
            	float3 lDir = normalize(_MainLightPosition.xyz);
            	float3 vDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
            	
            	//shadow
            	float shadow = MainLightRealtimeShadow(i.shadowCoord);

            	// Metallic & Smoothness
            	float4 MetallicSmoothnessTex = SAMPLE_TEXTURE2D(_MetallicSmoothnessTex,sampler_MetallicSmoothnessTex,i.uv).rgba;
            	float metallic = MetallicSmoothnessTex.r*_Metallic;
            	float smoothness = MetallicSmoothnessTex.a*_Smoothness;

            	//PBR
            	half3 result_RBR = CalculatePBRResult(nDir,lDir,vDir,mainTex,smoothness,metallic,shadow);
            	
                half4 result = half4(result_RBR,1.0);

                return result;
            }
        ENDHLSL
        
        Pass
        {
            Name "Pass"
            Tags 
            { 
                "LightMode" = "UniversalForward"
            }
            
            // Render State
            Cull Back
            ZTest LEqual
            ZWrite On

            HLSLPROGRAM

            #pragma require tessellation
            #pragma require geometry
            
            #pragma vertex BeforeTessVertProgram
            #pragma hull hull
            #pragma domain domain
            #pragma fragment frag

            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 4.6

            #pragma shader_feature _EnableTessDis
            
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

		#pragma require tessellation
        #pragma require geometry
        
        #pragma vertex BeforeTessVertProgram
        #pragma hull hull
        #pragma domain domain
        #pragma fragment frag_shadow

        #pragma prefer_hlslcc gles
        #pragma exclude_renderers d3d11_9x
        #pragma target 4.6

		half4 frag_shadow(Varyings i) : SV_TARGET
		{
			return 1;
		 }

		ENDHLSL
		}

    }
}