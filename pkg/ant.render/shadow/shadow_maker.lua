-- TODO: should move to scene package

local ecs = ...
local world = ecs.world
local w     = world.w

local setting	= import_package "ant.settings".setting
local ENABLE_SHADOW<const> = setting:get "graphic/shadow/enable"
local renderutil= require "util"
local sm = ecs.system "shadow_system"
local istonemountain = ecs.import.interface "ant.render|istonemountain"
if not ENABLE_SHADOW then
	renderutil.default_system(sm, 	"init",
									"init_world",
									"entity_init",
									"entity_remove",
									"update_camera",
									--"refine_filter",
									"refine_camera",
									"render_submit",
									"camera_usage",
									"update_filter")
	return
end

local viewidmgr = require "viewid_mgr"
--local mu		= mathpkg.util
local mc 		= import_package "ant.math".constant

local math3d	= require "math3d"
local bgfx		= require "bgfx"
local icamera	= ecs.import.interface "ant.camera|icamera"
local ishadow	= ecs.import.interface "ant.render|ishadow"
local irender	= ecs.import.interface "ant.render|irender"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local iom		= ecs.import.interface "ant.objcontroller|iobj_motion"
local fbmgr		= require "framebuffer_mgr"
local INV_Z<const> = true

local csm_matrices			= {mc.IDENTITY_MAT, mc.IDENTITY_MAT, mc.IDENTITY_MAT, mc.IDENTITY_MAT}
local split_distances_VS	= math3d.ref(math3d.vector(math.maxinteger, math.maxinteger, math.maxinteger, math.maxinteger))

local function update_camera_matrices(camera, light_view)
	camera.viewmat.m = light_view
	camera.projmat.m = math3d.projmat(camera.frustum, INV_Z)
	camera.viewprojmat.m = math3d.mul(camera.projmat, camera.viewmat)
end

local function set_worldmat(srt, mat)
	math3d.unmark(srt.worldmat)
	srt.worldmat = math3d.mark(math3d.matrix(mat))
end

local function calc_csm_matrix_attrib(csmidx, vp)
	return math3d.mul(ishadow.crop_matrix(csmidx), vp)
end

-- --local sm_bias_matrix = mu.calc_texture_matrix()
-- local biasX,biasY,biasZ
-- -- local function create_crop_matrix(shadow)
-- -- 	local view_camera = world.main_queue_camera(world)

-- -- 	local csm = shadow.csm
-- -- 	local csmindex = csm.index
-- -- 	local shadowcamera = world[shadow.camera_ref].camera
-- -- 	local shadow_viewmatrix = mu.view_proj(shadowcamera)

-- -- 	local bb_LS = get_frustum_points(view_camera, view_camera.frustum, shadow_viewmatrix, shadow.csm.split_ratios)
-- -- 	local aabb = bb_LS:get "aabb"
-- -- 	local min, max = aabb.min, aabb.max

-- -- 	local proj = math3d.projmat(shadowcamera.frustum)
-- -- 	local minproj, maxproj = math3d.transformH(proj, min) math3d.transformH(proj, max)

-- -- 	local scalex, scaley = math3d.mul(2, math3d.reciprocal(math3d.sub(maxproj, minproj)))
-- -- 	if csm.stabilize then
-- -- 		local quantizer = shadow.shadowmap_size
-- -- 		scalex = quantizer / math.ceil(quantizer / scalex);
-- -- 		scaley = quantizer / math.ceil(quantizer / scaley);
-- -- 	end

-- local function calc_offset(a, b, scale)
--  	return (a + b) * -0.5 * scale
-- end

-- -- 	local offsetx, offsety = 
-- -- 		calc_offset(maxproj[1], minproj[1], scalex), 
-- -- 		calc_offset(maxproj[2], minproj[2], scaley)

-- -- 	if csm.stabilize then
-- -- 		local half_size = shadow.shadowmap_size * 0.5;
-- -- 		offsetx = math.ceil(offsetx * half_size) / half_size;
-- -- 		offsety = math.ceil(offsety * half_size) / half_size;
-- -- 	end
	
-- -- 	return {
-- -- 		scalex, 0, 0, 0,
-- -- 		0, scaley, 0, 0,
-- -- 		0, 0, 1, 0,
-- -- 		offsetx, offsety, 0, 1,
-- -- 	}
-- -- end

-- local function keep_shadowmap_move_one_texel(minextent, maxextent, shadowmap_size)
-- 	local texsize = 1 / shadowmap_size

