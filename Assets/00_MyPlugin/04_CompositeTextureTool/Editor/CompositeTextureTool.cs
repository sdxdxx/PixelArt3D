using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using System.IO;
using System;
using System.Threading;
using System.Threading.Tasks;
using System.Linq;

public class CompositeTextureTool : EditorWindow
{
    
    [MenuItem("Tools/Composite Texture Tool")]
    static void AddWindow()
    {
        Rect rect = new Rect(0, 0, 600, 500);
        CompositeTextureTool window = (CompositeTextureTool)EditorWindow.GetWindowWithRect(typeof(CompositeTextureTool), rect, true, "Composite Texture Tool");
        window.Show();
    }
    enum EmImgFormat
    {
        PNG = 0,
        JPG = 1,
        TGA = 2
    }
    static string filePath = "";
    static string outPath = "";

    static int impWidth;
    static int impHeight;

    static int outSizeIndex = 0;
    static int outWidth = 4096;
    static int outHeight = 4096;
    public static readonly string[] enumNames = Enum.GetNames(typeof(EmImgFormat));
    public static readonly string[] enumSizes = new string[] {
        "32","64","128","256","512","1024","2048","4096","8192"
    };
    static List<Task> task = new List<Task>();
    static TaskFactory taskfactory = new TaskFactory();
    public void Init()
    {
        isMerge = false;
        minSize = new Vector2(500, 540);
        outSizeIndex = enumSizes.Length - 1;
        outWidth = outHeight = int.Parse(enumSizes[outSizeIndex]);
    }
    static EmImgFormat emImgFormat = EmImgFormat.JPG;
    static EmImgFormat emOutFormat = EmImgFormat.PNG;
    static string[] strImgFormat = new string[]
    {
        "*.png",
        "*.jpg",
        "*.tga"
    };
    static string importImgFormat = "*.jpg";
    GUIStyle filePathStyle;
    static int maxProgress = 1;

