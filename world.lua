-- World module that manages the block grid and terrain generation
local Block = require("block")

local World = {}
World.__index = World

-- Block types
World.BLOCK_AIR = 0
World.BLOCK_DIRT = 1
World.BLOCK_STONE = 2
World.BLOCK_TREE = 3
World.BLOCK_LEAVES = 4
World.BLOCK_WOOD = 5  -- New wood material block
World.BLOCK_WOOD_BACKGROUND = 6  -- Wood background that's non-solid

function World:new(width, height, tileSize)
    local self = setmetatable({}, World)

    -- Initialize with a random seed for consistent but varied world generation
    math.randomseed(os.time())
    self.worldSeed = math.random(1, 10000)
    math.randomseed(self.worldSeed)

    self.width = width
    self.height = height
    self.tileSize = tileSize

    -- Initialize two grid layers: foreground (solid blocks) and background (non-solid blocks)
    -- Foreground layer: for solid blocks (main gameplay elements)
    self.foregroundGrid = {}
    for y = 1, height do
        self.foregroundGrid[y] = {}
        for x = 1, width do
            self.foregroundGrid[y][x] = World.BLOCK_AIR
        end
    end

    -- Background layer: for non-solid decorative blocks
    self.backgroundGrid = {}
    for y = 1, height do
        self.backgroundGrid[y] = {}
        for x = 1, width do
            self.backgroundGrid[y][x] = World.BLOCK_AIR
        end
    end

    -- Keep a reference to the old grid for backward compatibility during transition
    self.grid = self.foregroundGrid

    -- Load sprite sheet
    self.spriteSheet = love.graphics.newImage("assets/Tiles/Assets/Assets.png")

    -- Based on the 400x400 sprite sheet that looks like it has a grid of tiles
    -- Let's estimate each tile is about 32x32 pixels
    self.tilesetSize = 16 -- Size of each tile in the sprite sheet

    -- Block definitions with sprite coordinates
    self.sprites = {
        [World.BLOCK_AIR] = { x = 0, y = 0 },

        [World.BLOCK_DIRT] = { x = 3, y = 0 },
        [World.BLOCK_DIRT .. "_TOP"] = { x = 3, y = 0 }, -- Special grass-topped dirt
        [World.BLOCK_DIRT .. "_TOP_LEFT"] = { x = 2, y = 0 },
        [World.BLOCK_DIRT .. "_LEFT"] = { x = 1, y = 2 },
        [World.BLOCK_DIRT .. "_TOP_RIGHT"] = { x = 5, y = 1 },
        [World.BLOCK_DIRT .. "_RIGHT"] = { x = 5, y = 2 },
        -- All bottom rows will use 3 1
        [World.BLOCK_DIRT .. "_MIDDLE"] = { x = 3, y = 1 }, -- Special grass-topped dirt
        [World.BLOCK_DIRT .. "_BOTTOM_LEFT"] = { x = 3, y = 1 },
        [World.BLOCK_DIRT .. "_BOTTOM_RIGHT"] = { x = 3, y = 1 },
        [World.BLOCK_DIRT .. "_BOTTOM"] = { x = 3, y = 1 },


        [World.BLOCK_TREE] = { x = 9, y = 18 },
        [World.BLOCK_TREE .. "_TOP_LEFT"] = { x = 9, y = 17 },
        [World.BLOCK_TREE .. "_LEFT"] = { x = 9, y = 17 },
        [World.BLOCK_TREE .. "_BOTTOM_LEFT"] = { x = 9, y = 17 },
        [World.BLOCK_TREE .. "_RIGHT"] = { x = 10, y = 17 },
        [World.BLOCK_TREE .. "_BOTTOM_RIGHT"] = { x = 10, y = 17 },
        [World.BLOCK_TREE .. "_TOP_RIGHT"] = { x = 10, y = 17 },

        -- New wood material block (using plank sprite)
        [World.BLOCK_WOOD] = { x = 8, y = 8 },

        -- Wood background (non-solid decorative version)
        [World.BLOCK_WOOD_BACKGROUND] = { x = 8, y = 13 },

        -- Base leaf sprite
        [World.BLOCK_LEAVES] = { x = 3, y = 15 },

        -- Leaf variants for auto-tiling
        [World.BLOCK_LEAVES .. "_MIDDLE"] = { x = 2, y = 17 },
        [World.BLOCK_LEAVES .. "_TOP"] = { x = 3, y = 15 },
        [World.BLOCK_LEAVES .. "_BOTTOM"] = { x = 3, y = 19 },
        [World.BLOCK_LEAVES .. "_LEFT"] = { x = 1, y = 17 },
        [World.BLOCK_LEAVES .. "_RIGHT"] = { x = 5, y = 17 },
        [World.BLOCK_LEAVES .. "_TOP_LEFT"] = { x = 1, y = 16 },
        [World.BLOCK_LEAVES .. "_TOP_RIGHT"] = { x = 4, y = 15 },
        [World.BLOCK_LEAVES .. "_BOTTOM_LEFT"] = { x = 1, y = 18 },
        [World.BLOCK_LEAVES .. "_BOTTOM_RIGHT"] = { x = 4, y = 19 },
        [World.BLOCK_LEAVES .. "_TOP_BOTTOM"] = { x = 4, y = 17 },
        [World.BLOCK_LEAVES .. "_LEFT_RIGHT"] = { x = 2, y = 19 },

        -- Stone variants
        [World.BLOCK_STONE] = { x = 3, y = 5 },
        [World.BLOCK_STONE .. "_TOP"] = { x = 3, y = 5 },
        [World.BLOCK_STONE .. "_MIDDLE"] = { x = 3, y = 8 },
        [World.BLOCK_STONE .. "_LEFT"] = { x = 1, y = 7 },
        [World.BLOCK_STONE .. "_RIGHT"] = { x = 4, y = 9 },
        [World.BLOCK_STONE .. "_TOP_LEFT"] = { x = 1, y = 6 },
        [World.BLOCK_STONE .. "_TOP_RIGHT"] = { x = 5, y = 6 },
        [World.BLOCK_STONE .. "_TOP_BOTTOM"] = { x = 5, y = 9 },
        [World.BLOCK_STONE .. "_BOTTOM"] = { x = 3, y = 9 },
        [World.BLOCK_STONE .. "_BOTTOM_LEFT"] = { x = 2, y = 9 },
        [World.BLOCK_STONE .. "_BOTTOM_RIGHT"] = { x = 4, y = 9 },
        [World.BLOCK_STONE .. "_LEFT_RIGHT"] = { x = 3, y = 11 },
    }
    self.blocks = {
        [World.BLOCK_AIR] = { name = "Air", color = {0, 0, 0, 0}, solid = false, sprite = nil },
        [World.BLOCK_DIRT] = {
            name = "Dirt",
            color = {0.6, 0.4, 0.2, 1},
            solid = true,
            sprite = self.sprites[World.BLOCK_DIRT]
        },
        [World.BLOCK_STONE] = {
            name = "Stone",
            color = {0.5, 0.5, 0.5, 1},
            solid = true,
            sprite = self.sprites[World.BLOCK_STONE]
        },
        [World.BLOCK_TREE] = {
            name = "Tree",
            color = {0.6, 0.3, 0.1, 1},
            solid = false,
            sprite = self.sprites[World.BLOCK_TREE]
        },
        [World.BLOCK_WOOD] = {
            name = "Wood",
            color = {0.8, 0.6, 0.4, 1},
            solid = true,
            sprite = self.sprites[World.BLOCK_WOOD]
        },
        [World.BLOCK_WOOD_BACKGROUND] = {
            name = "Wood Background",
            color = {0.7, 0.5, 0.3, 0.8},
            solid = false,
            sprite = self.sprites[World.BLOCK_WOOD_BACKGROUND]
        },
        [World.BLOCK_LEAVES] = {
            name = "Leaves",
            color = {0.1, 0.6, 0.1, 1},
            solid = false,
            sprite = self.sprites[World.BLOCK_LEAVES]
        },
    }

    -- Create quads for each block type plus variants
    self.blockQuads = {}
    for blockType, block in pairs(self.blocks) do
        if block.sprite then
            self.blockQuads[blockType] = love.graphics.newQuad(
                block.sprite.x * self.tilesetSize,
                block.sprite.y * self.tilesetSize,
                self.tilesetSize + 1,
                self.tilesetSize + 1,
                self.spriteSheet:getDimensions()
            )
        end
    end

    -- List of all possible variants to check for each block type
    local variants = {
        "_TOP", "_BOTTOM", "_LEFT", "_RIGHT",
        "_TOP_LEFT", "_TOP_RIGHT", "_BOTTOM_LEFT", "_BOTTOM_RIGHT",
        "_TOP_BOTTOM", "_LEFT_RIGHT", "_MIDDLE"
    }

    -- Add quads for all variants of all block types
    for blockType, _ in pairs(self.blocks) do
        if blockType ~= World.BLOCK_AIR then
            for _, variant in ipairs(variants) do
                local blockVariant = blockType .. variant
                if self.sprites[blockVariant] then
                    self.blockQuads[blockVariant] = love.graphics.newQuad(
                        self.sprites[blockVariant].x * self.tilesetSize,
                        self.sprites[blockVariant].y * self.tilesetSize,
                        self.tilesetSize +1,
                        self.tilesetSize +1,
                        self.spriteSheet:getDimensions()
                    )
                end
            end
        end
    end

    return self
