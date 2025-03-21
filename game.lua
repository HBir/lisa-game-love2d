-- Game class that manages the overall game state
local Camera = require("camera")
local World = require("world")
local Player = require("player")
local Chicken = require("chicken")  -- Import the chicken NPC

local Game = {}
Game.__index = Game

function Game:new()
    local self = setmetatable({}, Game)

    -- Game settings
    self.title = "Princess Builder"
    self.width = 800
    self.height = 600

    -- Interaction state
    self.mouseX = 0
    self.mouseY = 0
    self.isPlacingBlock = false
    self.isRemovingBlock = false

    -- Variables to track the last block interacted with
    self.lastBlockX = -1
    self.lastBlockY = -1

    -- Block placement rate control
    self.blockPlacementCooldown = 0
    self.blockPlacementRate = 0.1 -- seconds between block placements

    -- NPC management
    self.npcs = {}  -- Table to store all NPCs

    return self
end

function Game:load()
    -- Set window properties
    love.window.setTitle(self.title)
    love.window.setMode(self.width, self.height, {
        resizable = true,
        vsync = true,
        minwidth = 400,
        minheight = 300
    })

    -- Load background image
    self.backgroundImage = love.graphics.newImage("assets/Tiles/Assets/Background_2.png")

    -- Create dust particle system
    self:initParticleSystems()

    -- Initialize the world
    self.world = World:new(128, 128, 16) -- width, height, tile size
    self.world:generate()

    -- Find a good starting position near the surface
    local startX = 64 * self.world.tileSize -- Middle of the world horizontally
    local startY = 0

    -- Find the ground level at this X position by moving down until we hit solid ground
    for y = 1, self.world.height do
        if self.world:isSolid(startX, y * self.world.tileSize) then
            startY = (y - 1) * self.world.tileSize - 20 -- Position player just above the ground
            break
        end
    end

    -- If no ground found, use a default position
    if startY == 0 then
        startY = math.floor(self.world.height * 0.5) * self.world.tileSize
    end

    -- Initialize the player
    self.player = Player:new(self.world, startX, startY)

    -- Attach player to world so NPCs can access it
    self.world.player = self.player

    -- Initialize the camera
    self.camera = Camera:new(self.width, self.height, 1) -- Use scale factor of 1 instead of world.tileSize
    self.camera:follow(self.player)

    -- Create some chickens in the world
    self:spawnInitialNPCs()

    -- Game state
    self.paused = false
end

-- Function to spawn initial NPCs in the world
function Game:spawnInitialNPCs()
    -- Spawn a few chickens in different areas of the world
    -- We'll place them near the surface on solid ground

    -- First, spawn a chicken near the player
    local playerX = self.player.x
    local groundY = self:findGroundLevel(playerX + 100) -- 100 pixels to the right of player

    if groundY then
        local chicken = Chicken:new(self.world, playerX + 100, groundY - 8)
        table.insert(self.npcs, chicken)
    end

    -- Spawn a few more chickens at different locations
    local spawnPoints = {
        {x = playerX - 200, offset = 0},
        {x = playerX + 300, offset = 0},
        {x = playerX - 400, offset = 0}
    }

    for _, point in ipairs(spawnPoints) do
        local groundY = self:findGroundLevel(point.x)
        if groundY then
            local chicken = Chicken:new(self.world, point.x, groundY - 8)
            table.insert(self.npcs, chicken)
        end
    end
end

-- Helper function to find ground level at a specific x coordinate
function Game:findGroundLevel(x)
    for y = 1, self.world.height do
        local worldY = y * self.world.tileSize
        if self.world:isSolid(x, worldY) then
            return worldY
        end
    end

    -- If no ground found, return nil
    return nil
end