-- 	local unit_pretexel = math3d.mul(math3d.sub(maxextent, minextent), texsize)
-- 	local invunit_pretexel = math3d.reciprocal(unit_pretexel)
-- 	local function limit_move_in_one_texel(value)
-- 		-- value /= unit_pretexel;
-- 		-- value = floor( value );
-- 		-- value *= unit_pretexel;
-- 		return math3d.tovalue(
-- 			math3d.mul(math3d.floor(math3d.mul(math3d.vector(value), invunit_pretexel)), unit_pretexel))
-- 	end

-- 	local newmin = limit_move_in_one_texel(minextent)
-- 	local newmax = limit_move_in_one_texel(maxextent)
	
-- 	minextent[1], minextent[2] = newmin[1], newmin[2]
-- 	maxextent[1], maxextent[2] = newmax[1], newmax[2]
-- end

-- local function calc_shadow_camera_from_corners(corners_WS, lightdir, shadowmap_size, stabilize, shadow_ce,csm_index,ortho)
-- 	local center_WS = math3d.points_center(corners_WS)
-- 	local min_extent, max_extent

-- 	iom.set_rotation(shadow_ce, math3d.torotation(lightdir))
-- 	iom.set_position(shadow_ce, center_WS)
-- 	set_worldmat(shadow_ce.scene, shadow_ce.scene)

-- 	local camera = shadow_ce.camera
-- 	if stabilize then
-- 		local radius = math3d.points_radius(corners_WS, center_WS)
-- 		--radius = math.ceil(radius * 16.0) / 16.0	-- round to 16
-- 		min_extent, max_extent = {-radius, -radius, -radius}, {radius, radius, radius}
-- 		keep_shadowmap_move_one_texel(min_extent, max_extent, shadowmap_size)
-- 	else
--  		local minv, maxv = math3d.minmax(corners_WS, math3d.inverse(shadow_ce.scene.worldmat))
-- 		min_extent, max_extent = math3d.tovalue(minv), math3d.tovalue(maxv)
-- --[[  		local minproj, maxproj = math3d.transformH(ortho, minv),math3d.transformH(ortho, maxv)
-- 		local scalesub = math3d.sub(maxproj,minproj)
-- 		local scaleadd = math3d.add(maxproj, minproj)
-- 		local scalex = 2.0 / math3d.index(scalesub, 1)
-- 		local scaley = 2.0 / math3d.index(scalesub, 2)
-- 		local quantizer = 64.0
-- 		scalex = quantizer / math.ceil(quantizer / scalex)
-- 		scaley = quantizer / math.ceil(quantizer / scaley)
-- 		local offsetx = 0.5 * math3d.index(scaleadd, 1) * scalex
-- 		local offsety = 0.5 * math3d.index(scaleadd, 2) * scaley
-- 		local half_size = shadowmap_size * 0.5
-- 		offsetx = math.ceil(offsetx * half_size) / half_size
-- 		offsety = math.ceil(offsety * half_size) / half_size
-- 		local crop = math3d.matrix{
-- 	 		scalex, 0, 0, 0,
-- 	 		0, scaley, 0, 0,
-- 	 		0, 0, 1, 0,
-- 	 		offsetx, offsety, 0, 1,		
-- 		}
-- 		camera.viewmat = math3d.inverse(shadow_ce.scene.worldmat)
-- 		camera.projmat = math3d.mul(crop,ortho)
-- 		camera.viewprojmat = math3d.mul(camera.projmat, camera.viewmat)   ]]
-- 	end
--   	local f = camera.frustum
-- 	f.l, f.b, f.n = min_extent[1], min_extent[2], min_extent[3]
-- 	f.r, f.t, f.f = max_extent[1], max_extent[2], max_extent[3]
-- 	update_camera_matrices(camera, shadow_ce.scene.worldmat,csm_index) 
 
-- 	do
-- 		-- local ident_projmat = math3d.projmat{
-- 		-- 	ortho=true,
-- 		-- 	l=-1, r=1, b=-1, t=1, n=-100, f=100,
-- 		-- }

