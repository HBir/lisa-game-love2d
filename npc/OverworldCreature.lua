-- OverworldCreature class for all creature types in the overworld
local NPC = require("npc.npc")

local OverworldCreature = setmetatable({}, NPC)
OverworldCreature.__index = OverworldCreature

-- Helper function to create animation frames from a frames specification
function createOverWorldQuads(framesSpecArray, spriteSheet)
  if not framesSpecArray or not framesSpecArray.frames then
    return nil
  end

  -- Create a table to hold frame data
  local frames = {}
  for i, frameSpec in ipairs(framesSpecArray.frames) do
    frames[i] = {
      quad = love.graphics.newQuad(
        frameSpec.x, frameSpec.y,
        frameSpec.width, frameSpec.height,
        spriteSheet:getDimensions()
      ),
      offsetX = frameSpec.offsetX or 0,
      offsetY = frameSpec.offsetY or 0
    }
  end
  return frames
end


function OverworldCreature:new(world, x, y, creatureTypeId, level)
    -- Create a new instance using NPC's constructor
    local self = NPC.new(self, world, x, y, 16, 14)  -- Width 16, height 14

    -- Creature properties
    self.creatureTypeId = creatureTypeId or "chicken"  -- Default to chicken if no type provided
    self.level = level or math.random(1, 5)
    self.catchable = true  -- All creatures are catchable

    -- Load default sprite sheet (fallback)
    -- self.defaultSpriteSheet = "assets/Overworld/chicken.png"
    -- self.spriteSheet = love.graphics.newImage(self.defaultSpriteSheet)

    -- Graphics offsets
    self.offsetX = 0
    self.offsetY = 0  -- Adjust position to align with feet

    -- Collision state
    self.collisionCooldown = 0  -- Prevent multiple battle initiations in a row

    -- Initialize with default chicken animation frames
    self.animation.frames = {
        idle = {},
        walk = {}
    }

    -- Apply creature-specific appearance based on the creature registry
    self:applyCreatureAppearance()

    -- Random starting animation frame
    self.animation.frame = math.random(1, #self.animation.frames.idle)

    return self
end

-- Apply creature-specific appearance
function OverworldCreature:applyCreatureAppearance()
    -- If we don't have a creature registry in the world, use default chicken
    if not self.world.creatureRegistry then
        print("Warning: No creature registry found in world, using default chicken appearance")
        return
    end

    -- Get creature info from registry
    local creatureInfo = self.world.creatureRegistry:getCreatureTypeInfo(self.creatureTypeId)
    if not creatureInfo then
        print("Warning: Creature type '" .. self.creatureTypeId .. "' not found in registry, using default")
        return
    end

    -- Check if creature has custom sprite sheet
    if creatureInfo.spriteInfo and creatureInfo.spriteInfo.sheet then
        -- Try to load custom sprite sheet
        local success, newSheet = pcall(love.graphics.newImage, creatureInfo.spriteInfo.sheet)

        if success then
            self.spriteSheet = newSheet
        else
            print("Warning: Failed to load sprite sheet for " .. self.creatureTypeId .. ", using default")
        end
    end

    -- Try to load animations from creature info
    if creatureInfo.animations then
        -- If there's an idle animation
        if creatureInfo.animations.idle then
            local idleFrames = createOverWorldQuads(creatureInfo.animations.idle, self.spriteSheet)
            if idleFrames then
                self.animation.frames.idle = idleFrames

                -- Set frame time if specified in animation data
                if creatureInfo.animations.idle.frameTime then
                    self.animation.frameTime = creatureInfo.animations.idle.frameTime
                end
            end
        end

        -- If there's a walk animation
        if creatureInfo.animations.walk then
            local walkFrames = createOverWorldQuads(creatureInfo.animations.walk, self.spriteSheet)
            if walkFrames then
                self.animation.frames.walk = walkFrames
            else
                -- If no walk animation, use idle frames for walking too
                self.animation.frames.walk = self.animation.frames.idle
            end
        else
            -- If no walk animation defined, use idle for walking too
            self.animation.frames.walk = self.animation.frames.idle
        end
    end

    -- Adjust properties based on creature type
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

    -- Safety check for frames
    if not frames or #frames == 0 then
        -- Just draw a colored rectangle as fallback
        love.graphics.setColor(1, 0.5, 0.5, 1)
        love.graphics.rectangle("fill", self.x - self.width/2, self.y - self.height/2, self.width, self.height)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- Get current frame (with bounds check)
    local frameIndex = math.min(self.animation.frame, #frames)
    local frame = frames[frameIndex]

    -- Flip sprite based on direction
    -- Since sprites are facing WEST by default (left), we flip for RIGHT direction
    local scaleX = 1
    if self.direction == "right" then  -- Changed from "left" to "right"
        scaleX = -1
    end

    -- Draw the sprite
    love.graphics.draw(
        self.spriteSheet,
        frame.quad,
        self.x + (frame.offsetX or 0) * scaleX,
        self.y + (frame.offsetY or 0),
        0,  -- rotation
        scaleX,
        1   -- scaleY
    )

    -- Draw level indicator for catchable creatures
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self.creatureTypeId .. " Lv" .. self.level, self.x - 20, self.y - self.height/2 - 15)

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
    return self.world.creatureRegistry:createCreature(self.creatureTypeId, self.level)
end

return OverworldCreature