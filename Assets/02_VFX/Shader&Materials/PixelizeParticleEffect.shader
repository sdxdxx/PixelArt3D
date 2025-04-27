Shader "URP/VFX/PixelizeParticleEffect"
{
    Properties
    {
        [Header(Mode)]
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc("Blend Src Factor", float) = 5   //SrcAlpha
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst("Blend Dst Factor", float) = 10  //OneMinusSrcAlpha
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", float) = 2 //Back
        
        [Space(20)]
        
        [Header(FrameTexture)]
        [Toggle(_EnableFrameTexture)] _EnableFrameTexture("Enable Frame Texture",float) = 0
        _FrameTex("Sprite Frame Texture", 2D) = "white" {}
        _FrameNum("Frame Num",int) = 24
        _FrameRow("Frame Row",int) = 5
        _FrameColumn("Frame Column",int) = 5
        _FrameSpeed("Frame Speed",Range(0,10)) = 3
        _FrameOffset("Frame Offset",Range(0,1)) = 0
        
        [Space(20)]
        
        [Header(MainTex)]
        _MainTex("MainTex",2D) = "white"{}
        
        [Space(20)]
        
        [Header(Parameter)]
        [IntRange]_DownSampleValue("Down Sample Value",Range(0,7)) = 0
        [HDR]_BaseColor("Base Color",Color) = (1.0,1.0,1.0,1.0)
        _AlphaClip("Alpha Clip",Range(0,1)) = 0
        
    }
    
    SubShader
    {
         Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
        }
         
         pass
        {
            Lighting Off
            Blend [_BlendSrc] [_BlendDst]
            Cull[_CullMode]
            ZWrite Off
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature _EnableFrameTexture
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
            
            //----------贴图声明开始-----------
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_FrameTex);
            SAMPLER(sampler_FrameTex);
            //----------贴图声明结束-----------
            
            CBUFFER_START(UnityPerMaterial)
            //----------变量声明开始-----------
            int _FrameNum;
            int _FrameRow;
            int _FrameColumn;
            float _FrameSpeed;
            half4 _BaseColor;
            float4 _MainTex_ST;
            float4 _FrameTex_ST;
            float _DownSampleValue;
            float _AlphaClip;
            float _FrameOffset;
            //----------变量声明结束-----------
            CBUFFER_END

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
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
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            half4 frag (vertexOutput i) : SV_TARGET
            {
                
                float downSampleValue = pow(2,10-_DownSampleValue);
                float2 centerUV = float2(0.5,0.5)/downSampleValue;
                float2 pixelizeUV = floor(i.uv*downSampleValue-centerUV)/downSampleValue+centerUV;

                float2 mainTexUV;
                half4 mainTex;
                #ifdef _EnableFrameTexture
                    mainTexUV = pixelizeUV * _FrameTex_ST.xy + _FrameTex_ST.zw;
                    float perX = 1.0f /_FrameRow;
                    float perY = 1.0f /_FrameColumn;
                    float currentIndex = fmod(_Time.z*_FrameSpeed+_FrameOffset*_FrameNum,_FrameNum);
                    int rowIndex = currentIndex/_FrameRow;
                    int columnIndex = fmod(currentIndex,_FrameColumn);
                    float2 realMainTexUV = mainTexUV*float2(perX,perY)+float2(perX*columnIndex,perY*rowIndex);
                    mainTex =   SAMPLE_TEXTURE2D(_FrameTex, sampler_FrameTex, realMainTexUV);
                #else
                    mainTexUV = pixelizeUV *_MainTex_ST.xy+_MainTex_ST.zw;
                    mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainTexUV);
                #endif
                half4 albedo = mainTex;
                clip(albedo.a-_AlphaClip);
                float4 result = float4(albedo.rgb*i.color.rgb*_BaseColor.rgb,albedo.a);
                return result;
            }
            
            ENDHLSL
        }
    }
}