function Game:initParticleSystems()
    -- Create dust particle system with fewer max particles
    self.dustParticles = love.graphics.newParticleSystem(love.graphics.newCanvas(6, 6), 50)  -- Larger canvas, fewer max particles

    -- Draw a simple dust particle on the canvas (larger)
    love.graphics.setCanvas(self.dustParticles:getTexture())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 6, 6)  -- Larger base particle
    love.graphics.setCanvas()

    -- Configure the particle system
    self.dustParticles:setParticleLifetime(0.6, 1.3)  -- Slightly reduced lifetime for less rise
    self.dustParticles:setEmissionRate(0)  -- Start with no emission, will be set dynamically
    self.dustParticles:setSizeVariation(0.6) -- More size variation (60%)
    -- Larger initial sizes and more gradual shrinking
    self.dustParticles:setSizes(1.5, 1.3, 1.0, 0.6, 0.3)  -- Added more size steps for smoother shrinking
    self.dustParticles:setColors(
        0.95, 0.95, 0.9, 0.8,  -- Initial color (more opaque)
        0.9, 0.9, 0.85, 0.7,   -- Mid-life color
        0.85, 0.85, 0.8, 0.5,  -- Later color
        0.8, 0.8, 0.8, 0.3,    -- Near-end color
        0.8, 0.8, 0.75, 0      -- End color (fade out)
    )
    self.dustParticles:setPosition(0, 0)  -- Will be updated based on player position
    self.dustParticles:setLinearDamping(0.4) -- More damping to slow particles down faster

    -- In LÖVE, the emission direction 0 is right, π/2 is down, π is left, 3π/2 is up
    -- So for upward movement we need to use 3π/2 (or -π/2) as base direction
    self.dustParticles:setDirection(-math.pi/2)  -- Straight up
    self.dustParticles:setSpeed(8, 20)    -- REDUCED speed for gentler upward movement

    -- Linear acceleration: minX, minY, maxX, maxY
    self.dustParticles:setLinearAcceleration(-3, -25, 3, -15)  -- REDUCED upward acceleration

    self.dustParticles:setSpread(math.pi/7)  -- Slightly wider spread (25.7 degrees) for more natural dispersion
    self.dustParticles:setRelativeRotation(true)
    -- Add slight spin to particles
    self.dustParticles:setSpin(0, math.pi)  -- Reduced spin range
    self.dustParticles:setSpinVariation(1.0)

    -- Variables to control dust emission
    self.lastPlayerX = 0
    self.lastPlayerY = 0
    self.dustEmitTimer = 0
    self.burstEmitTimer = 0  -- Timer for larger, less frequent bursts

    -- Create block break particle system
    self.blockBreakParticles = love.graphics.newParticleSystem(love.graphics.newCanvas(4, 4), 100)

    -- Draw a simple square particle on the canvas
    love.graphics.setCanvas(self.blockBreakParticles:getTexture())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 4, 4)
    love.graphics.setCanvas()

    -- Configure the block break particle system
    self.blockBreakParticles:setParticleLifetime(0.3, 0.8)
    self.blockBreakParticles:setEmissionRate(0)  -- Only emit when triggered
    self.blockBreakParticles:setSizeVariation(0.5)
    self.blockBreakParticles:setSizes(0.8, 0.6, 0.4, 0.2)
    -- Colors will be set dynamically based on the block type
    self.blockBreakParticles:setPosition(0, 0)  -- Will be set when a block is broken
    self.blockBreakParticles:setLinearDamping(0.1)

    -- Explode in all directions
    self.blockBreakParticles:setDirection(0)  -- Will spread in all directions
    self.blockBreakParticles:setSpeed(30, 80)
    self.blockBreakParticles:setSpread(math.pi * 2)  -- Full 360 degrees

    -- Add gravity effect
    self.blockBreakParticles:setLinearAcceleration(0, 100, 0, 200)

    -- Add slight rotation to particles
    self.blockBreakParticles:setSpin(-6, 6)
    self.blockBreakParticles:setSpinVariation(1.0)

    -- Keep track of active particle systems for block breaks
    self.activeBlockParticles = {}

    -- Create block place particle system
    self.blockPlaceParticles = love.graphics.newParticleSystem(love.graphics.newCanvas(3, 3), 100)

    -- Draw a simple square particle on the canvas
    love.graphics.setCanvas(self.blockPlaceParticles:getTexture())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 3, 3)
    love.graphics.setCanvas()

    -- Configure the block place particle system
    self.blockPlaceParticles:setParticleLifetime(0.3, 0.6)
    self.blockPlaceParticles:setEmissionRate(0)  -- Only emit when triggered
    self.blockPlaceParticles:setSizeVariation(0.4)
    self.blockPlaceParticles:setSizes(0.6, 0.8, 0.5, 0.2)  -- Grow then shrink
    -- Colors will be set dynamically based on the block type
    self.blockPlaceParticles:setPosition(0, 0)  -- Will be set when a block is placed
    self.blockPlaceParticles:setLinearDamping(0.2)

    -- Particles rise from the block edges
    self.blockPlaceParticles:setDirection(-math.pi/2)  -- Upward
    self.blockPlaceParticles:setSpeed(5, 15)          -- Slower than break particles
    self.blockPlaceParticles:setSpread(math.pi/1.2)   -- Mostly upward with some spread

    -- Slight inward gravity to make them hover around the block
    self.blockPlaceParticles:setLinearAcceleration(-15, -10, 15, -5)

    -- Add slight rotation to particles
    self.blockPlaceParticles:setSpin(-2, 2)
    self.blockPlaceParticles:setSpinVariation(1.0)

    -- Keep track of active particle systems for block placements
    self.activePlaceParticles = {}

    -- Create landing particle system
    self.landingParticles = love.graphics.newParticleSystem(love.graphics.newCanvas(5, 5), 80)

    -- Draw a simple particle on the canvas
    love.graphics.setCanvas(self.landingParticles:getTexture())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 5, 5)
    love.graphics.setCanvas()

    -- Configure the landing particle system
    self.landingParticles:setParticleLifetime(0.2, 0.8)
    self.landingParticles:setEmissionRate(0)  -- Only emit when triggered
    self.landingParticles:setSizeVariation(0.6)
    self.landingParticles:setSizes(1.0, 1.5, 1.2, 0.7, 0.3)  -- Expand then contract
    -- Colors will be set based on terrain
    self.landingParticles:setColors(
        0.9, 0.9, 0.8, 0.7,  -- Initial color
        0.9, 0.85, 0.75, 0.8,  -- Mid-life color
        0.85, 0.8, 0.7, 0.6,  -- Later color
        0.8, 0.75, 0.7, 0.4,  -- Near-end color
        0.8, 0.75, 0.65, 0   -- End color (fade out)
    )

    -- Particles should go outward in a wide arc from the feet
    self.landingParticles:setDirection(0)  -- Will be modified at emission
    self.landingParticles:setSpread(math.pi * 0.7)  -- Wide spread but not full circle
    self.landingParticles:setSpeed(30, 70)  -- Faster for impact feeling

    -- Add effects to make them feel "impactful"
    self.landingParticles:setLinearAcceleration(-5, -20, 5, 30)  -- Slight upward then gravity
    self.landingParticles:setLinearDamping(2.0)  -- High damping to slow quickly

    -- Add slight rotation
    self.landingParticles:setSpin(-1, 1)
    self.landingParticles:setSpinVariation(1.0)

    -- Player air time tracking for landing intensity
    self.playerTracking = {
        wasInAir = false,      -- Was the player in the air last frame
        airTime = 0,           -- How long the player has been in the air
        prevVelocityY = 0,     -- Player's velocity on previous frame
        landingParticles = {}  -- Active landing particle systems
    }
