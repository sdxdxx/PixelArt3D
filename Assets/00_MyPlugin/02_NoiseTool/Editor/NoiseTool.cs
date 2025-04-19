using System;
using System.IO;
using UnityEditor;
using UnityEngine;

public class NoiseTool : EditorWindow
{
    [MenuItem("Tools/Noise Generator")]
    static void AddWindow()
    {
        Rect rect = new Rect(0, 0, 400, 600);
        NoiseTool window = (NoiseTool)EditorWindow.GetWindowWithRect(typeof(NoiseTool), rect, true, "Noise Generator");
        window.Show();
    }

    public enum TextureMode { Texture2D, Texture3D };//贴图模式
    public enum NoiseType2D { Perlin, Worley};//噪声类型2D
    public enum NoiseType3D { Perlin, Worley, PerlinWorley };//噪声类型3D
    public enum TextureSize {x64=64,x128=128, x256=256,x512=512,x1024=1024,x2048=2048};//噪声分辨率

    private ComputeShader computeShader;
    private string textureName = "Noise";
    private TextureMode texMode = TextureMode.Texture2D;
    private NoiseType2D _noiseType2D = NoiseType2D.Worley;
    private NoiseType3D _noiseType3D = NoiseType3D.PerlinWorley;
    private RenderTextureFormat format=RenderTextureFormat.ARGB32;
    private TextureSize size = TextureSize.x128;
    private float scale = 10f;

    RenderTexture renderTexture;
    RenderTexture tempTexture;
    int kernel;
    Texture2D texture2D; 
    Texture3D texture3D;
    string path;

    private void OnEnable()
    {
        path = "Assets";
    }

    private void OnGUI()
    {
        computeShader = Resources.Load<ComputeShader>("NoiseToolCS");
        computeShader = EditorGUILayout.ObjectField("Compute Shader:", computeShader,
            typeof(ComputeShader), true) as ComputeShader;

        textureName = EditorGUILayout.TextField("Texture Name", textureName);
        texMode = (TextureMode)EditorGUILayout.EnumPopup("Texture Mode：", texMode);

        if (texMode == TextureMode.Texture2D)
        {
            _noiseType2D =(NoiseType2D)EditorGUILayout.EnumPopup("Texture Type：", _noiseType2D);
        }
        
        if (texMode==TextureMode.Texture3D)
        {
            _noiseType3D =(NoiseType3D)EditorGUILayout.EnumPopup("Texture Type：", _noiseType3D);
        }
        
        format = (RenderTextureFormat)EditorGUILayout.EnumPopup("Texture Format：", format);
        size=(TextureSize)EditorGUILayout.EnumPopup("Texture Size：", size);
        scale = EditorGUILayout.Slider("Noise Scale:",scale, 1f, 40f);
        path = EditorGUILayout.TextField("Asset Path",path);

            if (GUILayout.Button("Build Noise !"))
        {
            if(computeShader==null)
            {
                ShowNotification(new GUIContent("Compute Shader Can Not Be Empty"));
            }
            else
            {
                Init();
            }
        }
        if(renderTexture!=null)
        {
            int x = 390;
            Rect rect = new Rect(5, 240, x, x);
            if (texMode == TextureMode.Texture2D)
            {
                //Texture2D模式清除tempTexture
                if (tempTexture!=null)
                {
                    tempTexture.Release();
                }
                
                //Texture2D模式清除原先的renderTexture
                if (renderTexture.volumeDepth>1)
                {
                    renderTexture.Release();
                    return;
                }
                
                GUI.DrawTexture(rect, renderTexture);
            }
            else if(tempTexture!=null)
            {
                //Texture3D模式清除原先的renderTexture
                if (renderTexture.volumeDepth<64)
                {
                    renderTexture.Release();
                    return;
                }
                
                GUI.DrawTexture(rect, tempTexture);
            }
            
        }
        if (GUILayout.Button("Save"))
        {
            if(renderTexture == null)
            {
                ShowNotification(new GUIContent("Texture Is Null"));
            }
            else
            {
                if (texMode==TextureMode.Texture2D)
                {
                    SaveTexture_2D();
                }

                if (texMode == TextureMode.Texture3D)
                {
                    SaveTexture_3D();
                }
                AssetDatabase.Refresh();
                ShowNotification(new GUIContent("Save Successfully !"));
            }
        }
    }

    private RenderTexture CreateRT_2D(int size)
    {
        RenderTexture renderTexture = new RenderTexture(size, size, 24, format);
        renderTexture.enableRandomWrite = true;
        renderTexture.wrapMode = TextureWrapMode.Repeat;
        renderTexture.Create();
        return renderTexture;
    }
    
