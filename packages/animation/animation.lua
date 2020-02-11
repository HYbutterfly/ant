local ecs = ...
local world = ecs.world

local asset = import_package "ant.asset".mgr
local ani_module = require "hierarchy.animation"

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack

ecs.component "pose_result"

local pr_p = ecs.policy "pose_result"
pr_p.require_component "skeleton"

pr_p.require_transform "pose_result_transform"

local pr_t = ecs.transform "pose_result_transform"
pr_t.input "skeleton"
pr_t.output "pose_result"

function pr_t.process(e)
	local ske = asset.get_resource(e.skeleton.ref_path)
	local skehandle = ske.handle
	e.pose_result.result = ani_module.new_bind_pose(#skehandle)
end


--there are 2 types in ik_data, which are 'two_bone'(IKTwoBoneJob) and 'aim'(IKAimJob).
ecs.component "ik_data"
	.name		"string"
	.type		"string"("aim")			-- can be 'two_bone'/'aim'
	.target 	"vector"{0, 0, 0, 1}	-- model space
	.pole_vector"vector"{0, 0, 0, 0}	-- model space
	.twist_angle"real" 	(0.0)
	.joints		"string[]"{}			-- type == 'aim', #joints == 1, type == 'two_bone', #joints == 3, with start/mid/end
	["opt"].mid_axis"vector" {0, 0, 1, 0}
	["opt"].soften "real" 	(0.0)
	["opt"].up_axis"vector" {0, 1, 0, 0}
	["opt"].forward "vector"{0, 0, 1, 0}-- local space
	["opt"].offset "vector" {0, 0, 0, 0}-- local space

ecs.component "ik"
	.jobs 'ik_data[]'

local ik_p = ecs.policy "ik"
ik_p.require_component "skeleton"
ik_p.require_component "ik"

ik_p.require_policy "pose_result"

ecs.component "animation_content"
	.ref_path "respath"
	.scale "real" (1)
	.looptimes "int" (0)

local ap = ecs.policy "animation"
ap.require_component "skeleton"
ap.require_component "animation"
ap.require_component "pose_result"

ap.require_policy "pose_result"

ap.require_system "animation_system"

local anicomp = ecs.component "animation"
	.anilist "animation_content{}"
	.birth_pose "string"

function anicomp:init()
	for name, ani in pairs(self.anilist) do
		ani.handle = asset.get_resource(ani.ref_path).handle
		ani.sampling_cache = ani_module.new_sampling_cache()
		ani.duration = ani.handle:duration() * 1000. / ani.scale
		ani.max_time = ani.looptimes > 0 and (ani.looptimes * ani.duration) or math.maxinteger
		ani.name = name
	end
	self.current = {
		animation = self.anilist[self.birth_pose],
		start_time = 0,
	}
	return self
end

ecs.component_alias("skeleton", "resource")

local anisystem = ecs.system "animation_system"
anisystem.require_interface "ant.timer|timer"

local timer = world:interface "ant.timer|timer"

local ikdata_cache = {}
local function prepare_ikdata(invtran, ikdata)
	ikdata_cache.type		= ikdata.type
	ikdata_cache.target 	= ms(ikdata.target, "m")
	ikdata_cache.pole_vector= ms(ikdata.pole_vector, "m")
	ikdata_cache.weight		= ikdata.weight
	ikdata_cache.twist_angle= ikdata.twist_angle
	ikdata_cache.joints 	= ikdata.joints

	if ikdata.type == "aim" then
		ikdata_cache.forward	= ms(ikdata.forward, "m")
		ikdata_cache.up_axis	= ms(ikdata.up_axis, "m")
		ikdata_cache.offset		= ms(ikdata.offset, "m")
	else
		assert(ikdata.type == "two_bone")
		ikdata_cache.soften		= ikdata.soften
		ikdata_cache.mid_axis	= ms(ikdata.mid_axis, "m")
	end
	return ikdata_cache
end

local fix_root <const> = true

function anisystem:sample_animation_pose()
	local current_time = timer.current()

	local function do_animation(task)
		if task.type == 'blend' then
			for _, t in ipairs(task) do
				do_animation(t)
			end
			ani_module.do_blend("blend", #task, task.weight)
		else
			local ani = task.animation
			local localtime = current_time - task.start_time
			local ratio = 0
			if localtime <= ani.max_time then
				ratio = localtime % ani.duration / ani.duration
			end
			ani_module.do_sample(ani.sampling_cache, ani.handle, ratio, task.weight)
		end
	end

	for _, eid in world:each "animation" do
		local e = world[eid]
		local animation = e.animation
		local ske = asset.get_resource(e.skeleton.ref_path)

		ani_module.setup(e.pose_result.result, ske.handle, fix_root)
		do_animation(animation.current)
		ani_module.fetch_result()
	end
end

function anisystem:do_ik()
	for _, eid in world:each "ik" do
		local e = world[eid]
		local ikcomp = e.ik
		local skehandle = asset.get_resource(e.skeleton.ref_path).handle
		
		ani_module.setup(e.pose_result.result, skehandle, fix_root)
		for _, job in ipairs(ikcomp.jobs) do
			ani_module.do_ik(skehandle, prepare_ikdata(job))
		end
	end
end

function anisystem:end_animation()
	ani_module.end_animation()
end