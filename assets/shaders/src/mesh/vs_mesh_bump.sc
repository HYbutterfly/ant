$input a_position, a_normal, a_tangent, a_tex0
$output v_tex0, v_lightdir, v_viewdir


#include "common/uniforms.sh"

#include <bgfx_shader.sh>

void main()
{
    vec3 pos = a_position;
	gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));
	vec4 worldpos = mul(u_model[0], vec4(pos, 1.0));

	v_tex0 = a_tex0;

	vec3 normal = normalize(mul(u_model[0], a_normal.xyz));
	vec3 tangent = normalize(mul(u_model[0], a_tangent.xyz));
	vec3 bitangent = cross(normal, tangent) * a_tangent.w;

	mat3 tbn = transpose(
			mat3(normalize(tangent),
			normalize(bitangent),
			normalize(normal)));
	
	v_lightdir 	= mul(directional_lightdir[0].xyz, tbn);
	v_viewdir 	= mul(normalize(u_eyepos - worldpos).xyz, tbn);
}