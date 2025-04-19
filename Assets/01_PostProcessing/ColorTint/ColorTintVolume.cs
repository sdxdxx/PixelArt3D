using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ColorTintVolume : VolumeComponent
{
    public  ColorParameter ColorChange = new ColorParameter(Color.white, true);
}