-- 		-- local minv, maxv = math3d.minmax(corners_WS, camera_rc.viewmat)
-- 		-- local minv_proj, maxv_proj = math3d.transformH(ident_projmat, minv, 1), math3d.transformH(ident_projmat, maxv, 1)
-- 		-- -- scale = 2 / (maxv_proj-minv_proj)
-- 		-- local scale = math3d.mul(2, math3d.reciprocal(math3d.sub(maxv_proj, minv_proj)))
-- 		-- -- offset = 0.5 * (minv_proj+maxv_proj) * scale
-- 		-- local offset = math3d.mul(scale, math3d.mul(0.5, math3d.add(minv_proj, maxv_proj)))
-- 		-- local scalex, scaley = math3d.index(scale, 1, 2)
-- 		-- local offsetx, offsety = math3d.index(offset, 1, 2)
-- 		-- local lightproj = math3d.mul(math3d.matrix(
-- 		-- scalex, 0.0, 	0.0, 0.0,
-- 		-- 0.0,	scaley,	0.0, 0.0,
-- 		-- 0.0,	0.0,	1.0, 0.0,
-- 		-- offsetx,offsety,0.0, 1.0
-- 		-- ), ident_projmat)

-- 		-- camera_rc.projmat = lightproj
-- 		-- camera_rc.viewprojmat = math3d.mul(camera_rc.projmat, camera_rc.viewmat)
-- 	end
-- end


-- local function calc_shadow_camera(viewmat, frustum, lightdir, shadowmap_size, stabilize, shadow_ce,csm_index,ortho)
-- 	local vp = math3d.mul(math3d.projmat(frustum, INV_Z), viewmat)

-- 	local corners_WS = math3d.frustum_points(vp)
-- 	calc_shadow_camera_from_corners(corners_WS, lightdir, shadowmap_size, stabilize, shadow_ce,csm_index,ortho)
-- end

-- -- local function calc_split_distance(frustum)
-- -- 	local corners_VS = math3d.frustum_points(math3d.projmat(frustum))
-- -- 	local minv, maxv = math3d.minmax(corners_VS)
-- -- 	return math3d.index(maxv, 3)
-- -- end

-- local function update_shadow_camera(dl, maincamera)
-- 	local lightdir = iom.get_direction(dl)
-- 	local setting = ishadow.setting()
-- 	local viewmat = maincamera.viewmat
-- 	local csmfrustums = ishadow.calc_split_frustums(maincamera.frustum)
-- 	local frustum = {
-- 		l = -1, r = 1, t = -1, b = 1,
-- 		n = 1, f = 100, ortho = true,
-- 	}
-- 	local ortho = math3d.projmat(frustum,INV_Z)
-- 	for qe in w:select "csm:in camera_ref:in" do
-- 		local csm = qe.csm
-- 		local vf = csmfrustums[csm.index]--csm.view_frustum
-- 		local shadow_ce <close> = w:entity(qe.camera_ref, "camera:in")
-- 		calc_shadow_camera(viewmat, vf, lightdir, setting.shadowmap_size, false, shadow_ce,csm.index,ortho)
-- 		csm_matrices[csm.index] = calc_csm_matrix_attrib(csm.index, shadow_ce.camera.viewprojmat)
-- 		--csm_matrices[csm.index] = calc_csm_matrix_attrib(csm.index, shadow_ce.camera.projmat,shadow_ce.camera.viewmat)
-- 		split_distances_VS[csm.index] = vf.f
-- 	end
-- end

local function calc_ortho_minmax(corners_light_view, shadowmap_size)
	local light_ortho_min, light_ortho_max = math3d.minmax(corners_light_view)
	local diagonal = math3d.sub(math3d.array_index(corners_light_view, 1), math3d.array_index(corners_light_view, 8))
	local bound = math3d.length(diagonal)
	diagonal = math3d.vector(bound, bound, bound)

	local offset = math3d.mul(math3d.sub(diagonal, math3d.sub(light_ortho_max, light_ortho_min)), 0.5)
	offset = math3d.vector(math3d.index(offset, 1), math3d.index(offset, 2), 0)
	light_ortho_max = math3d.add(light_ortho_max, offset)
	light_ortho_min = math3d.sub(light_ortho_min, offset)
	local world_unit_per_texel = bound / shadowmap_size
	local vworld_unit_per_texel = math3d.vector(world_unit_per_texel, world_unit_per_texel, 0)

	light_ortho_min = math3d.mul(light_ortho_min, math3d.reciprocal(vworld_unit_per_texel))
	light_ortho_min = math3d.floor(light_ortho_min)
	light_ortho_min = math3d.mul(light_ortho_min, vworld_unit_per_texel)
	light_ortho_max = math3d.mul(light_ortho_max, math3d.reciprocal(vworld_unit_per_texel))
	light_ortho_max = math3d.floor(light_ortho_max)
	light_ortho_max = math3d.mul(light_ortho_max, vworld_unit_per_texel)
	
	return light_ortho_min, light_ortho_max
end

