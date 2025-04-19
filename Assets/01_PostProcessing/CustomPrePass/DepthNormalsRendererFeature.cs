using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class DepthNormalsRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
     public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
        public LayerMask layerMask = 1;
    }
     
     //自定义的Pass
    class NormalPass : ScriptableRenderPass
    {
        FilteringSettings filtering;
        private List<ShaderTagId> shaderTagsList = new List<ShaderTagId>();
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "M_DepthNormalsPass";
        private ProfilingSampler m_ProfilingSampler = new(ProfilerTag);
        
        private RTHandle cameraColorRTHandle;//可以理解为GameView_RenderTarget的句柄
        private RTHandle depthTarget;
        private RTHandle tempRTHandle;

        //自定义Pass的构造函数(用于传参)
        public NormalPass(Settings settings)
        {
            filtering = new FilteringSettings(RenderQueueRange.all, settings.layerMask);//设置过滤器
            shaderTagsList.Add(new ShaderTagId("DepthNormals"));
            renderPassEvent = settings.renderPassEvent; //传入设置的渲染事件顺序(renderPassEvent在基类ScriptableRenderPass中)
        }

        public void GetDepthTempRT(ref RTHandle temp, in RenderingData data)
        {
            RenderTextureDescriptor desc = data.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 32;
            desc.colorFormat = RenderTextureFormat.Depth;
            if (desc.msaaSamples>1)
            {
                desc.bindMS = true;
                desc.msaaSamples = 2;
            }
            else
            {
                desc.bindMS = false;
                desc.msaaSamples = 1;
            }
            
            RenderingUtils.ReAllocateIfNeeded(ref temp, desc);
            
        }
        public void GetTempRT(ref RTHandle temp, in RenderingData data)
        {
            RenderTextureDescriptor desc = data.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0;
            desc.graphicsFormat = GraphicsFormat.R16G16B16A16_SNorm;
            RenderingUtils.ReAllocateIfNeeded(ref temp, desc);//使用该函数申请一张与相机大小一致的TempRT;
        }

        public void Setup(RTHandle cameraColor)
        {
            cameraColorRTHandle = cameraColor;
        }
        
        //此方法由渲染器在渲染相机之前调用
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            GetDepthTempRT(ref depthTarget, renderingData);
            ConfigureInput(ScriptableRenderPassInput.Color);
            GetTempRT(ref tempRTHandle,renderingData);//获取与摄像机大小一致的临时RT
            ConfigureTarget(tempRTHandle,depthTarget);
            ConfigureClear(ClearFlag.All, Color.black);
        }
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            
            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
            
            //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                // Ensure we flush our command-buffer before we render...
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
            
                var depthParams = new RenderStateBlock(RenderStateMask.Depth);
                DepthState depthState = new DepthState(writeEnabled: true, CompareFunction.LessEqual);
                depthParams.depthState = depthState;
            
                SortingCriteria sortingCriteria = SortingCriteria.CommonOpaque;
                var draw = CreateDrawingSettings(shaderTagsList, ref renderingData, sortingCriteria);
                context.DrawRenderers(renderingData.cullResults, ref draw, ref filtering);
            }
            cmd.SetGlobalTexture("_m_CameraNormalsTexture",tempRTHandle);
            
            context.ExecuteCommandBuffer(cmd);//执行CommandBuffer
            cmd.Clear();
            CommandBufferPool.Release(cmd);//释放CommandBuffer
        }
        
        //在完成渲染相机时调用
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
           
        }
        
        public void OnDispose() 
        {
            tempRTHandle?.Release();//如果tempRTHandle没被释放的话，会被释放
            depthTarget?.Release();
        }
    }
    
    class DepthPass : ScriptableRenderPass
    {
        FilteringSettings filtering;
        private List<ShaderTagId> shaderTagsList = new List<ShaderTagId>();
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "M_DepthPass";
        private ProfilingSampler m_ProfilingSampler = new(ProfilerTag);
        
        private RTHandle depthTarget;
        private RTHandle tempRTHandle;

        //自定义Pass的构造函数(用于传参)
        public DepthPass(Settings settings)
        {
            filtering = new FilteringSettings(RenderQueueRange.all, settings.layerMask);//设置过滤器
            shaderTagsList.Add(new ShaderTagId("DepthOnly"));
            renderPassEvent = settings.renderPassEvent; //传入设置的渲染事件顺序(renderPassEvent在基类ScriptableRenderPass中)
        }

        public void GetDepthTempRT(ref RTHandle temp, in RenderingData data)
        {
            RenderTextureDescriptor desc = data.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 32;
            desc.colorFormat = RenderTextureFormat.Depth;
            if (desc.msaaSamples>1)
            {
                desc.bindMS = true;
                desc.msaaSamples = 2;
            }
            else
            {
                desc.bindMS = false;
                desc.msaaSamples = 1;
            }
            
            RenderingUtils.ReAllocateIfNeeded(ref temp, desc);
            
        }
        public void GetTempRT(ref RTHandle temp, in RenderingData data)
        {
            RenderTextureDescriptor desc = data.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0;
            desc.colorFormat = RenderTextureFormat.R16;
            RenderingUtils.ReAllocateIfNeeded(ref temp, desc);//使用该函数申请一张与相机大小一致的TempRT;
        }

        //此方法由渲染器在渲染相机之前调用
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            GetDepthTempRT(ref depthTarget, renderingData);
            //depthTarget = renderingData.cameraData.renderer.cameraDepthTargetHandle;
            ConfigureInput(ScriptableRenderPassInput.Color);
            GetTempRT(ref tempRTHandle, renderingData);//获取与摄像机大小一致的临时RT
            ConfigureTarget(tempRTHandle,depthTarget);
            ConfigureClear(ClearFlag.All, Color.black);
        }
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
            
            //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                // Ensure we flush our command-buffer before we render...
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
            
                //var depthParams = new RenderStateBlock(RenderStateMask.Depth);
                //DepthState depthState = new DepthState(writeEnabled: true, CompareFunction.LessEqual);
                //depthParams.depthState = depthState;
            
                SortingCriteria sortingCriteria = SortingCriteria.CommonOpaque;
                var draw = CreateDrawingSettings(shaderTagsList, ref renderingData, sortingCriteria);
                context.DrawRenderers(renderingData.cullResults, ref draw, ref filtering);
            }
            cmd.SetGlobalTexture("_m_CameraDepthTexture",tempRTHandle);
            
            context.ExecuteCommandBuffer(cmd);//执行CommandBuffer
            cmd.Clear();
            CommandBufferPool.Release(cmd);//释放CommandBuffer
        }
        
        //在完成渲染相机时调用
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
           
        }
        
        public void OnDispose() 
        {
            tempRTHandle?.Release();//如果tempRTHandle没被释放的话，会被释放
            depthTarget?.Release();
        }
    }
    
    //-------------------------------------------------------------------------------------------------------
    private NormalPass m_NormalPass;
    private DepthPass m_DepthPass;
    public Settings settings = new Settings();
    
    //初始化时调用
    public override void Create()
    {
        m_NormalPass = new NormalPass(settings);
        m_DepthPass = new DepthPass(settings);
    }
    
    //每帧调用,将pass添加进流程
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_NormalPass);
        renderer.EnqueuePass(m_DepthPass);
    }

    //每帧调用,渲染目标初始化后的回调。这允许在创建并准备好目标后从渲染器访问目标
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        m_NormalPass.Setup(renderer.cameraColorTargetHandle);//可以理解为传入GameView_RenderTarget的句柄和相机渲染数据（相机渲染数据用于创建TempRT）
    }
    
    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        m_NormalPass.OnDispose();
        m_DepthPass.OnDispose();
    }
}


