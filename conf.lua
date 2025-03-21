-- Configuration file for LÖVE2D
function love.conf(t)
    -- Game identity
    t.identity = "lisas_game"  -- Save directory name
    t.version = "11.4"               -- LÖVE version this game was made for
    t.console = false                -- Enable console output on Windows

    -- Window settings
    t.window.title = "Lisa's Game"
    t.window.icon = nil              -- Path to window icon (can be set later)
    t.window.width = 800
    t.window.height = 600
    t.window.minwidth = 400
    t.window.minheight = 300
    t.window.resizable = true
    t.window.fullscreen = false
    t.window.vsync = true
    t.window.msaa = 0               -- Multi-sample anti-aliasing level
    t.window.depth = nil            -- Depth bits (for 3D)
    t.window.stencil = nil          -- Stencil bits (for 3D)
    t.window.display = 1            -- Monitor to display on
    t.window.highdpi = false        -- Enable high-dpi mode (not needed for most 2D games)

    -- Modules enabled
    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = true
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false       -- We'll do our own physics
    t.modules.sound = true
    t.modules.system = true
    t.modules.thread = true
    t.modules.timer = true
    t.modules.touch = true
    t.modules.video = false         -- Not needed for this game
    t.modules.window = true
end