end

function Game:update(dt)
    if self.paused then
        return
    end

    -- Track player air time before updating
    local playerWasInAir = not self.player.onGround
    local playerVelocityY = self.player.vy

    -- Update the player
    self.player:update(dt)

    -- Check for landing after player update
    self:checkPlayerLanding(dt, playerWasInAir, playerVelocityY)

    -- Update the camera to follow the player
    self.camera:update(dt)

    -- Update all NPCs
    self:updateNPCs(dt)

    -- Update dust particles
    self:updateDustParticles(dt)

    -- Update block break particles
    self:updateBlockParticles(dt)

    -- Update block place particles
    self:updatePlaceParticles(dt)

    -- Update landing particles
    self:updateLandingParticles(dt)

    -- Update mouse position
    self.mouseX, self.mouseY = love.mouse.getPosition()

    -- Update block placement cooldown
    if self.blockPlacementCooldown > 0 then
        self.blockPlacementCooldown = self.blockPlacementCooldown - dt
    end

    -- Handle continuous block placement/removal when mouse is held down
    if (self.isPlacingBlock or self.isRemovingBlock) and self.blockPlacementCooldown <= 0 then
        -- Convert screen coordinates to world coordinates
        local worldX, worldY = self.camera:screenToWorld(self.mouseX, self.mouseY)

        -- Convert to grid coordinates
        local gridX = math.floor(worldX / self.world.tileSize) + 1
        local gridY = math.floor(worldY / self.world.tileSize) + 1

        -- Check if this is a different block than the last one we interacted with
        if gridX ~= self.lastBlockX or gridY ~= self.lastBlockY then
            if self.isRemovingBlock then
                local blockType = self.world:getBlock(worldX, worldY)
                if blockType ~= World.BLOCK_AIR then
                    -- Create a block removal particle effect before removing the block
                    self:emitBlockBreakParticles(worldX, worldY, blockType)
                    self.world:removeBlock(worldX, worldY)
                end
            elseif self.isPlacingBlock then
                local success = self.world:placeBlock(worldX, worldY, self.player.selectedBlockType)
                if success then
                    -- Create a block placement particle effect after placing the block
                    self:emitBlockPlaceParticles(worldX, worldY, self.player.selectedBlockType)
                end
            end

            -- Update the last block coordinates
            self.lastBlockX = gridX
            self.lastBlockY = gridY

            -- Set cooldown to prevent too frequent block operations
            self.blockPlacementCooldown = self.blockPlacementRate
        end
    end
end

-- Function to update all NPCs
function Game:updateNPCs(dt)
    for i, npc in ipairs(self.npcs) do
        -- Only update NPCs that are visible on screen (optimization)
        if npc:isVisible(self.camera) then
            npc:update(dt)
        end
    end
