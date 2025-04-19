using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PixelizeBackgroundVolume : VolumeComponent
{
    public  ColorParameter ColorChange = new ColorParameter(Color.white, true);
    public ClampedIntParameter DownSampleValues = new ClampedIntParameter(0, 0, 5);
}
