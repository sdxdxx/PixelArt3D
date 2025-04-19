using System;
using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEditor;
using UnityEngine;
using UnityEngine.Serialization;

public class VTXPainter_Window : EditorWindow
{
    #region Variables
    GUIStyle boxStyle;
    public Vector2 mousePos;
    public RaycastHit curHit;
    
    public bool allowPainting = false;

    public bool changingBrushValue = false;

    [FormerlySerializedAs("isPainting")] public bool isPreparePainting = false;

    public bool isFirstClickPaint = false;

    public float brushSize = 0.5f;
    public float brushOpacity = 1.0f;
    public float brushFalloff = 0.8f;

    public GameObject curGameObject;
    public Mesh curMesh;

    public Color foregroundColor;

    public LinkedList<Color[]> revokeList = new LinkedList<Color[]>();
    public int revokeMaxNum = 10;
    public int revokeNum = 0;

    #endregion
    
    #region Main Method

    public static void LaunchVertexPainter()
    {
        var window = EditorWindow.GetWindow<VTXPainter_Window>(false, "VTX Painter", true);//是否为浮动窗口 标题 是否聚焦
        window.GenerateStyles();
    }
    #endregion

    #region  GUI Method
    
    //相当于Update()
    private void OnGUI()
    {
        //默认纵向排列
        
        //Header
        GUILayout.BeginHorizontal();//横向排列开始
        GUILayout.Box("Vertex Painter",boxStyle,GUILayout.Height(60),GUILayout.ExpandWidth(true));
        GUILayout.EndHorizontal();//横向排列结束
        
        //Body
        GUILayout.BeginVertical(boxStyle);//纵向排列开始（设置boxStyle）
        
        GUILayout.Space(10);//空十个像素格
        
        allowPainting = GUILayout.Toggle(allowPainting, "Allow Painting", GUI.skin.button,GUILayout.Height(60));//设置allowPainting开关
        
        EditorGUILayout.BeginVertical();
        foregroundColor = EditorGUILayout.ColorField("Fore Ground Color", foregroundColor,GUILayout.Height(30f));//绘制的顶点颜色
        EditorGUILayout.EndVertical();
        
        GUILayout.BeginHorizontal();
        GUILayout.Label("Brush Size");
        brushSize = GUILayout.HorizontalSlider(brushSize, 0.01f, 10f,GUILayout.Height(30f));
        GUILayout.EndHorizontal();
        
        GUILayout.BeginHorizontal();
        GUILayout.Label("Brush Opacity");
        brushOpacity = GUILayout.HorizontalSlider(brushOpacity, 0f, 1f,GUILayout.Height(30f));
        GUILayout.EndHorizontal();
        
        GUILayout.BeginHorizontal();
        GUILayout.Label("Brush Falloff");
        brushFalloff = GUILayout.HorizontalSlider(brushFalloff, 0f, 1f,GUILayout.Height(30f));
        GUILayout.EndHorizontal();
        
        
        if (GUILayout.Button("Export Asset File",GUILayout.Height(60)) && Selection.activeObject != null)//保存文件按钮
        {
            string path =
                EditorUtility.SaveFilePanel("Export asset file", "Assets/VertexPainter/Editor/Data", Selection.activeObject.name + "_Modified", "asset");
            if (path.Length > 0)
            {
                var dataPath = Application.dataPath;
                if (!path.StartsWith(dataPath))
                {
                    Debug.LogError("Invalid path: Path must be under " + dataPath);
                }
                else
                {
                    path = path.Replace(dataPath, "Assets");
                    curMesh = VTXPainter_Utils.GetMesh(Selection.activeObject.GameObject());
                    Mesh finalResult = Instantiate(curMesh);
                    AssetDatabase.CreateAsset(finalResult, path);
                    
                    MeshFilter curFilter = Selection.activeObject.GameObject().GetComponent<MeshFilter>();
                    SkinnedMeshRenderer curSkinned = Selection.activeObject.GameObject().GetComponent<SkinnedMeshRenderer>();

                    if (curFilter && !curSkinned)
                    {
                        curFilter.sharedMesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
                    }

                    if (!curFilter && curSkinned)
                    {
                        curSkinned.sharedMesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
                    }

                    Debug.Log("Asset exported: " + path);
                }
            }
        }
        
        GUILayout.Space(10);//空十个像素格
        
        GUILayout.Label("Revoke: Ctrl + Shift + Z");
        GUILayout.Label("Undo: Ctrl + Shift + Y");
        GUILayout.Label("BrushSize: Ctrl + MouseDragLeft");
        GUILayout.Label("BrushOpacity: Shift + MouseDragLeft");
        GUILayout.Label("BrushFalloff: Ctrl + Shift + MouseDragLeft");
        
        GUILayout.FlexibleSpace();//自动填充的空格
        
        GUILayout.EndVertical();//纵向排列结束
        
        GUILayout.Box("",boxStyle,GUILayout.Height(60),GUILayout.ExpandWidth(true));

        Repaint();//反复刷新UI列表（刷新速度约为Update()的三倍）
    }
    
