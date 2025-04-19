using System.Collections.Generic;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;

public class CombineMeshes : EditorWindow
{
    
    GUIStyle boxStyle;
    private GameObject parentGameObject;
    private Vector3 originPosition;
    private string savePath = "Assets";
    private string defaultName = "NewMesh";
    
    [MenuItem("Tools/CombineMeshes")]
    public static void OpenWindow()
    {
        Rect rect = new Rect(0, 0, 300, 250);
        CombineMeshes window = (CombineMeshes)EditorWindow.GetWindowWithRect<CombineMeshes>(rect,false, "Combine Meshes Tool",true);//是否为浮动窗口 标题 是否聚焦
        window.GenerateStyles();
        window.Show();
    }

    private void OnGUI()
    {
        //Header
        GUILayout.BeginHorizontal();//横向排列开始
        GUILayout.Box("COMBINE MESHES TOOL",boxStyle,GUILayout.Height(60),GUILayout.ExpandWidth(true));
        GUILayout.EndHorizontal();//横向排列结束
        
        GUILayout.BeginVertical(boxStyle);
        GUILayout.Space(10);
        parentGameObject = EditorGUILayout.ObjectField("Parent Game Object", parentGameObject, typeof(GameObject), true) as GameObject;
        GUILayout.Space(10);
        savePath = EditorGUILayout.TextField("Save Path：", savePath);
        GUILayout.Space(10);
        defaultName = EditorGUILayout.TextField("Default Name", defaultName);
        GUILayout.Space(10);
        GUILayout.EndVertical();
        
        GUILayout.BeginVertical(boxStyle);
        if (GUILayout.Button("Combine Meshes",GUILayout.Height(30)))
        {
            CombineMeshesWindow();
        }
        GUILayout.EndVertical();
        
        GUILayout.BeginVertical();
        EditorGUILayout.HelpBox("You can use it to combine mesh to optimize performance", MessageType.Info);
        GUILayout.EndVertical();
        
    }
    private void CombineMeshesWindow()
    {
        
        
        if (parentGameObject == null)
        {
            Debug.LogError("Parent game object is null.");
            return;
        }
        
        originPosition = parentGameObject.transform.position;
        parentGameObject.transform.position = new Vector3(0,0,0);
        
        var meshfilters = parentGameObject.GetComponentsInChildren<MeshFilter>();
        if (meshfilters != null && meshfilters.Length > 0)
        {
            var centerOffset = new List<Vector4>(); //记录偏离向量的list

            var combineInstances = new CombineInstance[meshfilters.Length];
            for (int i = 0; i < meshfilters.Length; i++)
            {
                var mesh = meshfilters[i].sharedMesh;
                combineInstances[i] = new CombineInstance()
                {
                    mesh = mesh,
                    transform = meshfilters[i].transform.localToWorldMatrix
                };
                for (int j = 0; j < mesh.vertexCount; j++)
                {
                    //默认合并结构是，quad在一个父物体下，那么localPosition就是距离父物体中心（局部空间原点）的偏离向量。
                    centerOffset.Add(meshfilters[i].transform.localPosition);
                }
            }

            var newMesh = new Mesh();
            newMesh.CombineMeshes(combineInstances, true);
            var colors = new List<Color>();
            foreach (var offset in centerOffset)
            {
                colors.Add(new Vector4(offset.x, offset.y, offset.z, 1));
                Debug.Log(offset);
            }
            //把偏移向量写入顶点颜色数据中
            newMesh.colors = colors.ToArray();
            SaveAssets(newMesh, ref savePath);
        }

        parentGameObject.transform.position = originPosition;

    }
    
    private void SaveAssets(Mesh mesh, ref string path)
    {
        path = EditorUtility.SaveFilePanel("Export asset file", Application.dataPath+"/"+path, defaultName, "asset");
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
                AssetDatabase.CreateAsset(mesh, path);
                Debug.Log("Asset exported: " + path);
            }
            
            path = path.Replace("/"+defaultName+".asset", "");
        }
    }
    
    #region BoxStyles
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