local aabb_tri_indexes = {
	[1] = {1, 2, 3},
	[2] = {2, 3, 4},
	[3] = {5, 6, 7},
	[4] = {6, 7, 8},
	[5] = {1, 3, 5},
	[6] = {3, 5, 7},
	[7] = {2, 4, 6},
	[8] = {4, 6, 8},
	[9] = {1, 2, 5},
	[10] = {2, 5, 6},
	[11] = {3, 4, 7},
	[12] = {4, 7, 8}	
}

local function compute_near_far(light_ortho_min, light_ortho_max, light_view_aabb_points)
	local near = 100000000
	local far  = -100000000
	local triangle_list = {}
	for i = 1, 16 do 
		local tri = {
			pt = {},
			culled = true
		}
		local default_v = math3d.vector(far, far, far)
		tri.pt[1], tri.pt[2], tri.pt[3] = default_v, default_v, default_v
		triangle_list[i] = tri
	end

	local triangle_cnt  = 1
	triangle_list[1] = {
		pt = {
			[1] = light_view_aabb_points[1],
			[2] = light_view_aabb_points[2],
			[3] = light_view_aabb_points[3]
		},
		culled = false 
	}
	local point_passes_collision = {}
	local light_ortho_min_x, light_ortho_min_y = light_ortho_min[1], light_ortho_min[2]
	local light_ortho_max_x, light_ortho_max_y = light_ortho_max[1], light_ortho_max[2]
	for aabb_idx = 1, 12 do
		local aabb_tri = aabb_tri_indexes[aabb_idx]
		triangle_list[1].pt[1] = light_view_aabb_points[aabb_tri[1]]
		triangle_list[1].pt[2] = light_view_aabb_points[aabb_tri[2]]
		triangle_list[1].pt[3] = light_view_aabb_points[aabb_tri[3]]
		triangle_cnt = 1
		triangle_list[1].culled = false

		for frustum_plane_idx = 1, 4 do
			local fEdge
			local iComponent
			if frustum_plane_idx == 1 then
				fEdge = light_ortho_min_x
				iComponent = 1
			elseif frustum_plane_idx == 2 then
				fEdge = light_ortho_max_x
				iComponent = 1
			elseif frustum_plane_idx == 3 then
				fEdge = light_ortho_min_y
				iComponent = 2
			elseif frustum_plane_idx == 4 then
				fEdge = light_ortho_max_y
				iComponent = 2
			end

			for tri_idx = 1, triangle_cnt do
				if not triangle_list[tri_idx].culled then
					local inside_vert_cnt = 0
					local temp_order = {}
					if frustum_plane_idx == 1 then
						for tri_Pt_idx = 1, 3 do
							if math3d.index(triangle_list[tri_idx].pt[tri_Pt_idx], 1) > light_ortho_min_x then
								point_passes_collision[tri_Pt_idx] = 1
							else
								point_passes_collision[tri_Pt_idx] = 0
							end
							inside_vert_cnt = inside_vert_cnt + point_passes_collision[tri_Pt_idx]
						end
					elseif frustum_plane_idx == 2 then
						for tri_Pt_idx = 1, 3 do
							if math3d.index(triangle_list[tri_idx].pt[tri_Pt_idx], 1) < light_ortho_max_x then
								point_passes_collision[tri_Pt_idx] = 1
							else
								point_passes_collision[tri_Pt_idx] = 0
							end
							inside_vert_cnt = inside_vert_cnt + point_passes_collision[tri_Pt_idx]
						end
					elseif frustum_plane_idx == 3 then
						for tri_Pt_idx = 1, 3 do
							if math3d.index(triangle_list[tri_idx].pt[tri_Pt_idx], 2) > light_ortho_min_y then
								point_passes_collision[tri_Pt_idx] = 1
							else
								point_passes_collision[tri_Pt_idx] = 0
							end
							inside_vert_cnt = inside_vert_cnt + point_passes_collision[tri_Pt_idx]
						end
					else

						for tri_Pt_idx = 1, 3 do
							if math3d.index(triangle_list[tri_idx].pt[tri_Pt_idx], 2) < light_ortho_max_y then
								point_passes_collision[tri_Pt_idx] = 1
							else
								point_passes_collision[tri_Pt_idx] = 0
							end
							inside_vert_cnt = inside_vert_cnt + point_passes_collision[tri_Pt_idx]
						end						
					end

					if point_passes_collision[2] == 1 and point_passes_collision[1] == 0 then
						temp_order = triangle_list[tri_idx].pt[1]
						triangle_list[tri_idx].pt[1] = triangle_list[tri_idx].pt[2]
						triangle_list[tri_idx].pt[2] = temp_order
						point_passes_collision[1] = 1
						point_passes_collision[2] = 0
					end
					if point_passes_collision[3] == 1 and point_passes_collision[2] == 0 then
						temp_order = triangle_list[tri_idx].pt[2]
						triangle_list[tri_idx].pt[2] = triangle_list[tri_idx].pt[3]
						triangle_list[tri_idx].pt[3] = temp_order
						point_passes_collision[2] = 1
						point_passes_collision[3] = 0
					end
					if point_passes_collision[2] == 1 and point_passes_collision[1] == 0 then
						temp_order = triangle_list[tri_idx].pt[1]
						triangle_list[tri_idx].pt[1] = triangle_list[tri_idx].pt[2]
						triangle_list[tri_idx].pt[2] = temp_order
						point_passes_collision[1] = 1
						point_passes_collision[2] = 0
					end
					if inside_vert_cnt == 0 then
						triangle_list[tri_idx].culled = true
					elseif inside_vert_cnt == 1 then
						triangle_list[tri_idx].culled = false
						local vert0_to_vert1 = math3d.sub(triangle_list[tri_idx].pt[2], triangle_list[tri_idx].pt[1])
						local vert0_to_vert2 = math3d.sub(triangle_list[tri_idx].pt[3], triangle_list[tri_idx].pt[1])
						local hit_point_time_ratio = fEdge - math3d.index(triangle_list[tri_idx].pt[1], iComponent)
						local distance_along_vector01 = hit_point_time_ratio / math3d.index(vert0_to_vert1, iComponent)
						local distance_along_vector02 = hit_point_time_ratio / math3d.index(vert0_to_vert2, iComponent)
						vert0_to_vert1 = math3d.add(math3d.mul(vert0_to_vert1, distance_along_vector01), triangle_list[tri_idx].pt[1])
						vert0_to_vert2 = math3d.add(math3d.mul(vert0_to_vert2, distance_along_vector02), triangle_list[tri_idx].pt[1])

						triangle_list[tri_idx].pt[2] = vert0_to_vert2
						triangle_list[tri_idx].pt[3] = vert0_to_vert1
					elseif inside_vert_cnt == 2 then
						triangle_list[triangle_cnt] = triangle_list[tri_idx+1]
						triangle_list[tri_idx].culled = false
						triangle_list[tri_idx+1].culled = false
						local vert2_to_vert0 = math3d.sub(triangle_list[tri_idx].pt[1], triangle_list[tri_idx].pt[3])
						local vert2_to_vert1 = math3d.sub(triangle_list[tri_idx].pt[2], triangle_list[tri_idx].pt[3])
						local hit_point_time_2_0 = fEdge - math3d.index(triangle_list[tri_idx].pt[3], iComponent)
						local distance_along_vector_2_0 = hit_point_time_2_0 / math3d.index(vert2_to_vert0, iComponent)
						vert2_to_vert0 = math3d.add(math3d.mul(vert2_to_vert0, distance_along_vector_2_0), triangle_list[tri_idx].pt[3])

						triangle_list[tri_idx+1].pt[1] = triangle_list[tri_idx].pt[1]
						triangle_list[tri_idx+1].pt[2] = triangle_list[tri_idx].pt[2]
						triangle_list[tri_idx+1].pt[3] = vert2_to_vert0

						local hit_point_time_2_1 = fEdge - math3d.index(triangle_list[tri_idx].pt[3], iComponent)
						local distance_along_vector_2_1 = hit_point_time_2_1 / math3d.index(vert2_to_vert1, iComponent)
						vert2_to_vert1 = math3d.add(math3d.mul(vert2_to_vert1, distance_along_vector_2_1), triangle_list[tri_idx].pt[3])

						triangle_list[tri_idx].pt[1] = triangle_list[tri_idx+1].pt[2]
						triangle_list[tri_idx].pt[2] = triangle_list[tri_idx+1].pt[3]
						triangle_list[tri_idx].pt[3] = vert2_to_vert1	
						
						triangle_cnt = triangle_cnt + 1
						tri_idx = tri_idx + 1
					else
						triangle_list[tri_idx].culled = false
					end
				end
			end
		end

		for idx = 1, triangle_cnt do
			if not triangle_list[idx].culled then
				for vert_idx = 1, 3 do
					local tri_z = math3d.index(triangle_list[idx].pt[vert_idx], 3)
					if near > tri_z then
						near = tri_z
					end
					if far < tri_z then
						far = tri_z
					end
				end
			end
		end
	end
	return near, far
