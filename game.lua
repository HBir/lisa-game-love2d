-- Game class that manages the overall game state
local Camera = require("camera")
local World = require("world")
local Player = require("player")

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

    -- Initialize the camera
    self.camera = Camera:new(self.width, self.height, 1) -- Use scale factor of 1 instead of world.tileSize
    self.camera:follow(self.player)

    -- Game state
    self.paused = false
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
    self.dustParticles:setParticleLifetime(0.5, 1.2)  -- Longer lifetime for larger particles
    self.dustParticles:setEmissionRate(0)  -- Start with no emission, will be set dynamically
    self.dustParticles:setSizeVariation(0.6) -- More size variation (60%)
    -- Larger initial sizes and more gradual shrinking
    self.dustParticles:setSizes(1.5, 1.2, 0.9, 0.5)  -- Particles start larger and shrink as they age
    self.dustParticles:setColors(
        0.95, 0.95, 0.9, 0.8,  -- Initial color (more opaque)
        0.9, 0.9, 0.85, 0.6,   -- Mid-life color
        0.85, 0.85, 0.8, 0.4,  -- Later color
        0.8, 0.8, 0.75, 0      -- End color (fade out)
    )
    self.dustParticles:setPosition(0, 0)  -- Will be updated based on player position
    self.dustParticles:setLinearDamping(0.4) -- Slightly less damping for larger particles
    self.dustParticles:setSpeed(8, 25)     -- Slightly reduced speed for larger particles
    self.dustParticles:setLinearAcceleration(0, -25, 0, -12)  -- Adjusted for larger particle weight
    self.dustParticles:setSpread(math.pi/5)  -- Slightly wider spread (36 degrees) for larger particles
    self.dustParticles:setRelativeRotation(true)

    -- Variables to control dust emission
    self.lastPlayerX = 0
    self.lastPlayerY = 0
    self.dustEmitTimer = 0
    self.burstEmitTimer = 0  -- Timer for larger, less frequent bursts
end

function Game:update(dt)
    if self.paused then
        return
    end

    -- Update the player
    self.player:update(dt)

    -- Update the camera to follow the player
    self.camera:update(dt)

    -- Update dust particles
    self:updateDustParticles(dt)

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
                self.world:removeBlock(worldX, worldY)
            elseif self.isPlacingBlock then
                self.world:placeBlock(worldX, worldY, self.player.selectedBlockType)
            end

            -- Update the last block coordinates
            self.lastBlockX = gridX
            self.lastBlockY = gridY

            -- Set cooldown to prevent too frequent block operations
            self.blockPlacementCooldown = self.blockPlacementRate
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

        -- Offset particles behind the player based on facing direction
        if self.player.facing == "right" then
            particleX = particleX - 10  -- Increased offset for larger particles
            -- Direction slightly more upward when facing right (left and up)
            self.dustParticles:setDirection(math.pi * 0.6)  -- More upward component
        else
            particleX = particleX + 10  -- Increased offset for larger particles
            -- Direction slightly more upward when facing left (right and up)
            self.dustParticles:setDirection(math.pi * 0.4)  -- More upward component
        end

        -- Position the emitter
        self.dustParticles:setPosition(particleX, particleY)

        -- Control emission rate based on horizontal speed but at lower rate
        local speedFactor = math.abs(self.player.vx) / self.player.speed
        self.dustParticles:setEmissionRate(12 * speedFactor)  -- Reduced emission rate (was 25)

        -- Emit a larger burst when direction changes or player starts moving
        if (self.lastPlayerX == 0 or (self.player.vx > 0 and self.lastPlayerX < 0) or
            (self.player.vx < 0 and self.lastPlayerX > 0)) then
            self.dustParticles:emit(5)  -- Slightly reduced burst (was 8)
        end

        -- Add less frequent but larger bursts for more dynamic effect
        self.dustEmitTimer = self.dustEmitTimer + dt
        if self.dustEmitTimer > 0.4 then  -- Less frequent (was 0.2 seconds)
            self.dustParticles:emit(2)  -- Fewer particles per burst (was 3)
            self.dustEmitTimer = 0
        end

        -- Occasional larger puffs of dust
        self.burstEmitTimer = self.burstEmitTimer + dt
        if self.burstEmitTimer > 1.2 then  -- Every 1.2 seconds
            -- Set temporary larger size for next few particles
            local originalSizes = {self.dustParticles:getSizes()}
            self.dustParticles:setSizes(2.2, 1.8, 1.4, 0.8)  -- Temporarily larger
            self.dustParticles:emit(3)  -- Emit a few big particles
            self.dustParticles:setSizes(unpack(originalSizes))  -- Restore original sizes
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

    -- Draw label
    love.graphics.print("Selected Block: " .. block.name, labelX, labelY)

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
    love.graphics.print("Mouse Wheel: Change Block Type", labelX + blockSize + margin, labelY)
    love.graphics.print("Left Click: Remove Block", labelX + blockSize + margin, labelY + 20)
    love.graphics.print("Right Click: Place Block", labelX + blockSize + margin, labelY + 40)

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
            self.world:removeBlock(worldX, worldY)
            self.isRemovingBlock = true
        elseif button == 2 then -- Right click
            self.world:placeBlock(worldX, worldY, self.player.selectedBlockType)
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

return Game