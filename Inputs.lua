-- Inputs module for handling all input-related functionality
local Inputs = {}
Inputs.__index = Inputs

-- Initialize a new Inputs instance
function Inputs:new(game)
    local self = setmetatable({}, Inputs)
    self.game = game

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

-- Update input state
function Inputs:update(dt)
    -- Update mouse position
    self.mouseX, self.mouseY = love.mouse.getPosition()

    -- Update block placement cooldown
    if self.blockPlacementCooldown > 0 then
        self.blockPlacementCooldown = self.blockPlacementCooldown - dt
    end

    -- Handle continuous block placement/removal when mouse is held down
    if (self.isPlacingBlock or self.isRemovingBlock) and self.blockPlacementCooldown <= 0 then
        self:handleBlockInteraction()
    end
end

-- Handle block interaction (placing or removing)
function Inputs:handleBlockInteraction()
    local camera = self.game.camera
    local world = self.game.world

    -- Convert screen coordinates to world coordinates
    local worldX, worldY = camera:screenToWorld(self.mouseX, self.mouseY)

    -- Convert to grid coordinates
    local gridX = math.floor(worldX / world.tileSize) + 1
    local gridY = math.floor(worldY / world.tileSize) + 1

    -- Check if this is a different block than the last one we interacted with
    if gridX ~= self.lastBlockX or gridY ~= self.lastBlockY then
        if self.isRemovingBlock then
            local blockType = world:getBlock(worldX, worldY)
            if blockType ~= world.blockRegistry.BLOCK_AIR then
                -- Create a block removal particle effect before removing the block
                self.game:emitBlockBreakParticles(worldX, worldY, blockType)
                world:removeBlock(worldX, worldY)
            end
        elseif self.isPlacingBlock then
            local success = world:placeBlock(worldX, worldY, self.game.player.selectedBlockType)
            if success then
                -- Create a block placement particle effect after placing the block
                self.game:emitBlockPlaceParticles(worldX, worldY, self.game.player.selectedBlockType)
            end
        end

        -- Update the last block coordinates
        self.lastBlockX = gridX
        self.lastBlockY = gridY

        -- Set cooldown to prevent too frequent block operations
        self.blockPlacementCooldown = self.blockPlacementRate
    end
end

-- Handle key press events
function Inputs:keypressed(key)
    local game = self.game

    if key == "escape" then
        game.paused = not game.paused
    end

    -- Save world with F5
    if key == "f5" then
        game:saveWorld()
    end

    -- Load world with F9
    if key == "f9" then
        game:loadWorld()
    end

    -- Toggle sprite debug view with X
    if key == "x" then
        -- Cycle through debug pages: 0 (off) -> 1 (sprite page 1) -> 2 (sprite page 2) -> 3 (game stats) -> 0 (off)
        game.debugPage = (game.debugPage + 1) % 4
        -- For backward compatibility
        game.showSpriteDebug = game.debugPage > 0
    end

    -- Check for LISA sequence
    game:checkLisaSequence(key)

    -- Number keys 1-5 for selecting block types
    local num = tonumber(key)
    if num and num >= 1 and num <= #game.player.blockTypes then
        game.player:selectBlockType(num)
    end

    if not game.paused then
        game.player:keypressed(key)
    end
end

-- Handle key release events
function Inputs:keyreleased(key)
    if not self.game.paused then
        self.game.player:keyreleased(key)
    end
end

-- Handle mouse press events
function Inputs:mousepressed(x, y, button)
    local game = self.game

    -- Check for pause menu interaction if game is paused
    if game.paused and button == 1 then -- Left click on pause menu
        if game.ui:handlePauseMenuClick(x, y) then
            return -- Click handled by the menu
        end
    end

    if not game.paused then
        -- Convert screen coordinates to world coordinates
        local worldX, worldY = game.camera:screenToWorld(x, y)

        -- Convert to grid coordinates for tracking
        local gridX = math.floor(worldX / game.world.tileSize) + 1
        local gridY = math.floor(worldY / game.world.tileSize) + 1

        -- Store the initial block coordinates
        self.lastBlockX = gridX
        self.lastBlockY = gridY

        -- Handle block placement/removal
        if button == 1 then -- Left click
            local blockType = game.world:getBlock(worldX, worldY)
            if blockType ~= game.world.blockRegistry.BLOCK_AIR then
                -- Create a block removal particle effect before removing the block
                game:emitBlockBreakParticles(worldX, worldY, blockType)
                game.world:removeBlock(worldX, worldY)
            end
            self.isRemovingBlock = true
        elseif button == 2 then -- Right click
            local success = game.world:placeBlock(worldX, worldY, game.player.selectedBlockType)
            if success then
                -- Create a block placement particle effect after placing the block
                game:emitBlockPlaceParticles(worldX, worldY, game.player.selectedBlockType)
            end
            self.isPlacingBlock = true
        end

        -- Reset cooldown after initial placement
        self.blockPlacementCooldown = self.blockPlacementRate
    end
end

-- Handle mouse release events
function Inputs:mousereleased(x, y, button)
    -- Handle mouse release events
    if button == 1 then -- Left click
        self.isRemovingBlock = false
    elseif button == 2 then -- Right click
        self.isPlacingBlock = false
    end
end

-- Handle mouse wheel movement
function Inputs:wheelmoved(x, y)
    -- Change selected block type
    if y > 0 then
        self.game.player:nextBlockType()
    elseif y < 0 then
        self.game.player:prevBlockType()
    end
end

return Inputs
