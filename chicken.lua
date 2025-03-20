-- Chicken NPC
local NPC = require("npc")

local Chicken = setmetatable({}, NPC)
Chicken.__index = Chicken

function Chicken:new(world, x, y)
    -- Create a new instance using NPC's constructor
    local self = NPC.new(self, world, x, y, 16, 14)  -- Width 16, height 14

    -- Load sprite sheet
    self.spriteSheet = love.graphics.newImage("assets/Rocky Roads/Enemies/chicken.png")

    -- Graphics offsets
    self.offsetX = 0
    self.offsetY = 0  -- Adjust position to align with feet

    -- Animation frames setup based on the CSS coordinates
    -- The CSS shows exact pixel locations for each frame
    self.animation.frames = {
        idle = {
            { -- idle1: x=7, y=16, width=17, height=16
                quad = love.graphics.newQuad(7, 16, 17, 16, self.spriteSheet:getDimensions()),
                offsetX = 0,
                offsetY = 0
            },
            { -- idle2: x=39, y=16, width=17, height=16
                quad = love.graphics.newQuad(39, 16, 17, 16, self.spriteSheet:getDimensions()),
                offsetX = 0,
                offsetY = 0
            }
        },
        walk = {
            { -- walk1: x=8, y=48, width=17, height=16
                quad = love.graphics.newQuad(8, 48, 17, 16, self.spriteSheet:getDimensions()),
                offsetX = 0,
                offsetY = 0
            },
            { -- walk2: x=40, y=48, width=18, height=16
                quad = love.graphics.newQuad(40, 48, 18, 16, self.spriteSheet:getDimensions()),
                offsetX = 0,
                offsetY = 0
            },
            { -- walk3: x=72, y=50, width=19, height=14
                quad = love.graphics.newQuad(72, 50, 19, 14, self.spriteSheet:getDimensions()),
                offsetX = 0,
                offsetY = 1  -- Small Y adjustment for height difference
            },
            { -- walk4: x=103, y=51, width=21, height=13
                quad = love.graphics.newQuad(103, 51, 21, 13, self.spriteSheet:getDimensions()),
                offsetX = 0,
                offsetY = 1.5  -- Y adjustment for height difference
            },
            { -- walk5: x=135, y=47, width=21, height=17
                quad = love.graphics.newQuad(135, 47, 21, 17, self.spriteSheet:getDimensions()),
                offsetX = 0,
                offsetY = -0.5  -- Y adjustment for height difference
            },
            { -- walk6: x=167, y=50, width=18, height=14
                quad = love.graphics.newQuad(167, 50, 18, 14, self.spriteSheet:getDimensions()),
                offsetX = 0,
                offsetY = 1  -- Y adjustment for height difference
            },
            { -- walk7: x=198, y=51, width=21, height=13
                quad = love.graphics.newQuad(198, 51, 21, 13, self.spriteSheet:getDimensions()),
                offsetX = 0,
                offsetY = 1.5  -- Y adjustment for height difference
            }
        }
    }

    -- Use actual frame dimensions instead of fixed values
    self.frameWidths = {
        idle = {17, 17},
        walk = {17, 18, 19, 21, 21, 18, 21}
    }
    self.frameHeights = {
        idle = {16, 16},
        walk = {16, 16, 14, 13, 17, 14, 13}
    }

    -- Override default behavior settings
    self.speed = 15 -- Chickens are slower
    self.thinkInterval = math.random(2, 5)  -- Chickens think less often
    self.moveInterval = math.random(2, 4)  -- Chickens move for longer periods
    self.idleInterval = math.random(1, 3)  -- Chickens pause occasionally

    -- Make chicken animation a bit faster
    self.animation.frameTime = 0.1

    return self
end

function Chicken:update(dt)
    -- Call the parent update method
    NPC.update(self, dt)

    -- Add any chicken-specific update logic here
    -- For example, chickens could have a small chance to jump randomly:
    if self.onGround and self.animation.state == "walk" and math.random() < 0.005 then
        self.vy = -100  -- Small hop
    end
end

function Chicken:draw()
    love.graphics.setColor(1, 1, 1, 1)

    -- Get current animation frame
    local frames = self.animation.frames[self.animation.state]
    if not frames or not frames[self.animation.frame] then
        -- If no valid frame exists, reset animation and use first frame
        self.animation.frame = 1
        self.animation.timer = 0

        -- Double check that we have valid frames now
        frames = self.animation.frames[self.animation.state]
        if not frames or not frames[1] then
            -- Fallback to a simple rectangle if we still don't have frames
            love.graphics.setColor(1, 0.5, 0.5, 1) -- Pinkish color for chicken
            love.graphics.rectangle("fill",
                self.x - self.width/2,
                self.y - self.height/2,
                self.width,
                self.height)
            love.graphics.setColor(1, 1, 1, 1)
            return
        end
    end

    -- Get the frame after validation
    local frame = frames[self.animation.frame]

    -- Get the current frame dimensions
    local frameWidth = self.frameWidths[self.animation.state][self.animation.frame]
    local frameHeight = self.frameHeights[self.animation.state][self.animation.frame]

    -- Draw the sprite with the correct orientation
    -- CORRECTION: The sprite sheet has the chicken facing LEFT as default
    -- So we need to flip when moving RIGHT
    local scaleX = 1
    if self.direction == "right" then
        scaleX = -1  -- Flip horizontally when facing right
    end

    love.graphics.draw(
        self.spriteSheet,
        frame.quad,
        math.floor(self.x),
        math.floor(self.y),
        0,  -- Rotation (none)
        scaleX, 1,  -- Scale
        frameWidth / 2 - self.offsetX,  -- Origin X (half width for center)
        frameHeight / 2 - self.offsetY  -- Origin Y (half height for center)
    )

    -- Uncomment for debugging collisions
    --[[
    love.graphics.setColor(1, 0, 0, 0.3)
    love.graphics.rectangle("fill",
        self.x - self.width/2,
        self.y - self.height/2,
        self.width,
        self.height)
    love.graphics.setColor(1, 1, 1, 1)
    --]]
end

return Chicken