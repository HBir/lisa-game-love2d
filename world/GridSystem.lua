-- GridSystem.lua - Manages the block grid operations
local GridSystem = {}
GridSystem.__index = GridSystem

function GridSystem:new(width, height, blockRegistry, furnitureRegistry)
    local self = setmetatable({}, GridSystem)

    self.width = width
    self.height = height
    self.blockRegistry = blockRegistry
    self.furnitureRegistry = furnitureRegistry

    -- Initialize grid layers
    -- Foreground layer: for solid blocks (main gameplay elements)
    self.foregroundGrid = {}
    -- Background layer: for non-solid decorative blocks
    self.backgroundGrid = {}
    -- Furniture layer: for furniture placement
    self.furnitureGrid = {}
    -- Furniture state layer: for storing furniture state (open/closed, etc.)
    self.furnitureStateGrid = {}

    -- Initialize grids with air blocks
    for y = 1, height do
        self.foregroundGrid[y] = {}
        self.backgroundGrid[y] = {}
        self.furnitureGrid[y] = {}
        self.furnitureStateGrid[y] = {}
        for x = 1, width do
            self.foregroundGrid[y][x] = blockRegistry.BLOCK_AIR
            self.backgroundGrid[y][x] = blockRegistry.BLOCK_AIR
            self.furnitureGrid[y][x] = nil
            self.furnitureStateGrid[y][x] = nil
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
            -- Can only place if the spot is empty (air) and doesn't have furniture
            if self.foregroundGrid[gridY][gridX] == self.blockRegistry.BLOCK_AIR and not self.furnitureGrid[gridY][gridX] then
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
    -- Convert to grid coordinates
    local gridX = math.floor(x / tileSize) + 1
    local gridY = math.floor(y / tileSize) + 1

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

    -- Check for furniture at this position
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        local furnitureData = self.furnitureGrid[gridY][gridX]
        if furnitureData then
            -- Get the furniture type and state
            local furnitureType = furnitureData.type
            local originX = furnitureData.originX
            local originY = furnitureData.originY

            -- Get the current state of the furniture (stored at the origin)
            local state = self.furnitureStateGrid[originY][originX]

            -- Check if the furniture is solid based on its state
            return self.furnitureRegistry:isSolid(furnitureType, state)
        end
    end

    -- Regular solidity check for non-platform blocks
    return self.blockRegistry:isSolid(blockType)
end

-- Get furniture at grid coordinates
function GridSystem:getFurnitureAt(gridX, gridY)
    -- Direct grid access with bounds checking
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        local furnitureData = self.furnitureGrid[gridY][gridX]
        if furnitureData then
            -- Get the state from the origin cell
            local originX = furnitureData.originX
            local originY = furnitureData.originY
            local state = self.furnitureStateGrid[originY][originX]
            return furnitureData, state
        end
    end
    return nil, nil
end

-- Get furniture at world coordinates
function GridSystem:getFurniture(x, y, tileSize)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x / tileSize) + 1
    local gridY = math.floor(y / tileSize) + 1

    return self:getFurnitureAt(gridX, gridY)
end

-- Check if a furniture can be placed at the specified position
function GridSystem:canPlaceFurniture(gridX, gridY, furnitureType)
    -- Check if furniture registry exists
    if not self.furnitureRegistry then
        return false
    end

    -- Get furniture dimensions
    local furnitureWidth, furnitureHeight = self.furnitureRegistry:getDimensions(furnitureType)

    -- Check if the entire furniture area is within bounds
    if gridX < 1 or gridY < 1 or
       gridX + furnitureWidth - 1 > self.width or
       gridY + furnitureHeight - 1 > self.height then
        return false
    end

    -- Check if any cell in the furniture area already has furniture or foreground blocks
    for y = gridY, gridY + furnitureHeight - 1 do
        for x = gridX, gridX + furnitureWidth - 1 do
            -- Check for existing furniture
            if self.furnitureGrid[y][x] then
                return false
            end

            -- Check for foreground blocks (furniture can't be placed over foreground blocks)
            if self.foregroundGrid[y][x] ~= self.blockRegistry.BLOCK_AIR then
                return false
            end
        end
    end

    -- For most furniture, check if there's a solid block beneath to support it
    -- Skip this check for wall-mounted furniture or if the furniture is at the bottom of the world
    local furniture = self.furnitureRegistry:getFurniture(furnitureType)
    local needsSupport = not furniture.wallMounted

    if needsSupport and gridY + furnitureHeight <= self.height then
        local hasSupport = false

        -- Check for support at the bottom of the furniture
        for x = gridX, gridX + furnitureWidth - 1 do
            local supportY = gridY + furnitureHeight
            if supportY <= self.height then
                local blockBelow = self.foregroundGrid[supportY][x]
                if self.blockRegistry:isSolid(blockBelow) then
                    hasSupport = true
                    break
                end
            end
        end

        if not hasSupport then
            return false
        end
    end

    return true
end

-- Place furniture at grid coordinates
function GridSystem:placeFurniture(gridX, gridY, furnitureType)
    -- Check if we can place the furniture
    if not self:canPlaceFurniture(gridX, gridY, furnitureType) then
        return false
    end

    -- Get furniture dimensions
    local furnitureWidth, furnitureHeight = self.furnitureRegistry:getDimensions(furnitureType)

    -- Get default state for this furniture
    local defaultState = self.furnitureRegistry:getDefaultState(furnitureType)

    -- Place the furniture in all its grid cells
    for y = gridY, gridY + furnitureHeight - 1 do
        for x = gridX, gridX + furnitureWidth - 1 do
            self.furnitureGrid[y][x] = {
                type = furnitureType,
                originX = gridX,
                originY = gridY
            }

            -- Only set state at the origin (top-left) cell
            if x == gridX and y == gridY then
                self.furnitureStateGrid[y][x] = defaultState
            end
        end
    end

    return true
end

-- Place furniture at world coordinates
function GridSystem:placeFurnitureWorld(x, y, furnitureType, tileSize)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x / tileSize) + 1
    local gridY = math.floor(y / tileSize) + 1

    return self:placeFurniture(gridX, gridY, furnitureType)
