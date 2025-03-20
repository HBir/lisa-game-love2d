-- World module that manages the block grid and terrain generation
local Block = require("block")

local World = {}
World.__index = World

-- Block types
World.BLOCK_AIR = 0
World.BLOCK_DIRT = 1
World.BLOCK_STONE = 2
World.BLOCK_WOOD = 3
World.BLOCK_LEAVES = 4

function World:new(width, height, tileSize)
    local self = setmetatable({}, World)

    self.width = width
    self.height = height
    self.tileSize = tileSize

    -- Initialize the grid
    self.grid = {}
    for y = 1, height do
        self.grid[y] = {}
        for x = 1, width do
            self.grid[y][x] = World.BLOCK_AIR
        end
    end

    -- Load sprite sheet
    self.spriteSheet = love.graphics.newImage("assets/Tiles/Assets/Assets.png")

    -- Based on the 400x400 sprite sheet that looks like it has a grid of tiles
    -- Let's estimate each tile is about 32x32 pixels
    self.tilesetSize = 16 -- Size of each tile in the sprite sheet

    -- Block definitions with sprite coordinates
    self.sprites = {
        [World.BLOCK_AIR] = { x = 0, y = 0 },
        [World.BLOCK_DIRT] = { x = 3, y = 1 },
        [World.BLOCK_DIRT .. "_TOP"] = { x = 3, y = 0 }, -- Special grass-topped dirt
        [World.BLOCK_STONE] = { x = 3, y = 9 },
        [World.BLOCK_WOOD] = { x = 9, y = 18 },

        -- Base leaf sprite
        [World.BLOCK_LEAVES] = { x = 2, y = 17 },

        -- Leaf variants for auto-tiling
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
        [World.BLOCK_WOOD] = {
            name = "Wood",
            color = {0.6, 0.3, 0.1, 1},
            solid = true,
            sprite = self.sprites[World.BLOCK_WOOD]
        },
        [World.BLOCK_LEAVES] = {
            name = "Leaves",
            color = {0.1, 0.6, 0.1, 1},
            solid = false,
            sprite = self.sprites[World.BLOCK_LEAVES]
        },
    }

    -- Create quads for each block type plus the grass-topped dirt variant
    self.blockQuads = {}
    for blockType, block in pairs(self.blocks) do
        if block.sprite then
            self.blockQuads[blockType] = love.graphics.newQuad(
                block.sprite.x * self.tilesetSize,
                block.sprite.y * self.tilesetSize,
                self.tilesetSize,
                self.tilesetSize,
                self.spriteSheet:getDimensions()
            )
        end
    end

    -- Add the grass-topped dirt quad
    if self.sprites[World.BLOCK_DIRT .. "_TOP"] then
        self.blockQuads[World.BLOCK_DIRT .. "_TOP"] = love.graphics.newQuad(
            self.sprites[World.BLOCK_DIRT .. "_TOP"].x * self.tilesetSize,
            self.sprites[World.BLOCK_DIRT .. "_TOP"].y * self.tilesetSize,
            self.tilesetSize,
            self.tilesetSize,
            self.spriteSheet:getDimensions()
        )
    end

    -- Add quads for each leaf variant
    for _, variant in ipairs({
        "_TOP", "_BOTTOM", "_LEFT", "_RIGHT",
        "_TOP_LEFT", "_TOP_RIGHT", "_BOTTOM_LEFT", "_BOTTOM_RIGHT",
        "_TOP_BOTTOM", "_LEFT_RIGHT"
    }) do
        local leafVariant = World.BLOCK_LEAVES .. variant
        if self.sprites[leafVariant] then
            self.blockQuads[leafVariant] = love.graphics.newQuad(
                self.sprites[leafVariant].x * self.tilesetSize,
                self.sprites[leafVariant].y * self.tilesetSize,
                self.tilesetSize,
                self.tilesetSize,
                self.spriteSheet:getDimensions()
            )
        else
            -- Use default leaf sprite for variants not explicitly defined
            self.blockQuads[leafVariant] = self.blockQuads[World.BLOCK_LEAVES]
        end
    end

    return self
end

