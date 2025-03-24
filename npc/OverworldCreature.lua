-- OverworldCreature class for all creature types in the overworld
local NPC = require("npc.npc")

local OverworldCreature = setmetatable({}, NPC)
OverworldCreature.__index = OverworldCreature

function OverworldCreature:new(world, x, y, creatureType, level)
    -- Create a new instance using NPC's constructor
    local self = NPC.new(self, world, x, y, 16, 14)  -- Width 16, height 14

    -- Creature properties
    self.creatureType = creatureType or "chicken"  -- Default to chicken if no type provided
    self.level = level or math.random(1, 5)
    self.catchable = true  -- All creatures are catchable

    -- Load sprite sheet (fallback to chicken by default)
    self.defaultSpriteSheet = "assets/Overworld/chicken.png"
    self.spriteSheet = love.graphics.newImage(self.defaultSpriteSheet)

    -- Graphics offsets
    self.offsetX = 0
    self.offsetY = 0  -- Adjust position to align with feet

    -- Collision state
    self.collisionCooldown = 0  -- Prevent multiple battle initiations in a row

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
            },
            { -- idle3: x=71, y=16, width=17, height=16
                quad = love.graphics.newQuad(71, 16, 17, 16, self.spriteSheet:getDimensions()),
                offsetX = 0,
                offsetY = 0
            },
            { -- idle4: x=103, y=16, width=17, height=16
                quad = love.graphics.newQuad(103, 16, 17, 16, self.spriteSheet:getDimensions()),
                offsetX = 0,
                offsetY = 0
            }
        },
        walk = {
            { -- walk1: x=7, y=48, width=17, height=16
                quad = love.graphics.newQuad(7, 48, 17, 16, self.spriteSheet:getDimensions()),
                offsetX = 0,
                offsetY = 0
            },
            { -- walk2: x=39, y=48, width=17, height=16
                quad = love.graphics.newQuad(39, 48, 17, 16, self.spriteSheet:getDimensions()),
                offsetX = 0,
                offsetY = 0
            },
            { -- walk3: x=71, y=48, width=17, height=16
                quad = love.graphics.newQuad(71, 48, 17, 16, self.spriteSheet:getDimensions()),
                offsetX = 0,
                offsetY = 0
            },
            { -- walk4: x=103, y=48, width=17, height=16
                quad = love.graphics.newQuad(103, 48, 17, 16, self.spriteSheet:getDimensions()),
                offsetX = 0,
                offsetY = 0
            }
        }
    }

    -- Apply custom appearance based on creature type
    self:applyCreatureAppearance()

    -- Random starting animation frame
    self.animation.frame = math.random(1, #self.animation.frames.idle)

    return self
end

-- Apply creature-specific appearance
function OverworldCreature:applyCreatureAppearance()
    -- If we don't have a creature registry in the world, use default chicken
    if not self.world.creatureRegistry then
        return
    end

    -- Get creature info from registry
    local creatureInfo = self.world.creatureRegistry:getCreatureTypeInfo(self.creatureType)
    if not creatureInfo then
        return
    end

    -- Check if creature has custom sprite sheet
    if creatureInfo.spriteInfo and creatureInfo.spriteInfo.sheet then
        -- Try to load custom sprite sheet
        local success, newSheet = pcall(love.graphics.newImage, creatureInfo.spriteInfo.sheet)

        if success then
            self.spriteSheet = newSheet

            -- If creature has custom animations, we could replace the chicken animations here
            -- For now, we'll stick with the chicken animations for all creatures
            -- This could be expanded in the future
        end
    end

    -- You could adjust size, speed, or other properties based on creature type
    -- For example:
    if creatureInfo.baseStats then
        -- Adjust speed based on creature's speed stat
        self.speed = 15 + (creatureInfo.baseStats.speed * 2)
    end
end

-- Update the creature
function OverworldCreature:update(dt)
    -- Normal NPC update
    NPC.update(self, dt)

    -- Update timers
    if self.collisionCooldown > 0 then
        self.collisionCooldown = self.collisionCooldown - dt
    end
end

-- Handle collision with player
function OverworldCreature:onPlayerCollision(player, dx, dy)
    -- Only respond to collision if not in cooldown
    if self.collisionCooldown <= 0 then
        -- Set collision cooldown to prevent multiple battle triggers
        self.collisionCooldown = 0.5

        -- Return true to indicate collision was handled
        -- This allows the game to start a battle based on this collision
        return true
    end

    -- Return false if cooldown active
    return false
end

-- Draw the creature
function OverworldCreature:draw()
    -- Draw shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", self.x, self.y + self.height / 2 - 2, self.width / 2, self.height / 4)

    -- Reset color for sprite
    love.graphics.setColor(1, 1, 1, 1)

    -- Get the current animation frames
    local frames = self.animation.frames[self.animation.state]
    if not frames then
        frames = self.animation.frames.idle  -- Default to idle if current state has no frames
    end

    -- Get current frame (with bounds check)
    local frameIndex = math.min(self.animation.frame, #frames)
    local frame = frames[frameIndex]

    -- Flip sprite based on direction
    local scaleX = 1
    if self.direction == "left" then
        scaleX = -1
    end

    -- Draw the sprite
    love.graphics.draw(
        self.spriteSheet,
        frame.quad,
        self.x + (frame.offsetX * scaleX),
        self.y + frame.offsetY,
        0,  -- rotation
        scaleX,
        1   -- scaleY
    )

    -- Draw level indicator for catchable creatures
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Lv" .. self.level, self.x - 8, self.y - self.height/2 - 15)

    -- Debug visualization (if enabled)
    if self.world.game and self.world.game.showDebugOverlay then
        -- Draw collision box
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.rectangle("line",
            self.x - self.width / 2,
            self.y - self.height / 2,
            self.width,
            self.height
        )

        -- Draw creature type and level
        love.graphics.setColor(1, 1, 0, 0.7)
        love.graphics.print(self.creatureType .. " Lv" .. self.level, self.x - 20, self.y - self.height/2 - 15)
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Create a creature instance for battle
function OverworldCreature:createCreatureInstance()
    if not self.world.creatureRegistry then
        return nil, "No creature registry found in world."
    end

    -- Create a creature instance with the same type and level as this NPC
    return self.world.creatureRegistry:createCreature(self.creatureType, self.level)
end

return OverworldCreature