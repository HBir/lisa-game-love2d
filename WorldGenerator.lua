-- WorldGenerator.lua - Handles procedural terrain generation
local WorldGenerator = {}
WorldGenerator.__index = WorldGenerator

function WorldGenerator:new(gridSystem, blockRegistry)
    local self = setmetatable({}, WorldGenerator)

    self.gridSystem = gridSystem
    self.blockRegistry = blockRegistry

    -- Initialize with a random seed for consistent but varied world generation
    math.randomseed(os.time())
    self.worldSeed = math.random(1, 10000)

    return self
end

-- Set a specific seed for reproducible generation
function WorldGenerator:setSeed(seed)
    self.worldSeed = seed
    math.randomseed(self.worldSeed)
end

-- Main generation function
function WorldGenerator:generate()
    -- Initialize with the seed for consistent generation
    math.randomseed(self.worldSeed)

    -- Simple terrain generation with clean, distinct layers
    local width = self.gridSystem.width
    local height = self.gridSystem.height
    local baseGroundHeight = math.floor(height * 0.7)

    -- Keep track of placed tree areas (including trunk width) to ensure proper spacing
    local occupiedPositions = {}

    -- Mark positions as occupied
    local function markOccupied(startX, width)
        -- Mark the tree position and a buffer zone around it
        for i = startX-2, startX+width+1 do
            occupiedPositions[i] = true
        end
    end

    -- Check if a position is available for a tree with given width
    local function canPlaceTreeAt(x, width)
        -- Default width if not specified
        width = width or 2

        -- Check the tree position and buffer zone
        for i = x-2, x+width+1 do
            if occupiedPositions[i] then
                return false
            end
        end
        return true
    end

    -- Generate terrain with smoother, less noisy features
    for x = 1, width do
        -- Create a varied terrain with a single, gentle sine wave
        local heightOffset = math.floor(math.sin(x / 25) * 4)

        -- Apply the height offset to create gentle hills
        local groundHeight = baseGroundHeight + heightOffset

        -- Keep a consistent rock depth
        local rockDepth = groundHeight + 4

        -- Fill ground
        for y = groundHeight, height do
            -- First place background stone behind everything
            if y >= 1 and y <= height and x >= 1 and x <= width then
                self.gridSystem.backgroundGrid[y][x] = self.blockRegistry.BLOCK_STONE_BACKGROUND
            end

            if y == groundHeight then
                -- Top layer is dirt with grass
                self.gridSystem:setBlock(x, y, self.blockRegistry.BLOCK_DIRT)
            elseif y < rockDepth then
                -- Clean dirt layer without mixed deposits
                self.gridSystem:setBlock(x, y, self.blockRegistry.BLOCK_DIRT)
            else
                -- Clean stone layer without mixed deposits
                self.gridSystem:setBlock(x, y, self.blockRegistry.BLOCK_STONE)
            end
        end

        -- Tree placement with proper spacing
        if math.abs(heightOffset - (x > 1 and (baseGroundHeight + math.floor(math.sin((x-1) / 25) * 4)) - baseGroundHeight or 0)) <= 1 then
            -- Only try placing a tree if the position is available
            if canPlaceTreeAt(x) and math.random() < 0.1 then
                -- Determine trunk width for this tree
                local trunkWidth = math.random() < 0.3 and 1 or 2

                -- Generate the tree
                self:generateTree(x, groundHeight, trunkWidth)

                -- Mark this position as occupied
                markOccupied(x, trunkWidth)

                -- Try to place a second tree at a safe distance
                local secondTreeX = x + 6  -- Greater spacing to ensure no overlap

                if secondTreeX <= width and canPlaceTreeAt(secondTreeX) and math.random() < 0.4 then
                    local secondTreeWidth = math.random() < 0.3 and 1 or 2
                    self:generateTree(secondTreeX, groundHeight, secondTreeWidth)
                    markOccupied(secondTreeX, secondTreeWidth)

                    -- Try for a third tree with proper spacing
                    local thirdTreeX = secondTreeX + 6

                    if thirdTreeX <= width and canPlaceTreeAt(thirdTreeX) and math.random() < 0.3 then
                        local thirdTreeWidth = math.random() < 0.3 and 1 or 2
                        self:generateTree(thirdTreeX, groundHeight, thirdTreeWidth)
                        -- No need to mark as occupied since we're done with this pass
                    end
                end
            end
        end
    end

    -- Add additional randomly placed trees with proper spacing
    self:placeExtraTrees(baseGroundHeight)
end

-- Place additional trees scattered throughout the world
function WorldGenerator:placeExtraTrees(baseGroundHeight)
    local width = self.gridSystem.width
    local occupiedPositions = {}

    -- Mark positions as occupied
    local function markOccupied(startX, width)
        for i = startX-2, startX+width+1 do
            occupiedPositions[i] = true
        end
    end

    -- Check if position is available
    local function canPlaceTreeAt(x, width)
        width = width or 2
        for i = x-2, x+width+1 do
            if occupiedPositions[i] then
                return false
            end
        end
        return true
    end

    local attempts = math.floor(width * 0.15) -- Increased attempts for better distribution
    local extraTreesPlaced = 0
    local maxExtraTrees = math.floor(width * 0.05) -- 5% of width as extra trees

    for i = 1, attempts do
        if extraTreesPlaced >= maxExtraTrees then
            break
        end

        local x = math.random(1, width)
        local trunkWidth = math.random() < 0.3 and 1 or 2

        -- Only place if there's enough space
        if canPlaceTreeAt(x, trunkWidth) then
            local groundHeight = math.floor(self.gridSystem.height * 0.7) + math.floor(math.sin(x / 25) * 4)
            self:generateTree(x, groundHeight, trunkWidth)
            markOccupied(x, trunkWidth)
            extraTreesPlaced = extraTreesPlaced + 1
        end
    end
end

-- Helper function to generate a tree at the specified location
function WorldGenerator:generateTree(x, y, trunkWidth)
    -- Tree height with some variation
    local treeHeight = math.random(4, 7)

    -- Calculate trunk positions based on width
    local trunkStartX = (trunkWidth == 1) and math.floor(x) or math.floor(x - 0.5)

    -- Calculate where leaves will be placed
    local leafSize = 2 -- Fixed leaf size
    local leafCenter = y - treeHeight - 2 -- Center of leaf cluster

    -- Place trunk blocks
    for i = 1, treeHeight do
        for w = 0, trunkWidth - 1 do
            local gridX = trunkStartX + w
            local gridY = math.floor(y - i)
            if gridX >= 1 and gridX <= self.gridSystem.width and gridY >= 1 and gridY <= self.gridSystem.height then
                self.gridSystem.backgroundGrid[gridY][gridX] = self.blockRegistry.BLOCK_TREE
            end
        end
    end

    -- Place a cluster of leaves around the top of the trunk
    for ly = leafCenter - leafSize, leafCenter + leafSize do
        for lx = trunkStartX - leafSize, trunkStartX + trunkWidth - 1 + leafSize do
            -- Don't overwrite existing blocks and stay in bounds
            if lx >= 1 and lx <= self.gridSystem.width and ly >= 1 and ly <= self.gridSystem.height then
                local gridX = math.floor(lx)
                local gridY = math.floor(ly)

                -- Only place leaves where there isn't already a tree trunk
                if self.gridSystem.backgroundGrid[gridY][gridX] == self.blockRegistry.BLOCK_AIR then
                    self.gridSystem.backgroundGrid[gridY][gridX] = self.blockRegistry.BLOCK_LEAVES
                end
            end
        end
    end
end

return WorldGenerator