#if (UNITY_EDITOR)

using UnityEditor;
using UnityEngine;

namespace SteppedAnimation
{
     [CustomEditor(typeof(SteppedAnimationTool))]
    public class SteppedAnimationEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            SteppedAnimationTool t = (SteppedAnimationTool)target;

            EditorGUILayout.LabelField("Stepped Animation Generator", EditorStyles.boldLabel);
            EditorGUILayout.HelpBox(SHORT_HELP, MessageType.Info);
            EditorGUILayout.LabelField("");

            serializedObject.Update();
            
            EditorGUILayout.PropertyField(serializedObject.FindProperty("SourceClips"));
            GUILayout.Space(5);
            EditorGUILayout.LabelField("Interpolation", UnityEditor.EditorStyles.boldLabel);
            EditorGUILayout.PropertyField(serializedObject.FindProperty("FixRotationInterpolations"));
            GUILayout.Space(5);
            EditorGUILayout.LabelField("Keyframes", UnityEditor.EditorStyles.boldLabel);
            EditorGUILayout.PropertyField(serializedObject.FindProperty("KeyframeMode"));
            switch (t.KeyframeMode)
            {
                case SteppedAnimationTool.StepMode.FixedRate:
                    EditorGUILayout.PropertyField(serializedObject.FindProperty("KeyframeRate"));
                    break;
                case SteppedAnimationTool.StepMode.FixedTimeDelay:
                    EditorGUILayout.PropertyField(serializedObject.FindProperty("FixedTimeDelay"));
                    break;
                case SteppedAnimationTool.StepMode.ManualTime:
                    EditorGUILayout.PropertyField(serializedObject.FindProperty("ManualKeyframeTimes"));
                    break;
                case SteppedAnimationTool.StepMode.ManualFrame:
                    EditorGUILayout.PropertyField(serializedObject.FindProperty("SampleRate"));
                    EditorGUILayout.PropertyField(serializedObject.FindProperty("ManualKeyframes"));
                    break;
            }

            EditorGUILayout.LabelField("");
            EditorGUILayout.LabelField("Output", UnityEditor.EditorStyles.boldLabel);
            EditorGUILayout.HelpBox("Output clips will be generated in the same folder as this asset, and given the same name as the source clip with the \"_stepped\" suffix.\nOutput clips will also be given the \"Stepped\" asset label.", MessageType.Info);
            EditorGUILayout.LabelField("");

            if (GUILayout.Button("Generate"))
            {
                t.Generate();
            }

            serializedObject.ApplyModifiedProperties();
        }

        public const string SHORT_HELP = "This asset can be used to create stepped versions of source animation clips. Stepped animations can be used to produce a convincing 'flipbook' effect.";
    }
}

#endif