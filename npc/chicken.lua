-- Chicken NPC
local NPC = require("npc.npc")

local Chicken = setmetatable({}, NPC)
Chicken.__index = Chicken

function Chicken:new(world, x, y)
    -- Create a new instance using NPC's constructor
    local self = NPC.new(self, world, x, y, 16, 14)  -- Width 16, height 14

    -- Load sprite sheet
    self.spriteSheet = love.graphics.newImage("assets/Overworld/chicken.png")

    -- Graphics offsets
    self.offsetX = 0
    self.offsetY = 0  -- Adjust position to align with feet

    -- Collision and physics properties
    self.isPushed = false
    self.pushRecoveryTimer = 0
    self.panicTimer = 0
    self.collisionCooldown = 0  -- Prevent multiple collisions in a row
    self.pushResistance = 0.2   -- Lower values make chickens get pushed further
    self.recoveryRate = 0.85    -- Slower recovery means longer sliding after being pushed

    -- Physics properties for push behavior
    self.maxPushVelocity = 200  -- Maximum velocity from push
    self.minAirborneTime = 0.1  -- Minimum time chicken stays airborne after push
    self.airborneTimer = 0      -- Timer to track forced airborne state
    self.isPushAirborne = false -- Flag for when chicken is airborne due to push
    self.gravity = 800          -- Gravity value for physics

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
    -- Check for collision with player before updating position
    self:checkPlayerCollision()

    -- Update airborne timer if active
    if self.isPushAirborne then
        self.airborneTimer = self.airborneTimer - dt
        if self.airborneTimer <= 0 then
            self.isPushAirborne = false
        else
            -- While push-airborne, don't apply gravity as quickly
            self.vy = self.vy + (self.gravity * 0.7 * dt)

            -- Calculate new position while in push-airborne state
            local newX = self.x + self.vx * dt
            local newY = self.y + self.vy * dt

            -- Handle collisions and position updates, but skip AI logic
            self:handleCollisions(newX, newY)

            -- Still update animation while airborne
            self:updateAnimation(dt)

            -- Return early to skip the regular NPC update
            return
        end
    end

    -- Call the parent update method when not in special airborne state
    NPC.update(self, dt)

    -- Add any chicken-specific update logic here
    -- For example, chickens could have a small chance to jump randomly:
    if self.onGround and self.animation.state == "walk" and math.random() < 0.005 and not self.isPushed then
        self.vy = -100  -- Small hop
    end

    -- Update panic timer
    if self.panicTimer > 0 then
        self.panicTimer = self.panicTimer - dt
    end

    -- Gradually recover from being pushed (slow down)
    -- if self.isPushed then
    --     -- Apply friction to slow down pushed chicken, but slower when airborne
    --     local friction = self.onGround and self.recoveryRate or 0.98
    --     self.vx = self.vx * friction

    --     -- If speed is very low and on ground, stop being pushed
    --     if math.abs(self.vx) < 5 and self.onGround and not self.isPushAirborne then
    --         self.isPushed = false
    --         -- Return to normal behavior
    --         if self.vx > 0 then
    --             self.direction = "right"
    --             self.vx = self.speed
    --         elseif self.vx < 0 then
    --             self.direction = "left"
    --             self.vx = -self.speed
    --         end
    --     end
    -- end
end

