local ecs = ...
local world = ecs.world
local w = world.w

local fbmgr 	= require "framebuffer_mgr"

local mathpkg	= import_package "ant.math"
local mu		= mathpkg.util

local vp_detect_sys = ecs.system "viewport_detect_system"

local icamera	= ecs.require "ant.camera|camera"
local irq		= ecs.require "ant.render|render_system.renderqueue"

local fb_cache, rb_cache
local function clear_cache()
	fb_cache, rb_cache = {}, {}
end

local function resize_framebuffer(w, h, fbidx)
	if fbidx == nil or fb_cache[fbidx] then
		return 
	end

	local fb = fbmgr.get(fbidx)
	fb_cache[fbidx] = fb

	local changed = false
	local rbs = {}
	for _, attachment in ipairs(fb)do
		local rbidx = attachment.rbidx
		rbs[#rbs+1] = attachment
		local c = rb_cache[rbidx]
		if c == nil then
			changed = fbmgr.resize_rb(rbidx, w, h) or changed
			rb_cache[rbidx] = changed
		else
			changed = true
		end
	end
	
	if changed then
		fbmgr.recreate(fbidx, fb)
	end
end

local function check_viewrect_size(queue_vr, new_viewrect, sceneratio)
	local scale_new_vr = mu.calc_viewrect(new_viewrect, sceneratio)
	if queue_vr.w ~= scale_new_vr.w or queue_vr.h ~= scale_new_vr.h then
		scale_new_vr.ratio = sceneratio
		mu.copy2viewrect(scale_new_vr, queue_vr)
	end
end

local function update_render_queue(q, viewsize, sceneratio)
	local rt = q.render_target
	local vr = rt.view_rect
	check_viewrect_size(vr, viewsize, sceneratio)

	if q.camera_ref then
		local camera <close> = world:entity(q.camera_ref)
		icamera.update_frustum(camera, vr.w, vr.h)
	end
	resize_framebuffer(vr.w, vr.h, rt.fb_idx)
	irq.update_rendertarget(q.queue_name, rt)
end

local function update_render_target(viewsize, sceneratio)
	clear_cache()
	for qe in w:select "watch_screen_buffer render_target:in queue_name:in camera_ref?in" do
		update_render_queue(qe, viewsize, sceneratio)
	end

	for qe in w:select "render_target:in watch_screen_buffer:absent" do
		local rt = qe.render_target
		local viewid = rt.viewid
		local fbidx = rt.fb_idx
		fbmgr.bind(viewid, fbidx)
	end
end

function vp_detect_sys:post_init()
	update_render_target()
end

local vp_changed_mb = world:sub{"world_viewport_changed"}
local scene_vp_changed_mb = world:sub{"scene_viewport_ratio_changed"}

function vp_detect_sys:data_changed()
	for _, vp in vp_changed_mb:unpack() do
		if vp.w ~= 0 and vp.h ~= 0 then
			update_render_target(vp, world.args.framebuffer.scene_ratio)
			break
		end
	end

	for _, newratio in scene_vp_changed_mb:unpack() do
		if newratio <= 1e-6 then
			error "scene ratio should larger than 0"
		end

		update_render_target(world.args.viewport, newratio)
		do
			local mq = w:first "main_queue render_target:in"
			local vr = mq.render_target.view_rect
			log.info(("scene viewrect:x=%2f, y=%2f, w=%2f, h=%2f, scene_ratio=%2f"):format(vr.x, vr.y, vr.w, vr.h, vr.ratio or 1.0))
		end

		world.args.framebuffer.scene_ratio = newratio
		break
	end
end