    //激活时执行
    private void OnEnable()
    {
        //这个步骤是为了让窗口激活时不选中物体也能一直执行OnSceneGUI里的命令
        SceneView.duringSceneGui-=this.OnSceneGUI;
        SceneView.duringSceneGui+=this.OnSceneGUI;
    }
    
    //销毁时执行
    private void OnDestroy()
    {
        SceneView.duringSceneGui-=this.OnSceneGUI;
    }

    private void Update()
    {
        if (allowPainting)
        {
            //获取Mesh
            if (Selection.activeObject != null)
            {
                curGameObject = Selection.activeObject.GameObject();
                curMesh = VTXPainter_Utils.GetMesh(curGameObject);
            }

            if (curMesh != null)
            {
                Selection.activeObject = null;//取消选择当前选择物体

                if (revokeList.Count>revokeMaxNum)
                {
                    revokeList.RemoveFirst();
                }

                if (revokeList.Count == 0)
                {
                    revokeList.AddLast(curMesh.colors);
                }
            }
            else
            {
                allowPainting = false;
                Debug.LogWarning("You haven't select game object yet");
            }
            
        }
        else
        {
            curGameObject = null;
            curMesh = null;
            revokeList.Clear();
            revokeNum = 0;
        }
        
        
       
    }

    void OnSceneGUI(SceneView sceneView)
    {
        /*
        Handles.BeginGUI();
        GUILayout.BeginArea(new Rect(50,10,200,100),boxStyle);//GUI.skin.box是Unity的默认boxStyle
        GUILayout.Button("Button",GUILayout.Height(25f));
        GUILayout.Button("Button",GUILayout.Height(25f));
        GUILayout.EndArea();
        Handles.EndGUI();
        */

        if (allowPainting)
        {
            if (curHit.transform != null)
            {
                Handles.color = Color.white;
                Handles.Label(curHit.point, curGameObject.name);//显示物品名字
                
                Handles.color = new Color(foregroundColor.r,foregroundColor.g,foregroundColor.b, brushOpacity*0.3f);//切换颜色
                Handles.DrawSolidDisc(curHit.point, curHit.normal,brushSize);//Solid意指填充颜色
                
                Handles.color = new Color(foregroundColor.r,foregroundColor.g,foregroundColor.b, brushOpacity*0.3f);//切换颜色
                Handles.DrawSolidDisc(curHit.point,curHit.normal,brushSize*brushFalloff);//Solid意指填充颜色
                
                Handles.color = Color.white;
                Handles.DrawWireDisc(curHit.point, curHit.normal,brushSize);//Wire意指线框

                Handles.color = new Color(0.7f, 0.7f, 0.7f,  0.5f);
                Handles.DrawWireDisc(curHit.point, curHit.normal,brushSize*brushFalloff);//Wire意指线框
            }
            
            HandleUtility.AddDefaultControl(GUIUtility.GetControlID(FocusType.Passive));//使Unity所带控件失效（如移动、缩放，旋转）
        
            Ray worldRay = HandleUtility.GUIPointToWorldRay(mousePos);//将 2D GUI 位置转换为世界空间射线。

            if (!changingBrushValue)
            {
                if (Physics.Raycast(worldRay, out curHit, 500f))//获取射线所射中的物体信息
                {
                    //做好顶点绘制准备
                    isPreparePainting = true;
                }
                else
                {
                    isPreparePainting = false;
                }
            }
            
        }
        
        
        //Get User Inputs
        ProcessInputs();

        //Update and Repaint Our Scene View GUI
        sceneView.Repaint();
    }
    
    #endregion

    #region TempPainter Method
    void PaintVertexColor()
    {
        if (curMesh)
        {
            Vector3[] verts = curMesh.vertices;//获取当前Mesh的所有顶点
            Color[] colors = null;

            if (curMesh.colors.Length>0)
            {
                //存在顶点色
                colors = curMesh.colors;
            }
            else
            {
                //不存在顶点色
                colors = new Color[verts.Length];
            }

            for (int i = 0; i < verts.Length; i++)
            {
                Vector3 vertPos = curGameObject.transform.TransformPoint(verts[i]);
                float magnitude = (vertPos - curHit.point).magnitude;//获取当前顶点到笔刷中心点的距离
                
                if (magnitude > brushSize)
                {
                    continue;
                }

                float falloff = VTXPainter_Utils.LinearFallOff(magnitude, brushSize, brushFalloff);
                
                colors[i] = VTXPainter_Utils.LerpVertexColor(colors[i], foregroundColor, falloff*brushOpacity);
            }
            
            curMesh.colors = colors;
        }
        else
        {
            Debug.LogWarning("Can‘t paint vertex color because there is no mesh available");
        }
    }
    #endregion

