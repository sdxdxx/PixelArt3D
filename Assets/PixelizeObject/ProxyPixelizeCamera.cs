using System.Collections;
using System.Collections.Generic;
using System.Numerics;
using Unity.Mathematics;
using UnityEngine;
using Matrix4x4 = UnityEngine.Matrix4x4;
using Vector3 = UnityEngine.Vector3;

public class ProxyPixelizeCamera : MonoBehaviour
{
    private float perPixelLength = 0;
    void Start()
    {
        perPixelLength = CalculatePerPixelLength();
    }

    // Update is called once per frame
    void Update()
    {

    }

    float CalculatePerPixelLength()
    {
        Vector3[] screenCorners = new Vector3[4];
        // 左下
        screenCorners[0] = Camera.main.ViewportToWorldPoint(new Vector3(0.0f, 0.0f, Camera.main.nearClipPlane));
        // 右下
        screenCorners[1] = Camera.main.ViewportToWorldPoint(new Vector3(1.0f, 0.0f, Camera.main.nearClipPlane));
        // 左上
        screenCorners[2] = Camera.main.ViewportToWorldPoint(new Vector3(0.0f, 1.0f, Camera.main.nearClipPlane));
        // 右上
        screenCorners[3] = Camera.main.ViewportToWorldPoint(new Vector3(1.0f, 1.0f, Camera.main.nearClipPlane));

        float widthDistance = Vector3.Distance(screenCorners[1], screenCorners[0]);
        float result = widthDistance/Screen.width;
        return result;
    }

    /*
    Matrix4x4 TransformToAnotherCoordinateSystem(float3 xAxis, float3 yAxis, float3 zAxis)
    {
        float3x3 tempMatrix = new float3x3(
            xAxis.x, xAxis.y, xAxis.z,
            yAxis., yAxis
            zAxis);
    }
    */
}
