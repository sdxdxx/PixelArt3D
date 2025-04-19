Shader "Hidden/CustomPrePass/DepthNormals"
{
    Properties
    {
    }
    
    SubShader
    {
         Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }
         
         Pass
        {
        	Name "CustomNormalsPass"

        	Tags{"LightMode" = "CustomNormalsPass"}
        	
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
            	float rawDepth : TEXCOORD3;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
            	float4 posCS = TransformObjectToHClip(v.vertex.xyz);
            	float3 posWS = TransformObjectToWorld(v.vertex).xyz;
                float rawDepth;
            	//正交摄像机判断
            	if (unity_OrthoParams.w > 0.5)
            	{
            		float linearEyeDepth = LinearEyeDepth(posWS,unity_MatrixV);
            		rawDepth = 1-(linearEyeDepth - _ProjectionParams.y) / (_ProjectionParams.z - _ProjectionParams.y);
            	}
	            else
	            {
		            float linearEyeDepth = LinearEyeDepth(posWS,unity_MatrixV);
            		rawDepth = (rcp(linearEyeDepth)-_ZBufferParams.w)/_ZBufferParams.z;
	            }
            	o.rawDepth = rawDepth;
                o.pos = posCS;
                o.nDirWS = normalize(TransformObjectToWorldNormal(v.normal));
                o.uv = v.uv;
            	o.screenPos = ComputeScreenPos(posCS);
                return o;
            }

            float4 frag (vertexOutput i) : SV_TARGET
            {
            	float3 normalWS = NormalizeNormalPerPixel(i.nDirWS);
            	return float4(normalWS,1);
            }
            
            ENDHLSL
        }
         
    }
}