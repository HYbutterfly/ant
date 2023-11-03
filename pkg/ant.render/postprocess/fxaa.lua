local ecs   = ...
local world = ecs.world
local w     = world.w

local setting = import_package "ant.settings"
local ENABLE_FXAA<const>    = setting:get "graphic/postprocess/fxaa/enable"
local ENABLE_TAA<const>    = setting:get "graphic/postprocess/taa/enable"
local renderutil = require "util"
local fxaasys = ecs.system "fxaa_system"
local sampler   = import_package "ant.render.core".sampler
if not ENABLE_FXAA then
    renderutil.default_system(fxaasys, "init", "init_world", "fxaa", "data_changed")
    return
end

local hwi       = import_package "ant.hwi"

local mu        = import_package "ant.math".util
local fbmgr     = require "framebuffer_mgr"

local util      = ecs.require "postprocess.util"

local imaterial = ecs.require "ant.asset|material"
local irender   = ecs.require "ant.render|render_system.render"
local irq       = ecs.require "ant.render|render_system.renderqueue"

function fxaasys:init()
    world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            simplemesh      = irender.full_quad(),
            material        = "/pkg/ant.resources/materials/postprocess/fxaa.material",
            visible_state   = "fxaa_queue",
            fxaa_drawer     = true,
            scene           = {},
        }
    }
end

local function create_fb(vr)
    local minmag_flag<const> = ENABLE_TAA and "POINT" or "LINEAR"
    return fbmgr.create{
        rbidx = fbmgr.create_rb{
            w = vr.w, h = vr.h, layers = 1,
            format = "RGBA8",
            flags = sampler{
                U = "CLAMP",
                V = "CLAMP",
                MIN=minmag_flag,
                MAG=minmag_flag,
                RT="RT_ON",
                BLIT="BLIT_COMPUTEWRITE"
            },
        }
    }
end

local fxaa_viewid<const> = hwi.viewid_get "fxaa"

function fxaasys:init_world()
    local vr = mu.copy_viewrect(world.args.viewport)
    util.create_queue(fxaa_viewid, mu.copy_viewrect(world.args.viewport), create_fb(vr), "fxaa_queue", "fxaa_queue")
end

local vp_changed_mb = world:sub{"world_viewport_changed"}

function fxaasys:data_changed()
    for _, vp in vp_changed_mb:unpack() do
        irq.set_view_rect("fxaa_queue", vp)
        break
    end
end

function fxaasys:fxaa()
    local sceneldr_handle
    if not ENABLE_TAA then
        local tme = w:first "tonemapping_queue render_target:in"
        sceneldr_handle = fbmgr.get_rb(tme.render_target.fb_idx, 1).handle
    else
        local tame = w:first "taa_queue render_target:in"
        sceneldr_handle = fbmgr.get_rb(tame.render_target.fb_idx, 1).handle
    end

    local fd = w:first "fxaa_drawer filter_material:in"
    imaterial.set_property(fd, "s_scene_ldr_color", sceneldr_handle)
end

