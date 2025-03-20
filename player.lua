-- Player module that manages the princess character's behavior and controls
local Player = {}
Player.__index = Player

function Player:new(world, x, y)
    local self = setmetatable({}, Player)

    -- World reference
    self.world = world

    -- Position and size
    self.x = x
    self.y = y
    self.width = 24
    self.height = 48

    -- Movement properties
    self.speed = 120
    self.gravity = 800
    self.jumpForce = 300
    self.vx = 0
    self.vy = 0
    self.onGround = false
    self.facing = "right"
    self.jumpCooldown = 0  -- Add cooldown timer for jumping

    -- Building
    self.selectedBlockType = world.BLOCK_DIRT
    self.blockTypes = {
        world.BLOCK_DIRT,
        world.BLOCK_STONE,
        world.BLOCK_WOOD,
        world.BLOCK_LEAVES
    }
    self.blockTypeIndex = 1

    -- Block selection feedback
    self.blockChangeNotification = {
        text = "",
        timer = 0,
        duration = 1.5 -- How long to show the notification
    }

    -- Controls
    self.controls = {
        left = {"left", "a"},
        right = {"right", "d"},
        jump = {"up", "w", "space"},
    }

    -- Input state
    self.input = {
        left = false,
        right = false,
        jump = false,
        jumpPressed = false
    }

    -- Animation state
    self.animation = {
        state = "idle", -- idle, run, jump, fall
        frame = 1,
        timer = 0,
        frameTime = 0.2  -- Slowed down slightly for better effect
    }

    -- Load the character spritesheet
    self.spritesheet = love.graphics.newImage("assets/Characters/DuskBorne-Elf/SpriteSheet/ElfIdle001Sheet.png")

    -- Define sprite dimensions and offsets based on the CSS values
    -- The actual sprite is much larger according to CSS
    self.spriteWidth = 200
    self.spriteHeight = 430

    -- From the CSS we can determine the positions of frames
    -- First idle frame: -680px -530px
    -- Second idle frame: -2280px -520px
    -- So the spacing between frames is considerable
    -- We'll estimate positions for additional frames

    -- Create quads for different animations
    self.quads = {
        idle = {},
        run = {},
        jump = {},
        fall = {}
    }

    -- Idle animation frames - based on CSS and estimating additional positions
    -- First frame at position -680px -530px
    self.quads.idle[1] = love.graphics.newQuad(
        680, 530,
        self.spriteWidth, self.spriteHeight,
        self.spritesheet:getDimensions()
    )

    -- Second frame at position -2280px -520px
    self.quads.idle[2] = love.graphics.newQuad(
        2280, 520,
        self.spriteWidth, self.spriteHeight,
        self.spritesheet:getDimensions()
    )

    -- Adding more frames by estimating positions based on the pattern seen in the first two frames
    -- Third frame (estimated position)
    self.quads.idle[3] = love.graphics.newQuad(
        3880, 530,  -- Estimated based on pattern
        self.spriteWidth, self.spriteHeight,
        self.spritesheet:getDimensions()
    )

    -- Fourth frame (estimated position)
    self.quads.idle[4] = love.graphics.newQuad(
        5480, 530,  -- Estimated based on pattern
        self.spriteWidth, self.spriteHeight,
        self.spritesheet:getDimensions()
    )

    -- For now, we'll use the idle frames for running too
    self.quads.run = self.quads.idle

    -- Jump and fall animations use the first idle frame for now
    self.quads.jump[1] = self.quads.idle[1]
    self.quads.fall[1] = self.quads.idle[2]

    return self
end

function Player:update(dt)
    -- Process input
    self:processInput()

    -- Apply horizontal movement
    self.vx = 0
    if self.input.left then self.vx = -self.speed end
    if self.input.right then self.vx = self.speed end

    -- Update jumpCooldown timer
    if self.jumpCooldown > 0 then
        self.jumpCooldown = self.jumpCooldown - dt
    end

    -- Update position based on velocity
    self:move(dt)

    -- Update animation
    self:updateAnimation(dt)
