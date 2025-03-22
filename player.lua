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
    self.speed = 130
    self.gravity = 800
    self.jumpForce = 330
    self.vx = 0
    self.vy = 0
    self.onGround = false
    self.facing = "right"
    self.jumpCooldown = 0  -- Add cooldown timer for jumping
    self.landingTimer = 0  -- Timer for landing animation

    -- Building
    self.selectedBlockType = world.BLOCK_DIRT
    self.blockTypes = {
        world.BLOCK_DIRT,
        world.BLOCK_STONE,
        world.BLOCK_WOOD,
        world.BLOCK_PLATFORM,
        world.BLOCK_WOOD_BACKGROUND,
        world.BLOCK_STONE_BACKGROUND,
        world.BLOCK_TREE,
        world.BLOCK_LEAVES,
    }
    self.blockTypeIndex = 1

    -- Furniture types
    self.furnitureMode = false
    self.selectedFurnitureType = world.FURNITURE_DOOR
    self.furnitureTypes = {
        world.FURNITURE_DOOR,
        world.FURNITURE_BED,
        world.FURNITURE_CHAIR,
        world.FURNITURE_TABLE,
        world.FURNITURE_BOOKSHELF,
        world.FURNITURE_SOFA,
        world.FURNITURE_SMALL_TABLE,
    }
    self.furnitureTypeIndex = 1

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
        down = {"down", "s"}
    }

    -- Input state
    self.input = {
        left = false,
        right = false,
        jump = false,
        jumpPressed = false,
        down = false
    }

    -- Animation state
    self.animation = {
        state = "idle", -- idle, run, jump, fall, landing
        frame = 1,
        timer = 0,
        frameTime = 0.15,  -- Made animation slightly faster for smooth walking
        wasInAir = false,   -- Track if player was in the air in previous frame
        jumpEndHoldCounter = 0  -- Counter to hold the final jump frame
    }

    -- Load the character spritesheets
    self.idleSpritesheet = love.graphics.newImage("assets/Characters/Knight_player_1.4/Knight_player/Idle_KG_1.png")
    self.walkingSpritesheet = love.graphics.newImage("assets/Characters/Knight_player_1.4/Knight_player/Walking_KG_1.png")
    self.jumpSpritesheet = love.graphics.newImage("assets/Characters/Knight_player_1.4/Knight_player/Jump_KG_1.png")
    self.fallSpritesheet = love.graphics.newImage("assets/Characters/Knight_player_1.4/Knight_player/Fall_KG_1.png")
    self.landingSpritesheet = love.graphics.newImage("assets/Characters/Knight_player_1.4/Knight_player/Landing_KG_1.png")

    -- Define sprite dimensions and offsets based on the CSS values
    -- From CSS we have dimensions around 32-33px width and 61-63px height
    self.spriteWidth = 33
    self.spriteHeight = 63

    -- Create quads for different animations
    self.quads = {
        idle = {},
        run = {},
        jump = {},
        fall = {},
        landing = {}
    }

    -- Idle animation frames - based on CSS
    -- First frame at position -33px -3px
    self.quads.idle[1] = love.graphics.newQuad(
        33, 1,  -- x, y position in the spritesheet
        33, 63, -- width, height of the frame
        self.idleSpritesheet:getDimensions()
    )

    -- Second frame at position -134px -3px
    self.quads.idle[2] = love.graphics.newQuad(
        134, 1,
        33, 63,
        self.idleSpritesheet:getDimensions()
    )

    -- Third frame at position -234px -1px
    self.quads.idle[3] = love.graphics.newQuad(
        234, 1,
        33, 63,
        self.idleSpritesheet:getDimensions()
    )

    -- Fourth frame - same as third (as per the CSS)
    self.quads.idle[4] = love.graphics.newQuad(
        234, 1,
        33, 63,
        self.idleSpritesheet:getDimensions()
    )

    -- Running/walking animation frames based on CSS for Walking_KG_1.png
    -- Frame 1 at position -34px 0
    self.quads.run[1] = love.graphics.newQuad(
        34, 1,
        30, 64,
        self.walkingSpritesheet:getDimensions()
    )

    -- Frame 2 at position -134px -2px
    self.quads.run[2] = love.graphics.newQuad(
        134, 1,
        32, 62,
        self.walkingSpritesheet:getDimensions()
    )

    -- Frame 3 at position -233px -3px
    self.quads.run[3] = love.graphics.newQuad(
        233, 1,
        36, 61,
        self.walkingSpritesheet:getDimensions()
    )

    -- Frame 4 at position -335px 0
    self.quads.run[4] = love.graphics.newQuad(
        335, 1,
        32, 64,
        self.walkingSpritesheet:getDimensions()
    )

    -- Frame 5 at position -434px -1px
    self.quads.run[5] = love.graphics.newQuad(
        434, 1,
        31, 63,
        self.walkingSpritesheet:getDimensions()
    )

    -- Frame 6 at position -530px -3px
    self.quads.run[6] = love.graphics.newQuad(
        530, 1,
        34, 61,
        self.walkingSpritesheet:getDimensions()
    )

    -- Frame 7 at position -633px -2px
    self.quads.run[7] = love.graphics.newQuad(
        633, 1,
        32, 62,
        self.walkingSpritesheet:getDimensions()
    )

    -- Jump animation frames for Jump_KG_1.png - assuming similar pattern as other spritesheets
    -- Frame 1
    self.quads.jump[1] = love.graphics.newQuad(
        34, 1,
        32, 64,
        self.jumpSpritesheet:getDimensions()
    )

    -- Frame 2
    self.quads.jump[2] = love.graphics.newQuad(
        134, 1,
        32, 64,
        self.jumpSpritesheet:getDimensions()
    )

    -- Frame 3
    self.quads.jump[3] = love.graphics.newQuad(
        234, 1,
        32, 64,
        self.jumpSpritesheet:getDimensions()
    )

    -- Frame 4
    self.quads.jump[4] = love.graphics.newQuad(
        334, 1,
        32, 64,
        self.jumpSpritesheet:getDimensions()
    )

    -- Frame 5
    self.quads.jump[5] = love.graphics.newQuad(
        434, 1,
        32, 64,
        self.jumpSpritesheet:getDimensions()
    )

    -- Frame 6
    self.quads.jump[6] = love.graphics.newQuad(
        534, 1,
        32, 64,
        self.jumpSpritesheet:getDimensions()
    )

    -- Fall animation frames for Fall_KG_1.png - 3 frames
    -- Frame 1
    self.quads.fall[1] = love.graphics.newQuad(
        34, 1,
        32, 64,
        self.fallSpritesheet:getDimensions()
    )

    -- Frame 2
    self.quads.fall[2] = love.graphics.newQuad(
        134, 1,
        32, 64,
        self.fallSpritesheet:getDimensions()
    )

    -- Frame 3
    self.quads.fall[3] = love.graphics.newQuad(
        234, 1,
        32, 64,
        self.fallSpritesheet:getDimensions()
    )


    -- Frame 2
    self.quads.landing[1] = love.graphics.newQuad(
        134, 1,
        32, 64,
        self.landingSpritesheet:getDimensions()
    )

    -- Frame 3
    self.quads.landing[2] = love.graphics.newQuad(
        234, 1,
        32, 64,
        self.landingSpritesheet:getDimensions()
    )

    -- Frame 4
    self.quads.landing[3] = love.graphics.newQuad(
        334, 1,
        32, 64,
        self.landingSpritesheet:getDimensions()
    )

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
        -- For horizontal movement, we're not moving down, and we want to pass through platforms
        local collisionTop = self.world:isSolid(checkX, newY - self.height / 2 + 2, false, false)
        local collisionMiddle = self.world:isSolid(checkX, newY, false, false)
        local collisionBottom = self.world:isSolid(checkX, newY + self.height / 2 - 2, false, false)

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
        -- Check if player wants to drop through platforms
        local passThroughPlatforms = self.input.down

        -- Check below player
        local feetY = newY + self.height / 2
        local groundLeft = self.world:isSolid(self.x - self.width / 2 + 2, feetY, true, passThroughPlatforms)
        local groundCenter = self.world:isSolid(self.x, feetY, true, passThroughPlatforms)
        local groundRight = self.world:isSolid(self.x + self.width / 2 - 2, feetY, true, passThroughPlatforms)

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
        local ceilingLeft = self.world:isSolid(self.x - self.width / 2 + 2, headY, false, false)
        local ceilingCenter = self.world:isSolid(self.x, headY, false, false)
        local ceilingRight = self.world:isSolid(self.x + self.width / 2 - 2, headY, false, false)

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

        -- Check if player wants to drop through platforms
        local passThroughPlatforms = self.input.down

        local groundLeft = self.world:isSolid(self.x - self.width / 2 + 2, checkY, true, passThroughPlatforms)
        local groundCenter = self.world:isSolid(self.x, checkY, true, passThroughPlatforms)
        local groundRight = self.world:isSolid(self.x + self.width / 2 - 2, checkY, true, passThroughPlatforms)

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
    -- Check if we just landed
    local justLanded = false
    if self.animation.wasInAir and self.onGround then
        justLanded = true
        self.animation.state = "landing"
        self.animation.frame = 1
        self.animation.timer = 0
        self.animation.frameTime = 0.08 -- Faster animation for landing
        self.landingTimer = 0.32 -- Duration of landing animation (4 frames * 0.08s)
        self.animation.jumpEndHoldCounter = 0 -- Reset jump hold counter when landing
    end

    -- Update landing timer
    if self.landingTimer > 0 then
        self.landingTimer = self.landingTimer - dt
    end

    -- Track if we were in the air in this frame for next frame's checks
    self.animation.wasInAir = not self.onGround

    -- Update animation state
    if not justLanded then -- Skip if we just started landing animation
        if not self.onGround then
            -- Handle jump/fall transition with hold counter
            if self.vy < 0 then
                -- Going up - jump animation
                self.animation.state = "jump"
                -- Adjust animation speed for jumping to be slightly faster
                self.animation.frameTime = 0.1
                -- Reset hold counter when starting jump
                if self.animation.state ~= "jump" then
                    self.animation.jumpEndHoldCounter = 0
                end
            else
                -- Going down - should transition to fall
                -- Check if we should continue holding the final jump frame
                if self.animation.state == "jump" then
                    -- If we're at the final jump frame
                    local maxJumpFrames = #self.quads["jump"]
                    if self.animation.frame == maxJumpFrames then
                        -- Increment the hold counter
                        if self.animation.jumpEndHoldCounter < 2 then
                            self.animation.jumpEndHoldCounter = self.animation.jumpEndHoldCounter + 1
                            -- Keep the jump state while holding
                        else
                            -- We've held it long enough, now transition to fall
                            self.animation.state = "fall"
                            self.animation.frame = 1
                            self.animation.timer = 0
                            self.animation.frameTime = 0.12
                            self.animation.jumpEndHoldCounter = 0
                        end
                    else
                        -- Not at final frame yet, continue jump animation
                    end
                else
                    -- We're already in fall or another state
                    self.animation.state = "fall"
                    self.animation.frameTime = 0.12
                    self.animation.jumpEndHoldCounter = 0
                end
            end
        else
            -- On ground states
            if self.landingTimer > 0 then
                -- Keep in landing state until landing animation completes
                self.animation.state = "landing"
                self.animation.frameTime = 0.08
                self.animation.jumpEndHoldCounter = 0
            elseif self.vx ~= 0 then
                self.animation.state = "run"
                self.animation.frameTime = 0.15
                self.animation.jumpEndHoldCounter = 0
            else
                self.animation.state = "idle"
                self.animation.frameTime = 0.15
                self.animation.jumpEndHoldCounter = 0
            end
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

        -- Don't advance frames if we're holding the final jump frame
        if self.animation.state == "jump" and
           self.animation.frame == #self.quads["jump"] and
           self.vy > 0 and
           self.animation.jumpEndHoldCounter > 0 then
            -- Don't increment frame, we're holding
        else
            self.animation.frame = self.animation.frame + 1
        end

        -- Animation loop or completion handling
        if self.animation.frame > maxFrames then
            if self.animation.state == "landing" then
                -- After landing animation completes, go to idle or run
                self.animation.frame = 1
                if self.vx ~= 0 then
                    self.animation.state = "run"
                else
                    self.animation.state = "idle"
                end
                self.landingTimer = 0
            else
                -- Loop other animations
                self.animation.frame = 1
            end
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

    -- Scale based on facing direction
    -- Using a larger scale since the knight sprite is smaller than the previous sprite
    local scaleX = 0.75  -- Adjust scale for the knight sprite
    if self.facing == "left" then scaleX = -0.75 end
    local scaleY = 0.75

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

    -- Select the correct spritesheet based on the animation state
    local currentSpritesheet
    if self.animation.state == "run" then
        currentSpritesheet = self.walkingSpritesheet
    elseif self.animation.state == "jump" then
        currentSpritesheet = self.jumpSpritesheet
    elseif self.animation.state == "fall" then
        currentSpritesheet = self.fallSpritesheet
    elseif self.animation.state == "landing" then
        currentSpritesheet = self.landingSpritesheet
    else
        currentSpritesheet = self.idleSpritesheet
    end

    -- Calculate the origin points (center of character)
    local originX = self.spriteWidth / 2   -- Center of the sprite width
    local originY = self.spriteHeight / 2  -- Center of the sprite height

    -- Draw the sprite
    love.graphics.draw(
        currentSpritesheet,
        quad,
        self.x,
        self.y,
        0,  -- rotation
        scaleX, scaleY,  -- scale x, y
        originX, originY  -- origin x, y (center of the sprite)
    )

    -- Draw block selection notification above player if active
    if self.blockChangeNotification.timer > 0 then
        -- Calculate alpha based on remaining time (fade out)
        local alpha = math.min(1, self.blockChangeNotification.timer / (self.blockChangeNotification.duration * 0.5))

        -- Draw text background
        love.graphics.setColor(0, 0, 0, 0.7 * alpha)
        local textWidth = #self.blockChangeNotification.text * 7.5 -- -Approximate width
        love.graphics.rectangle("fill",
            self.x - textWidth/2 - 5,
            self.y - self.height - 7,
            textWidth,
            20)

        -- Draw text
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(
            self.blockChangeNotification.text,
            self.x - textWidth/2,
            self.y - self.height - 5)
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
    if self.furnitureMode then
        -- Select furniture type
        self.furnitureTypeIndex = index
        self.selectedFurnitureType = self.furnitureTypes[index]

        -- Get furniture name
        local furniture = self.world.furnitureRegistry:getFurniture(self.selectedFurnitureType)
        local furnitureName = furniture and furniture.name or "Unknown Furniture"

        -- Show notification
        self.blockChangeNotification.text = "Selected: " .. furnitureName
        self.blockChangeNotification.timer = self.blockChangeNotification.duration
    else
        -- Original block selection code
        self.blockTypeIndex = index
        self.selectedBlockType = self.blockTypes[index]

        -- Get block name
        local block = self.world.blockRegistry:getBlock(self.selectedBlockType)
        local blockName = block and block.name or "Unknown Block"

        -- Show notification
        self.blockChangeNotification.text = "Selected: " .. blockName
        self.blockChangeNotification.timer = self.blockChangeNotification.duration
    end
