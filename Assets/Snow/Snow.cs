using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Snow : MonoBehaviour
{
    public RenderTexture rt;
    private RenderTexture rt0;

    public Texture drawImg;

    public Texture defaultTexture;

    public Material stamp_mat;

    public Material stamp_mat0;

    private Camera mainCam;
    
    void Start()
    {
        mainCam = Camera.main;


        rt0 = new RenderTexture(rt.width,rt.height,32,rt.graphicsFormat);
        rt0.Create();


        Draw0(rt.width/2,rt.height/2);//替换初始贴图
        gameObject.GetComponent<Renderer>().material.SetTexture("_HeightMap",rt);

        
    }
    
    void Draw0(int x, int y)
    {
        RenderTexture.active = rt;
        
        //栈中压入MVP矩阵
        GL.PushMatrix();
        GL.LoadPixelMatrix(0,rt.width,rt.height,0);//将正交投影加载到投影矩阵中
        
        x -= defaultTexture.width / 2; y -= defaultTexture.height / 2; //偏移半个贴图尺寸以将贴图绘制在中心
        
        //定义二维矩形（左上角为(0,0)点）
        Rect rect = new Rect(x, y, defaultTexture.width, defaultTexture.height);
        Graphics.DrawTexture(rect,defaultTexture,stamp_mat0);//屏幕坐标中绘制纹理，用这个将drawImg绘制到RT上
        //材质球负责控制混合
        
        //出栈
        GL.PopMatrix();
        RenderTexture.active = null;
        
    }

    void Draw(int x, int y)
    {
        //在绘制前先保存上一张RT
        Graphics.Blit(rt,rt0);
        
        RenderTexture.active = rt;
        
        //栈中压入MVP矩阵
        GL.PushMatrix();
        GL.LoadPixelMatrix(0,rt.width,rt.height,0);//将正交投影加载到投影矩阵中
        
        
        x -= (int) drawImg.width / 2;  y -= (int) drawImg.height / 2; //偏移半个贴图尺寸以将贴图绘制在中心
        
        //定义二维矩形（左上角为(0,0)点）
        Rect rect = new Rect(x, y, drawImg.width, drawImg.height);
        Vector4 sourceUV = new Vector4(0,0,0,0);
        sourceUV.z = rect.x / rt.width;
        sourceUV.w = 1 - rect.y / rt.height;
        sourceUV.x = rect.width / rt.width;
        sourceUV.y = rect.height / rt.height;
        sourceUV.w -= sourceUV.y;
        stamp_mat.SetTexture("_SourceTex",rt0);
        stamp_mat.SetVector("_SourceUV",sourceUV);
        Graphics.DrawTexture(rect,drawImg,stamp_mat);//屏幕坐标中绘制纹理，用这个将drawImg绘制到RT上
                                                                                    //材质球负责控制混合
        
        //出栈
        GL.PopMatrix();
        RenderTexture.active = null;
    }

    public void DrawAt(float x, float y)
    {
        int x_f = (int)(x * rt.width);
        int y_f = (int)(rt.height-y * rt.height);//坐标系修正
        Draw(x_f,y_f);
    }
    
    void Update()
    {
        /*
        if (Input.GetMouseButton(0))
        {
            Debug.Log("按下");

            Ray ray = mainCam.ScreenPointToRay(Input.mousePosition);

            RaycastHit hit;

            if (Physics.Raycast(ray, out hit))
            {
                Debug.Log("点击到"+hit.transform.name);
                DrawAt(hit.textureCoord.x,hit.textureCoord.y);
                //int x = (int)(hit.textureCoord.x * rt.width);
                //int y = (int)(rt.height-hit.textureCoord.y * rt.height);//坐标系修正
                //Draw(x,y);
            }
        }
        */
    }
    
}