end

function World:generate()
    -- Simple terrain generation with clean, distinct layers
    local baseGroundHeight = math.floor(self.height * 0.7)

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
    for x = 1, self.width do
        -- Create a varied terrain with a single, gentle sine wave
        local heightOffset = math.floor(math.sin(x / 25) * 4)

        -- Apply the height offset to create gentle hills
        local groundHeight = baseGroundHeight + heightOffset

        -- Keep a consistent rock depth
        local rockDepth = groundHeight + 4

        -- Fill ground
        for y = groundHeight, self.height do
            if y == groundHeight then
                -- Top layer is dirt with grass
                self:setBlock(x, y, World.BLOCK_DIRT)
            elseif y < rockDepth then
                -- Clean dirt layer without mixed deposits
                self:setBlock(x, y, World.BLOCK_DIRT)
            else
                -- Clean stone layer without mixed deposits
                self:setBlock(x, y, World.BLOCK_STONE)
            end
        end

        -- Tree placement with proper spacing
        if math.abs(heightOffset - (x > 1 and (baseGroundHeight + math.floor(math.sin((x-1) / 25) * 4)) - baseGroundHeight or 0)) <= 1 then
            -- Only try placing a tree if the position is available
            if canPlaceTreeAt(x) and math.random() < 0.1 then
                -- Determine trunk width for this tree
                local trunkWidth = math.random() < 0.3 and 1 or 2

                -- Generate the tree
                self:generateTree(x, groundHeight)

                -- Mark this position as occupied
                markOccupied(x, trunkWidth)

                -- Try to place a second tree at a safe distance
                local secondTreeX = x + 6  -- Greater spacing to ensure no overlap

                if secondTreeX <= self.width and canPlaceTreeAt(secondTreeX) and math.random() < 0.4 then
                    local secondTreeWidth = math.random() < 0.3 and 1 or 2
                    self:generateTree(secondTreeX, groundHeight)
                    markOccupied(secondTreeX, secondTreeWidth)

                    -- Try for a third tree with proper spacing
                    local thirdTreeX = secondTreeX + 6

                    if thirdTreeX <= self.width and canPlaceTreeAt(thirdTreeX) and math.random() < 0.3 then
                        self:generateTree(thirdTreeX, groundHeight)
                        -- No need to mark as occupied since we're done with this pass
                    end
                end
            end
        end
    end

    -- Add additional randomly placed trees with proper spacing
    local attempts = math.floor(self.width * 0.15) -- Increased attempts for better distribution
    local extraTreesPlaced = 0
    local maxExtraTrees = math.floor(self.width * 0.05) -- 5% of width as extra trees

    for i = 1, attempts do
        if extraTreesPlaced >= maxExtraTrees then
            break
        end

        local x = math.random(1, self.width)
        local trunkWidth = math.random() < 0.3 and 1 or 2

        -- Only place if there's enough space
        if canPlaceTreeAt(x, trunkWidth) then
            local groundHeight = math.floor(self.height * 0.7) + math.floor(math.sin(x / 25) * 4)
            self:generateTree(x, groundHeight)
            markOccupied(x, trunkWidth)
            extraTreesPlaced = extraTreesPlaced + 1
        end
    end