end

function Player:nextBlockType()
    if self.furnitureMode then
        -- Select next furniture type
        self.furnitureTypeIndex = self.furnitureTypeIndex % #self.furnitureTypes + 1
        self:selectBlockType(self.furnitureTypeIndex)
    else
        -- Original next block type code
        self.blockTypeIndex = self.blockTypeIndex % #self.blockTypes + 1
        self:selectBlockType(self.blockTypeIndex)
    end
end

function Player:prevBlockType()
    if self.furnitureMode then
        -- Select previous furniture type
        self.furnitureTypeIndex = (self.furnitureTypeIndex - 2) % #self.furnitureTypes + 1
        self:selectBlockType(self.furnitureTypeIndex)
    else
        -- Original previous block type code
        self.blockTypeIndex = (self.blockTypeIndex - 2) % #self.blockTypes + 1
        self:selectBlockType(self.blockTypeIndex)
    end
end

-- Toggle between furniture mode and block mode
function Player:toggleFurnitureMode()
    self.furnitureMode = not self.furnitureMode

    if self.furnitureMode then
        -- Switching to furniture mode
        self.blockChangeNotification.text = "Furniture Mode"
        self.blockChangeNotification.timer = self.blockChangeNotification.duration
    else
        -- Switching to block mode
        self.blockChangeNotification.text = "Block Mode"
        self.blockChangeNotification.timer = self.blockChangeNotification.duration
    end
end

-- Select furniture type by index
function Player:selectFurnitureType(index)
    if index <= 0 or index > #self.furnitureTypes then
        return
    end

    self.furnitureTypeIndex = index
    self.selectedFurnitureType = self.furnitureTypes[index]

    -- Get furniture name
    local furniture = self.world.furnitureRegistry:getFurniture(self.selectedFurnitureType)
    local furnitureName = furniture and furniture.name or "Unknown Furniture"

    -- Show notification
    self.blockChangeNotification.text = "Selected: " .. furnitureName
    self.blockChangeNotification.timer = self.blockChangeNotification.duration
end

-- Select next furniture type
function Player:nextFurnitureType()
    local nextIndex = self.furnitureTypeIndex % #self.furnitureTypes + 1
    self:selectFurnitureType(nextIndex)
end

-- Select previous furniture type
function Player:prevFurnitureType()
    local prevIndex = (self.furnitureTypeIndex - 2) % #self.furnitureTypes + 1
    self:selectFurnitureType(prevIndex)
end

return Player