end

local function update_csm_frustum(lightdir, shadowmap_size, csm_frustum, shadow_ce, main_view, world_scene_aabb)
	iom.set_rotation(shadow_ce, math3d.torotation(lightdir))
	set_worldmat(shadow_ce.scene, shadow_ce.scene)

	local camera_proj = math3d.projmat(csm_frustum, INV_Z)
	local light_world = shadow_ce.scene.worldmat
	local light_view = math3d.inverse(light_world)
	-- light_view main_view-1 camera_proj-1 homo
	-- camera_proj main_view light_world
	local light_view_to_homo = math3d.mul(camera_proj, math3d.mul(main_view, light_world))
	local corners_light_view = math3d.frustum_points(light_view_to_homo)

	local light_ortho_min, light_ortho_max = calc_ortho_minmax(corners_light_view, shadowmap_size)
	--[[ local light_view_scene_aabb = math3d.aabb_transform(light_view, world_scene_aabb)
	local light_frustum_aabb = math3d.aabb(light_ortho_min, light_ortho_max)
	local light_intersected_aabb = math3d.aabb_intersection(light_frustum_aabb, light_view_scene_aabb)
	local light_intersected_aabb = light_view_scene_aabb
	local min_intersected, max_intersected = math3d.tovalue(math3d.array_index(light_intersected_aabb, 1)), math3d.tovalue(math3d.array_index(light_intersected_aabb, 2)) ]]
 	local camera = shadow_ce.camera
	local f = camera.frustum
 	local minx, miny = math3d.index(light_ortho_min, 1, 2)
	local maxx, maxy = math3d.index(light_ortho_max, 1, 2) 
	f.l, f.b, f.n = minx, miny, csm_frustum.n
	f.r, f.t, f.f = maxx, maxy, csm_frustum.f * 10
	update_camera_matrices(camera, light_view)