function World:generate()
    -- Simple terrain generation
    local groundHeight = math.floor(self.height * 0.7)

    -- Generate terrain with Perlin noise
    for x = 1, self.width do
        -- Create a simple hill function
        local heightOffset = math.floor(math.sin(x / 20) * 5)
        local rockDepth = groundHeight + heightOffset + 3 -- Depth where dirt becomes stone

        -- Fill ground
        for y = groundHeight + heightOffset, self.height do
            if y == groundHeight + heightOffset then
                -- Top layer is just dirt - we'll show it with grass in the draw function
                self:setBlock(x, y, World.BLOCK_DIRT)
            elseif y < rockDepth then
                self:setBlock(x, y, World.BLOCK_DIRT)
            else
                self:setBlock(x, y, World.BLOCK_STONE)
            end
        end

        -- Randomly place trees
        if math.random() < 0.05 then
            self:generateTree(x, groundHeight + heightOffset)
        end
    end
end

function World:generateTree(x, y)
    -- Tree trunk
    local treeHeight = math.random(4, 6)
    for i = 1, treeHeight do
        self:setBlock(x, y - i, World.BLOCK_WOOD)
    end

    -- Tree leaves
    local leafSize = 2
    for ly = y - treeHeight - leafSize, y - treeHeight + leafSize do
        for lx = x - leafSize, x + leafSize do
            -- Don't overwrite existing blocks and stay in bounds
            if lx >= 1 and lx <= self.width and ly >= 1 and ly <= self.height then
                if self:getBlock(lx, ly) == World.BLOCK_AIR then
                    self:setBlock(lx, ly, World.BLOCK_LEAVES)
                end
            end
        end
    end
end

function World:getBlock(x, y)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x / self.tileSize) + 1
    local gridY = math.floor(y / self.tileSize) + 1

    -- Check if in bounds
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        return self.grid[gridY][gridX]
    end

    -- Default to air for out of bounds
    return World.BLOCK_AIR
end

function World:getBlockAt(gridX, gridY)
    -- Direct grid access with bounds checking
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        return self.grid[gridY][gridX]
    end
    return World.BLOCK_AIR
end

function World:setBlock(x, y, blockType)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x)
    local gridY = math.floor(y)

    -- Check if in bounds
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height then
        self.grid[gridY][gridX] = blockType
    end
end

function World:placeBlock(x, y, blockType)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x / self.tileSize) + 1
    local gridY = math.floor(y / self.tileSize) + 1

    -- Check if in bounds and the spot is empty (air)
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height and
       self.grid[gridY][gridX] == World.BLOCK_AIR then
        self.grid[gridY][gridX] = blockType
        return true
    end

    return false
end

function World:removeBlock(x, y)
    -- Convert world coordinates to grid indices
    local gridX = math.floor(x / self.tileSize) + 1
    local gridY = math.floor(y / self.tileSize) + 1

    -- Check if in bounds and the spot is not air
    if gridX >= 1 and gridX <= self.width and gridY >= 1 and gridY <= self.height and
       self.grid[gridY][gridX] ~= World.BLOCK_AIR then
        self.grid[gridY][gridX] = World.BLOCK_AIR
        return true
    end

    return false
end