end

function Game:updateDustParticles(dt)
    -- Update the particle system
    self.dustParticles:update(dt)

    -- Only emit dust when running on the ground
    local isRunning = self.player.vx ~= 0 and self.player.onGround
    local playerMovementState = self.player.animation.state

    if isRunning and playerMovementState == "run" then
        -- Position particles at the player's feet, slightly behind based on direction
        local particleX = self.player.x
        local particleY = self.player.y + self.player.height/2 - 2  -- At the player's feet, slightly higher

        -- Proper direction angles for upward movement
        -- In LÖVE, -π/2 is straight up, so we adjust slightly from that base
        if self.player.facing == "right" then
            particleX = particleX - 8  -- Slightly behind when facing right
            -- When facing right, we want particles to go up and slightly back (left)
            -- Less steep angle for more gentle rise
            self.dustParticles:setDirection(-math.pi/2 - math.pi/12)  -- Up and slightly left
        else
            particleX = particleX + 8  -- Slightly behind when facing left
            -- When facing left, we want particles to go up and slightly back (right)
            -- Less steep angle for more gentle rise
            self.dustParticles:setDirection(-math.pi/2 + math.pi/12)  -- Up and slightly right
        end

        -- Position the emitter
        self.dustParticles:setPosition(particleX, particleY)

        -- Control emission rate based on horizontal speed but at lower rate
        local speedFactor = math.abs(self.player.vx) / self.player.speed
        self.dustParticles:setEmissionRate(12 * speedFactor)  -- Slightly increased for more consistent dust

        -- Emit a larger burst when direction changes or player starts moving
        if (self.lastPlayerX == 0 or (self.player.vx > 0 and self.lastPlayerX < 0) or
            (self.player.vx < 0 and self.lastPlayerX > 0)) then
            -- For direction changes, emit particles with near-vertical trajectory
            local originalDirection = self.dustParticles:getDirection()
            local originalSpeed = {self.dustParticles:getSpeed()}

            -- Straight up is -π/2, with gentler velocity
            self.dustParticles:setDirection(-math.pi/2)
            self.dustParticles:setSpread(math.pi/10)
            self.dustParticles:setSpeed(10, 25)  -- Reduced burst speed
            self.dustParticles:emit(5)          -- Emit particles

            -- Restore original settings
            self.dustParticles:setDirection(originalDirection)
            self.dustParticles:setSpread(math.pi/7)
            self.dustParticles:setSpeed(unpack(originalSpeed))
        end

        -- Add less frequent but larger bursts for more dynamic effect
        self.dustEmitTimer = self.dustEmitTimer + dt
        if self.dustEmitTimer > 0.4 then  -- Less frequent
            -- Small burst with slightly higher velocity for mid-run particles
            local originalSpeed = {self.dustParticles:getSpeed()}
            self.dustParticles:setSpeed(originalSpeed[1] * 1.2, originalSpeed[2] * 1.2)
            self.dustParticles:emit(2)  -- Fewer particles per burst
            self.dustParticles:setSpeed(unpack(originalSpeed))
            self.dustEmitTimer = 0
        end

        -- Occasional larger puffs of dust with high vertical trajectory
        self.burstEmitTimer = self.burstEmitTimer + dt
        if self.burstEmitTimer > 1.2 then  -- Every 1.2 seconds
            -- Set temporary larger size for next few particles and vertical trajectory
            local originalSizes = {self.dustParticles:getSizes()}
            local originalDirection = self.dustParticles:getDirection()
            local originalSpread = self.dustParticles:getSpread()
            local originalSpeed = {self.dustParticles:getSpeed()}

            -- Configure for a big vertical burst - but more gentle
            self.dustParticles:setSizes(2.2, 1.8, 1.4, 0.9, 0.4)  -- Slightly smaller
            self.dustParticles:setDirection(-math.pi/2)           -- Straight up
            self.dustParticles:setSpread(math.pi/10)              -- Slightly wider spread
            self.dustParticles:setSpeed(15, 30)                  -- REDUCED upward speed

            -- Emit the big vertical burst
            self.dustParticles:emit(4)  -- Emit a few big particles

            -- Restore original settings
            self.dustParticles:setSizes(unpack(originalSizes))
            self.dustParticles:setDirection(originalDirection)
            self.dustParticles:setSpread(originalSpread)
            self.dustParticles:setSpeed(unpack(originalSpeed))

            self.burstEmitTimer = 0
        end
    else
        -- Stop emitting when not running
        self.dustParticles:setEmissionRate(0)
    end

    -- Remember player's velocity for next frame
    self.lastPlayerX = self.player.vx
    self.lastPlayerY = self.player.vy