    private RenderTexture CreateRT_3D(int size)
    {
        RenderTexture renderTexture = new RenderTexture(size, size, 0, format);
        renderTexture.enableRandomWrite = true;
        renderTexture.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
        renderTexture.volumeDepth = size;
        renderTexture.Create();
        return renderTexture;
    }

    void Init()
    {
        if (texMode == TextureMode.Texture2D)
        {
            renderTexture = CreateRT_2D((int)size);
            kernel = computeShader.FindKernel("NoiseToolCS_2D");
            computeShader.SetTexture(kernel, "Result2D", renderTexture);
            computeShader.SetInt("size", (int)size);
            computeShader.SetFloat("scale", scale);
            computeShader.SetInt("Type", (int)_noiseType2D);
            computeShader.Dispatch(kernel, (int)size / 8, (int)size / 8, 1);
        }
        
        if (texMode == TextureMode.Texture3D)
        {
            renderTexture = CreateRT_3D((int)size);
            tempTexture = CreateRT_2D((int)size);
            kernel = computeShader.FindKernel("NoiseToolCS_3D");
            computeShader.SetTexture(kernel,"Result3D",renderTexture);
            computeShader.SetInt("size", (int)size);
            computeShader.SetFloat("scale", scale);
            computeShader.SetInt("Type", (int)_noiseType3D);
            computeShader.Dispatch(kernel, (int)size / 8, (int)size / 8, (int)size/8);
            tempTexture = Copy3DSliceToRenderTexture(0, renderTexture);
        }

    }
    
    protected Texture2D ConvertFromRenderTexture(RenderTexture rt)
    {
        RenderTexture.active = rt;
        Texture2D output = new Texture2D((int)size, (int)size);
        output.ReadPixels(new Rect(0,0,(int)size, (int)size), 0, 0);
        output.Apply();
        return output;
    }

    void SaveTexture_2D()
    {
        RenderTexture previous = RenderTexture.active;
        RenderTexture.active = renderTexture;
        texture2D = ConvertFromRenderTexture(renderTexture);
        RenderTexture.active = previous;
        
        //生成Texture2D
        //AssetDatabase.CreateAsset(texture2D, path+ "/"+textureName+".asset");

        //生成TGA
        byte[] bytes = texture2D.EncodeToTGA();
        File.WriteAllBytes(path+"/"+textureName+".tga", bytes);
    }
    
    RenderTexture Copy3DSliceToRenderTexture(int layer, RenderTexture renderTexture)
    {
        RenderTexture render = new RenderTexture((int)size, (int)size, 0, RenderTextureFormat.ARGB32);
        render.dimension = UnityEngine.Rendering.TextureDimension.Tex2D;
        render.enableRandomWrite = true;
        render.wrapMode = TextureWrapMode.Clamp;
        render.Create();

        int kernelIndex = computeShader.FindKernel("Texture3DSlicer");
        computeShader.SetTexture(kernelIndex, "noise", renderTexture);
        computeShader.SetInt("layer", layer);
        computeShader.SetTexture(kernelIndex, "Result2D", render);
        computeShader.Dispatch(kernelIndex, (int)size/32, (int)size/32, 1);
        
        return render;
    }
    
    void SaveTexture_3D()
    {
        RenderTexture previous = RenderTexture.active;
        RenderTexture.active = renderTexture;
        
        texture3D = new Texture3D((int)renderTexture.width, (int)renderTexture.height, (int)renderTexture.volumeDepth, TextureFormat.ARGB32, true);
        texture3D.filterMode = FilterMode.Trilinear;
        
        //切片
        RenderTexture[] layers = new RenderTexture[(int)size];
        for(int i = 0; i < (int)size; i++)
            layers[i] = Copy3DSliceToRenderTexture(i,renderTexture);
        
        //切片保存
        Texture2D[] finalSlices = new Texture2D[(int)size];
        for(int i = 0; i < (int)size; i++)
            finalSlices[i] = ConvertFromRenderTexture(layers[i]);
        
        Color[] outputPixels = texture3D.GetPixels();
        for(int k = 0; k < (int)size; k++)
        {
            Color[] layerPixels = finalSlices[k].GetPixels();
            for(int i = 0; i < (int)size; i++){
                for(int j = 0; j < (int)size; j++){
                    outputPixels[i + j * (int)size + k * (int)size * (int)size] = layerPixels[i+j*(int)size];
                }
            }
        }
        
        RenderTexture.active = previous;

        texture3D.SetPixels(outputPixels);
        texture3D.Apply();

        //生成Texture3D
        AssetDatabase.CreateAsset(texture3D, path+"/"+textureName+".asset");

        //清空临时变量
        foreach (var variable in layers)
        {
            variable.Release();
        }
    }
    
    private void OnDisable()
    {
        if (renderTexture != null)
        { 
            renderTexture.Release(); 
        }
        
        if (tempTexture !=null )
        {
            tempTexture.Release();
        }
        
    }
}