end

function Player:processInput()
    -- Check jump
    if self.input.jumpPressed and self.onGround then
        self.vy = -self.jumpForce
        self.onGround = false
        self.input.jumpPressed = false

        -- Prevent ground detection for a few frames after jumping
        -- to avoid immediately re-detecting the ground
        self.jumpCooldown = 0.1 -- 0.1 seconds of cooldown after jumping
    end
end

function Player:move(dt)
    -- Calculate new position
    local newX = self.x + self.vx * dt

    -- Always apply gravity first, then check if on ground
    self.vy = self.vy + self.gravity * dt
    local newY = self.y + self.vy * dt

    -- Reset ground state (will be set to true if we detect ground)
    -- Only if we're not in jump cooldown
    if self.jumpCooldown <= 0 then
        self.onGround = false
    end

    -- Horizontal collision detection
    if self.vx ~= 0 then
        local checkX
        if self.vx > 0 then
            -- Moving right - check right side of player
            checkX = newX + self.width / 2
            self.facing = "right"
        else
            -- Moving left - check left side of player
            checkX = newX - self.width / 2
            self.facing = "left"
        end

        -- Check for collision with solid blocks - use newY for more accurate prediction
        local collisionTop = self.world:isSolid(checkX, newY - self.height / 2 + 2)
        local collisionMiddle = self.world:isSolid(checkX, newY)
        local collisionBottom = self.world:isSolid(checkX, newY + self.height / 2 - 2)

        if collisionTop or collisionMiddle or collisionBottom then
            -- If collision, adjust position to edge of block
            if self.vx > 0 then
                -- Right collision - place player at left edge of the block
                newX = math.floor(checkX / self.world.tileSize) * self.world.tileSize - self.width / 2
            else
                -- Left collision - place player at right edge of the block
                newX = math.ceil(checkX / self.world.tileSize) * self.world.tileSize + self.width / 2
            end
            self.vx = 0 -- Stop horizontal movement
        end
    end

    -- Vertical collision detection - simplified approach
    if self.vy > 0 then -- Falling down
        -- Check below player
        local feetY = newY + self.height / 2
        local groundLeft = self.world:isSolid(self.x - self.width / 2 + 2, feetY)
        local groundCenter = self.world:isSolid(self.x, feetY)
        local groundRight = self.world:isSolid(self.x + self.width / 2 - 2, feetY)

        if groundLeft or groundCenter or groundRight then
            -- Found ground - snap to top of the block
            newY = math.floor(feetY / self.world.tileSize) * self.world.tileSize - self.height / 2
            self.vy = 0
            if self.jumpCooldown <= 0 then
                self.onGround = true
            end
        end
    elseif self.vy < 0 then -- Moving up
        -- Check above player
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

    -- If we end up very close to the ground, just snap to it
    -- This helps prevent micro-bounces
    if not self.onGround and self.vy >= 0 and self.jumpCooldown <= 0 then
        local snapDistance = 2 -- Pixels to check below
        local checkY = newY + self.height / 2 + snapDistance

        local groundLeft = self.world:isSolid(self.x - self.width / 2 + 2, checkY)
        local groundCenter = self.world:isSolid(self.x, checkY)
        local groundRight = self.world:isSolid(self.x + self.width / 2 - 2, checkY)

        if groundLeft or groundCenter or groundRight then
            -- We're very close to ground, just snap to it
            newY = math.floor(checkY / self.world.tileSize) * self.world.tileSize - self.height / 2
            self.vy = 0
            self.onGround = true
        end
    end

    -- Update position
    self.x = newX
    self.y = newY

    -- World boundaries with simplified handling
    if self.x < self.width / 2 then
        self.x = self.width / 2
    elseif self.x > self.world.width * self.world.tileSize - self.width / 2 then
        self.x = self.world.width * self.world.tileSize - self.width / 2
    end

    if self.y < self.height / 2 then
        self.y = self.height / 2
        self.vy = 0
    elseif self.y > self.world.height * self.world.tileSize - self.height / 2 then
        self.y = self.world.height * self.world.tileSize - self.height / 2
        self.vy = 0
        if self.jumpCooldown <= 0 then
            self.onGround = true
        end
    end

    -- Add a larger deadzone for vertical velocities when on ground
    if self.onGround and math.abs(self.vy) < 10 then
        self.vy = 0
    end
