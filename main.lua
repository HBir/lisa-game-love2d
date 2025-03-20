-- Main entry point for our Terraria-like game
local Game = require("game")

-- Game instance
local game = nil

-- LÖVE callbacks
function love.load()
    -- Initialize the game
    game = Game:new()
    game:load()
end

function love.update(dt)
    -- Update the game state
    game:update(dt)
end

function love.draw()
    -- Render the game
    game:draw()
end

function love.keypressed(key)
    -- Handle key press events
    game:keypressed(key)
end

function love.keyreleased(key)
    -- Handle key release events
    game:keyreleased(key)
end

function love.mousepressed(x, y, button)
    -- Handle mouse press events
    game:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    -- Handle mouse release events
    game:mousereleased(x, y, button)
end

function love.wheelmoved(x, y)
    -- Handle mouse wheel events
    game:wheelmoved(x, y)
end