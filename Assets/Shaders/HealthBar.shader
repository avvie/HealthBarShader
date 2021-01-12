Shader "Custom/AnimatedHealthBar"
{
    Properties
    {
        _Health ("Health", Range(0,1)) = 1
        _Height ("Height", Range(0,1)) = 1
        _Width ("Width", Range(0,1)) = 1
        _Offset ("Offset", Range(0,1)) = 1
        _FlashPeriod ("_FlashPeriod", Range(0,8)) = 8.0
        _MainTex ("HealthGradient", 2D) = "white" {}
        _MinClamp ("Health Gradient min sampling bound", Range(0,1)) = 0.2
        _MaxClamp ("Health Gradient max sampling bound", Range(0,1)) = 0.9
        _BorderBaseColor ("Border Base Color", Color) = (0.7 , 0.7, 0.7,1)
        _GlintColor1 ("GlintColor1", Color) = (0.3 , 0, 0,1)
        _GlintColor2 ("GlintColor2", Color) = (0.85,0.85,0.85,1.0)
        _LineWidth("Border Line Width", Range(0,1)) = 0.58
        _BorderPeriod ("BorderPeriod", Range(0.01,6)) = 2
        _BorderGradient ("BorderGradient", Range(2,8)) = 3
        _BorderMinSaturation("BorderMinSaturation", Range(0.4,1)) = 0.75
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent" }
        LOD 100

        Pass
        {
            ZWrite off
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float2 aspect : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            uniform float _Health;
            uniform float _FlashPeriod = 8.0;
            uniform float _Height, _Width, _Offset, _LineWidth, _BorderPeriod, _BorderGradient, _BorderMinSaturation, _MinClamp, _MaxClamp;
            uniform fixed4 _BorderBaseColor, _GlintColor1, _GlintColor2;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                float3 scale = float3(
                    length(unity_ObjectToWorld._m00_m10_m20),
                    length(unity_ObjectToWorld._m01_m11_m21),
                    length(unity_ObjectToWorld._m02_m12_m22)
                );
                o.aspect = float2(scale.x/scale.y, 1); 
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
            
            float InverseLerp(float a, float b, float c){
                return (c-a)/(b-a);
            }
            
            float periodCalc(){
                return _FlashPeriod * (1.0 - _Health);
            }
            
            float boxSDF(float2 p, float2 b){
                float2 d = abs(p)-b;
                return length(max(d,0)) + min(max(d.x , d.y), 0);
            }
            
            float calcFlash(){
                return 0.1 * sin(_Time.y * ( 6.28 * periodCalc()) ) + 0.9;
            }
            
            float glint(float2 pos){
                float2 copy = pos;
                copy.x -= fmod(_Time.y /_BorderPeriod, 2.0) ;
                
                return copy.x * _BorderGradient;
            }

            fixed4 frag (v2f i) : SV_Target
            { 
                //Clamp Health level for texture sampling 
                float tHealthBarColor = clamp(_Health, _MinClamp,_MaxClamp);
                float3 healthBarColor = tex2D(_MainTex, float2(tHealthBarColor, i.uv.y)).xyz;
                //Mask
                float healthBarMask = _Health > i.uv.x;
                
                //make object center point
                float2 p = i.uv - 0.5;
                //correct for aspect
                p *= i.aspect;
                _Width *= i.aspect;
                //calc SDF
                float3 box = boxSDF(p, float2(_Width, _Height)) - _Offset;
                //Antialiase the box mask
                float distChange = fwidth(box) * 0.5;
                float antiAliasedCutoff = smoothstep(distChange, -distChange, box);
                float boxMask = (box > 0);
                //Calc glint 
                p = i.uv +0.5;
                float glnt = glint(p) * boxMask ;
                glnt = smoothstep( glnt-_LineWidth, glnt, p.y) - smoothstep( glnt, glnt+_LineWidth, p.y) ; 
                glnt = ((glnt*_GlintColor1)+(glnt*_GlintColor2));
                
                box = boxMask * clamp(box, _BorderMinSaturation,1);
                //Animate health according to health
                healthBarColor *= calcFlash();
                
                return float4 (box * _BorderBaseColor +
                 glnt + (1-boxMask) * healthBarColor * healthBarMask, 1);
            }
            ENDCG
        }
    }
}
