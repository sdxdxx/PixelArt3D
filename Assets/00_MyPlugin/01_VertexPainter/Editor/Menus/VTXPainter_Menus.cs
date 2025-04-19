using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class VTXPainter_Menus : MonoBehaviour
{
    [MenuItem("Tools/VertexPainter",false,10)]
    private static void LauchingSomething()
    {
        VTXPainter_Window.LaunchVertexPainter();
    }
}
