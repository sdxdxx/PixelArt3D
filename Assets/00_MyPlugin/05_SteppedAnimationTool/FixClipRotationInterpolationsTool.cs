#if (UNITY_EDITOR)
using UnityEditor;
using UnityEngine;
using System.Collections.Generic;
using Unity.Mathematics;

public class FixClipRotationInterpolationsTool
{
    [MenuItem("Tools/FixClipRotationInterpolationsTool")]
    public static void ConvertSelectedAnimationClip()
    {
        AnimationClip clip = Selection.activeObject as AnimationClip;
        if (clip == null)
        {
            Debug.LogError("Please choose an AnimationClip");
            return;
        }

        FixClipRotationInterpolations(clip);
    }

    private static void FixClipRotationInterpolations(AnimationClip clip)
    {
        EditorCurveBinding[] bindings = AnimationUtility.GetCurveBindings(clip);
        List<EditorCurveBinding> rotationBindings = new List<EditorCurveBinding>();
        List<AnimationCurve> rotationCurves = new List<AnimationCurve>();

        // 收集所有旋转曲线
        foreach (var binding in bindings)
        {
            if (binding.propertyName .Contains("m_LocalRotation") )
            {
                //Debug.Log(binding.propertyName);
                AnimationCurve curve = AnimationUtility.GetEditorCurve(clip, binding);
                rotationBindings.Add(binding);
                rotationCurves.Add(curve);
            }
        }

        // 删除原始旋转曲线
        foreach (var binding in rotationBindings)
        {
            AnimationUtility.SetEditorCurve(clip, binding, null);
        }
        
        
        // 为每个旋转曲线创建欧拉角曲线
        for (int i = 0; i < rotationBindings.Count; i++)
        {
            if (rotationBindings[i].propertyName == "m_LocalRotation.x")
            {
                EditorCurveBinding bindingX = rotationBindings[i];
                EditorCurveBinding bindingY= rotationBindings[i+1];
                EditorCurveBinding bindingZ= rotationBindings[i+2];
                EditorCurveBinding bindingW= rotationBindings[i+3];
                AnimationCurve curveX = rotationCurves[i];
                AnimationCurve curveY = rotationCurves[i+1];
                AnimationCurve curveZ = rotationCurves[i+2];
                AnimationCurve curveW = rotationCurves[i+3];
                Debug.Log(rotationBindings[i].propertyName);
                Debug.Log(rotationBindings[i+1].propertyName);
                Debug.Log(rotationBindings[i+2].propertyName);
                Debug.Log(rotationBindings[i+3].propertyName);
                FixRotations(curveX, curveY, curveZ, curveW);
                AnimationUtility.SetEditorCurve(clip, bindingX, curveX);
                AnimationUtility.SetEditorCurve(clip, bindingY, curveY);
                AnimationUtility.SetEditorCurve(clip, bindingZ, curveZ);
                AnimationUtility.SetEditorCurve(clip, bindingW, curveW);
            }
        }
        AssetDatabase.SaveAssets();
        Debug.Log("转换完成: " + clip.name);
        
    }
    static void FixRotations(AnimationCurve rotX, AnimationCurve rotY, AnimationCurve rotZ, AnimationCurve rotW) 
    {
        var prev = new quaternion(
            rotX.keys[0].value,
            rotY.keys[0].value,
            rotZ.keys[0].value,
        rotW.keys[0].value
        );
        for (var i = 1; i < rotX.keys.Length; i++) 
        {
            var keyX = rotX.keys[i];
            var keyY = rotY.keys[i];
            var keyZ = rotZ.keys[i];
            var keyW = rotW.keys[i];
            var value = new quaternion(
                keyX.value,
                keyY.value,
                keyZ.value,
                keyW.value
            );

            if (math.dot(prev, value) < 0) {
                value.value = -value.value;

                keyX.value = -keyX.value;
                rotX.MoveKey(i, keyX);
            
                keyY.value = -keyY.value;
                rotY.MoveKey(i, keyY);
            
                keyZ.value = -keyZ.value;
                rotZ.MoveKey(i, keyZ);
            
                keyW.value = -keyW.value;
                rotW.MoveKey(i, keyW);
            }
            prev = value;
        }
    }
}
#endif