end

function Game:updateBlockParticles(dt)
    local i = 1
    while i <= #self.activeBlockParticles do
        local particleSystem = self.activeBlockParticles[i]
        particleSystem.system:update(dt)
        particleSystem.timeRemaining = particleSystem.timeRemaining - dt

        -- Remove expired particle systems
        if particleSystem.timeRemaining <= 0 and particleSystem.system:getCount() == 0 then
            table.remove(self.activeBlockParticles, i)
        else
            i = i + 1
        end
    end
end

function Game:updatePlaceParticles(dt)
    local i = 1
    while i <= #self.activePlaceParticles do
        local particleSystem = self.activePlaceParticles[i]
        particleSystem.system:update(dt)
        particleSystem.timeRemaining = particleSystem.timeRemaining - dt

        -- Remove expired particle systems
        if particleSystem.timeRemaining <= 0 and particleSystem.system:getCount() == 0 then
            table.remove(self.activePlaceParticles, i)
        else
            i = i + 1
        end
    end
end

function Game:updateLandingParticles(dt)
    local i = 1
    while i <= #self.playerTracking.landingParticles do
        local particleSystem = self.playerTracking.landingParticles[i]
        particleSystem.system:update(dt)
        particleSystem.timeRemaining = particleSystem.timeRemaining - dt

        -- Remove expired particle systems
        if particleSystem.timeRemaining <= 0 and particleSystem.system:getCount() == 0 then
            table.remove(self.playerTracking.landingParticles, i)
        else
            i = i + 1
        end
    end
end

function Game:draw()
    -- Clear screen with default color (will be covered by background)
    love.graphics.clear(0, 0, 0)

    -- Draw the background image (tiled to fill the screen)
    love.graphics.setColor(1, 1, 1)
    local bgScaleX = self.width / self.backgroundImage:getWidth()
    local bgScaleY = self.height / self.backgroundImage:getHeight()
    love.graphics.draw(self.backgroundImage, 0, 0, 0, bgScaleX, bgScaleY)

    -- Begin camera transformation
    self.camera:set()

    -- Draw the world
    self.world:draw(self.camera)

    -- Draw dust particles (behind the player)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.dustParticles, 0, 0)

    -- Draw block break particles
    for _, particleSystem in ipairs(self.activeBlockParticles) do
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(particleSystem.system, 0, 0)
    end

    -- Draw block place particles
    for _, particleSystem in ipairs(self.activePlaceParticles) do
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(particleSystem.system, 0, 0)
    end

    -- Draw landing particles
    for _, particleSystem in ipairs(self.playerTracking.landingParticles) do
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(particleSystem.system, 0, 0)
    end

    -- Draw NPCs (behind or in front of player based on position)
    self:drawNPCs()

    -- Draw the player
    self.player:draw()

    -- Draw block placement preview
    if self.isPlacingBlock or self.isRemovingBlock then
        local worldX, worldY = self.camera:screenToWorld(self.mouseX, self.mouseY)
        local gridX = math.floor(worldX / self.world.tileSize) + 1
        local gridY = math.floor(worldY / self.world.tileSize) + 1
        local pixelX = (gridX - 1) * self.world.tileSize
        local pixelY = (gridY - 1) * self.world.tileSize

        if self.isPlacingBlock then
            -- Show preview of block to be placed
            local blockType = self.player.selectedBlockType
            local block = self.world.blocks[blockType]

            if self.world.blockQuads[blockType] then
                -- Draw semi-transparent sprite
                love.graphics.setColor(1, 1, 1, 0.5)

                -- Calculate scaling
                local scaleX = self.world.tileSize / self.world.tilesetSize
                local scaleY = self.world.tileSize / self.world.tilesetSize

                -- Draw the sprite
                love.graphics.draw(
                    self.world.spriteSheet,
                    self.world.blockQuads[blockType],
                    pixelX,
                    pixelY,
                    0,  -- rotation
                    scaleX,
                    scaleY
                )
            else
                -- Fallback to semi-transparent block
                love.graphics.setColor(block.color[1], block.color[2], block.color[3], 0.5)
                love.graphics.rectangle("fill", pixelX, pixelY, self.world.tileSize, self.world.tileSize)
            end

            -- Draw outline
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.rectangle("line", pixelX, pixelY, self.world.tileSize, self.world.tileSize)
        else
            -- Show removal indicator
            love.graphics.setColor(1, 0, 0, 0.3)
            love.graphics.rectangle("fill", pixelX, pixelY, self.world.tileSize, self.world.tileSize)

            -- Draw X
            love.graphics.setColor(1, 0, 0, 0.8)
            love.graphics.line(pixelX, pixelY, pixelX + self.world.tileSize, pixelY + self.world.tileSize)
            love.graphics.line(pixelX + self.world.tileSize, pixelY, pixelX, pixelY + self.world.tileSize)
        end
    end

    -- End camera transformation
    self.camera:unset()

    -- Draw the UI on top (fixed position, not affected by camera)
    self:drawUI()
