using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class PixelizeObject : ScriptableRendererFeature
{
    [System.Serializable]
     public class Settings
    {
        public LayerMask layerMask;
    }
    private static readonly RenderPassEvent pixelizeObjectMaskPassEvent = RenderPassEvent.BeforeRenderingPrePasses;
    private static readonly RenderPassEvent pixelizeObjectClearCartoonRenderPassEvent = RenderPassEvent.BeforeRenderingPrePasses;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
     
    //PixelizeObjectMaskPass
    class PixelizeObjectMaskPass : ScriptableRenderPass
    {
        private RenderingData renderingData;
        FilteringSettings filtering;
        private List<ShaderTagId> shaderTagsList = new List<ShaderTagId>();
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "Pixelize Object Mask Pass";
        private ProfilingSampler m_ProfilingSampler = new("Pixelize Object Mask");
        
        private RTHandle cameraColorRTHandle;//可以理解为GameView_RenderTarget的句柄
        private RTHandle depthTarget;
        private RTHandle maskRTHandle;

        //自定义Pass的构造函数(用于传参)
        public PixelizeObjectMaskPass(Settings settings)
        {
            filtering = new FilteringSettings(RenderQueueRange.all, settings.layerMask);//设置过滤器
            shaderTagsList.Add(new ShaderTagId("PixelizeObjectMaskPass"));
            renderPassEvent = pixelizeObjectMaskPassEvent;
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
            desc.colorFormat = RenderTextureFormat.ARGB64;
            RenderingUtils.ReAllocateIfNeeded(ref temp, desc);//使用该函数申请一张与相机大小一致的TempRT;
        }

        public void Setup(RTHandle cameraColor, RenderingData data)
        {
            cameraColorRTHandle = cameraColor;
            renderingData = data;
        }
        
        //此方法由渲染器在渲染相机之前调用
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            //depthTarget = renderingData.cameraData.renderer.cameraDepthTargetHandle;
            GetDepthTempRT(ref depthTarget,this.renderingData);
            ConfigureInput(ScriptableRenderPassInput.Color); //确认传入的参数类型为Color
            GetTempRT(ref maskRTHandle,this.renderingData);
            ConfigureTarget(maskRTHandle,depthTarget);
            ConfigureClear(ClearFlag.All, Color.black);
        }
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
            
            //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                //确保执行前清空
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                var depthParams = new RenderStateBlock(RenderStateMask.Depth);
                DepthState depthState = new DepthState(writeEnabled: true, CompareFunction.LessEqual);
                depthParams.depthState = depthState;
            
                SortingCriteria sortingCriteria = SortingCriteria.CommonOpaque;
                var draw = CreateDrawingSettings(shaderTagsList, ref renderingData, sortingCriteria);
                context.DrawRenderers(renderingData.cullResults, ref draw, ref filtering);
            }
            cmd.SetGlobalTexture("_PixelizeObjectMask",maskRTHandle);
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
            maskRTHandle?.Release();
            depthTarget?.Release();
        }
    }
    
    //Pixelize VFX Mask Pass
    class PixelizeVFXMaskPass : ScriptableRenderPass
    {
        private RenderingData renderingData;
        FilteringSettings filtering;
        private List<ShaderTagId> shaderTagsList = new List<ShaderTagId>();
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "Pixelize VFX Mask Pass";
        private ProfilingSampler m_ProfilingSampler = new("Pixelize VFX Mask");
        
        private RTHandle cameraColorRTHandle;//可以理解为GameView_RenderTarget的句柄
        private RTHandle depthTarget;
        private RTHandle maskRTHandle;

        //自定义Pass的构造函数(用于传参)
        public PixelizeVFXMaskPass(Settings settings)
        {
            filtering = new FilteringSettings(RenderQueueRange.all, settings.layerMask);//设置过滤器
            shaderTagsList.Add(new ShaderTagId("PixelizeVFXMaskPass"));
            renderPassEvent = pixelizeObjectMaskPassEvent;
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
            desc.colorFormat = RenderTextureFormat.ARGB64;
            RenderingUtils.ReAllocateIfNeeded(ref temp, desc);//使用该函数申请一张与相机大小一致的TempRT;
        }

        public void Setup(RTHandle cameraColor, RenderingData data)
        {
            cameraColorRTHandle = cameraColor;
            renderingData = data;
        }
        
        //此方法由渲染器在渲染相机之前调用
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            //depthTarget = renderingData.cameraData.renderer.cameraDepthTargetHandle;
            GetDepthTempRT(ref depthTarget,this.renderingData);
            ConfigureInput(ScriptableRenderPassInput.Color); //确认传入的参数类型为Color
            GetTempRT(ref maskRTHandle,this.renderingData);
            ConfigureTarget(maskRTHandle,depthTarget);
            ConfigureClear(ClearFlag.All, Color.black);
        }
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
            
            //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                //确保执行前清空
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                var depthParams = new RenderStateBlock(RenderStateMask.Depth);
                DepthState depthState = new DepthState(writeEnabled: true, CompareFunction.LessEqual);
                depthParams.depthState = depthState;
            
                SortingCriteria sortingCriteria = SortingCriteria.CommonOpaque;
                var draw = CreateDrawingSettings(shaderTagsList, ref renderingData, sortingCriteria);
                context.DrawRenderers(renderingData.cullResults, ref draw, ref filtering);
            }
            cmd.SetGlobalTexture("_PixelizeVFXMask",maskRTHandle);
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
            maskRTHandle?.Release();
            depthTarget?.Release();
        }
    }
    
    //PixelizeObjectCartoonPass
    class PixelizeObjectCartoonPass : ScriptableRenderPass
    {
        private RenderingData renderingData;
        FilteringSettings filtering;
        private List<ShaderTagId> shaderTagsList = new List<ShaderTagId>();
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "Pixelize Object Cartoon Pass";
        private ProfilingSampler m_ProfilingSampler = new("Pixelize Object Cartoon Pass");
        

        private RTHandle cameraColorRTHandle;
        private RTHandle depthTarget;
        private RTHandle tempRTHandle;

        //自定义Pass的构造函数(用于传参)
        public PixelizeObjectCartoonPass(Settings settings)
        {
            filtering = new FilteringSettings(RenderQueueRange.all, settings.layerMask);//设置过滤器
            shaderTagsList.Add(new ShaderTagId("PixelizeObjectCartoonPass"));
            shaderTagsList.Add(new ShaderTagId("PixelizeObjectOutlinePass"));
            renderPassEvent = pixelizeObjectClearCartoonRenderPassEvent;
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
            desc.colorFormat = RenderTextureFormat.ARGB32;
            RenderingUtils.ReAllocateIfNeeded(ref temp, desc);//使用该函数申请一张与相机大小一致的TempRT;
        }

        public void Setup(RTHandle cameraColor, RenderingData data)
        {
            cameraColorRTHandle = cameraColor;
            renderingData = data;
        }
        
        //此方法由渲染器在渲染相机之前调用
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            GetDepthTempRT(ref depthTarget,renderingData);
            ConfigureInput(ScriptableRenderPassInput.Color); //确认传入的参数类型为Color
            GetTempRT(ref tempRTHandle,renderingData);
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
                //确保执行前清空
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                SortingCriteria sortingCriteria = SortingCriteria.CommonOpaque;
                var draw = CreateDrawingSettings(shaderTagsList, ref renderingData, sortingCriteria);
                context.DrawRenderers(renderingData.cullResults, ref draw, ref filtering);
            }
            
            cmd.SetGlobalTexture("_PixelizeObjectCartoonTex",tempRTHandle);
            
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
            tempRTHandle?.Release();
            depthTarget?.Release();
        }
    }
    
    //PixelizeObjectCartoonPass
    class PixelizeVFXCartoonPass : ScriptableRenderPass
    {
        private RenderingData renderingData;
        FilteringSettings filtering;
        private List<ShaderTagId> shaderTagsList = new List<ShaderTagId>();
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "Pixelize VFX Cartoon Pass";
        private ProfilingSampler m_ProfilingSampler = new("Pixelize VFX Cartoon Pass");
        

        private RTHandle cameraColorRTHandle;
        private RTHandle depthTarget;
        private RTHandle tempRTHandle;

        //自定义Pass的构造函数(用于传参)
        public PixelizeVFXCartoonPass(Settings settings)
        {
            filtering = new FilteringSettings(RenderQueueRange.all,settings.layerMask);//设置过滤器
            shaderTagsList.Add(new ShaderTagId("PixelizeVFXCartoonPass"));
            renderPassEvent = pixelizeObjectClearCartoonRenderPassEvent;
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
            desc.colorFormat = RenderTextureFormat.ARGB32;
            RenderingUtils.ReAllocateIfNeeded(ref temp, desc);//使用该函数申请一张与相机大小一致的TempRT;
        }

        public void Setup(RTHandle cameraColor, RenderingData data)
        {
            cameraColorRTHandle = cameraColor;
            renderingData = data;
        }
        
        //此方法由渲染器在渲染相机之前调用
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            GetDepthTempRT(ref depthTarget,renderingData);
            ConfigureInput(ScriptableRenderPassInput.Color); //确认传入的参数类型为Color
            GetTempRT(ref tempRTHandle,renderingData);
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
                //确保执行前清空
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                SortingCriteria sortingCriteria = SortingCriteria.CommonOpaque;
                var draw = CreateDrawingSettings(shaderTagsList, ref renderingData, sortingCriteria);
                context.DrawRenderers(renderingData.cullResults, ref draw, ref filtering);
            }
            
            cmd.SetGlobalTexture("_PixelizeVFXCartoonTex",tempRTHandle);
            
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
            tempRTHandle?.Release();
            depthTarget?.Release();
        }
    }
    
    //PixelizeObjectCartoonOutlinePass_EditorMode
    class PixelizeObjectCartoonForDebugPass_EditorMode : ScriptableRenderPass
    {
        private RenderingData renderingData;
        FilteringSettings filtering;
        private List<ShaderTagId> shaderTagsList = new List<ShaderTagId>();
        
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "Pixelize Object Cartoon Pass_EditorMode";
        private ProfilingSampler m_ProfilingSampler = new("Pixelize Object Cartoon Pass_EditorMode");
        

        private RTHandle cameraColorRTHandle;
        private RTHandle depthTarget;
        private RTHandle tempRTHandle;

        //自定义Pass的构造函数(用于传参)
        public PixelizeObjectCartoonForDebugPass_EditorMode(Settings settings)
        {
            filtering = new FilteringSettings(RenderQueueRange.all);//设置过滤器
            //shaderTagsList.Add(new ShaderTagId("PixelizeObjectCartoonPass"));
            shaderTagsList.Add(new ShaderTagId("PixelizeObjectOutlinePass"));
            renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
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
            desc.colorFormat = RenderTextureFormat.ARGB32;
            RenderingUtils.ReAllocateIfNeeded(ref temp, desc);//使用该函数申请一张与相机大小一致的TempRT;
        }

        public void Setup(RTHandle cameraColor, RenderingData data)
        {
            cameraColorRTHandle = cameraColor;
            renderingData = data;
        }
        
        //此方法由渲染器在渲染相机之前调用
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ConfigureInput(ScriptableRenderPassInput.Color); //确认传入的参数类型为Color
        }
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {

             if (this.renderingData.cameraData.cameraType == CameraType.Game)
             {
                 return;
             }
            
            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
            
            //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                //确保执行前清空
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                SortingCriteria sortingCriteria = SortingCriteria.CommonOpaque;
                var draw = CreateDrawingSettings(shaderTagsList, ref renderingData, sortingCriteria);
                context.DrawRenderers(renderingData.cullResults, ref draw, ref filtering);
            }
            
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
            tempRTHandle?.Release();
            depthTarget?.Release();
        }
    }
    
    //-------------------------------------------------------------------------------------------------------
    private PixelizeObjectMaskPass pixelizeObjectMaskPass;
    private PixelizeObjectCartoonPass pixelizeObjectCartoonPass;
    private PixelizeObjectCartoonForDebugPass_EditorMode pixelizeObjectCartoonPass_EditorMode;
    
    private PixelizeVFXMaskPass pixelizeVFXMaskPass;
    private PixelizeVFXCartoonPass pixelizeVFXCartoonPass;
    public Settings settings = new Settings();
    
    //初始化时调用
    public override void Create()
    {
        pixelizeObjectMaskPass = new PixelizeObjectMaskPass(settings);
        pixelizeObjectCartoonPass = new PixelizeObjectCartoonPass(settings);
        pixelizeObjectCartoonPass_EditorMode = new PixelizeObjectCartoonForDebugPass_EditorMode(settings);

        pixelizeVFXMaskPass = new PixelizeVFXMaskPass(settings);
        pixelizeVFXCartoonPass = new PixelizeVFXCartoonPass(settings);
    }
    
    //每帧调用,将pass添加进流程
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pixelizeObjectMaskPass);
        renderer.EnqueuePass(pixelizeObjectCartoonPass);
        renderer.EnqueuePass(pixelizeObjectCartoonPass_EditorMode);
        
        renderer.EnqueuePass(pixelizeVFXMaskPass);
        renderer.EnqueuePass(pixelizeVFXCartoonPass);
    }

    //每帧调用,渲染目标初始化后的回调。这允许在创建并准备好目标后从渲染器访问目标
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        pixelizeObjectMaskPass.Setup(renderer.cameraColorTargetHandle,renderingData);//可以理解为传入GameView_RenderTarget的句柄和相机渲染数据（相机渲染数据用于创建TempRT）
        pixelizeObjectCartoonPass.Setup(renderer.cameraColorTargetHandle,renderingData);
        pixelizeObjectCartoonPass_EditorMode.Setup(renderer.cameraColorTargetHandle,renderingData);
        
        pixelizeVFXMaskPass.Setup(renderer.cameraColorTargetHandle,renderingData);
        pixelizeVFXCartoonPass.Setup(renderer.cameraColorTargetHandle,renderingData);
    }
    
    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        
        pixelizeObjectMaskPass.OnDispose();
        pixelizeObjectCartoonPass.OnDispose();
        pixelizeObjectCartoonPass_EditorMode.OnDispose();
        
        pixelizeVFXMaskPass.OnDispose();
        pixelizeVFXCartoonPass.OnDispose();
    }
}