end

--[[ local select_table = {
	[1] = "csm1_"
} ]]
local function update_shadow_frustum(dl, main_camera)
	local lightdir = iom.get_direction(dl)
	local shadow_setting = ishadow.setting()
	local csm_frustums = ishadow.calc_split_frustums(main_camera.frustum)
	local main_view = main_camera.viewmat

	--calculate scene_aabb in world space
 	local world_scene_aabb = math3d.aabb()
--[[ 	for e in w:select "scene:in render_object:in bounding:in name?in" do
		if e.bounding.scene_aabb and e.bounding.scene_aabb ~= mc.NULL then
			if not math3d.aabb_isvalid(world_scene_aabb) then
				world_scene_aabb = e.bounding.scene_aabb
			else
				if math3d.aabb_isvalid(e.bounding.scene_aabb) then
					world_scene_aabb = math3d.aabb_merge(world_scene_aabb, e.bounding.scene_aabb)
				end
			end
		end
	end  ]]
	for qe in w:select "csm:in camera_ref:in" do
		local csm = qe.csm
--[[ 		local queue_name = "csm" .. csm.index
 		local sm_aabb = math3d.ref(istonemountain.get_sm_aabb(queue_name))
		if math3d.aabb_isvalid(sm_aabb) then
			world_scene_aabb = math3d.aabb_merge(sm_aabb, world_scene_aabb)
		end  ]]
		local csm_frustum = csm_frustums[csm.index]
		csm_frustum.n = 1
		local shadow_ce <close> = w:entity(qe.camera_ref, "camera:in scene:in")
		update_csm_frustum(lightdir, shadow_setting.shadowmap_size, csm_frustum, shadow_ce, main_view, world_scene_aabb)
		csm_matrices[csm.index] = calc_csm_matrix_attrib(csm.index, shadow_ce.camera.viewprojmat)
		split_distances_VS[csm.index] = csm_frustum.f
	end
end

local function create_clear_shadowmap_queue(fbidx)
	local rb = fbmgr.get_rb(fbidx, 1)
	local ww, hh = rb.w, rb.h
	ecs.create_entity{
		policy = {
			"ant.render|postprocess_queue",
			"ant.general|name",
		},
		data = {
			render_target = {
				clear_state = {
					depth = 0,
					clear = "D",
				},
				fb_idx = fbidx,
				viewid = viewidmgr.get "csm_fb",
				view_rect = {x=0, y=0, w=ww, h=hh},
			},
			clear_sm = true,
			queue_name = "clear_sm",
			name = "clear_sm",
		}
	}
end

