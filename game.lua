-- Game class that manages the overall game state
local Camera = require("camera")
local World = require("world")
local Player = require("player")
local Chicken = require("npc.chicken")  -- Import the chicken NPC
local Inputs = require("Inputs")  -- Import the new inputs module
local ParticleSystem = require("ParticleSystem")
local Game = {}
Game.__index = Game

function Game:new()
    local self = setmetatable({}, Game)

    -- Game settings
    self.title = "Lisa's Game"
    self.width = 800
    self.height = 600

    -- NPC management
    self.npcs = {}  -- Table to store all NPCs

    -- Debug options
    self.showSpriteDebug = false

    return self
end

function Game:initParticleSystems()
    print("Initializing particle systems")
    self.particles = ParticleSystem:new()
    print("Particle systems initialized:", self.particles)

    -- Set world reference in the particle system
    self.particles:setWorld(self.world)
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

    -- Initialize particle systems after player is created
    self:initParticleSystems()
    print("After initParticleSystems, self.particles:", self.particles)

    -- Set player reference in the particle system
    self.particles:setPlayer(self.player)

    -- Initialize the camera
    self.camera = Camera:new(self.width, self.height, 1) -- Use scale factor of 1 instead of world.tileSize
    self.camera:follow(self.player)

    -- Create some chickens in the world
    self:spawnInitialNPCs()

    -- Initialize inputs system
    self.inputs = Inputs:new(self)

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
    self.particles:UpdateAllParticles(dt)


    -- Update save message
    self:updateSaveMessage(dt)

    -- Update inputs
    self.inputs:update(dt)
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
    love.graphics.draw(self.particles.dustParticles, 0, 0)

    -- Draw block break particles
    for _, particleSystem in ipairs(self.particles.activeBlockParticles) do
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(particleSystem.system, 0, 0)
    end

    -- Draw block place particles
    for _, particleSystem in ipairs(self.particles.activePlaceParticles) do
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(particleSystem.system, 0, 0)
    end

    -- Draw landing particles
    for _, particleSystem in ipairs(self.particles.playerTracking.landingParticles) do
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(particleSystem.system, 0, 0)
    end

    -- Draw firework particles
    for _, firework in ipairs(self.particles.fireworkParticles) do
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(firework.system, 0, 0)
    end

    -- Draw NPCs (behind or in front of player based on position)
    self:drawNPCs()

    -- Draw the player
    self.player:draw()

    -- Draw block placement preview
    self:drawBlockPlacementPreview()

    -- End camera transformation
    self.camera:unset()

    -- Draw the UI on top (fixed position, not affected by camera)
    self:drawUI()

    -- Draw LISA sequence progress
    self:drawLisaProgress()

    -- Draw sprite debug view if enabled (should be on top of everything)
    if self.showSpriteDebug then
        self:drawSpriteDebug()
    end
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

    -- Draw current block type indicator (in bottom left)
    local blockType = self.player.selectedBlockType
    local block = self.world.blocks[blockType]
    local blockSize = 32
    local margin = 10
    local labelX = 10
    local labelY = self.height - blockSize - margin - 20

    -- Draw save/load message if present
    if self.saveMessage then
        -- Position message at top center of screen
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(self.saveMessage.text)
        local x = (self.width - textWidth) / 2
        local y = 40

        -- Draw a semi-transparent background for better readability
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", x - 10, y - 5, textWidth + 20, 30)

        -- Draw the message text
        love.graphics.setColor(self.saveMessage.color)
        love.graphics.print(self.saveMessage.text, x, y)

        -- Reset color
        love.graphics.setColor(1, 1, 1, 1)
    end

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

    -- Draw controls help
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("F5: Save World  |  F9: Load World", self.width - 250, 10)

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