end

function World:generateTree(x, y)
    -- Tree trunk - place in the background layer since trees are non-solid
    local treeHeight = math.random(4, 7) -- Simple height variation

    -- Determine trunk width - only 1 or 2 blocks
    local trunkWidth = math.random() < 0.3 and 1 or 2 -- 30% chance for 1-block, 70% chance for 2-block

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
            if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
                self.backgroundGrid[gridY][gridX] = World.BLOCK_TREE
            end
        end
    end

    -- Place a cluster of leaves around the top of the trunk
    for ly = leafCenter - leafSize, leafCenter + leafSize do
        for lx = trunkStartX - leafSize, trunkStartX + trunkWidth - 1 + leafSize do
            -- Don't overwrite existing blocks and stay in bounds
            if lx >= 1 and lx <= self.width and ly >= 1 and ly <= self.height then
                local gridX = math.floor(lx)
                local gridY = math.floor(ly)

                -- Only place leaves where there isn't already a tree trunk
                if self.backgroundGrid[gridY][gridX] == World.BLOCK_AIR then
                    self.backgroundGrid[gridY][gridX] = World.BLOCK_LEAVES
                end
            end
        end
    end
end

function World:getBlock(x, y, layer)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x / self.tileSize) + 1
    local gridY = math.floor(y / self.tileSize) + 1

    -- Check if in bounds
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        if layer == "background" then
            return self.backgroundGrid[gridY][gridX]
        else
            return self.foregroundGrid[gridY][gridX]
        end
    end

    -- Default to air for out of bounds
    return World.BLOCK_AIR
