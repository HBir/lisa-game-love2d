-- NPC base class for all non-player characters
local NPC = {}
NPC.__index = NPC

function NPC:new(world, x, y, width, height)
    local self = setmetatable({}, self)

    -- World reference
    self.world = world

    -- Position and size
    self.x = x
    self.y = y
    self.width = width or 16  -- Default size
    self.height = height or 16

    -- Movement properties
    self.vx = 0
    self.vy = 0
    self.speed = 20  -- Default speed (slower than player)
    self.direction = math.random() > 0.5 and "left" or "right"  -- Random initial direction
    self.gravity = 800
    self.onGround = false

    -- AI behavior
    self.behavior = "wander"  -- Default behavior
    self.thinkTimer = 0
    self.thinkInterval = math.random(1, 4)  -- Random time between AI decisions
    self.moveTimer = 0
    self.moveInterval = math.random(1, 3)  -- Random time to move in one direction
    self.idleTimer = 0
    self.idleInterval = math.random(1, 2)  -- Random time to stay idle
    self.active = true  -- Whether this NPC is currently active

    -- Animation state
    self.animation = {
        state = "idle",  -- idle, walk
        frame = 1,
        timer = 0,
        frameTime = 0.2,
        frames = {}  -- Will be set by child classes
    }

    return self
end

function NPC:update(dt)
    if not self.active then return end

    -- Update AI behavior
    self:updateAI(dt)

    -- Apply gravity
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

function NPC:updateAI(dt)
    -- Update think timer
    self.thinkTimer = self.thinkTimer + dt

    -- Make decisions based on behavior
    if self.behavior == "wander" then
        if self.animation.state == "idle" then
            -- In idle state
            self.idleTimer = self.idleTimer + dt
            if self.idleTimer >= self.idleInterval then
                -- Done being idle, start moving
                self.idleTimer = 0
                self.idleInterval = math.random(1, 2)  -- Set next idle time

                -- Choose random direction
                if math.random() > 0.5 then
                    self.direction = "left"
                    self.vx = -self.speed
                else
                    self.direction = "right"
                    self.vx = self.speed
                end

                self.animation.state = "walk"
            end
        else
            -- In walk state
            self.moveTimer = self.moveTimer + dt
            if self.moveTimer >= self.moveInterval then
                -- Done moving, go idle
                self.moveTimer = 0
                self.moveInterval = math.random(1, 3)  -- Set next move time
                self.vx = 0
                self.animation.state = "idle"
            end

            -- Check if we should think about changing direction
            if self.thinkTimer >= self.thinkInterval then
                self.thinkTimer = 0
                self.thinkInterval = math.random(1, 4)  -- Set next think time

                -- 30% chance to change direction while walking
                if math.random() < 0.3 then
                    if self.direction == "left" then
                        self.direction = "right"
                        self.vx = self.speed
                    else
                        self.direction = "left"
                        self.vx = -self.speed
                    end
                end
            end
        end
    end

    -- Ensure direction always matches velocity for consistent movement
    if self.vx > 0 then
        self.direction = "right"
    elseif self.vx < 0 then
        self.direction = "left"
    end
end

