using System;
using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEditor;
using UnityEngine;

public class AverageNormalsTool : EditorWindow
{
    GUIStyle boxStyle;
    private bool isAveraged;
    public bool enableVertexColorMode = false;
    
    [MenuItem("Tools/AverageNormalsTool")]
    static void AddWindow()
    {
        Rect rect = new Rect(0, 0, 300, 300);
        AverageNormalsTool window = (AverageNormalsTool)EditorWindow.GetWindowWithRect<AverageNormalsTool>(rect,false, "Average Normals Tool",true);//是否为浮动窗口 标题 是否聚焦
        window.GenerateStyles();
        window.Show();
    }
    
    private void OnGUI()
    {
        //Header
        GUILayout.BeginHorizontal();//横向排列开始
        GUILayout.Box("AVERAGE NORMALS TOOL",boxStyle,GUILayout.Height(60),GUILayout.ExpandWidth(true));
        GUILayout.EndHorizontal();//横向排列结束
        
        GUILayout.BeginVertical(boxStyle);
        
        GUILayout.Space(10);
        
        enableVertexColorMode = GUILayout.Toggle(enableVertexColorMode,"Vertex Color Mode");
        
        GUILayout.Space(10);

        if (GUILayout.Button("Average Normals",GUILayout.Height(60)) && Selection.activeObject != null)
        {
            if (enableVertexColorMode)
            {
                WirteAverageNormalToVertexColorTools();
            }
            else
            {
                WirteAverageNormalToVertexNormalTools();
            }
            
        }
        
        GUILayout.Space(10);
        
        if (GUILayout.Button("Export Asset File",GUILayout.Height(60)) && Selection.activeObject != null)//保存文件按钮
        {
            SaveAssets();
        }
        
        GUILayout.EndVertical();
        
        GUILayout.Space(10);
        
        GUILayout.BeginVertical();
        EditorGUILayout.HelpBox("You can use it to average mesh normals to vertex normal or vertex color", MessageType.Info);
        GUILayout.EndVertical();
    }
    
    # region Function
    private void WirteAverageNormalToVertexNormalTools()
    {
        MeshFilter[] meshFilters = Selection.activeGameObject.GetComponentsInChildren<MeshFilter>();
        foreach (var meshFilter in meshFilters)
        {
            Mesh mesh = meshFilter.sharedMesh;
            WirteAverageNormalToVertexNormal(mesh);
        }

        SkinnedMeshRenderer[] skinMeshRenders = Selection.activeGameObject.GetComponentsInChildren<SkinnedMeshRenderer>();
        foreach (var skinMeshRender in skinMeshRenders)
        {
            Mesh mesh = skinMeshRender.sharedMesh;
            WirteAverageNormalToVertexNormal(mesh);
        }
    }

    private void WirteAverageNormalToVertexNormal(Mesh mesh)
    {
        var averageNormalHash = new Dictionary<Vector3, Vector3>();
        for (var j = 0; j < mesh.vertexCount; j++)
        {
            if (!averageNormalHash.ContainsKey(mesh.vertices[j]))
            {
                averageNormalHash.Add(mesh.vertices[j], mesh.normals[j]);
            }
            else
            {
                averageNormalHash[mesh.vertices[j]] =
                    (averageNormalHash[mesh.vertices[j]] + mesh.normals[j]).normalized;
            }
        }

        var averageNormals = new Vector3[mesh.vertexCount];
        for (var j = 0; j < mesh.vertexCount; j++)
        {
            averageNormals[j] = averageNormalHash[mesh.vertices[j]];
        }

        var vertexNormal = new Vector3[mesh.vertexCount];
        for (var j = 0; j < mesh.vertexCount; j++)
        {
            vertexNormal[j] = new Vector4(averageNormals[j].x, averageNormals[j].y, averageNormals[j].z, 0);
        }
        mesh.normals = vertexNormal;
    }
    
    private void WirteAverageNormalToVertexColorTools()
    {
        MeshFilter[] meshFilters = Selection.activeGameObject.GetComponentsInChildren<MeshFilter>();
        foreach (var meshFilter in meshFilters)
        {
            Mesh mesh = meshFilter.sharedMesh;
            WirteAverageNormalToVertexColor(mesh);
        }

        SkinnedMeshRenderer[] skinMeshRenders = Selection.activeGameObject.GetComponentsInChildren<SkinnedMeshRenderer>();
        foreach (var skinMeshRender in skinMeshRenders)
        {
            Mesh mesh = skinMeshRender.sharedMesh;
            WirteAverageNormalToVertexColor(mesh);
        }
        
        Debug.Log("Average Normal to the Vertex Color Successfully");
    }

    private void WirteAverageNormalToVertexColor(Mesh mesh)
    {
        var averageNormalHash = new Dictionary<Vector3, Vector3>();
        for (var j = 0; j < mesh.vertexCount; j++)
        {
            if (!averageNormalHash.ContainsKey(mesh.vertices[j]))
            {
                averageNormalHash.Add(mesh.vertices[j], mesh.normals[j]);
            }
            else
            {
                averageNormalHash[mesh.vertices[j]] =
                    (averageNormalHash[mesh.vertices[j]] + mesh.normals[j]).normalized;
            }
        }

        var averageNormals = new Vector3[mesh.vertexCount];
        for (var j = 0; j < mesh.vertexCount; j++)
        {
            averageNormals[j] = averageNormalHash[mesh.vertices[j]];
        }

        var vertexColors = new Color[mesh.vertexCount];
        for (var j = 0; j < mesh.vertexCount; j++)
        {
            vertexColors[j] = new Vector4(averageNormals[j].x, averageNormals[j].y, averageNormals[j].z, 0);
        }
        mesh.colors = vertexColors;
    }
    
    public Mesh GetMesh()
    {
        Mesh curMesh = null;

        if (Selection.activeObject)
        {
            MeshFilter curFilter = Selection.activeObject.GetComponent<MeshFilter>();
            SkinnedMeshRenderer curSkinned = Selection.activeObject.GetComponent<SkinnedMeshRenderer>();
            
            //3D组件有两种
            //一种是MeshFilter+MeshRender
            //一种是SkinnedMeshRender
            
            if (curFilter && !curSkinned)
            {
                curMesh = curFilter.sharedMesh;
            }

            if (!curFilter && curSkinned)
            {
                curMesh = curSkinned.sharedMesh;
            }
        }

        return curMesh;
    }
    
    private void SaveAssets()
    {
        string path =
            EditorUtility.SaveFilePanel("Export asset file", Application.dataPath, Selection.activeObject.name + "_Modified", "asset");
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
                Mesh curMesh = GetMesh();
                Mesh finalResult = Instantiate(curMesh);
                AssetDatabase.CreateAsset(finalResult, path);
                    
                MeshFilter curFilter = Selection.activeObject.GameObject().GetComponent<MeshFilter>();
                SkinnedMeshRenderer curSkinned = Selection.activeObject.GameObject().GetComponent<SkinnedMeshRenderer>();
                
                
                if (curFilter && !curSkinned)
                {
                    EditorUtility.SetDirty(curFilter.GameObject());
                    curFilter.sharedMesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
                }

                if (!curFilter && curSkinned)
                {
                    EditorUtility.SetDirty(curSkinned.GameObject());
                    curSkinned.sharedMesh = AssetDatabase.LoadAssetAtPath<Mesh>(path);
                }

                Debug.Log("Asset exported: " + path);
            }
        }
    }
    #endregion
    
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