end

function World:getBlockAt(gridX, gridY, layer)
    -- Direct grid access with bounds checking
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        if layer == "background" then
            return self.backgroundGrid[gridY][gridX]
        else
            return self.foregroundGrid[gridY][gridX]
        end
    end
    return World.BLOCK_AIR
end

function World:setBlock(x, y, blockType)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x)
    local gridY = math.floor(y)

    -- Check if in bounds
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        -- Determine which layer to use based on block solidity
        if self.blocks[blockType] and not self.blocks[blockType].solid then
            self.backgroundGrid[gridY][gridX] = blockType
        else
            self.foregroundGrid[gridY][gridX] = blockType
        end
    end
end

function World:placeBlock(x, y, blockType)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x / self.tileSize) + 1
    local gridY = math.floor(y / self.tileSize) + 1

    -- Check if in bounds
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        -- Determine which layer to use based on block solidity
        if self.blocks[blockType] and not self.blocks[blockType].solid then
            -- Non-solid blocks go to background layer
            -- Can place regardless of what's in foreground
            self.backgroundGrid[gridY][gridX] = blockType
            return true
        else
            -- Solid blocks go to foreground layer
            -- Can only place if the spot is empty (air)
            if self.foregroundGrid[gridY][gridX] == World.BLOCK_AIR then
                self.foregroundGrid[gridY][gridX] = blockType
                return true
            end
        end
    end

    return false
end

function World:removeBlock(x, y)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x / self.tileSize) + 1
    local gridY = math.floor(y / self.tileSize) + 1

    -- Check if in bounds
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        -- First try to remove from foreground if it's not air
        if self.foregroundGrid[gridY][gridX] ~= World.BLOCK_AIR then
            self.foregroundGrid[gridY][gridX] = World.BLOCK_AIR
            return true
        -- Then try to remove from background if it's not air
        elseif self.backgroundGrid[gridY][gridX] ~= World.BLOCK_AIR then
            self.backgroundGrid[gridY][gridX] = World.BLOCK_AIR
            return true
        end
    end

    return false
end

