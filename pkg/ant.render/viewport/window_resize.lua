local ecs   = ...
local world = ecs.world
local w     = world.w

local setting   = import_package "ant.settings".setting
local mu		= import_package "ant.math".util

local rhwi      = import_package "ant.hwi"

local ENABLE_HVFILP<const> 	= setting:get "graphic/postprocess/hv_flip/enable"

local SCENE_RATIO<const> 	= setting:get "framebuffer/scene_ratio" or 1.0
local RATIO<const> 			= setting:get "framebuffer/ratio" 		or 1.0

world.args.framebuffer.ratio 		= RATIO
world.args.framebuffer.scene_ratio 	= SCENE_RATIO
log.info(("framebuffer ratio:%2f, scene:%2f"):format(RATIO, SCENE_RATIO))

local function update_config(args, ww, hh)
	local fb = args.framebuffer
	fb.w, fb.h = ww, hh

	local vp = args.viewport
	if vp == nil then
		vp = {}
		args.viewport = vp
	end

	vp.x, vp.y = 0, 0
	if ENABLE_HVFILP then
		vp.w, vp.h = hh, ww
	else
		vp.w, vp.h = ww, hh
	end
end

local resize_mb			= world:sub {"resize"}
local ratio_change_mb	= world:sub {"framebuffer_ratio_changed"}

local winresize_sys = ecs.system "window_resize_system"

if __ANT_EDITOR__ then
	function winresize_sys:start_frame()
	end
else
	local function winsize_update(s, ratio)
		local ns = mu.calc_viewrect(s, ratio)
		log.info("resize framebuffer from:", s.w, s.h, ", to:", ns.w, ns.h)
		update_config(world.args, ns.w, ns.h)
		rhwi.reset(nil, ns.w, ns.h)
		local vp = world.args.viewport
		log.info("main viewport:", vp.x, vp.y, vp.w, vp.h, vp.ratio or "(viewport ratio is nil)")
		world:pub{"world_viewport_changed", vp}
	end

	function winresize_sys:start_frame()
		for _, ww, hh in resize_mb:unpack() do
			winsize_update({w=ww, h=hh}, world.args.framebuffer.ratio)
		end

		for _, which, ratio in ratio_change_mb:unpack() do
			if which == "ratio" then
				local oldratio = world.args.framebuffer.ratio
				world.args.framebuffer.ratio = ratio
				winsize_update(mu.calc_viewrect(world.args.framebuffer, 1.0/oldratio), ratio)
			else
				assert(which == "scene_ratio", "Invalid ratio type:" .. which)
				world:pub{"scene_viewport_ratio_changed", ratio}
			end
		end
	end
end
