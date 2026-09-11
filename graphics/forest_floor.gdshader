shader_type spatial;
render_mode cull_back;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 float n=noise(world_pos.xz*0.35)*0.6+noise(world_pos.xz*2.0)*0.25+noise(world_pos.xz*18.0)*0.15;
 vec3 moss=mix(vec3(0.105,0.16,0.065),vec3(0.38,0.40,0.17),smoothstep(0.2,0.8,n));
 float earth=smoothstep(0.62,0.82,noise(world_pos.xz*0.8));
 ALBEDO=pow(mix(moss,vec3(0.28,0.22,0.13),earth*0.45),vec3(1.5));
 ROUGHNESS=0.96;
 NORMAL_MAP=vec3(0.5+(noise(world_pos.xz*25.0)-0.5)*0.22,0.5+(noise(world_pos.zx*23.0)-0.5)*0.22,1.0);
}
