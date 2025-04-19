using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

[ExecuteInEditMode]
public class DrawLeaf : MonoBehaviour
{
    public Mesh ShapeMesh;
    public Mesh LeafMesh;
    public List<Material> mats = new List<Material>();
    [Range(0.1f,1f)]
    public float LeafDenesity = 1;
    [Range(0.1f, 2f)]
    public float LeafSize = 1;
    [Range(0f, 1f)]
    public float LeafOffset = 0;
    [Range(0f,1f)]
    public float LightOffset = 0;
    [Range(0f, 1f)]
    public float LifhtOffsetDenesity = 0;

    private List<LeafData> LeafDatas;

    void Start()
    {
        InitLeaf();
    }

    public void InitLeaf() { 
        LeafDatas = new List<LeafData>();
        for (int i = 0; i < ShapeMesh.vertices.Length; i++) {
            float random = Random.Range(0f, 1f);
            if (LeafDenesity < random)
                continue;
            Vector3 pos = transform.TransformPoint(ShapeMesh.vertices[i]);
            Vector3 normal = transform.TransformPoint(ShapeMesh.normals[i]) - transform.position;
            Quaternion quaternion = Quaternion.Euler(0,0,Random.Range(-20f,20f));
            float size = Random.Range(0.5f, 1f);
            int matIndex = Random.Range(0, mats.Count);
            float speedOffset = Random.Range(0f, 4f);
            float lightOffset = Random.Range(0f, 1f);
            if (LifhtOffsetDenesity < lightOffset)
                lightOffset = 0;
            LeafData data = new LeafData() { pos = pos,normal = normal,Size = size, matIndex = matIndex,
            speedOffset = speedOffset,quaternion = quaternion,lightOffset = lightOffset};
            LeafDatas.Add(data);
        }
    }
    
    void Update()
    {
        if (LeafDatas == null)
            InitLeaf();
        DrawLeafs();
    }

    private void DrawLeafs() { 
        List<List<Matrix4x4>> matrix4X4s = new List<List<Matrix4x4>>();
        List<List<Vector4>> normals = new List<List<Vector4>>();
        List<List<float>> speedShift = new List<List<float>>();
        List<List<float>> lightOffset = new List<List<float>>();
        for (int i = 0; i < mats.Count; i++) { 
            matrix4X4s.Add(new List<Matrix4x4>());
            normals.Add(new List<Vector4>());
            speedShift.Add(new List<float>());
            lightOffset.Add(new List<float>());
        }

        foreach (LeafData data in LeafDatas) { 
            int index = data.matIndex;
            Vector3 pos = data.pos + data.normal * LeafOffset;
            Vector3 scale = Vector3.one * data.Size * LeafSize;
            Matrix4x4 matrix4X4 = Matrix4x4.TRS(pos, data.quaternion, scale);
            matrix4X4s[index].Add(matrix4X4);
            normals[index].Add(data.normal);
            speedShift[index].Add(data.speedOffset);
            lightOffset[index].Add(data.lightOffset * LightOffset);
            if (matrix4X4s[index].Count >= 1023) { 
                MaterialPropertyBlock block = new MaterialPropertyBlock();
                block.SetVectorArray("_normal", normals[index].ToArray());
                block.SetFloatArray("_speedOffset", speedShift[index].ToArray());
                block.SetFloatArray("_lightOffset", lightOffset[index].ToArray());
                Graphics.DrawMeshInstanced(LeafMesh, 0, mats[index], matrix4X4s[index].ToArray(), matrix4X4s[index].Count,
                    block, UnityEngine.Rendering.ShadowCastingMode.Off, false);
                matrix4X4s[index].Clear();
                normals[index].Clear();
                speedShift[index].Clear();
                lightOffset[index].Clear();
            }
        }
        for (int i = 0; i < mats.Count; i++)
        {
            int index = i;
            if (matrix4X4s[index].Count == 0)
                continue;
            MaterialPropertyBlock block = new MaterialPropertyBlock();
            block.SetVectorArray("_normal", normals[index].ToArray());
            block.SetFloatArray("_speedOffset", speedShift[index].ToArray());
            block.SetFloatArray("_lightOffset", lightOffset[index].ToArray());
            Graphics.DrawMeshInstanced(LeafMesh, 0, mats[index], matrix4X4s[index].ToArray(), matrix4X4s[index].Count,
                block, UnityEngine.Rendering.ShadowCastingMode.Off, false);
            matrix4X4s[index].Clear();
            normals[index].Clear();
            speedShift[index].Clear();
            lightOffset[index].Clear();
        }
    }



    public struct LeafData {
        public Vector3 pos;
        public Vector3 normal;
        public Quaternion quaternion;
        public float Size;
        public int matIndex;
        public float speedOffset;
        public float lightOffset;
    }
}

[CustomEditor(typeof(DrawLeaf))]
public class DrawLeafEditor : Editor {
    public override void OnInspectorGUI() {

        base.OnInspectorGUI();

        bool refresh = GUILayout.Button("Refresh Leaf", GUILayout.Height(25));

        if (refresh) {
            (this.target as DrawLeaf).InitLeaf();
            Debug.Log("Refresh Leaf");
        }
    }
}