local function create_csm_entity(index, vr, fbidx)
	local csmname = "csm" .. index
	local queuename = csmname .. "_queue"
	local camera_ref = icamera.create {
			updir 	= mc.YAXIS,
			viewdir = mc.ZAXIS,
			eyepos 	= mc.ZERO_PT,
			frustum = {
				l = -1, r = 1, t = -1, b = 1,
				n = 1, f = 100, ortho = true,
			},
			name = csmname
		}
	ecs.create_entity {
		policy = {
			"ant.render|render_queue",
			"ant.render|cull",
			"ant.render|csm_queue",
			"ant.general|name",
		},
		data = {
			csm = {
				index = index,
			},
			camera_ref = camera_ref,
			render_target = {
				viewid = viewidmgr.get(csmname),
				view_rect = {x=vr.x, y=vr.y, w=vr.w, h=vr.h},
				clear_state = {
					clear = "",
				},
				fb_idx = fbidx,
			},
			visible = false,
			queue_name = queuename,
			[queuename] = true,
			name = "csm" .. index,
			camera_depend = true
		},
	}
end

local shadow_material
local gpu_skinning_material
local shadow_sm_material
function sm:init()
	local fbidx = ishadow.fb_index()
	local s = ishadow.shadowmap_size()
	create_clear_shadowmap_queue(fbidx)
	shadow_material = imaterial.load_res "/pkg/ant.resources/materials/depth.material"
	gpu_skinning_material = imaterial.load_res "/pkg/ant.resources/materials/depth_skin.material"
	shadow_sm_material = imaterial.load_res "/pkg/ant.resources/materials/depth_sm.material"
	for ii=1, ishadow.split_num() do
		local vr = {x=(ii-1)*s, y=0, w=s, h=s}
		create_csm_entity(ii, vr, fbidx)
	end
end

-- local function main_camera_changed(ceid)
-- 	local camera <close> = w:entity(ceid, "camera:in").camera
-- 	local csmfrustums = ishadow.calc_split_frustums(camera.frustum)
-- 	for cqe in w:select "csm:in" do
-- 		local csm = cqe.csm
-- 		local idx = csm.index
-- 		local cf = assert(csmfrustums[csm.index])
-- 		csm.view_frustum = cf
-- 		split_distances_VS[idx] = cf.f
-- 	end
-- end

local function set_csm_visible(enable)
	for v in w:select "csm visible?out" do
		v.visible = enable
	end
end

function sm:entity_init()
	for e in w:select "INIT make_shadow directional_light light:in" do
		local csm_dl = w:first("csm_directional_light light:in")
		if csm_dl == nil then
			e.csm_directional_light = true
			w:extend(e, "csm_directional_light?out")
			set_csm_visible(true)
		else
			error("already have 'make_shadow' directional light")
		end
	end
end

function sm:entity_remove()
	for _ in w:select "REMOVED csm_directional_light" do
		set_csm_visible(false)
	end
end

local function commit_csm_matrices_attribs()
	local sa = imaterial.system_attribs()
	sa:update("u_csm_matrix", csm_matrices)
	sa:update("u_csm_split_distances", split_distances_VS)
end

function sm:init_world()
	local sa = imaterial.system_attribs()
	sa:update("s_shadowmap", fbmgr.get_rb(ishadow.fb_index(), 1).handle)
	sa:update("u_shadow_param1", ishadow.shadow_param())
	sa:update("u_shadow_param2", ishadow.shadow_param2())
end

function sm:update_camera_depend()
	local dl = w:first("csm_directional_light light:in scene:in scene_changed?in")
	if dl then
		local mq = w:first("main_queue camera_ref:in")
		local camera <close> = w:entity(mq.camera_ref, "camera:in")
		--update_shadow_camera(dl, camera.camera)
		update_shadow_frustum(dl, camera.camera)
		commit_csm_matrices_attribs()
	end
end