end

function Player:updateAnimation(dt)
    -- Update animation state
    if not self.onGround then
        if self.vy < 0 then
            self.animation.state = "jump"
        else
            self.animation.state = "fall"
        end
    else
        if self.vx ~= 0 then
            self.animation.state = "run"
        else
            self.animation.state = "idle"
        end
    end

    -- Ensure frame is valid for current animation state
    local maxFrames = #self.quads[self.animation.state]
    if self.animation.frame > maxFrames then
        self.animation.frame = 1
    end

    -- Update animation frame
    self.animation.timer = self.animation.timer + dt
    if self.animation.timer >= self.animation.frameTime then
        self.animation.timer = self.animation.timer - self.animation.frameTime
        self.animation.frame = self.animation.frame + 1

        -- Animation loop based on state
        if self.animation.frame > maxFrames then
            self.animation.frame = 1
        end
    end

    -- Update block change notification timer
    if self.blockChangeNotification.timer > 0 then
        self.blockChangeNotification.timer = self.blockChangeNotification.timer - dt
    end
end

function Player:draw()
    -- Draw player sprite
    love.graphics.setColor(1, 1, 1, 1)

    -- Scale based on facing direction and make the sprite smaller to fit the game
    local scaleX = 0.12  -- Restored to the larger scale
    if self.facing == "left" then scaleX = -0.12 end
    local scaleY = 0.12  -- Scaling y-axis to match

    -- Ensure we have a valid animation state and frame
    if not self.quads[self.animation.state] then
        self.animation.state = "idle"
    end

    local maxFrames = #self.quads[self.animation.state]
    if self.animation.frame > maxFrames then
        self.animation.frame = 1
    end

    -- Get current animation frame
    local quad = self.quads[self.animation.state][self.animation.frame]

    -- Calculate the origin points (center of character)
    local originX = self.spriteWidth / 2   -- Center of the sprite width
    local originY = self.spriteHeight / 2  -- Center of the sprite height

    -- Draw the sprite
    love.graphics.draw(
        self.spritesheet,
        quad,
        self.x,
        self.y,
        0,  -- rotation
        scaleX, scaleY,  -- scale x, y (restored to larger size)
        originX, originY  -- origin x, y (center of the sprite)
    )

    -- Draw debug collision box
    love.graphics.setColor(1, 0, 0, 0.5)
    love.graphics.rectangle("line",
        self.x - self.width / 2,
        self.y - self.height / 2,
        self.width,
        self.height
    )

    -- Draw ground check points - show where we're checking for ground
    -- Bottom collision points
    love.graphics.setColor(0, 1, 0, 1)
    local feetY = self.y + self.height / 2

    -- Left check point
    love.graphics.circle("fill", self.x - self.width/2 + 2, feetY, 2)

    -- Center check point
    love.graphics.circle("fill", self.x, feetY, 2)

    -- Right check point
    love.graphics.circle("fill", self.x + self.width/2 - 2, feetY, 2)

    -- Enhanced debug info
    love.graphics.setColor(1, 1, 1, 1)
    local debugY = self.y - self.height - 10
    local lineHeight = 15

    -- Ground status
    local groundText = self.onGround and "On Ground: YES" or "On Ground: NO"
    love.graphics.print(
        groundText,
        self.x - 60,
        debugY,
        0,   -- rotation
        1, 1 -- scale
    )

    -- Vertical velocity info
    love.graphics.print(
        "vY: " .. string.format("%.1f", self.vy),
        self.x - 60,
        debugY + lineHeight,
        0,   -- rotation
        1, 1 -- scale
    )

    -- Horizontal velocity info
    love.graphics.print(
        "vX: " .. string.format("%.1f", self.vx),
        self.x - 60,
        debugY + lineHeight * 2,
        0,   -- rotation
        1, 1 -- scale
    )

    -- Jump cooldown
    love.graphics.print(
        "Jump CD: " .. string.format("%.2f", self.jumpCooldown),
        self.x - 60,
        debugY + lineHeight * 3,
        0,   -- rotation
        1, 1 -- scale
    )

    -- Animation state
    love.graphics.print(
        "State: " .. self.animation.state,
        self.x - 60,
        debugY + lineHeight * 4,
        0,   -- rotation
        1, 1 -- scale
    )

    -- Position info
    love.graphics.print(
        "Pos: " .. string.format("%.1f, %.1f", self.x, self.y),
        self.x - 60,
        debugY + lineHeight * 5,
        0,   -- rotation
        1, 1 -- scale
    )

    -- Draw block selection notification above player if active
    if self.blockChangeNotification.timer > 0 then
        -- Calculate alpha based on remaining time (fade out)
        local alpha = math.min(1, self.blockChangeNotification.timer / (self.blockChangeNotification.duration * 0.5))

        -- Draw text background
        love.graphics.setColor(0, 0, 0, 0.7 * alpha)
        local textWidth = #self.blockChangeNotification.text * 8 -- Approximate width
        love.graphics.rectangle("fill",
            self.x - textWidth/2 - 5,
            debugY + lineHeight * 6,
            textWidth + 10,
            20)

        -- Draw text
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(
            self.blockChangeNotification.text,
            self.x - textWidth/2,
            debugY + lineHeight * 6 + 5)
    end
