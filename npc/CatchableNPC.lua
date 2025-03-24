-- CatchableNPC class for NPCs that can be caught as creatures
local NPC = require("npc.npc")

local CatchableNPC = setmetatable({}, NPC)
CatchableNPC.__index = CatchableNPC

function CatchableNPC:new(world, x, y, creatureType, level)
    -- Create a new instance using NPC's constructor
    local self = NPC.new(self, world, x, y, 16, 16)  -- Default width and height

    -- Properties specific to catchable NPCs
    self.creatureType = creatureType  -- Type of creature this NPC represents
    self.level = level or math.random(1, 5)  -- Level of the creature
    self.catchable = true  -- Flag indicating this NPC can be caught

    -- Customize appearance based on creature type
    self:applyCreatureAppearance()

    return self
end

-- Override update method to add custom behavior
function CatchableNPC:update(dt)
    -- Call the parent update method
    NPC.update(self, dt)

    -- Add additional catchable NPC-specific behavior here
end

-- Apply appearance based on creature type (load sprites, animations, etc.)
function CatchableNPC:applyCreatureAppearance()
    if not self.world.creatureRegistry then
        print("Warning: No creature registry found in world.")
        return
    end

    -- Get creature type info from registry
    local creatureInfo = self.world.creatureRegistry:getCreatureTypeInfo(self.creatureType)
    if not creatureInfo then
        print("Warning: Creature type not found in registry: " .. self.creatureType)
        return
    end

    -- Load sprite sheet
    if creatureInfo.spriteInfo and creatureInfo.spriteInfo.sheet then
        self.spriteSheet = love.graphics.newImage(creatureInfo.spriteInfo.sheet)

        -- Set up animations
        if creatureInfo.spriteInfo.animations then
            -- Adapt creature animations to NPC animation format
            self.animation.frames = {
                idle = {},
                walk = {}
            }

            -- Convert creature idle animation to NPC idle animation
            if creatureInfo.spriteInfo.animations.idle and creatureInfo.spriteInfo.animations.idle.frames then
                for _, frame in ipairs(creatureInfo.spriteInfo.animations.idle.frames) do
                    table.insert(self.animation.frames.idle, {
                        x = frame.x,
                        y = frame.y,
                        width = frame.width,
                        height = frame.height
                    })
                end
            end

            -- Use attack animation as walk animation if available, otherwise use idle
            local walkFrames = creatureInfo.spriteInfo.animations.attack and
                               creatureInfo.spriteInfo.animations.attack.frames or
                               creatureInfo.spriteInfo.animations.idle.frames

            for _, frame in ipairs(walkFrames) do
                table.insert(self.animation.frames.walk, {
                    x = frame.x,
                    y = frame.y,
                    width = frame.width,
                    height = frame.height
                })
            end

            -- Set animation frame time
            if creatureInfo.spriteInfo.animations.idle.frameTime then
                self.animation.frameTime = creatureInfo.spriteInfo.animations.idle.frameTime
            end
        end
    end

    -- Adjust size based on creature (optional)
    -- self.width = creatureInfo.size and creatureInfo.size.width or 16
    -- self.height = creatureInfo.size and creatureInfo.size.height or 16
end

-- Override draw method to implement custom drawing
function CatchableNPC:draw()
    -- Draw the sprite
    love.graphics.setColor(1, 1, 1, 1)

    -- If we have a sprite sheet, draw from it
    if self.spriteSheet then
        -- Get current animation frames
        local frames = self.animation.frames[self.animation.state]
        if frames and #frames > 0 then
            -- Calculate current frame index (clamped to available frames)
            local frameIndex = math.min(self.animation.frame, #frames)
            local frame = frames[frameIndex]

            -- Create quad for current frame
            local quad = love.graphics.newQuad(
                frame.x, frame.y,
                frame.width, frame.height,
                self.spriteSheet:getDimensions()
            )

            -- Draw the sprite with correct orientation
            local scaleX = 1
            if self.direction == "left" then
                scaleX = -1
            end

            love.graphics.draw(
                self.spriteSheet,
                quad,
                self.x,
                self.y,
                0,  -- rotation
                scaleX,
                1,  -- scaleY
                frame.width / 2,  -- originX (center horizontally)
                frame.height / 2   -- originY (center vertically)
            )
        end
    else
        -- Default drawing if no sprite sheet
        love.graphics.setColor(0.8, 0.4, 0.8, 1)  -- Purple for catchable NPCs
        love.graphics.rectangle("fill",
            self.x - self.width/2,
            self.y - self.height/2,
            self.width,
            self.height)

        -- Draw level indicator
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Lv" .. self.level, self.x - 8, self.y - self.height/2 - 15)
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)

    -- Draw debug info if enabled
    if self.world.game and self.world.game.showDebugOverlay then
        love.graphics.setColor(1, 1, 0, 0.7)
        love.graphics.print(self.creatureType .. " Lv" .. self.level, self.x - 20, self.y - self.height/2 - 15)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Create a creature instance from this NPC
function CatchableNPC:createCreatureInstance()
    if not self.world.creatureRegistry then
        return nil, "No creature registry found in world."
    end

    -- Create a creature instance with the same type and level as this NPC
    return self.world.creatureRegistry:createCreature(self.creatureType, self.level)
end

return CatchableNPC