function Game:drawLisaProgress()
    -- Only display the progress if the sequence has been started (at least "L" pressed)
    if self.particles.lisaSequence.displayTimer > 0 and self.particles.lisaSequence.currentIndex > 0 then
        local sequence = "LISA"
        local font = love.graphics.getFont()
        local letterSpacing = 40  -- Increased from 30 to 40 for more space between letters
        local totalWidth = letterSpacing * (#sequence - 1) + font:getWidth(sequence) * 2  -- Adjusted for larger letters
        local x = (self.width - totalWidth) / 2
        local y = 470

        -- Draw a semi-transparent background for better visibility
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", x - 20, y - 10, totalWidth, 60, 10, 10)

        for i = 1, #sequence do
            local letter = sequence:sub(i, i)
            local letterX = x + (i - 1) * letterSpacing

            if i <= self.particles.lisaSequence.currentIndex then
                -- Draw completed letters in bright yellow (more visible than green)
                love.graphics.setColor(1, 0.9, 0.2, 1)  -- Bright yellow

                -- Add glow effect for completed letters
                love.graphics.setColor(1, 0.9, 0.2, 0.3)  -- Transparent yellow for glow
                love.graphics.circle("fill", letterX + font:getWidth(letter), y + 15, 20)

                -- Draw the actual letter
                love.graphics.setColor(1, 0.9, 0.2, 1)  -- Bright yellow
            else
                -- Draw pending letters in white/silver (more visible than gray)
                love.graphics.setColor(0.9, 0.9, 1, 0.8)  -- Bright silver/white
            end

            -- Draw letter with larger scaling (increased from 1.5/1.0 to 2.0/1.5)
            local scale = i <= self.particles.lisaSequence.currentIndex and 2.0 or 1.5
            love.graphics.print(letter, letterX, y, 0, scale, scale)

            -- Draw a subtle outline for better contrast against any background
            if i <= self.particles.lisaSequence.currentIndex then
                love.graphics.setColor(0.5, 0.5, 0, 0.5)  -- Dark yellow outline
            else
                love.graphics.setColor(0.1, 0.1, 0.2, 0.5)  -- Dark blue/black outline
            end
            love.graphics.setLineWidth(2)
            love.graphics.print(letter, letterX + 1, y + 1, 0, scale, scale)
            love.graphics.setLineWidth(1)
        end

        -- Reset color
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Drawing the block placement preview
function Game:drawBlockPlacementPreview()
    if self.inputs.isPlacingBlock or self.inputs.isRemovingBlock then
        local worldX, worldY = self.camera:screenToWorld(self.inputs.mouseX, self.inputs.mouseY)
        local gridX = math.floor(worldX / self.world.tileSize) + 1
        local gridY = math.floor(worldY / self.world.tileSize) + 1
        local pixelX = (gridX - 1) * self.world.tileSize
        local pixelY = (gridY - 1) * self.world.tileSize

        if self.inputs.isPlacingBlock then
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
end

-- Forward input events to the inputs module
function Game:keypressed(key)
    self.inputs:keypressed(key)
end

function Game:keyreleased(key)
    self.inputs:keyreleased(key)
end

function Game:mousepressed(x, y, button)
    self.inputs:mousepressed(x, y, button)
end

function Game:mousereleased(x, y, button)
    self.inputs:mousereleased(x, y, button)
end

function Game:wheelmoved(x, y)
    self.inputs:wheelmoved(x, y)
end

-- Function to emit particles when a block is broken
function Game:emitBlockBreakParticles(worldX, worldY, blockType)
    self.particles:emitBlockBreakParticles(worldX, worldY, blockType)
end

-- Function to emit particles when a block is placed
function Game:emitBlockPlaceParticles(worldX, worldY, blockType)
    self.particles:emitBlockPlaceParticles(worldX, worldY, blockType)
end

-- Function to check if player just landed and create particles if needed
function Game:checkPlayerLanding(dt, wasInAir, prevVelocityY)
    -- Update air time tracking
    if not self.player.onGround then
        self.particles.playerTracking.airTime = self.particles.playerTracking.airTime + dt
        self.particles.playerTracking.wasInAir = true
    else
        -- Check if player just landed this frame
        if self.particles.playerTracking.wasInAir then
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
            self.particles.playerTracking.airTime = 0
        end

        self.particles.playerTracking.wasInAir = false
    end

    -- Store current vertical velocity for next frame
    self.particles.playerTracking.prevVelocityY = self.player.vy
end

-- Function to emit particles when player lands
function Game:emitLandingParticles(count, intensity)
    -- Call the particle system to emit landing particles
    self.particles:emitLandingParticles(self.player.x, self.player.y + self.player.height / 2 - 2, count, intensity)
end

-- Save the current world state to a file
function Game:saveWorld()
    -- Create a saves directory if it doesn't exist
    os.execute("mkdir -p saves")

    -- Generate a filename based on current date and time
    local filename = "saves/world_" .. os.date("%Y%m%d_%H%M%S") .. ".sav"

    -- Save the world
    local success = self.world:saveWorld(filename)

    -- Show a message to the player
    if success then
        print("World saved to " .. filename)
        self.saveMessage = {
            text = "World saved!",
            timer = 3, -- Display for 3 seconds
            color = {0, 1, 0, 1} -- Green color
        }
    else
        print("Failed to save world.")
        self.saveMessage = {
            text = "Save failed!",
            timer = 3,
            color = {1, 0, 0, 1} -- Red color
        }
    end
end

-- Load a world from the most recent save file
function Game:loadWorld()
    -- Get a list of save files
    local saveFiles = {}
    local dir = io.popen('ls -1 saves/*.sav 2>/dev/null')
    if dir then
        for file in dir:lines() do
            table.insert(saveFiles, file)
        end
        dir:close()
    end

    -- If no save files found
    if #saveFiles == 0 then
        print("No save files found.")
        self.saveMessage = {
            text = "No save files found!",
            timer = 3,
            color = {1, 0.5, 0, 1} -- Orange color
        }
        return
    end

    -- Sort files by name (assuming yyyy-mm-dd_hhmmss format, this will sort by date)
    table.sort(saveFiles)

    -- Get the most recent save file (last in the sorted list)
    local filename = saveFiles[#saveFiles]

    -- Load the world
    local success = self.world:loadWorld(filename)

    -- Show a message to the player
    if success then
        print("World loaded from " .. filename)
        self.saveMessage = {
            text = "World loaded!",
            timer = 3,
            color = {0, 1, 0, 1} -- Green color
        }
    else
        print("Failed to load world from " .. filename)
        self.saveMessage = {
            text = "Load failed!",
            timer = 3,
            color = {1, 0, 0, 1} -- Red color
        }
    end
end

-- Update the save message timer
function Game:updateSaveMessage(dt)
    if self.saveMessage then
        self.saveMessage.timer = self.saveMessage.timer - dt
        if self.saveMessage.timer <= 0 then
            self.saveMessage = nil
        end
    end
end

-- Check if the key is part of the LISA sequence
function Game:checkLisaSequence(key)
    local nextExpectedKey = self.particles.lisaSequence.pattern[self.particles.lisaSequence.currentIndex + 1]

    -- If the key matches the next expected key in the sequence
    if key == nextExpectedKey then
        -- Increment the index
        self.particles.lisaSequence.currentIndex = self.particles.lisaSequence.currentIndex + 1

        -- Reset the display timer
        self.particles.lisaSequence.displayTimer = 3

        -- If completed the sequence
        if self.particles.lisaSequence.currentIndex == #self.particles.lisaSequence.pattern then
            -- Launch firework
            self:launchFirework()

            -- Set a longer display time (4 seconds instead of 3) for the completed sequence
            self.particles.lisaSequence.displayTimer = 4

            -- LISA sequence stays visible, but will be reset for next input
            -- We don't reset the currentIndex to 0 immediately, this will be done after timer expires
        end
    elseif key == self.particles.lisaSequence.pattern[1] then
        -- If it's the first key in the sequence, start the sequence
        self.particles.lisaSequence.currentIndex = 1
        self.particles.lisaSequence.displayTimer = 3
    else
        -- Wrong key, reset the sequence only if we had started the sequence
        if self.particles.lisaSequence.currentIndex > 0 then
            self.particles.lisaSequence.currentIndex = 0
            -- Keep the display up briefly to show the reset
            self.particles.lisaSequence.displayTimer = 1
        end
    end
end

-- Launch a firework from the player's position
function Game:launchFirework()
    -- Call the particle system to launch a firework from the player's position
    self.particles:launchFirework(self.player.x, self.player.y - self.player.height/2)
end

-- Get random colors for the firework explosion
function Game:getRandomExplosionColors()
    return self.particles:getRandomExplosionColors()
end

-- Create an explosion effect at the specified position
function Game:createExplosion(x, y, colors)
    self.particles:createExplosion(x, y, colors)
end

-- Function to draw the sprite debug view
function Game:drawSpriteDebug()
    -- Get the sprite sheet and tilesize from the block registry
    local spriteSheet = self.world.blockRegistry.spriteSheet
    local tileSize = self.world.blockRegistry.tilesetSize

    -- Calculate how many sprites fit per row based on window width
    local columns = math.floor(self.width / (tileSize * 4))
    local spacing = 5 -- Space between sprites horizontally
    local verticalSpacing = 35 -- Increased vertical spacing to make room for text
    local scale = 3 -- Scale up sprites for better visibility

    -- Draw semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, self.width, self.height)

    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("SPRITE DEBUG VIEW (Press X to exit)", 10, 10)

    -- Get the sprite mappings
    local sprites = self.world.blockRegistry.sprites
    local sortedKeys = {}

    -- Collect and sort sprite keys for organized display
    for key, _ in pairs(sprites) do
        table.insert(sortedKeys, key)
    end

    -- Custom sort function to handle both string and numeric keys
    table.sort(sortedKeys, function(a, b)
        local typeA, typeB = type(a), type(b)

        -- If both keys are the same type, compare directly
        if typeA == typeB then
            if typeA == "number" then
                return a < b
            else
                return tostring(a) < tostring(b)
            end
        else
            -- If different types, numbers come first
            return typeA == "number"
        end
    end)

    -- Draw each sprite
    local row = 0
    local col = 0
    local startY = 50 -- Start below the title, increased for better spacing

    for i, key in ipairs(sortedKeys) do
        local sprite = sprites[key]
        local x = 10 + col * (tileSize * scale + spacing)
        local y = startY + row * (tileSize * scale + verticalSpacing)

        -- Draw sprite if valid
        if sprite and sprite.x and sprite.y then
            -- Create a quad for this sprite
            local quad = love.graphics.newQuad(
                sprite.x * tileSize,
                sprite.y * tileSize,
                tileSize,
                tileSize,
                spriteSheet:getDimensions()
            )

            -- Draw sprite
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(spriteSheet, quad, x, y, 0, scale, scale)

            -- Draw sprite info
            local spriteKey = tostring(key)
            if type(key) == "number" then
                -- For block types, show the block name
                local block = self.world.blockRegistry:getBlock(key)
                if block then
                    spriteKey = block.name
                end
            end

            -- Draw text with dark background for better readability
            local textWidth = spriteKey:len() * 6 -- Approximate width
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", x, y + tileSize * scale + 2, textWidth, 14)

            -- Draw the text
            love.graphics.setColor(1, 1, 0.5, 1)
            love.graphics.print(spriteKey, x, y + tileSize * scale + 2, 0, 0.8, 0.8)
        end

        -- Move to next column or row
        col = col + 1
        if col >= columns then
            col = 0
            row = row + 1
        end
    end
end

return Game