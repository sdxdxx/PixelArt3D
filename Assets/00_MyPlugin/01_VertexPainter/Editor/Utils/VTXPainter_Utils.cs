using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public static class VTXPainter_Utils 
{
    public static Mesh GetMesh(GameObject gameObject)
    {
        Mesh curMesh = null;

        if (gameObject)
        {
            MeshFilter curFilter = gameObject.GetComponent<MeshFilter>();
            SkinnedMeshRenderer curSkinned = gameObject.GetComponent<SkinnedMeshRenderer>();
            
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

    public static float LinearFallOff(float distance, float brushSize, float falloff)
    {
        float result = 0;
        

        if (distance > brushSize*falloff)
        {
            result = Mathf.Clamp01(1-(distance-brushSize*falloff)/(brushSize - brushSize*falloff));
        }
        else
        {
            result = 1;
        }
        
        return result;
    }

    public static Color LerpVertexColor(Color colorA,Color colorB, float lerpValue)
    {
        Color result;
        result = new Color(colorA.r + (colorB.r - colorA.r)*lerpValue,
                colorA.g + (colorB.g - colorA.g)*lerpValue,
                colorA.b + (colorB.b - colorA.b)*lerpValue,
                colorA.a + (colorB.a - colorA.a)*lerpValue);
        return result;
    }
}
