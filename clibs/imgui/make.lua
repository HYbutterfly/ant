local lm = require "luamake"

dofile "../common.lua"

local defines = {
    lm.os ~= "macos" and "IMGUI_DISABLE_OBSOLETE_FUNCTIONS",
    lm.os ~= "macos" and "IMGUI_DISABLE_OBSOLETE_KEYIO",
    "IMGUI_DISABLE_DEBUG_TOOLS",
    "IMGUI_DISABLE_DEMO_WINDOWS",
    "IMGUI_DISABLE_DEFAULT_ALLOCATORS",
    "IMGUI_USER_CONFIG=\\\"imgui_lua_config.h\\\"",
    lm.os == "windows" and "IMGUI_ENABLE_WIN32_DEFAULT_IME_FUNCTIONS"
}

lm:source_set "imgui" {
    includes = {
        ".",
        lm.AntDir .. "/3rd/imgui",
    },
    defines = defines,
    sources = {
        "backend/imgui_impl_platform.cpp",
    },
    windows = {
        sources = {
            lm.AntDir .. "/3rd/imgui/backends/imgui_impl_win32.cpp",
        },
        defines = {
            "_UNICODE",
            "UNICODE",
        },
        links = {
            "user32",
            "shell32",
            "ole32",
            "imm32",
            "dwmapi",
            "gdi32",
            "uuid"
        },
    },
    macos = {
        sources = {
            "backend/imgui_impl_platform.mm",
            lm.AntDir .. "/3rd/imgui/backends/imgui_impl_osx.mm",
        },
        flags = {
            "-fobjc-arc"
        },
        frameworks = {
            "GameController"
        }
    },
    ios = {
        sources = {
            "backend/imgui_impl_platform.mm",
        },
    },
}

lm:source_set "imgui" {
    includes = {
        ".",
        lm.AntDir .. "/3rd/imgui",
    },
    sources = {
        lm.AntDir .. "/3rd/imgui/imgui_draw.cpp",
        lm.AntDir .. "/3rd/imgui/imgui_tables.cpp",
        lm.AntDir .. "/3rd/imgui/imgui_widgets.cpp",
        lm.AntDir .. "/3rd/imgui/imgui.cpp",
    },
    defines = defines,
}

lm:lua_source "imgui" {
    includes = {
        ".",
        lm.AntDir .. "/3rd/imgui",
        lm.AntDir .. "/3rd/glm",
        BgfxInclude,
        "../bgfx",
    },
    sources = {
        "backend/imgui_impl_bgfx.cpp",
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
        defines,
    },
}

lm:lua_source "imgui" {
    deps = "luabind",
    includes = {
        ".",
        lm.AntDir .. "/3rd/imgui",
        lm.AntDir .. "/3rd/bee.lua",
        BgfxInclude,
        "../luabind"
    },
    sources = {
        "imgui_lua_config.cpp",
        "imgui_lua_funcs.cpp",
        "imgui_lua_util.cpp",
        "imgui_lua_backend.cpp",
        "imgui_lua_legacy.cpp",
    },
    defines = {
        defines,
    },
}

lm:runlua "imgui-gen" {
    script = "gen.lua",
    args = { lm.AntDir }
}