-- Check collision with player and get pushed
function Chicken:checkPlayerCollision()
    local world = self.world
    if not world.player then
        return  -- No player in the world yet
    end

    local player = world.player

    -- Skip collision if on cooldown
    if self.collisionCooldown > 0 then
        self.collisionCooldown = self.collisionCooldown - love.timer.getDelta()
        return
    end

    -- Simple box collision check
    local chickenLeft = self.x - self.width / 2
    local chickenRight = self.x + self.width / 2
    local chickenTop = self.y - self.height / 2
    local chickenBottom = self.y + self.height / 2

    local playerLeft = player.x - player.width / 2
    local playerRight = player.x + player.width / 2
    local playerTop = player.y - player.height / 2
    local playerBottom = player.y + player.height / 2

    -- Check if collision boxes overlap
    if chickenRight > playerLeft and
       chickenLeft < playerRight and
       chickenBottom > playerTop and
       chickenTop < playerBottom then

        -- Determine push direction (away from player)
        local pushForce = 150  -- Increased base push force
        local dx = self.x - player.x
        local dy = self.y - player.y

        -- Calculate distance for push strength
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < 1 then dist = 1 end  -- Avoid division by zero

        -- Normalize direction and apply push force
        dx = dx / dist
        dy = dy / dist

        -- Add player's velocity to push force for more realistic physics
        local playerSpeedBonus = math.abs(player.vx) * 1.2  -- Increased player velocity influence

        -- Apply horizontal push with increased force
        local basePushX = dx * (pushForce + playerSpeedBonus)

        -- Reduce push based on chicken's push resistance
        local finalPushX = basePushX * (1 - self.pushResistance)

        -- Apply horizontal velocity
        self.vx = math.min(self.maxPushVelocity, math.max(-self.maxPushVelocity, finalPushX))

        -- Apply enhanced vertical push (hop) - stronger upward force
        local upwardForce = -100 - math.abs(player.vy) * 0.5  -- Increased upward force

        -- Apply extra upward boost if player is moving down significantly
        if player.vy > 100 then
            -- Player falling/stomping gives extra upward boost
            upwardForce = upwardForce * 1.5
        end

        -- If player is jumping, apply even more upward force to the chicken
        if player.vy < -50 then
            upwardForce = upwardForce * 1.3
        end

        -- Apply the vertical push if on ground or enhance existing vertical movement if in air
        if self.onGround then
            self.vy = upwardForce
            -- Force chicken to remain airborne for a minimum time
            self.isPushAirborne = true
            self.airborneTimer = self.minAirborneTime + math.abs(playerSpeedBonus) / 500
        else
            -- If already in air, add to the vertical velocity
            self.vy = self.vy + upwardForce * 0.5
            -- Reset airborne timer for longer push trajectory
            self.isPushAirborne = true
            self.airborneTimer = self.minAirborneTime
        end

        -- Set direction based on push
        if dx > 0 then
            self.direction = "right"
        else
            self.direction = "left"
        end

        -- Mark as pushed to handle special movement recovery
        self.isPushed = true

        -- Set cooldown to prevent multiple collisions in quick succession
        self.collisionCooldown = 0.2  -- 0.2 seconds cooldown

        -- In panic, chicken will be pushed further and stay in push mode longer
        self.panicTimer = 1.5  -- 1.5 seconds of panic (increased from 1.0)
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

    -- When pushed, make the chicken appear more dynamically affected
    local scaleY = 1
    local rotation = 0

    if self.isPushed then
        -- Calculate push effects based on velocity
        local pushMagnitude = math.abs(self.vx) / self.maxPushVelocity

        -- Apply squash and stretch effect
        if not self.onGround or self.isPushAirborne then
            -- In air - stretch effect (longer horizontally)
            scaleX = scaleX * (1 + pushMagnitude * 0.2)
            scaleY = 1 - pushMagnitude * 0.15
        else
            -- On ground - squash effect (shorter and wider)
            scaleY = 1 - pushMagnitude * 0.3
            scaleX = scaleX * (1 + pushMagnitude * 0.15)
        end

        -- Dynamic rotation based on velocity and direction
        local rotationMagnitude = pushMagnitude * 0.4 -- Max rotation in radians

        -- When in air, rotate more dramatically
        if not self.onGround or self.isPushAirborne then
            rotationMagnitude = rotationMagnitude * 1.5
        end

        -- Determine rotation direction based on movement
        local rotationDir = (self.vx > 0) and 1 or -1

        -- Panic adds wobble effect
        if self.panicTimer > 0 then
            rotation = math.sin(love.timer.getTime() * 15) * rotationMagnitude * rotationDir
        else
            rotation = rotationMagnitude * rotationDir
        end
    end

    love.graphics.draw(
        self.spriteSheet,
        frame.quad,
        math.floor(self.x),
        math.floor(self.y),
        rotation,  -- Add rotation when pushed
        scaleX, scaleY,  -- Apply squish effect when pushed
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