function sm:refine_camera()
	-- local setting = ishadow.setting()
	-- for se in w:select "csm primitive_filter:in"
	-- 	local se = world[eid]
	-- assert(false && "should move code new ecs")
	-- 		local filter = se.primitive_filter.result
	-- 		local sceneaabb = math3d.aabb()
	
	-- 		local function merge_scene_aabb(sceneaabb, filtertarget)
	-- 			for _, item in ipf.iter_target(filtertarget) do
	-- 				if item.aabb then
	-- 					sceneaabb = math3d.aabb_merge(sceneaabb, item.aabb)
	-- 				end
	-- 			end
	-- 			return sceneaabb
	-- 		end
	
	-- 		sceneaabb = merge_scene_aabb(sceneaabb, filter.opacity)
	-- 		sceneaabb = merge_scene_aabb(sceneaabb, filter.translucent)
	
	-- 		if math3d.aabb_isvalid(sceneaabb) then
	-- 			local camera_rc = world[se.camera_ref]._rendercache
	
	-- 			local function calc_refine_frustum_corners(rc)
	-- 				local frustm_points_WS = math3d.frustum_points(rc.viewprojmat)
	-- 				local frustum_aabb_WS = math3d.points_aabb(frustm_points_WS)
		
	-- 				local scene_frustum_aabb_WS = math3d.aabb_intersection(sceneaabb, frustum_aabb_WS)
	-- 				local max_frustum_aabb_WS = math3d.aabb_merge(sceneaabb, frustum_aabb_WS)
	-- 				local _, extents = math3d.aabb_center_extents(scene_frustum_aabb_WS)
	-- 				extents = math3d.mul(0.1, extents)
	-- 				scene_frustum_aabb_WS = math3d.aabb_expand(scene_frustum_aabb_WS, extents)
					
	-- 				local max_frustum_aabb_VS = math3d.aabb_transform(rc.viewmat, max_frustum_aabb_WS)
	-- 				local max_n, max_f = math3d.index(math3d.array_index(max_frustum_aabb_VS, 1), 3), math3d.index(math3d.array_index(max_frustum_aabb_VS, 2), 3)
	
	-- 				local scene_frustum_aabb_VS = math3d.aabb_transform(rc.viewmat, scene_frustum_aabb_WS)
	
	-- 				local minv, maxv = math3d.array_index(scene_frustum_aabb_VS, 1), math3d.array_index(scene_frustum_aabb_VS, 2)
	-- 				minv, maxv = math3d.set_index(minv, 3, max_n), math3d.set_index(maxv, 3, max_f)
	-- 				scene_frustum_aabb_VS = math3d.aabb(minv, maxv)
					
	-- 				scene_frustum_aabb_WS = math3d.aabb_transform(rc.worldmat, scene_frustum_aabb_VS)
	-- 				return math3d.aabb_points(scene_frustum_aabb_WS)
	-- 			end
	
	-- 			local aabb_corners_WS = calc_refine_frustum_corners(camera_rc)
	
	-- 			local lightdir = math3d.index(camera_rc.worldmat, 3)
	-- 			calc_shadow_camera_from_corners(aabb_corners_WS, lightdir, setting.shadowmap_size, setting.stabilize, camera_rc)
	-- 		end
	-- end
end

function sm:render_submit()
	local viewid = viewidmgr.get "csm_fb"
	bgfx.touch(viewid)
end

function sm:camera_usage()
	-- local sa = imaterial.system_attribs()
	-- local mq = w:first("main_queue camera_ref:in")
	-- local camera <close> = w:entity(mq.camera_ref, "camera:in")
	-- sa:update("u_main_camera_matrix",camera.camera.viewmat)
end

local function which_material(skinning, stonemountain)
 	if stonemountain then
		return shadow_sm_material
	elseif skinning then
		return gpu_skinning_material
	else
		return shadow_material
	end 
	--return skinning and gpu_skinning_material or shadow_material
end

local omni_stencils = {
	[0] = bgfx.make_stencil{
		TEST="EQUAL",
		FUNC_REF = 0,
	},
	[1] = bgfx.make_stencil{
		TEST="EQUAL",
		FUNC_REF = 1,
	},
}

local material_cache = {__mode="k"}

function sm:update_filter()
    for e in w:select "filter_result render_layer:in render_object:update filter_material:in skinning?in stonemountain?in name?in" do
		if e.render_layer == "opacity" then
			local ro = e.render_object
			local m = which_material(e.skinning, e.stonemountain)
			local mo = m.object
			local fm = e.filter_material
			local newstate = irender.check_set_state(mo, fm.main_queue)
			local new_matobj = irender.create_material_from_template(mo, newstate, material_cache)
			
			local mi = new_matobj:instance()

			fm["csm1_queue"] = mi
			fm["csm2_queue"] = mi
			fm["csm3_queue"] = mi
			fm["csm4_queue"] = mi

			ro.mat_csm = mi:ptr()
		else
			w:extend(e, "csm1_queue_visible?out csm2_queue_visible?out csm3_queue_visible?out csm4_queue_visible?out")
			e.csm1_queue_visible = nil
			e.csm2_queue_visible = nil
			e.csm3_queue_visible = nil
			e.csm4_queue_visible = nil
			w:submit(e)
		end
	end
end


