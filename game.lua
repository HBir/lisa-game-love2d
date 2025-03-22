-- Game class that manages the overall game state
local Camera = require("camera")
local World = require("world.world")
local Player = require("player")
local Chicken = require("npc.chicken")  -- Import the chicken NPC
local Inputs = require("Inputs")  -- Import the new inputs module
local ParticleSystem = require("ParticleSystem")
local UI = require("UI.UI")  -- Import the new UI module
local Game = {}

Game.__index = Game

function Game:new()
    local self = setmetatable({}, Game)

    -- Game settings
    self.title = "Lisa's Game"
    local _, _, flags = love.window.getMode()
    local window_width, window_height = love.window.getDesktopDimensions(flags.display)
    self.width = window_width
    self.height = window_height-100

    -- NPC management
    self.npcs = {}  -- Table to store all NPCs

    -- Debug options
    self.showSpriteDebug = false
    self.debugPage = 0  -- Track which debug page is displayed (0 = off, 1 = page 1, 2 = page 2)

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
        resizable = false,
        vsync = true,
        minwidth = 800,
        minheight = 600
    })

    -- love.graphics.setDefaultFilter("nearest", "nearest")
    -- love.graphics.setLineStyle("smooth")

    -- Load background image
    self.backgroundImage = love.graphics.newImage("assets/Tiles/Background_2.png")

    -- Initialize the world
    self.world = World:new(256, 256, 14) -- width, height, tile size
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

    -- Initialize UI system
    self.ui = UI:new(self)

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
        if self.world:isSolid(x, worldY, true, false) then
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
    self.ui:updateSaveMessage(dt)

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
    self.ui:drawBlockPlacementPreview()

    -- End camera transformation
    self.camera:unset()

    -- Draw the UI on top (fixed position, not affected by camera)
    self.ui:drawUI()

    -- Draw LISA sequence progress
    self.ui:drawLisaProgress()

    -- Draw sprite debug view if enabled (should be on top of everything)
    if self.debugPage > 0 then
        self.ui:drawDebugMenu(self.debugPage)
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
        self.ui:setSaveMessage("World saved!", {0, 1, 0, 1}, 3) -- Green color, 3 seconds
    else
        print("Failed to save world.")
        self.ui:setSaveMessage("Save failed!", {1, 0, 0, 1}, 3) -- Red color, 3 seconds
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
        self.ui:setSaveMessage("No save files found!", {1, 0.5, 0, 1}, 3) -- Orange color, 3 seconds
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
        self.ui:setSaveMessage("World loaded!", {0, 1, 0, 1}, 3) -- Green color, 3 seconds
    else
        print("Failed to load world from " .. filename)
        self.ui:setSaveMessage("Load failed!", {1, 0, 0, 1}, 3) -- Red color, 3 seconds
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

return Game