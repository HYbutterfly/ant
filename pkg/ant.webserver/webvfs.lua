local function copy_fs(fsname)
	local fs = {}
	local localfs = require(fsname)
	for k,v in pairs(localfs) do
		fs[k] = v
	end
	return fs
end

local FS = {
	vfs = copy_fs "filesystem",
	localfs = copy_fs "bee.filesystem",
} ; do
	FS.vfs.localpath = function (path)
		return path:localpath()
	end
	FS.localfs.localpath = function (path)
		return path
	end
end

local M = {}

local html_header = [[
<html>
<head><meta charset="utf-8"></head>
<body>
<ul>
]]
local html_footer = [[
</ul>
</body>
]]

local plaintext = "text/plain;charset=utf-8"

local content_text_types = {
    [".settings"] = plaintext,
    -- ecs
    [".prefab"] = plaintext,
    [".ecs"] = plaintext,
    -- script
    [".lua"] = plaintext,
    -- ui
    [".rcss"] = plaintext,
    [".rml"] = plaintext,
    -- animation
    [".event"] = plaintext,
    [".anim"] = plaintext,
    -- compiled resource
    [".cfg"] = plaintext,
    [".attr"] = plaintext,
    [".state"] = plaintext,
	-- shader
	[".sc"] = plaintext,
	[".sh"] = plaintext,
	-- local file
	[".log"] = plaintext,
	[".json"] = plaintext,
	-- for html
	[".html"] = "text/html",
	[".js"] = "text/html",
	[".gif"] = "image/gif",
	[".jpg"] = "image/jpeg",
	[".png"] = "image/png",
}

local function gen_get(fs)
	local function get_file(path)
		local ext = path:extension():string():lower()
		local localpath = fs.localpath(path):string()
		local header = {
			["Content-Type"] = content_text_types[ext] or "application/octet-stream"
		}
		-- todo: use func for large file
		local f = assert(io.open(localpath, "rb"))
		local function reader()
			local bytes = f:read(4096)
			if bytes then
				return bytes
			else
				f:close()
			end
		end
		return reader, header
	end

	local function get_dir(path, url, name)
		local filelist = {}
		for file, file_status in fs.pairs(path) do
			local t = file_status:is_directory() and "d" or "f"
			table.insert(filelist, t .. file:filename():string())
		end
		table.sort(filelist)
		local list = { html_header }
		for _, filename in ipairs(filelist) do
			local t , filename = filename:sub(1,1), filename:sub(2)
			local slash = t == "d" and "/" or ""
			table.insert(list, ('<li><a href="%s%s%s">%s%s</a></li>'):format(url, name, filename, filename, slash))
		end
		table.insert(list, html_footer)
		return table.concat(list, "\n")
	end

	local function get_path(path, url, name)
		if not fs.exists(path) then
			return
		end
		if fs.is_directory(path) then
			local index = path / "index.html"
			if fs.exists(index) then
				return get_file(index)
			else
				if name ~= "" then
					name = name .. "/"
				end
				return get_dir(path, url, name)
			end
		else
			return get_file(path)
		end
	end

	return get_path
end

local get_path = {}; do
	for k,v in pairs(FS) do
		get_path[k] = gen_get(v)
	end
end

local function get_directory(what)
	local directory = require "directory"
	if what == "log" then
		return directory.log_path():string()
	elseif what == "app" then
		return directory.app_path("ant"):string()
	end
end

-- path : abc
-- url_path : /vfs
-- vfs_path : web
-- url : vfs/abc
-- vfs : web/abc
function M.get(fsname, path, url_path, vfs_path)
	local fullpath = path == "" and vfs_path or (vfs_path .. path)
	local fs = FS[fsname]
	if not fs then
		fullpath = assert(get_directory(fsname)) .. fullpath
		fsname = "localfs"
		fs = FS.localfs
		print("GET", fullpath)
	end
	local pathname = FS[fsname].path(fullpath)
	local data, header = get_path[fsname](pathname, url_path, path)
	if data then
		return 200, data, header
	else
		return 403, "ERROR 403 : " ..  path .. " not found"
	end
end

return M