    static float progress = 0f;
    static string proDesc = "";
    static bool isMerge = false;
    private void OnGUI()
    {
        GUILayout.BeginVertical();
        GUILayout.Space(10.0f);
        GUILayout.Label("序列帧图片设置", new GUILayoutOption[] { GUILayout.Width(100) });
        GUILayout.Space(10.0f);
        GUILayout.BeginHorizontal();
        GUILayout.Label("序列帧图片路径：", new GUILayoutOption[] { GUILayout.Width(100) });
        filePathStyle = new GUIStyle(GUI.skin.GetStyle("TextField"));
        filePathStyle.alignment = TextAnchor.LowerLeft;
        GUILayout.TextField(filePath, filePathStyle, new GUILayoutOption[] { GUILayout.Width(330) });
        GUILayout.Space(10.0f);
        if (GUILayout.Button("浏览", new GUILayoutOption[] { GUILayout.Width(40.0f) }))
        {
            filePath = EditorUtility.OpenFolderPanel("选择序列帧图片目录", Application.dataPath, "");
        }
        GUILayout.EndHorizontal();
        //异常显示
        if (string.IsNullOrEmpty(filePath))
        {
            ShowRedTipsLab("请选择序列帧图片目录路径");
        }
        //图片格式
        GUILayout.Space(10.0f);
        GUILayout.BeginHorizontal();
        GUILayout.Label("序列帧图片格式:", new GUILayoutOption[] { GUILayout.Width(100) });
        EditorGUI.BeginChangeCheck();
        emImgFormat = (EmImgFormat)EditorGUILayout.Popup("",(int)emImgFormat, enumNames, new GUILayoutOption[] { GUILayout.Width(330) });
        if (EditorGUI.EndChangeCheck())
        {
            importImgFormat = strImgFormat[(int)emImgFormat];
        }
        GUILayout.EndHorizontal();
        //序列帧尺寸设置
        GUILayout.Space(10.0f);
        GUILayout.BeginHorizontal();
        GUILayout.Label("序列帧图片尺寸：", new GUILayoutOption[] { GUILayout.Width(100) });
        GUILayout.Label("Width", new GUILayoutOption[] { GUILayout.Width(40) });
        impWidth = EditorGUILayout.IntField(impWidth, new GUILayoutOption[] { GUILayout.Width(80) });
        GUILayout.Label("Height", new GUILayoutOption[] { GUILayout.Width(40) });
        impHeight = EditorGUILayout.IntField(impHeight, new GUILayoutOption[] { GUILayout.Width(80) });
        GUILayout.EndHorizontal();
        if (impHeight <= 0 || impWidth <= 0)
        {
            ShowRedTipsLab("请设置序列帧图片尺寸");
        }else if ((impHeight & (impHeight - 1)) != 0 || (impWidth & (impWidth - 1)) != 0)
        {
            ShowRedTipsLab("输入的尺寸不是2的次幂");
        }
        GUILayout.Space(10.0f);
        GUILayout.Label("注意：请确保宽高为2的次幂", new GUILayoutOption[] { GUILayout.Width(500) });
        //导出设置
        GUILayout.Space(30.0f);
        GUILayout.Label("导出图片设置", new GUILayoutOption[] { GUILayout.Width(100) });
        GUILayout.Space(10.0f);
        GUILayout.BeginHorizontal();

        GUILayout.Label("导出图片路径：", new GUILayoutOption[] { GUILayout.Width(100) });
        GUIStyle tryStyle = new GUIStyle(GUI.skin.GetStyle("TextField"));
        tryStyle.alignment = TextAnchor.LowerLeft;
        GUILayout.TextField(outPath, tryStyle, new GUILayoutOption[] { GUILayout.Width(330) });
        GUILayout.Space(10.0f);
        if (GUILayout.Button("浏览", new GUILayoutOption[] { GUILayout.Width(40.0f) }))
        {
            outPath = EditorUtility.OpenFolderPanel("选择要导出的目录", Application.dataPath, "");
        }

        GUILayout.EndHorizontal();
        if (string.IsNullOrEmpty(outPath))
        {
            ShowRedTipsLab("请选择要导出的目录路径");
        }
        //导出尺寸设置
        GUILayout.Space(10.0f);
        GUILayout.BeginHorizontal();
        GUILayout.Label("导出图片大小:", new GUILayoutOption[] { GUILayout.Width(100) });
        EditorGUI.BeginChangeCheck();
        outSizeIndex = EditorGUILayout.Popup("", outSizeIndex, enumSizes, new GUILayoutOption[] { GUILayout.Width(330) });
        if (EditorGUI.EndChangeCheck())
        {
            outWidth = int.Parse(enumSizes[outSizeIndex]);
            outHeight = outWidth;
        }
        GUILayout.EndHorizontal();
        //导出图片格式
        GUILayout.Space(10.0f);
        GUILayout.BeginHorizontal();
        GUILayout.Label("导出图片格式:", new GUILayoutOption[] { GUILayout.Width(100) });
        emOutFormat = (EmImgFormat)EditorGUILayout.Popup("", (int)emOutFormat, enumNames, new GUILayoutOption[] { GUILayout.Width(330) });
        GUILayout.EndHorizontal();
        GUILayout.Space(10.0f);
        //执行
        if (GUILayout.Button("执行合并", new GUILayoutOption[] { GUILayout.Width(120.0f) }) && !isMerge)
        {
            //先做一系列检测
            if (!CheckIsValid())
            {
                Debug.LogError("参数检查未通过！");
                return;
            }
            isMerge = true;
            StartMerge();
        }
        GUILayout.EndVertical();
    }
    static void ShowRedTipsLab(string tips)
    {
        GUI.color = Color.red;
        GUILayout.Label(tips, new GUILayoutOption[] { GUILayout.Width(500) });
        GUI.color = Color.white;
    }
    public static void StartMerge()
    {
        proDesc = "开始读取序列帧图片";
        EditorUtility.DisplayProgressBar(proDesc, "", progress);
        Debug.Log(filePath);
        DirectoryInfo folder = new DirectoryInfo(filePath);
        var files = folder.GetFiles(importImgFormat);
        maxProgress = files.Length;
        Texture2D[] texture2Ds = new Texture2D[maxProgress];
        for (int i = 0; i < maxProgress; i++)
        {
            FileInfo file = files[i];
            FileStream fs = new FileStream(filePath + "/" + file.Name, FileMode.Open, FileAccess.Read);
            int byteLength = (int)fs.Length;
            byte[] imgBytes = new byte[byteLength];
            fs.Read(imgBytes, 0, byteLength);
            fs.Close();
            fs.Dispose();
            Texture2D t2d = new Texture2D(impWidth,impHeight);
            t2d.LoadImage(imgBytes);
            t2d.Apply();
            texture2Ds[i] = t2d;
            progress = (float)(i + 1) / maxProgress;
            EditorUtility.DisplayProgressBar(proDesc, file.Name, progress);
        }
        proDesc = "准备写入贴图";
        progress = 0f;
        EditorUtility.DisplayProgressBar(proDesc, "", progress);
        Texture2D tex = GetOutTex(texture2Ds);
        byte[] bytes = new byte[] { };
        string suffix = "";
        if(emOutFormat == EmImgFormat.PNG)
        {
            bytes = tex.EncodeToPNG();
            suffix = ".png";
        }
        else if(emOutFormat == EmImgFormat.JPG)
        {
            bytes = tex.EncodeToJPG();
            suffix = ".jpg";
        }
        else if(emOutFormat == EmImgFormat.TGA)
        {
            bytes = tex.EncodeToTGA();
            suffix = ".tga";
        }
        File.WriteAllBytes(outPath + "/output" + suffix, bytes);
        EditorUtility.ClearProgressBar();
        EditorApplication.ExecuteMenuItem("Assets/Refresh");
        isMerge = false;
    }
    public static Texture2D GetOutTex(Texture2D[] texs)
    {
        int len = texs.Length;
        if (len < 1) return null;
        Texture2D nTex = new Texture2D(outWidth, outHeight, TextureFormat.ARGB32, true);
        Color[] colors = new Color[outWidth * outHeight];
        int offsetW, offsetH;
        offsetW = 0;//横向写入偏移
        offsetH = 0;//纵向写入偏移
        //是否是宽图
        bool isHor = impWidth > impHeight;
        float ratio = isHor ? (float)impWidth / impHeight : (float)impHeight / impWidth;
        //根据数量计算单侧个数
        float oriCnt = Mathf.Sqrt(len / ratio);

        int littleCnt = Mathf.CeilToInt(oriCnt);
        int moreCnt = Mathf.CeilToInt(oriCnt * ratio);


        int wCnt = isHor ? littleCnt : moreCnt;
        //纵向个数
        int hCnt = isHor ? moreCnt : littleCnt;
        //单张高度
        int singleH = Mathf.FloorToInt(outHeight / hCnt);
        int singleW = Mathf.FloorToInt(outWidth / wCnt);
        //单张宽度
        Debug.Log(string.Format("计算得到单张图的width=={0}==height=={1}",singleW,singleH));
        Debug.Log(string.Format("计算得到单张图的wCnt=={0}==hCnt=={1}", wCnt, hCnt));
        int texIndex = 0;
        GetTextureCol(texs, ref colors, texIndex, singleW, singleH, offsetW, offsetH);
        proDesc = "图片合并完成，开始写入大图";
        EditorUtility.DisplayProgressBar(proDesc, "", progress);
        nTex.SetPixels(colors);
        nTex.Apply();
        return nTex;
    }
    static void GetTextureCol(Texture2D[] texs, ref Color[] colors, int texIndex,int singleW,int singleH,int offsetW,int offsetH)
    {
        proDesc = string.Format("写入第{0}张图片", texIndex + 1);
        Texture2D tex = texs[texIndex];
        EditorUtility.DisplayProgressBar(proDesc, tex.name, progress);
        for (int h = 0; h < singleH; h++)
        {
            for (int w = 0; w < singleW; w++)
            {
                Color color = tex.GetPixelBilinear((float)w / singleW, (float)h / singleH);
                int index = h * outWidth + w + offsetW + (offsetH * outHeight);
                try
                {
                    if (colors[index] == null)
                    {
                        colors[index] = color;
                        continue;
                    }
                    colors[index] = color;

                }catch(Exception e)
                {
                    Debug.LogError(e.ToString());
                }
            }

        }
        offsetW += singleW;
        if (offsetW + singleW > outWidth)
        {
            offsetH += singleH;
            offsetW = 0;
        }
        texIndex = texIndex + 1;
        progress = (float)texIndex / maxProgress;
        if (texIndex < texs.Length)
        {
            GetTextureCol(texs, ref colors, texIndex , singleW, singleH, offsetW, offsetH);
        }
    }

    static bool CheckIsValid()
    {
        bool ret = true;
        //路径检测
        if (string.IsNullOrEmpty(filePath))
        {
            return false;
        }
        if(string.IsNullOrEmpty(outPath))
        {
            return false;
        }
        //尺寸检测
        if(impHeight <= 0 || impWidth <= 0)
        {
            return false;
        }
        if(outWidth <= 0 || outHeight <= 0)
        {
            return false;
        }
        return ret;
    }
}