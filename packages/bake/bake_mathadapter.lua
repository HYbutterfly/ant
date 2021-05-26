local bake = require "bake"

local mathadapter_util = import_package "ant.math.adapter"
local math3d_adapter = require "math3d.adapter"
mathadapter_util.bind("bake", function ()
    local ctx_mt = bake.context_metatable()
    if ctx_mt == nil then
        error("invalid bake.context_metatable")
    end
    ctx_mt.begin_patch = math3d_adapter.getter(ctx_mt.begin_patch, "vmm", 2)
end)