-- Helper function for determining the appropriate tile variant based on surroundings
function World:getAutoTileVariant(x, y, blockType, layer)
    -- If it's air, just return air
    if blockType == World.BLOCK_AIR then
        return tostring(blockType)
    end

    -- For all blocks, check surrounding blocks of the same type
    local function isSameBlock(checkX, checkY)
        local block = self:getBlockAt(checkX, checkY, layer)

        -- Special case for leaves - both tree and wood connect with leaves
        if blockType == World.BLOCK_LEAVES then
            return block == World.BLOCK_LEAVES or block == World.BLOCK_TREE or block == World.BLOCK_WOOD
        end

        return block == blockType
    end

    local hasBlockAbove = isSameBlock(x, y-1)
    local hasBlockBelow = isSameBlock(x, y+1)
    local hasBlockLeft = isSameBlock(x-1, y)
    local hasBlockRight = isSameBlock(x+1, y)

    -- Determine which variant to use based on neighbors
    local variant

    -- Check for all the different possible configurations
    if hasBlockAbove and hasBlockBelow and hasBlockLeft and hasBlockRight then
        -- Block surrounded on all sides - use middle sprite
        local middleVariant = blockType .. "_MIDDLE"
        -- Check if middle variant exists in our quads
        if self.blockQuads[middleVariant] then
            variant = middleVariant
        else
            -- If no middle variant exists, use default
            variant = tostring(blockType)
        end
    else
        -- In all other cases, prefer the top variant
        variant = blockType .. "_TOP"

        -- Special cases for corners and edges if they exist
        if not hasBlockAbove and hasBlockBelow and not hasBlockLeft and hasBlockRight then
            -- Top-left corner
            local cornerVariant = blockType .. "_TOP_LEFT"
            if self.blockQuads[cornerVariant] then
                variant = cornerVariant
            end
        elseif not hasBlockAbove and hasBlockBelow and hasBlockLeft and not hasBlockRight then
            -- Top-right corner
            local cornerVariant = blockType .. "_TOP_RIGHT"
            if self.blockQuads[cornerVariant] then
                variant = cornerVariant
            end
        elseif hasBlockAbove and not hasBlockBelow and not hasBlockLeft and hasBlockRight then
            -- Bottom-left corner
            local cornerVariant = blockType .. "_BOTTOM_LEFT"
            if self.blockQuads[cornerVariant] then
                variant = cornerVariant
            end
        elseif hasBlockAbove and not hasBlockBelow and hasBlockLeft and not hasBlockRight then
            -- Bottom-right corner
            local cornerVariant = blockType .. "_BOTTOM_RIGHT"
            if self.blockQuads[cornerVariant] then
                variant = cornerVariant
            end
        elseif hasBlockAbove and hasBlockBelow and not hasBlockLeft and not hasBlockRight then
            -- Left-right edge
            local edgeVariant = blockType .. "_LEFT_RIGHT"
            if self.blockQuads[edgeVariant] then
                variant = edgeVariant
            end
        elseif not hasBlockAbove and not hasBlockBelow and hasBlockLeft and hasBlockRight then
            -- Top-bottom edge
            local edgeVariant = blockType .. "_TOP_BOTTOM"
            if self.blockQuads[edgeVariant] then
                variant = edgeVariant
            end
        elseif hasBlockAbove and hasBlockBelow and not hasBlockLeft and hasBlockRight then
            -- Left edge
            local edgeVariant = blockType .. "_LEFT"
            if self.blockQuads[edgeVariant] then
                variant = edgeVariant
            end
        elseif hasBlockAbove and hasBlockBelow and hasBlockLeft and not hasBlockRight then
            -- Right edge
            local edgeVariant = blockType .. "_RIGHT"
            if self.blockQuads[edgeVariant] then
                variant = edgeVariant
            end
        elseif hasBlockAbove and not hasBlockBelow and hasBlockLeft and hasBlockRight then
            -- Bottom edge
            local edgeVariant = blockType .. "_BOTTOM"
            if self.blockQuads[edgeVariant] then
                variant = edgeVariant
            end
        end

        -- If the variant quad doesn't exist, fall back to default
        if not self.blockQuads[variant] then
            variant = tostring(blockType)
        end
    end

    return variant
