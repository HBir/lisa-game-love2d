-- GridSystem.lua - Manages the block grid operations
local GridSystem = {}
GridSystem.__index = GridSystem

function GridSystem:new(width, height, blockRegistry)
    local self = setmetatable({}, GridSystem)

    self.width = width
    self.height = height
    self.blockRegistry = blockRegistry

    -- Initialize grid layers
    -- Foreground layer: for solid blocks (main gameplay elements)
    self.foregroundGrid = {}
    -- Background layer: for non-solid decorative blocks
    self.backgroundGrid = {}

    -- Initialize grids with air blocks
    for y = 1, height do
        self.foregroundGrid[y] = {}
        self.backgroundGrid[y] = {}
        for x = 1, width do
            self.foregroundGrid[y][x] = blockRegistry.BLOCK_AIR
            self.backgroundGrid[y][x] = blockRegistry.BLOCK_AIR
        end
    end

    return self
end

-- Get block at world coordinates
function GridSystem:getBlock(x, y, layer)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x) + 1
    local gridY = math.floor(y) + 1

    return self:getBlockAt(gridX, gridY, layer)
end

-- Get block directly at grid coordinates
function GridSystem:getBlockAt(gridX, gridY, layer)
    -- Direct grid access with bounds checking
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        if layer == "background" then
            return self.backgroundGrid[gridY][gridX]
        else
            return self.foregroundGrid[gridY][gridX]
        end
    end
    return self.blockRegistry.BLOCK_AIR
end

-- Set block at grid coordinates
function GridSystem:setBlock(x, y, blockType)
    -- Convert to grid indices
    local gridX = math.floor(x)
    local gridY = math.floor(y)

    -- Check if in bounds
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        -- Determine which layer to use based on block solidity
        if not self.blockRegistry:isSolid(blockType) then
            self.backgroundGrid[gridY][gridX] = blockType
        else
            self.foregroundGrid[gridY][gridX] = blockType
        end
        return true
    end

    return false
end

-- Place block at world coordinates
function GridSystem:placeBlock(x, y, blockType, tileSize)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x / tileSize) + 1
    local gridY = math.floor(y / tileSize) + 1

    -- Check if in bounds
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        -- Special case for background air - explicitly removes background blocks
        if not self.blockRegistry:isSolid(blockType) then
            -- Non-solid blocks go to background layer
            -- Can place regardless of what's in foreground
            self.backgroundGrid[gridY][gridX] = blockType
            return true
        else
            -- Solid blocks go to foreground layer
            -- Can only place if the spot is empty (air)
            if self.foregroundGrid[gridY][gridX] == self.blockRegistry.BLOCK_AIR then
                self.foregroundGrid[gridY][gridX] = blockType
                return true
            end
        end
    end

    return false
end

-- Remove block at world coordinates
function GridSystem:removeBlock(x, y, targetLayer, tileSize)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x / tileSize) + 1
    local gridY = math.floor(y / tileSize) + 1

    -- Check if in bounds
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        -- If a specific layer is targeted, only remove from that layer
        if targetLayer == "background" then
            if self.backgroundGrid[gridY][gridX] ~= self.blockRegistry.BLOCK_AIR then
                self.backgroundGrid[gridY][gridX] = self.blockRegistry.BLOCK_AIR
                return true
            end
        elseif targetLayer == "foreground" then
            if self.foregroundGrid[gridY][gridX] ~= self.blockRegistry.BLOCK_AIR then
                self.foregroundGrid[gridY][gridX] = self.blockRegistry.BLOCK_AIR
                return true
            end
        else
            -- Default behavior (no layer specified): try foreground first, then background
            if self.foregroundGrid[gridY][gridX] ~= self.blockRegistry.BLOCK_AIR then
                self.foregroundGrid[gridY][gridX] = self.blockRegistry.BLOCK_AIR
                return true
            -- Then try to remove from background if it's not air
            elseif self.backgroundGrid[gridY][gridX] ~= self.blockRegistry.BLOCK_AIR then
                self.backgroundGrid[gridY][gridX] = self.blockRegistry.BLOCK_AIR
                return true
            end
        end
    end

    return false
end

-- Check if a position is solid
function GridSystem:isSolid(x, y, tileSize, movingDown, passThroughPlatforms)
    -- Only check foreground layer for solidity
    local blockType = self:getBlock(x / tileSize, y / tileSize, "foreground")

    -- Check if it's a platform
    if self.blockRegistry:isPlatform(blockType) then
        -- If we're explicitly passing through platforms (pressing down while on a platform)
        if passThroughPlatforms then
            return false
        end

        -- If moving up (jumping), allow passing through platforms from below
        if not movingDown then
            return false
        end

        -- For horizontal movement, we need more context. We'll use a heuristic:
        -- If the check position is near the middle of the entity, it's likely a horizontal check,
        -- and we should allow passing through the platform
        local gridY = math.floor(y / tileSize)
        local posY = y / tileSize
        local isMidLevel = math.abs(posY - (gridY + 0.5)) < 0.35

        -- If we're checking the middle part of an entity, it's likely a horizontal movement check
        if isMidLevel then
            return false
        end

        -- In all other cases (falling down onto the platform), treat as solid
        return true
    end

    -- Regular solidity check for non-platform blocks
    return self.blockRegistry:isSolid(blockType)
end

-- Clear the grid and set all blocks to air
function GridSystem:clear()
    for y = 1, self.height do
        for x = 1, self.width do
            self.foregroundGrid[y][x] = self.blockRegistry.BLOCK_AIR
            self.backgroundGrid[y][x] = self.blockRegistry.BLOCK_AIR
        end
    end
end

-- Serialize the grid for saving
function GridSystem:serialize()
    return {
        width = self.width,
        height = self.height,
        foregroundGrid = self.foregroundGrid,
        backgroundGrid = self.backgroundGrid
    }
end

-- Deserialize and load grid data
function GridSystem:deserialize(data)
    if data then
        self.width = data.width
        self.height = data.height
        self.foregroundGrid = data.foregroundGrid
        self.backgroundGrid = data.backgroundGrid
    end
end

return GridSystem