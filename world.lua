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
        self:setBlock(x, y - i, World.BLOCK_TREE)
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

-- Helper function for determining the appropriate tile variant based on surroundings
function World:getAutoTileVariant(x, y, blockType)
    -- If it's air, just return air
    if blockType == World.BLOCK_AIR then
        return tostring(blockType)
    end

    -- For all blocks, check surrounding blocks of the same type
    local function isSameBlock(checkX, checkY)
        local block = self:getBlockAt(checkX, checkY)

        -- Special case for leaves - both tree and wood connect with leaves
        if blockType == World.BLOCK_LEAVES then
            return block == World.BLOCK_LEAVES or block == World.BLOCK_TREE
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

                -- Get the variant of the block to use based on auto-tiling
                local blockVariant = self:getAutoTileVariant(x, y, blockType)
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
                            love.graphics.setColor(block.color)
                            love.graphics.rectangle("fill", pixelX, pixelY, self.tileSize, self.tileSize)

                            -- Draw outline
                            love.graphics.setColor(0, 0, 0, 0.3)
                            love.graphics.rectangle("line", pixelX, pixelY, self.tileSize, self.tileSize)
                        end
                    else
                        -- Fallback to colored rectangle if still no quad
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
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function World:isSolid(x, y)
    local blockType = self:getBlock(x, y)
    return self.blocks[blockType] and self.blocks[blockType].solid
end

return World