function World:draw(camera)
    -- Get visible area bounds in tiles
    local x1, y1, x2, y2 = camera:getBounds()

    -- Convert to grid indices
    local startX = math.max(1, math.floor(x1 / self.tileSize) + 1)
    local startY = math.max(1, math.floor(y1 / self.tileSize) + 1)
    local endX = math.min(self.width, math.floor(x2 / self.tileSize) + 1)
    local endY = math.min(self.height, math.floor(y2 / self.tileSize) + 1)

    -- Draw visible blocks
    for y = startY, endY do
        for x = startX, endX do
            local blockType = self.grid[y][x]

            -- Skip air blocks
            if blockType ~= World.BLOCK_AIR then
                -- Calculate position
                local pixelX = (x - 1) * self.tileSize
                local pixelY = (y - 1) * self.tileSize

                -- Set color for the block (used for tinting or if no sprite)
                love.graphics.setColor(1, 1, 1, 1)

                -- Determine which quad to use based on block type and surroundings
                local quadToUse = nil

                if blockType == World.BLOCK_DIRT then
                    -- Check if there's no solid block above
                    local blockAbove = self:getBlockAt(x, y-1)
                    if blockAbove == World.BLOCK_AIR then
                        -- Use grass-topped dirt sprite
                        quadToUse = self.blockQuads[World.BLOCK_DIRT .. "_TOP"]
                    else
                        -- Regular dirt sprite
                        quadToUse = self.blockQuads[blockType]
                    end
                elseif blockType == World.BLOCK_LEAVES then
                    -- Auto-tiling for leaves based on surrounding leaves
                    -- Count wood blocks as connecting blocks for leaves too
                    local isConnectingBlock = function(x, y)
                        local block = self:getBlockAt(x, y)
                        return block == World.BLOCK_LEAVES or block == World.BLOCK_WOOD
                    end

                    local hasLeafAbove = isConnectingBlock(x, y-1)
                    local hasLeafBelow = isConnectingBlock(x, y+1)
                    local hasLeafLeft = isConnectingBlock(x-1, y)
                    local hasLeafRight = isConnectingBlock(x+1, y)

                    -- Determine which leaf sprite to use based on neighbors
                    local leafType = World.BLOCK_LEAVES

                    -- Check for all the different possible configurations
                    if hasLeafAbove and hasLeafBelow and hasLeafLeft and hasLeafRight then
                        -- Leaf surrounded by leaves on all sides
                        leafType = World.BLOCK_LEAVES
                    elseif not hasLeafAbove and hasLeafBelow and hasLeafLeft and hasLeafRight then
                        -- Leaf with top exposed
                        leafType = World.BLOCK_LEAVES .. "_TOP"
                    elseif hasLeafAbove and not hasLeafBelow and hasLeafLeft and hasLeafRight then
                        -- Leaf with bottom exposed
                        leafType = World.BLOCK_LEAVES .. "_BOTTOM"
                    elseif hasLeafAbove and hasLeafBelow and not hasLeafLeft and hasLeafRight then
                        -- Leaf with left exposed
                        leafType = World.BLOCK_LEAVES .. "_LEFT"
                    elseif hasLeafAbove and hasLeafBelow and hasLeafLeft and not hasLeafRight then
                        -- Leaf with right exposed
                        leafType = World.BLOCK_LEAVES .. "_RIGHT"
                    elseif not hasLeafAbove and not hasLeafBelow and hasLeafLeft and hasLeafRight then
                        -- Leaf with top and bottom exposed
                        leafType = World.BLOCK_LEAVES .. "_TOP_BOTTOM"
                    elseif hasLeafAbove and hasLeafBelow and not hasLeafLeft and not hasLeafRight then
                        -- Leaf with left and right exposed
                        leafType = World.BLOCK_LEAVES .. "_LEFT_RIGHT"
                    elseif not hasLeafAbove and hasLeafBelow and not hasLeafLeft and hasLeafRight then
                        -- Top-left corner
                        leafType = World.BLOCK_LEAVES .. "_TOP_LEFT"
                    elseif not hasLeafAbove and hasLeafBelow and hasLeafLeft and not hasLeafRight then
                        -- Top-right corner
                        leafType = World.BLOCK_LEAVES .. "_TOP_RIGHT"
                    elseif hasLeafAbove and not hasLeafBelow and not hasLeafLeft and hasLeafRight then
                        -- Bottom-left corner
                        leafType = World.BLOCK_LEAVES .. "_BOTTOM_LEFT"
                    elseif hasLeafAbove and not hasLeafBelow and hasLeafLeft and not hasLeafRight then
                        -- Bottom-right corner
                        leafType = World.BLOCK_LEAVES .. "_BOTTOM_RIGHT"
                    end

                    -- Use the determined leaf quad if it exists, or fall back to default
                    quadToUse = self.blockQuads[leafType] or self.blockQuads[World.BLOCK_LEAVES]
                else
                    -- Other block types use their standard quads
                    quadToUse = self.blockQuads[blockType]
                end

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
                    -- Fallback to colored rectangle if no sprite
                    local block = self.blocks[blockType]
                    love.graphics.setColor(block.color)
                    love.graphics.rectangle("fill", pixelX, pixelY, self.tileSize, self.tileSize)

                    -- Draw outline
                    love.graphics.setColor(0, 0, 0, 0.3)
                    love.graphics.rectangle("line", pixelX, pixelY, self.tileSize, self.tileSize)
                end
            end
        end
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function World:isSolid(x, y)
    local blockType = self:getBlock(x, y)
    return self.blocks[blockType] and self.blocks[blockType].solid
end

return World