end

-- Function to draw all NPCs
function Game:drawNPCs()
    for _, npc in ipairs(self.npcs) do
        -- Only draw NPCs that are visible on screen (optimization)
        if npc:isVisible(self.camera) then
            npc:draw()
        end
    end
end

function Game:drawUI()
    -- Draw the UI elements here
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Princess Builder - FPS: " .. love.timer.getFPS(), 10, 10)

    -- Draw current block type indicator (in bottom left)
    local blockType = self.player.selectedBlockType
    local block = self.world.blocks[blockType]
    local blockSize = 32
    local margin = 10
    local labelX = 10
    local labelY = self.height - blockSize - margin - 20

    -- Draw block preview
    love.graphics.setColor(1, 1, 1, 1)
    if self.world.blockQuads[blockType] then
        -- Calculate scaling to match display size
        local scaleX = blockSize / self.world.tilesetSize
        local scaleY = blockSize / self.world.tilesetSize

        -- Draw the sprite
        love.graphics.draw(
            self.world.spriteSheet,
            self.world.blockQuads[blockType],
            labelX,
            labelY + 20,
            0,  -- rotation
            scaleX,
            scaleY
        )
    else
        -- Fallback to colored rectangle
        love.graphics.setColor(block.color)
        love.graphics.rectangle("fill", labelX, labelY + 20, blockSize, blockSize)
    end

    -- Draw block outline
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("line", labelX, labelY + 20, blockSize, blockSize)

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)

    -- Draw controls help
    -- love.graphics.print("Mouse Wheel: Change Block Type", labelX + blockSize + margin, labelY)
    -- love.graphics.print("Left Click: Remove Block", labelX + blockSize + margin, labelY + 20)
    -- love.graphics.print("Right Click: Place Block", labelX + blockSize + margin, labelY + 40)

    -- Draw block selection hotbar at the bottom of the screen
    self:drawBlockHotbar()
end

function Game:drawBlockHotbar()
    local blockSize = 40
    local margin = 5
    local totalBlocks = #self.player.blockTypes
    local hotbarWidth = (blockSize + margin) * totalBlocks - margin
    local hotbarX = (self.width - hotbarWidth) / 2
    local hotbarY = self.height - blockSize - margin

    -- Draw background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", hotbarX - margin, hotbarY - margin,
                            hotbarWidth + margin * 2, blockSize + margin * 2, 5, 5)

    -- Draw each block in the hotbar
    for i, blockTypeId in ipairs(self.player.blockTypes) do
        local block = self.world.blocks[blockTypeId]
        local x = hotbarX + (i - 1) * (blockSize + margin)
        local y = hotbarY

        -- Draw the block
        love.graphics.setColor(1, 1, 1, 1)
        if self.world.blockQuads[blockTypeId] then
            -- Calculate scaling to match display size
            local scaleX = blockSize / self.world.tilesetSize
            local scaleY = blockSize / self.world.tilesetSize

            -- Draw the sprite
            love.graphics.draw(
                self.world.spriteSheet,
                self.world.blockQuads[blockTypeId],
                x,
                y,
                0,  -- rotation
                scaleX,
                scaleY
            )
        else
            -- Fallback to colored rectangle
            love.graphics.setColor(block.color)
            love.graphics.rectangle("fill", x, y, blockSize, blockSize)
        end

        -- Draw outline
        if self.player.blockTypeIndex == i then
            -- Highlight selected block
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x - 2, y - 2, blockSize + 4, blockSize + 4)
            love.graphics.setLineWidth(1)
        else
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle("line", x, y, blockSize, blockSize)
        end

        -- Draw block number (1-5)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(i, x + 5, y + 5)
    end

    -- Reset color and line width
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function Game:keypressed(key)
    if key == "escape" then
        self.paused = not self.paused
    end

    -- Number keys 1-5 for selecting block types
    local num = tonumber(key)
    if num and num >= 1 and num <= #self.player.blockTypes then
        self.player:selectBlockType(num)
    end

    if not self.paused then
        self.player:keypressed(key)
    end
end

function Game:keyreleased(key)
    if not self.paused then
        self.player:keyreleased(key)
    end
end

