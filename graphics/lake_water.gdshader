shader_type spatial;
render_mode cull_back;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 float waves=sin(p.x*2.3+p.y*1.4+TIME*1.3)*0.5+sin(p.x*5.1-p.y*2.7-TIME*1.8)*0.25;
 float ripples=sin(p.x*12.0+sin(p.y*5.0)+TIME*2.0)*0.12;
 ALBEDO=mix(vec3(0.025,0.11,0.13),vec3(0.10,0.29,0.28),waves*0.08+0.3);
 METALLIC=0.15;
 ROUGHNESS=0.19+waves*0.035;
 NORMAL_MAP=vec3(0.5+cos(p.x*9.3+p.y*5.4+TIME*1.3)*0.035+ ripples*0.15,0.5+sin(p.y*11.1-p.x*4.1+TIME)*0.025,1.0);
 NORMAL_MAP_DEPTH=1.5;
}