end

function Player:keypressed(key)
    -- Check controls
    for action, keys in pairs(self.controls) do
        for _, k in ipairs(keys) do
            if key == k then
                self.input[action] = true
                if action == "jump" then
                    self.input.jumpPressed = true
                end
            end
        end
    end
end

function Player:keyreleased(key)
    -- Check controls
    for action, keys in pairs(self.controls) do
        for _, k in ipairs(keys) do
            if key == k then
                self.input[action] = false
            end
        end
    end
end

function Player:selectBlockType(index)
    if index >= 1 and index <= #self.blockTypes then
        self.blockTypeIndex = index
        self.selectedBlockType = self.blockTypes[self.blockTypeIndex]

        -- Update notification with block name
        local blockName = self.world.blocks[self.selectedBlockType].name
        self.blockChangeNotification.text = "Selected: " .. blockName
        self.blockChangeNotification.timer = self.blockChangeNotification.duration
    end
end

function Player:nextBlockType()
    self.blockTypeIndex = self.blockTypeIndex + 1
    if self.blockTypeIndex > #self.blockTypes then
        self.blockTypeIndex = 1
    end
    self.selectedBlockType = self.blockTypes[self.blockTypeIndex]

    -- Update notification with block name
    local blockName = self.world.blocks[self.selectedBlockType].name
    self.blockChangeNotification.text = "Selected: " .. blockName
    self.blockChangeNotification.timer = self.blockChangeNotification.duration
end

function Player:prevBlockType()
    self.blockTypeIndex = self.blockTypeIndex - 1
    if self.blockTypeIndex < 1 then
        self.blockTypeIndex = #self.blockTypes
    end
    self.selectedBlockType = self.blockTypes[self.blockTypeIndex]

    -- Update notification with block name
    local blockName = self.world.blocks[self.selectedBlockType].name
    self.blockChangeNotification.text = "Selected: " .. blockName
    self.blockChangeNotification.timer = self.blockChangeNotification.duration
end

return Player