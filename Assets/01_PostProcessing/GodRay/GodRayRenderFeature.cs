using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class GodRayRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
     public class Settings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }
     
     //自定义的Pass
    class CustomRenderPass : ScriptableRenderPass
    {
        //定义一个 ProfilingSampler 方便设置在FrameDebugger里查看
        private const string ProfilerTag = "GodRay";
        private ProfilingSampler m_ProfilingSampler = new(ProfilerTag);
        
        private Material material;
        private GodRayVolume godRayVolume;

        private RTHandle cameraColorRTHandle;//可以理解为GameView_RenderTarget的句柄
        private RTHandle tempRTHandle00;
        private RTHandle tempRTHandle01;
        private RTHandle tempRTHandle02;

        //自定义Pass的构造函数(用于传参)
        public CustomRenderPass(Settings settings)
        {
            renderPassEvent = settings.renderPassEvent; //传入设置的渲染事件顺序(renderPassEvent在基类ScriptableRenderPass中)
            Shader shader = Shader.Find("URP/PostProcessing/GodRay");
            material = CoreUtils.CreateEngineMaterial(shader);//根据传入的Shader创建material;
        }

        public void GetTempRT(ref RTHandle temp, in RenderingData data, int downSample)
        {
            RenderTextureDescriptor desc = data.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0; //这步很重要！！！
            desc.height = desc.height / downSample;
            desc.width = desc.width / downSample;
            RenderingUtils.ReAllocateIfNeeded(ref temp, desc);//使用该函数申请一张与相机大小一致的TempRT;
        }

        public void Setup(RTHandle cameraColor)
        {
            cameraColorRTHandle = cameraColor;
        }
        
        //此方法由渲染器在渲染相机之前调用
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var stack = VolumeManager.instance.stack;//获取Volume的栈
            godRayVolume = stack.GetComponent<GodRayVolume>();//从栈中获取到ColorTintVolume
            GetTempRT(ref tempRTHandle01,renderingData,godRayVolume.DownSample.value);
            GetTempRT(ref tempRTHandle02,renderingData,godRayVolume.DownSample.value);
            GetTempRT(ref tempRTHandle00,renderingData,1);
            ConfigureInput(ScriptableRenderPassInput.Color); //确认传入的参数类型为Color
            ConfigureTarget(tempRTHandle01);//确认传入的目标为cameraColorRT
            
        }
        
        //执行传递。这是自定义渲染发生的地方
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(ProfilerTag);//获得一个为ProfilerTag的CommandBuffer
            
            var stack = VolumeManager.instance.stack;//获取Volume的栈
            godRayVolume = stack.GetComponent<GodRayVolume>();//从栈中获取到ColorTintVolume
            material.SetColor("_BaseColor", godRayVolume.ColorChange.value);//将材质颜色设置为volume中的值
            material.SetInt("_StepTime",godRayVolume.StepTime.value);
            material.SetFloat("_Intensity",godRayVolume.Intensity.value);
            material.SetFloat("_Scattering",godRayVolume.Scattering.value);
            material.SetFloat("_RandomNumber",godRayVolume.RandomNumber.value);
            material.SetFloat("_BlurRange",godRayVolume.BlurRange.value);
            
            if (godRayVolume.EnableEffect.value)
            {
                //性能分析器(自带隐式垃圾回收),之后可以在FrameDebugger中查看
                using (new ProfilingScope(cmd, m_ProfilingSampler))
                {
                    
                    Blitter.BlitCameraTexture(cmd,cameraColorRTHandle,tempRTHandle01,material,0);
                    Blitter.BlitCameraTexture(cmd,tempRTHandle01,tempRTHandle02,material,1);
                    material.SetTexture("_GodRayRangeTexture",tempRTHandle02);
                    Blitter.BlitCameraTexture(cmd, cameraColorRTHandle, tempRTHandle00);//写入渲染命令进CommandBuffer
                    Blitter.BlitCameraTexture(cmd,tempRTHandle00,cameraColorRTHandle,material,2);//写入渲染命令进CommandBuffer
                }
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
            tempRTHandle01?.Release();//如果tempRTHandle没被释放的话，会被释放
            tempRTHandle02?.Release();
            tempRTHandle00?.Release();
        }
    }

    //-------------------------------------------------------------------------------------------------------
    private CustomRenderPass m_ScriptablePass;
    public Settings settings = new Settings();
    
    //初始化时调用
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass(settings);
    }
    
    //每帧调用,将pass添加进流程
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }

    //每帧调用,渲染目标初始化后的回调。这允许在创建并准备好目标后从渲染器访问目标
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        m_ScriptablePass.Setup(renderer.cameraColorTargetHandle);//可以理解为传入GameView_RenderTarget的句柄和相机渲染数据（相机渲染数据用于创建TempRT）
    }
    
    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        m_ScriptablePass.OnDispose();
    }
}