function Game:mousepressed(x, y, button)
    if not self.paused then
        -- Convert screen coordinates to world coordinates
        local worldX, worldY = self.camera:screenToWorld(x, y)

        -- Convert to grid coordinates for tracking
        local gridX = math.floor(worldX / self.world.tileSize) + 1
        local gridY = math.floor(worldY / self.world.tileSize) + 1

        -- Store the initial block coordinates
        self.lastBlockX = gridX
        self.lastBlockY = gridY

        -- Handle block placement/removal
        if button == 1 then -- Left click
            local blockType = self.world:getBlock(worldX, worldY)
            if blockType ~= World.BLOCK_AIR then
                -- Create a block removal particle effect before removing the block
                self:emitBlockBreakParticles(worldX, worldY, blockType)
                self.world:removeBlock(worldX, worldY)
            end
            self.isRemovingBlock = true
        elseif button == 2 then -- Right click
            local success = self.world:placeBlock(worldX, worldY, self.player.selectedBlockType)
            if success then
                -- Create a block placement particle effect after placing the block
                self:emitBlockPlaceParticles(worldX, worldY, self.player.selectedBlockType)
            end
            self.isPlacingBlock = true
        end

        -- Reset cooldown after initial placement
        self.blockPlacementCooldown = self.blockPlacementRate
    end
end

function Game:mousereleased(x, y, button)
    -- Handle mouse release events
    if button == 1 then -- Left click
        self.isRemovingBlock = false
    elseif button == 2 then -- Right click
        self.isPlacingBlock = false
    end
end

function Game:wheelmoved(x, y)
    -- Change selected block type
    if y > 0 then
        self.player:nextBlockType()
    elseif y < 0 then
        self.player:prevBlockType()
    end
end

-- Function to emit particles when a block is broken
function Game:emitBlockBreakParticles(worldX, worldY, blockType)
    -- Convert to pixel coordinates for the center of the block
    local pixelX = math.floor(worldX / self.world.tileSize) * self.world.tileSize + self.world.tileSize / 2
    local pixelY = math.floor(worldY / self.world.tileSize) * self.world.tileSize + self.world.tileSize / 2

    -- Clone the particle system for this specific block break
    local newParticleSystem = self.blockBreakParticles:clone()
    newParticleSystem:setPosition(pixelX, pixelY)

    -- Set color based on block type
    local blockInfo = self.world.blocks[blockType]
    if blockInfo then
        local r, g, b = unpack(blockInfo.color or {0.8, 0.8, 0.8})
        -- Set gradient of colors from full color to faded
        newParticleSystem:setColors(
            r, g, b, 1.0,    -- Initial color
            r, g, b, 0.8,    -- Mid-life
            r, g, b, 0.5,    -- Later
            r, g, b, 0.2,    -- Near end
            r, g, b, 0.0     -- End color (fade out)
        )
    else
        -- Default colors for unknown block types
        newParticleSystem:setColors(
            0.8, 0.8, 0.8, 1.0,
            0.8, 0.8, 0.8, 0.8,
            0.8, 0.8, 0.8, 0.5,
            0.8, 0.8, 0.8, 0.2,
            0.8, 0.8, 0.8, 0.0
        )
    end

    -- Emit a burst of particles
    newParticleSystem:emit(20 + math.random(10))

    -- Add to active particle systems with lifetime
    table.insert(self.activeBlockParticles, {
        system = newParticleSystem,
        timeRemaining = 1.0  -- 1 second lifetime
    })
end