end

function World:draw(camera)
    -- Get visible area bounds in tiles
    local x1, y1, x2, y2 = camera:getBounds()

    -- Convert to grid indices
    local startX = math.max(1, math.floor(x1 / self.tileSize) + 1)
    local startY = math.max(1, math.floor(y1 / self.tileSize) + 1)
    local endX = math.min(self.width, math.floor(x2 / self.tileSize) + 1)
    local endY = math.min(self.height, math.floor(y2 / self.tileSize) + 1)

    -- Draw background layer first
    self:drawLayer(camera, startX, startY, endX, endY, "background")

    -- Then draw foreground layer on top
    self:drawLayer(camera, startX, startY, endX, endY, "foreground")

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Helper method to draw a specific layer
function World:drawLayer(camera, startX, startY, endX, endY, layer)
    local grid = layer == "background" and self.backgroundGrid or self.foregroundGrid
    local alpha = layer == "background" and 0.9 or 1.0 -- Slightly less opacity for background

    -- Draw visible blocks in this layer
    for y = startY, endY do
        for x = startX, endX do
            local blockType = grid[y][x]

            -- Skip air blocks
            if blockType ~= World.BLOCK_AIR then
                -- Calculate position
                local pixelX = (x - 1) * self.tileSize
                local pixelY = (y - 1) * self.tileSize

                -- Set color for the block (used for tinting or if no sprite)
                love.graphics.setColor(1, 1, 1, alpha)

                -- Get the variant of the block to use based on auto-tiling
                local blockVariant = self:getAutoTileVariant(x, y, blockType, layer)
                local quadToUse = self.blockQuads[blockVariant]

                -- Draw using sprite if available
                if quadToUse then
                    -- Calculate scaling to match tile size
                    local scaleX = self.tileSize / self.tilesetSize
                    local scaleY = self.tileSize / self.tilesetSize

                    -- Draw the sprite with proper scaling
                    love.graphics.draw(
                        self.spriteSheet,
                        quadToUse,
                        pixelX,
                        pixelY,
                        0,  -- rotation
                        scaleX,
                        scaleY
                    )
                else
                    -- Try again with numeric key if string key failed
                    if type(blockVariant) == "string" and tonumber(blockVariant) then
                        quadToUse = self.blockQuads[tonumber(blockVariant)]
                        if quadToUse then
                            -- Draw with the quad found by numeric key
                            love.graphics.draw(
                                self.spriteSheet,
                                quadToUse,
                                pixelX,
                                pixelY,
                                0,  -- rotation
                                self.tileSize / self.tilesetSize,
                                self.tileSize / self.tilesetSize
                            )
                        else
                            -- Fallback to colored rectangle
                            local block = self.blocks[blockType]
                            local r, g, b, a = block.color[1], block.color[2], block.color[3], block.color[4] or 1
                            love.graphics.setColor(r, g, b, a * alpha)
                            love.graphics.rectangle("fill", pixelX, pixelY, self.tileSize, self.tileSize)

                            -- Draw outline
                            love.graphics.setColor(0, 0, 0, 0.3 * alpha)
                            love.graphics.rectangle("line", pixelX, pixelY, self.tileSize, self.tileSize)
                        end
                    else
                        -- Fallback to colored rectangle if still no quad
                        local block = self.blocks[blockType]
                        local r, g, b, a = block.color[1], block.color[2], block.color[3], block.color[4] or 1
                        love.graphics.setColor(r, g, b, a * alpha)
                        love.graphics.rectangle("fill", pixelX, pixelY, self.tileSize, self.tileSize)

                        -- Draw outline
                        love.graphics.setColor(0, 0, 0, 0.3 * alpha)
                        love.graphics.rectangle("line", pixelX, pixelY, self.tileSize, self.tileSize)
                    end
                end
            end
        end
    end
end

function World:isSolid(x, y)
    -- Only check foreground layer for solidity since background blocks are always non-solid
    local blockType = self:getBlock(x, y, "foreground")
    return self.blocks[blockType] and self.blocks[blockType].solid
end

return World