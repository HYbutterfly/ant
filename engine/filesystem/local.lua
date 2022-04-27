local fs = require "bee.filesystem"
local platform = require 'platform'

function fs.open(filepath, ...)
    return io.open(filepath:string(), ...)
end
function fs.lines(filepath, ...)
    return io.lines(filepath:string(), ...)
end
function fs.loadfile(filepath, ...)
    return loadfile(filepath:string(), ...)
end
function fs.dofile(filepath)
    return dofile(filepath:string())
end
local path_mt = debug.getmetatable(fs.path())
if not path_mt.localpath then
    function path_mt:localpath()
        return self
    end
end

return fs