-- Function to emit particles when a block is placed
function Game:emitBlockPlaceParticles(worldX, worldY, blockType)
    -- Convert to pixel coordinates for the center of the block
    local gridX = math.floor(worldX / self.world.tileSize) + 1
    local gridY = math.floor(worldY / self.world.tileSize) + 1
    local pixelX = (gridX - 1) * self.world.tileSize + self.world.tileSize / 2
    local pixelY = (gridY - 1) * self.world.tileSize + self.world.tileSize / 2

    -- Clone the particle system for this specific block placement
    local newParticleSystem = self.blockPlaceParticles:clone()

    -- Set color based on block type
    local blockInfo = self.world.blocks[blockType]
    if blockInfo then
        local r, g, b = unpack(blockInfo.color or {0.8, 0.8, 0.8})
        -- Set gradient of colors from faded to full color then faded
        newParticleSystem:setColors(
            r, g, b, 0.1,    -- Initial faded
            r, g, b, 0.8,    -- Near-peak opacity
            r*1.2, g*1.2, b*1.2, 0.9,  -- Peak brightness (slightly brighter)
            r, g, b, 0.6,    -- Post-peak
            r, g, b, 0.0     -- End color (fade out)
        )
    else
        -- Default colors for unknown block types
        newParticleSystem:setColors(
            1, 1, 1, 0.1,
            1, 1, 1, 0.7,
            1, 1, 1, 0.8,
            1, 1, 1, 0.4,
            1, 1, 1, 0.0
        )
    end

    -- Create particles around the edges of the block, not just center
    local halfSize = self.world.tileSize / 2
    for i = 1, 4 do -- Emit from 4 positions - N, E, S, W points
        local offsetX, offsetY

        if i == 1 then -- Top
            offsetX = 0
            offsetY = -halfSize + 2
        elseif i == 2 then -- Right
            offsetX = halfSize - 2
            offsetY = 0
        elseif i == 3 then -- Bottom
            offsetX = 0
            offsetY = halfSize - 2
        else -- Left
            offsetX = -halfSize + 2
            offsetY = 0
        end

        newParticleSystem:setPosition(pixelX + offsetX, pixelY + offsetY)

        -- Change direction based on side
        if i == 1 then -- Top edge
            newParticleSystem:setDirection(-math.pi/2) -- Up
            newParticleSystem:setSpread(math.pi/4)
        elseif i == 2 then -- Right edge
            newParticleSystem:setDirection(0) -- Right
            newParticleSystem:setSpread(math.pi/4)
        elseif i == 3 then -- Bottom edge
            newParticleSystem:setDirection(math.pi/2) -- Down
            newParticleSystem:setSpread(math.pi/4)
        else -- Left edge
            newParticleSystem:setDirection(math.pi) -- Left
            newParticleSystem:setSpread(math.pi/4)
        end

        -- Emit particles from this position
        newParticleSystem:emit(3 + math.random(2))
    end

    -- Also emit a small burst from the center for a "poof" effect
    newParticleSystem:setPosition(pixelX, pixelY)
    newParticleSystem:setDirection(0)
    newParticleSystem:setSpread(math.pi * 2) -- Full 360 degrees
    newParticleSystem:emit(6 + math.random(3))

    -- Add to active particle systems with lifetime
    table.insert(self.activePlaceParticles, {
        system = newParticleSystem,
        timeRemaining = 0.8  -- 0.8 second lifetime (shorter than break effect)
    })
end

-- Function to check if player just landed and create particles if needed
function Game:checkPlayerLanding(dt, wasInAir, prevVelocityY)
    -- Update air time tracking
    if not self.player.onGround then
        self.playerTracking.airTime = self.playerTracking.airTime + dt
        self.playerTracking.wasInAir = true
    else
        -- Check if player just landed this frame
        if self.playerTracking.wasInAir then
            -- Only emit particles if the player was falling
            if prevVelocityY > 50 then
                -- Calculate intensity based on fall speed and air time
                local intensity = math.min(1.0, (prevVelocityY / 400))
                local minParticles = 5
                local maxParticles = 30
                local particleCount = math.floor(minParticles + intensity * (maxParticles - minParticles))

                -- Emit landing particles
                self:emitLandingParticles(particleCount, intensity)
            end

            -- Reset air time
            self.playerTracking.airTime = 0
        end

        self.playerTracking.wasInAir = false
    end

    -- Store current vertical velocity for next frame
    self.playerTracking.prevVelocityY = self.player.vy
end

-- Function to emit particles when player lands
function Game:emitLandingParticles(count, intensity)
    -- Position at player's feet
    local particleX = self.player.x
    local particleY = self.player.y + self.player.height / 2 - 2

    -- Clone the particle system for this landing
    local newParticleSystem = self.landingParticles:clone()
    newParticleSystem:setPosition(particleX, particleY)

    -- Scale speeds based on landing intensity
    local baseSpeed = {newParticleSystem:getSpeed()}
    local scaledMinSpeed = baseSpeed[1] * (0.7 + intensity * 0.6)
    local scaledMaxSpeed = baseSpeed[2] * (0.7 + intensity * 0.6)
    newParticleSystem:setSpeed(scaledMinSpeed, scaledMaxSpeed)

    -- Add a ground impact "burst" effect going left and right
    -- Left side burst
    newParticleSystem:setDirection(math.pi)  -- Left
    newParticleSystem:emit(math.floor(count / 2))

    -- Right side burst
    newParticleSystem:setDirection(0)  -- Right
    newParticleSystem:emit(math.floor(count / 2))

    -- Add some vertical particles too for a more dynamic effect
    local lowIntensityCount = math.floor(count / 4)
    if intensity > 0.5 and lowIntensityCount > 0 then
        newParticleSystem:setDirection(-math.pi/2)  -- Upward
        newParticleSystem:setSpread(math.pi/4)  -- Narrower spread
        newParticleSystem:emit(lowIntensityCount)
    end

    -- Reset spread for future emissions
    newParticleSystem:setSpread(math.pi * 0.7)

    -- Add to active particle systems
    table.insert(self.playerTracking.landingParticles, {
        system = newParticleSystem,
        timeRemaining = 1.0  -- 1 second lifetime for landing particles
    })
end

return Game