function NPC:handleCollisions(newX, newY)
    -- Horizontal collision detection
    if self.vx ~= 0 then
        local checkX
        if self.vx > 0 then
            -- Moving right - check right side of NPC
            checkX = newX + self.width / 2
        else
            -- Moving left - check left side of NPC
            checkX = newX - self.width / 2
        end

        -- Check for collision with solid blocks
        local collisionTop = self.world:isSolid(checkX, self.y - self.height / 2 + 2)
        local collisionMiddle = self.world:isSolid(checkX, self.y)
        local collisionBottom = self.world:isSolid(checkX, self.y + self.height / 2 - 2)

        if collisionTop or collisionMiddle or collisionBottom then
            -- If collision, adjust position to edge of block and reverse direction
            if self.vx > 0 then
                newX = math.floor(checkX / self.world.tileSize) * self.world.tileSize - self.width / 2
                self.direction = "left"
                self.vx = -self.speed
            else
                newX = math.ceil(checkX / self.world.tileSize) * self.world.tileSize + self.width / 2
                self.direction = "right"
                self.vx = self.speed
            end
        end
    end

    -- Vertical collision detection
    if self.vy > 0 then -- Falling down
        -- Check below NPC
        local feetY = newY + self.height / 2
        local groundLeft = self.world:isSolid(self.x - self.width / 2 + 2, feetY)
        local groundCenter = self.world:isSolid(self.x, feetY)
        local groundRight = self.world:isSolid(self.x + self.width / 2 - 2, feetY)

        if groundLeft or groundCenter or groundRight then
            -- Found ground - snap to top of the block
            newY = math.floor(feetY / self.world.tileSize) * self.world.tileSize - self.height / 2
            self.vy = 0
            self.onGround = true
        end
    elseif self.vy < 0 then -- Moving up
        -- Check above NPC
        local headY = newY - self.height / 2
        local ceilingLeft = self.world:isSolid(self.x - self.width / 2 + 2, headY)
        local ceilingCenter = self.world:isSolid(self.x, headY)
        local ceilingRight = self.world:isSolid(self.x + self.width / 2 - 2, headY)

        if ceilingLeft or ceilingCenter or ceilingRight then
            -- Hit ceiling - stop upward motion
            newY = math.ceil(headY / self.world.tileSize) * self.world.tileSize + self.height / 2
            self.vy = 0
        end
    end

    -- Turn around at ledges if the NPC is on the ground
    if self.onGround and self.vx ~= 0 then
        local checkX
        if self.vx > 0 then
            -- Moving right - check for ledge on right
            checkX = self.x + self.width / 2 + 2
        else
            -- Moving left - check for ledge on left
            checkX = self.x - self.width / 2 - 2
        end

        -- Check for ground below the potential ledge
        local ledgeY = self.y + self.height / 2 + 5  -- Check a bit below feet
        local hasGround = self.world:isSolid(checkX, ledgeY)

        if not hasGround then
            -- No ground ahead, turn around
            if self.vx > 0 then
                self.direction = "left"
                self.vx = -self.speed
            else
                self.direction = "right"
                self.vx = self.speed
            end
        end
    end

    -- Check world boundaries
    if newX < self.width / 2 then
        newX = self.width / 2
        self.direction = "right"
        self.vx = self.speed
    elseif newX > self.world.width * self.world.tileSize - self.width / 2 then
        newX = self.world.width * self.world.tileSize - self.width / 2
        self.direction = "left"
        self.vx = -self.speed
    end

    if newY < self.height / 2 then
        newY = self.height / 2
        self.vy = 0
    elseif newY > self.world.height * self.world.tileSize - self.height / 2 then
        newY = self.world.height * self.world.tileSize - self.height / 2
        self.vy = 0
        self.onGround = true
    end

    -- Update position
    self.x = newX
    self.y = newY
end

function NPC:updateAnimation(dt)
    -- Update animation timer
    self.animation.timer = self.animation.timer + dt

    -- Advance frame if needed
    if self.animation.timer >= self.animation.frameTime then
        self.animation.timer = self.animation.timer - self.animation.frameTime
        self.animation.frame = self.animation.frame + 1

        -- Loop animation
        local frames = self.animation.frames[self.animation.state]
        if frames and self.animation.frame > #frames then
            self.animation.frame = 1
        end
    end
end

function NPC:draw()
    -- This should be overridden by child classes
    love.graphics.setColor(1, 1, 1, 1)

    -- Draw a placeholder rectangle if no specific drawing is implemented
    if not self.sprite then
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.rectangle("fill",
            self.x - self.width/2,
            self.y - self.height/2,
            self.width,
            self.height)

        -- Reset color
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Method to check if the NPC is visible in the camera view (for optimization)
function NPC:isVisible(camera)
    -- Check if camera exists
    if not camera then return true end

    -- Use camera's getBounds method to determine visible area
    local x1, y1, x2, y2 = camera:getBounds()

    -- Check if the NPC is within the visible bounds with some margin
    local margin = 50 -- Add a small margin so NPCs don't pop in/out at screen edge
    return not (self.x + self.width / 2 < x1 - margin or
                self.x - self.width / 2 > x2 + margin or
                self.y + self.height / 2 < y1 - margin or
                self.y - self.height / 2 > y2 + margin)
end

return NPC