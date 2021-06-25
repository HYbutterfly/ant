$input v_texcoord0
#include <bgfx_shader.sh>

SAMPLER2D(s_lightmap, 0);

void main()
{
    gl_FragColor = 
        vec4(texture2D(s_lightmap, v_texcoord0).rgb, gl_FrontFacing ? 1.0 : 0.0);
}