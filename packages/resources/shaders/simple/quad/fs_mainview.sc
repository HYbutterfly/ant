$input v_texcoord0
#include <bgfx_shader.sh>
#include "common/uniforms.sh"
#include "common/postprocess.sh"

void main()
{
    gl_FragColor = texture2D(s_mainview, v_texcoord0);
}