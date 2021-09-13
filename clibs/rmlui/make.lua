local lm = require "luamake"

dofile "../common.lua"

lm:import "../font/make.lua"
lm:import "../luabind/build.lua"

lm:source_set "yoga" {
    rootdir = Ant3rd .. "yoga",
    includes = {
        ".",
    },
    sources = {
        "yoga/**.cpp",
    }
}

lm:source_set "rmlui_core" {
    rootdir = Ant3rd .. "rmlui",
    includes = {
        "Include",
        Ant3rd .. "glm",
        Ant3rd .. "yoga",
    },
    defines = "GLM_FORCE_QUAT_DATA_XYZW",
    sources = {
        "Source/*.cpp",
    }
}

lm:source_set "source_rmlui" {
    deps = {
        "yoga",
        "rmlui_core",
        "luabind",
    },
    includes = {
        LuaInclude,
        Ant3rd .. "bgfx/include",
        Ant3rd .. "bx/include",
        Ant3rd .. "glm",
        Ant3rd .. "rmlui/Include",
        Ant3rd .. "bgfx/3rdparty",
        Ant3rd .. "yoga",
        "../luabind",
    },
    sources = {
        "*.cpp",
    },
    windows = {
        links = "user32"
    }
}

lm:lua_dll "rmlui" {
    deps = {
        "source_rmlui",
    }
}
