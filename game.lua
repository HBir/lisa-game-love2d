-- Game class that manages the overall game state
local Camera = require("camera")
local World = require("world")
local Player = require("player")

local Game = {}
Game.__index = Game

function Game:new()
    local self = setmetatable({}, Game)

    -- Game settings
    self.title = "Princess Builder"
    self.width = 800
    self.height = 600

    return self
end

function Game:load()
    -- Set window properties
    love.window.setTitle(self.title)
    love.window.setMode(self.width, self.height, {
        resizable = true,
        vsync = true,
        minwidth = 400,
        minheight = 300
    })

    -- Initialize the world
    self.world = World:new(128, 128, 16) -- width, height, tile size
    self.world:generate()

    -- Initialize the player
    self.player = Player:new(self.world, self.width / 2, self.height / 2)

    -- Initialize the camera
    self.camera = Camera:new(self.width, self.height, self.world.tileSize)
    self.camera:follow(self.player)

    -- Game state
    self.paused = false
end

function Game:update(dt)
    if self.paused then
        return
    end

    -- Update the player
    self.player:update(dt)

    -- Update the camera to follow the player
    self.camera:update(dt)
end

function Game:draw()
    -- Begin camera transformation
    self.camera:set()

    -- Draw the world
    self.world:draw(self.camera)

    -- Draw the player
    self.player:draw()

    -- End camera transformation
    self.camera:unset()

    -- Draw the UI on top (fixed position, not affected by camera)
    self:drawUI()
end

function Game:drawUI()
    -- Draw the UI elements here
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Princess Builder - FPS: " .. love.timer.getFPS(), 10, 10)

    -- Draw inventory selection
    -- ...
end

function Game:keypressed(key)
    if key == "escape" then
        self.paused = not self.paused
    end

    if not self.paused then
        self.player:keypressed(key)
    end
end

function Game:keyreleased(key)
    if not self.paused then
        self.player:keyreleased(key)
    end
end

function Game:mousepressed(x, y, button)
    if not self.paused then
        -- Convert screen coordinates to world coordinates
        local worldX, worldY = self.camera:screenToWorld(x, y)

        -- Handle block placement/removal
        if button == 1 then -- Left click
            self.world:removeBlock(worldX, worldY)
        elseif button == 2 then -- Right click
            self.world:placeBlock(worldX, worldY, self.player.selectedBlockType)
        end
    end
end

function Game:mousereleased(x, y, button)
    -- Handle mouse release events
end

function Game:wheelmoved(x, y)
    -- Change selected block type
    if y > 0 then
        self.player:nextBlockType()
    elseif y < 0 then
        self.player:prevBlockType()
    end
end

return Game