end

-- Remove furniture at grid coordinates
function GridSystem:removeFurniture(gridX, gridY)
    -- Check if there's furniture at this position
    if gridX < 1 or gridY < 1 or gridX > self.width or gridY > self.height then
        return false
    end

    local furnitureData = self.furnitureGrid[gridY][gridX]

    if not furnitureData then
        return false
    end

    -- Get the origin of the furniture
    local originX = furnitureData.originX
    local originY = furnitureData.originY
    local furnitureType = furnitureData.type

    -- Get furniture dimensions
    local furnitureWidth, furnitureHeight = self.furnitureRegistry:getDimensions(furnitureType)

    -- Remove furniture from all its grid cells
    for y = originY, originY + furnitureHeight - 1 do
        for x = originX, originX + furnitureWidth - 1 do
            if y <= self.height and x <= self.width then
                self.furnitureGrid[y][x] = nil
                self.furnitureStateGrid[y][x] = nil
            end
        end
    end

    return true
end

-- Remove furniture at world coordinates
function GridSystem:removeFurnitureWorld(x, y, tileSize)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x / tileSize) + 1
    local gridY = math.floor(y / tileSize) + 1

    return self:removeFurniture(gridX, gridY)
end

-- Change the state of a furniture
function GridSystem:setFurnitureState(gridX, gridY, newState)
    if not self.furnitureGrid[gridY] or not self.furnitureGrid[gridY][gridX] then
        return false
    end

    local furnitureData = self.furnitureGrid[gridY][gridX]
    if not furnitureData then
        return false
    end

    -- Update state at the origin cell
    self.furnitureStateGrid[furnitureData.originY][furnitureData.originX] = newState
    return true
end

-- Get the state of a furniture
function GridSystem:getFurnitureState(gridX, gridY)
    if not self.furnitureGrid[gridY] or not self.furnitureGrid[gridY][gridX] then
        return nil
    end

    local furnitureData = self.furnitureGrid[gridY][gridX]
    if not furnitureData then
        return nil
    end

    -- Return state from the origin cell
    return self.furnitureStateGrid[furnitureData.originY][furnitureData.originX]
end

-- Clear the grid and set all blocks to air
function GridSystem:clear()
    for y = 1, self.height do
        for x = 1, self.width do
            self.foregroundGrid[y][x] = self.blockRegistry.BLOCK_AIR
            self.backgroundGrid[y][x] = self.blockRegistry.BLOCK_AIR
            self.furnitureGrid[y][x] = nil
            self.furnitureStateGrid[y][x] = nil
        end
    end
end

-- Serialize the grid for saving
function GridSystem:serialize()
    -- Convert furniture grid to a serializable format
    local serializedFurniture = {}
    local serializedFurnitureState = {}

    for y = 1, self.height do
        for x = 1, self.width do
            if self.furnitureGrid[y][x] and self.furnitureGrid[y][x].originX == x and self.furnitureGrid[y][x].originY == y then
                -- Only serialize the origin cell of each furniture
                table.insert(serializedFurniture, {
                    x = x,
                    y = y,
                    type = self.furnitureGrid[y][x].type,
                    state = self.furnitureStateGrid[y][x]
                })
            end
        end
    end

    return {
        width = self.width,
        height = self.height,
        foregroundGrid = self.foregroundGrid,
        backgroundGrid = self.backgroundGrid,
        furniture = serializedFurniture
    }
end

-- Deserialize and load grid data
function GridSystem:deserialize(data)
    if data then
        self.width = data.width
        self.height = data.height
        self.foregroundGrid = data.foregroundGrid
        self.backgroundGrid = data.backgroundGrid

        -- Clear existing furniture data
        for y = 1, self.height do
            for x = 1, self.width do
                self.furnitureGrid[y][x] = nil
                self.furnitureStateGrid[y][x] = nil
            end
        end

        -- Restore furniture from serialized data
        if data.furniture then
            for _, furnitureData in ipairs(data.furniture) do
                self:placeFurniture(furnitureData.x, furnitureData.y, furnitureData.type)
                if furnitureData.state then
                    self:setFurnitureState(furnitureData.x, furnitureData.y, furnitureData.state)
                end
            end
        end
    end
end

return GridSystem