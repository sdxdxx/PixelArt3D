using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ScreenSpaceReflectionVolume : VolumeComponent
{
    //Universal
    public BoolParameter EnableReflection = new BoolParameter(false,true);
    public BoolParameter ShowReflectionTexture = new BoolParameter(false,true);
    public ColorParameter ColorChange = new ColorParameter(Color.white, true);
    
    //BinarySearch
    public ClampedFloatParameter MaxStepLength = new ClampedFloatParameter(0.1f, 0f, 5f);
    public ClampedFloatParameter MinDistance = new ClampedFloatParameter(0.02f, 0f, 1f);
    
    //Jitter Dither
    public ClampedFloatParameter DitherIntensity = new ClampedFloatParameter(1f, 0f, 5f);
    
}


