using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class InteractiveSnow : MonoBehaviour
{
    private Vector3 oldPos;
    public float dis = 0.1f;
    void Start()
    {
        oldPos = transform.position;
    }
    
    // Update is called once per frame
    void Update()
    {
        Ray ray = new Ray(transform.position, Vector3.down);

        RaycastHit hit;
        if (Vector3.Distance(oldPos, transform.position)>dis)
        {
            oldPos = transform.position;
            if (Physics.Raycast(ray, out hit))
            {
                Snow snow = hit.collider.GetComponent<Snow>();
                
                if (snow)
                {
                    snow.DrawAt(hit.textureCoord.x, hit.textureCoord.y);
                }
            }
        }
    }
}
