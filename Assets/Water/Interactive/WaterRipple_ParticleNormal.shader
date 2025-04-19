Shader "URP/WaterRipple_ParticleNormal"
{
    Properties
    {
        _BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        //_ShapeRadius("Shape Radius",Range(0,1)) = 1
        _CircleRadiusSmooth("Circle Radius Smooth",Range(0,1)) = 1
        _CircleRadius("Circle Radius",Range(0,1)) = 1
        _CircleWidth("Circle Width",Range(0,1)) = 0.5
        _NormalInt("Normal Intensity",Range(0,1)) = 1
        _Opacity("Opacity",Range(0,1)) = 1
    }
    
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue"="Transparent"
            "RenderPipeline" = "UniversalPipeline"  
        }

        //解决深度引动模式Depth Priming Mode问题
        //UsePass "Universal Render Pipeline/Lit/DepthOnly"
        //UsePass "Universal Render Pipeline/Lit/DepthNormals"
        
        pass
        {
            Tags{"LightMode"="UniversalForward"}
            
            Blend One OneMinusSrcAlpha
            Zwrite Off
             
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
            half4 _BaseColor;
            //float _ShapeRadius;
            float _CircleRadiusSmooth;
            float _CircleRadius;
            float _CircleWidth;
            float _NormalInt;
            float _Opacity;
            float4 _MainTex_ST;
            //----------变量声明结束-----------
            CBUFFER_END

            //Remap
            float remap(float original_value, float original_min, float original_max, float new_min, float new_max)
             {
               return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
             }

            float CalculateBellShape(float2 uv, float ShapeRadius, float ShapeRadiusSmooth, float ShapeRadiusSmoothRange)
            {
                float2 centerPoint = float2(0.5f,0.5f);
                float maxPoint = distance(float2(0,0),float2(0.5,0.5));
                float distance0 = distance(uv,centerPoint);
                float distance0_Remap = distance0/(maxPoint*ShapeRadius);
                float range = 0;
                float value = smoothstep(ShapeRadiusSmoothRange, ShapeRadiusSmoothRange + ShapeRadiusSmooth, distance0_Remap);
                float result = 1-value;
                return result;
            }

            float CalculateCircle(float2 uv, float CircleWidth, float CircleRadiusSmooth, float CircleRadius)
            {
                float result = CalculateBellShape(uv,0.7,CircleRadiusSmooth,CircleRadius)
                - CalculateBellShape(uv,0.7-CircleWidth,CircleRadiusSmooth,CircleRadius);
                return result;
            }
            
            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct vertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 nDirWS : TEXCOORD1;
                float4 color : TEXCOORD2;
            };

            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.nDirWS = TransformObjectToWorldNormal(v.normal);
                o.uv = v.uv;
                o.color = v.color;
                return o;
            }

            
            half4 frag (vertexOutput i) : SV_TARGET
            {
                float circle =CalculateCircle(i.uv,_CircleWidth, _CircleRadiusSmooth, _CircleRadius);
                
                // CalculateNormal
                float color0 = CalculateCircle(i.uv + half4(-1, 0, 0, 0) * 0.004,_CircleWidth, _CircleRadiusSmooth, _CircleRadius);
                float color1 = CalculateCircle(i.uv + half4(1, 0, 0, 0) * 0.004,_CircleWidth, _CircleRadiusSmooth, _CircleRadius);
                float color2 = CalculateCircle(i.uv + half4(0, -1, 0, 0) * 0.004,_CircleWidth, _CircleRadiusSmooth, _CircleRadius);
                float color3 = CalculateCircle(i.uv + half4(0, 1, 0, 0) * 0.004,_CircleWidth, _CircleRadiusSmooth, _CircleRadius);

                float2 ddxy = float2(color0 - color1, color2 - color3);
                float3 normal = float3((ddxy * _NormalInt*50), 1.0);
                normal = normalize(normal);
                float4 finalColor = float4((normal*0.5+0.5) * circle * _Opacity*i.color.a, circle * _Opacity*i.color.a);
                
                return finalColor;
            }
            
            ENDHLSL
        }
    }
}