    #region Utility Methods
    void ProcessInputs()
    {
        Event e = Event.current;
        mousePos = e.mousePosition;
        
        //检测键盘按键
        if (e.type == EventType.KeyDown)
        {
            if (e.isKey)
            {
                //检测按键B
                if (e.keyCode == KeyCode.B)
                {
                    allowPainting = !allowPainting;
                    if (!allowPainting)
                    {
                        Tools.current = Tool.View;
                    }
                    else
                    {
                        Tools.current = Tool.None;
                    }
                }
                
                if (e.keyCode == KeyCode.Space)
                {
                    //Debug.Log("Pressed Space");
                }
            }
        }

        //检测鼠标按键
        if (e.type == EventType.MouseDown)
        {
            if (e.button == 0)
            { 
                //Debug.Log("Pressed Left Button");
            }
            else if (e.button == 1)
            {
                //Debug.Log("Pressed Right Button");
            }
            else if  (e.button == 2)
            {
                //Debug.Log("Pressed Middle Button");
            }
        }

        if (e.type == EventType.MouseUp)
        {
            changingBrushValue = false;
            if (isFirstClickPaint)
            {
                revokeList.AddLast(curMesh.colors);
            }
        }
        
        //Brush Key Combinations
        if (allowPainting)
        {
            //ctrl+按住鼠标左键横向移动控制brushSize
            if (e.type == EventType.MouseDrag && e.control && e.button == 0 && !e.shift)
            {
                brushSize += e.delta.x*0.003f;
                brushSize = Mathf.Clamp(brushSize, 0.01f, 10f);
                changingBrushValue = true;
            }
            
            //shift+按住鼠标左键横向移动控制brushOpacity
            if (e.type == EventType.MouseDrag && !e.control && e.button == 0 && e.shift)
            {
                brushOpacity += e.delta.x*0.003f;
                brushOpacity = Mathf.Clamp01(brushOpacity);
                changingBrushValue = true;
            }
            
            //ctrl+shift+按住鼠标左键横向移动控制brushFallOff
            if (e.type == EventType.MouseDrag && e.control && e.button == 0 && e.shift)
            {
                brushFalloff += e.delta.x*0.003f;
                brushFalloff = Mathf.Clamp01(brushFalloff);
                changingBrushValue = true;
            }
            
            //按住鼠标左键横向移动控制刷顶点色
            if (e.type == EventType.MouseDown && !e.control && e.button == 0 && !e.shift && !e.alt)
            {
                for (int i = 0; i < revokeNum; i++)
                {
                    revokeList.RemoveLast();
                }
                revokeNum = 0;
                
                //第一次顶点绘制
                if (isPreparePainting)
                {
                    isFirstClickPaint = true;
                    PaintVertexColor();
                }
            }

            if ((e.type == EventType.MouseDrag && !e.control && e.button == 0 && !e.shift && !e.alt&&e.delta.x!=0))
            {
                //第二次顶点绘制
                if (isPreparePainting)
                {
                    PaintVertexColor();
                }
            }
            
            //撤销&重做
            if (e.control && e.shift &&e.type==EventType.KeyDown)
            {
                if (e.keyCode == KeyCode.Z)
                {
                    if (revokeList.Count!=0)
                    {
                        LinkedListNode<Color[]> temp = revokeList.Last.Previous;
                        for (int i = 0; i < revokeNum&& temp!=null; i++)
                        {
                            temp = temp.Previous;
                        }

                        if (temp !=null)
                        {
                            curMesh.colors = temp.Value;
                            revokeNum++;
                            Debug.Log("已撤销");
                        }
                        else
                        {
                            Debug.LogWarning("You cant revoke now because this is the last!");
                        }
                        
                    }
                }

                if (e.keyCode == KeyCode.Y)
                {
                    if (revokeNum!=0)
                    {
                        LinkedListNode<Color[]> temp = revokeList.Last;
                        revokeNum--;
                        for (int i = 0; i < revokeNum; i++)
                        {
                            temp = temp.Previous;
                        }

                        curMesh.colors = temp.Value;
                        Debug.Log("已重做");
                    }
                    else
                    {
                        Debug.LogWarning("You cant undo now because this is the latest one");
                    }
                }
            }
            
            
        }

    }

    void GenerateStyles()
    {
        boxStyle = new GUIStyle();
        boxStyle.normal.background = (Texture2D)Resources.Load("GUISkins/Title_bg");//加载设置style的背景
        boxStyle.normal.textColor = Color.white;
        boxStyle.border = new RectOffset(3, 3, 3, 3);//边框只取3个像素，其余部分颜色拉伸填充
        boxStyle.margin = new RectOffset(2, 2, 2, 2);//设置标题的偏移
        boxStyle.fontStyle = FontStyle.Bold;//设置字体为粗体
        boxStyle.fontSize = 30;//设置字体大小为25
        boxStyle.font = (Font)Resources.Load("Fonts/Cupid-Darling-2");//设置字体
        boxStyle.alignment = TextAnchor.MiddleCenter;//设置字体中置
    }
    
    #endregion
}
