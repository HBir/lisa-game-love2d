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


function OverworldCreature:new(world, x, y, creatureType, level)
    -- Create a new instance using NPC's constructor
    local self = NPC.new(self, world, x, y, 16, 14)  -- Width 16, height 14

    -- Creature properties
    self.creatureType = creatureType
    -- self.creatureTypeId = creatureTypeId or "chicken"  -- Default to chicken if no type provided
    self.level = level or math.random(1, 5)
    self.catchable = true  -- All creatures are catchable by default

    -- Player ownership flags
    self.isPlayerOwned = false -- Flag to indicate if this creature belongs to the player
    self.followPlayer = false  -- Flag to indicate if this creature should follow the player
    self.followDistance = 40   -- Distance to maintain behind player
    self.followIndex = 1       -- Position in follow chain (for multiple followers)

    -- Graphics offsets
    self.offsetX = 0
    self.offsetY = 0  -- Adjust position to align with feet

    -- Collision state
    self.collisionCooldown = 0  -- Prevent multiple battle initiations in a row

    -- Initialize with default chicken animation frames

    self.animation.idle = {
        sheet = nil,
        frames = {},
        frameTime = 0.2
    }

    self.animation.walk = {
        sheet = nil,
        frames = {},
        frameTime = 0.2
    }

    -- Apply creature-specific appearance based on the creature registry
    self:applyCreatureAppearance()

    -- Random starting animation frame
    -- self.animation.frame = math.random(1, #self.animation.frames.idle)

    return self
end

-- Apply creature-specific appearance
function OverworldCreature:applyCreatureAppearance()
    -- If we don't have a creature registry in the world, use default chicken
    -- if not self.world.creatureRegistry then
    --     print("Warning: No creature registry found in world, using default chicken appearance")
    --     return
    -- end

    -- -- Get creature info from registry
    -- local creatureInfo = self.world.creatureRegistry:getCreatureTypeInfo(self.creatureTypeId)
    -- if not creatureInfo then
    --     print("Warning: Creature type '" .. self.creatureTypeId .. "' not found in registry, using default")
    --     return
    -- end

    -- Check if creature has custom sprite sheet
    -- if creatureInfo.spriteInfo and creatureInfo.spriteInfo.sheet then
    --     -- Try to load custom sprite sheet
    --     local success, newSheet = pcall(love.graphics.newImage, creatureInfo.spriteInfo.sheet)

    --     if success then
    --         self.spriteSheet = newSheet
    --     else
    --         print("Warning: Failed to load sprite sheet for " .. self.creatureTypeId .. ", using default")
    --     end
    -- end

    local creatureInfo = self.creatureType
    -- If no creatureInfo.spriteInfo, return
    if not creatureInfo.spriteInfo then
        return
    end

    local animations = creatureInfo.spriteInfo.animations
    -- Try to load animations from creature info
    if animations then
        -- If there's an idle animation
        if animations.idle then
            local sheet = love.graphics.newImage(animations.idle.sheet)
            self.animation.idle.sheet = sheet
            local idleFrames = createOverWorldQuads(animations.idle, sheet)
            if idleFrames then
                self.animation.idle.frames = idleFrames

                -- Set frame time if specified in animation data
                if animations.idle.frameTime then
                    self.animation.idle.frameTime = animations.idle.frameTime
                end
            end
        end

        -- If there's a walk animation
        if animations.walk then
            local sheet = love.graphics.newImage(animations.walk.sheet)
            self.animation.walk.sheet = sheet
            local walkFrames = createOverWorldQuads(animations.walk, sheet)
            if walkFrames then
                self.animation.walk.frames = walkFrames
            else
                -- If no walk animation, use idle frames for walking too
                self.animation.walk.frames = self.animation.frames.idle
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
    -- If this creature is owned by the player, it shouldn't be catchable
    if self.isPlayerOwned then
        self.catchable = false
    end

    -- Check if we should follow the player
    if self.followPlayer and self.world.player then
        self:updateFollowBehavior(dt)
    else
        -- Normal NPC update for wild creatures
        NPC.update(self, dt)
    end

    -- Update timers
    if self.collisionCooldown > 0 then
        self.collisionCooldown = self.collisionCooldown - dt
    end
end

-- New method for following the player
function OverworldCreature:updateFollowBehavior(dt)
    local player = self.world.player
    if not player then return end

    -- Calculate target position behind player based on follow index
    local targetX = player.x
    local targetY = player.y

    -- Position is based on which direction player is facing
    local offsetX = 0
    local offsetY = 0

    -- Calculate base offset distance based on follow index
    local distance = self.followDistance * self.followIndex

    -- Adjust target position based on player direction
    if player.direction == "left" then
        offsetX = distance
    elseif player.direction == "right" then
        offsetX = -distance
    end

    targetX = player.x + offsetX
    targetY = player.y + offsetY

    -- Calculate distance to target
    local dx = targetX - self.x
    local dy = targetY - self.y
    local distanceToTarget = math.sqrt(dx*dx + dy*dy)

    -- Only move if far enough away
    if distanceToTarget > self.followDistance * 0.7 then
        -- Set animation state to walking
        self.animation.state = "walk"

        -- Normalize direction vector
        local length = math.sqrt(dx*dx + dy*dy)
        if length > 0 then
            dx = dx / length
            dy = dy / length
        end

        -- Set velocity based on distance (faster when further away)
        local speedFactor = math.min(2.0, distanceToTarget / self.followDistance)
        self.vx = dx * self.speed * speedFactor
        self.vy = dy * 0.5 * self.speed -- Less vertical movement

        -- Set creature direction
        if dx > 0 then
            self.direction = "right"
        elseif dx < 0 then
            self.direction = "left"
        end
    else
        -- Close enough, stop moving
        self.vx = 0
        self.vy = 0
        self.animation.state = "idle"
    end

    -- Apply gravity and handle collisions
    self.vy = self.vy + self.gravity * dt

    -- Calculate new position
    local newX = self.x + self.vx * dt
    local newY = self.y + self.vy * dt

    -- Reset ground state
    self.onGround = false

    -- Handle collisions and update position
    self:handleCollisions(newX, newY)

    -- Update animation
    self:updateAnimation(dt)
end

-- Handle collision with player
function OverworldCreature:onPlayerCollision(player, dx, dy)
    -- If this is a player's creature, don't trigger battle
    if self.isPlayerOwned then
        return false
    end

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
    local sheet = self.animation[self.animation.state].sheet
    local frames = self.animation[self.animation.state].frames
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
        sheet,
        frame.quad,
        self.x + (frame.offsetX or 0),
        self.y + (frame.offsetY or 0),
        0,  -- rotation
        scaleX * 0.5,
        0.5   -- scaleY
    )

    -- Draw level indicator for catchable creatures
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self.creatureType.name .. " Lv" .. self.level, self.x - 20, self.y - self.height/2 - 15)

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
    print("Creating creature instance: " .. self.creatureTypeId .. " level " .. self.level)
    return self.world.creatureRegistry:createCreature(self.creatureTypeId, self.level)
end

return OverworldCreature