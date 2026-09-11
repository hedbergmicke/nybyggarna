shader_type spatial;
uniform vec4 tint: source_color = vec4(0.34,0.22,0.12,1.0);
varying vec3 p;
void vertex(){p=VERTEX;}
void fragment(){
 float grain=sin(p.x*53.0+sin(p.z*4.0)*3.0+sin(p.x*8.0))*0.07+sin(p.x*123.0+p.z*3.0)*0.025;
 ALBEDO=tint.rgb*(0.9+grain);
 ROUGHNESS=0.84;
 NORMAL_MAP=vec3(0.5+grain*0.3,0.5,1.0);
}
