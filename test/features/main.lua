package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    enable_mouse = true,
    import = {
        "@ant.test.features",
    },
    feature = {
        "ant.animation",
        "ant.daynight",
        "ant.motion_sampler",
        "ant.sky|sky",
        "ant.terrain|canvas",
        "ant.terrain|water",
    },
    system = {
        "ant.test.features|init_loader_system",
    },
    pipeline = {
        "init",
        "update",
        "exit",
    },
    policy = {},
}
