shader_type spatial;
render_mode cull_disabled;
uniform float wind_strength=0.10;
varying vec3 world_pos;
void vertex(){
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float sway=sin(TIME*1.4+world_pos.x*0.7+world_pos.z*0.5);
 VERTEX.x+=sway*wind_strength*max(VERTEX.y,0.0);
}
void fragment(){ALBEDO=pow(max(COLOR.rgb,vec3(0.001)),vec3(2.2)); ROUGHNESS=1.0; SPECULAR=0.0; BACKLIGHT=pow(max(COLOR.rgb,vec3(0.001)),vec3(2.2))*0.14;}
